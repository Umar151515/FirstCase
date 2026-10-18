from shared.features.common import Repository
from shared.features.notifications.models import Notification


class NotificationRepository(Repository[Notification]):
    def __init__(self, session):
        super().__init__(session, Notification)
