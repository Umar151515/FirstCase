from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from shared.core.config import Settings
from shared.core.dependencies import get_session
from shared.core.exceptions import DomainError, forbidden
from shared.core.i18n import locale
from shared.core.security import decode_access_token, unauthorized
from shared.features.users.models import User
from shared.features.users.repositories import UserRepository
from shared.features.users.services import UserService

Session = Annotated[AsyncSession, Depends(get_session, scope="function")]
bearer = HTTPBearer(auto_error=False)


def app_settings(request: Request) -> Settings:
    return request.app.state.settings


Config = Annotated[Settings, Depends(app_settings)]


async def optional_user(
    request: Request,
    session: Session,
    settings: Config,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
):
    if not credentials:
        return None
    identifier = decode_access_token(credentials.credentials, settings)
    try:
        user = await UserRepository(session).get(identifier)
    except DomainError as exc:
        if exc.status_code == 404:
            raise unauthorized() from exc
        raise
    if not request.headers.get("accept-language"):
        locale.set(user.language)
    if user.status != "active":
        raise forbidden("account_blocked")
    if settings.app_mode == "production" and user.is_demo:
        raise unauthorized()
    user.role = UserService.effective_role(user, settings)
    return user


OptionalUser = Annotated[User | None, Depends(optional_user)]


async def current_user(user: OptionalUser) -> User:
    if user is None:
        raise unauthorized()
    return user


CurrentUser = Annotated[User, Depends(current_user)]


async def admin_user(user: CurrentUser) -> User:
    if user.role != "admin":
        raise forbidden("admin_only")
    return user


AdminUser = Annotated[User, Depends(admin_user)]
