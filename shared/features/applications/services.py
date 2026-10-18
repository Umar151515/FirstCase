from shared.core.database import utcnow
from shared.core.exceptions import DomainError, conflict, forbidden
from shared.features.applications.repositories import ApplicationRepository
from shared.features.applications.schemas import ApplicationOut
from shared.features.notifications.services import NotificationService
from shared.features.orders.repositories import OrderRepository
from shared.features.tasks.repositories import TaskRepository
from shared.features.users.repositories import UserRepository
from shared.features.users.services import UserService


class ApplicationService:
    def __init__(self, session):
        self.session = session
        self.repository = ApplicationRepository(session)

    async def view(self, application):
        performer = await UserRepository(self.session).get(application.performer_id)
        return ApplicationOut.model_validate(
            {
                **{
                    k: getattr(application, k)
                    for k in (
                        "id",
                        "task_id",
                        "performer_id",
                        "message",
                        "proposed_deadline",
                        "comment",
                        "status",
                        "created_at",
                    )
                },
                "performer": await UserService(self.session).public(performer),
            }
        )

    async def create(self, task_id: int, actor_id: int, data):
        task = await TaskRepository(self.session).get(task_id, lock=True)
        if task.customer_id == actor_id:
            raise forbidden("Нельзя откликнуться на свою задачу")
        if task.status != "published" or task.is_hidden:
            raise conflict("Задача уже не принимает отклики")
        if data.proposed_deadline <= utcnow():
            raise DomainError("Предложенный срок должен быть в будущем", 422, "validation_error")
        if await self.repository.existing(task_id, actor_id):
            raise conflict("Вы уже откликнулись на эту задачу")
        application = await self.repository.add(
            task_id=task_id, performer_id=actor_id, **data.model_dump()
        )
        await NotificationService(self.session).notify(
            task.customer_id, "new_application", "Новый отклик на вашу задачу", f"/tasks/{task_id}"
        )
        return application

    async def accept(self, identifier: int, actor_id: int):
        application = await self.repository.get(identifier)
        task = await TaskRepository(self.session).get(application.task_id, lock=True)
        application = await self.repository.get(identifier, lock=True)
        if task.customer_id != actor_id:
            raise forbidden()
        if application.status == "accepted":
            return await self.repository.order_for_task(task.id)
        if task.status != "published" or task.is_hidden or application.status != "pending":
            raise conflict("Исполнитель уже выбран или отклик недоступен")
        performer = await UserRepository(self.session).get(application.performer_id)
        if performer.status != "active":
            raise conflict("Исполнитель заблокирован")
        application.status = "accepted"
        task.status = "assigned"
        await self.repository.reject_others(task.id, application.id)
        order = await OrderRepository(self.session).add(
            task_id=task.id,
            customer_id=task.customer_id,
            performer_id=application.performer_id,
            max_revisions=task.max_revisions,
        )
        await OrderRepository(self.session).event(
            order.id, actor_id, "assigned", {"application_id": application.id}
        )
        await NotificationService(self.session).notify(
            application.performer_id, "assigned", "Вас выбрали исполнителем", f"/orders/{order.id}"
        )
        return order

    async def decide(self, identifier: int, actor_id: int, withdraw: bool = False):
        application = await self.repository.get(identifier)
        task = await TaskRepository(self.session).get(application.task_id, lock=True)
        application = await self.repository.get(identifier, lock=True)
        if actor_id != (application.performer_id if withdraw else task.customer_id):
            raise forbidden()
        if application.status != "pending" or task.status != "published":
            raise conflict("Отклик больше не ожидает решения")
        application.status = "withdrawn" if withdraw else "rejected"
        await self.session.flush()
        return application
