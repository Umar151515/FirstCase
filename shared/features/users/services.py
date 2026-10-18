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
            update={
                **await self.repository.reputation(user.id),
                "avatar_url": self.avatar_url(user),
            }
        )

    async def own(self, user: User) -> UserOut:
        return UserOut.model_validate(user).model_copy(
            update={
                **await self.repository.reputation(user.id),
                "avatar_url": self.avatar_url(user),
            }
        )

    @staticmethod
    def avatar_url(user: User) -> str | None:
        if user.avatar_attachment_id:
            return f"/api/v1/uploads/{user.avatar_attachment_id}"
        return user.avatar_url

    async def get_public(self, identifier: int) -> PublicUser:
        user = await self.repository.get(identifier)
        if user.status != "active":
            raise missing()
        return await self.public(user)

    async def get_by_telegram(self, telegram_id: int) -> User | None:
        return await self.repository.by_telegram(telegram_id)

    async def update(self, user: User, data: ProfileUpdate) -> UserOut:
        user = await self.repository.get(user.id, lock=True)
        if "avatar_attachment_id" in data.model_fields_set:
            from shared.features.uploads.services import UploadService

            if data.avatar_attachment_id:
                await UploadService(self.session).claim_image(
                    data.avatar_attachment_id, user.id, avatar_user_id=user.id
                )
            else:
                user.avatar_url = None
            user.avatar_attachment_id = data.avatar_attachment_id
        for key, value in data.model_dump(
            exclude_none=True, mode="json", exclude={"avatar_attachment_id"}
        ).items():
            setattr(user, key, value)
        await self.session.flush()
        return await self.own(user)
