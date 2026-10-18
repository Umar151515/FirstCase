from datetime import datetime

from sqlalchemy import JSON, CheckConstraint, DateTime, ForeignKey, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from shared.core.database import Base, TimestampMixin


class PortfolioCase(TimestampMixin, Base):
    __tablename__ = "portfolio_cases"
    __table_args__ = (
        UniqueConstraint("order_id"),
        CheckConstraint("visibility IN ('private','anonymous','public')", name="valid_visibility"),
        CheckConstraint("NOT verified OR order_id IS NOT NULL", name="verified_source"),
        CheckConstraint(
            "ai_usage IN ('no_ai','consultation','ai_assisted')", name="valid_ai_usage"
        ),
    )
    id: Mapped[int] = mapped_column(primary_key=True)
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    order_id: Mapped[int | None] = mapped_column(ForeignKey("orders.id"))
    title: Mapped[str] = mapped_column(String(150))
    description: Mapped[str] = mapped_column(Text)
    result: Mapped[str] = mapped_column(Text)
    ai_usage: Mapped[str] = mapped_column(String(16), default="no_ai", server_default="no_ai")
    ai_disclosure: Mapped[str] = mapped_column(String(2000), default="", server_default="")
    cover_attachment_id: Mapped[int | None] = mapped_column(
        ForeignKey("attachments.id", use_alter=True, name="fk_portfolio_cases_cover_attachment")
    )
    visibility: Mapped[str] = mapped_column(String(20), default="private", index=True)
    verified: Mapped[bool] = mapped_column(default=False)
    show_customer: Mapped[bool] = mapped_column(default=False)
    category_id: Mapped[int | None] = mapped_column(ForeignKey("categories.id"))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    is_hidden: Mapped[bool] = mapped_column(default=False)


class PortfolioEvidence(Base):
    __tablename__ = "portfolio_evidence"
    __table_args__ = (
        CheckConstraint(
            "(attachment_id IS NOT NULL AND message_id IS NULL) OR (attachment_id IS NULL AND message_id IS NOT NULL)",
            name="one_source",
        ),
    )
    id: Mapped[int] = mapped_column(primary_key=True)
    case_id: Mapped[int] = mapped_column(
        ForeignKey("portfolio_cases.id", ondelete="CASCADE"), index=True
    )
    attachment_id: Mapped[int | None] = mapped_column(ForeignKey("attachments.id"))
    message_id: Mapped[int | None] = mapped_column(ForeignKey("messages.id"))


class PrivacyConsent(TimestampMixin, Base):
    __tablename__ = "privacy_consents"
    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"), unique=True)
    customer_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    allow_identity: Mapped[bool] = mapped_column(default=False)
    attachment_ids: Mapped[list] = mapped_column(JSON, default=list)
    message_ids: Mapped[list] = mapped_column(JSON, default=list)
