from shared.features.common import Schema


class AttachmentOut(Schema):
    id: int
    filename: str
    mime_type: str
    size: int
    url: str
