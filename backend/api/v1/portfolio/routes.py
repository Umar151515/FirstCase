from fastapi import APIRouter, Query

from backend.api.dependencies import CurrentUser, OptionalUser, Session
from shared.core.security import unauthorized
from shared.features.common import Page
from shared.features.portfolio.models import PortfolioCase
from shared.features.portfolio.schemas import CaseCreate, CaseOut, CaseUpdate, VisibilityUpdate
from shared.features.portfolio.services import PortfolioService

router = APIRouter(prefix="/portfolio", tags=["portfolio"])


@router.get("", response_model=Page[CaseOut])
async def portfolio(
    user: OptionalUser,
    session: Session,
    user_id: int | None = None,
    mine: bool = False,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    if mine and not user:
        raise unauthorized("Войдите для просмотра своих кейсов")
    owner_id = user.id if mine else user_id
    own = user and owner_id == user.id
    conditions = (
        [] if own else [PortfolioCase.visibility != "private", PortfolioCase.is_hidden.is_(False)]
    )
    if owner_id:
        conditions.append(PortfolioCase.owner_id == owner_id)
    service = PortfolioService(session)
    items, total = await service.repository.list(*conditions, offset=offset, limit=limit)
    return {
        "items": [await service.view(c, user.id if user else None) for c in items],
        "total": total,
    }


@router.post("", response_model=CaseOut, status_code=201)
async def create_case(data: CaseCreate, user: CurrentUser, session: Session):
    service = PortfolioService(session)
    return await service.view(await service.create(user.id, data), user.id)


@router.get("/{identifier}", response_model=CaseOut)
async def case(identifier: int, user: OptionalUser, session: Session):
    service = PortfolioService(session)
    return await service.view(
        await service.get(identifier, user.id if user else None), user.id if user else None
    )


@router.patch("/{identifier}", response_model=CaseOut)
async def edit_case(identifier: int, data: CaseUpdate, user: CurrentUser, session: Session):
    service = PortfolioService(session)
    return await service.view(await service.edit(identifier, user.id, data), user.id)


@router.patch("/{identifier}/visibility", response_model=CaseOut)
async def visibility(identifier: int, data: VisibilityUpdate, user: CurrentUser, session: Session):
    service = PortfolioService(session)
    return await service.view(await service.visibility(identifier, user.id, data), user.id)
