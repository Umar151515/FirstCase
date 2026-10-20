"""One entrypoint for migration, optional demo bootstrap and serving the API."""

import argparse
import asyncio
import os
import subprocess
import sys

from shared.core.config import get_settings


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reload", action="store_true")
    args = parser.parse_args()
    settings = get_settings()  # Fail before touching the DB if secrets are invalid.
    if settings.app_mode == "production" and args.reload:
        parser.error("Hot reload is unavailable in production")
    subprocess.run(["alembic", "upgrade", "head"], check=True)
    if settings.app_mode == "demo":
        from scripts.seed_demo import seed_demo

        asyncio.run(seed_demo())
    else:
        from scripts.seed_reference import seed_reference

        asyncio.run(seed_reference())
    command = [
        sys.executable,
        "-m",
        "uvicorn",
        "backend.main:app",
        "--host",
        "0.0.0.0",
        "--port",
        "8000",
        "--proxy-headers",
    ]
    if args.reload:
        command += ["--reload", "--reload-dir", "backend", "--reload-dir", "shared"]
    if settings.app_mode == "production":
        # Production API has no published port; only the internal reverse proxy reaches it.
        command += ["--forwarded-allow-ips", "*"]
    os.execv(sys.executable, command)


if __name__ == "__main__":
    main()
