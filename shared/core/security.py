import hashlib
import hmac
import json
import time
from datetime import UTC, datetime, timedelta
from urllib.parse import parse_qsl

import jwt

from shared.core.config import Settings
from shared.core.exceptions import DomainError


def unauthorized(message: str = "Требуется авторизация") -> DomainError:
    return DomainError(message, 401, "unauthorized")


def validate_telegram_init_data(
    raw: str, bot_token: str, max_age: int = 3600, now: int | None = None
) -> dict:
    if not raw or not bot_token or len(raw) > 16384:
        raise unauthorized("Отсутствуют данные Telegram")
    try:
        pairs = parse_qsl(raw, strict_parsing=True, keep_blank_values=True)
        data = dict(pairs)
        if len(data) != len(pairs):
            raise ValueError("Duplicate fields")
        signature = data.pop("hash")
        check_string = "\n".join(f"{key}={value}" for key, value in sorted(data.items()))
        secret = hmac.new(b"WebAppData", bot_token.encode(), hashlib.sha256).digest()
        expected = hmac.new(secret, check_string.encode(), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(signature, expected):
            raise ValueError("Invalid hash")
        timestamp = int(data["auth_date"])
        current = int(time.time()) if now is None else int(now)
        if timestamp > current + 30 or current - timestamp > max_age:
            raise ValueError("Expired data")
        user = json.loads(data["user"])
        if not isinstance(user, dict) or not isinstance(user.get("id"), int) or user["id"] <= 0:
            raise ValueError("Invalid user")
        return user
    except (KeyError, ValueError, TypeError, OverflowError) as exc:
        raise unauthorized("Недействительные или просроченные данные Telegram") from exc


def create_access_token(user_id: int, settings: Settings) -> str:
    now = datetime.now(UTC)
    return jwt.encode(
        {
            "sub": str(user_id),
            "iat": now,
            "exp": now + timedelta(minutes=settings.jwt_expire_minutes),
            "iss": "firstcase",
            "aud": "firstcase-api",
            "mode": settings.app_mode,
        },
        settings.jwt_secret,
        algorithm="HS256",
    )


def decode_access_token(token: str, settings: Settings) -> int:
    try:
        claims = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=["HS256"],
            audience="firstcase-api",
            issuer="firstcase",
            options={"require": ["exp", "iat", "sub", "mode"]},
        )
        if claims["mode"] != settings.app_mode:
            raise ValueError("Wrong mode")
        value = int(claims["sub"])
        if value < 1:
            raise ValueError("Invalid ID")
        return value
    except (jwt.PyJWTError, ValueError, TypeError) as exc:
        raise unauthorized("Сессия истекла. Войдите снова") from exc
