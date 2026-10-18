import io

import pytest
from PIL import Image

from shared.core.i18n import CATALOGS, translate
from shared.tests.conftest import create_order

pytestmark = pytest.mark.asyncio


async def image_upload(client, headers, name="photo.png"):
    output = io.BytesIO()
    Image.new("RGB", (8, 8), "#174687").save(output, "PNG")
    response = await client.post(
        "/api/v1/uploads",
        headers=headers,
        files={"file": (name, output.getvalue(), "image/png")},
    )
    assert response.status_code == 201, response.text
    return response.json()


@pytest.mark.parametrize(
    ("policy", "usage", "expected"),
    [
        ("no_ai", "no_ai", 200),
        ("no_ai", "consultation", 422),
        ("no_ai", "ai_assisted", 422),
        ("consultation", "consultation", 200),
        ("consultation", "ai_assisted", 422),
        ("ai_allowed", "ai_assisted", 200),
    ],
)
async def test_order_snapshot_enforces_ai_agreement(
    client, identities, task_data, policy, usage, expected
):
    task, order = await create_order(client, identities, {**task_data, "ai_policy": policy})
    assert task["ai_policy"] == order["ai_policy"] == policy
    performer = identities["performer"]["headers"]
    path = f"/api/v1/orders/{order['id']}"
    await client.post(f"{path}/start", headers=performer)
    result = await client.post(
        f"{path}/submit",
        headers=performer,
        json={
            "description": "Работа готова и проверена",
            "ai_usage": usage,
            "ai_disclosure": "Проверка идей",
        },
    )
    assert result.status_code == expected, result.text
    stored = await client.get(path, headers=performer)
    assert stored.json()["ai_policy"] == policy
    if expected == 422:
        assert result.json()["error"]["key"] == "ai_policy_violation"
        assert stored.json()["status"] == "in_progress"
    forbidden_edit = await client.patch(
        f"/api/v1/tasks/{task['id']}",
        headers=identities["customer"]["headers"],
        json={"ai_policy": "ai_allowed"},
    )
    assert forbidden_edit.status_code == 409


async def test_ai_disclosure_and_verified_final_version_are_not_spoofable(
    client, identities, task_data
):
    _, order = await create_order(client, identities, task_data)
    customer, performer = identities["customer"]["headers"], identities["performer"]["headers"]
    path = f"/api/v1/orders/{order['id']}"
    await client.post(f"{path}/start", headers=performer)
    missing = await client.post(
        f"{path}/submit",
        headers=performer,
        json={"description": "Результат готов к проверке", "ai_usage": "consultation"},
    )
    assert missing.status_code == 422
    assert missing.json()["error"]["key"] == "ai_disclosure_required"
    await client.post(
        f"{path}/submit",
        headers=performer,
        json={"description": "Первая версия результата", "ai_usage": "no_ai"},
    )
    revised = await client.post(
        f"{path}/request-revision",
        headers=customer,
        json={"reason": "Добавьте проверку результата"},
    )
    assert revised.status_code == 200, revised.text
    private_disclosure = "Айбек: приватная инструкция https://customer.example/private"
    submitted = await client.post(
        f"{path}/submit",
        headers=performer,
        json={
            "description": "Окончательная проверенная версия",
            "ai_usage": "consultation",
            "ai_disclosure": private_disclosure,
        },
    )
    assert submitted.status_code == 200, submitted.text
    await client.post(f"{path}/accept", headers=customer)
    reviewed = await client.post(
        f"{path}/reviews",
        headers=customer,
        json={"rating": 5, "comment": "Работа выполнена по договорённости"},
    )
    assert reviewed.status_code == 201, reviewed.text
    created = await client.post(
        "/api/v1/portfolio",
        headers=performer,
        json={
            "order_id": order["id"],
            "title": "Результат по заказу",
            "description": "Описание выполненной работы",
            "result": "Готовый проверенный проект",
            "visibility": "anonymous",
            "ai_usage": "no_ai",
        },
    )
    assert created.status_code == 201, created.text
    case = created.json()
    assert case["verified"] is True
    assert case["ai_usage"] == "consultation"
    assert case["ai_disclosure"] == private_disclosure
    spoof = await client.patch(
        f"/api/v1/portfolio/{case['id']}", headers=performer, json={"ai_usage": "no_ai"}
    )
    assert spoof.status_code == 403
    for visibility in ("anonymous", "public"):
        updated = await client.patch(
            f"/api/v1/portfolio/{case['id']}/visibility",
            headers=performer,
            json={"visibility": visibility},
        )
        assert updated.status_code == 200
        public = (await client.get(f"/api/v1/portfolio/{case['id']}")).json()
        assert public["ai_usage"] == "consultation"
        assert public["ai_disclosure"] == ""
        assert private_disclosure not in str(public)


async def test_only_current_avatar_is_public_and_identity_assets_cannot_be_rebound(
    client, identities
):
    owner, outsider = identities["performer"]["headers"], identities["outsider"]["headers"]
    photo, replacement = await image_upload(client, owner), await image_upload(client, owner)
    assert (await client.get(photo["url"])).status_code == 404
    assert (await client.get(f"{photo['url']}/metadata")).status_code == 404
    foreign = await client.patch(
        "/api/v1/users/me", headers=outsider, json={"avatar_attachment_id": photo["id"]}
    )
    assert foreign.status_code == 403
    saved = await client.patch(
        "/api/v1/users/me", headers=owner, json={"avatar_attachment_id": photo["id"]}
    )
    assert saved.status_code == 200, saved.text
    assert (await client.get(photo["url"])).status_code == 200
    assert (await client.get(f"{photo['url']}/metadata")).json()["id"] == photo["id"]
    rebound = await client.post(
        "/api/v1/portfolio",
        headers=owner,
        json={
            "title": "Учебный проект",
            "description": "Подробное описание проекта",
            "result": "Работающий проект",
            "visibility": "public",
            "attachment_ids": [photo["id"]],
        },
    )
    assert rebound.status_code == 409
    saved = await client.patch(
        "/api/v1/users/me", headers=owner, json={"avatar_attachment_id": replacement["id"]}
    )
    assert saved.status_code == 200
    assert (await client.get(photo["url"])).status_code == 404
    assert (await client.get(replacement["url"])).status_code == 200
    removed = await client.patch(
        "/api/v1/users/me", headers=owner, json={"avatar_attachment_id": None}
    )
    assert removed.status_code == 200
    assert removed.json()["avatar_attachment_id"] is None
    assert (await client.get(replacement["url"])).status_code == 404


async def test_hidden_or_replaced_task_cover_never_opens_private_task_files(
    client, identities, task_data, db
):
    from shared.features.tasks.models import Task

    owner = identities["customer"]["headers"]
    cover, private, replacement = [await image_upload(client, owner) for _ in range(3)]
    created = await client.post(
        "/api/v1/tasks",
        headers=owner,
        json={
            **task_data,
            "category_id": identities["category_id"],
            "cover_attachment_id": cover["id"],
            "attachment_ids": [private["id"]],
        },
    )
    assert created.status_code == 201, created.text
    task = created.json()
    assert (await client.get(cover["url"])).status_code == 200
    assert (await client.get(private["url"])).status_code == 404
    assert (await client.get(f"{private['url']}/metadata")).status_code == 404
    updated = await client.patch(
        f"/api/v1/tasks/{task['id']}",
        headers=owner,
        json={"cover_attachment_id": replacement["id"]},
    )
    assert updated.status_code == 200, updated.text
    assert (await client.get(cover["url"])).status_code == 404
    assert (await client.get(replacement["url"])).status_code == 200
    row = await db.get(Task, task["id"])
    row.is_hidden = True
    await db.commit()
    assert (await client.get(replacement["url"])).status_code == 404
    assert (await client.get(replacement["url"], headers=owner)).status_code == 200


async def test_case_cover_publication_and_revocation_follow_exact_customer_consent(
    client, identities, task_data
):
    from shared.tests.conftest import complete_order

    _, order = await complete_order(client, identities, task_data)
    customer, performer = identities["customer"]["headers"], identities["performer"]["headers"]
    photo = await image_upload(client, performer)
    path = f"/api/v1/orders/{order['id']}"
    linked = await client.post(
        f"{path}/messages",
        headers=performer,
        json={"text": "Изображение результата", "attachment_ids": [photo["id"]]},
    )
    assert linked.status_code == 201, linked.text
    payload = {
        "title": "Фотография результата",
        "description": "Описание выполненного проекта",
        "result": "Готовый результат",
        "order_id": order["id"],
        "visibility": "public",
        "cover_attachment_id": photo["id"],
    }
    assert (
        await client.post("/api/v1/portfolio", headers=performer, json=payload)
    ).status_code == 403
    consent = await client.put(
        f"{path}/privacy-consent", headers=customer, json={"attachment_ids": [photo["id"]]}
    )
    assert consent.status_code == 200
    created = await client.post("/api/v1/portfolio", headers=performer, json=payload)
    assert created.status_code == 201, created.text
    assert (await client.get(photo["url"])).status_code == 200
    await client.put(f"{path}/privacy-consent", headers=customer, json={"attachment_ids": []})
    public = (await client.get(f"/api/v1/portfolio/{created.json()['id']}")).json()
    assert public["cover"] is None and public["cover_attachment_id"] is None
    assert (await client.get(photo["url"])).status_code == 404
    assert (await client.get(f"{photo['url']}/metadata")).status_code == 404


async def test_language_covers_errors_categories_notifications_and_profile_preference(
    client, identities, task_data, db
):
    from shared.features.tasks.models import Category

    assert CATALOGS["ru"].keys() == CATALOGS["ky"].keys()
    category = Category(name="Дизайн", slug="design", sort_order=50)
    db.add(category)
    await db.commit()
    ky = {"Accept-Language": "ky-KG,ru;q=0.5"}
    response = await client.get("/api/v1/categories", headers=ky)
    categories = response.json()["items"] if isinstance(response.json(), dict) else response.json()
    assert next(item for item in categories if item["id"] == category.id)["name"] == translate(
        "category.design", "ky"
    )
    missing = await client.get("/api/v1/tasks/999999999", headers=ky)
    error = missing.json()["error"]
    assert error["message"] == translate(error["key"], "ky")
    assert error["message"] != translate(error["key"], "ru")
    preferred = await client.patch(
        "/api/v1/users/me", headers=identities["performer"]["headers"], json={"language": "ky"}
    )
    assert preferred.status_code == 200 and preferred.json()["language"] == "ky"
    _, order = await create_order(client, identities, task_data)
    notifications = (
        await client.get("/api/v1/notifications", headers=identities["performer"]["headers"])
    ).json()["items"]
    assert notifications
    assert any(n["title"] in CATALOGS["ky"].values() for n in notifications)
    explicit_ru = (
        await client.get(
            "/api/v1/notifications",
            headers={**identities["performer"]["headers"], "Accept-Language": "ru"},
        )
    ).json()["items"]
    assert [n["title"] for n in notifications] != [n["title"] for n in explicit_ru]
