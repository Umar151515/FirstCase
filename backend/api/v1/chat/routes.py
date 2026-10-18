from fastapi import APIRouter, Query

from backend.api.dependencies import CurrentUser, Session
from shared.features.chat.schemas import MessageCreate, MessageOut
from shared.features.chat.services import ChatService
from shared.features.common import Page

router = APIRouter(tags=["chat"])


@router.get("/orders/{identifier}/messages", response_model=Page[MessageOut])
async def messages(
    identifier: int,
    user: CurrentUser,
    session: Session,
    after_id: int | None = Query(default=None, ge=0),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    service = ChatService(session)
    items, total = await service.history(identifier, user.id, after_id, offset, limit)
    return {"items": [await service.view(m) for m in items], "total": total}


@router.post("/orders/{identifier}/messages", response_model=MessageOut, status_code=201)
async def send(identifier: int, data: MessageCreate, user: CurrentUser, session: Session):
    service = ChatService(session)
    return await service.view(await service.send(identifier, user.id, data))
