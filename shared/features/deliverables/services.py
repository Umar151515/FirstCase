from shared.features.deliverables.models import Deliverable
from shared.features.deliverables.repositories import DeliverableRepository
from shared.features.orders.services import OrderService


class DeliverableService:
    def __init__(self, session):
        self.session = session
        self.repository = DeliverableRepository(session)

    async def history(self, order_id: int, actor_id: int, offset=0, limit=20):
        await OrderService(self.session).participant(order_id, actor_id)
        return await self.repository.list(
            Deliverable.order_id == order_id,
            order_by=Deliverable.version,
            offset=offset,
            limit=limit,
        )
