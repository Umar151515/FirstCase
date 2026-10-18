from sqlalchemy import select

from shared.features.orders.models import Order
from shared.features.tips.models import TipSettings


class TipRepository:
    def __init__(self, session):
        self.session = session

    async def get(self, user_id):
        return await self.session.get(TipSettings, user_id)

    async def is_customer(self, user_id, actor_id):
        return (
            await self.session.scalar(
                select(Order.id)
                .where(
                    Order.performer_id == user_id,
                    Order.customer_id == actor_id,
                    Order.status == "completed",
                )
                .limit(1)
            )
            is not None
        )
