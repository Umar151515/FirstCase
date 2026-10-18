import 'package:flutter_telegram_miniapp/flutter_telegram_miniapp.dart';

String? telegramInitData() {
  try {
    final app = WebApp();
    if (!app.isSupported) return null;
    app.init();
    app.ready();
    app.expand();
    return app.initData;
  } catch (_) {
    return null;
  }
}

bool? telegramDark() {
  try {
    return WebApp().isSupported ? WebApp().colorScheme.name == 'dark' : null;
  } catch (_) {
    return null;
  }
}

Stream<bool> get telegramThemeChanges {
  try {
    return WebApp().eventHandler.themeChanged.map((e) => e.$1.name == 'dark');
  } catch (_) {
    return const Stream.empty();
  }
}
