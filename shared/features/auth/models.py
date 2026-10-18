from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from shared.core.database import Base


class DemoMarker(Base):
    __tablename__ = "demo_markers"
    key: Mapped[str] = mapped_column(String(100), primary_key=True)
    value: Mapped[str] = mapped_column(String(200))
