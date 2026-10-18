import 'package:drift/native.dart';
import 'package:firstcase/core/database/local_database.dart';
import 'package:firstcase/core/l10n/l10n.dart';
import 'package:firstcase/core/providers.dart';
import 'package:firstcase/features/profile/presentation/profile_form_page.dart';
import 'package:firstcase/shared/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

class _TelegramSession extends SessionController {
  @override
  Future<Person?> build() async => Person({
    ...testUser,
    'avatar_url': 'https://firstcase.test/telegram-photo.jpg',
  });
}

void main() {
  for (final removePhoto in [false, true]) {
    testWidgets(
      removePhoto
          ? 'removing a Telegram profile photo explicitly sends null'
          : 'editing profile details preserves an unchanged Telegram photo',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = LocalDatabase(NativeDatabase.memory());
        final transport = TestTransport((request) async => jsonBody(testUser));
        final container = ProviderContainer(
          overrides: [
            apiProvider.overrideWithValue(apiWith(transport)),
            databaseProvider.overrideWithValue(database),
            sessionProvider.overrideWith(_TelegramSession.new),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await database.close();
        });
        await container.read(sessionProvider.future);
        final router = GoRouter(
          initialLocation: '/profile/edit',
          routes: [
            GoRoute(
              path: '/profile/edit',
              builder: (_, _) => const ProfileFormPage(),
            ),
            GoRoute(path: '/profile', builder: (_, _) => const Text('Saved')),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
              locale: const Locale('ru'),
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (_, child) => FTheme(
                data: FTheme.neutral.light.touch,
                child: Scaffold(body: child),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ProfileFormPage)),
        );
        if (removePhoto) {
          await tester.tap(find.text(l10n.mediaRemovePhoto));
          await tester.pumpAndSettle();
        }
        final save = find.text(l10n.saveProfile);
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        final request = transport.requests.single;
        expect(request.path, '/users/me');
        expect(request.data.containsKey('avatar_attachment_id'), removePhoto);
        if (removePhoto) expect(request.data['avatar_attachment_id'], isNull);
        expect(find.text('Saved'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
