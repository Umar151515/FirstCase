import asyncio
from contextlib import suppress

from aiogram import Bot, Dispatcher
from aiogram.client.default import DefaultBotProperties
from aiogram.client.session.aiohttp import AiohttpSession
from aiogram.enums import ParseMode
from aiogram.types import BotCommand, MenuButtonWebApp, WebAppInfo

from bot.handlers.commands import router
from bot.keyboards.webapp import app_url
from bot.middleware import ServiceMiddleware
from bot.outbox import delivery_loop
from shared.core.config import get_settings
from shared.core.database import engine, session_factory
from shared.core.logging import configure_logging


async def main() -> None:
    settings = get_settings()
    configure_logging()
    if not settings.telegram_bot_token:
        raise RuntimeError(
            "Bot requires TELEGRAM_BOT_TOKEN; the demo app works without running bot"
        )
    app_url(settings.public_webapp_url)  # Validate before starting any network workers.
    bot = Bot(
        settings.telegram_bot_token,
        session=AiohttpSession(timeout=15),
        default=DefaultBotProperties(parse_mode=ParseMode.HTML),
    )
    dispatcher = Dispatcher()
    dispatcher.message.outer_middleware(ServiceMiddleware(session_factory, settings))
    dispatcher.include_router(router)
    worker = None
    try:
        await bot.set_my_commands(
            [
                BotCommand(command="start", description="Открыть FirstCase"),
                BotCommand(command="help", description="Как работает сервис"),
                BotCommand(command="profile", description="Мой профиль"),
                BotCommand(command="tasks", description="Найти заказ"),
            ]
        )
        await bot.set_chat_menu_button(
            menu_button=MenuButtonWebApp(
                text="FirstCase", web_app=WebAppInfo(url=app_url(settings.public_webapp_url))
            )
        )
        worker = asyncio.create_task(
            delivery_loop(bot, session_factory, settings), name="telegram-outbox"
        )
        await dispatcher.start_polling(bot, close_bot_session=False)
    finally:
        if worker:
            worker.cancel()
            with suppress(asyncio.CancelledError):
                await worker
        await bot.session.close()
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
