# Проверка FirstCase

Дата: 18 октября 2026 года. Здесь перечислены выполненные команды и практические ограничения проверки.

## Backend и PostgreSQL

- `uv run python -m pytest shared/tests -q`: 59 passed до добавления отдельной проверки chunked upload.
- `uv run python -m pytest shared/tests/api/test_privacy.py::test_exact_privacy_consent_revocation_and_anonymous_redaction shared/tests/api/test_privacy.py::test_chunked_upload_cannot_bypass_body_limit -q`: 2 passed после последних изменений приватности и ограничения потока.
- `docker compose --profile test run --rm --build backend-test`: **60 passed**, Linux / Python 3.13.7, PostgreSQL 17.6.
- `uv run ruff check backend shared bot scripts alembic`: passed.
- `uv run ruff format --check backend shared bot scripts alembic`: 114 files already formatted.
- `uv run python -m compileall -q backend shared bot scripts alembic`: passed.
- `uv run alembic upgrade head`: initial migration применена к отдельной demo-БД.
- `uv run alembic check`: No new upgrade operations detected.

Проверен реальный API-сценарий: задача → отклик → выбор исполнителя → чат → сдача → правки → повторная сдача → принятие → обязательный отзыв → подтверждённое портфолио. Проверяются сохранённые ORM-данные и рейтинг. Отдельный тест запускает два конкурентных HTTP-запроса с независимыми транзакциями PostgreSQL: создаётся ровно один заказ.

Приватность проверяется для private / anonymous / public, точных согласий на сообщения и файлы, отзыва согласия, приватных загрузок, подмены ID вложения и доступа постороннего к чату. Администратор получает доказательства только в рамках конкретной жалобы; чтение файлов фиксируется в аудите. Проверяются блокировки, решения по жалобам и отсутствие production demo-эндпоинтов через реальные HTTP-запросы.

Telegram initData подписывается независимым кодом теста: проверены подпись, изменение данных, срок, будущая дата, повторяющиеся параметры и отсутствующие данные. Проверяются JWT-подпись и привязка токена к режиму. Тест outbox подтверждает, что ошибка Telegram не отменяет созданный заказ и что доставка повторяется после задержки.

Основная БД не очищается тестами. Используются отдельная `firstcase_test`, внешняя транзакция и savepoints; проверка имени БД запрещает основной URL. Тест конкурентного выбора создаёт и удаляет только собственную схему в test-БД.

## Docker и demo

- Docker Desktop / Linux engine запущен; Compose dev-конфигурация валидна.
- Собраны locked Python development/runtime и bot образы.
- PostgreSQL demo и test работают раздельно на localhost:5543 и localhost:5544.
- Demo backend работает на localhost:8000: `/health` и `/health/ready` возвращают 200, `/api/v1/config` возвращает demo.
- Реальные запросы к каталогу, авторизованным заказам, портфолио и уведомлениям прошли.
- QR PNG и текстовый результат скачаны из Docker volume с авторизацией.
- Seed → повторный seed → защищённый reset проверены на PostgreSQL: 16 пользователей, 6 категорий, 24 задачи, 34 отклика, 10 заказов, 20 сообщений, 4 отзыва, 4 кейса, 2 жалобы.
- Повторный seed восстанавливает отсутствующие fixture-файлы при переносе demo-БД в новый файловый volume.
- Production Compose отказывается запускаться с отсутствующими обязательными секретами.
- GNU Make в Windows-среде не установлен; эквивалентные команды Makefile выполнены напрямую через PowerShell / Docker Compose.

## Проверка реальных внешних интеграций

В этой среде не предоставлены настоящие Telegram Bot Token, аккаунт Telegram для входа и публичный HTTPS-домен. Поэтому вход внутри Telegram-клиента, отправка сообщения настоящему пользователю и внешнее production-развёртывание здесь не выполнялись. HMAC/JWT, production-разделение и обработка ошибок транспорта проверены автоматически; инструкция подключения находится в README.

## Flutter и браузер

- Flutter 3.47.3 stable, Dart 3.13.3; ForUI 0.27.6, Riverpod 3.4.3, Drift 2.35.2. Lock-файл сохранён.
- `flutter analyze`: No issues found.
- `flutter test --no-pub`: 14 passed. Проверены реальные локальные SQLite-операции, очистка кеша/черновиков при смене пользователя, гонка со старым сетевым ответом, MIME загрузок, сохранение имени/расширения скачиваемого файла, ошибки, формы и доступность навигации.
- `flutter build web --release --no-wasm-dry-run --dart-define=API_BASE_URL=/api/v1`: release JS build прошёл локально и в Docker/Linux.
- Docker Nginx на `http://localhost:8080`: SPA и API доступны, `sqlite3.wasm` имеет сигнатуру WASM и MIME `application/wasm`, worker JS доступен.
- Chromium 153: проверены desktop 1440×1080, mobile 390×844 и tablet 820×1050; светлая/тёмная темы. После перезагрузки тёмная тема восстановилась из Drift; browser OPFS содержит `drift_db`; `crossOriginIsolated=true`.
- Прямое открытие `/tasks` показывает каталог. Верхняя панель, demo-переключатель и нижняя мобильная навигация доступны в semantics tree.
- Окончательная Docker-сборка дополнительно проверена на `/orders/11`: участник видит исходные файлы задания и скачивает `brief.txt` с правильным содержимым и расширением; ошибок JavaScript нет. Backend, frontend и PostgreSQL прошли Compose healthchecks.
- Playwright провёл через реальный интерфейс полный сценарий с независимым переключением Айбек ↔ Нурбек: задача с TXT-вложением → поиск → отклик → выбор → старт → сообщение → сдача → запрос правки → повторная сдача с новым TXT-файлом → принятие → обязательный отзыв → анонимное портфолио.
- В PostgreSQL для созданного заказa #11 подтверждены `completed`, одна использованная правка, две версии результата, один отзыв и один кейс. Публичный API кейса #5 не раскрывает заказчика, source ID, текст отзыва, переписку или файлы. В проходе нет page errors и HTTP-ошибок API.

После браузерного прохода в demo сохранены дополнительная задача #25, завершённый заказ #11 и подтверждённый анонимный кейс #5. Это реальные сохранённые данные, доступные для просмотра. Документированная команда reset возвращает исходный seed.

Flutter собирается в JavaScript: optional WASM dry-run отключён из-за JS interop зависимости flutter_telegram_miniapp 0.1.2. Это не отключает SQLite WASM Drift. Проверка в настоящем Telegram WebView, Safari и Firefox не выполнялась.

Снимки проверенного интерфейса: [desktop](screenshots/desktop.png), [mobile light](screenshots/mobile-light.png), [mobile dark](screenshots/mobile-dark.png), [подтверждённый анонимный кейс](screenshots/verified-case.png).

## Первичные источники

- [Проверка Telegram Mini App initData](https://core.telegram.org/bots/webapps#validating-data-received-via-the-mini-app).
- [Транзакции SQLAlchemy и интеграция Session с внешней транзакцией теста](https://docs.sqlalchemy.org/en/20/orm/session_transaction.html#joining-a-session-into-an-external-transaction-such-as-for-test-suites).
- API Flutter-зависимостей дополнительно сверены с установленными исходниками из pub cache и официальными страницами pub.dev; точные версии зафиксированы в `frontend/pubspec.lock`.
