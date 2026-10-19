import 'package:drift/native.dart';
import 'package:firstcase/core/database/local_database.dart';
import 'package:firstcase/core/l10n/l10n.dart';
import 'package:firstcase/core/providers.dart';
import 'package:firstcase/features/chat/presentation/chat_panel.dart';
import 'package:firstcase/features/chat/presentation/telegram_invite.dart';
import 'package:firstcase/shared/models/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

class _Session extends SessionController {
  @override
  Future<Person?> build() async =>
      Person({...testUser, 'username': 'my_username'});
}

Json message(int id, {int author = 2, String? body}) => {
  'id': id,
  'order_id': 17,
  'author_id': author,
  'author': {
    ...testUser,
    'id': author,
    'display_name': author == 1 ? 'Айбек' : 'Нурбек',
  },
  'text': body ?? 'Message $id: a detailed update about the project.',
  'attachment_ids': <int>[],
  'created_at': DateTime(2026, 10, 19, 12, id % 60).toUtc().toIso8601String(),
};

Json invitation(String status, {int requester = 2}) => {
  'id': 4,
  'order_id': 17,
  'requested_by': requester,
  'status': status,
  'my_username': status == 'accepted' ? 'my_username' : null,
  'peer_username': status == 'accepted' ? 'peer_username' : null,
  'created_at': '2026-10-19T10:00:00Z',
  'responded_at': null,
};

Future<ProviderContainer> mountChat(
  WidgetTester tester,
  TestTransport transport, {
  double width = 1000,
  String locale = 'ru',
  bool readOnly = false,
  String? draft,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final database = LocalDatabase(NativeDatabase.memory());
  if (draft != null) {
    await database.write('chat_draft:17', draft, personal: true);
  }
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
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        builder: (_, child) => FTheme(
          data: locale == 'ky'
              ? FTheme.neutral.dark.touch
              : FTheme.neutral.light.touch,
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ChatPanel(
              17,
              peer: Person({...testUser, 'id': 2, 'display_name': 'Нурбек'}),
              readOnly: readOnly,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    await initializeDateFormatting('ky');
  });

  for (final width in [320.0, 820.0, 1280.0]) {
    for (final locale in ['ru', 'ky']) {
      testWidgets(
        'populated chat and incoming invitation fit $width in $locale',
        (tester) async {
          final transport = TestTransport(
            (request) async => jsonBody(
              request.path.endsWith('/telegram')
                  ? invitation('pending')
                  : {
                      'items': [
                        message(1),
                        {
                          ...message(2),
                          'attachment_ids': [9],
                        },
                        message(3, author: 1),
                      ],
                      'total': 3,
                    },
            ),
          );
          await mountChat(tester, transport, width: width, locale: locale);
          expect(tester.takeException(), isNull);
          final accept = locale == 'ru'
              ? 'Принять приглашение'
              : 'Чакырууну кабыл алуу';
          await tester.tap(
            find.byKey(const ValueKey('telegram-invite-notice')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(accept));
          await tester.pumpAndSettle();
          expect(find.byType(TelegramContactForm), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'desktop Enter sends restored draft and Shift+Enter keeps a newline',
    (tester) async {
      final rows = <Json>[message(1)];
      final transport = TestTransport((request) async {
        if (request.path.endsWith('/telegram')) return jsonBody(null);
        if (request.method == 'POST') {
          final saved = message(
            2,
            author: 1,
            body: request.data['text'] as String,
          );
          rows.add(saved);
          return jsonBody(saved, 201);
        }
        return jsonBody({'items': rows, 'total': rows.length});
      });
      final container = await mountChat(
        tester,
        transport,
        draft: 'Saved draft',
      );
      final field = find.byWidgetPredicate(
        (widget) => widget is EditableText && !widget.readOnly,
      );
      expect(tester.widget<EditableText>(field).controller.text, 'Saved draft');
      await tester.tap(field);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(transport.requests.where((r) => r.method == 'POST'), isEmpty);
      expect(
        tester.widget<EditableText>(field).controller.text,
        contains('\n'),
      );
      await tester.enterText(field, 'Ready to send');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final sent = transport.requests.singleWhere((r) => r.method == 'POST');
      expect(sent.data, {'text': 'Ready to send', 'attachment_ids': []});
      expect(tester.widget<EditableText>(field).controller.text, '');
      expect(await container.read(databaseProvider).read('chat_draft:17'), '');
      expect(find.text('Ready to send'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed send preserves composer text for retry', (tester) async {
    final transport = TestTransport((request) async {
      if (request.path.endsWith('/telegram')) return jsonBody(null);
      if (request.method == 'POST') {
        return jsonBody({'message': 'Temporary failure'}, 503);
      }
      return jsonBody({'items': <Json>[], 'total': 0});
    });
    await mountChat(tester, transport);
    await tester.enterText(find.byType(EditableText), 'Keep this message');
    await tester.tap(find.byIcon(FLucideIcons.arrowUp));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Keep this message',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('older history prepends and polling catches more than one page', (
    tester,
  ) async {
    final rows = List.generate(125, (i) => message(i + 1));
    final transport = TestTransport((request) async {
      if (request.path.endsWith('/telegram')) return jsonBody(null);
      final query = request.queryParameters;
      final before = int.tryParse('${query['before_id']}');
      final after = int.tryParse('${query['after_id']}');
      var page = rows
          .where(
            (row) =>
                (before == null || (row['id'] as int) < before) &&
                (after == null || (row['id'] as int) > after),
          )
          .toList();
      final total = page.length;
      final limit = int.parse('${query['limit']}');
      page = query['latest'] == 'true'
          ? page.skip((page.length - limit).clamp(0, page.length)).toList()
          : page.take(limit).toList();
      return jsonBody({'items': page, 'total': total});
    });
    await mountChat(tester, transport);
    final history = find.byKey(const ValueKey('chat-messages'));
    final controller = tester.widget<ListView>(history).controller!;
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ранние сообщения'));
    await tester.pumpAndSettle();
    expect(
      transport.requests.any((r) => r.queryParameters['before_id'] == '76'),
      isTrue,
    );
    final loaded =
        tester.widget<ListView>(history).childrenDelegate
            as SliverChildListDelegate;
    expect(loaded.children.whereType<Widget>().length, greaterThan(100));
    final beforePoll = controller.offset;
    rows.addAll(List.generate(120, (i) => message(i + 126)));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(
      transport.requests.any((r) => r.queryParameters['after_id'] == '125'),
      isTrue,
    );
    expect(
      transport.requests.any((r) => r.queryParameters['after_id'] == '225'),
      isTrue,
    );
    expect(controller.offset, closeTo(beforePoll, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'accepting Telegram invitation posts contact and updates both controls',
    (tester) async {
      var invite = invitation('pending');
      final transport = TestTransport((request) async {
        if (request.path.endsWith('/respond')) {
          invite = invitation('accepted');
          return jsonBody(invite);
        }
        if (request.path.endsWith('/telegram')) return jsonBody(invite);
        return jsonBody({'items': <Json>[], 'total': 0});
      });
      await mountChat(tester, transport);
      await tester.tap(find.byKey(const ValueKey('telegram-invite-notice')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Принять приглашение'));
      await tester.pumpAndSettle();
      final form = find.byType(TelegramContactForm);
      await tester.tap(
        find.descendant(of: form, matching: find.text('Принять приглашение')),
      );
      await tester.pumpAndSettle();
      final response = transport.requests.singleWhere(
        (r) => r.path.endsWith('/respond'),
      );
      expect(response.data, {'action': 'accept', 'username': 'my_username'});
      expect(
        find.descendant(
          of: find.byType(TelegramInviteDetails),
          matching: find.text('Вы договорились общаться в Telegram'),
        ),
        findsOneWidget,
      );
      expect(find.text('Открыть Telegram'), findsOneWidget);
      expect(find.byType(TelegramContactForm), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in ['pending', 'accepted']) {
    testWidgets(
      'Telegram $status notice leaves the latest message visible on mobile',
      (tester) async {
        final transport = TestTransport(
          (request) async => jsonBody(
            request.path.endsWith('/telegram')
                ? invitation(status, requester: 1)
                : {
                    'items': List.generate(6, (i) => message(i + 1)),
                    'total': 6,
                  },
          ),
        );
        await mountChat(tester, transport, width: 320, locale: 'ky');
        final notice = find.byKey(const ValueKey('telegram-invite-notice'));
        expect(tester.getSize(notice).height, lessThanOrEqualTo(56));
        final history = find.byKey(const ValueKey('chat-messages'));
        final viewport = tester.getRect(history);
        final latest = tester.getRect(
          find.text('Message 6: a detailed update about the project.'),
        );
        expect(latest.top, greaterThanOrEqualTo(viewport.top));
        expect(latest.bottom, lessThanOrEqualTo(viewport.bottom));
        await tester.tap(notice);
        await tester.pumpAndSettle();
        expect(find.byType(TelegramInviteDetails), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('resizing the chat keeps the latest message in view', (
    tester,
  ) async {
    final transport = TestTransport(
      (request) async => jsonBody(
        request.path.endsWith('/telegram')
            ? null
            : {'items': List.generate(12, (i) => message(i + 1)), 'total': 12},
      ),
    );
    await mountChat(tester, transport);
    final history = find.byKey(const ValueKey('chat-messages'));
    final controller = tester.widget<ListView>(history).controller!;
    expect(controller.offset, closeTo(controller.position.maxScrollExtent, 1));
    tester.view.physicalSize = const Size(320, 1000);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(controller.position.maxScrollExtent, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled order keeps history and removes composer', (
    tester,
  ) async {
    final transport = TestTransport(
      (request) async => jsonBody(
        request.path.endsWith('/telegram')
            ? null
            : {
                'items': [message(1)],
                'total': 1,
              },
      ),
    );
    await mountChat(tester, transport, width: 320, readOnly: true);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is EditableText && !widget.readOnly,
      ),
      findsNothing,
    );
    expect(
      find.text('Заказ отменён. Переписка доступна для чтения.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
