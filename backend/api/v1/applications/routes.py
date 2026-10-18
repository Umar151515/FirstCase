from fastapi import APIRouter, Query

from backend.api.dependencies import CurrentUser, Session
from shared.core.exceptions import missing
from shared.features.applications.models import Application
from shared.features.applications.schemas import ApplicationOut
from shared.features.applications.services import ApplicationService
from shared.features.common import Page
from shared.features.orders.schemas import OrderOut
from shared.features.orders.services import OrderService
from shared.features.tasks.repositories import TaskRepository

router = APIRouter(prefix="/applications", tags=["applications"])


@router.get("", response_model=Page[ApplicationOut])
async def applications(
    user: CurrentUser,
    session: Session,
    mine: bool = True,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    service = ApplicationService(session)
    items, total = await service.repository.list(
        Application.performer_id == user.id, offset=offset, limit=limit
    )
    return {"items": [await service.view(a) for a in items], "total": total}


@router.get("/{identifier}", response_model=ApplicationOut)
async def application(identifier: int, user: CurrentUser, session: Session):
    service = ApplicationService(session)
    item = await service.repository.get(identifier)
    task = await TaskRepository(session).get(item.task_id)
    if user.id not in (task.customer_id, item.performer_id):
        raise missing()
    return await service.view(item)


@router.post("/{identifier}/accept", response_model=OrderOut)
async def accept(identifier: int, user: CurrentUser, session: Session):
    return await OrderService(session).view(
        await ApplicationService(session).accept(identifier, user.id)
    )


@router.post("/{identifier}/reject", response_model=ApplicationOut)
async def reject(identifier: int, user: CurrentUser, session: Session):
    service = ApplicationService(session)
    return await service.view(await service.decide(identifier, user.id))


@router.post("/{identifier}/withdraw", response_model=ApplicationOut)
async def withdraw(identifier: int, user: CurrentUser, session: Session):
    service = ApplicationService(session)
    return await service.view(await service.decide(identifier, user.id, withdraw=True))
