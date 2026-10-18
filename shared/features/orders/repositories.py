from sqlalchemy import select

from shared.features.common import Repository
from shared.features.orders.models import Order, OrderEvent


class OrderRepository(Repository[Order]):
    def __init__(self, session):
        super().__init__(session, Order)

    async def for_task(self, task_id):
        return await self.session.scalar(select(Order).where(Order.task_id == task_id))

    async def event(self, order_id: int, actor_id: int, type: str, details: dict | None = None):
        event = OrderEvent(order_id=order_id, actor_id=actor_id, type=type, details=details or {})
        self.session.add(event)
        await self.session.flush()
        return event
