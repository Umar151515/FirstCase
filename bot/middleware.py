"""aiogram dependency assembly; FastAPI Depends is deliberately not involved."""

from collections.abc import Awaitable, Callable
from typing import Any

from aiogram import BaseMiddleware
from aiogram.types import TelegramObject
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from shared.core.config import Settings
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
            except Exception:
                await session.rollback()
                raise
