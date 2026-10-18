from datetime import datetime
from typing import Literal

from pydantic import Field

from shared.features.common import Schema

ReportStatus = Literal["pending", "in_review", "resolved", "rejected"]


class ReportCreate(Schema):
    target_type: Literal["user", "task", "message", "portfolio", "review", "order"]
    target_id: int = Field(gt=0)
    reason: Literal[
        "spam",
        "fraud",
        "abuse",
        "prohibited_content",
        "agreement_violation",
        "rating_manipulation",
        "other",
    ]
    description: str = Field(min_length=10, max_length=10000)
    attachment_ids: list[int] = Field(default_factory=list, max_length=10)


class ReportUpdate(Schema):
    status: ReportStatus
    moderator_comment: str = Field(min_length=5, max_length=4000)


class ReportOut(Schema):
    id: int
    reporter_id: int
    target_type: str
    target_id: int
    reason: str
    description: str
    attachment_ids: list[int]
    status: str
    moderator_comment: str
    created_at: datetime
    updated_at: datetime
