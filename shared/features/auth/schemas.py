from pydantic import Field

from shared.features.common import Schema
from shared.features.users.schemas import UserOut


class TelegramLogin(Schema):
    init_data: str = Field(min_length=1, max_length=16384)


class DemoLogin(Schema):
    user_id: int = Field(gt=0)


class TokenResponse(Schema):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
