import 'package:drift/native.dart';
import 'package:firstcase/core/database/local_database.dart';
import 'package:firstcase/core/l10n/l10n.dart';
import 'package:firstcase/core/providers.dart';
import 'package:firstcase/features/orders/presentation/order_forms.dart';
import 'package:firstcase/features/tasks/presentation/task_card.dart';
import 'package:firstcase/shared/models/models.dart';
import 'package:firstcase/shared/widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    await initializeDateFormatting('ky');
  });
  test('agreed AI policies expose only permitted disclosure choices', () {
    expect(AiPolicy.noAi.permittedUsages, [AiUsage.noAi]);
    expect(AiPolicy.consultation.permittedUsages, [
      AiUsage.noAi,
      AiUsage.consultation,
    ]);
    expect(AiPolicy.allowed.permittedUsages, AiUsage.values);
    expect(AiPolicy.fromCode(null), AiPolicy.allowed);
    expect(AiUsage.fromCode(null), AiUsage.noAi);
  });

  for (final locale in ['ru', 'ky']) {
    testWidgets('review controls fit a mobile dialog in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resourceProvider('/orders/17/deliverables')
                .overrideWith((ref) async => {'items': []}),
          ],
          child: MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FTheme(
              data: FTheme.neutral.light.touch,
              child: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(46),
                  child: ReviewForm(17),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets('task card fits a narrow screen in $locale', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final task = Task({
        'id': 1,
        'customer_id': 2,
        'customer': {'id': 2, 'display_name': 'Long customer display name'},
        'category': {'slug': 'data', 'name': ''},
        'title': 'Data processing and automation',
        'description': 'Prepare a spreadsheet for a small company.',
        'deadline': DateTime(2027, 1, 25).toIso8601String(),
        'ai_policy': 'consultation',
        'payment_type': 'tips',
        'application_count': 125,
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FTheme(
            data: FTheme.neutral.light.touch,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(18),
                child: TaskCard(task),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'consultation disclosure is required and submitted in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = LocalDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final transport = TestTransport((request) async => jsonBody({}));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiProvider.overrideWithValue(apiWith(transport)),
              databaseProvider.overrideWithValue(database),
            ],
            child: MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: FTheme(
                data: FTheme.neutral.light.touch,
                child: const Scaffold(
                  body: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: SubmitForm(17, aiPolicy: AiPolicy.consultation),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(SubmitForm)),
        );
        expect(find.text(l10n.aiUsageAssisted), findsNothing);
        await tester.tap(find.text(l10n.aiUsageConsultation));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(EditableText).first,
          'Finished result',
        );
        final submit = find.byType(ActionButton).last;
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.aiDisclosureRequired, findRichText: true),
          findsOneWidget,
        );
        expect(transport.requests, isEmpty);
        await tester.enterText(
          find.byType(EditableText).last,
          'Used AI for advice',
        );
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        final sent = transport.requests.single;
        expect(sent.path, '/orders/17/submit');
        expect(sent.data['ai_usage'], 'consultation');
        expect(sent.data['ai_disclosure'], 'Used AI for advice');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
