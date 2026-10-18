from sqlalchemy import select, update

from shared.features.common import Repository
from shared.features.orders.models import Order
from shared.features.tips.models import TipSettings
from shared.features.uploads.models import Attachment


class AttachmentRepository(Repository[Attachment]):
    def __init__(self, session):
        super().__init__(session, Attachment)

    async def task_order(self, task_id):
        return await self.session.scalar(select(Order).where(Order.task_id == task_id))

    async def unbind_task(self, task_id):
        await self.session.execute(
            update(Attachment).where(Attachment.task_id == task_id).values(task_id=None)
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
