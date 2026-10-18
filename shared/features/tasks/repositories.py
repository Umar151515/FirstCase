from sqlalchemy import func, select

from shared.features.applications.models import Application
from shared.features.common import Repository
from shared.features.tasks.models import Category, Task
from shared.features.uploads.models import Attachment


class TaskRepository(Repository[Task]):
    def __init__(self, session):
        super().__init__(session, Task)

    async def category(self, identifier: int) -> Category | None:
        return await self.session.get(Category, identifier)

    async def application_count(self, identifier: int) -> int:
        return await self.session.scalar(
            select(func.count(Application.id)).where(Application.task_id == identifier)
        )

    async def attachment_ids(self, identifier: int) -> list[int]:
        return list(
            await self.session.scalars(
                select(Attachment.id).where(Attachment.task_id == identifier)
            )
        )


class CategoryRepository(Repository[Category]):
    def __init__(self, session):
        super().__init__(session, Category)
