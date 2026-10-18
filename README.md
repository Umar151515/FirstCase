# FirstCase

**Первый заказ. Первый кейс. Реальная репутация.** Платформа первого профессионального опыта для Бишкека: бесплатные задачи и добровольные чаевые, реальный рабочий чат, обязательный отзыв заказчика и подтверждённые кейсы с контролем приватности.

## Быстрый запуск demo

Нужны Docker Desktop с Linux containers и Docker Compose v2. Бот и Telegram-аккаунт для demo не нужны. Первичная сборка Flutter скачивает SDK и пакеты, поэтому требует интернета и нескольких гигабайт свободного места.

PowerShell из корня проекта:

```powershell
Copy-Item .env.example .env
docker compose up -d --build postgres backend frontend
docker compose ps
```

Или GNU Make: `make demo`. Откройте **http://localhost:8080**. Backend доступен на http://localhost:8000, OpenAPI — http://localhost:8000/docs, проверка состояния — http://localhost:8000/health.

Backend при старте применяет Alembic migrations, затем один раз создаёт demo-набор. Повторный запуск сохраняет изменения пользователей. Данные PostgreSQL и загруженные файлы находятся в отдельных Docker volumes и переживают `docker compose down`.

Порты по умолчанию: frontend `8080`, API `8000`, demo PostgreSQL `5543`, test PostgreSQL `5544`. Они намеренно не совпадают со старым Silk-Fetch. Если порт занят, поменяйте соответствующий `*_PORT` в `.env`; при локальном запуске Python также измените порт в `DATABASE_URL`/`TEST_DATABASE_URL`.

## Сценарий для демонстрации

В панели **«Войти как…»** выберите Айбека или Алину, создайте задачу. Переключитесь на Нурбека, Диану или Тимура и отправьте отклик. Вернитесь к заказчику и выберите исполнителя. В аккаунте исполнителя откройте заказ, начните работу, напишите в чат, загрузите файл и сдайте результат. Заказчик может запросить правки или принять результат; успешное завершение требует его отзыва. Исполнитель затем самостоятельно создаёт кейс и выбирает private, anonymous или public.

Переключатель получает отдельный серверный JWT для текущего браузера. Все изменения проходят через тот же API и сервисы, что и production, и сохраняются в PostgreSQL. Production не регистрирует demo endpoints.

Seed содержит 16 пользователей, 6 категорий и 24 задачи на русском языке. Есть отклики, 10 заказов в разных состояниях, переписка, реальные вложения, 3 завершённых заказа с отзывами и подтверждёнными кейсами, обычная работа без подтверждения, QR-настройки, жалобы и администратор. Демо QR ведёт на безопасный пример `example.org` и **не предназначен для оплаты**.

Перед выступлением:

```powershell
docker compose exec backend python -m scripts.reset_demo --confirm firstcase_demo
```

Или `make reset-demo`. Эта команда удаляет изменения demo, восстанавливает первоначальные данные и инвалидирует смысл старых открытых карточек; после сброса переключите аккаунт заново и обновите страницу. Отдельный seed: `docker compose exec backend python -m scripts.seed_demo` / `make seed-demo`.

Reset разрешён только при `APP_MODE=demo`, точном имени БД `firstcase_demo`, корректном маркере владения, созданном seed, и отсутствии реальных пользователей. Скрипт не удаляет базы, схемы или неизвестные каталоги. Он очищает только таблицы приложения и принадлежащие им файлы. Seed отказывается присваивать demo-маркер уже заполненной чужой базе.

## Разработка без контейнера приложения

Требуются Python 3.13, [uv](https://docs.astral.sh/uv/getting-started/installation/) и Flutter SDK версии, указанной в `frontend/Dockerfile`/`frontend/pubspec.yaml`.

```powershell
Copy-Item .env.example .env
docker compose up -d postgres
docker compose --profile test up -d test-postgres
uv sync --locked
uv run alembic upgrade head
uv run python -m scripts.seed_demo
uv run uvicorn backend.main:app --host 127.0.0.1 --port 8000 --reload
```

В другом терминале:

```powershell
Set-Location frontend
flutter pub get --enforce-lockfile
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

`CORS_ORIGINS` и `ADMIN_TELEGRAM_IDS` — строки через запятую, без JSON-скобок. `UPLOAD_DIR` задаёт локальный каталог файлов; его содержимое нельзя публиковать как открытый static directory. API проверяет доступ к каждому приватному вложению. Секреты хранятся только в `.env` и не попадают в Git или Docker build context.

`make dev` запускает контейнеры в foreground с Python hot reload. Горячий reload Flutter доступен через `flutter run`. Для ручной миграции: `uv run alembic upgrade head` или `make migrate`. Изменение схемы оформляется новой ревизией Alembic, затем проверяется на отдельной test-БД.

## Telegram-бот и настоящая авторизация

Создайте бота через [@BotFather](https://t.me/BotFather), задайте `TELEGRAM_BOT_TOKEN` и `TELEGRAM_BOT_USERNAME`. Для Telegram Mini App нужен доступный **HTTPS** адрес frontend. Настройте Menu Button / Main Mini App в BotFather на этот адрес. Установите `PUBLIC_WEBAPP_URL=https://ваш-домен`, `API_PUBLIC_URL=https://ваш-домен` и точный origin в `CORS_ORIGINS`.

Flutter отправляет сырой `initData` серверу. Сервер проверяет HMAC и срок действия, а роль администратора вычисляет по `ADMIN_TELEGRAM_IDS`, например `123456789,987654321`. Идентичность из `initDataUnsafe` не используется для авторизации.

Запуск бота в dev:

```powershell
docker compose --profile bot up -d --build bot
```

Локально: `uv run python -m bot.main`. Команды `/start`, `/help`, `/profile`, `/tasks` работают через общие сервисы; WebApp-кнопки открывают соответствующие страницы. Нельзя запускать два polling-процесса с одним токеном.

Уведомления сохраняются вместе с бизнес-изменением в таблице `notifications`. Отдельный цикл бота забирает их короткими lease с `SKIP LOCKED` и повторяет неудачные отправки с задержкой. Сбой Telegram не откатывает заказ или сообщение. Доставка допускает повтор уведомления после аварии между успешной отправкой и записью результата; это обычная гарантия «как минимум один раз». Demo-идентичности никогда не получают Telegram-уведомления. Бот должен иметь открытый личный чат с пользователем, чтобы отправлять ему сообщения.

## Production

Production запускается **отдельным** Compose-файлом и отдельным project name; не объединяйте его с dev override. Исходники не монтируются, demo seed не запускается, debug и demo-auth отключены сервером. API и PostgreSQL не публикуются наружу; frontend слушает только loopback для внешнего TLS reverse proxy.

Создайте исключённый из Git `.env.production`:

```env
APP_MODE=production
DEBUG=false
POSTGRES_PASSWORD=replace-with-unique-url-safe-password
DATABASE_URL=postgresql+asyncpg://firstcase:replace-with-unique-url-safe-password@postgres:5432/firstcase_production
JWT_SECRET=replace-with-independent-random-secret-at-least-32-characters
TELEGRAM_BOT_TOKEN=your-real-bot-token
TELEGRAM_BOT_USERNAME=your_bot_username
ADMIN_TELEGRAM_IDS=your_numeric_telegram_id
PUBLIC_WEBAPP_URL=https://firstcase.example
API_PUBLIC_URL=https://firstcase.example
CORS_ORIGINS=https://firstcase.example
MAX_UPLOAD_SIZE_MB=10
WEB_PORT=8080
```

Сгенерируйте независимые секреты, например `uv run python -c "import secrets; print(secrets.token_urlsafe(48))"`. Для пароля используйте URL-safe значение или корректно кодируйте пароль в `DATABASE_URL`. Compose требует непустые production-секреты, а сервер дополнительно запрещает demo JWT secret, debug, demo database и незащищённый WebApp URL.

```powershell
docker compose --env-file .env.production -f docker-compose.prod.yml config --quiet
docker compose --env-file .env.production -f docker-compose.prod.yml up -d --build
docker compose --env-file .env.production -f docker-compose.prod.yml ps
```

Или `make prod`. Настройте Nginx/Caddy на сервере с действительным TLS-сертификатом и проксированием HTTPS домена на `127.0.0.1:8080`. Передавайте `Host`, `X-Forwarded-Proto` и `X-Forwarded-For`; лимит тела запроса установите не ниже `MAX_UPLOAD_SIZE_MB`. Внутренний frontend Nginx обслуживает Flutter SPA и проксирует `/api/` на backend. Telegram требует сертификат доверенного удостоверяющего центра.

Перед обновлением делайте `pg_dump` production-БД и копию volume `uploads`. Миграции применяются при старте backend; разворачивайте один backend во время миграции, затем масштабируйте после успешного healthcheck. Восстановление БД и файлов должно выполняться согласованно. Не используйте `down -v` для среды с нужными данными.

## Проверки

```powershell
docker compose --profile test run --rm --build backend-test
uv run ruff check backend shared bot scripts
uv run ruff format --check backend shared bot scripts
Set-Location frontend
flutter analyze
flutter test
flutter build web --release --no-wasm-dry-run --dart-define=API_BASE_URL=/api/v1
```

Или `make test`, `make test-backend`, `make test-frontend`, `make lint`. Backend-тесты используют PostgreSQL `firstcase_test` и savepoints с rollback. Проверка URL отказывается подключаться к основной БД как к тестовой. Тестовая БД в Compose использует tmpfs и не содержит пользовательских данных.

Фактически выполненные проверки, версии и ограничения среды фиксируются отдельно в [docs/verification.md](docs/verification.md). Команды выше — воспроизводимые инструкции; их наличие само по себе не означает, что каждая проверка уже прошла.

## Устройство проекта

`shared/core` содержит конфигурацию, сессию БД, безопасность, storage и общие ошибки. `shared/features` — модели, repositories и сервисы конкретных функций. Роутеры `backend/api/v1` остаются транспортным слоем; `bot` отдельно собирает зависимости aiogram из тех же сервисов. Flutter организован по функциям, API вызывается через repositories, состояние — Riverpod 3. Drift кеширует серверные данные и черновики; PostgreSQL остаётся источником истины, а пользовательский кеш очищается при смене аккаунта.

Архитектурный образец Silk-Fetch изучен из доступного локального Docker-образа: database/session DI, repository/service и savepoint test fixtures. Его исходная папка отсутствовала. Бизнес-логика старого проекта и Redis не переносились.

Контракт API: [docs/api-contract.md](docs/api-contract.md). Платежи внутри FirstCase отсутствуют: сервис не принимает деньги и не подтверждает перевод по QR. Публикация личности заказчика, выбранных сообщений и файлов требует отдельных согласий; private-кейс никогда не становится публичным автоматически.
