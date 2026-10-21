from contextlib import asynccontextmanager
from datetime import timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from sqlalchemy import create_engine, select

from bot.outbox import PendingDelivery, record_delivery
from shared.core.database import utcnow
from shared.models import Notification


@pytest.fixture
def notification_store():
    """Run the production UPDATE against SQL without accessing any application DB."""
    engine = create_engine("sqlite://")
    Notification.__table__.create(engine)

    @asynccontextmanager
    async def transaction():
        with engine.begin() as connection:
            yield SimpleNamespace(execute=AsyncMock(side_effect=connection.execute))

    @asynccontextmanager
    async def factory():
        async with transaction() as session:
            session.begin = lambda: _no_transaction()
            yield session

    @asynccontextmanager
    async def _no_transaction():
        yield

    try:
        yield engine, factory
    finally:
        engine.dispose()


@pytest.mark.parametrize("error", [None, RuntimeError("old worker failed")])
@pytest.mark.parametrize("completed", [False, True])
async def test_expired_delivery_cannot_overwrite_a_newer_attempt(
    notification_store, error, completed
):
    engine, factory = notification_store
    now = utcnow()
    lease = None if completed else now + timedelta(minutes=5)
    delivered_at = now if completed else None
    with engine.begin() as connection:
        connection.execute(
            Notification.__table__.insert().values(
                id=1,
                user_id=1,
                type="test",
                title="Test",
                attempts=2,
                claim_until=lease,
                delivered_at=delivered_at,
                last_error="new worker result",
            )
        )
        before = connection.execute(select(Notification.__table__)).mappings().one()

    await record_delivery(
        factory, PendingDelivery(1, 123, "Test", "", "/", attempts=1), error=error
    )

    with engine.connect() as connection:
        after = connection.execute(select(Notification.__table__)).mappings().one()
    assert after == before


@pytest.mark.parametrize("error", [None, RuntimeError("try again")])
async def test_current_delivery_finishes_and_repeated_completion_is_ignored(
    notification_store, error
):
    engine, factory = notification_store
    with engine.begin() as connection:
        connection.execute(
            Notification.__table__.insert().values(
                id=1,
                user_id=1,
                type="test",
                title="Test",
                attempts=1,
                claim_until=utcnow() + timedelta(minutes=5),
            )
        )
    delivery = PendingDelivery(1, 123, "Test", "", "/", attempts=1)
    await record_delivery(factory, delivery, error=error)
    with engine.connect() as connection:
        finished = connection.execute(select(Notification.__table__)).mappings().one()
    assert finished["claim_until"] is None
    assert (finished["delivered_at"] is not None) == (error is None)
    assert finished["last_error"] == (None if error is None else "RuntimeError")
    if error is not None:
        assert finished["next_attempt_at"].replace(tzinfo=utcnow().tzinfo) > utcnow()

    await record_delivery(factory, delivery, error=RuntimeError("duplicate completion"))
    with engine.connect() as connection:
        repeated = connection.execute(select(Notification.__table__)).mappings().one()
    assert repeated == finished
