from typing import Literal

from fastapi import APIRouter, Query
from pydantic import AwareDatetime

from backend.api.dependencies import CurrentUser, OptionalUser, Session
from shared.core.security import unauthorized
from shared.features.applications.models import Application
from shared.features.applications.schemas import ApplicationCreate, ApplicationOut
from shared.features.applications.services import ApplicationService
from shared.features.common import Page
from shared.features.tasks.models import Category
from shared.features.tasks.repositories import CategoryRepository
from shared.features.tasks.schemas import CategoryOut, TaskCreate, TaskOut, TaskUpdate
from shared.features.tasks.services import TaskService

router = APIRouter(tags=["tasks"])


@router.get("/categories", response_model=Page[CategoryOut])
async def categories(session: Session):
    items, total = await CategoryRepository(session).list(
        Category.active.is_(True), limit=100, order_by=Category.sort_order
    )
    return {"items": items, "total": total}


@router.get("/tasks", response_model=Page[TaskOut])
async def tasks(
    session: Session,
    user: OptionalUser,
    q: str = Query(default="", max_length=100),
    category_id: int | None = None,
    status: Literal["published", "assigned", "completed", "cancelled"] | None = None,
    city: str | None = None,
    sort: Literal["newest", "oldest", "deadline"] = "newest",
    mine: bool = False,
    created_after: AwareDatetime | None = None,
    created_before: AwareDatetime | None = None,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    if mine and not user:
        raise unauthorized("Войдите для просмотра своих задач")
    service = TaskService(session)
    items, total = await service.catalog(
        q,
        category_id,
        status,
        city,
        sort,
        user.id if mine else None,
        offset,
        limit,
        created_after=created_after,
        created_before=created_before,
    )
    return {"items": [await service.view(t) for t in items], "total": total}


@router.post("/tasks", response_model=TaskOut, status_code=201)
async def create_task(data: TaskCreate, user: CurrentUser, session: Session):
    service = TaskService(session)
    return await service.view(await service.create(user.id, data))


@router.get("/tasks/{identifier}", response_model=TaskOut)
async def task(identifier: int, session: Session, user: OptionalUser):
    service = TaskService(session)
    return await service.view(await service.get(identifier, user.id if user else None))


@router.patch("/tasks/{identifier}", response_model=TaskOut)
async def update_task(identifier: int, data: TaskUpdate, user: CurrentUser, session: Session):
    service = TaskService(session)
    return await service.view(await service.update(identifier, user.id, data))


@router.post("/tasks/{identifier}/cancel", response_model=TaskOut)
async def cancel_task(identifier: int, user: CurrentUser, session: Session):
    service = TaskService(session)
    return await service.view(await service.cancel(identifier, user.id))


@router.get("/tasks/{identifier}/applications", response_model=Page[ApplicationOut])
async def applications(
    identifier: int,
    user: CurrentUser,
    session: Session,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    task = await TaskService(session).get(identifier, user.id)
    conditions = [Application.task_id == identifier]
    if task.customer_id != user.id:
        conditions.append(Application.performer_id == user.id)
    service = ApplicationService(session)
    items, total = await service.repository.list(*conditions, offset=offset, limit=limit)
    return {"items": [await service.view(a) for a in items], "total": total}


@router.post("/tasks/{identifier}/applications", response_model=ApplicationOut, status_code=201)
async def apply(identifier: int, data: ApplicationCreate, user: CurrentUser, session: Session):
    service = ApplicationService(session)
    return await service.view(await service.create(identifier, user.id, data))
