from sqlalchemy import select

from shared.features.common import Repository
from shared.features.reviews.models import Review


class ReviewRepository(Repository[Review]):
    def __init__(self, session):
        super().__init__(session, Review)

    async def for_author(self, order_id, author_id):
        return await self.session.scalar(
            select(Review).where(Review.order_id == order_id, Review.author_id == author_id)
        )
