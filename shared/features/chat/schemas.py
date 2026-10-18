from datetime import datetime

from pydantic import Field, model_validator

from shared.features.common import Schema
from shared.features.users.schemas import PublicUser


class MessageCreate(Schema):
    text: str = Field(default="", max_length=10000)
    attachment_ids: list[int] = Field(default_factory=list, max_length=10)

    @model_validator(mode="after")
    def nonempty(self):
        if not self.text and not self.attachment_ids:
            raise ValueError("message_or_file_required")
        return self


class MessageOut(Schema):
    id: int
    order_id: int
    author_id: int
    author: PublicUser
    text: str
    attachment_ids: list[int]
    created_at: datetime
