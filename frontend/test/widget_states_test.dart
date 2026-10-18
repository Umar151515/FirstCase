import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:firstcase/app/app.dart';
import 'package:firstcase/core/database/local_database.dart';
import 'package:firstcase/core/providers.dart';
import 'package:firstcase/core/l10n/l10n.dart';
import 'package:firstcase/shared/widgets/ui.dart';

import 'support.dart';

Widget harness(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      retry: (count, error) => null,
      child: MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: FTheme(
          data: FTheme.neutral.light.touch,
          child: Scaffold(body: child),
        ),
      ),
    );

void main() {
  testWidgets(
    'task field validates minimum length and accepts meaningful input',
    (tester) async {
      final controller = TextEditingController();
      final key = GlobalKey<FormState>();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(
          Form(
            key: key,
            child: Field('Название задачи', controller, minLength: 5),
          ),
        ),
      );
      expect(key.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(
        find.text('Введите минимум 5 символов', findRichText: true),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(EditableText),
        'Telegram-бот для кофейни',
      );
      expect(key.currentState!.validate(), isTrue);
    },
  );

  testWidgets('empty state gives clear next step', (tester) async {
    await tester.pumpWidget(
      harness(
        const StateMessage(
          'Пока нет задач',
          subtitle: 'Создайте первую задачу',
        ),
      ),
    );
    expect(find.text('Пока нет задач'), findsOneWidget);
    expect(find.text('Создайте первую задачу'), findsOneWidget);
  });

  testWidgets('resource transitions from skeleton to error and retries', (
    tester,
  ) async {
    final pending = Completer<dynamic>();
    int calls = 0;
    await tester.pumpWidget(
      harness(
        ResourceView('/test', builder: (_) => const Text('Готово')),
        overrides: [
          resourceProvider('/test').overrideWith((ref) {
            calls++;
            return pending.future;
          }),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(LoadingView), findsOneWidget);
    pending.completeError(Exception('Нет сети'));
    await tester.pumpAndSettle();
    expect(find.text('Не получилось загрузить'), findsOneWidget);
    await tester.tap(find.text('Попробовать снова'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('real GoRouter opens task catalogue route', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = LocalDatabase(NativeDatabase.memory());
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
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FirstCaseApp(),
      ),
    );
    container.read(routerProvider).go('/tasks');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(PageTitle),
        matching: find.text('Задачи'),
      ),
      findsOneWidget,
    );
    expect(find.text('Пока ничего не нашлось'), findsOneWidget);
    final accessibilityTree = tester
        .binding
        .renderViews
        .first
        .owner!
        .semanticsOwner!
        .rootSemanticsNode!
        .toStringDeep();
    expect(accessibilityTree, contains('Войти'));
    expect(accessibilityTree, contains('Переключить тему'));
    expect(accessibilityTree, contains('Задачи'));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
