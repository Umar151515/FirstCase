from sqlalchemy import func, select

from shared.features.common import Repository
from shared.features.deliverables.models import Deliverable


class DeliverableRepository(Repository[Deliverable]):
    def __init__(self, session):
        super().__init__(session, Deliverable)

    async def next_version(self, order_id: int) -> int:
        version = await self.session.scalar(
            select(func.max(Deliverable.version)).where(Deliverable.order_id == order_id)
        )
        return (version or 0) + 1

    async def latest(self, order_id: int):
        return await self.session.scalar(
            select(Deliverable)
            .where(Deliverable.order_id == order_id)
            .order_by(Deliverable.version.desc())
            .limit(1)
        )
