FROM ghcr.io/astral-sh/uv:0.8.22@sha256:9874eb7afe5ca16c363fe80b294fe700e460df29a55532bbfea234a0f12eddb1 AS uv

FROM python:3.13.7-slim-bookworm@sha256:adafcc17694d715c905b4c7bebd96907a1fd5cf183395f0ebc4d3428bd22d92d AS base
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 UV_PROJECT_ENVIRONMENT=/opt/venv UV_LINK_MODE=copy PATH="/opt/venv/bin:$PATH"
WORKDIR /app
COPY --from=uv /uv /uvx /usr/local/bin/

FROM base AS dependencies
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv uv sync --locked --no-dev --no-install-project

FROM base AS development
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv uv sync --locked --no-install-project
COPY . .
CMD ["python", "-m", "scripts.run_backend", "--reload"]

FROM base AS runtime
RUN groupadd --gid 10001 firstcase && useradd --uid 10001 --gid firstcase --create-home firstcase && mkdir -p /data/uploads && chown firstcase:firstcase /data/uploads
COPY --from=dependencies /opt/venv /opt/venv
COPY backend ./backend
COPY shared ./shared
COPY bot ./bot
COPY scripts ./scripts
COPY alembic ./alembic
COPY alembic.ini ./
USER firstcase
EXPOSE 8000
CMD ["python", "-m", "scripts.run_backend"]
