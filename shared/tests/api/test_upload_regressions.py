import io

import pytest
from PIL import Image

from shared.tests.api.test_ai_media_locale import image_upload

pytestmark = pytest.mark.asyncio


async def test_truncated_image_returns_validation_error_without_writing_file(client, identities):
    output = io.BytesIO()
    Image.new("RGB", (32, 32), "red").save(output, "JPEG")
    response = await client.post(
        "/api/v1/uploads",
        headers=identities["customer"]["headers"],
        files={"file": ("truncated.jpg", output.getvalue()[:-2], "image/jpeg")},
    )
    assert response.status_code == 422, response.text
    assert response.json()["error"]["code"] == "invalid_file"
    assert not list(client._transport.app.state.settings.upload_dir.glob("*"))


async def test_disabled_tip_qr_stays_reserved_until_removed_from_settings(client, identities):
    owner = identities["performer"]["headers"]
    photo = await image_upload(client, owner)
    config = {"qr_attachment_id": photo["id"], "enabled": False, "public_consent": False}
    saved = await client.put("/api/v1/tips/settings", headers=owner, json=config)
    assert saved.status_code == 200, saved.text
    reused = await client.patch(
        "/api/v1/users/me", headers=owner, json={"avatar_attachment_id": photo["id"]}
    )
    assert reused.status_code == 409, reused.text
    assert (await client.get(photo["url"])).status_code == 404

    cleared = await client.put("/api/v1/tips/settings", headers=owner, json={"enabled": False})
    assert cleared.status_code == 200, cleared.text
    reusable = await client.patch(
        "/api/v1/users/me", headers=owner, json={"avatar_attachment_id": photo["id"]}
    )
    assert reusable.status_code == 200, reusable.text
