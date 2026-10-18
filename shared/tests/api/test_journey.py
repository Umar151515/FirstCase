"""Real API + PostgreSQL journey, including revision, review and portfolio."""

import pytest
from sqlalchemy import select

from shared.tests.conftest import create_order

pytestmark = pytest.mark.asyncio


async def test_full_first_case_journey(client, db, identities, task_data):
    customer = identities["customer"]["headers"]
    performer = identities["performer"]["headers"]
    outsider = identities["outsider"]["headers"]
    task, order = await create_order(client, identities, task_data)
    root = f"/api/v1/orders/{order['id']}"

    # Only the accepted performer can start, communicate and submit work.
    assert (await client.get(root, headers=outsider)).status_code in (403, 404)
    assert (await client.post(f"{root}/start", headers=customer)).status_code == 403
    started = await client.post(f"{root}/start", headers=performer)
    assert started.json()["status"] == "in_progress"
    message = await client.post(
        f"{root}/messages",
        headers=customer,
        json={"text": "Меню можно взять из приложенного задания."},
    )
    assert message.status_code == 201, message.text
    history = await client.get(f"{root}/messages", headers=performer)
    assert message.json()["id"] in [item["id"] for item in history.json()["items"]]
    polled = await client.get(f"{root}/messages?after_id={message.json()['id']}", headers=performer)
    assert polled.json()["items"] == []
    assert (await client.get(f"{root}/messages", headers=outsider)).status_code in (403, 404)

    submitted = await client.post(
        f"{root}/submit", headers=performer, json={"description": "Бот с меню и контактами готов"}
    )
    assert submitted.json()["status"] == "submitted"
    revised = await client.post(
        f"{root}/request-revision",
        headers=customer,
        json={"reason": "Пожалуйста, обновите время работы."},
    )
    assert revised.json()["status"] == "revision_requested"
    resubmitted = await client.post(
        f"{root}/submit", headers=performer, json={"description": "Время работы исправлено"}
    )
    assert resubmitted.json()["status"] == "submitted"
    too_many = await client.post(
        f"{root}/request-revision",
        headers=customer,
        json={"reason": "Ещё одна правка сверх согласованных"},
    )
    assert too_many.status_code == 409
    versions = (await client.get(f"{root}/deliverables", headers=customer)).json()["items"]
    assert {v["version"] for v in versions} == {1, 2}

    accepted = await client.post(f"{root}/accept", headers=customer)
    assert accepted.json()["status"] == "accepted_pending_review"
    premature_case = await client.post(
        "/api/v1/portfolio",
        headers=performer,
        json={
            "order_id": order["id"],
            "title": "Мой первый бот",
            "description": "Готовый проект",
            "result": "Меню и контакты кофейни",
            "visibility": "anonymous",
        },
    )
    assert premature_case.status_code == 409
    reviewed = await client.post(
        f"{root}/reviews",
        headers=customer,
        json={"rating": 5, "comment": "Удобный бот, спасибо за работу!"},
    )
    assert reviewed.status_code == 201, reviewed.text
    completed = await client.get(root, headers=performer)
    assert completed.json()["status"] == "completed"
    assert completed.json()["completed_at"]
    duplicate = await client.post(
        f"{root}/reviews", headers=customer, json={"rating": 1, "comment": "Повторный отзыв"}
    )
    assert duplicate.status_code == 409

    published = await client.post(
        "/api/v1/portfolio",
        headers=performer,
        json={
            "order_id": order["id"],
            "title": "Бот для локальной кофейни",
            "description": "Помог гостям быстро найти меню и контакты.",
            "result": "Рабочий Telegram-бот",
            "visibility": "anonymous",
        },
    )
    assert published.status_code == 201, published.text
    case = (await client.get(f"/api/v1/portfolio/{published.json()['id']}")).json()
    assert case["verified"] is True
    assert case["customer"] is None
    assert "order_id" not in case and "customer_id" not in case
    assert case["evidence"]["messages"] == []
    assert not case.get("review", {}).get("comment")

    profile = (await client.get(f"/api/v1/users/{identities['performer']['id']}")).json()
    assert profile["rating"] == 5
    assert profile["completed_orders"] == 1
    assert profile["verified_cases"] == 1
    assert profile["review_count"] == 1
    assert "telegram_id" not in profile and "username" not in profile

    # A second review by the performer is optional and does not govern completion.
    optional = await client.post(
        f"{root}/reviews", headers=performer, json={"rating": 5, "comment": "Чёткое задание"}
    )
    assert optional.status_code == 201
    from shared.features.orders.models import Order

    stored = await db.scalar(select(Order).where(Order.id == order["id"]))
    assert stored.status == "completed"
    assert stored.performer_id == identities["performer"]["id"]
    assert stored.task_id == task["id"]


async def test_invalid_transitions_and_review_before_acceptance(client, identities, task_data):
    _, order = await create_order(client, identities, task_data)
    root = f"/api/v1/orders/{order['id']}"
    customer, performer = identities["customer"]["headers"], identities["performer"]["headers"]
    assert (await client.post(f"{root}/accept", headers=customer)).status_code == 409
    assert (
        await client.post(
            f"{root}/reviews", headers=customer, json={"rating": 5, "comment": "Слишком рано"}
        )
    ).status_code == 409
    assert (
        await client.post(
            f"{root}/request-revision", headers=customer, json={"reason": "Результата ещё нет"}
        )
    ).status_code == 409
    assert (
        await client.post(f"{root}/submit", headers=customer, json={"description": "Чужая роль"})
    ).status_code == 403
    assert (await client.post(f"{root}/start", headers=performer)).status_code == 200
    assert (await client.post(f"{root}/start", headers=performer)).status_code == 409


async def test_dispute_and_cancellation(client, identities, task_data):
    _, order = await create_order(client, identities, task_data)
    root = f"/api/v1/orders/{order['id']}"
    disputed = await client.post(f"{root}/dispute", headers=identities["customer"]["headers"])
    assert disputed.json()["status"] == "disputed"
    _, another = await create_order(
        client, identities, {**task_data, "title": "Второй независимый заказ"}
    )
    cancelled = await client.post(
        f"/api/v1/orders/{another['id']}/cancel", headers=identities["customer"]["headers"]
    )
    assert cancelled.json()["status"] == "cancelled"
