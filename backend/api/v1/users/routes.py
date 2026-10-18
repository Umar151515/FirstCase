from fastapi import APIRouter, Query
from sqlalchemy import or_

from backend.api.dependencies import CurrentUser, OptionalUser, Session
from shared.features.common import Page
from shared.features.tips.schemas import TipSettingsOut
from shared.features.tips.services import TipService
from shared.features.users.models import User
from shared.features.users.schemas import ProfileUpdate, PublicUser, UserOut
from shared.features.users.services import UserService

router = APIRouter(prefix="/users", tags=["users"])


@router.get("", response_model=Page[PublicUser])
async def users(
    session: Session,
    q: str = Query(default="", max_length=100),
    city: str | None = None,
    specialization: str | None = None,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    conditions = [User.status == "active"]
    if q:
        conditions.append(
            or_(User.display_name.ilike(f"%{q}%"), User.specialization.ilike(f"%{q}%"))
        )
    if city:
        conditions.append(User.city.ilike(f"%{city}%"))
    if specialization:
        conditions.append(User.specialization.ilike(f"%{specialization}%"))
    service = UserService(session)
    items, total = await service.repository.list(*conditions, offset=offset, limit=limit)
    return {"items": [await service.public(u) for u in items], "total": total}


@router.get("/me", response_model=UserOut)
async def me(user: CurrentUser, session: Session):
    return await UserService(session).own(user)


@router.patch("/me", response_model=UserOut)
async def update_me(data: ProfileUpdate, user: CurrentUser, session: Session):
    return await UserService(session).update(user, data)


@router.get("/{identifier}", response_model=PublicUser)
async def profile(identifier: int, session: Session):
    return await UserService(session).get_public(identifier)


@router.get("/{identifier}/tips", response_model=TipSettingsOut)
async def tips(identifier: int, user: OptionalUser, session: Session):
    return await TipService(session).public(identifier, user.id if user else None)
