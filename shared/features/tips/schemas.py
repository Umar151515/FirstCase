from pydantic import Field

from shared.features.common import HttpsUrl, Schema
from shared.features.uploads.schemas import AttachmentOut


class TipSettingsUpdate(Schema):
    payment_method: str = Field(default="", max_length=100)
    qr_attachment_id: int | None = Field(default=None, gt=0)
    payment_url: HttpsUrl | None = Field(default=None, max_length=2048)
    enabled: bool = False
    public_consent: bool = False


class TipSettingsOut(Schema):
    user_id: int
    payment_method: str
    qr_attachment_id: int | None
    payment_url: str | None
    enabled: bool
    public_consent: bool
    qr: AttachmentOut | None = None
