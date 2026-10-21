from shared.core.exceptions import DomainError, forbidden, missing
from shared.features.tips.models import TipSettings
from shared.features.tips.repositories import TipRepository
from shared.features.tips.schemas import TipSettingsOut
from shared.features.uploads.repositories import AttachmentRepository
from shared.features.uploads.services import UploadService
from shared.features.users.repositories import UserRepository


class TipService:
    def __init__(self, session):
        self.session = session
        self.repository = TipRepository(session)

    async def own(self, user_id):
        settings = await self.repository.get(user_id)
        if not settings:
            return TipSettingsOut(
                user_id=user_id,
                payment_method="",
                qr_attachment_id=None,
                payment_url=None,
                enabled=False,
                public_consent=False,
            )
        return await self.view(settings)

    async def view(self, settings):
        result = TipSettingsOut.model_validate(settings)
        if settings.qr_attachment_id:
            result.qr = UploadService.view(
                await AttachmentRepository(self.session).get(settings.qr_attachment_id)
            )
        return result

    async def update(self, user_id, data):
        # A settings row may not exist yet. Lock its owner so concurrent first
        # writes cannot both insert the same primary key.
        await UserRepository(self.session).get(user_id, lock=True)
        if data.enabled and not data.qr_attachment_id and not data.payment_url:
            raise DomainError("tips_destination_required", 422, "validation_error")
        if data.qr_attachment_id:
            file = await AttachmentRepository(self.session).get(data.qr_attachment_id, lock=True)
            if await AttachmentRepository(self.session).avatar_owner(file.id):
                raise forbidden("standalone_qr_required")
            if file.owner_id != user_id or not file.mime_type.startswith("image/"):
                raise forbidden("own_qr_required")
            if any(getattr(file, k) for k in ("task_id", "order_id", "report_id", "case_id")):
                raise forbidden("standalone_qr_required")
        settings = await self.repository.get(user_id)
        if not settings:
            settings = TipSettings(user_id=user_id)
            self.session.add(settings)
        for key, value in data.model_dump(mode="json").items():
            setattr(settings, key, value)
        await self.session.flush()
        return await self.view(settings)

    async def public(self, user_id, actor_id=None):
        owner = await UserRepository(self.session).get(user_id)
        if owner.status != "active":
            raise missing("tips_unavailable")
        settings = await self.repository.get(user_id)
        if not settings or not settings.enabled:
            raise missing("tips_unavailable")
        if (
            actor_id != user_id
            and not settings.public_consent
            and not (actor_id and await self.repository.is_customer(user_id, actor_id))
        ):
            raise missing()
        return await self.view(settings)
