from fastapi import APIRouter

from backend.api.v1.admin.routes import router as admin_router
from backend.api.v1.applications.routes import router as applications_router
from backend.api.v1.auth.routes import demo_router
from backend.api.v1.auth.routes import router as auth_router
from backend.api.v1.chat.routes import router as chat_router
from backend.api.v1.notifications.routes import router as notifications_router
from backend.api.v1.orders.routes import router as orders_router
from backend.api.v1.portfolio.routes import router as portfolio_router
from backend.api.v1.reports.routes import router as reports_router
from backend.api.v1.reviews.routes import router as reviews_router
from backend.api.v1.tasks.routes import router as tasks_router
from backend.api.v1.tips.routes import router as tips_router
from backend.api.v1.uploads.routes import router as uploads_router
from backend.api.v1.users.routes import router as users_router


def create_router(mode: str) -> APIRouter:
    router = APIRouter(prefix="/api/v1")
    for feature in (
        auth_router,
        users_router,
        tasks_router,
        applications_router,
        orders_router,
        chat_router,
        reviews_router,
        portfolio_router,
        tips_router,
        uploads_router,
        reports_router,
        notifications_router,
        admin_router,
    ):
        router.include_router(feature)
    if mode == "demo":
        router.include_router(demo_router)

    @router.get("/config", tags=["configuration"])
    async def config() -> dict[str, str]:
        return {"mode": mode}

    return router
