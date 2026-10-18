"""Independent signed Telegram payloads exercise real authentication validation."""

import hashlib
import hmac
import json
from urllib.parse import urlencode

import httpx
import pytest
from pydantic import ValidationError

from shared.core.exceptions import DomainError
from shared.tests.conftest import assert_test_database

TOKEN = "123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk"
NOW = 1_800_000_000


def signed_data(**overrides):
    fields = {
        "auth_date": str(NOW),
        "query_id": "AAETest",
        "user": json.dumps({"id": 12345, "first_name": "Айбек"}),
    }
    fields.update(overrides)
    check = "\n".join(f"{k}={v}" for k, v in sorted(fields.items()))
    secret = hmac.new(b"WebAppData", TOKEN.encode(), hashlib.sha256).digest()
    fields["hash"] = hmac.new(secret, check.encode(), hashlib.sha256).hexdigest()
    return urlencode(fields)


def test_valid_telegram_payload():
    from shared.core.security import validate_telegram_init_data

    data = validate_telegram_init_data(signed_data(), TOKEN, now=NOW)
    assert data["id"] == 12345


@pytest.mark.parametrize("raw", ["", "user=%7B%7D", "auth_date=1&hash=xyz"])
def test_missing_or_malformed_telegram_payload(raw):
    from shared.core.security import validate_telegram_init_data

    with pytest.raises(DomainError):
        validate_telegram_init_data(raw, TOKEN, now=NOW)


def test_invalid_signature():
    from shared.core.security import validate_telegram_init_data

    with pytest.raises(DomainError):
        validate_telegram_init_data(signed_data().replace("AAETest", "tampered"), TOKEN, now=NOW)


@pytest.mark.parametrize("timestamp", [NOW - 3601, NOW + 301])
def test_stale_or_future_payload(timestamp):
    from shared.core.security import validate_telegram_init_data

    with pytest.raises(DomainError):
        validate_telegram_init_data(signed_data(auth_date=str(timestamp)), TOKEN, now=NOW)


def test_duplicate_parameters_rejected():
    from shared.core.security import validate_telegram_init_data

    with pytest.raises(DomainError):
        validate_telegram_init_data(signed_data() + "&auth_date=1", TOKEN, now=NOW)


@pytest.mark.parametrize(
    "url",
    [
        "postgresql+asyncpg://u:p@localhost/firstcase_demo",
        "postgresql+asyncpg://u:p@localhost/postgres",
        "sqlite+aiosqlite:///:memory:",
    ],
)
def test_tests_cannot_clear_primary_database(url):
    with pytest.raises(RuntimeError):
        assert_test_database(url)


def test_tests_cannot_use_same_test_named_primary_database():
    url = "postgresql+asyncpg://u:p@localhost/firstcase_test"
    with pytest.raises(RuntimeError):
        assert_test_database(url, url)


def test_production_rejects_demo_secrets():
    from shared.core.config import Settings

    with pytest.raises(ValidationError):
        Settings(app_mode="production", jwt_secret="demo-secret", telegram_bot_token="")


async def test_production_contains_no_demo_routes():
    from backend.main import create_app
    from shared.core.config import Settings

    settings = Settings(
        app_mode="production",
        debug=False,
        telegram_bot_token=TOKEN,
        jwt_secret="04c219a735b00f1c8d46f6b1af2c0b7ea35c199bdc671347f465b811732e5a97",
        database_url="postgresql+asyncpg://production:independent@localhost/firstcase",
        cors_origins="https://firstcase.example.com",
        public_webapp_url="https://firstcase.example.com",
        api_public_url="https://firstcase.example.com",
    )
    app = create_app(settings)
    paths = set(app.openapi()["paths"])
    assert "/api/v1/auth/demo-login" not in paths
    assert "/api/v1/auth/demo-users" not in paths
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="https://production"
    ) as client:
        assert (
            await client.post("/api/v1/auth/demo-login", json={"user_id": 1})
        ).status_code == 404
        assert (await client.get("/api/v1/auth/demo-users")).status_code == 404
        assert (await client.get("/docs")).status_code == 404
        assert (await client.get("/openapi.json")).status_code == 404


def test_mode_bound_tokens_and_tampering():
    from shared.core.config import Settings
    from shared.core.security import create_access_token, decode_access_token

    settings = Settings(jwt_secret="a-local-independent-test-key-32-characters-long")
    token = create_access_token(42, settings)
    assert decode_access_token(token, settings) == 42
    production = settings.model_copy(update={"app_mode": "production"})
    with pytest.raises(DomainError):
        decode_access_token(token, production)
    with pytest.raises(DomainError):
        decode_access_token(token[:-10] + "invalidkey", settings)
