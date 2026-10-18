import '../../../core/l10n/l10n.dart';

import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../../shared/widgets/attachment_button.dart';
import '../../../shared/widgets/media.dart';
import '../../auth/presentation/login_page.dart';
import '../../chat/presentation/chat_panel.dart';
import 'order_forms.dart';
import '../../tasks/presentation/ai_policy.dart';

class OrderPage extends ConsumerWidget {
  const OrderPage(this.id, {super.key});
  final int id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value;
    if (user == null) return requireLogin(context);
    return PageBody(
      width: 980,
      children: [
        ResourceView(
          '/orders/$id',
          builder: (data) {
            final order = Map<String, dynamic>.from(data as Map);
            final task = Task(Map<String, dynamic>.from(order['task'] as Map));
            final customer = order['customer_id'] == user.id;
            final performer = order['performer_id'] == user.id;
            final status = order['status'] as String;
            final aiPolicy = AiPolicy.fromCode(order['ai_policy'] as String?);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tag(
                  context.l10n.orderNumber(id),
                  icon: FLucideIcons.briefcaseBusiness,
                ),
                const SizedBox(height: 16),
                PageTitle(task.title, subtitle: context.l10n.orderSubtitle),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          Tag(statusLabel(context, status)),
                          Tag(aiPolicyLabel(context, aiPolicy), color: muted),
                          Tag(
                            context.l10n.dueBy(
                              dateLabel(context, task.deadline),
                            ),
                            icon: FLucideIcons.calendar,
                          ),
                          Tag(
                            context.l10n.revisionsUsed(
                              order['revisions_used'] as int,
                              order['max_revisions'] as int,
                            ),
                            color: muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        task.description,
                        style: const TextStyle(height: 1.7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.resultLabel(task.result),
                        style: const TextStyle(color: muted, height: 1.7),
                      ),
                      if ((task.json['attachment_ids'] as List? ?? [])
                          .isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          context.l10n.taskFiles,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        AttachmentGallery(
                          attachmentIds: List<int>.from(
                            task.json['attachment_ids'] as List,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (performer && status == 'assigned')
                            ActionButton(
                              context.l10n.startWork,
                              icon: FLucideIcons.play,
                              action: () async {
                                await mutate(ref, '/orders/$id/start');
                              },
                            ),
                          if (performer &&
                              [
                                'assigned',
                                'in_progress',
                                'revision_requested',
                              ].contains(status))
                            FButton(
                              onPress: () => modal(
                                context,
                                SubmitForm(id, aiPolicy: aiPolicy),
                              ),
                              child: Text(context.l10n.submitWork),
                            ),
                          if (customer && status == 'submitted') ...[
                            ActionButton(
                              context.l10n.acceptWork,
                              icon: FLucideIcons.check,
                              action: () async {
                                if (!await confirm(
                                  context,
                                  context.l10n.acceptWorkTitle,
                                  context.l10n.acceptWorkHint,
                                )) {
                                  return;
                                }
                                await mutate(ref, '/orders/$id/accept');
                                if (context.mounted) {
                                  await modal(context, ReviewForm(id));
                                }
                              },
                            ),
                            if ((order['revisions_used'] as int) <
                                (order['max_revisions'] as int))
                              FButton(
                                variant: .outline,
                                onPress: () => modal(context, RevisionForm(id)),
                                child: Text(context.l10n.requestRevision),
                              ),
                          ],
                          if (customer && status == 'accepted_pending_review')
                            FButton(
                              onPress: () => modal(context, ReviewForm(id)),
                              child: Text(context.l10n.mandatoryReview),
                            ),
                          if (performer && status == 'completed')
                            FButton(
                              onPress: () =>
                                  context.go('/portfolio/new?order_id=$id'),
                              prefix: const Icon(
                                FLucideIcons.badgeCheck,
                                size: 16,
                              ),
                              child: Text(context.l10n.addToPortfolio),
                            ),
                          if (performer && status == 'completed')
                            FButton(
                              variant: .outline,
                              onPress: () => modal(
                                context,
                                ReviewForm(id, requiredComment: false),
                              ),
                              child: Text(context.l10n.reviewCustomer),
                            ),
                          if (customer && status == 'completed')
                            FButton(
                              variant: .outline,
                              onPress: () => modal(
                                context,
                                TipsViewer(order['performer_id'] as int),
                              ),
                              child: Text(context.l10n.thankPerformerShort),
                            ),
                          if ([
                            'assigned',
                            'in_progress',
                            'revision_requested',
                          ].contains(status))
                            ActionButton(
                              context.l10n.cancelOrder,
                              secondary: true,
                              action: () async {
                                if (await confirm(
                                  context,
                                  context.l10n.cancelOrderTitle,
                                  context.l10n.cancelOrderHint,
                                )) {
                                  await mutate(ref, '/orders/$id/cancel');
                                }
                              },
                            ),
                          if (![
                            'completed',
                            'cancelled',
                            'disputed',
                          ].contains(status))
                            ActionButton(
                              context.l10n.openDispute,
                              secondary: true,
                              action: () async {
                                if (!await confirm(
                                  context,
                                  context.l10n.openDisputeTitle,
                                  context.l10n.openDisputeHint,
                                )) {
                                  return;
                                }
                                await mutate(ref, '/orders/$id/dispute');
                                if (context.mounted) {
                                  await modal(context, ReportForm('order', id));
                                }
                              },
                            ),
                          FButton(
                            variant: .ghost,
                            onPress: () =>
                                modal(context, ReportForm('order', id)),
                            child: Text(context.l10n.report),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (status == 'accepted_pending_review')
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Panel(
                      color: accent.withValues(alpha: .06),
                      child: Text(
                        customer
                            ? context.l10n.orderNeedsCustomerReview
                            : context.l10n.orderWaitingCustomerReview,
                        style: TextStyle(
                          color: context.theme.colors.primary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                ResourceView(
                  '/orders/$id/deliverables',
                  builder: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (items(data).isNotEmpty) ...[
                        Text(
                          context.l10n.workResults,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      for (final deliverable in items(data).reversed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Panel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Tag(
                                  context.l10n.resultVersion(
                                    deliverable['version'] as int,
                                    dateLabel(
                                      context,
                                      deliverable['created_at'],
                                    ),
                                  ),
                                  icon: FLucideIcons.packageCheck,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  deliverable['description'] as String,
                                  style: const TextStyle(height: 1.7),
                                ),
                                const SizedBox(height: 14),
                                Tag(
                                  aiUsageLabel(
                                    context,
                                    AiUsage.fromCode(
                                      deliverable['ai_usage'] as String?,
                                    ),
                                  ),
                                  color: muted,
                                ),
                                if ('${deliverable['ai_disclosure'] ?? ''}'
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      deliverable['ai_disclosure'] as String,
                                      style: const TextStyle(
                                        color: muted,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                AttachmentGallery(
                                  attachmentIds: List<int>.from(
                                    deliverable['attachment_ids'] as List? ??
                                        [],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final link
                                        in (deliverable['links'] as List? ??
                                            []))
                                      FButton(
                                        variant: .outline,
                                        mainAxisSize: MainAxisSize.min,
                                        onPress: () => launchUrl(
                                          Uri.parse(link as String),
                                          mode: LaunchMode.externalApplication,
                                        ),
                                        child: Text(context.l10n.openResult),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ChatPanel(id, key: ValueKey('chat:$id:${user.id}')),
                const SizedBox(height: 24),
                ResourceView(
                  '/orders/$id/reviews',
                  builder: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (items(data).isNotEmpty) ...[
                        Text(
                          context.l10n.collaborationReviews,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      for (final review in items(data))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Panel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '★' * (review['rating'] as int),
                                  style: const TextStyle(
                                    color: Color(0xFFEAB548),
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(review['comment'] as String? ?? ''),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        review['author_id'] ==
                                                order['customer_id']
                                            ? context.l10n.reviewByCustomer(
                                                dateLabel(
                                                  context,
                                                  review['created_at'],
                                                ),
                                              )
                                            : context.l10n.reviewByPerformer(
                                                dateLabel(
                                                  context,
                                                  review['created_at'],
                                                ),
                                              ),
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    FButton.icon(
                                      variant: .ghost,
                                      onPress: () => modal(
                                        context,
                                        ReportForm(
                                          'review',
                                          review['id'] as int,
                                        ),
                                      ),
                                      child: const Icon(
                                        FLucideIcons.flag,
                                        size: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (customer) ...[
                  const SizedBox(height: 12),
                  ActionButton(
                    context.l10n.configurePermissions,
                    secondary: true,
                    icon: FLucideIcons.shieldCheck,
                    action: () async {
                      final repository = ref.read(taskRepositoryProvider);
                      final messages = items(
                        await repository.resource(
                          '/orders/$id/messages?limit=100',
                        ),
                      );
                      final deliverables = items(
                        await repository.resource('/orders/$id/deliverables'),
                      );
                      final attachmentIds = <int>{
                        ...List<int>.from(
                          task.json['attachment_ids'] as List? ?? [],
                        ),
                        for (final m in [...messages, ...deliverables])
                          ...List<int>.from(m['attachment_ids'] as List? ?? []),
                      }.toList();
                      if (context.mounted) {
                        await modal(
                          context,
                          PrivacyForm(
                            id,
                            messages: messages,
                            attachmentIds: attachmentIds,
                          ),
                        );
                      }
                    },
                  ),
                ],
                const SizedBox(height: 24),
                ResourceView(
                  '/orders/$id/events',
                  builder: (data) => Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.orderHistory,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (final event in items(data).reversed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(
                                  FLucideIcons.circleCheck,
                                  size: 14,
                                  color: context.theme.colors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    statusLabel(
                                      context,
                                      event['type'] as String,
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  dateLabel(context, event['created_at']),
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class TipsViewer extends StatelessWidget {
  const TipsViewer(this.userId, {super.key});
  final int userId;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageTitle(
        context.l10n.performerGratitude,
        subtitle: context.l10n.tipsIntro,
      ),
      ResourceView(
        '/users/$userId/tips',
        builder: (data) {
          if (data == null || data['enabled'] != true) {
            return StateMessage(
              context.l10n.tipsNoQr,
              subtitle: context.l10n.tipsReviewAlternative,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${data['payment_method']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              if (data['qr_attachment_id'] != null)
                AttachmentButton(
                  data['qr_attachment_id'] as int,
                  image: true,
                  filename: context.l10n.viewQr,
                ),
              if (data['payment_url'] != null) ...[
                const SizedBox(height: 12),
                FButton(
                  variant: .outline,
                  onPress: () => launchUrl(
                    Uri.parse(data['payment_url'] as String),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(context.l10n.openPaymentLink),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                context.l10n.externalPaymentHint,
                style: TextStyle(color: muted, height: 1.6, fontSize: 12),
              ),
            ],
          );
        },
      ),
    ],
  );
}
