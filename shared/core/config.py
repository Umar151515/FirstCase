from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

DEMO_SECRET = "firstcase-local-demo-secret-change-in-production-4d924ef7"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", extra="ignore", case_sensitive=False, hide_input_in_errors=True
    )

    app_mode: Literal["demo", "production"] = "demo"
    debug: bool = False
    database_url: str = (
        "postgresql+asyncpg://firstcase:firstcase_demo_local@localhost:5543/firstcase_demo"
    )
    test_database_url: str = (
        "postgresql+asyncpg://firstcase_test:firstcase_test_local@localhost:5544/firstcase_test"
    )
    telegram_bot_token: str = Field(default="", repr=False)
    telegram_bot_username: str = ""
    jwt_secret: str = Field(default=DEMO_SECRET, repr=False)
    jwt_expire_minutes: int = Field(default=120, ge=5, le=1440)
    telegram_auth_max_age: int = Field(default=3600, ge=60, le=86400)
    admin_telegram_ids: str = ""
    public_webapp_url: str = "http://localhost:8080"
    api_public_url: str = "http://localhost:8000"
    upload_dir: Path = Path("storage/uploads")
    max_upload_size_mb: int = Field(default=10, ge=1, le=100)
    cors_origins: str = "http://localhost:8080,http://127.0.0.1:8080"
    auth_rate_limit: int = Field(default=30, ge=1)
    write_rate_limit: int = Field(default=120, ge=1)

    @field_validator("debug", mode="before")
    @classmethod
    def host_debug_mode(cls, value):
        return False if value == "release" else value

    @field_validator("database_url", "test_database_url")
    @classmethod
    def postgres_only(cls, value: str) -> str:
        if not value.startswith("postgresql+asyncpg://"):
            raise ValueError("Use a PostgreSQL asyncpg URL")
        return value

    @field_validator("admin_telegram_ids")
    @classmethod
    def valid_admin_ids(cls, value: str) -> str:
        if any(
            not item.strip().isdigit() or int(item.strip()) <= 0
            for item in value.split(",")
            if item.strip()
        ):
            raise ValueError(
                "ADMIN_TELEGRAM_IDS must contain positive comma-separated Telegram IDs"
            )
        return value

    @model_validator(mode="after")
    def safe_production(self):
        if self.app_mode == "production":
            if not self.telegram_bot_token or ":" not in self.telegram_bot_token:
                raise ValueError("Production requires TELEGRAM_BOT_TOKEN")
            if len(self.jwt_secret) < 32 or self.jwt_secret == DEMO_SECRET:
                raise ValueError(
                    "Production requires an independent JWT_SECRET of at least 32 characters"
                )
            if self.debug:
                raise ValueError("DEBUG must be false in production")
            if not self.public_webapp_url.startswith("https://"):
                raise ValueError("Production PUBLIC_WEBAPP_URL must use HTTPS")
            if not self.origins or "*" in self.origins:
                raise ValueError("Production CORS_ORIGINS must list explicit origins")
            if "demo" in self.database_url.rsplit("/", 1)[-1].lower():
                raise ValueError("Production must not use the demonstration database")
        return self

    @property
    def origins(self) -> list[str]:
        return [v.strip() for v in self.cors_origins.split(",") if v.strip()]

    @property
    def admin_ids(self) -> set[int]:
        return {int(v.strip()) for v in self.admin_telegram_ids.split(",") if v.strip()}


@lru_cache
def get_settings() -> Settings:
    return Settings()
