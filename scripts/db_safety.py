"""Explicit safeguards shared by destructive demo operator commands."""

from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from shared.core.config import get_settings
from shared.models import DemoMarker, User

DEMO_DATABASE = "firstcase_demo"
PURPOSE_KEY = "firstcase.database-purpose"
PURPOSE_VALUE = "firstcase-demo-only-v1"
SEED_KEY = "firstcase.demo.seed"
SEED_VERSION = "2026-10-v1"
ADVISORY_LOCK = 392840116


async def check_demo_database(session: AsyncSession, *, require_marker: bool) -> None:
    settings = get_settings()
    if settings.app_mode != "demo":
        raise RuntimeError("Demo seed/reset is forbidden outside APP_MODE=demo")
    database = await session.scalar(text("SELECT current_database()"))
    if database != DEMO_DATABASE:
        raise RuntimeError(f"Demo operations require the isolated database {DEMO_DATABASE!r}")
    marker = await session.get(DemoMarker, PURPOSE_KEY)
    if marker is None:
        if require_marker:
            raise RuntimeError("Reset refused: this database has no demo ownership marker")
        existing_users = await session.scalar(select(func.count()).select_from(User))
        if existing_users:
            raise RuntimeError("Seed refused: an unmarked database already contains users")
        session.add(DemoMarker(key=PURPOSE_KEY, value=PURPOSE_VALUE))
        await session.flush()
    elif marker.value != PURPOSE_VALUE:
        raise RuntimeError("Demo operation refused: database purpose marker does not match")
    real_users = await session.scalar(select(func.count()).select_from(User).where(~User.is_demo))
    if real_users:
        raise RuntimeError("Demo operation refused: this database contains non-demo identities")
