from sqlalchemy import select, update

from shared.features.common import Repository
from shared.features.orders.models import Order
from shared.features.tasks.models import Task
from shared.features.tips.models import TipSettings
from shared.features.uploads.models import Attachment
from shared.features.users.models import User


class AttachmentRepository(Repository[Attachment]):
    def __init__(self, session):
        super().__init__(session, Attachment)

    async def task_order(self, task_id):
        return await self.session.scalar(select(Order).where(Order.task_id == task_id))

    async def unbind_task(self, task_id):
        await self.session.execute(
            update(Attachment).where(Attachment.task_id == task_id).values(task_id=None)
        )

    async def avatar_owner(self, attachment_id):
        return await self.session.scalar(
            select(User).where(User.avatar_attachment_id == attachment_id)
        )

    async def public_task_cover(self, attachment_id):
        return await self.session.scalar(
            select(Task.id)
            .join(User, User.id == Task.customer_id)
            .where(
                Task.cover_attachment_id == attachment_id,
                Task.status == "published",
                Task.is_hidden.is_(False),
                User.status == "active",
            )
            .limit(1)
        )

    async def tip_settings(self, attachment_id):
        return (
            await self.session.scalars(
                select(TipSettings).where(
                    TipSettings.qr_attachment_id == attachment_id, TipSettings.enabled.is_(True)
                )
            )
        ).all()

    async def completed_customer(self, performer_id, customer_id):
        return (
            await self.session.scalar(
                select(Order.id)
                .where(
                    Order.performer_id == performer_id,
                    Order.customer_id == customer_id,
                    Order.status == "completed",
                )
                .limit(1)
            )
            is not None
        )
