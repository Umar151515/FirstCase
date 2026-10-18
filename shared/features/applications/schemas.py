from datetime import datetime

from pydantic import AwareDatetime, Field

from shared.features.common import Schema
from shared.features.users.schemas import PublicUser


class ApplicationCreate(Schema):
    message: str = Field(min_length=10, max_length=4000)
    proposed_deadline: AwareDatetime
    comment: str = Field(default="", max_length=2000)


class ApplicationOut(Schema):
    id: int
    task_id: int
    performer_id: int
    performer: PublicUser
    message: str
    proposed_deadline: datetime
    comment: str
    status: str
    created_at: datetime
