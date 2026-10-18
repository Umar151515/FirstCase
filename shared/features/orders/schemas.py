from datetime import datetime

from pydantic import Field

from shared.features.ai import AiPolicy, AiUsage
from shared.features.common import HttpsUrl, Schema
from shared.features.tasks.schemas import TaskOut
from shared.features.users.schemas import PublicUser


class OrderOut(Schema):
    id: int
    order_id: int
    task_id: int
    task: TaskOut
    customer_id: int
    performer_id: int
    customer: PublicUser
    performer: PublicUser
    status: str
    revisions_used: int
    max_revisions: int
    ai_policy: AiPolicy
    created_at: datetime
    accepted_at: datetime | None
    completed_at: datetime | None


class SubmitWork(Schema):
    ai_usage: AiUsage = "no_ai"
    ai_disclosure: str = Field(default="", max_length=2000)
    description: str = Field(min_length=10, max_length=10000)
    links: list[HttpsUrl] = Field(default_factory=list, max_length=10)
    attachment_ids: list[int] = Field(default_factory=list, max_length=20)


class RevisionRequest(Schema):
    reason: str = Field(min_length=5, max_length=4000)


class EventOut(Schema):
    id: int
    order_id: int
    actor_id: int
    type: str
    details: dict
    created_at: datetime
