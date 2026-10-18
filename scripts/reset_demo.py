"""Reset only a marked, isolated demo DB; never drops schemas or whole databases."""

import argparse
import asyncio

from sqlalchemy import select, text

from scripts.db_safety import ADVISORY_LOCK, DEMO_DATABASE, SEED_KEY, check_demo_database
from scripts.seed_demo import seed_demo
from shared.core.config import get_settings
from shared.core.database import Base, session_factory
from shared.models import Attachment, DemoMarker


async def reset_demo(confirmation: str) -> None:
    if confirmation != DEMO_DATABASE:
        raise RuntimeError(f"Pass --confirm {DEMO_DATABASE} to reset this demo")
    upload_root = get_settings().upload_dir.resolve()
    async with session_factory() as session, session.begin():
        await session.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": ADVISORY_LOCK})
        await check_demo_database(session, require_marker=True)
        keys = list(await session.scalars(select(Attachment.storage_key)))
        tables = [
            table for table in Base.metadata.sorted_tables if table.name != DemoMarker.__tablename__
        ]
        quoted = ", ".join(f'"{table.name}"' for table in tables)
        await session.execute(text(f"TRUNCATE TABLE {quoted} RESTART IDENTITY CASCADE"))
        marker = await session.get(DemoMarker, SEED_KEY)
        if marker:
            await session.delete(marker)
    # Delete only the exact DB-owned files, after the successful transaction.
    for key in keys:
        path = (upload_root / key).resolve()
        if path.parent == upload_root and path.is_file():
            path.unlink()
    await seed_demo()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--confirm", required=True, choices=[DEMO_DATABASE])
    args = parser.parse_args()
    asyncio.run(reset_demo(args.confirm))


if __name__ == "__main__":
    main()
