"""PostgreSQL-only integration fixtures; every test rolls back its outer transaction."""

import os
from collections.abc import AsyncIterator
from datetime import UTC, datetime, timedelta

import httpx
import pytest
import pytest_asyncio
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

TEST_URL = os.environ.get(
    "TEST_DATABASE_URL",
    "postgresql+asyncpg://firstcase_test:firstcase_test_local@localhost:5544/firstcase_test",
)


def assert_test_database(url: str, main_url: str | None = None) -> None:
    """Reject any URL that could point at the primary or a non-test database."""
    parsed = make_url(url)
    if not parsed.drivername.startswith("postgresql") or not parsed.database:
        raise RuntimeError("Tests require a dedicated PostgreSQL database")
    if not parsed.database.endswith("_test"):
        raise RuntimeError("Test database name must end with _test")
    if main_url:
        main = make_url(main_url)
        if (main.host, main.port, main.database) == (parsed.host, parsed.port, parsed.database):
            raise RuntimeError("TEST_DATABASE_URL must not reference the primary database")


@pytest_asyncio.fixture
async def db(tmp_path) -> AsyncIterator[AsyncSession]:
    assert_test_database(TEST_URL, os.environ.get("DATABASE_URL"))
    from backend.main import create_app  # noqa: F401 — registers every feature model
    from shared.core.database import Base

    engine = create_async_engine(TEST_URL)
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    async with engine.connect() as connection:
        transaction = await connection.begin()
        async with AsyncSession(
            bind=connection,
            expire_on_commit=False,
            join_transaction_mode="create_savepoint",
        ) as session:
            yield session
        await transaction.rollback()
    await engine.dispose()


@pytest_asyncio.fixture
async def client(db: AsyncSession, tmp_path) -> AsyncIterator[httpx.AsyncClient]:
    from backend.main import create_app
    from shared.core.config import Settings, get_settings
    from shared.core.dependencies import get_session

    settings = Settings(
        app_mode="demo",
        database_url=TEST_URL,
        jwt_secret="test-only-secret-72930f2699c04398a3d2769fa690840f",
        telegram_bot_token="123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk",
        upload_dir=tmp_path / "uploads",
    )
    app = create_app(settings)

    async def override_session():
        try:
            yield db
            await db.commit()
        except Exception:
            await db.rollback()
            raise

    app.dependency_overrides[get_session] = override_session
    app.dependency_overrides[get_settings] = lambda: settings
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as http:
        yield http
    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def identities(db, client):
    from shared.features.tasks.models import Category
    from shared.features.users.models import User

    users = [
        User(display_name="Айбек", is_demo=True, role="user", onboarding_completed=True),
        User(display_name="Нурбек", is_demo=True, role="user", onboarding_completed=True),
        User(display_name="Диана", is_demo=True, role="user", onboarding_completed=True),
        User(display_name="Администратор", is_demo=True, role="admin", onboarding_completed=True),
    ]
    category = Category(name="Разработка", slug="development-test", sort_order=0)
    db.add_all([*users, category])
    await db.commit()
    result = {"category_id": category.id}
    for key, user in zip(("customer", "performer", "outsider", "admin"), users, strict=True):
        response = await client.post("/api/v1/auth/demo-login", json={"user_id": user.id})
        assert response.status_code == 200, response.text
        token = response.json()["access_token"]
        result[key] = {"id": user.id, "headers": {"Authorization": f"Bearer {token}"}}
    return result


@pytest.fixture
def task_data():
    return {
        "title": "Сделать Telegram-бота для кофейни",
        "description": "Нужен бот с меню кофейни, часами работы и контактами. Без платежей.",
        "expected_result": "Рабочий бот и инструкция по запуску",
        "deadline": (datetime.now(UTC) + timedelta(days=7)).isoformat(),
        "max_revisions": 1,
        "payment_type": "tips",
        "city": "Бишкек",
    }


async def create_order(client, identities, task_data):
    customer = identities["customer"]["headers"]
    performer = identities["performer"]["headers"]
    created = await client.post(
        "/api/v1/tasks",
        headers=customer,
        json={**task_data, "category_id": identities["category_id"]},
    )
    assert created.status_code == 201, created.text
    task = created.json()
    applied = await client.post(
        f"/api/v1/tasks/{task['id']}/applications",
        headers=performer,
        json={
            "message": "Занимаюсь Python и aiogram, сделаю аккуратно.",
            "proposed_deadline": task_data["deadline"],
        },
    )
    assert applied.status_code == 201, applied.text
    accepted = await client.post(
        f"/api/v1/applications/{applied.json()['id']}/accept", headers=customer
    )
    assert accepted.status_code == 200, accepted.text
    return task, accepted.json()


async def complete_order(client, identities, task_data):
    task, order = await create_order(client, identities, task_data)
    path = f"/api/v1/orders/{order['id']}"
    for action, identity, payload in (
        ("start", "performer", None),
        (
            "submit",
            "performer",
            {"description": "Готовый бот", "links": ["https://example.com/result"]},
        ),
        ("accept", "customer", None),
        ("reviews", "customer", {"rating": 5, "comment": "Отличная работа, всё по заданию"}),
    ):
        response = await client.post(
            f"{path}/{action}", headers=identities[identity]["headers"], json=payload
        )
        assert response.status_code in (200, 201), response.text
    return task, order
