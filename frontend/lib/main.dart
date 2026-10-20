import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/input_diagnostics/input_diagnostics.dart';
import 'core/providers.dart';
import 'core/telegram/telegram.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installInputDiagnostics();
  // Capture Telegram authentication before navigation can change its URL hash.
  final initData = telegramInitData();
  final miniApp = initData?.isNotEmpty ?? false;
  var initialLocation = '/';
  if (miniApp) {
    final launchUri = Uri.base;
    initialLocation = Uri(
      path: launchUri.path.isEmpty ? '/' : launchUri.path,
      query: launchUri.hasQuery ? launchUri.query : null,
    ).toString();
    // Keep the host WebView URL intact; GoRouter still changes its page stack.
    setUrlStrategy(null);
  } else {
    usePathUrlStrategy();
  }
  recordNavigation('mode', miniApp ? 'embedded' : 'browser');
  await initializeDateFormatting('ru');
  await initializeDateFormatting('ky');
  runApp(
    ProviderScope(
      retry: (count, error) => null,
      overrides: [
        telegramInitDataProvider.overrideWithValue(initData),
        appInitialLocationProvider.overrideWithValue(initialLocation),
      ],
      child: const FirstCaseApp(),
    ),
  );
}
