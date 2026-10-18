from fastapi import APIRouter, Query

from backend.api.dependencies import CurrentUser, Session
from shared.features.common import Page
from shared.features.reports.models import Report
from shared.features.reports.schemas import ReportCreate, ReportOut
from shared.features.reports.services import ReportService

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("", response_model=Page[ReportOut])
async def reports(
    user: CurrentUser,
    session: Session,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    items, total = await ReportService(session).repository.list(
        Report.reporter_id == user.id, offset=offset, limit=limit
    )
    return {"items": items, "total": total}


@router.post("", response_model=ReportOut, status_code=201)
async def create(data: ReportCreate, user: CurrentUser, session: Session):
    return await ReportService(session).create(user.id, data)


@router.get("/{identifier}", response_model=ReportOut)
async def report(identifier: int, user: CurrentUser, session: Session):
    return await ReportService(session).get(identifier, user)
