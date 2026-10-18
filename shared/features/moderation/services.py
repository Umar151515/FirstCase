from shared.core.exceptions import conflict, forbidden
from shared.features.chat.models import Message
from shared.features.chat.repositories import MessageRepository
from shared.features.chat.services import ChatService
from shared.features.moderation.repositories import ModerationRepository
from shared.features.notifications.services import NotificationService
from shared.features.orders.services import OrderService
from shared.features.portfolio.services import PortfolioService
from shared.features.reports.repositories import ReportRepository
from shared.features.reviews.repositories import ReviewRepository
from shared.features.tasks.repositories import TaskRepository
from shared.features.uploads.models import Attachment
from shared.features.uploads.repositories import AttachmentRepository
from shared.features.uploads.services import UploadService
from shared.features.users.repositories import UserRepository


class ModerationService:
    def __init__(self, session):
        self.session = session
        self.repository = ModerationRepository(session)

    async def user(self, admin_id, identifier, data):
        user = await UserRepository(self.session).get(identifier, lock=True)
        if user.id == admin_id or user.role == "admin":
            raise forbidden("Нельзя блокировать администратора этим действием")
        user.status = data.status
        await self.repository.add(
            admin_id=admin_id,
            target_type="user",
            target_id=user.id,
            action="block" if data.status == "blocked" else "unblock",
            reason=data.reason,
        )
        await self.session.flush()
        return user

    async def task(self, admin_id, identifier, data):
        task = await TaskRepository(self.session).get(identifier, lock=True)
        task.is_hidden = data.is_hidden
        await self.repository.add(
            admin_id=admin_id,
            target_type="task",
            target_id=task.id,
            action="hide" if data.is_hidden else "unhide",
            reason=data.reason,
        )
        await self.session.flush()
        return task

    async def report(self, admin_id, identifier, data):
        report = await ReportRepository(self.session).get(identifier, lock=True)
        report.status = data.status
        report.moderator_comment = data.moderator_comment
        await self.repository.add(
            admin_id=admin_id,
            target_type="report",
            target_id=report.id,
            action=f"report_{data.status}",
            reason=data.moderator_comment,
        )
        await NotificationService(self.session).notify(
            report.reporter_id,
            "report_decision",
            "Обновление по вашей жалобе",
            f"/reports/{report.id}",
            data.moderator_comment,
        )
        await self.session.flush()
        return report

    async def evidence_access(self, admin_id, identifier, reason):
        report = await ReportRepository(self.session).get(identifier, lock=True)
        order = None
        case = None
        if report.target_type == "order":
            order = await OrderService(self.session).repository.get(report.target_id)
        elif report.target_type == "message":
            message = await MessageRepository(self.session).get(report.target_id)
            order = await OrderService(self.session).repository.get(message.order_id)
        elif report.target_type == "review":
            review = await ReviewRepository(self.session).get(report.target_id)
            order = await OrderService(self.session).repository.get(review.order_id)
        elif report.target_type == "portfolio":
            case = await PortfolioService(self.session).repository.get(report.target_id)
            if case.order_id:
                order = await OrderService(self.session).repository.get(case.order_id)
        if report.status not in ("pending", "in_review") and (
            not order or order.status != "disputed"
        ):
            raise forbidden("Доступ к доказательствам требует открытой жалобы или спора")
        await self.repository.add(
            admin_id=admin_id,
            target_type="report",
            target_id=report.id,
            action="evidence_access",
            reason=reason,
        )
        files = {i: await AttachmentRepository(self.session).get(i) for i in report.attachment_ids}
        messages = []
        if order:
            sources, _ = await MessageRepository(self.session).list(
                Message.order_id == order.id, order_by=Message.id, limit=100
            )
            messages = [await ChatService(self.session).view(m) for m in sources]
            for message in sources:
                for file_id in message.attachment_ids:
                    files[file_id] = await AttachmentRepository(self.session).get(file_id)
            order_files, _ = await AttachmentRepository(self.session).list(
                (Attachment.order_id == order.id) | (Attachment.task_id == order.task_id), limit=100
            )
            files.update({f.id: f for f in order_files})
        if case:
            for evidence in await PortfolioService(self.session).repository.evidence(case.id):
                if evidence.attachment_id:
                    files[evidence.attachment_id] = await AttachmentRepository(self.session).get(
                        evidence.attachment_id
                    )
        return {
            "report": report,
            "order": await OrderService(self.session).view(order) if order else None,
            "messages": messages,
            "attachments": [UploadService.view(f) for f in files.values()],
            "portfolio": await PortfolioService(self.session).view(case, privileged=True)
            if case
            else None,
        }

    async def resolve_dispute(self, admin_id, identifier, action, reason):
        order = await OrderService(self.session).repository.get(identifier, lock=True)
        if order.status != "disputed":
            raise conflict("Заказ не находится в споре")
        new_state = "cancelled" if action == "cancel" else "in_progress"
        order.status = new_state
        if action == "cancel":
            task = await TaskRepository(self.session).get(order.task_id)
            task.status = "cancelled"
        await self.repository.add(
            admin_id=admin_id,
            target_type="order",
            target_id=order.id,
            action=f"dispute_{action}",
            reason=reason,
        )
        await OrderService(self.session).repository.event(
            order.id, admin_id, new_state, {"moderator_reason": reason}
        )
        for user_id in (order.customer_id, order.performer_id):
            await NotificationService(self.session).notify(
                user_id,
                "dispute_decision",
                "Администратор рассмотрел спор",
                f"/orders/{order.id}",
                reason,
            )
        return order
