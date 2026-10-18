import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../../shared/widgets/attachment_button.dart';
import '../../auth/presentation/login_page.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionProvider).value == null) return requireLogin(context);
    return PageBody(
      width: 850,
      children: [
        const PageTitle(
          'Важное рядом',
          subtitle: 'Отклики, сообщения и маленькие победы ваших проектов.',
        ),
        ResourceView(
          '/notifications?limit=100',
          builder: (data) => items(data).isEmpty
              ? const StateMessage(
                  'Пока тихо',
                  subtitle: 'Здесь появятся новости ваших заказов.',
                  icon: FLucideIcons.bell,
                )
              : Column(
                  children: items(data)
                      .map(
                        (notification) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Panel(
                            color: notification['read_at'] == null
                                ? accent.withValues(alpha: .04)
                                : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification['title'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (notification['read_at'] == null)
                                      const Tag('Новое'),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  notification['body'] as String,
                                  style: const TextStyle(
                                    color: muted,
                                    height: 1.7,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Text(
                                      dateLabel(notification['created_at']),
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Spacer(),
                                    ActionButton(
                                      'Открыть',
                                      secondary: true,
                                      action: () async {
                                        await mutate(
                                          ref,
                                          '/notifications/${notification['id']}/read',
                                        );
                                        final link =
                                            notification['link'] as String?;
                                        if (context.mounted &&
                                            link != null &&
                                            link.startsWith('/') &&
                                            !link.startsWith('//')) {
                                          context.go(link);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionProvider).value == null) return requireLogin(context);
    return PageBody(
      width: 850,
      children: [
        const PageTitle(
          'Мои обращения',
          subtitle: 'Следите за рассмотрением жалоб и решениями модерации.',
        ),
        ResourceView(
          '/reports?limit=100',
          builder: (data) => items(data).isEmpty
              ? const StateMessage(
                  'Нет обращений',
                  subtitle: 'Сообщить о нарушении можно со страницы задачи, заказа, профиля или кейса.',
                  icon: FLucideIcons.shieldCheck,
                )
              : Column(
                  children: items(data)
                      .map(
                        (report) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Panel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Обращение #${report['id']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Tag(
                                      statusLabel(report['status'] as String),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  report['description'] as String,
                                  style: const TextStyle(height: 1.7),
                                ),
                                if ('${report['moderator_comment'] ?? ''}'
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 18),
                                    child: Text(
                                      'Решение модератора: ${report['moderator_comment']}',
                                      style: const TextStyle(
                                        color: accent,
                                        height: 1.7,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      (report['attachment_ids'] as List? ?? [])
                                          .map(
                                            (id) => AttachmentButton(id as int),
                                          )
                                          .toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}
