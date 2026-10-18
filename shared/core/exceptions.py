from typing import Any

from shared.core.i18n import translate


class DomainError(Exception):
    def __init__(
        self,
        message: str,
        status_code: int = 400,
        code: str = "invalid_request",
        details: Any = None,
    ):
        super().__init__(message)
        self.key = message
        self.status_code = status_code
        self.code = code
        self.details = details

    @property
    def message(self) -> str:
        return translate(self.key)


def missing(message: str = "not_found") -> DomainError:
    return DomainError(message, 404, "not_found")


def forbidden(message: str = "forbidden") -> DomainError:
    return DomainError(message, 403, "forbidden")


def conflict(message: str) -> DomainError:
    return DomainError(message, 409, "invalid_state")
