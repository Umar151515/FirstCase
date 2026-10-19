import 'package:drift/native.dart';
import 'package:firstcase/core/database/local_database.dart';
import 'package:firstcase/core/l10n/l10n.dart';
import 'package:firstcase/core/providers.dart';
import 'package:firstcase/features/orders/presentation/order_forms.dart';
import 'package:firstcase/features/orders/presentation/order_page.dart';
import 'package:firstcase/features/profile/presentation/profile_page.dart';
import 'package:firstcase/features/tasks/presentation/task_detail_page.dart';
import 'package:firstcase/shared/models/models.dart';
import 'package:firstcase/shared/widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

class _Session extends SessionController {
  @override
  Future<Person?> build() async => Person(testUser);
}

void expectLabelsInsideButtons(WidgetTester tester) {
  for (final button in find.byType(FButton).evaluate()) {
    final buttonFinder = find.byElementPredicate(
      (element) => identical(element, button),
    );
    final bounds = tester.getRect(buttonFinder).inflate(.5);
    for (final text
        in find
            .descendant(of: buttonFinder, matching: find.byType(Text))
            .evaluate()) {
      final finder = find.byElementPredicate(
        (element) => identical(element, text),
      );
      final label = tester.getRect(finder);
      expect(
        label.left,
        greaterThanOrEqualTo(bounds.left),
        reason: 'Label leaves its button: ${(text.widget as Text).data}',
      );
      expect(
        label.right,
        lessThanOrEqualTo(bounds.right),
        reason: 'Label leaves its button: ${(text.widget as Text).data}',
      );
      expect(label.top, greaterThanOrEqualTo(bounds.top));
      expect(label.bottom, lessThanOrEqualTo(bounds.bottom));
    }
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    await initializeDateFormatting('ky');
  });
  for (final width in [320.0, 420.0]) {
    for (final scale in [1.0, 1.4]) {
      for (final locale in ['ru', 'ky']) {
        testWidgets(
          'actions and privacy labels fit ${width}px at ${scale}x in $locale',
          (tester) async {
            tester.view.physicalSize = Size(width, 960);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final database = LocalDatabase(NativeDatabase.memory());
            final task = <String, dynamic>{
              'id': 7,
              'customer_id': 1,
              'customer': testUser,
              'title': 'Small business website and Telegram bot',
              'description':
                  'A real task with a detailed description and a clear result.',
              'expected_result': 'A working bot and instructions',
              'deadline': '2027-01-25T12:00:00Z',
              'created_at': '2026-10-19T12:00:00Z',
              'category': {
                'id': 1,
                'slug': 'development',
                'name': 'Development',
              },
              'status': 'published',
              'payment_type': 'tips',
            };
            final order = {
              'id': 17,
              'customer_id': 1,
              'performer_id': 2,
              'customer': testUser,
              'performer': {...testUser, 'id': 2},
              'task': task,
              'status': 'completed',
              'revisions_used': 1,
              'max_revisions': 1,
            };
            final transport = TestTransport(
              (request) async => jsonBody(switch (request.path) {
                '/orders/17' => order,
                '/tasks/7' => task,
                '/auth/me' => testUser,
                '/orders/17/telegram' => null,
                '/orders/17/privacy-consent' => request.data,
                _ => {'items': [], 'total': 0},
              }),
            );
            final container = ProviderContainer(
              overrides: [
                databaseProvider.overrideWithValue(database),
                apiProvider.overrideWithValue(apiWith(transport)),
                sessionProvider.overrideWith(_Session.new),
              ],
            );
            await container.read(sessionProvider.future);
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox.shrink());
              container.dispose();
              await database.close();
            });

            Future<void> show(Widget page) async {
              await tester.pumpWidget(
                UncontrolledProviderScope(
                  container: container,
                  child: MaterialApp(
                    locale: Locale(locale),
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates: appLocalizationsDelegates,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: FTheme(
                        data: locale == 'ky'
                            ? FTheme.neutral.dark.touch
                            : FTheme.neutral.light.touch,
                        child: child!,
                      ),
                    ),
                    home: Scaffold(body: page),
                  ),
                ),
              );
              await tester.pumpAndSettle();
            }

            for (final page in [
              const OrderPage(17),
              const ProfilePage(),
              const TaskDetailPage(7),
            ]) {
              await show(page);
              expect(
                tester.takeException(),
                isNull,
                reason: '${page.runtimeType}',
              );
              expectLabelsInsideButtons(tester);
            }
            await show(
              Builder(
                builder: (context) => FButton(
                  onPress: () => modal(
                    context,
                    const PrivacyForm(
                      17,
                      messages: [
                        {
                          'id': 21,
                          'text': 'A long message about project requirements, delivery dates and all the agreed changes that must remain readable inside the permissions dialog.',
                        },
                      ],
                      attachmentIds: [10, 14, 11],
                    ),
                  ),
                  child: const Flexible(child: Text('Open')),
                ),
              ),
            );
            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();
            expect(find.byType(FCheckbox), findsNWidgets(5));
            expect(tester.takeException(), isNull);
            expectLabelsInsideButtons(tester);
            final identity = find.byType(FCheckbox).first;
            await tester.ensureVisible(identity);
            await tester.tap(identity);
            await tester.pumpAndSettle();
            expect(tester.widget<FCheckbox>(identity).value, isTrue);
            final l = AppLocalizations.of(
              tester.element(find.byType(PrivacyForm)),
            );
            final save = find.text(l.savePermissions);
            await tester.ensureVisible(save);
            await tester.tap(save);
            await tester.pumpAndSettle();
            final saved = transport.requests.singleWhere(
              (r) => r.path.endsWith('/privacy-consent'),
            );
            expect(saved.data, {
              'allow_identity': true,
              'attachment_ids': [],
              'message_ids': [],
            });
            expect(find.byType(PrivacyForm), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
