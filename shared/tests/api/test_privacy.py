import base64

import pytest

from shared.tests.conftest import complete_order, create_order

pytestmark = pytest.mark.asyncio
PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEklEQVR4nGMsCbvPwMDAxAAGABOrAa1VyZalAAAAAElFTkSuQmCC"
)


async def test_private_case_is_not_public_and_unverified_work_stays_unverified(client, identities):
    owner = identities["performer"]["headers"]
    created = await client.post(
        "/api/v1/portfolio",
        headers=owner,
        json={
            "title": "Личный учебный проект",
            "description": "Дизайн для практики",
            "result": "Концепция сайта",
            "visibility": "private",
        },
    )
    assert created.status_code == 201, created.text
    case = created.json()
    assert case["verified"] is False
    assert (await client.get(f"/api/v1/portfolio/{case['id']}")).status_code == 404
    assert (
        await client.get(
            f"/api/v1/portfolio/{case['id']}", headers=identities["outsider"]["headers"]
        )
    ).status_code == 404
    assert (await client.get(f"/api/v1/portfolio/{case['id']}", headers=owner)).status_code == 200
    public_list = (
        await client.get(f"/api/v1/portfolio?user_id={identities['performer']['id']}")
    ).json()["items"]
    assert case["id"] not in [item["id"] for item in public_list]
    mine = (await client.get("/api/v1/portfolio?mine=true", headers=owner)).json()["items"]
    assert case["id"] in [item["id"] for item in mine]


async def test_files_are_private_and_invalid_uploads_rejected(client, identities, task_data):
    customer, performer = identities["customer"]["headers"], identities["performer"]["headers"]
    uploaded = await client.post(
        "/api/v1/uploads",
        headers=performer,
        files={"file": ("../../secret.txt", b"private work result", "text/plain")},
    )
    assert uploaded.status_code == 201, uploaded.text
    attachment = uploaded.json()
    assert "/" not in attachment["filename"] and "\\" not in attachment["filename"]
    url = attachment["url"]
    assert (await client.get(url)).status_code in (401, 403, 404)
    assert (await client.get(url, headers=customer)).status_code in (403, 404)
    assert (await client.get(url, headers=performer)).content == b"private work result"
    _, order = await create_order(client, identities, task_data)
    await client.post(f"/api/v1/orders/{order['id']}/start", headers=performer)
    submitted = await client.post(
        f"/api/v1/orders/{order['id']}/submit",
        headers=performer,
        json={"description": "Приватный результат", "attachment_ids": [attachment["id"]]},
    )
    assert submitted.status_code == 200, submitted.text
    assert (await client.get(url, headers=customer)).status_code == 200
    assert (await client.get(url, headers=identities["outsider"]["headers"])).status_code in (
        403,
        404,
    )
    for filename, data, mime in [
        ("attack.html", b"<script>alert(1)</script>", "text/html"),
        ("fake.png", b"<script>not an image</script>", "image/png"),
        ("huge.txt", b"x" * (10 * 1024 * 1024 + 1), "text/plain"),
    ]:
        rejected = await client.post(
            "/api/v1/uploads", headers=performer, files={"file": (filename, data, mime)}
        )
        assert rejected.status_code in (413, 415, 422), rejected.text


async def test_exact_privacy_consent_revocation_and_anonymous_redaction(
    client, identities, task_data
):
    customer, performer = identities["customer"]["headers"], identities["performer"]["headers"]
    _, order = await complete_order(client, identities, task_data)
    root = f"/api/v1/orders/{order['id']}"
    message = await client.post(
        f"{root}/messages", headers=customer, json={"text": "Приватная информация заказчика"}
    )
    assert message.status_code == 201
    message_id = message.json()["id"]
    attachment = (
        await client.post(
            "/api/v1/uploads",
            headers=performer,
            files={"file": ("result.txt", b"private result", "text/plain")},
        )
    ).json()
    # Link the file to an exact order message so its provenance is unambiguous.
    linked = await client.post(
        f"{root}/messages",
        headers=performer,
        json={"text": "Файл проекта", "attachment_ids": [attachment["id"]]},
    )
    assert linked.status_code == 201
    payload = {
        "order_id": order["id"],
        "title": "Подтверждённый кейс",
        "description": "Описание результата",
        "result": "Рабочий проект",
        "visibility": "public",
        "show_customer": True,
        "message_ids": [message_id],
        "attachment_ids": [attachment["id"]],
    }
    without_consent = await client.post("/api/v1/portfolio", headers=performer, json=payload)
    assert without_consent.status_code in (403, 409), without_consent.text
    consent_data = {
        "allow_identity": True,
        "message_ids": [message_id],
        "attachment_ids": [attachment["id"]],
    }
    assert (
        await client.put(f"{root}/privacy-consent", headers=performer, json=consent_data)
    ).status_code == 403
    consent = await client.put(f"{root}/privacy-consent", headers=customer, json=consent_data)
    assert consent.status_code == 200, consent.text
    published = await client.post("/api/v1/portfolio", headers=performer, json=payload)
    assert published.status_code == 201, published.text
    case_id = published.json()["id"]
    public = (await client.get(f"/api/v1/portfolio/{case_id}")).json()
    assert public["customer"]["id"] == identities["customer"]["id"]
    assert public["evidence"]["messages"][0]["text"] == "Приватная информация заказчика"
    assert public["evidence"]["attachments"][0]["id"] == attachment["id"]
    assert (await client.get(attachment["url"])).status_code == 200

    revoked = await client.put(
        f"{root}/privacy-consent",
        headers=customer,
        json={"allow_identity": False, "message_ids": [], "attachment_ids": []},
    )
    assert revoked.status_code == 200
    private_again = (await client.get(f"/api/v1/portfolio/{case_id}")).json()
    assert private_again["customer"] is None
    assert private_again["evidence"]["messages"] == []
    assert private_again["evidence"]["attachments"] == []
    assert (await client.get(attachment["url"])).status_code in (401, 403, 404)

    # Anonymous suppresses source evidence even after renewed customer consent.
    await client.put(f"{root}/privacy-consent", headers=customer, json=consent_data)
    changed = await client.patch(
        f"/api/v1/portfolio/{case_id}/visibility",
        headers=performer,
        json={
            "visibility": "anonymous",
            "show_customer": True,
            "message_ids": [message_id],
            "attachment_ids": [attachment["id"]],
        },
    )
    assert changed.status_code == 403
    changed = await client.patch(
        f"/api/v1/portfolio/{case_id}/visibility",
        headers=performer,
        json={"visibility": "anonymous"},
    )
    assert changed.status_code == 200
    anonymous = (await client.get(f"/api/v1/portfolio/{case_id}")).json()
    assert anonymous["customer"] is None
    assert anonymous["evidence"]["messages"] == []
    assert anonymous["evidence"]["attachments"] == []
    assert "customer_id" not in anonymous and "order_id" not in anonymous
    private_case = await client.patch(
        f"/api/v1/portfolio/{case_id}/visibility",
        headers=performer,
        json={
            "visibility": "private",
            "message_ids": [message_id],
            "attachment_ids": [attachment["id"]],
        },
    )
    assert private_case.status_code == 200
    assert len(private_case.json()["evidence"]["messages"]) == 1
    assert len(private_case.json()["evidence"]["attachments"]) == 1
    assert (await client.get(f"/api/v1/portfolio/{case_id}")).status_code == 404


async def test_tips_require_owner_image_and_consent_without_payment_side_effect(
    client, identities, task_data
):
    owner, outsider = identities["performer"]["headers"], identities["outsider"]["headers"]
    uploaded = await client.post(
        "/api/v1/uploads", headers=owner, files={"file": ("qr.png", PNG, "image/png")}
    )
    assert uploaded.status_code == 201, uploaded.text
    attachment = uploaded.json()
    config = {
        "payment_method": "Электронный кошелёк",
        "qr_attachment_id": attachment["id"],
        "payment_url": "https://example.com/tip",
        "enabled": True,
        "public_consent": False,
    }
    assert (
        await client.put("/api/v1/tips/settings", headers=outsider, json=config)
    ).status_code in (403, 404)
    saved = await client.put("/api/v1/tips/settings", headers=owner, json=config)
    assert saved.status_code == 200, saved.text
    private_qr = await client.get(f"/api/v1/users/{identities['performer']['id']}/tips")
    assert private_qr.status_code in (403, 404)
    published = await client.put(
        "/api/v1/tips/settings", headers=owner, json={**config, "public_consent": True}
    )
    assert published.status_code == 200
    assert (
        await client.get(f"/api/v1/users/{identities['performer']['id']}/tips")
    ).status_code == 200
    assert (await client.get(attachment["url"])).status_code == 200
    assert (
        await client.post("/api/v1/tips/confirm-payment", headers=outsider, json={"amount": 500})
    ).status_code == 404


async def test_attachment_idor_cannot_rebind_another_users_file(client, identities, task_data):
    customer = identities["customer"]["headers"]
    performer = identities["performer"]["headers"]
    stranger = identities["outsider"]["headers"]
    foreign = await client.post(
        "/api/v1/uploads",
        headers=stranger,
        files={"file": ("private.txt", b"stranger confidential data", "text/plain")},
    )
    assert foreign.status_code == 201
    attachment_id = foreign.json()["id"]
    task = await client.post(
        "/api/v1/tasks",
        headers=customer,
        json={
            **task_data,
            "category_id": identities["category_id"],
            "attachment_ids": [attachment_id],
        },
    )
    assert task.status_code in (403, 404)
    _, order = await create_order(client, identities, task_data)
    sent = await client.post(
        f"/api/v1/orders/{order['id']}/messages",
        headers=performer,
        json={"text": "Попытка привязать чужой файл", "attachment_ids": [attachment_id]},
    )
    assert sent.status_code in (403, 404)
    assert (await client.get(foreign.json()["url"], headers=performer)).status_code in (403, 404)


async def test_chunked_upload_cannot_bypass_body_limit(client, identities):
    async def stream():
        yield b'--firstcase\r\nContent-Disposition: form-data; name="file"; filename="large.txt"\r\nContent-Type: text/plain\r\n\r\n'
        for _ in range(12):
            yield b"x" * (1024 * 1024)
        yield b"\r\n--firstcase--\r\n"

    response = await client.post(
        "/api/v1/uploads",
        headers={
            **identities["performer"]["headers"],
            "Content-Type": "multipart/form-data; boundary=firstcase",
        },
        content=stream(),
    )
    assert response.status_code == 413, response.text
