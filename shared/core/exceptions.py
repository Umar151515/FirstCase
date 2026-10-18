from typing import Any


class DomainError(Exception):
    def __init__(
        self,
        message: str,
        status_code: int = 400,
        code: str = "invalid_request",
        details: Any = None,
    ):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.code = code
        self.details = details


def missing(message: str = "Ресурс не найден") -> DomainError:
    return DomainError(message, 404, "not_found")


def forbidden(message: str = "Недостаточно прав") -> DomainError:
    return DomainError(message, 403, "forbidden")


def conflict(message: str) -> DomainError:
    return DomainError(message, 409, "invalid_state")
