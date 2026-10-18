from fastapi import APIRouter

from backend.api.dependencies import Config, CurrentUser, Session
from shared.features.auth.schemas import DemoLogin, TelegramLogin, TokenResponse
from shared.features.auth.services import AuthService
from shared.features.common import Page
from shared.features.users.schemas import UserOut
from shared.features.users.services import UserService

router = APIRouter(prefix="/auth", tags=["auth"])
demo_router = APIRouter(prefix="/auth", tags=["demo authentication"])


@router.post("/telegram", response_model=TokenResponse)
async def telegram(data: TelegramLogin, session: Session, settings: Config):
    return await AuthService(session, settings).login_telegram(data.init_data)


@router.get("/me", response_model=UserOut)
async def me(user: CurrentUser, session: Session):
    return await UserService(session).own(user)


@demo_router.get("/demo-users", response_model=Page[UserOut])
async def demo_users(session: Session, settings: Config):
    users, total = await AuthService(session, settings).repository.demo_users()
    return {"items": [await UserService(session).own(u) for u in users], "total": total}


@demo_router.post("/demo-login", response_model=TokenResponse)
async def demo_login(data: DemoLogin, session: Session, settings: Config):
    return await AuthService(session, settings).login_demo(data.user_id)
