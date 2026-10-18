from datetime import datetime

from shared.features.ai import AiUsage
from shared.features.common import Schema


class DeliverableOut(Schema):
    id: int
    order_id: int
    performer_id: int
    description: str
    ai_usage: AiUsage
    ai_disclosure: str
    links: list[str]
    attachment_ids: list[int]
    version: int
    created_at: datetime
