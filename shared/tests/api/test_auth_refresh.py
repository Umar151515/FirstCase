import time

import pytest

from shared.tests.unit.test_security import signed_data

pytestmark = pytest.mark.asyncio


async def telegram_login(client):
    return await client.post(
        "/api/v1/auth/telegram", json={"init_data": signed_data(auth_date=str(int(time.time())))}
    )


async def test_telegram_login_preserves_custom_profile_name(client):
    first = await telegram_login(client)
    assert first.status_code == 200, first.text
    headers = {"Authorization": f"Bearer {first.json()['access_token']}"}
    updated = await client.patch(
        "/api/v1/users/me", headers=headers, json={"display_name": "Моё имя в FirstCase"}
    )
    assert updated.status_code == 200, updated.text
    refreshed = await telegram_login(client)
    assert refreshed.status_code == 200, refreshed.text
    assert refreshed.json()["user"]["display_name"] == "Моё имя в FirstCase"


async def test_removed_admin_loses_access_with_existing_token_and_after_login(client):
    settings = client._transport.app.state.settings
    settings.admin_telegram_ids = "12345"
    first = await telegram_login(client)
    assert first.status_code == 200, first.text
    assert first.json()["user"]["role"] == "admin"
    headers = {"Authorization": f"Bearer {first.json()['access_token']}"}
    assert (await client.get("/api/v1/admin/stats", headers=headers)).status_code == 200

    settings.admin_telegram_ids = ""
    denied = await client.get("/api/v1/admin/stats", headers=headers)
    assert denied.status_code == 403, denied.text
    assert (await client.get("/api/v1/auth/me", headers=headers)).json()["role"] == "user"
    refreshed = await telegram_login(client)
    assert refreshed.status_code == 200, refreshed.text
    assert refreshed.json()["user"]["role"] == "user"
