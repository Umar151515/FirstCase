import 'package:drift/native.dart';
import 'package:firstcase/app/app.dart';
import 'package:firstcase/core/database/local_database.dart';
import 'package:firstcase/core/l10n/l10n.dart';
import 'package:firstcase/core/providers.dart';
import 'package:firstcase/shared/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support.dart';

class _SignedIn extends SessionController {
  @override
  Future<Person?> build() async => Person(testUser);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    await initializeDateFormatting('ky');
  });
  for (final width in [320.0, 390.0, 820.0, 1024.0, 1280.0, 1440.0]) {
    for (final locale in ['ru', 'ky']) {
      testWidgets(
        'populated home and catalogue fit ${width.toInt()}px in $locale',
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
              (request) async => jsonBody(switch (request.uri.path
                  .split('/')
                  .last) {
                'config' => {'mode': 'demo'},
                'categories' => {
                  'items': [
                    for (final (index, slug) in [
                      'development',
                      'design',
                      'video',
                      'illustration',
                      'text',
                      'data',
                    ].indexed)
                      {'id': index + 1, 'slug': slug, 'name': slug},
                  ],
                },
                'tasks' => {
                  'items': [
                    for (var i = 1; i <= 6; i++)
                      {
                        'id': i,
                        'customer_id': 1,
                        'customer': testUser,
                        'category': {'id': 6, 'slug': 'data', 'name': 'Data'},
                        'title': 'Prepare a spreadsheet for a local business',
                        'description': 'Organize customer information and prepare a monthly report.',
                        'deadline': '2027-01-25T12:00:00Z',
                        'ai_policy': 'consultation',
                        'payment_type': 'tips',
                        'application_count': 125,
                      },
                  ],
                  'total': 6,
                },
                'users' => {
                  'items': [testUser],
                  'total': 1,
                },
                _ => {'items': [], 'total': 0},
              }),
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
          container.read(routerProvider).go('/tasks');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.byIcon(FLucideIcons.slidersHorizontal));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
