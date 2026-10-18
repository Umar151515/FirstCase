from sqlalchemy import select, update

from shared.features.applications.models import Application
from shared.features.common import Repository
from shared.features.orders.models import Order


class ApplicationRepository(Repository[Application]):
    def __init__(self, session):
        super().__init__(session, Application)

    async def existing(self, task_id: int, user_id: int):
        return await self.session.scalar(
            select(Application).where(
                Application.task_id == task_id, Application.performer_id == user_id
            )
        )

    async def order_for_task(self, task_id: int):
        return await self.session.scalar(select(Order).where(Order.task_id == task_id))

    async def reject_others(self, task_id: int, accepted_id: int):
        await self.session.execute(
            update(Application)
            .where(
                Application.task_id == task_id,
                Application.id != accepted_id,
                Application.status == "pending",
            )
            .values(status="rejected")
        )
