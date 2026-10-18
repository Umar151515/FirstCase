from sqlalchemy import func, select

from shared.features.applications.models import Application
from shared.features.common import Repository
from shared.features.moderation.models import ModerationAction
from shared.features.orders.models import Order
from shared.features.portfolio.models import PortfolioCase
from shared.features.reports.models import Report
from shared.features.reviews.models import Review
from shared.features.tasks.models import Task
from shared.features.users.models import User


class ModerationRepository(Repository[ModerationAction]):
    def __init__(self, session):
        super().__init__(session, ModerationAction)

    async def stats(self):
        conditions = {
            "users": (User, []),
            "active_tasks": (Task, [Task.status == "published", Task.is_hidden.is_(False)]),
            "completed_orders": (Order, [Order.status == "completed"]),
            "applications": (Application, [Application.status == "pending"]),
            "reviews": (Review, []),
            "verified_cases": (PortfolioCase, [PortfolioCase.verified.is_(True)]),
            "open_reports": (Report, [Report.status.in_(["pending", "in_review"])]),
        }
        return {
            key: await self.session.scalar(select(func.count()).select_from(model).where(*where))
            for key, (model, where) in conditions.items()
        }
