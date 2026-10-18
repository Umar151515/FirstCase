from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from shared.core.database import Base, TimestampMixin


class TipSettings(TimestampMixin, Base):
    __tablename__ = "tip_settings"
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), primary_key=True)
    payment_method: Mapped[str] = mapped_column(String(100), default="")
    qr_attachment_id: Mapped[int | None] = mapped_column(ForeignKey("attachments.id"))
    payment_url: Mapped[str | None] = mapped_column(String(2048))
    enabled: Mapped[bool] = mapped_column(default=False)
    public_consent: Mapped[bool] = mapped_column(default=False)
