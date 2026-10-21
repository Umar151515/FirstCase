"""First writes need a stable row to lock before settings exist."""

import asyncio
import uuid

import pytest
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from shared.tests.conftest import TEST_URL, assert_test_database


@pytest.mark.asyncio
async def test_simultaneous_first_tip_updates_preserve_one_complete_settings_row():
    from backend.main import create_app  # noqa: F401 -- registers feature models
    from shared.core.database import Base
    from shared.features.tips.models import TipSettings
    from shared.features.tips.schemas import TipSettingsUpdate
    from shared.features.tips.services import TipService
    from shared.features.users.models import User

    assert_test_database(TEST_URL)
    schema = "firstcase_tips_race_" + uuid.uuid4().hex
    control = create_async_engine(TEST_URL)
    async with control.begin() as connection:
        await connection.execute(text(f'CREATE SCHEMA "{schema}"'))
    engine = create_async_engine(
        TEST_URL, connect_args={"server_settings": {"search_path": schema}}
    )
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    try:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        async with sessions.begin() as session:
            owner = User(display_name="Исполнитель", is_demo=True)
            session.add(owner)
            await session.flush()
            owner_id = owner.id

        writes = 8
        ready = asyncio.Barrier(writes)

        async def update_settings(index):
            async with sessions.begin() as session:
                # Establish all independent connections first, then make their
                # initial writes race rather than measuring connection startup.
                await session.connection()
                await ready.wait()
                return await TipService(session).update(
                    owner_id,
                    TipSettingsUpdate(
                        enabled=True,
                        payment_method=f"method-{index}",
                        payment_url=f"https://example.com/tip/{index}",
                    ),
                )

        results = await asyncio.gather(*(update_settings(index) for index in range(writes)))
        assert len(results) == writes
        async with sessions() as session:
            assert await session.scalar(select(func.count()).select_from(TipSettings)) == 1
            saved = await session.get(TipSettings, owner_id)
            index = saved.payment_method.removeprefix("method-")
            assert saved.payment_url == f"https://example.com/tip/{index}"
            assert saved.enabled is True
    finally:
        await engine.dispose()
        async with control.begin() as connection:
            await connection.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
        await control.dispose()
