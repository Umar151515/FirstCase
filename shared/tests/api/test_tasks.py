from datetime import datetime, timedelta

import pytest

pytestmark = pytest.mark.asyncio


async def test_task_crud_search_filters_and_authorization(client, identities, task_data):
    customer, outsider = identities["customer"]["headers"], identities["outsider"]["headers"]
    response = await client.post(
        "/api/v1/tasks",
        headers=customer,
        json={**task_data, "category_id": identities["category_id"]},
    )
    assert response.status_code == 201, response.text
    task_id = response.json()["id"]
    assert (await client.get(f"/api/v1/tasks/{task_id}")).status_code == 200
    forbidden = await client.patch(
        f"/api/v1/tasks/{task_id}",
        headers=outsider,
        json={"title": "Попытка изменить чужую задачу"},
    )
    assert forbidden.status_code == 403
    changed = await client.patch(
        f"/api/v1/tasks/{task_id}", headers=customer, json={"title": "Разработать меню кофейни"}
    )
    assert changed.json()["title"] == "Разработать меню кофейни"
    found = await client.get(
        "/api/v1/tasks",
        params={
            "q": "меню кофейни",
            "category_id": identities["category_id"],
            "city": "Бишкек",
            "status": "published",
            "sort": "oldest",
            "offset": 0,
            "limit": 1,
        },
    )
    assert found.json()["total"] == 1
    assert found.json()["items"][0]["id"] == task_id
    created_at = datetime.fromisoformat(response.json()["created_at"])
    future = await client.get(
        "/api/v1/tasks",
        params={
            "created_after": (created_at + timedelta(seconds=1)).isoformat(),
        },
    )
    assert future.json()["items"] == []
    past = await client.get(
        "/api/v1/tasks",
        params={
            "created_before": (created_at - timedelta(seconds=1)).isoformat(),
        },
    )
    assert past.json()["items"] == []
    invalid_dates = await client.get(
        "/api/v1/tasks",
        params={
            "created_after": (created_at + timedelta(days=1)).isoformat(),
            "created_before": created_at.isoformat(),
        },
    )
    assert invalid_dates.status_code == 422
    null_patch = await client.patch(
        f"/api/v1/tasks/{task_id}", headers=customer, json={"title": None}
    )
    assert null_patch.status_code == 422
    empty = await client.get("/api/v1/tasks?q=nonexistent987654321")
    assert empty.json()["items"] == []
    assert (await client.get("/api/v1/tasks?mine=true")).status_code == 401
    cancelled = await client.post(f"/api/v1/tasks/{task_id}/cancel", headers=customer)
    assert cancelled.json()["status"] == "cancelled"
    assert (
        await client.post(
            f"/api/v1/tasks/{task_id}/applications",
            headers=outsider,
            json={"message": "Сделаю качественно", "proposed_deadline": task_data["deadline"]},
        )
    ).status_code == 409


async def test_application_uniqueness_self_application_and_single_assignment(
    client, identities, task_data
):
    customer, performer = identities["customer"]["headers"], identities["performer"]["headers"]
    outsider = identities["outsider"]["headers"]
    task = (
        await client.post(
            "/api/v1/tasks",
            headers=customer,
            json={**task_data, "category_id": identities["category_id"]},
        )
    ).json()
    path = f"/api/v1/tasks/{task['id']}/applications"
    payload = {"message": "Подхожу для этой задачи", "proposed_deadline": task_data["deadline"]}
    assert (await client.post(path, headers=customer, json=payload)).status_code in (403, 409)
    first = await client.post(path, headers=performer, json=payload)
    assert first.status_code == 201
    assert (await client.post(path, headers=performer, json=payload)).status_code == 409
    second = await client.post(path, headers=outsider, json=payload)
    assert second.status_code == 201
    own = (await client.get(path, headers=performer)).json()["items"]
    assert len(own) == 1 and own[0]["performer_id"] == identities["performer"]["id"]
    assert len((await client.get(path, headers=customer)).json()["items"]) == 2
    accepted = await client.post(
        f"/api/v1/applications/{first.json()['id']}/accept", headers=customer
    )
    assert accepted.status_code == 200
    again = await client.post(f"/api/v1/applications/{first.json()['id']}/accept", headers=customer)
    assert again.status_code in (200, 409)
    other = await client.post(
        f"/api/v1/applications/{second.json()['id']}/accept", headers=customer
    )
    assert other.status_code == 409
    assert (
        await client.patch(
            f"/api/v1/tasks/{task['id']}",
            headers=customer,
            json={"title": "После выбора менять нельзя"},
        )
    ).status_code == 409


async def test_input_validation(client, identities, task_data):
    for updates in (
        {"title": ""},
        {"max_revisions": -1},
        {"max_revisions": 100},
        {"payment_type": "credit_card"},
        {"category_id": -1},
    ):
        response = await client.post(
            "/api/v1/tasks",
            headers=identities["customer"]["headers"],
            json={**task_data, "category_id": identities["category_id"], **updates},
        )
        assert response.status_code in (404, 422), response.text
    assert (await client.get("/api/v1/tasks?limit=100000")).status_code == 422
