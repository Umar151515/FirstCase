from sqlalchemy import JSON, BigInteger, CheckConstraint, String
from sqlalchemy.orm import Mapped, mapped_column

from shared.core.database import Base, TimestampMixin


class User(TimestampMixin, Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint("role IN ('user','admin')", name="valid_role"),
        CheckConstraint("status IN ('active','blocked')", name="valid_status"),
    )
    id: Mapped[int] = mapped_column(primary_key=True)
    telegram_id: Mapped[int | None] = mapped_column(BigInteger, unique=True)
    username: Mapped[str | None] = mapped_column(String(64))
    display_name: Mapped[str] = mapped_column(String(100))
    avatar_url: Mapped[str | None] = mapped_column(String(2048))
    bio: Mapped[str] = mapped_column(String(2000), default="")
    specialization: Mapped[str] = mapped_column(String(100), default="")
    skills: Mapped[list] = mapped_column(JSON, default=list)
    city: Mapped[str] = mapped_column(String(100), default="Бишкек", index=True)
    work_links: Mapped[list] = mapped_column(JSON, default=list)
    role: Mapped[str] = mapped_column(String(20), default="user")
    status: Mapped[str] = mapped_column(String(20), default="active", index=True)
    is_demo: Mapped[bool] = mapped_column(default=False, index=True)
    onboarding_completed: Mapped[bool] = mapped_column(default=False)
