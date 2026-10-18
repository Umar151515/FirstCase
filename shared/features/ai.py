"""The agreed AI policy and the performer's disclosure are separate facts."""

from typing import Literal

from shared.core.exceptions import DomainError

AiPolicy = Literal["no_ai", "consultation", "ai_allowed"]
AiUsage = Literal["no_ai", "consultation", "ai_assisted"]


def validate_ai_usage(policy: str, usage: str, disclosure: str) -> None:
    allowed = {
        "no_ai": {"no_ai"},
        "consultation": {"no_ai", "consultation"},
        "ai_allowed": {"no_ai", "consultation", "ai_assisted"},
    }
    if usage not in allowed[policy]:
        raise DomainError("ai_policy_violation", 422, "ai_policy_violation")
    if usage != "no_ai" and not disclosure.strip():
        raise DomainError("ai_disclosure_required", 422, "ai_disclosure_required")
