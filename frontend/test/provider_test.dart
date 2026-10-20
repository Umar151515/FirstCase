import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firstcase/core/database/local_database.dart';
import 'package:firstcase/core/providers.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
