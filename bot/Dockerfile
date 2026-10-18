FROM ghcr.io/astral-sh/uv:0.8.22@sha256:9874eb7afe5ca16c363fe80b294fe700e460df29a55532bbfea234a0f12eddb1 AS uv
FROM python:3.13.7-slim-bookworm@sha256:adafcc17694d715c905b4c7bebd96907a1fd5cf183395f0ebc4d3428bd22d92d AS builder
WORKDIR /app
COPY --from=uv /uv /usr/local/bin/
COPY pyproject.toml uv.lock ./
ENV UV_PROJECT_ENVIRONMENT=/opt/venv UV_LINK_MODE=copy
RUN --mount=type=cache,target=/root/.cache/uv uv sync --locked --no-dev --no-install-project

FROM python:3.13.7-slim-bookworm@sha256:adafcc17694d715c905b4c7bebd96907a1fd5cf183395f0ebc4d3428bd22d92d AS runtime
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 PATH="/opt/venv/bin:$PATH"
RUN groupadd --gid 10001 firstcase && useradd --uid 10001 --gid firstcase --create-home firstcase
COPY --from=builder /opt/venv /opt/venv
COPY bot ./bot
COPY shared ./shared
USER firstcase
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 CMD ["python", "-c", "import pathlib,tempfile,time; p=pathlib.Path(tempfile.gettempdir())/'firstcase-bot-heartbeat'; assert p.exists() and time.time()-p.stat().st_mtime < 240"]
CMD ["python", "-m", "bot.main"]
