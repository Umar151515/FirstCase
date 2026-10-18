from shared.core.exceptions import missing
from shared.features.users.models import User
from shared.features.users.repositories import UserRepository
from shared.features.users.schemas import ProfileUpdate, PublicUser, UserOut


class UserService:
    def __init__(self, session):
        self.session = session
        self.repository = UserRepository(session)

    async def public(self, user: User) -> PublicUser:
        return PublicUser.model_validate(user).model_copy(
            update=await self.repository.reputation(user.id)
        )

    async def own(self, user: User) -> UserOut:
        return UserOut.model_validate(user).model_copy(
            update=await self.repository.reputation(user.id)
        )

    async def get_public(self, identifier: int) -> PublicUser:
        user = await self.repository.get(identifier)
        if user.status != "active":
            raise missing()
        return await self.public(user)

    async def get_by_telegram(self, telegram_id: int) -> User | None:
        return await self.repository.by_telegram(telegram_id)

    async def update(self, user: User, data: ProfileUpdate) -> UserOut:
        for key, value in data.model_dump(exclude_none=True, mode="json").items():
            setattr(user, key, value)
        await self.session.flush()
        return await self.own(user)
