from shared.features.chat.models import Message
from shared.features.common import Repository


class MessageRepository(Repository[Message]):
    def __init__(self, session):
        super().__init__(session, Message)
