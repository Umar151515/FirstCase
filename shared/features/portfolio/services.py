from shared.core.exceptions import conflict, forbidden, missing
from shared.features.chat.repositories import MessageRepository
from shared.features.orders.services import OrderService
from shared.features.portfolio.models import PrivacyConsent
from shared.features.portfolio.repositories import PortfolioRepository
from shared.features.portfolio.schemas import CaseOut, EvidenceOut, SafeMessage, SafeReview
from shared.features.reviews.repositories import ReviewRepository
from shared.features.tasks.repositories import TaskRepository
from shared.features.uploads.repositories import AttachmentRepository
from shared.features.uploads.services import UploadService
from shared.features.users.repositories import UserRepository
from shared.features.users.services import UserService


class PortfolioService:
    def __init__(self, session):
        self.session = session
        self.repository = PortfolioRepository(session)

    async def get(self, identifier, actor_id=None):
        case = await self.repository.get(identifier)
        if (case.visibility == "private" or case.is_hidden) and actor_id != case.owner_id:
            raise missing()
        return case

    async def create(self, actor_id, data):
        order = None
        category_id = None
        if data.order_id:
            order = await OrderService(self.session).participant(data.order_id, actor_id, lock=True)
            if order.performer_id != actor_id:
                raise forbidden("Подтверждённый кейс создаёт исполнитель")
            if order.status != "completed":
                raise conflict("Сначала завершите заказ и получите отзыв заказчика")
            if await self.repository.for_order(order.id):
                raise conflict("По этому заказу уже есть кейс")
            category_id = (await TaskRepository(self.session).get(order.task_id)).category_id
        case = await self.repository.add(
            owner_id=actor_id,
            order_id=data.order_id,
            title=data.title,
            description=data.description,
            result=data.result,
            visibility=data.visibility,
            verified=order is not None,
            show_customer=data.show_customer,
            category_id=category_id,
            completed_at=order.completed_at if order else None,
        )
        await self._set_evidence(case, actor_id, data)
        return case

    async def edit(self, identifier, actor_id, data):
        case = await self.repository.get(identifier, lock=True)
        if case.owner_id != actor_id:
            raise forbidden()
        for key, value in data.model_dump(exclude_none=True).items():
            setattr(case, key, value)
        await self.session.flush()
        return case

    async def visibility(self, identifier, actor_id, data):
        case = await self.repository.get(identifier, lock=True)
        if case.owner_id != actor_id:
            raise forbidden()
        case.visibility = data.visibility
        case.show_customer = data.show_customer
        await self._set_evidence(case, actor_id, data)
        await self.session.flush()
        return case

    async def _set_evidence(self, case, actor_id, data):
        consent = await self.repository.consent(case.order_id) if case.order_id else None
        if data.show_customer and (
            case.visibility != "public" or not consent or not consent.allow_identity
        ):
            raise forbidden("Заказчик не согласился на публикацию личности")
        if case.visibility == "anonymous" and (
            data.message_ids or data.attachment_ids or data.show_customer
        ):
            raise forbidden("Анонимный кейс не публикует исходные файлы и переписку")
        if data.message_ids and not case.order_id:
            raise forbidden("Для переписки нужен исходный заказ")
        if len(set(data.attachment_ids)) != len(data.attachment_ids) or len(
            set(data.message_ids)
        ) != len(data.message_ids):
            raise conflict("Доказательства повторяются")
        order = (
            await OrderService(self.session).repository.get(case.order_id)
            if case.order_id
            else None
        )
        for identifier in data.attachment_ids:
            file = await AttachmentRepository(self.session).get(identifier)
            if order:
                if not (file.order_id == order.id or file.task_id == order.task_id):
                    raise forbidden("Файл не относится к этому заказу")
                if case.visibility == "public" and (
                    not consent or identifier not in consent.attachment_ids
                ):
                    raise forbidden("Нет согласия заказчика на публикацию файла")
            elif (
                file.owner_id != actor_id
                or any(getattr(file, k) for k in ("task_id", "order_id", "report_id"))
                or file.case_id not in (None, case.id)
            ):
                raise forbidden("Нельзя публиковать чужие или приватные файлы")
            else:
                file.case_id = case.id
        for identifier in data.message_ids:
            message = await MessageRepository(self.session).get(identifier)
            if message.order_id != case.order_id:
                raise forbidden()
            if case.visibility == "public" and (
                not consent or identifier not in consent.message_ids
            ):
                raise forbidden("Нет согласия заказчика на публикацию сообщения")
        await self.repository.replace_evidence(case.id, data.attachment_ids, data.message_ids)

    async def set_consent(self, order_id, actor_id, data):
        order = await OrderService(self.session).participant(order_id, actor_id, lock=True)
        if order.customer_id != actor_id:
            raise forbidden("Согласие предоставляет заказчик")
        for identifier in data.attachment_ids:
            file = await AttachmentRepository(self.session).get(identifier)
            if file.order_id != order_id and file.task_id != order.task_id:
                raise forbidden("Файл не относится к заказу")
        for identifier in data.message_ids:
            message = await MessageRepository(self.session).get(identifier)
            if message.order_id != order_id:
                raise forbidden("Сообщение не относится к заказу")
        consent = await self.repository.consent(order_id)
        if not consent:
            consent = PrivacyConsent(order_id=order_id, customer_id=actor_id)
            self.session.add(consent)
        for key, value in data.model_dump().items():
            setattr(consent, key, value)
        await self.session.flush()
        return consent

    async def view(self, case, actor_id=None, *, privileged=False) -> CaseOut:
        private_access = case.visibility == "private" and (actor_id == case.owner_id or privileged)
        consent = await self.repository.consent(case.order_id) if case.order_id else None
        order = (
            await OrderService(self.session).repository.get(case.order_id)
            if case.order_id
            else None
        )
        customer = None
        review = None
        if order:
            source = await ReviewRepository(self.session).for_author(order.id, order.customer_id)
            if source:
                review = SafeReview(
                    rating=source.rating,
                    comment=source.comment
                    if private_access
                    or (case.visibility == "public" and consent and consent.allow_identity)
                    else "",
                )
            if private_access or (
                case.visibility == "public"
                and case.show_customer
                and consent
                and consent.allow_identity
            ):
                customer = await UserService(self.session).public(
                    await UserRepository(self.session).get(order.customer_id)
                )
        evidence = EvidenceOut()
        for source in await self.repository.evidence(case.id):
            if case.visibility == "anonymous":
                continue
            if source.attachment_id:
                allowed = (
                    private_access
                    or not order
                    or (
                        case.visibility == "public"
                        and consent
                        and source.attachment_id in consent.attachment_ids
                    )
                )
                if allowed:
                    file = await AttachmentRepository(self.session).get(source.attachment_id)
                    evidence.attachments.append(UploadService.view(file))
            if source.message_id and (
                private_access
                or (
                    case.visibility == "public"
                    and consent
                    and source.message_id in consent.message_ids
                )
            ):
                msg = await MessageRepository(self.session).get(source.message_id)
                evidence.messages.append(SafeMessage(text=msg.text, created_at=msg.created_at))
        return CaseOut(
            id=case.id,
            owner_id=case.owner_id,
            title=case.title,
            description=case.description,
            result=case.result,
            visibility=case.visibility,
            verified=case.verified,
            category=await TaskRepository(self.session).category(case.category_id)
            if case.category_id
            else None,
            completed_at=case.completed_at,
            customer=customer,
            review=review,
            evidence=evidence,
            created_at=case.created_at,
        )

    async def public_attachment_allowed(self, file):
        for case in await self.repository.public_cases_for_attachment(file.id):
            if case.visibility != "public":
                continue
            if not case.order_id:
                return file.owner_id == case.owner_id and file.case_id == case.id
            consent = await self.repository.consent(case.order_id)
            if consent and file.id in consent.attachment_ids:
                return True
        return False
