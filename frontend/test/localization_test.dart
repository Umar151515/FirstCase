import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:firstcase/core/api/api_client.dart';
import 'package:firstcase/core/database/local_database.dart';
import 'package:firstcase/core/l10n/l10n.dart';
import 'package:firstcase/core/l10n/generated/app_localizations_ky.dart';
import 'package:firstcase/core/l10n/generated/app_localizations_ru.dart';
import 'package:firstcase/core/providers.dart';
import 'package:firstcase/features/tasks/data/task_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import 'support.dart';

void main() {
  test(
    'Russian plurals and Kyrgyz count messages preserve their arguments',
    () {
      final ru = AppLocalizationsRu();
      final ky = AppLocalizationsKy();
      expect(ru.applicationCount(1), '1 отклик');
      expect(ru.applicationCount(2), '2 отклика');
      expect(ru.applicationCount(5), '5 откликов');
      expect(ky.applicationCount(1), '1 өтүнмө');
      expect(ky.applicationCount(21), '21 өтүнмө');
      expect(ky.customerLabel('Айбек'), 'Буйрутмачы: Айбек');
      expect(ky.mediaFileLabel(42), 'Файл №42');
    },
  );

  test('language selection persists across accounts and container restarts', () async {
    final database = LocalDatabase(NativeDatabase.memory());
    final first = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    await first.read(localeProvider.notifier).select(const Locale('ky'));
    await database.wipePersonal();
    expect(await database.read('locale'), 'ky');
    first.dispose();
    final second = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    second.read(localeProvider);
    // Wait for the same SQLite queue used by the provider's restore operation.
    await database.read('locale');
    await Future<void>.delayed(Duration.zero);
    expect(second.read(localeProvider).languageCode, 'ky');
    second.dispose();
    await database.close();
  });

  test(
    'changing language keeps authorization and updates request headers',
    () async {
      final database = LocalDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      final api = container.read(apiProvider)..token = 'existing-session';
      final transport = TestTransport(
        (request) async => jsonBody({'items': []}),
      );
      api.dio.httpClientAdapter = transport;
      api.dio.options.baseUrl = 'https://firstcase.test/api/v1';
      await container.read(localeProvider.notifier).select(const Locale('ky'));
      expect(container.read(apiProvider), same(api));
      expect(api.token, 'existing-session');
      await api.request('/categories');
      expect(transport.requests.single.headers['Accept-Language'], 'ky');
      expect(
        transport.requests.single.headers['Authorization'],
        'Bearer existing-session',
      );
      container.dispose();
      await database.close();
    },
  );

  test('offline resources never reuse a different language cache', () async {
    final database = LocalDatabase(NativeDatabase.memory());
    var offline = false;
    final transport = TestTransport((request) async {
      if (offline) {
        throw DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
        );
      }
      return jsonBody({
        'items': [],
        'language': request.headers['Accept-Language'],
      });
    });
    final api = apiWith(transport);
    final repository = TaskRepository(api, database);
    expect((await repository.resource('/tasks'))['language'], 'ru');
    api.language = 'ky';
    offline = true;
    await expectLater(
      repository.resource('/tasks'),
      throwsA(isA<ApiFailure>()),
    );
    offline = false;
    expect((await repository.resource('/tasks'))['language'], 'ky');
    offline = true;
    final cached = await repository.resource('/tasks');
    expect(cached['language'], 'ky');
    expect(cached['_offline'], isTrue);
    await database.close();
  });

  test(
    'saved language wins at login and changes persist for bot notifications',
    () async {
      final database = LocalDatabase(NativeDatabase.memory());
      await database.write('locale', 'ky');
      var user = {...testUser, 'language': 'ru'};
      final transport = TestTransport((request) async {
        if (request.path == '/auth/demo-login') {
          return jsonBody({'access_token': 'session', 'user': user});
        }
        if (request.path == '/users/me' && request.method == 'PATCH') {
          user = {...user, ...Map<String, dynamic>.from(request.data as Map)};
          return jsonBody(user);
        }
        throw StateError('Unexpected request ${request.path}');
      });
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      final api = container.read(apiProvider);
      api.dio.httpClientAdapter = transport;
      api.dio.options.baseUrl = 'https://firstcase.test/api/v1';
      await container.read(sessionProvider.future);
      await container.read(sessionProvider.notifier).demo(1);
      expect(container.read(sessionProvider).value?.json['language'], 'ky');
      expect(container.read(localeProvider).languageCode, 'ky');
      await container.read(localeProvider.notifier).select(const Locale('ru'));
      expect(user['language'], 'ru');
      expect(api.token, 'session');
      expect(transport.requests.last.headers['Accept-Language'], 'ru');
      expect(await database.read('locale'), 'ru');
      container.dispose();
      await database.close();
    },
  );

  test(
    'account language is adopted on the first login without a local choice',
    () async {
      final database = LocalDatabase(NativeDatabase.memory());
      final api = apiWith(
        TestTransport(
          (request) async => jsonBody({
            'access_token': 'session',
            'user': {...testUser, 'language': 'ky'},
          }),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          apiProvider.overrideWithValue(api),
        ],
      );
      await container.read(sessionProvider.future);
      await container.read(sessionProvider.notifier).demo(1);
      expect(container.read(localeProvider).languageCode, 'ky');
      expect(container.read(sessionProvider).value?.json['language'], 'ky');
      container.dispose();
      await database.close();
    },
  );

  test('errors without server messages use the selected language', () async {
    final api = apiWith(TestTransport((_) async => jsonBody({}, 503)))
      ..language = 'ky';
    await expectLater(
      api.request('/tasks'),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.message,
          'localized message',
          AppLocalizationsKy().errorServer,
        ),
      ),
    );
  });

  testWidgets('switching language updates UI, dates and built-in components', (
    tester,
  ) async {
    final database = LocalDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    await container.read(localeProvider.notifier).select(const Locale('ru'));
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            locale: ref.watch(localeProvider),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: FTheme(
              data: FTheme.neutral.light.touch,
              child: Builder(
                builder: (context) => Scaffold(
                  body: Column(
                    children: [
                      const LanguagePicker(),
                      Text(context.l10n.statusCompleted),
                      Text(statusLabel(context, 'revision_requested')),
                      Text(categoryLabel(context, 'data')),
                      Text(localizedDate(context, DateTime(2026, 10, 18))),
                      Text(MaterialLocalizations.of(context).okButtonLabel),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Завершён'), findsOneWidget);
    await tester.tap(find.text('Кыргызча'));
    await tester.pumpAndSettle();
    expect(find.text('Аяктады'), findsOneWidget);
    expect(find.text('Оңдоо керек'), findsOneWidget);
    expect(find.text('Маалыматтар жана автоматташтыруу'), findsOneWidget);
    expect(find.text('Завершён'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
