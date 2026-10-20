# FirstCase Flutter Web

Русский marketplace интерфейс на Flutter 3.47.3 / Dart 3.13.3. Используются ForUI,
Riverpod 3, GoRouter, Dio и Drift. Установка и запуск всего проекта описаны в
[основном README](../README.md).

```powershell
flutter pub get --enforce-lockfile
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8000/api/v1
flutter build web --release --no-wasm-dry-run --dart-define=API_BASE_URL=/api/v1
```

`web/sqlite3.wasm` и `web/drift_worker.js` соответствуют Drift 2.35.2. Nginx
выдаёт WASM с правильным MIME и COOP/COEP. При недоступности browser storage
работа с API продолжается. PostgreSQL — источник серверных данных.

Приватный кеш и черновики очищаются при смене идентичности; ответы старых
запросов не могут повторно заполнить кеш новой сессии. Настройка темы сохраняется.
В обычном браузере маршруты используют обычные URL. В Telegram Mini App
начальный адрес `/tasks` или `/orders/{id}` сохраняется при запуске, а последующие
переходы выполняет GoRouter без изменения URL встроенного окна (`setUrlStrategy(null)`).
Telegram initData считывается один раз до настройки навигации. Сервер должен
возвращать `index.html` для маршрутов SPA и проксировать `/api/` в FastAPI.

Для диагностики доступна панель «Проверка переходов», включаемая только явным
параметром `?diagnostics=1`. Она отдельно отражает запрошенный маршрут, перенаправление
и фактически открытый экран. В отчёт не включаются query/hash, идентификаторы
заказов, initData или содержимое форм. JavaScript-тесты: `node --test tool/input_diagnostics_test.cjs`.
Проверки переходов через кнопки настоящего production-интерфейса находятся
в `test/navigation_test.dart`; они не заменяют ручную проверку внутри Telegram.

Flutter собирается в JavaScript. `--no-wasm-dry-run` отключает необязательную
проверку компиляции Flutter в WASM: flutter_telegram_miniapp 0.1.2 содержит
несовместимый с ней JS interop. SQLite WASM для Drift работает независимо от
выбранного Flutter renderer.
