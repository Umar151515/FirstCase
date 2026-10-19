import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../core/l10n/l10n.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/tasks/presentation/tasks_page.dart';
import '../features/tasks/presentation/task_detail_page.dart';
import '../features/tasks/presentation/task_form_page.dart';
import '../features/orders/presentation/orders_page.dart';
import '../features/orders/presentation/order_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/profile/presentation/profile_form_page.dart';
import '../features/portfolio/presentation/portfolio_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/admin/presentation/admin_page.dart';
import '../shared/widgets/ui.dart';
import 'shell.dart';

final routerProvider = Provider((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final user = ref.read(sessionProvider).value;
      if (user != null && !user.onboarded && state.uri.path != '/onboarding') {
        return '/onboarding';
      }
      if (user != null && state.uri.path == '/login') return '/';
      return null;
    },
    initialLocation: '/',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomePage()),
          GoRoute(
            path: '/tasks',
            builder: (_, state) => TasksPage(
              initialQuery: state.uri.queryParameters['q'] ?? '',
              category: state.uri.queryParameters['category_id'],
            ),
          ),
          GoRoute(path: '/tasks/new', builder: (_, _) => const TaskFormPage()),
          GoRoute(
            path: '/tasks/:id/edit',
            builder: (_, state) =>
                TaskFormPage(id: int.parse(state.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/tasks/:id',
            builder: (_, state) =>
                TaskDetailPage(int.parse(state.pathParameters['id']!)),
          ),
          GoRoute(path: '/orders', builder: (_, _) => const OrdersPage()),
          GoRoute(
            path: '/orders/:id',
            builder: (_, state) =>
                OrderPage(int.parse(state.pathParameters['id']!)),
          ),
          GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
          GoRoute(
            path: '/users/:id',
            builder: (_, state) =>
                ProfilePage(id: int.parse(state.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/profile/edit',
            builder: (_, _) => const ProfileFormPage(),
          ),
          GoRoute(
            path: '/onboarding',
            builder: (_, _) => const ProfileFormPage(onboarding: true),
          ),
          GoRoute(path: '/tips', builder: (_, _) => const TipsPage()),
          GoRoute(
            path: '/portfolio/new',
            builder: (_, state) => PortfolioFormPage(
              orderId: int.tryParse(
                state.uri.queryParameters['order_id'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: '/portfolio/:id',
            builder: (_, state) =>
                PortfolioDetailPage(int.parse(state.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsPage(),
          ),
          GoRoute(path: '/reports', builder: (_, _) => const ReportsPage()),
          GoRoute(path: '/admin', builder: (_, _) => const AdminPage()),
        ],
      ),
    ],
    errorBuilder: (context, _) =>
        Scaffold(body: Center(child: Text(context.l10n.pageNotFound))),
  );
  ref.onDispose(router.dispose);
  ref.onDispose(refresh.dispose);
  return router;
});

class FirstCaseApp extends ConsumerWidget {
  const FirstCaseApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(themeProvider);
    final colors = (dark ? FColors.neutralDark : FColors.neutralLight).copyWith(
      primary: dark ? const Color(0xFFA7C3EE) : accent,
      primaryForeground: dark ? const Color(0xFF102B50) : Colors.white,
      background: dark ? const Color(0xFF151B21) : const Color(0xFFF6F5F1),
      foreground: dark ? const Color(0xFFEAECE8) : const Color(0xFF262D32),
      secondary: dark ? const Color(0xFF252D35) : const Color(0xFFECEBE5),
      secondaryForeground: dark
          ? const Color(0xFFE1E8F1)
          : const Color(0xFF414947),
      muted: dark ? const Color(0xFF202830) : const Color(0xFFF0EFE9),
      mutedForeground: dark ? const Color(0xFFA6ADA9) : const Color(0xFF666F6C),
      border: dark ? const Color(0xFF343D43) : const Color(0xFFDDDFD7),
    );
    final theme = FThemeData(colors: colors, touch: true);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      theme: theme.toApproximateMaterialTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => FTheme(
        data: theme,
        child: FToaster(child: FTooltipGroup(child: child!)),
      ),
    );
  }
}
