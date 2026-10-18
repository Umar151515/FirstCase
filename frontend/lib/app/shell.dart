import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../core/l10n/l10n.dart';
import '../features/auth/presentation/login_page.dart';
import '../shared/widgets/ui.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, required this.location, super.key});
  final Widget child;
  final String location;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewport = MediaQuery.sizeOf(context).width;
    final mobile = viewport < 1280;
    final session = ref.watch(sessionProvider);
    final user = session.value;
    final demo = ref.watch(modeProvider).value == 'demo';
    final l = context.l10n;
    final paths = ['/', '/tasks', '/tasks/new', '/orders', '/profile'];
    final labels = [
      l.navHome,
      mobile ? l.navTasksShort : l.navTasks,
      mobile ? l.navCreateShort : l.navCreate,
      mobile ? l.navOrdersShort : l.navOrders,
      l.navProfile,
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
                height: mobile ? 64 : 80,
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
                          child: Brand(width: viewport < 380 ? 96 : 142),
                        ),
                        if (!mobile) ...[
                          const SizedBox(width: 28),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final i in [0, 1, 3])
                                    Flexible(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6,
                                        ),
                                        child: FButton(
                                          variant: .ghost,
                                          mainAxisSize: MainAxisSize.min,
                                          onPress: () => context.go(paths[i]),
                                          child: Flexible(
                                            child: Text(
                                              labels[i],
                                              style: TextStyle(
                                                color: index == i
                                                    ? context
                                                          .theme
                                                          .colors
                                                          .primary
                                                    : ink(context),
                                                fontWeight: index == i
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (mobile) const Spacer(),
                        const LanguagePicker(compact: true),
                        FButton.icon(
                          variant: .ghost,
                          semanticsLabel: l.navTheme,
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
                            semanticsLabel: l.navNotifications,
                            onPress: () => context.go('/notifications'),
                            child: const Icon(FLucideIcons.bell, size: 19),
                          ),
                          if (!mobile) ...[
                            const SizedBox(width: 10),
                            FButton(
                              onPress: () => context.go('/tasks/new'),
                              prefix: const Icon(FLucideIcons.plus, size: 16),
                              child: Text(l.navCreate),
                            ),
                            const SizedBox(width: 14),
                          ],
                          GestureDetector(
                            onTap: () => context.go('/profile'),
                            child: PersonAvatar(user, size: 34),
                          ),
                        ] else
                          FButton(
                            size: .sm,
                            onPress: () => context.go('/login'),
                            child: Text(l.signIn),
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
                          Text(
                            l.demoLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              user == null
                                  ? l.demoTryRoles
                                  : user.admin
                                  ? l.signedInAsAdmin(user.name)
                                  : l.signedInAs(user.name),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.theme.colors.mutedForeground,
                              ),
                            ),
                          ),
                          FButton(
                            size: .xs,
                            variant: .ghost,
                            mainAxisSize: MainAxisSize.min,
                            onPress: () =>
                                modal(context, const IdentityPicker()),
                            child: Text(
                              mobile ? l.demoSwitchRole : l.demoSignInAs,
                            ),
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
                    ? const Center(child: BrandLoading())
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
