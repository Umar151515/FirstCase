from shared.core.database import utcnow
from shared.core.exceptions import DomainError, conflict
from shared.features.notifications.services import NotificationService
from shared.features.orders.services import OrderService
from shared.features.reviews.repositories import ReviewRepository
from shared.features.tasks.repositories import TaskRepository


class ReviewService:
    def __init__(self, session):
        self.session = session
        self.repository = ReviewRepository(session)

    async def create(self, order_id: int, actor_id: int, data):
        orders = OrderService(self.session)
        order = await orders.participant(order_id, actor_id, lock=True)
        customer_review = actor_id == order.customer_id
        allowed = {"accepted_pending_review", "completed"} if customer_review else {"completed"}
        if order.status not in allowed:
            raise conflict("Отзыв можно оставить только после принятия работы")
        if customer_review and len(data.comment.strip()) < 5:
            raise DomainError("Добавьте текст отзыва не короче 5 символов", 422, "validation_error")
        if await self.repository.for_author(order_id, actor_id):
            raise conflict("Вы уже оставили отзыв по этому заказу")
        recipient = order.performer_id if customer_review else order.customer_id
        review = await self.repository.add(
            order_id=order_id, author_id=actor_id, recipient_id=recipient, **data.model_dump()
        )
        if customer_review:
            order.status = "completed"
            order.completed_at = utcnow()
            task = await TaskRepository(self.session).get(order.task_id)
            task.status = "completed"
            await orders.repository.event(order_id, actor_id, "completed", {"review_id": review.id})
        await NotificationService(self.session).notify(
            recipient, "new_review", "Вы получили отзыв", f"/orders/{order_id}"
        )
        await self.session.flush()
        return review
