from sqlalchemy.dialects.postgresql import insert

from shared.core.exceptions import forbidden, missing
from shared.core.security import create_access_token, validate_telegram_init_data
from shared.features.auth.repositories import AuthRepository
from shared.features.auth.schemas import TokenResponse
from shared.features.users.models import User
from shared.features.users.services import UserService


class AuthService:
    def __init__(self, session, settings):
        self.session = session
        self.settings = settings
        self.repository = AuthRepository(session)
        self.users = UserService(session)

    async def upsert_telegram(self, data: dict) -> User:
        display_name = (
            " ".join(str(data.get(k) or "") for k in ("first_name", "last_name")).strip()[:100]
            or "Пользователь"
        )
        role = "admin" if data["id"] in self.settings.admin_ids else "user"
        avatar = data.get("photo_url")
        if avatar and not str(avatar).startswith("https://"):
            avatar = None
        values = {
            "telegram_id": data["id"],
            "username": data.get("username"),
            "display_name": display_name,
            "avatar_url": avatar,
            "role": role,
        }
        updates = {k: v for k, v in values.items() if k not in ("telegram_id", "role")}
        if role == "admin":
            updates["role"] = "admin"
        stmt = (
            insert(User)
            .values(**values)
            .on_conflict_do_update(
                index_elements=[User.telegram_id],
                set_=updates,
            )
            .returning(User)
        )
        user = (await self.session.scalars(stmt.execution_options(populate_existing=True))).one()
        if user.status != "active" or (self.settings.app_mode == "production" and user.is_demo):
            raise forbidden("Аккаунт заблокирован")
        return user

    async def login_telegram(self, raw: str) -> TokenResponse:
        user_data = validate_telegram_init_data(
            raw, self.settings.telegram_bot_token, self.settings.telegram_auth_max_age
        )
        return await self.token(await self.upsert_telegram(user_data))

    async def login_demo(self, identifier: int) -> TokenResponse:
        if self.settings.app_mode != "demo":
            raise missing()
        user = await self.repository.get(identifier)
        if not user.is_demo or user.status != "active":
            raise forbidden("Демонстрационный аккаунт недоступен")
        return await self.token(user)

    async def token(self, user: User) -> TokenResponse:
        return TokenResponse(
            access_token=create_access_token(user.id, self.settings),
            user=await self.users.own(user),
        )
