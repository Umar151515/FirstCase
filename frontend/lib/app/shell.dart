import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../features/auth/presentation/login_page.dart';
import '../shared/widgets/ui.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, required this.location, super.key});
  final Widget child;
  final String location;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mobile = MediaQuery.sizeOf(context).width < 1100;
    final session = ref.watch(sessionProvider);
    final user = session.value;
    final demo = ref.watch(modeProvider).value == 'demo';
    final paths = ['/', '/tasks', '/tasks/new', '/orders', '/profile'];
    final labels = [
      'Главная',
      'Найти заказ',
      'Создать',
      'Мои заказы',
      'Профиль',
    ];
    final icons = [
      FLucideIcons.house,
      FLucideIcons.search,
      FLucideIcons.circlePlus,
      FLucideIcons.briefcaseBusiness,
      FLucideIcons.userRound,
    ];
    final index = location == '/'
        ? 0
        : location == '/tasks/new'
        ? 2
        : location.startsWith('/tasks')
        ? 1
        : location.startsWith('/orders')
        ? 3
        : 4;
    return Scaffold(
      backgroundColor: surface(context),
      body: SafeArea(
        child: Column(
          children: [
            Semantics(
              container: true,
              explicitChildNodes: true,
              child: Container(
                height: mobile ? 68 : 86,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: edge(context))),
                ),
                padding: EdgeInsets.symmetric(horizontal: mobile ? 18 : 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1220),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.go('/'),
                          child: const Brand(),
                        ),
                        if (!mobile) ...[
                          const SizedBox(width: 48),
                          for (final i in [0, 1, 3])
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: FButton(
                                variant: .ghost,
                                mainAxisSize: MainAxisSize.min,
                                onPress: () => context.go(paths[i]),
                                child: Text(
                                  labels[i],
                                  style: TextStyle(
                                    color: index == i ? accent : ink(context),
                                    fontWeight: index == i
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                        const Spacer(),
                        FButton.icon(
                          variant: .ghost,
                          semanticsLabel: 'Переключить тему',
                          onPress: () =>
                              ref.read(themeProvider.notifier).toggle(),
                          child: Icon(
                            ref.watch(themeProvider)
                                ? FLucideIcons.sun
                                : FLucideIcons.moon,
                            size: 19,
                          ),
                        ),
                        if (user != null) ...[
                          FButton.icon(
                            variant: .ghost,
                            semanticsLabel: 'Уведомления',
                            onPress: () => context.go('/notifications'),
                            child: const Icon(FLucideIcons.bell, size: 19),
                          ),
                          if (!mobile) ...[
                            const SizedBox(width: 18),
                            FButton(
                              onPress: () => context.go('/tasks/new'),
                              prefix: const Icon(FLucideIcons.plus, size: 16),
                              child: const Text('Создать заказ'),
                            ),
                            const SizedBox(width: 20),
                          ],
                          GestureDetector(
                            onTap: () => context.go('/profile'),
                            child: PersonAvatar(user, size: 34),
                          ),
                        ] else
                          FButton(
                            size: .sm,
                            onPress: () => context.go('/login'),
                            child: const Text('Войти'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (demo)
              Semantics(
                container: true,
                explicitChildNodes: true,
                child: Container(
                  color: accent.withValues(alpha: .055),
                  padding: EdgeInsets.symmetric(
                    horizontal: mobile ? 18 : 36,
                    vertical: 8,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1220),
                      child: Row(
                        children: [
                          const Tag('DEMO', color: accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              user == null
                                  ? 'Попробуйте FirstCase в любой роли'
                                  : 'Вы вошли как ${user.name}${user.admin ? ' · администратор' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: accent,
                              ),
                            ),
                          ),
                          FButton(
                            size: .xs,
                            variant: .ghost,
                            mainAxisSize: MainAxisSize.min,
                            onPress: () =>
                                modal(context, const IdentityPicker()),
                            child: const Text('Войти как…'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                child: session.isLoading
                    ? const Center(child: FCircularProgress())
                    : child,
              ),
            ),
            if (mobile)
              FBottomNavigationBar(
                index: index,
                onChange: (i) => context.go(paths[i]),
                children: List.generate(
                  5,
                  (i) => FBottomNavigationBarItem(
                    icon: Icon(icons[i]),
                    label: Text(labels[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(FLucideIcons.layers, color: Colors.white, size: 21),
      ),
      const SizedBox(width: 9),
      const Text(
        'firstcase',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 25,
          letterSpacing: -1.3,
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(left: 3),
        child: Text('●', style: TextStyle(color: accent, fontSize: 12)),
      ),
    ],
  );
}
