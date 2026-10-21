import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firstcase/core/database/local_database.dart';
import 'package:firstcase/core/providers.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('logout discards a login response that arrives later', () async {
    final response = Completer<ResponseBody>();
    final started = Completer<void>();
    final database = LocalDatabase(NativeDatabase.memory());
    final api = apiWith(
      TestTransport((request) {
        started.complete();
        return response.future;
      }),
    );
    final container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(api),
        databaseProvider.overrideWithValue(database),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    await container.read(sessionProvider.future);
    final login = container.read(sessionProvider.notifier).demo(1);
    await started.future;
    await container.read(sessionProvider.notifier).logout();
    response.complete(
      jsonBody({'access_token': 'old-session', 'user': testUser}),
    );
    await login;
    expect(api.token, isNull);
    expect(container.read(sessionProvider).value, isNull);
    expect(container.read(sessionProvider).hasError, isFalse);
  });

  test('the most recent demo login wins out of order responses', () async {
    final responses = <int, Completer<ResponseBody>>{};
    final firstStarted = Completer<void>();
    final secondStarted = Completer<void>();
    final database = LocalDatabase(NativeDatabase.memory());
    final api = apiWith(
      TestTransport((request) {
        final id = (request.data as Map)['user_id'] as int;
        final response = responses[id] = Completer<ResponseBody>();
        (id == 1 ? firstStarted : secondStarted).complete();
        return response.future;
      }),
    );
    final container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(api),
        databaseProvider.overrideWithValue(database),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    await container.read(sessionProvider.future);
    final first = container.read(sessionProvider.notifier).demo(1);
    await firstStarted.future;
    final second = container.read(sessionProvider.notifier).demo(2);
    await secondStarted.future;
    responses[2]!.complete(
      jsonBody({
        'access_token': 'second-session',
        'user': {...testUser, 'id': 2},
      }),
    );
    await second;
    responses[1]!.complete(
      jsonBody({'access_token': 'first-session', 'user': testUser}),
    );
    await first;
    expect(api.token, 'second-session');
    expect(container.read(sessionProvider).value?.id, 2);
  });

  test('logout also cancels the initial Telegram login', () async {
    final response = Completer<ResponseBody>();
    final started = Completer<void>();
    final database = LocalDatabase(NativeDatabase.memory());
    final api = apiWith(
      TestTransport((request) {
        started.complete();
        return response.future;
      }),
    );
    final container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(api),
        databaseProvider.overrideWithValue(database),
        telegramInitDataProvider.overrideWithValue('signed-init-data'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    final login = container.read(sessionProvider.future);
    await started.future;
    await container.read(sessionProvider.notifier).logout();
    response.complete(
      jsonBody({'access_token': 'old-session', 'user': testUser}),
    );
    await login;
    await Future<void>.delayed(Duration.zero);
    expect(api.token, isNull);
    expect(container.read(sessionProvider).value, isNull);
    expect(container.read(sessionProvider).hasError, isFalse);
  });

  test('a failed login language sync leaves no authenticated token', () async {
    final database = LocalDatabase(NativeDatabase.memory());
    await database.write('locale', 'ky');
    final api = apiWith(
      TestTransport((request) async {
        if (request.path == '/auth/demo-login') {
          return jsonBody({'access_token': 'session', 'user': testUser});
        }
        return jsonBody({}, 503);
      }),
    );
    final container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(api),
        databaseProvider.overrideWithValue(database),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    await container.read(sessionProvider.future);
    await container.read(sessionProvider.notifier).demo(1);
    expect(container.read(sessionProvider).hasError, isTrue);
    expect(api.token, isNull);
  });

  test(
    'demo identity really exchanges server JWT and resets personal data',
    () async {
      final database = LocalDatabase(NativeDatabase.memory());
      final api = apiWith(
        TestTransport(
          (request) async => jsonBody({
            'access_token': 'server-signed-token',
            'token_type': 'bearer',
            'user': testUser,
          }),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(api),
          databaseProvider.overrideWithValue(database),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });
      await database.write('task_draft', {
        'title': 'Old account',
      }, personal: true);
      await container.read(sessionProvider.future);
      await container.read(sessionProvider.notifier).demo(1);
      expect(container.read(sessionProvider).value?.id, 1);
      expect(api.token, 'server-signed-token');
      expect(await database.read('task_draft'), isNull);
      await container.read(sessionProvider.notifier).logout();
      expect(api.token, isNull);
      expect(container.read(sessionProvider).value, isNull);
    },
  );

  test('failed demo authentication becomes recoverable AsyncError', () async {
    final database = LocalDatabase(NativeDatabase.memory());
    final api = apiWith(
      TestTransport(
        (_) async => jsonBody({
          'error': {'message': 'Аккаунт заблокирован'},
        }, 403),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(api),
        databaseProvider.overrideWithValue(database),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    await container.read(sessionProvider.future);
    await container.read(sessionProvider.notifier).demo(1);
    expect(container.read(sessionProvider).hasError, isTrue);
    expect(api.token, isNull);
  });
}
