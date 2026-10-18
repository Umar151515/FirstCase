import '../../../core/l10n/l10n.dart';

import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: PageBody(
        width: 540,
        children: [
          const SizedBox(height: 50),
          const Brand(),
          const SizedBox(height: 40),
          PageTitle(
            context.l10n.loginFirstCase,
            subtitle: context.l10n.loginSubtitle,
          ),
          ref
              .watch(modeProvider)
              .when(
                data: (mode) => mode == 'demo'
                    ? const IdentityPicker()
                    : StateMessage(
                        context.l10n.loginTelegram,
                        subtitle: context.l10n.loginTelegramHint,
                        icon: FLucideIcons.send,
                      ),
                loading: () => const LoadingView(),
                error: (e, _) => StateMessage(
                  context.l10n.serverUnavailable,
                  subtitle: '$e',
                  action: FButton(
                    onPress: () => ref.invalidate(modeProvider),
                    child: Text(context.l10n.retry),
                  ),
                ),
              ),
          const SizedBox(height: 22),
          if (ref.watch(sessionProvider).hasError)
            StateMessage(
              context.l10n.loginFailed,
              subtitle: '${ref.watch(sessionProvider).error}',
              action: FButton(
                onPress: () => ref.invalidate(sessionProvider),
                child: Text(context.l10n.retryLogin),
              ),
            ),
          FButton(
            variant: .ghost,
            onPress: () => context.go('/'),
            child: Text(context.l10n.browseWithoutLogin),
          ),
        ],
      ),
    ),
  );
}

class IdentityPicker extends ConsumerWidget {
  const IdentityPicker({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.demoSignInAs,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 9),
      Text(
        context.l10n.demoAccountsHint,
        style: TextStyle(color: muted, height: 1.5),
      ),
      const SizedBox(height: 20),
      ref
          .watch(demoUsersProvider)
          .when(
            data: (users) => Column(
              children: users.map((user) => _IdentityRow(user)).toList(),
            ),
            loading: () => const LoadingView(),
            error: (e, _) => StateMessage(
              context.l10n.demoAccountsFailed,
              subtitle: '$e',
              action: FButton(
                onPress: () => ref.invalidate(demoUsersProvider),
                child: Text(context.l10n.retry),
              ),
            ),
          ),
    ],
  );
}

class _IdentityRow extends ConsumerWidget {
  const _IdentityRow(this.user);
  final Person user;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Panel(
      padding: 12,
      child: Row(
        children: [
          PersonAvatar(user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  user.admin
                      ? context.l10n.roleAdmin
                      : user.specialty.isEmpty
                      ? context.l10n.roleCustomer
                      : user.specialty,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          ActionButton(
            context.l10n.signIn,
            secondary: true,
            action: () async {
              await ref.read(sessionProvider.notifier).demo(user.id);
              final state = ref.read(sessionProvider);
              if (state.hasError) throw state.error!;
              if (context.mounted) {
                if (Navigator.canPop(context)) Navigator.pop(context);
                context.go(state.value!.onboarded ? '/' : '/onboarding');
              }
            },
          ),
        ],
      ),
    ),
  );
}

Widget requireLogin(BuildContext context) => StateMessage(
  context.l10n.signInRequired,
  subtitle: context.l10n.loginRequiredHint,
  icon: FLucideIcons.userRound,
  action: FButton(
    onPress: () => context.go('/login'),
    child: Text(context.l10n.loginFirstCase),
  ),
);
