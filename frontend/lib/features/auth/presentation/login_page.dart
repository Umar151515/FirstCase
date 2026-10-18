import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell.dart';
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
          const PageTitle(
            'Большой путь\nс первого кейса.',
            subtitle: 'Знакомьтесь, работайте вместе и собирайте репутацию, подтверждённую реальными делами.',
          ),
          ref
              .watch(modeProvider)
              .when(
                data: (mode) => mode == 'demo'
                    ? const IdentityPicker()
                    : const StateMessage(
                        'Откройте FirstCase в Telegram',
                        subtitle: 'Вход выполняется автоматически через защищённые данные Telegram Mini App.',
                        icon: FLucideIcons.send,
                      ),
                loading: () => const LoadingView(),
                error: (e, _) => StateMessage(
                  'Сервер недоступен',
                  subtitle: '$e',
                  action: FButton(
                    onPress: () => ref.invalidate(modeProvider),
                    child: const Text('Повторить'),
                  ),
                ),
              ),
          const SizedBox(height: 22),
          if (ref.watch(sessionProvider).hasError)
            StateMessage(
              'Не удалось войти',
              subtitle: '${ref.watch(sessionProvider).error}',
              action: FButton(
                onPress: () => ref.invalidate(sessionProvider),
                child: const Text('Повторить вход'),
              ),
            ),
          FButton(
            variant: .ghost,
            onPress: () => context.go('/'),
            child: const Text('Посмотреть заказы без входа'),
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
      const Text(
        'Войти как…',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 9),
      const Text(
        'Каждая роль — настоящий аккаунт. Изменения сохраняются на сервере.',
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
              'Не удалось получить аккаунты',
              subtitle: '$e',
              action: FButton(
                onPress: () => ref.invalidate(demoUsersProvider),
                child: const Text('Повторить'),
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
                      ? 'Администратор'
                      : user.specialty.isEmpty
                      ? 'Заказчик'
                      : user.specialty,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          ActionButton(
            'Войти',
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
  'Продолжим после знакомства',
  subtitle: 'Войдите, чтобы создавать заказы, общаться и собирать портфолио.',
  icon: FLucideIcons.userRound,
  action: FButton(
    onPress: () => context.go('/login'),
    child: const Text('Войти в FirstCase'),
  ),
);
