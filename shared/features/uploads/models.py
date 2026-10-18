from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from shared.core.database import Base, utcnow


class Attachment(Base):
    __tablename__ = "attachments"
    __table_args__ = (CheckConstraint("size > 0", name="positive_size"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    filename: Mapped[str] = mapped_column(String(200))
    mime_type: Mapped[str] = mapped_column(String(100))
    size: Mapped[int] = mapped_column()
    storage_key: Mapped[str] = mapped_column(String(80), unique=True)
    task_id: Mapped[int | None] = mapped_column(ForeignKey("tasks.id"), index=True)
    order_id: Mapped[int | None] = mapped_column(ForeignKey("orders.id"), index=True)
    report_id: Mapped[int | None] = mapped_column(ForeignKey("reports.id"), index=True)
    case_id: Mapped[int | None] = mapped_column(ForeignKey("portfolio_cases.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
