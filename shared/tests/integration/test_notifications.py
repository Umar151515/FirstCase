from datetime import timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock

from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker

from bot.outbox import claim_pending, deliver_batch
from shared.core.database import utcnow
from shared.models import Notification, Order, User
from shared.tests.conftest import create_order


async def test_delivery_failure_keeps_business_order_and_retries(db, client, identities, task_data):
    _, order = await create_order(client, identities, task_data)
    performer = await db.get(User, identities["performer"]["id"])
    performer.is_demo = False
    performer.telegram_id = 740001
    await db.commit()
    factory = async_sessionmaker(
        bind=db.bind, expire_on_commit=False, join_transaction_mode="create_savepoint"
    )
    bot = SimpleNamespace(send_message=AsyncMock(side_effect=RuntimeError("Telegram unavailable")))
    settings = SimpleNamespace(public_webapp_url="https://firstcase.example")
    assert await deliver_batch(bot, factory, settings) == 1
    stored_order = await db.get(Order, order["id"])
    assert stored_order.status == "assigned"
    notification_id = (
        await db.execute(select(Notification.id).where(Notification.user_id == performer.id))
    ).scalar_one()
    notification = await db.get(Notification, notification_id)
    await db.refresh(notification)
    assert notification.delivered_at is None
    assert notification.last_error == "RuntimeError"
    assert notification.attempts == 1
    assert notification.claim_until is None
    assert notification.next_attempt_at > utcnow()
    notification.next_attempt_at = utcnow() - timedelta(seconds=1)
    await db.commit()
    bot.send_message = AsyncMock()
    assert await deliver_batch(bot, factory, settings) == 1
    await db.refresh(notification)
    assert notification.delivered_at is not None
    assert notification.attempts == 2
    assert notification.last_error is None
    assert await deliver_batch(bot, factory, settings) == 0


async def test_demo_notifications_never_call_telegram(db):
    user = User(display_name="Демо", telegram_id=-740002, is_demo=True)
    db.add(user)
    await db.flush()
    db.add(Notification(user_id=user.id, type="test", title="Только демо", link="/"))
    await db.commit()
    factory = async_sessionmaker(
        bind=db.bind, expire_on_commit=False, join_transaction_mode="create_savepoint"
    )
    bot = SimpleNamespace(send_message=AsyncMock())
    assert (
        await deliver_batch(
            bot, factory, SimpleNamespace(public_webapp_url="https://firstcase.example")
        )
        == 0
    )
    bot.send_message.assert_not_awaited()


async def test_outbox_lease_prevents_second_worker_claim(db):
    user = User(display_name="Telegram user", telegram_id=740003, is_demo=False)
    db.add(user)
    await db.flush()
    notification = Notification(user_id=user.id, type="test", title="Один получатель", link="/")
    db.add(notification)
    await db.commit()
    factory = async_sessionmaker(
        bind=db.bind, expire_on_commit=False, join_transaction_mode="create_savepoint"
    )
    claimed = await claim_pending(factory)
    assert [delivery.id for delivery in claimed] == [notification.id]
    assert await claim_pending(factory) == []
