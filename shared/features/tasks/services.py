from sqlalchemy import or_

from shared.core.database import utcnow
from shared.core.exceptions import DomainError, conflict, forbidden, missing
from shared.features.tasks.models import Task
from shared.features.tasks.repositories import TaskRepository
from shared.features.tasks.schemas import TaskCreate, TaskOut, TaskUpdate
from shared.features.users.repositories import UserRepository
from shared.features.users.services import UserService


class TaskService:
    def __init__(self, session):
        self.session = session
        self.repository = TaskRepository(session)

    async def catalog(
        self,
        q=None,
        category_id=None,
        status=None,
        city=None,
        sort="newest",
        mine_user_id=None,
        offset=0,
        limit=20,
        admin=False,
        created_after=None,
        created_before=None,
    ):
        conditions = [] if admin else [Task.is_hidden.is_(False)]
        if q:
            conditions.append(or_(Task.title.ilike(f"%{q}%"), Task.description.ilike(f"%{q}%")))
        if category_id:
            conditions.append(Task.category_id == category_id)
        if status:
            conditions.append(Task.status == status)
        if city:
            conditions.append(Task.city.ilike(f"%{city}%"))
        if mine_user_id:
            conditions.append(Task.customer_id == mine_user_id)
        if created_after:
            conditions.append(Task.created_at >= created_after)
        if created_before:
            conditions.append(Task.created_at <= created_before)
        if created_after and created_before and created_after > created_before:
            raise DomainError(
                "Начало диапазона должно предшествовать концу", 422, "validation_error"
            )
        order = {
            "newest": Task.created_at.desc(),
            "oldest": Task.created_at.asc(),
            "deadline": Task.deadline.asc(),
        }[sort]
        return await self.repository.list(*conditions, offset=offset, limit=limit, order_by=order)

    async def get(self, identifier: int, actor_id: int | None = None, *, lock: bool = False):
        task = await self.repository.get(identifier, lock=lock)
        if task.is_hidden and task.customer_id != actor_id:
            raise missing()
        return task

    async def view(self, task: Task) -> TaskOut:
        customer = await UserRepository(self.session).get(task.customer_id)
        return TaskOut.model_validate(
            {
                **{
                    k: getattr(task, k)
                    for k in (
                        "id",
                        "customer_id",
                        "category_id",
                        "title",
                        "description",
                        "expected_result",
                        "deadline",
                        "max_revisions",
                        "payment_type",
                        "city",
                        "status",
                        "is_hidden",
                        "created_at",
                        "updated_at",
                    )
                },
                "customer": await UserService(self.session).public(customer),
                "category": await self.repository.category(task.category_id),
                "application_count": await self.repository.application_count(task.id),
                "attachment_ids": await self.repository.attachment_ids(task.id),
            }
        )

    async def _validate(self, data: dict):
        if "deadline" in data and data["deadline"] <= utcnow():
            raise DomainError("Укажите будущий срок", 422, "validation_error")
        if "category_id" in data:
            category = await self.repository.category(data["category_id"])
            if not category or not category.active:
                raise DomainError("Категория недоступна", 422, "validation_error")

    async def create(self, actor_id: int, data: TaskCreate):
        values = data.model_dump(exclude={"attachment_ids"})
        await self._validate(values)
        task = await self.repository.add(customer_id=actor_id, **values)
        from shared.features.uploads.services import UploadService

        await UploadService(self.session).bind(data.attachment_ids, actor_id, task_id=task.id)
        return task

    async def update(self, identifier: int, actor_id: int, data: TaskUpdate):
        task = await self.repository.get(identifier, lock=True)
        if task.customer_id != actor_id:
            raise forbidden()
        if task.status != "published":
            raise conflict("После выбора исполнителя задача не редактируется")
        values = data.model_dump(exclude_none=True, exclude={"attachment_ids"})
        await self._validate(values)
        for key, value in values.items():
            setattr(task, key, value)
        if data.attachment_ids is not None:
            from shared.features.uploads.services import UploadService

            await UploadService(self.session).replace_task_files(
                task.id, actor_id, data.attachment_ids
            )
        await self.session.flush()
        return task

    async def cancel(self, identifier: int, actor_id: int):
        task = await self.repository.get(identifier, lock=True)
        if task.customer_id != actor_id:
            raise forbidden()
        if task.status != "published":
            raise conflict("Задачу с выбранным исполнителем нельзя отменить здесь")
        task.status = "cancelled"
        await self.session.flush()
        return task
