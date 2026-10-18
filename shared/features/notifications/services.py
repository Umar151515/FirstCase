from shared.core.database import utcnow
from shared.core.exceptions import missing
from shared.core.i18n import translate
from shared.features.notifications.repositories import NotificationRepository
from shared.features.notifications.schemas import NotificationOut


class NotificationService:
    def __init__(self, session):
        self.repository = NotificationRepository(session)

    async def notify(self, user_id: int, type: str, title: str, link: str, body: str = ""):
        return await self.repository.add(
            user_id=user_id, type=type, title=title, link=link, body=body
        )

    @staticmethod
    def view(note) -> NotificationOut:
        return NotificationOut.model_validate(note).model_copy(
            update={"title": translate(note.title)}
        )

    async def mark_read(self, identifier: int, user_id: int):
        note = await self.repository.get(identifier, lock=True)
        if note.user_id != user_id:
            raise missing()
        note.read_at = note.read_at or utcnow()
        await self.repository.session.flush()
        return note
