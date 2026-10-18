import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
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
    errorBuilder: (_, _) =>
        const Scaffold(body: Center(child: Text('Страница не найдена'))),
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
      primary: accent,
      primaryForeground: Colors.white,
      background: dark ? const Color(0xFF15151C) : const Color(0xFFFCFCFD),
      foreground: dark ? const Color(0xFFF1F0F8) : const Color(0xFF242333),
      border: dark ? const Color(0xFF30303C) : const Color(0xFFECEBF1),
    );
    final theme = FThemeData(colors: colors, touch: true);
    return MaterialApp.router(
      title: 'FirstCase · Первый опыт начинается здесь',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: FLocalizations.localizationsDelegates,
      theme: theme.toApproximateMaterialTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => FTheme(
        data: theme,
        child: FToaster(child: FTooltipGroup(child: child!)),
      ),
    );
  }
}
