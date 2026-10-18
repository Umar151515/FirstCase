from shared.core.exceptions import conflict
from shared.features.chat.models import Message
from shared.features.chat.repositories import MessageRepository
from shared.features.chat.schemas import MessageOut
from shared.features.notifications.services import NotificationService
from shared.features.orders.services import OrderService
from shared.features.users.repositories import UserRepository
from shared.features.users.services import UserService


class ChatService:
    def __init__(self, session):
        self.session = session
        self.repository = MessageRepository(session)

    async def view(self, message):
        return MessageOut.model_validate(
            {
                **{
                    k: getattr(message, k)
                    for k in ("id", "order_id", "author_id", "text", "attachment_ids", "created_at")
                },
                "author": await UserService(self.session).public(
                    await UserRepository(self.session).get(message.author_id)
                ),
            }
        )

    async def history(self, order_id: int, actor_id: int, after_id=None, offset=0, limit=20):
        await OrderService(self.session).participant(order_id, actor_id)
        conditions = [Message.order_id == order_id]
        if after_id:
            conditions.append(Message.id > after_id)
        return await self.repository.list(
            *conditions, order_by=Message.id, offset=offset, limit=limit
        )

    async def send(self, order_id: int, actor_id: int, data):
        order = await OrderService(self.session).participant(order_id, actor_id, lock=True)
        if order.status == "cancelled":
            raise conflict("Заказ отменён")
        from shared.features.uploads.services import UploadService

        await UploadService(self.session).bind(data.attachment_ids, actor_id, order_id=order_id)
        message = await self.repository.add(
            order_id=order_id, author_id=actor_id, **data.model_dump()
        )
        other = order.performer_id if actor_id == order.customer_id else order.customer_id
        await NotificationService(self.session).notify(
            other, "new_message", "Новое сообщение в заказе", f"/orders/{order_id}"
        )
        return message
