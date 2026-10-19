import re
from datetime import datetime
from typing import Literal

from pydantic import Field, field_validator, model_validator

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


class TelegramContact(Schema):
    username: str = Field(min_length=3, max_length=64)

    @field_validator("username")
    @classmethod
    def normalize_username(cls, value):
        value = value.removeprefix("https://t.me/").removeprefix("t.me/").removeprefix("@")
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]{2,31}", value):
            raise ValueError("telegram_username_invalid")
        return value


class TelegramInviteResponse(Schema):
    action: Literal["accept", "decline", "cancel"]
    username: str | None = None

    @model_validator(mode="after")
    def contact_on_accept(self):
        if self.action == "accept":
            self.username = TelegramContact(username=self.username or "").username
        elif self.username is not None:
            raise ValueError("telegram_username_unexpected")
        return self


class TelegramInviteOut(Schema):
    id: int
    order_id: int
    requested_by: int
    status: Literal["pending", "accepted", "declined", "cancelled"]
    my_username: str | None
    peer_username: str | None
    created_at: datetime
    responded_at: datetime | None
