from fastapi import APIRouter, Query

from backend.api.dependencies import CurrentUser, Session
from shared.features.chat.schemas import (
    MessageCreate,
    MessageOut,
    TelegramContact,
    TelegramInviteOut,
    TelegramInviteResponse,
)
from shared.features.chat.services import ChatService
from shared.features.chat.telegram import TelegramChatService
from shared.features.common import Page

router = APIRouter(tags=["chat"])


@router.get("/orders/{identifier}/messages", response_model=Page[MessageOut])
async def messages(
    identifier: int,
    user: CurrentUser,
    session: Session,
    after_id: int | None = Query(default=None, ge=0),
    before_id: int | None = Query(default=None, gt=0),
    latest: bool = False,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    service = ChatService(session)
    items, total = await service.history(
        identifier, user.id, after_id, offset, limit, before_id=before_id, latest=latest
    )
    return {"items": [await service.view(m) for m in items], "total": total}


@router.post("/orders/{identifier}/messages", response_model=MessageOut, status_code=201)
async def send(identifier: int, data: MessageCreate, user: CurrentUser, session: Session):
    service = ChatService(session)
    return await service.view(await service.send(identifier, user.id, data))


@router.get("/orders/{identifier}/telegram", response_model=TelegramInviteOut | None)
async def telegram_state(identifier: int, user: CurrentUser, session: Session):
    return await TelegramChatService(session).get(identifier, user.id)


@router.post("/orders/{identifier}/telegram", response_model=TelegramInviteOut, status_code=201)
async def propose_telegram(
    identifier: int, data: TelegramContact, user: CurrentUser, session: Session
):
    return await TelegramChatService(session).propose(identifier, user.id, data)


@router.post("/orders/{identifier}/telegram/{invite_id}/respond", response_model=TelegramInviteOut)
async def respond_telegram(
    identifier: int,
    invite_id: int,
    data: TelegramInviteResponse,
    user: CurrentUser,
    session: Session,
):
    return await TelegramChatService(session).respond(identifier, invite_id, user.id, data)
