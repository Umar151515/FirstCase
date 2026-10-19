from sqlalchemy import select

from shared.core.database import utcnow
from shared.core.exceptions import conflict, forbidden
from shared.features.chat.models import TelegramInvite
from shared.features.chat.schemas import TelegramInviteOut
from shared.features.notifications.services import NotificationService
from shared.features.orders.services import OrderService


class TelegramChatService:
    def __init__(self, session):
        self.session = session

    async def latest(self, order_id):
        return await self.session.scalar(
            select(TelegramInvite)
            .where(TelegramInvite.order_id == order_id)
            .order_by(TelegramInvite.id.desc())
            .limit(1)
        )

    @staticmethod
    def view(invite, actor_id):
        if invite is None:
            return None
        requester = invite.requested_by == actor_id
        accepted = invite.status == "accepted"
        return TelegramInviteOut(
            id=invite.id,
            order_id=invite.order_id,
            requested_by=invite.requested_by,
            status=invite.status,
            my_username=(invite.requester_username if requester else invite.recipient_username)
            if invite.status in ("pending", "accepted")
            else None,
            peer_username=(invite.recipient_username if requester else invite.requester_username)
            if accepted
            else None,
            created_at=invite.created_at,
            responded_at=invite.responded_at,
        )

    async def get(self, order_id, actor_id):
        await OrderService(self.session).participant(order_id, actor_id)
        return self.view(await self.latest(order_id), actor_id)

    async def propose(self, order_id, actor_id, contact):
        # Serialize proposals and responses on the same order, including first creation.
        order = await OrderService(self.session).participant(order_id, actor_id, lock=True)
        if order.status == "cancelled":
            raise conflict("order_cancelled")
        previous = await self.latest(order_id)
        if previous and previous.status in ("pending", "accepted"):
            raise conflict("telegram_invite_active")
        invite = TelegramInvite(
            order_id=order_id, requested_by=actor_id, requester_username=contact.username
        )
        self.session.add(invite)
        await self.session.flush()
        other = order.performer_id if actor_id == order.customer_id else order.customer_id
        await NotificationService(self.session).notify(
            other, "telegram_invite", "telegram_invite_received", f"/orders/{order_id}"
        )
        return self.view(invite, actor_id)

    async def respond(self, order_id, invite_id, actor_id, response):
        order = await OrderService(self.session).participant(order_id, actor_id, lock=True)
        invite = await self.latest(order_id)
        if invite is None or invite.id != invite_id:
            raise conflict("telegram_invite_outdated")
        requester = invite.requested_by == actor_id
        if response.action == "cancel":
            if invite.status not in ("pending", "accepted"):
                raise conflict("telegram_invite_outdated")
            if invite.status == "pending" and not requester:
                raise forbidden("order_other_participant")
            invite.status = "cancelled"
        else:
            if requester:
                raise forbidden("order_other_participant")
            if invite.status != "pending":
                raise conflict("telegram_invite_outdated")
            if response.action == "accept":
                if order.status == "cancelled":
                    raise conflict("order_cancelled")
                invite.recipient_username = response.username
                invite.status = "accepted"
            else:
                invite.status = "declined"
        invite.responded_at = utcnow()
        await self.session.flush()
        other = order.performer_id if actor_id == order.customer_id else order.customer_id
        await NotificationService(self.session).notify(
            other, "telegram_invite", f"telegram_invite_{invite.status}", f"/orders/{order_id}"
        )
        return self.view(invite, actor_id)
