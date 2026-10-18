from datetime import datetime

from shared.features.common import Schema


class DeliverableOut(Schema):
    id: int
    order_id: int
    performer_id: int
    description: str
    links: list[str]
    attachment_ids: list[int]
    version: int
    created_at: datetime
