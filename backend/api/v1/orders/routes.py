from typing import Literal

from fastapi import APIRouter, Query
from sqlalchemy import or_

from backend.api.dependencies import CurrentUser, Session
from shared.features.common import Page, Repository
from shared.features.deliverables.schemas import DeliverableOut
from shared.features.deliverables.services import DeliverableService
from shared.features.orders.models import Order, OrderEvent
from shared.features.orders.schemas import EventOut, OrderOut, RevisionRequest, SubmitWork
from shared.features.orders.services import OrderService
from shared.features.portfolio.schemas import ConsentOut, PrivacyConsentUpdate
from shared.features.portfolio.services import PortfolioService

router = APIRouter(prefix="/orders", tags=["orders"])


@router.get("", response_model=Page[OrderOut])
async def orders(
    user: CurrentUser,
    session: Session,
    role: Literal["customer", "performer"] | None = None,
    status: str | None = None,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    conditions = (
        [Order.customer_id == user.id]
        if role == "customer"
        else [Order.performer_id == user.id]
        if role == "performer"
        else [or_(Order.customer_id == user.id, Order.performer_id == user.id)]
    )
    if status:
        conditions.append(Order.status == status)
    service = OrderService(session)
    items, total = await service.repository.list(*conditions, offset=offset, limit=limit)
    return {"items": [await service.view(o) for o in items], "total": total}


@router.get("/{identifier}", response_model=OrderOut)
async def order(identifier: int, user: CurrentUser, session: Session):
    service = OrderService(session)
    return await service.view(await service.participant(identifier, user.id))


@router.post("/{identifier}/start", response_model=OrderOut)
async def start(identifier: int, user: CurrentUser, session: Session):
    service = OrderService(session)
    return await service.view(await service.transition(identifier, user.id, "start"))


@router.post("/{identifier}/submit", response_model=OrderOut)
async def submit(identifier: int, data: SubmitWork, user: CurrentUser, session: Session):
    service = OrderService(session)
    return await service.view(await service.submit(identifier, user.id, data))


@router.post("/{identifier}/accept", response_model=OrderOut)
async def accept(identifier: int, user: CurrentUser, session: Session):
    service = OrderService(session)
    return await service.view(await service.transition(identifier, user.id, "accept"))


@router.post("/{identifier}/request-revision", response_model=OrderOut)
async def revision(identifier: int, data: RevisionRequest, user: CurrentUser, session: Session):
    service = OrderService(session)
    return await service.view(
        await service.transition(identifier, user.id, "request_revision", data.reason)
    )


@router.post("/{identifier}/cancel", response_model=OrderOut)
async def cancel(identifier: int, user: CurrentUser, session: Session):
    service = OrderService(session)
    return await service.view(await service.transition(identifier, user.id, "cancel"))


@router.post("/{identifier}/dispute", response_model=OrderOut)
async def dispute(identifier: int, user: CurrentUser, session: Session):
    service = OrderService(session)
    return await service.view(await service.transition(identifier, user.id, "dispute"))


@router.get("/{identifier}/deliverables", response_model=Page[DeliverableOut])
async def deliverables(
    identifier: int,
    user: CurrentUser,
    session: Session,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    items, total = await DeliverableService(session).history(identifier, user.id, offset, limit)
    return {"items": items, "total": total}


@router.get("/{identifier}/events", response_model=Page[EventOut])
async def events(
    identifier: int,
    user: CurrentUser,
    session: Session,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    await OrderService(session).participant(identifier, user.id)
    items, total = await Repository(session, OrderEvent).list(
        OrderEvent.order_id == identifier, order_by=OrderEvent.id, offset=offset, limit=limit
    )
    return {"items": items, "total": total}


@router.put("/{identifier}/privacy-consent", response_model=ConsentOut)
async def privacy_consent(
    identifier: int, data: PrivacyConsentUpdate, user: CurrentUser, session: Session
):
    return await PortfolioService(session).set_consent(identifier, user.id, data)
