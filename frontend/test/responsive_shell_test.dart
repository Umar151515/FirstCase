import 'package:drift/native.dart';
import 'package:firstcase/app/app.dart';
import 'package:firstcase/core/database/local_database.dart';
import 'package:firstcase/core/l10n/l10n.dart';
import 'package:firstcase/core/providers.dart';
import 'package:firstcase/shared/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

class _SignedIn extends SessionController {
  @override
  Future<Person?> build() async => Person(testUser);
}

void main() {
  for (final width in [320.0, 820.0, 1280.0]) {
    for (final locale in ['ru', 'ky']) {
      testWidgets(
        'signed-in shell and home fit ${width.toInt()}px in $locale',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final database = LocalDatabase(NativeDatabase.memory());
          await database.write('locale', locale);
          await database.write('theme', locale == 'ky');
          final api = apiWith(
            TestTransport(
              (request) async => jsonBody(
                request.path == '/config'
                    ? {'mode': 'demo'}
                    : {'items': [], 'total': 0},
              ),
            ),
          );
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(database),
              apiProvider.overrideWithValue(api),
              sessionProvider.overrideWith(_SignedIn.new),
            ],
          );
          addTearDown(() async {
            container.dispose();
            await database.close();
          });
          await container.read(localeProvider.notifier).ready;
          await container.read(sessionProvider.future);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const FirstCaseApp(),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
