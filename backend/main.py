import logging
import time
from collections import defaultdict, deque
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from starlette.exceptions import HTTPException

import shared.models  # noqa: F401
from backend.api.dependencies import Session
from backend.api.middleware import BodyLimitMiddleware
from backend.api.router import create_router
from shared.core.config import Settings, get_settings
from shared.core.database import engine
from shared.core.dependencies import get_session
from shared.core.exceptions import DomainError
from shared.core.logging import configure_logging

logger = logging.getLogger("firstcase")


def error_response(status: int, code: str, message: str, details=None):
    body = {"error": {"code": code, "message": message}}
    if details is not None:
        body["error"]["details"] = details
    return JSONResponse(body, status_code=status)


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    app_engine = (
        engine
        if settings.database_url == get_settings().database_url
        else create_async_engine(settings.database_url, pool_pre_ping=True)
    )

    @asynccontextmanager
    async def lifespan(application: FastAPI):
        configure_logging()
        yield
        await app_engine.dispose()

    app = FastAPI(
        title="FirstCase API",
        version="1.0.0",
        lifespan=lifespan,
        debug=False,
        docs_url="/docs" if settings.app_mode == "demo" else None,
        redoc_url=None,
        openapi_url="/openapi.json" if settings.app_mode == "demo" else None,
    )
    app.state.settings = settings
    app.state.engine = app_engine
    if app_engine is not engine:
        factory = async_sessionmaker(app_engine, expire_on_commit=False)

        async def configured_session():
            async with factory() as session, session.begin():
                yield session

        app.dependency_overrides[get_session] = configured_session
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.origins,
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "PATCH", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type"],
        expose_headers=["Content-Disposition"],
    )
    app.add_middleware(BodyLimitMiddleware, maximum=(settings.max_upload_size_mb + 1) * 1024 * 1024)
    buckets: dict[tuple, deque] = defaultdict(deque)

    @app.middleware("http")
    async def request_limits(request: Request, call_next):
        length = request.headers.get("content-length")
        if length:
            try:
                if int(length) > (settings.max_upload_size_mb + 1) * 1024 * 1024:
                    return error_response(
                        413, "request_too_large", "Запрос превышает допустимый размер"
                    )
            except ValueError:
                return error_response(400, "invalid_request", "Некорректный Content-Length")
        if request.method in {"POST", "PATCH", "PUT", "DELETE"}:
            now = time.monotonic()
            sensitive = request.url.path.startswith("/api/v1/auth/")
            key = (
                request.client.host if request.client else "unknown",
                "auth" if sensitive else "write",
            )
            bucket = buckets[key]
            while bucket and bucket[0] < now - 60:
                bucket.popleft()
            if len(bucket) >= (
                settings.auth_rate_limit if sensitive else settings.write_rate_limit
            ):
                response = error_response(
                    429, "rate_limited", "Слишком много запросов. Попробуйте через минуту"
                )
                response.headers["Retry-After"] = "60"
                return response
            bucket.append(now)
            if len(buckets) > 10000:
                for old_key in list(buckets):
                    if not buckets[old_key] or buckets[old_key][-1] < now - 60:
                        del buckets[old_key]
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Cache-Control"] = "no-store"
        return response

    @app.exception_handler(DomainError)
    async def domain_error(request: Request, exc: DomainError):
        return error_response(exc.status_code, exc.code, exc.message, exc.details)

    @app.exception_handler(RequestValidationError)
    async def validation_error(request: Request, exc: RequestValidationError):
        details = [
            {"loc": list(e["loc"]), "message": e["msg"], "type": e["type"]} for e in exc.errors()
        ]
        return error_response(422, "validation_error", "Проверьте введённые данные", details)

    @app.exception_handler(IntegrityError)
    async def integrity_error(request: Request, exc: IntegrityError):
        return error_response(409, "conflict", "Операция конфликтует с текущим состоянием данных")

    @app.exception_handler(HTTPException)
    async def http_error(request: Request, exc: HTTPException):
        return error_response(exc.status_code, "http_error", str(exc.detail))

    @app.exception_handler(Exception)
    async def unexpected_error(request: Request, exc: Exception):
        logger.error(
            "Request failed: %s %s (%s)", request.method, request.url.path, type(exc).__name__
        )
        return error_response(500, "internal_error", "Внутренняя ошибка сервера")

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/health/ready")
    async def ready(session: Session) -> dict[str, str]:
        await session.execute(text("SELECT 1"))
        return {"status": "ok", "database": "reachable"}

    app.include_router(create_router(settings.app_mode))
    return app


app = create_app()
