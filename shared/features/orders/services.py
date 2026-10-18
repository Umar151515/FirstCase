from shared.core.database import utcnow
from shared.core.exceptions import conflict, forbidden, missing
from shared.features.ai import validate_ai_usage
from shared.features.deliverables.repositories import DeliverableRepository
from shared.features.notifications.services import NotificationService
from shared.features.orders.repositories import OrderRepository
from shared.features.orders.schemas import OrderOut
from shared.features.tasks.repositories import TaskRepository
from shared.features.tasks.services import TaskService
from shared.features.users.repositories import UserRepository
from shared.features.users.services import UserService


class OrderService:
    def __init__(self, session):
        self.session = session
        self.repository = OrderRepository(session)

    async def participant(self, identifier: int, actor_id: int, *, lock=False):
        order = await self.repository.get(identifier, lock=lock)
        if actor_id not in (order.customer_id, order.performer_id):
            raise missing()
        return order

    async def view(self, order) -> OrderOut:
        users = UserService(self.session)
        return OrderOut.model_validate(
            {
                **{
                    k: getattr(order, k)
                    for k in (
                        "id",
                        "task_id",
                        "customer_id",
                        "performer_id",
                        "status",
                        "revisions_used",
                        "max_revisions",
                        "ai_policy",
                        "created_at",
                        "accepted_at",
                        "completed_at",
                    )
                },
                "order_id": order.id,
                "task": await TaskService(self.session).view(
                    await TaskRepository(self.session).get(order.task_id)
                ),
                "customer": await users.public(
                    await UserRepository(self.session).get(order.customer_id)
                ),
                "performer": await users.public(
                    await UserRepository(self.session).get(order.performer_id)
                ),
            }
        )

    async def transition(self, identifier: int, actor_id: int, action: str, reason: str = ""):
        order = await self.participant(identifier, actor_id, lock=True)
        actor_role = "customer" if actor_id == order.customer_id else "performer"
        transitions = {
            "start": ({"assigned"}, "performer", "in_progress"),
            "accept": ({"submitted"}, "customer", "accepted_pending_review"),
            "request_revision": ({"submitted"}, "customer", "revision_requested"),
            "cancel": ({"assigned", "in_progress", "revision_requested"}, "either", "cancelled"),
            "dispute": (
                {
                    "assigned",
                    "in_progress",
                    "submitted",
                    "revision_requested",
                    "accepted_pending_review",
                },
                "either",
                "disputed",
            ),
        }
        allowed, required_role, new_status = transitions[action]
        if required_role not in ("either", actor_role):
            raise forbidden("order_other_participant")
        if order.status not in allowed:
            raise conflict("invalid_order_transition")
        if action == "request_revision":
            if order.revisions_used >= order.max_revisions:
                raise conflict("revisions_exhausted")
            order.revisions_used += 1
        if action == "accept":
            order.accepted_at = utcnow()
        order.status = new_status
        if action == "cancel":
            task = await TaskRepository(self.session).get(order.task_id)
            task.status = "cancelled"
        await self.repository.event(
            order.id, actor_id, new_status, {"reason": reason} if reason else {}
        )
        other_id = order.performer_id if actor_role == "customer" else order.customer_id
        titles = {
            "start": "work_started",
            "accept": "work_accepted",
            "request_revision": "revision_requested",
            "cancel": "order_cancelled",
            "dispute": "dispute_opened",
        }
        await NotificationService(self.session).notify(
            other_id, new_status, titles[action], f"/orders/{order.id}"
        )
        if action == "accept":
            await NotificationService(self.session).notify(
                order.customer_id,
                "review_required",
                "review_required",
                f"/orders/{order.id}",
            )
        await self.session.flush()
        return order

    async def submit(self, identifier: int, actor_id: int, data):
        order = await self.participant(identifier, actor_id, lock=True)
        if actor_id != order.performer_id:
            raise forbidden("performer_submits")
        if order.status not in {"assigned", "in_progress", "revision_requested"}:
            raise conflict("submit_unavailable")
        validate_ai_usage(order.ai_policy, data.ai_usage, data.ai_disclosure)
        from shared.features.uploads.services import UploadService

        await UploadService(self.session).bind(data.attachment_ids, actor_id, order_id=order.id)
        version = await DeliverableRepository(self.session).next_version(order.id)
        await DeliverableRepository(self.session).add(
            order_id=order.id,
            performer_id=actor_id,
            version=version,
            **data.model_dump(mode="json"),
        )
        order.status = "submitted"
        await self.repository.event(order.id, actor_id, "submitted", {"version": version})
        await NotificationService(self.session).notify(
            order.customer_id, "submitted", "work_submitted", f"/orders/{order.id}"
        )
        await self.session.flush()
        return order
