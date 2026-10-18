from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from shared.core.database import Base, utcnow


class Review(Base):
    __tablename__ = "reviews"
    __table_args__ = (
        UniqueConstraint("order_id", "author_id"),
        CheckConstraint("rating BETWEEN 1 AND 5", name="rating_range"),
        CheckConstraint("author_id <> recipient_id", name="different_users"),
    )
    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"), index=True)
    author_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    recipient_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    rating: Mapped[int] = mapped_column()
    comment: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
