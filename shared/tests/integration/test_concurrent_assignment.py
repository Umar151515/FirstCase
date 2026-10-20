"""Two independent transactions race against PostgreSQL row locks."""

import asyncio
import uuid

import httpx
import pytest
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from shared.tests.conftest import TEST_URL, assert_test_database


@pytest.mark.asyncio
async def test_two_simultaneous_accepts_create_exactly_one_order(task_data, tmp_path):
    from backend.main import create_app
    from shared.core.config import Settings, get_settings
    from shared.core.database import Base
    from shared.core.dependencies import get_session
    from shared.features.orders.models import Order
    from shared.features.tasks.models import Category
    from shared.features.users.models import User

    assert_test_database(TEST_URL)
    # Isolated schema makes setup committed and visible to both HTTP sessions.
    schema = "firstcase_race_" + uuid.uuid4().hex
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
            users = [
                User(display_name=name, is_demo=True)
                for name in ("Заказчик", "Исполнитель 1", "Исполнитель 2")
            ]
            category = Category(name="Разработка", slug="race-development", sort_order=0)
            session.add_all([*users, category])
        settings = Settings(
            app_mode="demo",
            database_url=TEST_URL,
            upload_dir=tmp_path,
            jwt_secret="concurrency-test-secret-366ce56545824f30",
        )
        app = create_app(settings)

        async def independent_session():
            async with sessions() as session, session.begin():
                yield session

        app.dependency_overrides[get_session] = independent_session
        app.dependency_overrides[get_settings] = lambda: settings
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://race"
        ) as client:
            headers = []
            for user in users:
                login = await client.post("/api/v1/auth/demo-login", json={"user_id": user.id})
                assert login.status_code == 200, login.text
                headers.append({"Authorization": "Bearer " + login.json()["access_token"]})
            task = await client.post(
                "/api/v1/tasks", headers=headers[0], json={**task_data, "category_id": category.id}
            )
            assert task.status_code == 201, task.text
            applications = []
            for performer_headers in headers[1:]:
                response = await client.post(
                    f"/api/v1/tasks/{task.json()['id']}/applications",
                    headers=performer_headers,
                    json={
                        "message": "Готов выполнить эту задачу",
                        "proposed_deadline": task_data["deadline"],
                    },
                )
                assert response.status_code == 201, response.text
                applications.append(response.json())
            results = await asyncio.gather(
                *[
                    client.post(
                        f"/api/v1/applications/{application['id']}/accept", headers=headers[0]
                    )
                    for application in applications
                ]
            )
            assert sorted(response.status_code for response in results) == [200, 409], [
                r.text for r in results
            ]
        async with sessions() as session:
            assert await session.scalar(select(func.count()).select_from(Order)) == 1
    finally:
        await engine.dispose()
        async with control.begin() as connection:
            await connection.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
        await control.dispose()
