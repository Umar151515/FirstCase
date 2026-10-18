import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../auth/presentation/login_page.dart';
import '../../portfolio/presentation/portfolio_page.dart';
import '../../orders/presentation/order_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({this.id, super.key});
  final int? id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    if (id == null && session == null) return requireLogin(context);
    final userId = id ?? session!.id;
    final own = userId == session?.id;
    return PageBody(
      width: 1000,
      children: [
        ResourceView(
          own ? '/auth/me' : '/users/$userId',
          builder: (data) {
            final person = Person(Map<String, dynamic>.from(data as Map));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PersonAvatar(person, size: 74),
                          const SizedBox(width: 22),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person.name,
                                  style: const TextStyle(
                                    fontSize: 29,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  person.specialty.isEmpty
                                      ? 'Открыт к новым возможностям'
                                      : person.specialty,
                                  style: const TextStyle(color: muted),
                                ),
                                const SizedBox(height: 10),
                                Tag(
                                  person.city,
                                  icon: FLucideIcons.mapPin,
                                  color: muted,
                                ),
                              ],
                            ),
                          ),
                          if (own && MediaQuery.sizeOf(context).width > 600)
                            FButton(
                              variant: .outline,
                              mainAxisSize: MainAxisSize.min,
                              onPress: () => context.go('/profile/edit'),
                              child: const Text('Редактировать'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Wrap(
                        spacing: 28,
                        runSpacing: 18,
                        children: [
                          _Stat(
                            person.rating == 0
                                ? '—'
                                : person.rating.toStringAsFixed(1),
                            'Рейтинг',
                          ),
                          _Stat(
                            '${person.json['review_count'] ?? 0}',
                            'Отзывов',
                          ),
                          _Stat(
                            '${person.json['completed_orders'] ?? 0}',
                            'Завершено заказов',
                          ),
                          _Stat(
                            '${person.json['verified_cases'] ?? 0}',
                            'Подтверждённых кейсов',
                          ),
                        ],
                      ),
                      if (person.bio.isNotEmpty) ...[
                        const SizedBox(height: 25),
                        Text(person.bio, style: const TextStyle(height: 1.8)),
                      ],
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: person.skills.map((s) => Tag(s)).toList(),
                      ),
                      if ((person.json['work_links'] as List? ?? [])
                          .isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          children: (person.json['work_links'] as List)
                              .map(
                                (link) => FButton(
                                  variant: .outline,
                                  mainAxisSize: MainAxisSize.min,
                                  onPress: () => launchUrl(
                                    Uri.parse(link),
                                    mode: LaunchMode.externalApplication,
                                  ),
                                  child: Text(Uri.parse(link as String).host),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (own) ...[
                            FButton(
                              variant: .outline,
                              onPress: () => context.go('/profile/edit'),
                              child: const Text('Настроить профиль'),
                            ),
                            FButton(
                              variant: .outline,
                              onPress: () => context.go('/tips'),
                              child: const Text('QR для чаевых'),
                            ),
                            FButton(
                              variant: .ghost,
                              onPress: () => context.go('/reports'),
                              child: const Text('Мои жалобы'),
                            ),
                            if (person.admin)
                              FButton(
                                onPress: () => context.go('/admin'),
                                prefix: const Icon(
                                  FLucideIcons.shieldCheck,
                                  size: 16,
                                ),
                                child: const Text('Администрирование'),
                              ),
                            ActionButton(
                              'Выйти',
                              secondary: true,
                              action: () async {
                                await ref
                                    .read(sessionProvider.notifier)
                                    .logout();
                                if (context.mounted) context.go('/');
                              },
                            ),
                          ] else ...[
                            FButton(
                              variant: .outline,
                              onPress: () => modal(context, TipsViewer(userId)),
                              child: const Text('Поблагодарить ♡'),
                            ),
                            if (session != null)
                              FButton(
                                variant: .ghost,
                                onPress: () =>
                                    modal(context, ReportForm('user', userId)),
                                child: const Text('Пожаловаться'),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                PageTitle(
                  own ? 'Моё портфолио' : 'Портфолио',
                  subtitle: 'Опыт, подтверждённый реальными делами.',
                  action: own
                      ? FButton(
                          variant: .outline,
                          onPress: () => context.go('/portfolio/new'),
                          child: const Text('Добавить работу'),
                        )
                      : null,
                ),
                ResourceView(
                  own
                      ? '/portfolio?mine=true&limit=100'
                      : '/portfolio?user_id=$userId&limit=100',
                  builder: (data) {
                    final cases = items(data);
                    return cases.isEmpty
                        ? const StateMessage(
                            'Здесь будет первый кейс',
                            subtitle: 'Выполните задачу и сохраните историю своего успеха.',
                            icon: FLucideIcons.folderHeart,
                          )
                        : PortfolioGrid(cases);
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: accent,
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: muted, fontSize: 11)),
    ],
  );
}
