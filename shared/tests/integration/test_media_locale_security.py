import io
import json
import time
from types import SimpleNamespace
from unittest.mock import AsyncMock

from PIL import Image
from sqlalchemy.ext.asyncio import async_sessionmaker

from bot.outbox import deliver_batch
from shared.core.i18n import translate
from shared.core.storage import sanitize_image, validate_bytes
from shared.features.notifications.services import NotificationService
from shared.models import User
from shared.tests.unit.test_security import signed_data


async def test_custom_avatar_and_preferred_language_survive_telegram_refresh(client):
    identity = {
        "id": 932741,
        "first_name": "Айпери",
        "language_code": "ky",
        "photo_url": "https://telegram.example/old.jpg",
    }
    raw = signed_data(auth_date=str(int(time.time())), user=json.dumps(identity))
    login = await client.post("/api/v1/auth/telegram", json={"init_data": raw})
    assert login.status_code == 200, login.text
    first = login.json()
    assert first["user"]["language"] == "ky"
    headers = {"Authorization": f"Bearer {first['access_token']}"}
    picture = io.BytesIO()
    Image.new("RGB", (12, 12), "navy").save(picture, "PNG")
    upload = await client.post(
        "/api/v1/uploads",
        headers=headers,
        files={"file": ("avatar.png", picture.getvalue(), "image/png")},
    )
    assert upload.status_code == 201, upload.text
    photo = upload.json()
    updated = await client.patch(
        "/api/v1/users/me",
        headers=headers,
        json={"avatar_attachment_id": photo["id"], "language": "ky"},
    )
    assert updated.status_code == 200, updated.text
    refreshed = signed_data(
        auth_date=str(int(time.time())),
        user=json.dumps(
            {**identity, "language_code": "ru", "photo_url": "https://telegram.example/new.jpg"}
        ),
    )
    again = await client.post("/api/v1/auth/telegram", json={"init_data": refreshed})
    assert again.status_code == 200, again.text
    user = again.json()["user"]
    assert user["id"] == first["user"]["id"]
    assert user["avatar_attachment_id"] == photo["id"]
    assert user["avatar_url"] == photo["url"]
    assert user["language"] == "ky"
    public = await client.get(f"/api/v1/users/{user['id']}")
    assert public.json()["avatar_url"] == photo["url"]
    assert (await client.get(photo["url"])).status_code == 200


async def test_telegram_outbox_uses_saved_kyrgyz_language_without_translating_user_text(db):
    user = User(display_name="Айпери", telegram_id=932742, is_demo=False, language="ky")
    db.add(user)
    await db.flush()
    body = "Заказчик: файл {client_document} готов."
    notification = await NotificationService(db).notify(
        user.id, "new_message", "new_message", "/orders/42", body
    )
    await db.commit()
    factory = async_sessionmaker(
        bind=db.bind, expire_on_commit=False, join_transaction_mode="create_savepoint"
    )
    bot = SimpleNamespace(send_message=AsyncMock())
    assert (
        await deliver_batch(
            bot, factory, SimpleNamespace(public_webapp_url="https://firstcase.example")
        )
        == 1
    )
    bot.send_message.assert_awaited_once()
    sent = bot.send_message.await_args.kwargs
    assert sent["chat_id"] == user.telegram_id
    assert sent["text"] == f"{translate('new_message', 'ky')}\n\n{body}"
    assert sent["reply_markup"].inline_keyboard[0][0].text == translate("bot.open_in_app", "ky")
    assert sent["parse_mode"] is None
    await db.refresh(notification)
    assert notification.delivered_at is not None
    assert notification.title == "new_message"


def test_public_image_sanitization_strips_gps_identity_and_preserves_orientation():
    image = Image.new("RGB", (16, 8), "#174687")
    exif = Image.Exif()
    exif[274] = 6  # The viewer must apply a quarter turn before removing EXIF.
    exif[315] = "Private Customer Identity"
    exif[34853] = {1: "N", 2: (42.0, 51.0, 0.0), 3: "E", 4: (74.0, 36.0, 0.0)}
    original = io.BytesIO()
    image.save(original, "JPEG", exif=exif)
    source = original.getvalue()
    with Image.open(io.BytesIO(source)) as stored:
        assert stored.getexif()[315] == "Private Customer Identity"
        assert stored.getexif().get_ifd(34853)
    clean = sanitize_image(source, "image/jpeg")
    validate_bytes(clean, "image/jpeg")
    with Image.open(io.BytesIO(clean)) as stored:
        assert stored.size == (8, 16)
        assert not stored.getexif()
        assert "exif" not in stored.info
    assert b"Private Customer Identity" not in clean


async def test_private_case_cover_is_available_only_through_audited_report_access(
    client, identities
):
    owner, admin = identities["performer"]["headers"], identities["admin"]["headers"]
    picture = io.BytesIO()
    Image.new("RGB", (10, 10), "navy").save(picture, "PNG")
    photo = (
        await client.post(
            "/api/v1/uploads",
            headers=owner,
            files={"file": ("cover.png", picture.getvalue(), "image/png")},
        )
    ).json()
    case = await client.post(
        "/api/v1/portfolio",
        headers=owner,
        json={
            "title": "Личный учебный проект",
            "description": "Описание личного проекта",
            "result": "Готовая иллюстрация",
            "visibility": "private",
            "cover_attachment_id": photo["id"],
        },
    )
    assert case.status_code == 201, case.text
    report = await client.post(
        "/api/v1/reports",
        headers=owner,
        json={
            "target_type": "portfolio",
            "target_id": case.json()["id"],
            "reason": "other",
            "description": "Прошу проверить изображение обложки моего проекта.",
        },
    )
    assert report.status_code == 201, report.text
    assert (await client.get(photo["url"], headers=admin)).status_code == 404
    report_path = f"/api/v1/admin/reports/{report.json()['id']}"
    evidence = await client.post(
        f"{report_path}/evidence-access",
        headers=admin,
        json={"reason": "Проверяю обложку по конкретной жалобе"},
    )
    assert evidence.status_code == 200, evidence.text
    attachments = evidence.json()["attachments"]
    cover = next(file for file in attachments if file["id"] == photo["id"])
    assert cover["url"] == f"{report_path}/attachments/{photo['id']}"
    assert (await client.get(cover["url"], headers=admin)).status_code == 200
    closed = await client.patch(
        report_path,
        headers=admin,
        json={"status": "resolved", "moderator_comment": "Проверка обложки завершена"},
    )
    assert closed.status_code == 200, closed.text
    assert (await client.get(cover["url"], headers=admin)).status_code == 403
