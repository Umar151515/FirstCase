import pytest

from shared.tests.conftest import create_order

pytestmark = pytest.mark.asyncio


@pytest.mark.parametrize(
    ("is_demo", "stored_role", "configured_admin", "expected_status"),
    [
        (False, "admin", False, 200),
        (False, "user", True, 403),
        (True, "admin", False, 403),
    ],
)
async def test_admin_block_protection_uses_current_configuration(
    client, db, identities, is_demo, stored_role, configured_admin, expected_status
):
    from shared.features.users.models import User

    target = User(
        display_name="Пользователь для проверки роли",
        telegram_id=None if is_demo else 700001,
        is_demo=is_demo,
        role=stored_role,
    )
    db.add(target)
    await db.commit()
    target_id = target.id
    settings = client._transport.app.state.settings
    settings.admin_telegram_ids = "700001" if configured_admin else ""

    # The target never signs in or makes a request to refresh its stored role.
    response = await client.patch(
        f"/api/v1/admin/users/{target_id}",
        headers=identities["admin"]["headers"],
        json={"status": "blocked", "reason": "Проверка актуальных прав администратора"},
    )
    assert response.status_code == expected_status, response.text
    saved = await db.get(User, target_id, populate_existing=True)
    if expected_status == 200:
        assert response.json()["role"] == "user"
        assert saved.status == "blocked"
    else:
        assert response.json()["error"]["key"] == "admin_block_forbidden"
        assert saved.status == "active"
    assert (
        await client.get("/api/v1/admin/stats", headers=identities["admin"]["headers"])
    ).status_code == 200


async def test_reports_moderation_blocking_and_audit(client, identities):
    customer, admin = identities["customer"]["headers"], identities["admin"]["headers"]
    assert (await client.get("/api/v1/admin/stats", headers=customer)).status_code == 403
    assert (await client.get("/api/v1/admin/users")).status_code == 401
    created = await client.post(
        "/api/v1/reports",
        headers=customer,
        json={
            "target_type": "user",
            "target_id": identities["outsider"]["id"],
            "reason": "spam",
            "description": "Пользователь рассылает повторяющиеся сообщения.",
        },
    )
    assert created.status_code == 201, created.text
    report_id = created.json()["id"]
    assert (
        await client.get(f"/api/v1/reports/{report_id}", headers=identities["performer"]["headers"])
    ).status_code in (403, 404)
    for status in ("in_review", "resolved"):
        updated = await client.patch(
            f"/api/v1/admin/reports/{report_id}",
            headers=admin,
            json={"status": status, "moderator_comment": "Проверили жалобу и приняли решение."},
        )
        assert updated.status_code == 200, updated.text
        assert updated.json()["status"] == status
    blocked = await client.patch(
        f"/api/v1/admin/users/{identities['outsider']['id']}",
        headers=admin,
        json={"status": "blocked", "reason": "Подтверждённый спам"},
    )
    assert blocked.status_code == 200
    blocked_request = await client.get("/api/v1/auth/me", headers=identities["outsider"]["headers"])
    assert blocked_request.status_code == 403
    unblocked = await client.patch(
        f"/api/v1/admin/users/{identities['outsider']['id']}",
        headers=admin,
        json={"status": "active", "reason": "Блокировка снята после проверки"},
    )
    assert unblocked.status_code == 200
    actions = (await client.get("/api/v1/admin/moderation-actions", headers=admin)).json()
    assert actions["total"] >= 4
    notifications = (await client.get("/api/v1/notifications", headers=customer)).json()["items"]
    assert notifications
    read = await client.post(
        f"/api/v1/notifications/{notifications[0]['id']}/read", headers=customer
    )
    assert read.status_code == 200 and read.json()["read_at"]


async def test_admin_chat_access_requires_specific_report_and_is_audited(
    client, identities, task_data
):
    _, order = await create_order(client, identities, task_data)
    admin, customer = identities["admin"]["headers"], identities["customer"]["headers"]
    root = f"/api/v1/orders/{order['id']}"
    await client.post(
        f"{root}/messages", headers=customer, json={"text": "Приватный чат по заказу"}
    )
    proof = await client.post(
        "/api/v1/uploads",
        headers=customer,
        files={"file": ("report-proof.txt", b"private report evidence", "text/plain")},
    )
    assert proof.status_code == 201
    assert (await client.get(f"{root}/messages", headers=admin)).status_code in (403, 404)
    report = await client.post(
        "/api/v1/reports",
        headers=customer,
        json={
            "target_type": "order",
            "target_id": order["id"],
            "reason": "agreement_violation",
            "description": "Прошу проверить переписку по конкретному спору.",
            "attachment_ids": [proof.json()["id"]],
        },
    )
    assert report.status_code == 201
    access = await client.post(
        f"/api/v1/admin/reports/{report.json()['id']}/evidence-access",
        headers=admin,
        json={"reason": "Проверка обстоятельств конкретной жалобы"},
    )
    assert access.status_code == 200, access.text
    assert access.json()["messages"][0]["text"] == "Приватный чат по заказу"
    assert (await client.get(proof.json()["url"], headers=admin)).status_code in (403, 404)
    proof_url = f"/api/v1/admin/reports/{report.json()['id']}/attachments/{proof.json()['id']}"
    proof_read = await client.get(proof_url, headers=admin)
    assert proof_read.status_code == 200, proof_read.text
    assert proof_read.content == b"private report evidence"
    assert "no-store" in proof_read.headers.get("cache-control", "")
    actions = (await client.get("/api/v1/admin/moderation-actions", headers=admin)).json()
    assert actions["total"] >= 2
    await client.patch(
        f"/api/v1/admin/reports/{report.json()['id']}",
        headers=admin,
        json={"status": "resolved", "moderator_comment": "Проверка по жалобе завершена"},
    )
    assert (await client.get(proof_url, headers=admin)).status_code == 403


async def test_admin_can_hide_and_restore_task(client, identities, task_data):
    task = (
        await client.post(
            "/api/v1/tasks",
            headers=identities["customer"]["headers"],
            json={**task_data, "category_id": identities["category_id"]},
        )
    ).json()
    path = f"/api/v1/admin/tasks/{task['id']}"
    hidden = await client.patch(
        path,
        headers=identities["admin"]["headers"],
        json={"is_hidden": True, "reason": "Проверка публикации"},
    )
    assert hidden.status_code == 200
    assert (await client.get(f"/api/v1/tasks/{task['id']}")).status_code == 404
    public = await client.get("/api/v1/tasks")
    assert task["id"] not in [item["id"] for item in public.json()["items"]]
    mine = await client.get("/api/v1/tasks?mine=true", headers=identities["customer"]["headers"])
    assert mine.status_code == 200, mine.text
    assert task["id"] in [item["id"] for item in mine.json()["items"]]
    assert mine.json()["items"][0]["is_hidden"] is True
    restored = await client.patch(
        path,
        headers=identities["admin"]["headers"],
        json={"is_hidden": False, "reason": "Проверка завершена"},
    )
    assert restored.status_code == 200
    assert (await client.get(f"/api/v1/tasks/{task['id']}")).status_code == 200
