from typing import Literal

from fastapi import APIRouter, Query
from fastapi.responses import FileResponse
from sqlalchemy import or_

from backend.api.dependencies import AdminUser, Config, Session
from shared.core.exceptions import missing
from shared.features.chat.schemas import MessageOut
from shared.features.common import Page, Repository, Schema
from shared.features.moderation.schemas import (
    EvidenceAccess,
    ModerationActionOut,
    StatsOut,
    TaskModeration,
    UserModeration,
)
from shared.features.moderation.services import ModerationService
from shared.features.orders.models import Order, OrderEvent
from shared.features.orders.schemas import EventOut, OrderOut
from shared.features.orders.services import OrderService
from shared.features.portfolio.schemas import CaseOut
from shared.features.reports.models import Report
from shared.features.reports.repositories import ReportRepository
from shared.features.reports.schemas import ReportOut, ReportUpdate
from shared.features.tasks.schemas import TaskOut
from shared.features.tasks.services import TaskService
from shared.features.uploads.repositories import AttachmentRepository
from shared.features.uploads.schemas import AttachmentOut
from shared.features.uploads.services import UploadService
from shared.features.users.models import User
from shared.features.users.schemas import UserOut
from shared.features.users.services import UserService

router = APIRouter(prefix="/admin", tags=["administration"])


class EvidenceOut(Schema):
    report: ReportOut
    order: OrderOut | None
    messages: list[MessageOut]
    attachments: list[AttachmentOut]
    portfolio: CaseOut | None


class DisputeResolution(EvidenceAccess):
    action: Literal["cancel", "resume"]


@router.get("/stats", response_model=StatsOut)
async def stats(admin: AdminUser, session: Session):
    return await ModerationService(session).repository.stats()


@router.get("/users", response_model=Page[UserOut])
async def users(
    admin: AdminUser,
    session: Session,
    q: str = Query(default="", max_length=100),
    status: str | None = None,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    service = UserService(session)
    conditions = []
    if q:
        conditions.append(
            or_(User.display_name.ilike(f"%{q}%"), User.specialization.ilike(f"%{q}%"))
        )
    if status:
        conditions.append(User.status == status)
    items, total = await service.repository.list(*conditions, offset=offset, limit=limit)
    return {"items": [await service.own(u) for u in items], "total": total}


@router.patch("/users/{identifier}", response_model=UserOut)
async def moderate_user(identifier: int, data: UserModeration, admin: AdminUser, session: Session):
    return await UserService(session).own(
        await ModerationService(session).user(admin.id, identifier, data)
    )


@router.get("/tasks", response_model=Page[TaskOut])
async def tasks(
    admin: AdminUser,
    session: Session,
    status: str | None = None,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    service = TaskService(session)
    items, total = await service.catalog(status=status, offset=offset, limit=limit, admin=True)
    return {"items": [await service.view(t) for t in items], "total": total}


@router.patch("/tasks/{identifier}", response_model=TaskOut)
async def moderate_task(identifier: int, data: TaskModeration, admin: AdminUser, session: Session):
    return await TaskService(session).view(
        await ModerationService(session).task(admin.id, identifier, data)
    )


@router.get("/orders", response_model=Page[OrderOut])
async def orders(
    admin: AdminUser,
    session: Session,
    status: str | None = None,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    service = OrderService(session)
    items, total = await service.repository.list(
        *([Order.status == status] if status else []), offset=offset, limit=limit
    )
    return {"items": [await service.view(o) for o in items], "total": total}


@router.post("/orders/{identifier}/resolve-dispute", response_model=OrderOut)
async def resolve_dispute(
    identifier: int, data: DisputeResolution, admin: AdminUser, session: Session
):
    return await OrderService(session).view(
        await ModerationService(session).resolve_dispute(
            admin.id, identifier, data.action, data.reason
        )
    )


@router.get("/orders/{identifier}/events", response_model=Page[EventOut])
async def order_events(
    identifier: int,
    admin: AdminUser,
    session: Session,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    await OrderService(session).repository.get(identifier)
    items, total = await Repository(session, OrderEvent).list(
        OrderEvent.order_id == identifier, order_by=OrderEvent.id, offset=offset, limit=limit
    )
    return {"items": items, "total": total}


@router.get("/reports", response_model=Page[ReportOut])
async def reports(
    admin: AdminUser,
    session: Session,
    status: str | None = None,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    items, total = await ReportRepository(session).list(
        *([Report.status == status] if status else []), offset=offset, limit=limit
    )
    return {"items": items, "total": total}


@router.patch("/reports/{identifier}", response_model=ReportOut)
async def report_update(identifier: int, data: ReportUpdate, admin: AdminUser, session: Session):
    return await ModerationService(session).report(admin.id, identifier, data)


@router.post("/reports/{identifier}/evidence-access", response_model=EvidenceOut)
async def evidence(identifier: int, data: EvidenceAccess, admin: AdminUser, session: Session):
    result = await ModerationService(session).evidence_access(admin.id, identifier, data.reason)
    result["attachments"] = [
        a.model_copy(update={"url": f"/api/v1/admin/reports/{identifier}/attachments/{a.id}"})
        for a in result["attachments"]
    ]
    return result


@router.get("/reports/{identifier}/attachments/{attachment_id}", response_class=FileResponse)
async def evidence_download(
    identifier: int,
    attachment_id: int,
    admin: AdminUser,
    session: Session,
    settings: Config,
    reason: str = Query(default="report_evidence_view", min_length=10, max_length=4000),
):
    result = await ModerationService(session).evidence_access(admin.id, identifier, reason)
    if attachment_id not in [a.id for a in result["attachments"]]:
        raise missing()
    file = await AttachmentRepository(session).get(attachment_id)
    path = UploadService(session, settings).storage.path(file.storage_key)
    if not path.is_file():
        raise missing()
    return FileResponse(
        path,
        filename=file.filename,
        media_type=file.mime_type,
        headers={"Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff"},
    )


@router.get("/moderation-actions", response_model=Page[ModerationActionOut])
async def actions(
    admin: AdminUser,
    session: Session,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    items, total = await ModerationService(session).repository.list(offset=offset, limit=limit)
    return {"items": items, "total": total}
