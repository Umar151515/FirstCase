from datetime import datetime
from typing import Literal

from pydantic import AwareDatetime, Field

from shared.features.common import PatchSchema, Schema
from shared.features.users.schemas import PublicUser


class CategoryOut(Schema):
    id: int
    name: str
    slug: str
    sort_order: int


class TaskCreate(Schema):
    category_id: int = Field(gt=0)
    title: str = Field(min_length=5, max_length=150)
    description: str = Field(min_length=20, max_length=10000)
    expected_result: str = Field(min_length=5, max_length=5000)
    deadline: AwareDatetime
    max_revisions: int = Field(default=2, ge=0, le=10)
    payment_type: Literal["free", "tips"] = "tips"
    city: str = Field(default="Бишкек", max_length=100)
    attachment_ids: list[int] = Field(default_factory=list, max_length=10)


class TaskUpdate(PatchSchema):
    category_id: int | None = Field(default=None, gt=0)
    title: str | None = Field(default=None, min_length=5, max_length=150)
    description: str | None = Field(default=None, min_length=20, max_length=10000)
    expected_result: str | None = Field(default=None, min_length=5, max_length=5000)
    deadline: AwareDatetime | None = None
    max_revisions: int | None = Field(default=None, ge=0, le=10)
    payment_type: Literal["free", "tips"] | None = None
    city: str | None = Field(default=None, max_length=100)
    attachment_ids: list[int] | None = Field(default=None, max_length=10)


class TaskOut(Schema):
    id: int
    customer_id: int
    customer: PublicUser
    category_id: int
    category: CategoryOut
    title: str
    description: str
    expected_result: str
    deadline: datetime
    max_revisions: int
    payment_type: str
    city: str
    status: str
    is_hidden: bool
    application_count: int
    attachment_ids: list[int]
    created_at: datetime
    updated_at: datetime
