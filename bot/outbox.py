"""Durable Telegram delivery with leases and retry; no business transactions here."""

import asyncio
import logging
from dataclasses import dataclass
from datetime import timedelta
from pathlib import Path
from tempfile import gettempdir

from aiogram import Bot
from aiogram.exceptions import TelegramForbiddenError, TelegramRetryAfter
from sqlalchemy import or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from bot.keyboards.webapp import open_app
from shared.core.config import Settings
from shared.core.database import utcnow
from shared.core.i18n import translate
from shared.models import Notification, User

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class PendingDelivery:
    id: int
    telegram_id: int
    title: str
    body: str
    link: str
    attempts: int
    language: str = "ru"


async def claim_pending(factory: async_sessionmaker[AsyncSession]) -> list[PendingDelivery]:
    """Commit a short lease before touching the external Telegram API."""
    now = utcnow()
    async with factory() as session, session.begin():
        rows = (
            await session.execute(
                select(Notification, User.telegram_id, User.language)
                .join(User, User.id == Notification.user_id)
                .where(
                    Notification.delivered_at.is_(None),
                    Notification.next_attempt_at <= now,
                    or_(Notification.claim_until.is_(None), Notification.claim_until < now),
                    User.is_demo.is_(False),
                    User.status == "active",
                    User.telegram_id > 0,
                )
                .order_by(Notification.id)
                .limit(10)
                .with_for_update(of=Notification, skip_locked=True)
            )
        ).all()
        pending = []
        for notification, telegram_id, language in rows:
            notification.claim_until = now + timedelta(minutes=5)
            notification.attempts += 1
            pending.append(
                PendingDelivery(
                    notification.id,
                    telegram_id,
                    translate(notification.title, language),
                    notification.body,
                    notification.link,
                    notification.attempts,
                    language,
                )
            )
        return pending


async def record_delivery(
    factory: async_sessionmaker[AsyncSession], delivery: PendingDelivery, *, error: Exception | None
) -> None:
    now = utcnow()
    values = {"claim_until": None}
    if error is None:
        values.update(delivered_at=now, last_error=None)
    else:
        delay = min(3600, 15 * 2 ** min(delivery.attempts, 8))
        if isinstance(error, TelegramRetryAfter):
            delay = max(delay, error.retry_after)
        if isinstance(error, TelegramForbiddenError):
            delay = 86400  # The user may unblock the bot later; retain the notification.
        values.update(
            next_attempt_at=now + timedelta(seconds=delay), last_error=type(error).__name__
        )
    async with factory() as session, session.begin():
        await session.execute(
            update(Notification).where(Notification.id == delivery.id).values(**values)
        )


async def deliver_batch(
    bot: Bot, factory: async_sessionmaker[AsyncSession], settings: Settings
) -> int:
    pending = await claim_pending(factory)
    for delivery in pending:
        error = None
        try:
            await bot.send_message(
                chat_id=delivery.telegram_id,
                text=f"{delivery.title}\n\n{delivery.body}"[:4000],
                parse_mode=None,
                reply_markup=open_app(
                    settings.public_webapp_url,
                    delivery.link,
                    translate("bot.open_in_app", delivery.language),
                ),
            )
        except Exception as exc:
            error = exc
            # Never log token-bearing Telegram URLs or private message bodies.
            logger.warning(
                "telegram_delivery_failed notification_id=%s error_type=%s",
                delivery.id,
                type(exc).__name__,
            )
        await record_delivery(factory, delivery, error=error)
    return len(pending)


async def delivery_loop(
    bot: Bot, factory: async_sessionmaker[AsyncSession], settings: Settings
) -> None:
    while True:
        try:
            delivered = await deliver_batch(bot, factory, settings)
            (Path(gettempdir()) / "firstcase-bot-heartbeat").touch()
            await asyncio.sleep(1 if delivered else 5)
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            logger.error("outbox_cycle_failed error_type=%s", type(exc).__name__)
            await asyncio.sleep(5)
