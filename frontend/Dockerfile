FROM debian:bookworm-slim@sha256:7c7b2c966bc9ee8cedfeef67e0e279108992c77681fa595db4a9d65c06ccc587 AS build
ARG FLUTTER_VERSION=3.47.3
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils libglu1-mesa && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics && flutter precache --web
WORKDIR /app
COPY frontend/pubspec.yaml frontend/pubspec.lock ./
RUN flutter pub get --enforce-lockfile
COPY frontend/ ./
ARG API_BASE_URL=/api/v1
ARG APP_MODE=demo
RUN flutter build web --release --no-wasm-dry-run --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236 AS runtime
COPY frontend/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
