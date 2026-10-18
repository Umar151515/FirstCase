import time

import pytest

from shared.tests.unit.test_security import signed_data

pytestmark = pytest.mark.asyncio


async def test_verified_telegram_login_creates_and_reuses_identity(client):
    raw = signed_data(auth_date=str(int(time.time())))
    response = await client.post("/api/v1/auth/telegram", json={"init_data": raw})
    assert response.status_code == 200, response.text
    first = response.json()
    assert first["user"]["telegram_id"] == 12345
    assert first["user"]["is_demo"] is False
    headers = {"Authorization": f"Bearer {first['access_token']}"}
    current = await client.get("/api/v1/auth/me", headers=headers)
    assert current.status_code == 200
    assert current.json()["id"] == first["user"]["id"]
    again = await client.post("/api/v1/auth/telegram", json={"init_data": raw})
    assert again.json()["user"]["id"] == first["user"]["id"]
    tampered = await client.post(
        "/api/v1/auth/telegram", json={"init_data": raw.replace("AAETest", "tampered")}
    )
    assert tampered.status_code == 401
    missing = await client.post("/api/v1/auth/telegram", json={})
    assert missing.status_code == 422
    assert (await client.get("/api/v1/auth/me")).status_code == 401
    forged = await client.get(
        "/api/v1/auth/me", headers={"Authorization": "Bearer invalid.token.signature"}
    )
    assert forged.status_code == 401


async def test_profile_onboarding_and_public_data_minimization(client, identities):
    headers = identities["performer"]["headers"]
    updated = await client.patch(
        "/api/v1/users/me",
        headers=headers,
        json={
            "bio": "Делаю Telegram-ботов для небольших проектов.",
            "specialization": "Python разработчик",
            "skills": ["Python", "aiogram"],
            "city": "Бишкек",
            "work_links": ["https://example.com/portfolio"],
            "onboarding_completed": True,
        },
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["onboarding_completed"] is True
    assert updated.json()["skills"] == ["Python", "aiogram"]
    public = await client.get(f"/api/v1/users/{identities['performer']['id']}")
    assert public.json()["specialization"] == "Python разработчик"
    for field in ("telegram_id", "username", "role", "is_demo", "status"):
        assert field not in public.json()
    invalid = await client.patch(
        "/api/v1/users/me", headers=headers, json={"work_links": ["javascript:alert(1)"]}
    )
    assert invalid.status_code == 422
    escalation = await client.patch("/api/v1/users/me", headers=headers, json={"role": "admin"})
    assert escalation.status_code == 422
    assert (await client.get("/api/v1/auth/me", headers=headers)).json()["role"] == "user"
