from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from shared.core.database import Base, TimestampMixin


class Category(Base):
    __tablename__ = "categories"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    slug: Mapped[str] = mapped_column(String(100), unique=True)
    sort_order: Mapped[int] = mapped_column(default=0)
    active: Mapped[bool] = mapped_column(default=True)


class Task(TimestampMixin, Base):
    __tablename__ = "tasks"
    __table_args__ = (
        CheckConstraint(
            "ai_policy IN ('no_ai','consultation','ai_allowed')", name="valid_ai_policy"
        ),
        CheckConstraint("max_revisions BETWEEN 0 AND 10", name="max_revisions_range"),
        CheckConstraint("payment_type IN ('free','tips')", name="payment_type"),
        CheckConstraint(
            "status IN ('published','assigned','completed','cancelled')", name="valid_status"
        ),
    )
    id: Mapped[int] = mapped_column(primary_key=True)
    customer_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id"), index=True)
    title: Mapped[str] = mapped_column(String(150))
    description: Mapped[str] = mapped_column(Text)
    expected_result: Mapped[str] = mapped_column(Text)
    deadline: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    max_revisions: Mapped[int] = mapped_column(default=2)
    payment_type: Mapped[str] = mapped_column(String(16), default="tips")
    ai_policy: Mapped[str] = mapped_column(
        String(16), default="ai_allowed", server_default="ai_allowed"
    )
    cover_attachment_id: Mapped[int | None] = mapped_column(
        ForeignKey("attachments.id", use_alter=True, name="fk_tasks_cover_attachment")
    )
    city: Mapped[str] = mapped_column(String(100), default="Бишкек", index=True)
    status: Mapped[str] = mapped_column(String(24), default="published", index=True)
    is_hidden: Mapped[bool] = mapped_column(default=False, index=True)
