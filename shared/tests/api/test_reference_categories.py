import time

import pytest
from sqlalchemy import func, select

from scripts.seed_reference import CATEGORIES, ensure_categories
from shared.features.tasks.models import Category
from shared.features.users.models import User
from shared.tests.unit.test_security import signed_data

pytestmark = pytest.mark.asyncio


async def test_reference_bootstrap_is_idempotent_and_preserves_existing_categories(db):
    existing = Category(slug="design", name="Custom design", active=False, sort_order=99)
    db.add(existing)
    await db.flush()
    original_id = existing.id
    await ensure_categories(db)
    await ensure_categories(db)
    categories = list(await db.scalars(select(Category)))
    assert {c.slug for c in categories} == {slug for slug, _ in CATEGORIES}
    await db.refresh(existing)
    assert (existing.id, existing.name, existing.active, existing.sort_order) == (
        original_id,
        "Custom design",
        False,
        99,
    )
    assert await db.scalar(select(func.count()).select_from(User)) == 0


async def test_fresh_database_supports_task_publication_without_demo_seed(client, db, task_data):
    await ensure_categories(db)
    response = await client.get("/api/v1/categories")
    assert response.status_code == 200
    assert response.json()["total"] == len(CATEGORIES)
    login = await client.post(
        "/api/v1/auth/telegram", json={"init_data": signed_data(auth_date=str(int(time.time())))}
    )
    assert login.status_code == 200, login.text
    assert login.json()["user"]["is_demo"] is False
    created = await client.post(
        "/api/v1/tasks",
        headers={"Authorization": f"Bearer {login.json()['access_token']}"},
        json={**task_data, "category_id": response.json()["items"][0]["id"]},
    )
    assert created.status_code == 201, created.text
    assert created.json()["category"]["slug"] in {slug for slug, _ in CATEGORIES}
