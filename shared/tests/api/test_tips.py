import pytest

pytestmark = pytest.mark.asyncio


async def test_blocked_user_tips_are_unavailable_until_unblocked(client, identities):
    owner_id = identities["performer"]["id"]
    saved = await client.put(
        "/api/v1/tips/settings",
        headers=identities["performer"]["headers"],
        json={
            "enabled": True,
            "public_consent": True,
            "payment_url": "https://example.com/tip",
        },
    )
    assert saved.status_code == 200, saved.text
    path = f"/api/v1/users/{owner_id}/tips"
    assert (await client.get(path)).status_code == 200

    for status, expected in (("blocked", 404), ("active", 200)):
        moderated = await client.patch(
            f"/api/v1/admin/users/{owner_id}",
            headers=identities["admin"]["headers"],
            json={"status": status, "reason": "Проверка доступности реквизитов"},
        )
        assert moderated.status_code == 200, moderated.text
        response = await client.get(path)
        assert response.status_code == expected, response.text
        if status == "blocked":
            assert "example.com" not in response.text


async def test_tip_payment_url_limit_matches_storage(client, identities):
    headers = identities["performer"]["headers"]
    prefix = "https://example.com/"
    url = prefix + "a" * (2048 - len(prefix))
    saved = await client.put(
        "/api/v1/tips/settings",
        headers=headers,
        json={"enabled": True, "payment_url": url},
    )
    assert saved.status_code == 200, saved.text
    assert saved.json()["payment_url"] == url

    rejected = await client.put(
        "/api/v1/tips/settings",
        headers=headers,
        json={"enabled": True, "payment_url": url + "a"},
    )
    assert rejected.status_code == 422, rejected.text
    unchanged = await client.get("/api/v1/tips/settings", headers=headers)
    assert unchanged.status_code == 200, unchanged.text
    assert unchanged.json()["payment_url"] == url
