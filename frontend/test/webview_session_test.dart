import 'dart:async';

import 'package:drift/drift.dart' show LazyDatabase, QueryExecutor;
import 'package:drift/native.dart';
import 'package:firstcase/core/database/local_database.dart';
import 'package:firstcase/core/providers.dart';
import 'package:firstcase/shared/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class _SignedInSession extends SessionController {
  @override
  Future<Person?> build() async => Person(testUser);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'logout clears identity before an unavailable cache completes',
    () async {
      final opening = Completer<QueryExecutor>();
      final database = LocalDatabase(
        LazyDatabase(() => opening.future),
        const Duration(milliseconds: 20),
      );
      final api = apiWith(TestTransport((_) async => jsonBody({})))
        ..token = 'old-session';
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          apiProvider.overrideWithValue(api),
          sessionProvider.overrideWith(_SignedInSession.new),
        ],
      );
      await container.read(sessionProvider.future);
      final logout = container.read(sessionProvider.notifier).logout();
      expect(api.token, isNull);
      expect(container.read(sessionProvider).value, isNull);
      await logout.timeout(const Duration(milliseconds: 500));
      opening.complete(NativeDatabase.memory());
      await database.customSelect('SELECT 1').get();
      container.dispose();
      await database.close();
    },
  );

  test(
    'a stalled browser cache does not block Telegram authentication',
    () async {
      final opening = Completer<QueryExecutor>();
      final database = LocalDatabase(
        LazyDatabase(() => opening.future),
        const Duration(milliseconds: 20),
      );
      final api = apiWith(
        TestTransport(
          (_) async => jsonBody({'access_token': 'session', 'user': testUser}),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          apiProvider.overrideWithValue(api),
          telegramInitDataProvider.overrideWithValue('test-signed-init-data'),
        ],
      );
      final user = await container
          .read(sessionProvider.future)
          .timeout(const Duration(milliseconds: 500));
      expect(user?.id, testUser['id']);
      opening.complete(NativeDatabase.memory());
      await database.customSelect('SELECT 1').get();
      // Storage remains disabled for this session, even when its worker returns late.
      await database.write('task_draft', {
        'title': 'Late private draft',
      }, personal: true);
      expect(await database.read('task_draft'), isNull);
      container.dispose();
      await database.close();
    },
  );

  test('reopening Telegram preserves the same account drafts', () async {
    final database = LocalDatabase(NativeDatabase.memory());
    await database.write('task_draft', {
      'title': 'Unfinished task',
    }, personal: true);
    final api = apiWith(
      TestTransport(
        (_) async => jsonBody({'access_token': 'session', 'user': testUser}),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        apiProvider.overrideWithValue(api),
        telegramInitDataProvider.overrideWithValue('test-signed-init-data'),
      ],
    );
    await container.read(sessionProvider.future);
    expect((await database.read('task_draft'))['title'], 'Unfinished task');
    container.dispose();
    await database.close();
  });
}
