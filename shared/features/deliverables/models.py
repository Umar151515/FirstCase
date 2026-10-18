from datetime import datetime

from sqlalchemy import JSON, CheckConstraint, DateTime, ForeignKey, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from shared.core.database import Base, utcnow


class Deliverable(Base):
    __tablename__ = "deliverables"
    __table_args__ = (
        UniqueConstraint("order_id", "version"),
        CheckConstraint(
            "ai_usage IN ('no_ai','consultation','ai_assisted')", name="valid_ai_usage"
        ),
    )
    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"), index=True)
    performer_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    description: Mapped[str] = mapped_column(Text)
    ai_usage: Mapped[str] = mapped_column(String(16), default="no_ai", server_default="no_ai")
    ai_disclosure: Mapped[str] = mapped_column(String(2000), default="", server_default="")
    links: Mapped[list] = mapped_column(JSON, default=list)
    attachment_ids: Mapped[list] = mapped_column(JSON, default=list)
    version: Mapped[int] = mapped_column()
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
