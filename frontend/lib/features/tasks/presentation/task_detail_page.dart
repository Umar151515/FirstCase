import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../../shared/widgets/attachment_button.dart';

class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage(this.id, {super.key});
  final int id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    width: 940,
    children: [
      FButton(
        variant: .ghost,
        mainAxisSize: MainAxisSize.min,
        prefix: const Icon(FLucideIcons.arrowLeft, size: 15),
        onPress: () => context.go('/tasks'),
        child: const Text('Все задачи'),
      ),
      const SizedBox(height: 20),
      ResourceView(
        '/tasks/$id',
        builder: (data) {
          final task = Task(Map<String, dynamic>.from(data as Map));
          final user = ref.watch(sessionProvider).value;
          final owner = user?.id == task.customerId;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  Tag(task.category),
                  Tag(statusLabel(task.status), color: const Color(0xFF5E8B42)),
                ],
              ),
              const SizedBox(height: 20),
              PageTitle(
                task.title,
                subtitle:
                    'Опубликовано ${dateLabel(task.json['created_at'])} · ${task.json['city'] ?? 'Удалённо'}',
              ),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PersonAvatar(task.customer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.customer.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Заказчик',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        FButton(
                          variant: .outline,
                          mainAxisSize: MainAxisSize.min,
                          onPress: () =>
                              context.go('/users/${task.customerId}'),
                          child: const Text('Профиль'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Что нужно сделать',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      task.description,
                      style: const TextStyle(height: 1.8),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Какой результат ожидается',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      task.result,
                      style: const TextStyle(height: 1.8),
                    ),
                    const SizedBox(height: 26),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        Tag(
                          'Срок: ${dateLabel(task.deadline)}',
                          icon: FLucideIcons.calendarDays,
                        ),
                        Tag(
                          '${task.revisions} правок',
                          icon: FLucideIcons.refreshCw,
                        ),
                        Tag(
                          task.tips
                              ? 'Добровольные чаевые'
                              : 'Бесплатно · за опыт',
                          icon: FLucideIcons.heart,
                        ),
                      ],
                    ),
                    if ((task.json['attachment_ids'] as List? ?? [])
                        .isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: (task.json['attachment_ids'] as List)
                            .map((id) => AttachmentButton(id as int))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (task.status == 'published' && !owner)
                          FButton(
                            onPress: () => user == null
                                ? context.go('/login')
                                : modal(context, ApplicationForm(id)),
                            prefix: const Icon(FLucideIcons.send, size: 16),
                            child: const Text('Откликнуться на задачу'),
                          ),
                        if (task.status == 'published' && owner) ...[
                          FButton(
                            onPress: () => context.go('/tasks/$id/edit'),
                            child: const Text('Редактировать'),
                          ),
                          ActionButton(
                            'Отменить задачу',
                            secondary: true,
                            action: () async {
                              if (await confirm(
                                context,
                                'Отменить задачу?',
                                'Она больше не будет доступна для откликов.',
                              )) {
                                await mutate(ref, '/tasks/$id/cancel');
                              }
                            },
                          ),
                        ],
                        if (user != null && !owner)
                          FButton(
                            variant: .ghost,
                            onPress: () =>
                                modal(context, ReportForm('task', id)),
                            child: const Text('Пожаловаться'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              if (user != null) ...[
                Text(
                  owner ? 'Отклики исполнителей' : 'Мой отклик',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                ResourceView(
                  '/tasks/$id/applications',
                  builder: (data) {
                    final applications = items(data);
                    if (applications.isEmpty) {
                      return StateMessage(
                        owner
                            ? 'Первые отклики уже в пути'
                            : 'Станьте частью этой истории',
                        subtitle: owner
                            ? 'Исполнители увидят вашу задачу в каталоге.'
                            : 'Расскажите, почему хотите взяться за задачу.',
                      );
                    }
                    return Column(
                      children: applications.map((application) {
                        final person = Person(
                          Map<String, dynamic>.from(
                            application['performer'] as Map,
                          ),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Panel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    PersonAvatar(person),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        person.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Tag(
                                      statusLabel(
                                        application['status'] as String,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  application['message'] as String,
                                  style: const TextStyle(height: 1.6),
                                ),
                                if ('${application['comment'] ?? ''}'
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      application['comment'] as String,
                                      style: const TextStyle(color: muted),
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                Text(
                                  'Предлагаемый срок: ${dateLabel(application['proposed_deadline'])}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    FButton(
                                      variant: .outline,
                                      mainAxisSize: MainAxisSize.min,
                                      onPress: () =>
                                          context.go('/users/${person.id}'),
                                      child: const Text('Профиль и портфолио'),
                                    ),
                                    if (application['status'] == 'pending' &&
                                        owner) ...[
                                      ActionButton(
                                        'Выбрать исполнителя',
                                        action: () async {
                                          if (!await confirm(
                                            context,
                                            'Начать работу вместе?',
                                            'После выбора исполнителя откроется заказ с личным чатом.',
                                          )) {
                                            return;
                                          }
                                          final order = await mutate(
                                            ref,
                                            '/applications/${application['id']}/accept',
                                          );
                                          if (context.mounted) {
                                            context.go(
                                              '/orders/${order['id']}',
                                            );
                                          }
                                        },
                                      ),
                                      ActionButton(
                                        'Отклонить',
                                        secondary: true,
                                        action: () async {
                                          await mutate(
                                            ref,
                                            '/applications/${application['id']}/reject',
                                          );
                                        },
                                      ),
                                    ],
                                    if (application['status'] == 'pending' &&
                                        !owner)
                                      ActionButton(
                                        'Отозвать отклик',
                                        secondary: true,
                                        action: () async {
                                          await mutate(
                                            ref,
                                            '/applications/${application['id']}/withdraw',
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    ],
  );
}

class ApplicationForm extends ConsumerStatefulWidget {
  const ApplicationForm(this.id, {super.key});
  final int id;
  @override
  ConsumerState<ApplicationForm> createState() => _ApplicationFormState();
}

class _ApplicationFormState extends ConsumerState<ApplicationForm> {
  final form = GlobalKey<FormState>();
  final message = TextEditingController();
  final comment = TextEditingController();
  final days = TextEditingController(text: '5');
  @override
  void dispose() {
    message.dispose();
    comment.dispose();
    days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageTitle(
          'Ваш первый шаг',
          subtitle: 'Расскажите, чем задача вам интересна и как вы её решите.',
        ),
        Field('Почему вы подходите?', message, minLength: 10, lines: 4),
        Field(
          'За сколько дней справитесь?',
          days,
          validator: (v) =>
              (int.tryParse(v ?? '') ?? 0) < 1 ||
                  (int.tryParse(v ?? '') ?? 0) > 365
              ? 'Укажите от 1 до 365 дней'
              : null,
        ),
        Field('Дополнительный комментарий', comment, lines: 2, required: false),
        ActionButton(
          'Отправить отклик',
          action: () async {
            if (!form.currentState!.validate()) return;
            await mutate(
              ref,
              '/tasks/${widget.id}/applications',
              data: {
                'message': message.text.trim(),
                'comment': comment.text.trim(),
                'proposed_deadline': DateTime.now()
                    .add(Duration(days: int.parse(days.text)))
                    .toUtc()
                    .toIso8601String(),
              },
            );
            if (context.mounted) {
              Navigator.pop(context);
              feedback(context, 'Отклик отправлен заказчику');
            }
          },
        ),
      ],
    ),
  );
}
