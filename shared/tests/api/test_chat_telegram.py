import pytest
from sqlalchemy import select

from shared.features.chat.models import Message, TelegramInvite
from shared.features.notifications.models import Notification
from shared.tests.conftest import create_order

pytestmark = pytest.mark.asyncio


async def test_telegram_contacts_require_mutual_consent_and_stay_private(
    client, identities, task_data, db
):
    _, order = await create_order(client, identities, task_data)
    root = f"/api/v1/orders/{order['id']}/telegram"
    customer = identities["customer"]["headers"]
    performer = identities["performer"]["headers"]
    assert (await client.get(root, headers=customer)).json() is None
    proposal = await client.post(
        root, headers=customer, json={"username": "https://t.me/first_customer"}
    )
    assert proposal.status_code == 201, proposal.text
    invite = proposal.json()
    assert invite["my_username"] == "first_customer"
    assert invite["peer_username"] is None
    incoming = (await client.get(root, headers=performer)).json()
    assert incoming["my_username"] is None and incoming["peer_username"] is None
    assert "first_customer" not in str(incoming)
    for identity in ("outsider", "admin"):
        headers = identities[identity]["headers"]
        assert (await client.get(root, headers=headers)).status_code == 404
        assert (
            await client.post(root, headers=headers, json={"username": "outsider"})
        ).status_code == 404
        assert (
            await client.post(
                f"{root}/{invite['id']}/respond",
                headers=headers,
                json={"action": "accept", "username": "outsider"},
            )
        ).status_code == 404
    assert (await client.get(root)).status_code == 401
    response = await client.post(
        f"{root}/{invite['id']}/respond",
        headers=performer,
        json={"action": "accept", "username": "@first_performer"},
    )
    assert response.status_code == 200, response.text
    assert response.json()["peer_username"] == "first_customer"
    accepted = (await client.get(root, headers=customer)).json()
    assert accepted["peer_username"] == "first_performer"
    assert accepted["responded_at"] is not None
    # Contacts never become public profile fields or portfolio message evidence.
    profile = (await client.get(f"/api/v1/users/{identities['customer']['id']}")).json()
    assert "username" not in profile
    history = (await client.get(f"/api/v1/orders/{order['id']}/messages", headers=customer)).json()
    assert history["items"] == []
    notes = list(
        await db.scalars(select(Notification).where(Notification.type == "telegram_invite"))
    )
    assert len(notes) == 2
    assert all("first_customer" not in note.body for note in notes)


async def test_telegram_response_roles_conflicts_and_revocation(client, identities, task_data, db):
    _, order = await create_order(client, identities, task_data)
    root = f"/api/v1/orders/{order['id']}/telegram"
    owner = identities["customer"]["headers"]
    peer = identities["performer"]["headers"]
    invite = (await client.post(root, headers=owner, json={"username": "customer"})).json()
    response_url = f"{root}/{invite['id']}/respond"
    for identity in (owner, peer):
        assert (
            await client.post(root, headers=identity, json={"username": "another"})
        ).status_code == 409
    for action in ("accept", "decline"):
        payload = {"action": action, **({"username": "customer"} if action == "accept" else {})}
        assert (await client.post(response_url, headers=owner, json=payload)).status_code == 403
    assert (
        await client.post(response_url, headers=peer, json={"action": "cancel"})
    ).status_code == 403
    assert (
        await client.post(response_url, headers=peer, json={"action": "accept"})
    ).status_code == 422
    accepted = await client.post(
        response_url, headers=peer, json={"action": "accept", "username": "performer"}
    )
    assert accepted.status_code == 200
    assert (
        await client.post(
            response_url, headers=peer, json={"action": "accept", "username": "performer"}
        )
    ).status_code == 409
    cancelled = await client.post(response_url, headers=peer, json={"action": "cancel"})
    assert cancelled.status_code == 200
    assert cancelled.json()["peer_username"] is None
    for headers in (owner, peer):
        state = (await client.get(root, headers=headers)).json()
        assert state["status"] == "cancelled"
        assert state["my_username"] is None and state["peer_username"] is None
    again = await client.post(root, headers=peer, json={"username": "new_performer"})
    assert again.status_code == 201
    assert again.json()["id"] != invite["id"]
    assert (
        await client.post(response_url, headers=peer, json={"action": "decline"})
    ).status_code == 409
    assert len(list(await db.scalars(select(TelegramInvite)))) == 2


async def test_telegram_invitation_can_be_declined_or_withdrawn(client, identities, task_data):
    _, order = await create_order(client, identities, task_data)
    root = f"/api/v1/orders/{order['id']}/telegram"
    owner = identities["customer"]["headers"]
    peer = identities["performer"]["headers"]
    for action, actor in (("decline", peer), ("cancel", owner)):
        invite = (await client.post(root, headers=owner, json={"username": "customer"})).json()
        decided = await client.post(
            f"{root}/{invite['id']}/respond", headers=actor, json={"action": action}
        )
        assert decided.status_code == 200
        assert decided.json()["status"] == {"decline": "declined", "cancel": "cancelled"}[action]
        assert decided.json()["peer_username"] is None


@pytest.mark.parametrize(
    "username", ["ab", "https://evil.test/user", "@a/bcd", "user?x=1", "12345", "a" * 33]
)
async def test_telegram_rejects_invalid_contacts(client, identities, task_data, username):
    _, order = await create_order(client, identities, task_data)
    response = await client.post(
        f"/api/v1/orders/{order['id']}/telegram",
        headers=identities["customer"]["headers"],
        json={"username": username},
    )
    assert response.status_code == 422


async def test_cancelled_order_cannot_start_telegram_handoff(client, identities, task_data):
    _, order = await create_order(client, identities, task_data)
    root = f"/api/v1/orders/{order['id']}"
    headers = identities["customer"]["headers"]
    invite = (
        await client.post(f"{root}/telegram", headers=headers, json={"username": "customer"})
    ).json()
    assert (await client.post(f"{root}/cancel", headers=headers)).status_code == 200
    assert (
        await client.post(f"{root}/telegram", headers=headers, json={"username": "customer"})
    ).status_code == 409
    assert (
        await client.post(
            f"{root}/telegram/{invite['id']}/respond",
            headers=identities["performer"]["headers"],
            json={"action": "accept", "username": "performer"},
        )
    ).status_code == 409


async def test_chat_history_loads_latest_and_earlier_pages_without_losing_legacy_order(
    client, identities, task_data, db
):
    _, order = await create_order(client, identities, task_data)
    messages = [
        Message(order_id=order["id"], author_id=identities["customer"]["id"], text=f"Message {i}")
        for i in range(125)
    ]
    db.add_all(messages)
    await db.commit()
    root = f"/api/v1/orders/{order['id']}/messages"
    headers = identities["performer"]["headers"]
    latest = (
        await client.get(root, params={"latest": "true", "limit": 50}, headers=headers)
    ).json()
    assert latest["total"] == 125
    assert [m["id"] for m in latest["items"]] == [m.id for m in messages[-50:]]
    earlier = (
        await client.get(
            root,
            params={"latest": "true", "before_id": latest["items"][0]["id"], "limit": 50},
            headers=headers,
        )
    ).json()
    assert [m["id"] for m in earlier["items"]] == [m.id for m in messages[25:75]]
    legacy = (await client.get(root, params={"offset": 10, "limit": 20}, headers=headers)).json()
    assert [m["id"] for m in legacy["items"]] == [m.id for m in messages[10:30]]
    incremental = (
        await client.get(root, params={"after_id": messages[119].id, "limit": 100}, headers=headers)
    ).json()
    assert [m["id"] for m in incremental["items"]] == [m.id for m in messages[120:]]
