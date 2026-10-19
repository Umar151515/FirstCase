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
                height: mobile ? 64 : 76,
                decoration: BoxDecoration(
                  color: paper(context),
                  border: Border(bottom: BorderSide(color: edge(context))),
                ),
                padding: EdgeInsets.symmetric(horizontal: mobile ? 18 : 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1220),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
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
                                      child: _NavLink(
                                        labels[i],
                                        selected: index == i,
                                        onTap: () => context.go(paths[i]),
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
                              mainAxisSize: MainAxisSize.min,
                              onPress: () => context.go('/tasks/new'),
                              prefix: const Icon(FLucideIcons.plus, size: 16),
                              child: Flexible(child: Text(l.navCreate)),
                            ),
                            const SizedBox(width: 14),
                          ],
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => context.go('/profile'),
                            child: PersonAvatar(user, size: 34),
                          ),
                        ] else
                          FButton(
                            mainAxisSize: MainAxisSize.min,
                            size: .sm,
                            onPress: () => context.go('/login'),
                            child: Flexible(child: Text(l.signIn)),
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
                  decoration: BoxDecoration(
                    color: context.theme.colors.muted,
                    border: Border(bottom: BorderSide(color: edge(context))),
                  ),
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
                            style: TextStyle(
                              color: quiet(context),
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
                            child: Flexible(
                              child: Text(
                                mobile ? l.demoSwitchRole : l.demoSignInAs,
                              ),
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

class _NavLink extends StatelessWidget {
  const _NavLink(this.label, {required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.symmetric(vertical: 27),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? context.theme.colors.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: selected ? context.theme.colors.primary : quiet(context),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );
}
