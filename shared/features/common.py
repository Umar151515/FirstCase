from collections.abc import Sequence
from typing import Annotated, Any, ClassVar

from pydantic import BaseModel, ConfigDict, HttpUrl, UrlConstraints, model_validator
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from shared.core.database import Base
from shared.core.exceptions import missing


class Schema(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid", str_strip_whitespace=True)


HttpsUrl = Annotated[HttpUrl, UrlConstraints(allowed_schemes=["https"])]


class PatchSchema(Schema):
    nullable_fields: ClassVar[frozenset[str]] = frozenset()

    @model_validator(mode="before")
    @classmethod
    def disallow_explicit_null(cls, value):
        if isinstance(value, dict) and any(
            v is None and k not in cls.nullable_fields for k, v in value.items()
        ):
            raise ValueError("patch_null_forbidden")
        return value


class Page[T](BaseModel):
    items: list[T]
    total: int


class Repository[T: Base]:
    def __init__(self, session: AsyncSession, model: type[T]):
        self.session = session
        self.model = model

    async def get(self, identifier: int, *, lock: bool = False) -> T:
        stmt = select(self.model).where(self.model.id == identifier)
        if lock:
            stmt = stmt.with_for_update().execution_options(populate_existing=True)
        item = await self.session.scalar(stmt)
        if item is None:
            raise missing()
        return item

    async def add(self, **data: Any) -> T:
        instance = self.model(**data)
        self.session.add(instance)
        await self.session.flush()
        return instance

    async def list(
        self, *conditions, offset: int = 0, limit: int = 20, order_by=None
    ) -> tuple[Sequence[T], int]:
        stmt = select(self.model).where(*conditions)
        total = await self.session.scalar(select(func.count()).select_from(stmt.subquery()))
        stmt = stmt.order_by(order_by if order_by is not None else self.model.id.desc())
        items = (await self.session.scalars(stmt.offset(offset).limit(limit))).all()
        return items, total or 0
