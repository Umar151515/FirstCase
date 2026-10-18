"""aiogram dependency assembly; FastAPI Depends is deliberately not involved."""

from collections.abc import Awaitable, Callable
from typing import Any

from aiogram import BaseMiddleware
from aiogram.types import TelegramObject
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from shared.core.config import Settings
from shared.core.exceptions import DomainError
from shared.core.i18n import language, locale
from shared.features.auth.services import AuthService
from shared.features.tasks.services import TaskService
from shared.features.users.services import UserService


class ServiceMiddleware(BaseMiddleware):
    def __init__(self, factory: async_sessionmaker[AsyncSession], settings: Settings):
        self.factory = factory
        self.settings = settings

    async def __call__(
        self,
        handler: Callable[[TelegramObject, dict[str, Any]], Awaitable[Any]],
        event: TelegramObject,
        data: dict[str, Any],
    ) -> Any:
        async with self.factory() as session:
            sender = data.get("event_from_user") or getattr(event, "from_user", None)
            user = await UserService(session).get_by_telegram(sender.id) if sender else None
            token = locale.set(
                user.language if user else language(getattr(sender, "language_code", None))
            )
            data.update(
                settings=self.settings,
                auth_service=AuthService(session, self.settings),
                user_service=UserService(session),
                task_service=TaskService(session),
            )
            try:
                result = await handler(event, data)
                await session.commit()
                return result
            except DomainError as exc:
                await session.rollback()
                if hasattr(event, "answer"):
                    await event.answer(exc.message, parse_mode=None)
                    return None
                raise
            except Exception:
                await session.rollback()
                raise
            finally:
                locale.reset(token)
