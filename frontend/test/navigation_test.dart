import 'package:drift/native.dart';
import 'package:firstcase/app/app.dart';
import 'package:firstcase/core/database/local_database.dart';
import 'package:firstcase/core/l10n/l10n.dart';
import 'package:firstcase/core/providers.dart';
import 'package:firstcase/features/home/presentation/home_page.dart';
import 'package:firstcase/features/profile/presentation/profile_form_page.dart';
import 'package:firstcase/features/profile/presentation/profile_page.dart';
import 'package:firstcase/features/tasks/presentation/tasks_page.dart';
import 'package:firstcase/shared/widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    await initializeDateFormatting('ky');
  });

  for (final path in ['/tasks/new', '/profile/edit']) {
    testWidgets('switching accounts resets private form input on $path', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = LocalDatabase(NativeDatabase.memory());
      final api = apiWith(
        TestTransport((request) async {
          if (request.path == '/auth/demo-login') {
            final id = (request.data as Map)['user_id'] as int;
            return jsonBody({
              'access_token': 'session-$id',
              'user': {...testUser, 'id': id, 'display_name': 'Account $id'},
            });
          }
          if (request.path == '/config') {
            return jsonBody({'mode': 'production'});
          }
          return jsonBody({'items': [], 'total': 0});
        }),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          apiProvider.overrideWithValue(api),
          appInitialLocationProvider.overrideWithValue(path),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await database.close();
      });
      await tester.runAsync(() async {
        await container.read(sessionProvider.future);
        await container.read(sessionProvider.notifier).demo(1);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FirstCaseApp(),
        ),
      );
      await tester.pumpAndSettle();
      final router = container.read(routerProvider);
      final labels = AppLocalizations.of(
        tester.element(find.byType(Field).first),
      );
      final label = path == '/tasks/new'
          ? labels.taskTitle
          : labels.profileName;
      final field = find.byWidgetPredicate(
        (widget) => widget is Field && widget.label == label,
      );
      await tester.enterText(
        find.descendant(of: field, matching: find.byType(EditableText)),
        'Private input from account one',
      );
      await tester.runAsync(
        () => container.read(sessionProvider.notifier).demo(2),
      );
      await tester.pumpAndSettle();
      expect(container.read(routerProvider), same(router));
      expect(router.routerDelegate.currentConfiguration.uri.path, path);
      expect(
        tester.widget<Field>(field).controller.text,
        isNot('Private input from account one'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final onboarded in [true, false]) {
    testWidgets(
      onboarded
          ? 'production Telegram profile supports menu navigation, editing and logout'
          : 'new Telegram account can finish onboarding and then use the menu',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = LocalDatabase(NativeDatabase.memory());
        var user = {...testUser, 'onboarding_completed': onboarded};
        final transport = TestTransport((request) async {
          if (request.path == '/auth/telegram') {
            return jsonBody({'access_token': 'telegram-session', 'user': user});
          }
          if (request.path == '/config') {
            return jsonBody({'mode': 'production'});
          }
          if (request.path == '/users/me' && request.method == 'PATCH') {
            user = {...user, ...Map<String, dynamic>.from(request.data as Map)};
            return jsonBody(user);
          }
          if (request.path == '/auth/me') return jsonBody(user);
          return jsonBody({'items': [], 'total': 0});
        });
        final api = apiWith(transport);
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            apiProvider.overrideWithValue(api),
            telegramInitDataProvider.overrideWithValue('test-signed-init-data'),
            appInitialLocationProvider.overrideWithValue('/profile'),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          await database.close();
        });
        await tester.runAsync(() => container.read(sessionProvider.future));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const FirstCaseApp(),
          ),
        );
        await tester.pumpAndSettle();
        final router = container.read(routerProvider);
        String currentPath() =>
            router.routerDelegate.currentConfiguration.uri.path;
        if (!onboarded) {
          expect(currentPath(), '/onboarding');
          final labels = AppLocalizations.of(
            tester.element(find.byType(ProfileFormPage)),
          );
          final later = find.text(labels.fillLater);
          await tester.ensureVisible(later);
          await tester.tap(later);
          await tester.pumpAndSettle();
          expect(container.read(sessionProvider).value?.onboarded, isTrue);
          expect(currentPath(), '/');
        }
        if (!onboarded) {
          router.go('/profile');
          await tester.pumpAndSettle();
        }
        expect(currentPath(), '/profile');
        expect(find.byType(ProfilePage), findsOneWidget);
        Future<void> menu(IconData icon) async {
          await tester.tap(
            find.descendant(
              of: find.byType(FBottomNavigationBar),
              matching: find.byIcon(icon),
            ),
          );
          await tester.pumpAndSettle();
        }

        await menu(FLucideIcons.search);
        expect(currentPath(), '/tasks');
        expect(find.byType(TasksPage), findsOneWidget);
        await menu(FLucideIcons.house);
        expect(currentPath(), '/');
        expect(find.byType(HomePage), findsOneWidget);
        await menu(FLucideIcons.userRound);
        expect(currentPath(), '/profile');
        final labels = AppLocalizations.of(
          tester.element(find.byType(ProfilePage)),
        );
        final edit = find.text(labels.configureProfile);
        await tester.ensureVisible(edit);
        await tester.tap(edit);
        await tester.pumpAndSettle();
        expect(currentPath(), '/profile/edit');
        expect(find.byType(ProfileFormPage), findsOneWidget);
        await menu(FLucideIcons.userRound);
        final signOut = find.text(labels.signOut);
        await tester.ensureVisible(signOut);
        await tester.tap(signOut);
        await tester.pumpAndSettle();
        expect(currentPath(), '/');
        expect(api.token, isNull);
        expect(container.read(sessionProvider).value, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
