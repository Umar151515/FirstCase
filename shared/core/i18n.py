"""Small catalogs shared by HTTP, the bot and durable notifications."""

import json
from contextvars import ContextVar
from pathlib import Path

CATALOGS = {
    language: json.loads(
        (Path(__file__).parent.parent / "locales" / f"{language}.json").read_text(encoding="utf-8")
    )
    for language in ("ru", "ky")
}
locale: ContextVar[str] = ContextVar("locale", default="ru")


def language(value: str | None) -> str:
    return "ky" if (value or "").lower().split("-")[0] == "ky" else "ru"


def accept_language(value: str) -> str:
    choices = []
    for index, part in enumerate(value.split(",")):
        tag, *options = part.strip().split(";")
        try:
            quality = float(next((p[2:] for p in options if p.startswith("q=")), "1"))
        except ValueError:
            quality = 0
        if tag.split("-")[0].lower() in CATALOGS and quality > 0:
            choices.append((quality, -index, language(tag)))
    return max(choices)[2] if choices else "ru"


def translate(key: str, lang: str | None = None, *, fallback: str | None = None, **values) -> str:
    catalog = CATALOGS[language(lang or locale.get())]
    return (
        catalog[key].format(**values) if key in catalog else (key if fallback is None else fallback)
    )


class LocaleMiddleware:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        headers = dict(scope.get("headers", []))
        token = locale.set(accept_language(headers.get(b"accept-language", b"").decode("latin-1")))
        try:
            await self.app(scope, receive, send)
        finally:
            locale.reset(token)
