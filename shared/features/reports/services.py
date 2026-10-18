from shared.core.exceptions import missing
from shared.features.chat.repositories import MessageRepository
from shared.features.orders.services import OrderService
from shared.features.portfolio.services import PortfolioService
from shared.features.reports.repositories import ReportRepository
from shared.features.reviews.repositories import ReviewRepository
from shared.features.tasks.services import TaskService
from shared.features.uploads.services import UploadService
from shared.features.users.services import UserService


class ReportService:
    def __init__(self, session):
        self.session = session
        self.repository = ReportRepository(session)

    async def accessible(self, type, identifier, actor_id):
        if type == "user":
            return await UserService(self.session).get_public(identifier)
        if type == "task":
            return await TaskService(self.session).get(identifier, actor_id)
        if type == "portfolio":
            return await PortfolioService(self.session).get(identifier, actor_id)
        if type == "order":
            return await OrderService(self.session).participant(identifier, actor_id)
        if type == "message":
            message = await MessageRepository(self.session).get(identifier)
            await OrderService(self.session).participant(message.order_id, actor_id)
            return message
        if type == "review":
            review = await ReviewRepository(self.session).get(identifier)
            await OrderService(self.session).participant(review.order_id, actor_id)
            return review
        raise missing()

    async def create(self, actor_id, data):
        await self.accessible(data.target_type, data.target_id, actor_id)
        report = await self.repository.add(reporter_id=actor_id, **data.model_dump())
        await UploadService(self.session).bind(data.attachment_ids, actor_id, report_id=report.id)
        return report

    async def get(self, identifier, actor):
        report = await self.repository.get(identifier)
        if actor.role != "admin" and report.reporter_id != actor.id:
            raise missing()
        return report
