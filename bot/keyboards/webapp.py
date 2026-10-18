from urllib.parse import urlsplit, urlunsplit

from aiogram.types import InlineKeyboardButton, InlineKeyboardMarkup, WebAppInfo

from shared.core.i18n import translate


def app_url(base: str, route: str = "/") -> str:
    parsed = urlsplit(base)
    if parsed.scheme != "https" or not parsed.netloc:
        raise ValueError("Telegram WebApp buttons require an HTTPS PUBLIC_WEBAPP_URL")
    safe_route = route if route.startswith("/") and not route.startswith("//") else "/"
    return urlunsplit((parsed.scheme, parsed.netloc, parsed.path.rstrip("/") + safe_route, "", ""))


def open_app(base: str, route: str = "/", label: str | None = None) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        inline_keyboard=[
            [
                InlineKeyboardButton(
                    text=label or translate("bot.open_app"),
                    web_app=WebAppInfo(url=app_url(base, route)),
                )
            ]
        ]
    )
