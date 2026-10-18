import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../../shared/widgets/attachment_button.dart';
import '../../auth/presentation/login_page.dart';
import '../../chat/presentation/chat_panel.dart';
import 'order_forms.dart';

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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tag('ЗАКАЗ #$id', icon: FLucideIcons.briefcaseBusiness),
                const SizedBox(height: 16),
                PageTitle(
                  task.title,
                  subtitle: 'Ваше пространство для хорошей совместной работы',
                ),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          Tag(statusLabel(status)),
                          Tag(
                            'До ${dateLabel(task.deadline)}',
                            icon: FLucideIcons.calendar,
                          ),
                          Tag(
                            'Правки: ${order['revisions_used']} из ${order['max_revisions']}',
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
                        'Результат: ${task.result}',
                        style: const TextStyle(color: muted, height: 1.7),
                      ),
                      if ((task.json['attachment_ids'] as List? ?? [])
                          .isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const Text(
                          'Файлы задания',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final id
                                in task.json['attachment_ids'] as List)
                              AttachmentButton(id as int),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (performer && status == 'assigned')
                            ActionButton(
                              'Начать работу',
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
                              onPress: () => modal(context, SubmitForm(id)),
                              child: const Text('Сдать работу'),
                            ),
                          if (customer && status == 'submitted') ...[
                            ActionButton(
                              'Принять работу',
                              icon: FLucideIcons.check,
                              action: () async {
                                if (!await confirm(
                                  context,
                                  'Принять результат?',
                                  'После принятия нужно оставить отзыв. Именно он успешно завершит заказ.',
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
                                child: const Text('Запросить правки'),
                              ),
                          ],
                          if (customer && status == 'accepted_pending_review')
                            FButton(
                              onPress: () => modal(context, ReviewForm(id)),
                              child: const Text('Оставить обязательный отзыв'),
                            ),
                          if (performer && status == 'completed')
                            FButton(
                              onPress: () =>
                                  context.go('/portfolio/new?order_id=$id'),
                              prefix: const Icon(
                                FLucideIcons.badgeCheck,
                                size: 16,
                              ),
                              child: const Text('Добавить в портфолио'),
                            ),
                          if (performer && status == 'completed')
                            FButton(
                              variant: .outline,
                              onPress: () => modal(
                                context,
                                ReviewForm(id, requiredComment: false),
                              ),
                              child: const Text('Оценить заказчика'),
                            ),
                          if (customer && status == 'completed')
                            FButton(
                              variant: .outline,
                              onPress: () => modal(
                                context,
                                TipsViewer(order['performer_id'] as int),
                              ),
                              child: const Text('Поблагодарить исполнителя ♡'),
                            ),
                          if ([
                            'assigned',
                            'in_progress',
                            'revision_requested',
                          ].contains(status))
                            ActionButton(
                              'Отменить заказ',
                              secondary: true,
                              action: () async {
                                if (await confirm(
                                  context,
                                  'Отменить заказ?',
                                  'Обсудите это решение со вторым участником. Отмена сохранится в истории.',
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
                              'Открыть спор',
                              secondary: true,
                              action: () async {
                                if (!await confirm(
                                  context,
                                  'Открыть спор?',
                                  'Исполнение приостановится. Опишите ситуацию команде модерации в жалобе.',
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
                            child: const Text('Пожаловаться'),
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
                            ? 'Остался один важный шаг: оставьте отзыв. Он завершит заказ и подтвердит опыт исполнителя.'
                            : 'Работа принята! Ждём отзыв заказчика, после чего вы сможете создать подтверждённый кейс.',
                        style: const TextStyle(color: accent, height: 1.6),
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
                        const Text(
                          'Результаты работы',
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
                                  'ВЕРСИЯ ${deliverable['version']} · ${dateLabel(deliverable['created_at'])}',
                                  icon: FLucideIcons.packageCheck,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  deliverable['description'] as String,
                                  style: const TextStyle(height: 1.7),
                                ),
                                const SizedBox(height: 14),
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
                                        child: const Text(
                                          'Открыть результат ↗',
                                        ),
                                      ),
                                    for (final attachment
                                        in (deliverable['attachment_ids']
                                                as List? ??
                                            []))
                                      AttachmentButton(attachment as int),
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
                        const Text(
                          'Отзывы о сотрудничестве',
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
                                        'Отзыв от ${review['author_id'] == order['customer_id'] ? 'заказчика' : 'исполнителя'} · ${dateLabel(review['created_at'])}',
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
                    'Настроить разрешения на публикацию',
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
                        const Text(
                          'История заказа',
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
                                const Icon(
                                  FLucideIcons.circleCheck,
                                  size: 14,
                                  color: accent,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    statusLabel(event['type'] as String),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  dateLabel(event['created_at']),
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
      const PageTitle(
        'Спасибо за хорошую работу ♡',
        subtitle: 'Чаевые — только по вашему желанию. Заказ и приватность не зависят от перевода.',
      ),
      ResourceView(
        '/users/$userId/tips',
        builder: (data) {
          if (data == null || data['enabled'] != true) {
            return const StateMessage(
              'Исполнитель ещё не добавил QR',
              subtitle: 'Тёплый отзыв тоже очень ценен.',
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
                  filename: 'Посмотреть QR-код',
                ),
              if (data['payment_url'] != null) ...[
                const SizedBox(height: 12),
                FButton(
                  variant: .outline,
                  onPress: () => launchUrl(
                    Uri.parse(data['payment_url'] as String),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('Открыть платёжную ссылку ↗'),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'Перевод выполняется во внешнем приложении. FirstCase не принимает деньги, не берёт комиссию и не подтверждает получение перевода.',
                style: TextStyle(color: muted, height: 1.6, fontSize: 12),
              ),
            ],
          );
        },
      ),
    ],
  );
}
