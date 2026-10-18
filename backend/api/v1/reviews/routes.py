from fastapi import APIRouter, Query

from backend.api.dependencies import CurrentUser, Session
from shared.features.common import Page
from shared.features.orders.services import OrderService
from shared.features.reviews.models import Review
from shared.features.reviews.schemas import ReviewCreate, ReviewOut
from shared.features.reviews.services import ReviewService

router = APIRouter(tags=["reviews"])


@router.get("/orders/{identifier}/reviews", response_model=Page[ReviewOut])
async def reviews(
    identifier: int,
    user: CurrentUser,
    session: Session,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
):
    await OrderService(session).participant(identifier, user.id)
    items, total = await ReviewService(session).repository.list(
        Review.order_id == identifier, offset=offset, limit=limit
    )
    return {"items": items, "total": total}


@router.post("/orders/{identifier}/reviews", response_model=ReviewOut, status_code=201)
async def review(identifier: int, data: ReviewCreate, user: CurrentUser, session: Session):
    return await ReviewService(session).create(identifier, user.id, data)
