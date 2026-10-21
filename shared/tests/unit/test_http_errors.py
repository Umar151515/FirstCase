import httpx
import pytest

from backend.main import create_app
from shared.core.config import Settings

ORIGIN = "http://localhost:8080"


@pytest.mark.parametrize("content_length", ["-1", "invalid", str(12 * 1024 * 1024)])
async def test_rejected_request_keeps_cors_and_security_headers(content_length):
    app = create_app(Settings())
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/health", headers={"Origin": ORIGIN, "Content-Length": content_length}
        )
    assert response.status_code == (413 if content_length.isdigit() else 400)
    assert response.headers["Access-Control-Allow-Origin"] == ORIGIN
    assert response.headers["X-Content-Type-Options"] == "nosniff"
    assert response.headers["Cache-Control"] == "no-store"


async def test_rate_limit_is_readable_by_browser_and_keeps_retry_header():
    app = create_app(Settings(write_rate_limit=1))
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as client:
        await client.post("/health", headers={"Origin": ORIGIN})
        response = await client.post("/health", headers={"Origin": ORIGIN})
    assert response.status_code == 429
    assert response.headers["Access-Control-Allow-Origin"] == ORIGIN
    assert response.headers["Retry-After"] == "60"
    assert response.headers["X-Content-Type-Options"] == "nosniff"
    assert response.json()["error"]["key"] == "rate_limited"


async def test_method_not_allowed_keeps_allowed_methods():
    app = create_app(Settings())
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post("/health")
    assert response.status_code == 405
    assert "GET" in response.headers["Allow"]


@pytest.mark.parametrize(
    "allowed_origins,request_origin,expected_origin",
    [(ORIGIN, ORIGIN, ORIGIN), ("*", ORIGIN, "*"), (ORIGIN, "https://untrusted.example", None)],
)
async def test_unexpected_error_keeps_response_policy(
    allowed_origins, request_origin, expected_origin
):
    app = create_app(Settings(cors_origins=allowed_origins))

    @app.get("/unexpected-error")
    async def crash():
        raise RuntimeError("private server details")

    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app, raise_app_exceptions=False),
        base_url="http://test",
    ) as client:
        response = await client.get("/unexpected-error", headers={"Origin": request_origin})
    assert response.status_code == 500
    assert response.headers.get("Access-Control-Allow-Origin") == expected_origin
    assert response.headers["X-Content-Type-Options"] == "nosniff"
    assert response.headers["Cache-Control"] == "no-store"
    assert response.json()["error"]["key"] == "internal_error"
    assert "private server details" not in response.text
