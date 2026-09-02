# syntax=docker/dockerfile:1.7
FROM node:24.20.0-bookworm-slim AS frontend
WORKDIR /build
RUN corepack enable
COPY app/frontend/package.json app/frontend/pnpm-lock.yaml ./
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile
COPY app/frontend/ ./
RUN pnpm build

FROM ghcr.io/astral-sh/uv:0.12.9 AS uv

FROM python:3.13.15-slim-bookworm AS runtime
ARG APP_VERSION=dev
ENV APP_ENV=production \
    APP_VERSION=${APP_VERSION} \
    AWS_LWA_PORT=8080 \
    AWS_LWA_READINESS_CHECK_PATH=/healthz \
    PATH=/app/.venv/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app

COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:1.0.1 \
    /lambda-adapter /opt/extensions/lambda-adapter
COPY --from=uv /uv /uvx /bin/
COPY app/backend/pyproject.toml app/backend/uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project
COPY app/backend/src ./src
COPY --from=frontend /build/dist/frontend/browser ./static
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev && \
    /usr/local/bin/python -m pip uninstall --yes pip && \
    rm -f /bin/uv /bin/uvx

EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=2s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz')"
CMD ["gunicorn", "--bind=0.0.0.0:8080", "--workers=2", "--threads=4", "--access-logfile=-", "palladium:create_app()"]
