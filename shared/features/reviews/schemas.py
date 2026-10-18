from datetime import datetime

from pydantic import Field

from shared.features.common import Schema


class ReviewCreate(Schema):
    rating: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=4000)


class ReviewOut(Schema):
    id: int
    order_id: int
    author_id: int
    recipient_id: int
    rating: int
    comment: str
    created_at: datetime
