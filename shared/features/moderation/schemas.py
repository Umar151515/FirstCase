from datetime import datetime
from typing import Literal

from pydantic import Field

from shared.features.common import Schema


class UserModeration(Schema):
    status: Literal["active", "blocked"]
    reason: str = Field(min_length=5, max_length=4000)


class TaskModeration(Schema):
    is_hidden: bool
    reason: str = Field(min_length=5, max_length=4000)


class EvidenceAccess(Schema):
    reason: str = Field(min_length=10, max_length=4000)


class ModerationActionOut(Schema):
    id: int
    admin_id: int
    target_type: str
    target_id: int
    action: str
    reason: str
    created_at: datetime


class StatsOut(Schema):
    users: int
    active_tasks: int
    completed_orders: int
    applications: int
    reviews: int
    verified_cases: int
    open_reports: int
