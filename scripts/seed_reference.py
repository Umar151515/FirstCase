"""Essential reference data for production; never creates demo identities or tasks."""

import asyncio

from sqlalchemy.dialects.postgresql import insert

from shared.core.database import session_factory
from shared.features.tasks.models import Category

CATEGORIES = (
    ("development", "Разработка"),
    ("design", "Дизайн"),
    ("video", "Видео и монтаж"),
    ("illustration", "Иллюстрация"),
    ("text", "Тексты и SMM"),
    ("data", "Данные и автоматизация"),
)


async def ensure_categories(session) -> None:
    # Preserve existing IDs, custom names and intentional deactivation.
    await session.execute(
        insert(Category)
        .values(
            [
                {"slug": slug, "name": name, "sort_order": order, "active": True}
                for order, (slug, name) in enumerate(CATEGORIES)
            ]
        )
        .on_conflict_do_nothing(index_elements=["slug"])
    )


async def seed_reference() -> None:
    async with session_factory() as session, session.begin():
        await ensure_categories(session)


if __name__ == "__main__":
    asyncio.run(seed_reference())
