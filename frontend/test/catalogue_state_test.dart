import 'package:drift/native.dart';
import 'package:firstcase/app/app.dart';
import 'package:firstcase/core/api/api_client.dart';
import 'package:firstcase/core/database/local_database.dart';
import 'package:firstcase/core/l10n/l10n.dart';
import 'package:firstcase/core/providers.dart';
import 'package:firstcase/features/tasks/data/task_repository.dart';
import 'package:firstcase/features/tasks/presentation/tasks_page.dart';
import 'package:firstcase/shared/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

class _RecordingTasks extends TaskRepository {
  _RecordingTasks(super.api, super.cache);

  final List<String> paths = [];

  @override
  Future<List<Json>> categories() async => [];

  @override
  Future<dynamic> resource(String path) async {
    paths.add(path);
    return {'items': <Json>[], 'total': 0};
  }
}

void main() {
  testWidgets(
    'a date filter keeps the same request across unrelated rebuilds',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = LocalDatabase(NativeDatabase.memory());
      final repository = _RecordingTasks(ApiClient(), database);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        repository.api.dio.close();
        await database.close();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [taskRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            locale: const Locale('ru'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: FTheme(
              data: FTheme.neutral.light.touch,
              child: const Scaffold(body: TasksPage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final labels = AppLocalizations.of(
        tester.element(find.byType(TasksPage)),
      );
      await tester.tap(find.byIcon(FLucideIcons.slidersHorizontal));
      await tester.pumpAndSettle();
      await tester.tap(find.text(labels.lastWeek));
      await tester.pumpAndSettle();
      expect(
        Uri.parse(repository.paths.last).queryParameters['created_after'],
        isNotNull,
      );
      final filteredRequests = repository.paths.length;
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byIcon(FLucideIcons.slidersHorizontal));
      await tester.pumpAndSettle();
      expect(repository.paths.length, filteredRequests);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid resource IDs display a missing page without crashing', (
    tester,
  ) async {
    final database = LocalDatabase(NativeDatabase.memory());
    final api = apiWith(
      TestTransport(
        (request) async => jsonBody(
          request.path == '/config'
              ? {'mode': 'production'}
              : {'items': [], 'total': 0},
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(api),
        databaseProvider.overrideWithValue(database),
        appInitialLocationProvider.overrideWithValue('/tasks/invalid'),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await database.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FirstCaseApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(routerProvider);
    final labels = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    for (final path in [
      '/tasks/invalid',
      '/tasks/invalid/edit',
      '/orders/abc',
      '/users/0',
      '/portfolio/-1',
      '/tasks/999999999999999999999999999999999999',
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.text(labels.pageNotFound), findsOneWidget, reason: path);
      expect(tester.takeException(), isNull, reason: path);
    }
  });
}
