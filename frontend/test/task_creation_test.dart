import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:firstcase/core/database/local_database.dart';
import 'package:firstcase/core/l10n/l10n.dart';
import 'package:firstcase/core/providers.dart';
import 'package:firstcase/features/tasks/presentation/task_form_page.dart';
import 'package:firstcase/shared/models/models.dart';
import 'package:firstcase/shared/widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

class _SignedIn extends SessionController {
  @override
  Future<Person?> build() async => Person(testUser);
}

void main() {
  testWidgets(
    'a task form waits for authentication before restoring a private draft',
    (tester) async {
      final database = LocalDatabase(NativeDatabase.memory());
      await database.write('personal_owner', 2);
      await database.write('task_draft', {
        'title': 'Private draft from the previous account',
      }, personal: true);
      final authenticated = Completer<ResponseBody>();
      final api = apiWith(
        TestTransport((request) async {
          if (request.path == '/auth/telegram') return authenticated.future;
          return jsonBody({'items': [], 'total': 0});
        }),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          apiProvider.overrideWithValue(api),
          telegramInitDataProvider.overrideWithValue('signed-init-data'),
        ],
      );
      late Future<Person?> login;
      await tester.runAsync(() async {
        login = container.read(sessionProvider.future);
        await Future<void>.delayed(Duration.zero);
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await database.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('ru'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: FTheme(
              data: FTheme.neutral.light.touch,
              child: const Scaffold(body: TaskFormPage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        authenticated.complete(
          jsonBody({'access_token': 'session', 'user': testUser}),
        );
        await login;
      });
      await tester.pumpAndSettle();
      final labels = AppLocalizations.of(
        tester.element(find.byType(TaskFormPage)),
      );
      final field = tester.widget<Field>(
        find.byWidgetPredicate(
          (widget) => widget is Field && widget.label == labels.taskTitle,
        ),
      );
      expect(field.controller.text, isEmpty);
      expect(await tester.runAsync(() => database.read('task_draft')), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty catalogue can be retried and a selected category is published',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = LocalDatabase(NativeDatabase.memory());
      await tester.runAsync(() => database.read('task_draft'));
      var available = false;
      Json? published;
      final api = apiWith(
        TestTransport((request) async {
          if (request.path == '/categories') {
            return jsonBody({
              'items': available
                  ? [
                      {'id': 12, 'name': 'Разработка', 'slug': 'development'},
                    ]
                  : [],
              'total': available ? 1 : 0,
            });
          }
          if (request.path == '/tasks' && request.method == 'POST') {
            published = Map<String, dynamic>.from(request.data as Map);
            return jsonBody({'id': 42}, 201);
          }
          throw StateError('Unexpected request ${request.path}');
        }),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          apiProvider.overrideWithValue(api),
          sessionProvider.overrideWith(_SignedIn.new),
        ],
      );
      await container.read(sessionProvider.future);
      final router = GoRouter(
        initialLocation: '/tasks/new',
        routes: [
          GoRoute(path: '/tasks/new', builder: (_, _) => const TaskFormPage()),
          GoRoute(
            path: '/tasks/:id',
            builder: (_, _) => const Text('Published task'),
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        container.dispose();
        await database.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('ru'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            builder: (_, child) => FTheme(
              data: FTheme.neutral.light.touch,
              child: Scaffold(body: child),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(TaskFormPage)));
      expect(find.text(l.chooseCategory), findsOneWidget);
      final publish = find.widgetWithText(FButton, l.publishTask);
      expect(tester.widget<FButton>(publish).onPress, isNull);
      available = true;
      await tester.ensureVisible(find.text(l.retry));
      await tester.tap(find.text(l.retry));
      await tester.pumpAndSettle();
      expect(find.text(l.chooseCategory), findsNothing);
      await tester.tap(find.text('Разработка'));
      await tester.pumpAndSettle();
      Future<void> fill(String label, String value) async {
        final input = find.descendant(
          of: find.byWidgetPredicate((w) => w is Field && w.label == label),
          matching: find.byType(EditableText),
        );
        await tester.ensureVisible(input);
        await tester.enterText(input, value);
      }

      await fill(l.taskTitle, 'Создать сайт для небольшой кофейни');
      await fill(
        l.taskDetailedDescription,
        'Нужен простой сайт с меню кофейни, контактами и временем работы.',
      );
      await fill(l.expectedResult, 'Рабочий сайт и инструкция по запуску');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(publish);
      await tester.pumpAndSettle();
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(published?['category_id'], 12);
      expect(published?['title'], 'Создать сайт для небольшой кофейни');
      expect(find.text('Published task'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
