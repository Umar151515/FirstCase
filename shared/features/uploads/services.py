import asyncio

from shared.core.config import get_settings
from shared.core.exceptions import DomainError, forbidden, missing
from shared.core.storage import LocalStorage, safe_filename, validate_bytes
from shared.features.orders.repositories import OrderRepository
from shared.features.tasks.repositories import TaskRepository
from shared.features.uploads.repositories import AttachmentRepository
from shared.features.uploads.schemas import AttachmentOut


class UploadService:
    def __init__(self, session, settings=None):
        self.session = session
        self.settings = settings or get_settings()
        self.repository = AttachmentRepository(session)
        self.storage = LocalStorage(self.settings.upload_dir)

    @staticmethod
    def view(attachment) -> AttachmentOut:
        return AttachmentOut(
            id=attachment.id,
            filename=attachment.filename,
            mime_type=attachment.mime_type,
            size=attachment.size,
            url=f"/api/v1/uploads/{attachment.id}",
        )

    async def create(self, actor_id: int, data: bytes, filename: str | None, mime_type: str):
        if not data:
            raise DomainError("Файл пуст", 422, "invalid_file")
        if len(data) > self.settings.max_upload_size_mb * 1024 * 1024:
            raise DomainError("Файл превышает допустимый размер", 413, "file_too_large")
        await asyncio.to_thread(validate_bytes, data, mime_type)
        key = await self.storage.write(data)
        return await self.repository.add(
            owner_id=actor_id,
            filename=safe_filename(filename),
            mime_type=mime_type,
            size=len(data),
            storage_key=key,
        )

    async def bind(self, identifiers: list[int], actor_id: int, **context):
        if len(set(identifiers)) != len(identifiers):
            raise DomainError("Повторяющиеся вложения", 422, "validation_error")
        for identifier in identifiers:
            file = await self.repository.get(identifier, lock=True)
            if file.owner_id != actor_id:
                raise forbidden("Можно прикреплять только свои файлы")
            for key in ("task_id", "order_id", "report_id", "case_id"):
                existing = getattr(file, key)
                if existing is not None and (key not in context or context[key] != existing):
                    raise conflict_file()
            for key, value in context.items():
                setattr(file, key, value)
        await self.session.flush()

    async def replace_task_files(self, task_id, actor_id, identifiers):
        for identifier in identifiers:
            file = await self.repository.get(identifier, lock=True)
            if (
                file.owner_id != actor_id
                or any(getattr(file, k) is not None for k in ("order_id", "report_id", "case_id"))
                or file.task_id not in (None, task_id)
            ):
                raise forbidden()
        await self.repository.unbind_task(task_id)
        await self.bind(identifiers, actor_id, task_id=task_id)

    async def readable(self, identifier: int, actor_id: int | None = None):
        file = await self.repository.get(identifier)
        if actor_id == file.owner_id:
            return file
        if actor_id is not None and file.order_id:
            order = await OrderRepository(self.session).get(file.order_id)
            if actor_id in (order.customer_id, order.performer_id):
                return file
        if actor_id is not None and file.task_id:
            task = await TaskRepository(self.session).get(file.task_id)
            order = await self.repository.task_order(task.id)
            if actor_id == task.customer_id or (order and actor_id == order.performer_id):
                return file
        for tip in await self.repository.tip_settings(file.id):
            if tip.public_consent or (
                actor_id and await self.repository.completed_customer(tip.user_id, actor_id)
            ):
                return file
        from shared.features.portfolio.services import PortfolioService

        if await PortfolioService(self.session).public_attachment_allowed(file):
            return file
        raise missing()

    async def download(self, identifier: int, actor_id: int | None = None):
        file = await self.readable(identifier, actor_id)
        path = self.storage.path(file.storage_key)
        if not path.is_file():
            raise missing("Файл не найден")
        return file, path


def conflict_file():
    return DomainError("Файл уже прикреплён к другому объекту", 409, "file_already_attached")
