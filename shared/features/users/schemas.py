from datetime import datetime
from typing import Literal

from pydantic import Field, field_validator

from shared.features.common import HttpsUrl, PatchSchema, Schema


class PublicUser(Schema):
    id: int
    display_name: str
    avatar_url: str | None
    bio: str
    specialization: str
    skills: list[str]
    city: str
    work_links: list[str]
    rating: float = 0
    review_count: int = 0
    completed_orders: int = 0
    verified_cases: int = 0
    created_at: datetime


class UserOut(PublicUser):
    telegram_id: int | None
    username: str | None
    role: Literal["user", "admin"]
    status: Literal["active", "blocked"]
    is_demo: bool
    onboarding_completed: bool


class ProfileUpdate(PatchSchema):
    display_name: str | None = Field(default=None, min_length=2, max_length=100)
    bio: str | None = Field(default=None, max_length=2000)
    specialization: str | None = Field(default=None, max_length=100)
    skills: list[str] | None = Field(default=None, max_length=20)
    city: str | None = Field(default=None, max_length=100)
    work_links: list[HttpsUrl] | None = Field(default=None, max_length=10)
    onboarding_completed: bool | None = None

    @field_validator("skills")
    @classmethod
    def valid_skills(cls, value):
        if value is not None and any(not s.strip() or len(s) > 60 for s in value):
            raise ValueError("Название навыка должно содержать 1–60 символов")
        return value
