from sqlalchemy import JSON, CheckConstraint, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from shared.core.database import Base, TimestampMixin


class Report(TimestampMixin, Base):
    __tablename__ = "reports"
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending','in_review','resolved','rejected')", name="valid_status"
        ),
    )
    id: Mapped[int] = mapped_column(primary_key=True)
    reporter_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    target_type: Mapped[str] = mapped_column(String(30), index=True)
    target_id: Mapped[int] = mapped_column(index=True)
    reason: Mapped[str] = mapped_column(String(40))
    description: Mapped[str] = mapped_column(Text)
    attachment_ids: Mapped[list] = mapped_column(JSON, default=list)
    status: Mapped[str] = mapped_column(String(24), default="pending", index=True)
    moderator_comment: Mapped[str] = mapped_column(Text, default="")
