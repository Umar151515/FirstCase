from sqlalchemy import func, or_, select

from shared.features.common import Repository
from shared.features.orders.models import Order
from shared.features.portfolio.models import PortfolioCase
from shared.features.reviews.models import Review
from shared.features.users.models import User


class UserRepository(Repository[User]):
    def __init__(self, session):
        super().__init__(session, User)

    async def by_telegram(self, telegram_id: int) -> User | None:
        return await self.session.scalar(select(User).where(User.telegram_id == telegram_id))

    async def reputation(self, user_id: int) -> dict:
        rating, count = (
            await self.session.execute(
                select(func.avg(Review.rating), func.count(Review.id)).where(
                    Review.recipient_id == user_id
                )
            )
        ).one()
        completed = await self.session.scalar(
            select(func.count(Order.id)).where(
                Order.status == "completed",
                or_(Order.performer_id == user_id, Order.customer_id == user_id),
            )
        )
        cases = await self.session.scalar(
            select(func.count(PortfolioCase.id)).where(
                PortfolioCase.owner_id == user_id,
                PortfolioCase.verified.is_(True),
                PortfolioCase.visibility != "private",
                PortfolioCase.is_hidden.is_(False),
            )
        )
        return {
            "rating": round(float(rating or 0), 2),
            "review_count": count,
            "completed_orders": completed,
            "verified_cases": cases,
        }
