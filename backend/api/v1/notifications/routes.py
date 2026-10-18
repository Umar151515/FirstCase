from fastapi import APIRouter, Query

from backend.api.dependencies import CurrentUser, Session
from shared.features.common import Page
from shared.features.notifications.models import Notification
from shared.features.notifications.schemas import NotificationOut
from shared.features.notifications.services import NotificationService

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=Page[NotificationOut])
async def notifications(
    user: CurrentUser,
    session: Session,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    items, total = await NotificationService(session).repository.list(
        Notification.user_id == user.id, offset=offset, limit=limit
    )
    return {"items": [NotificationService.view(item) for item in items], "total": total}


@router.post("/{identifier}/read", response_model=NotificationOut)
async def read(identifier: int, user: CurrentUser, session: Session):
    return NotificationService.view(
        await NotificationService(session).mark_read(identifier, user.id)
    )
