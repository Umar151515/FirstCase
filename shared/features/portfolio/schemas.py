from datetime import datetime
from typing import Literal

from pydantic import Field

from shared.features.common import PatchSchema, Schema
from shared.features.tasks.schemas import CategoryOut
from shared.features.uploads.schemas import AttachmentOut
from shared.features.users.schemas import PublicUser

Visibility = Literal["private", "anonymous", "public"]


class VisibilityUpdate(Schema):
    visibility: Visibility
    show_customer: bool = False
    attachment_ids: list[int] = Field(default_factory=list, max_length=20)
    message_ids: list[int] = Field(default_factory=list, max_length=20)


class CaseCreate(VisibilityUpdate):
    order_id: int | None = Field(default=None, gt=0)
    title: str = Field(min_length=5, max_length=150)
    description: str = Field(min_length=10, max_length=10000)
    result: str = Field(min_length=5, max_length=10000)


class CaseUpdate(PatchSchema):
    title: str | None = Field(default=None, min_length=5, max_length=150)
    description: str | None = Field(default=None, min_length=10, max_length=10000)
    result: str | None = Field(default=None, min_length=5, max_length=10000)


class PrivacyConsentUpdate(Schema):
    allow_identity: bool = False
    attachment_ids: list[int] = Field(default_factory=list, max_length=50)
    message_ids: list[int] = Field(default_factory=list, max_length=50)


class ConsentOut(Schema):
    order_id: int
    allow_identity: bool
    attachment_ids: list[int]
    message_ids: list[int]
    updated_at: datetime


class SafeReview(Schema):
    rating: int
    comment: str


class SafeMessage(Schema):
    text: str
    created_at: datetime


class EvidenceOut(Schema):
    attachments: list[AttachmentOut] = Field(default_factory=list)
    messages: list[SafeMessage] = Field(default_factory=list)


class CaseOut(Schema):
    id: int
    owner_id: int
    title: str
    description: str
    result: str
    visibility: str
    verified: bool
    category: CategoryOut | None
    completed_at: datetime | None
    customer: PublicUser | None
    review: SafeReview | None
    evidence: EvidenceOut
    created_at: datetime
