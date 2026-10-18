import '../../../core/l10n/l10n.dart';

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
        PageTitle(
          context.l10n.navNotifications,
          subtitle: context.l10n.notificationsSubtitle,
        ),
        ResourceView(
          '/notifications?limit=100',
          builder: (data) => items(data).isEmpty
              ? StateMessage(
                  context.l10n.notificationsNoNew,
                  subtitle: context.l10n.notificationsEmptyHint,
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
                                      Tag(context.l10n.newBadge),
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
                                      dateLabel(
                                        context,
                                        notification['created_at'],
                                      ),
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Spacer(),
                                    ActionButton(
                                      context.l10n.open,
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
        PageTitle(
          context.l10n.reportsTitle,
          subtitle: context.l10n.reportsIntro,
        ),
        ResourceView(
          '/reports?limit=100',
          builder: (data) => items(data).isEmpty
              ? StateMessage(
                  context.l10n.reportsEmpty,
                  subtitle: context.l10n.reportsEmptyHint,
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
                                        context.l10n.reportLabel(
                                          report['id'] as int,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Tag(
                                      statusLabel(
                                        context,
                                        report['status'] as String,
                                      ),
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
                                      context.l10n.moderatorDecisionLabel(
                                        report['moderator_comment'] as String,
                                      ),
                                      style: TextStyle(
                                        color: context.theme.colors.primary,
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
