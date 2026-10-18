from fastapi import APIRouter

from backend.api.dependencies import CurrentUser, Session
from shared.features.tips.schemas import TipSettingsOut, TipSettingsUpdate
from shared.features.tips.services import TipService

router = APIRouter(prefix="/tips", tags=["tips"])


@router.get("/settings", response_model=TipSettingsOut)
async def settings(user: CurrentUser, session: Session):
    return await TipService(session).own(user.id)


@router.put("/settings", response_model=TipSettingsOut)
async def update_settings(data: TipSettingsUpdate, user: CurrentUser, session: Session):
    return await TipService(session).update(user.id, data)
