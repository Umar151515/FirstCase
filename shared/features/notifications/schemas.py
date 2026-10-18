from datetime import datetime

from shared.features.common import Schema


class NotificationOut(Schema):
    id: int
    type: str
    title: str
    body: str
    link: str
    read_at: datetime | None
    created_at: datetime
