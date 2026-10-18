import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../../shared/widgets/attachment_button.dart';

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});
  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  String tab = 'stats';
  String status = '';
  String query = '';
  int offset = 0;
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider).value?.admin != true) {
      return const StateMessage(
        'Доступ ограничен',
        subtitle: 'Этот раздел доступен администраторам платформы.',
        icon: FLucideIcons.lockKeyhole,
      );
    }
    final path = Uri(
      path: '/admin/$tab',
      queryParameters: {
        'limit': '20',
        'offset': '$offset',
        if (query.isNotEmpty) 'q': query,
        if (status.isNotEmpty) 'status': status,
      },
    ).toString();
    return PageBody(
      children: [
        const PageTitle(
          'Пульс FirstCase',
          subtitle: 'Управляйте платформой, помогайте участникам и защищайте доверие.',
        ),
        ChoiceField(
          'Администрирование',
          value: tab,
          options: const {
            'stats': 'Обзор',
            'users': 'Пользователи',
            'tasks': 'Задачи',
            'orders': 'Заказы',
            'reports': 'Жалобы',
            'moderation-actions': 'Журнал действий',
          },
          onChange: (v) => setState(() {
            tab = v;
            status = '';
            query = '';
            offset = 0;
            search.clear();
          }),
        ),
        if (tab == 'stats')
          ResourceView(
            '/admin/stats',
            builder: (data) => LayoutBuilder(
              builder: (context, constraints) {
                final labels = {
                  'users': 'Пользователей',
                  'active_tasks': 'Активных задач',
                  'completed_orders': 'Завершённых заказов',
                  'applications': 'Откликов',
                  'reviews': 'Отзывов',
                  'verified_cases': 'Подтверждённых кейсов',
                  'open_reports': 'Открытых жалоб',
                };
                final columns = constraints.maxWidth > 900
                    ? 4
                    : constraints.maxWidth > 550
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - 16 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: labels.entries
                      .map(
                        (entry) => SizedBox(
                          width: width,
                          child: Panel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${data[entry.key] ?? 0}',
                                  style: const TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  entry.value,
                                  style: const TextStyle(color: muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          )
        else ...[
          if (tab == 'users')
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  Expanded(
                    child: FTextField(
                      control: .managed(controller: search),
                      hint: 'Поиск пользователей',
                      onSubmit: (v) => setState(() {
                        query = v;
                        offset = 0;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FButton(
                    onPress: () => setState(() {
                      query = search.text;
                      offset = 0;
                    }),
                    child: const Text('Найти'),
                  ),
                ],
              ),
            ),
          if (tab != 'moderation-actions')
            ChoiceField(
              'Фильтр',
              value: status,
              options: {
                '': 'Все',
                ...switch (tab) {
                  'users' => {
                    'active': 'Активные',
                    'blocked': 'Заблокированные',
                  },
                  'reports' => {
                    'pending': 'Новые',
                    'in_review': 'На рассмотрении',
                    'resolved': 'Решённые',
                    'rejected': 'Отклонённые',
                  },
                  'tasks' => {
                    'published': 'Открытые',
                    'assigned': 'В работе',
                    'completed': 'Завершённые',
                    'cancelled': 'Отменённые',
                  },
                  _ => {
                    'assigned': 'Назначенные',
                    'in_progress': 'В работе',
                    'submitted': 'На проверке',
                    'completed': 'Завершённые',
                    'disputed': 'Споры',
                  },
                },
              },
              onChange: (v) => setState(() {
                status = v;
                offset = 0;
              }),
            ),
          ResourceView(
            path,
            builder: (data) {
              final list = items(data);
              return Column(
                children: [
                  if (list.isEmpty)
                    const StateMessage(
                      'Здесь пока пусто',
                      subtitle: 'Попробуйте изменить фильтр.',
                    ),
                  for (final row in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Panel(child: _row(context, row)),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FButton(
                        variant: .outline,
                        onPress: offset == 0
                            ? null
                            : () => setState(() => offset -= 20),
                        child: const Text('Назад'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(15),
                        child: Text('${offset ~/ 20 + 1}'),
                      ),
                      FButton(
                        variant: .outline,
                        onPress: offset + 20 >= (data['total'] as int)
                            ? null
                            : () => setState(() => offset += 20),
                        child: const Text('Дальше'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, Json row) {
    if (tab == 'users') {
      final person = Person(row);
      final blocked = row['status'] == 'blocked';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PersonAvatar(person),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  person.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Tag(
                blocked ? 'Заблокирован' : 'Активен',
                color: blocked ? const Color(0xFFBE4354) : accent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FButton(
                variant: .outline,
                onPress: () => context.go('/users/${person.id}'),
                child: const Text('Профиль'),
              ),
              FButton(
                onPress: () => modal(
                  context,
                  AdminActionForm(
                    title: blocked
                        ? 'Разблокировать пользователя'
                        : 'Заблокировать пользователя',
                    path: '/admin/users/${person.id}',
                    data: {'status': blocked ? 'active' : 'blocked'},
                  ),
                ),
                child: Text(blocked ? 'Разблокировать' : 'Заблокировать'),
              ),
            ],
          ),
        ],
      );
    }
    if (tab == 'tasks') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row['title'] as String,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              Tag(statusLabel(row['status'] as String)),
              if (row['is_hidden'] == true)
                const Tag('Скрыта', color: Color(0xFFBE4354)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FButton(
                variant: .outline,
                onPress: () => context.go('/tasks/${row['id']}'),
                child: const Text('Открыть задачу'),
              ),
              FButton(
                onPress: () => modal(
                  context,
                  AdminActionForm(
                    title: row['is_hidden'] == true
                        ? 'Вернуть публикацию'
                        : 'Скрыть публикацию',
                    path: '/admin/tasks/${row['id']}',
                    data: {'is_hidden': row['is_hidden'] != true},
                  ),
                ),
                child: Text(row['is_hidden'] == true ? 'Вернуть' : 'Скрыть'),
              ),
            ],
          ),
        ],
      );
    }
    if (tab == 'orders') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${row['id']} · ${(row['task'] as Map)['title']}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Tag(statusLabel(row['status'] as String)),
          const SizedBox(height: 12),
          Text(
            'Заказчик: ${(row['customer'] as Map)['display_name']}\nИсполнитель: ${(row['performer'] as Map)['display_name']}',
            style: const TextStyle(height: 1.8),
          ),
          const SizedBox(height: 12),
          const Text(
            'Доступ к переписке открывается только через разбор конкретной жалобы и фиксируется в журнале.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FButton(
                variant: .outline,
                onPress: () => modal(
                  context,
                  ResourceView(
                    '/admin/orders/${row['id']}/events',
                    builder: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PageTitle('История заказа'),
                        for (final event in items(data))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '${statusLabel(event['type'] as String)} · ${dateLabel(event['created_at'])}',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                child: const Text('История событий'),
              ),
              if (row['status'] == 'disputed') ...[
                FButton(
                  onPress: () => modal(
                    context,
                    AdminActionForm(
                      title: 'Возобновить заказ после спора',
                      path: '/admin/orders/${row['id']}/resolve-dispute',
                      data: const {'action': 'resume'},
                      method: 'POST',
                    ),
                  ),
                  child: const Text('Возобновить работу'),
                ),
                FButton(
                  variant: .outline,
                  onPress: () => modal(
                    context,
                    AdminActionForm(
                      title: 'Отменить спорный заказ',
                      path: '/admin/orders/${row['id']}/resolve-dispute',
                      data: const {'action': 'cancel'},
                      method: 'POST',
                    ),
                  ),
                  child: const Text('Отменить заказ'),
                ),
              ],
            ],
          ),
        ],
      );
    }
    if (tab == 'reports') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Жалоба #${row['id']} · ${row['target_type']} #${row['target_id']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Tag(statusLabel(row['status'] as String)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            row['description'] as String,
            style: const TextStyle(height: 1.7),
          ),
          if ('${row['moderator_comment'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Решение: ${row['moderator_comment']}',
                style: const TextStyle(color: accent),
              ),
            ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FButton(
                onPress: () =>
                    modal(context, ReportDecisionForm(row['id'] as int)),
                child: const Text('Обработать жалобу'),
              ),
              if (['pending', 'in_review'].contains(row['status']))
                FButton(
                  variant: .outline,
                  onPress: () => modal(context, EvidenceForm(row['id'] as int)),
                  child: const Text('Изучить доказательства'),
                ),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${row['action'] ?? row['type'] ?? 'Действие'} · #${row['id']}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SelectableText(
          const JsonEncoder.withIndent('  ').convert(row),
          style: const TextStyle(fontSize: 11, color: muted, height: 1.5),
        ),
      ],
    );
  }
}

class AdminActionForm extends ConsumerStatefulWidget {
  const AdminActionForm({
    required this.title,
    required this.path,
    required this.data,
    this.method = 'PATCH',
    super.key,
  });
  final String title;
  final String path;
  final Json data;
  final String method;
  @override
  ConsumerState<AdminActionForm> createState() => _AdminActionFormState();
}

class _AdminActionFormState extends ConsumerState<AdminActionForm> {
  final form = GlobalKey<FormState>();
  final reason = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          widget.title,
          subtitle:
              'Действие и его основание будут сохранены в журнале модерации.',
        ),
        Field('Основание', reason, lines: 3, minLength: 10),
        ActionButton(
          'Подтвердить действие',
          action: () async {
            if (!form.currentState!.validate()) return;
            await mutate(
              ref,
              widget.path,
              method: widget.method,
              data: {...widget.data, 'reason': reason.text.trim()},
            );
            if (context.mounted) {
              Navigator.pop(context);
              feedback(context, 'Действие выполнено');
            }
          },
        ),
      ],
    ),
  );
}

class ReportDecisionForm extends ConsumerStatefulWidget {
  const ReportDecisionForm(this.id, {super.key});
  final int id;
  @override
  ConsumerState<ReportDecisionForm> createState() => _ReportDecisionFormState();
}

class _ReportDecisionFormState extends ConsumerState<ReportDecisionForm> {
  final form = GlobalKey<FormState>();
  final comment = TextEditingController();
  String status = 'in_review';
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle('Решение по жалобе #${widget.id}'),
        ChoiceField(
          'Статус',
          value: status,
          options: const {
            'in_review': 'На рассмотрении',
            'resolved': 'Решена',
            'rejected': 'Отклонена',
          },
          onChange: (v) => setState(() => status = v),
        ),
        Field('Комментарий модератора', comment, lines: 4, minLength: 5),
        ActionButton(
          'Сохранить решение',
          action: () async {
            if (!form.currentState!.validate()) return;
            await mutate(
              ref,
              '/admin/reports/${widget.id}',
              method: 'PATCH',
              data: {
                'status': status,
                'moderator_comment': comment.text.trim(),
              },
            );
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}

class EvidenceForm extends ConsumerStatefulWidget {
  const EvidenceForm(this.id, {super.key});
  final int id;
  @override
  ConsumerState<EvidenceForm> createState() => _EvidenceFormState();
}

class _EvidenceFormState extends ConsumerState<EvidenceForm> {
  final form = GlobalKey<FormState>();
  final reason = TextEditingController();
  Json? evidence;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageTitle(
          'Доступ к доказательствам',
          subtitle: 'Укажите основание доступа к приватным данным. Просмотр и скачивание файлов попадут в аудит.',
        ),
        Field('Зачем нужен доступ?', reason, lines: 3, minLength: 10),
        ActionButton(
          'Открыть материалы',
          action: () async {
            if (!form.currentState!.validate()) return;
            final data = await ref
                .read(taskRepositoryProvider)
                .mutate(
                  '/admin/reports/${widget.id}/evidence-access',
                  data: {'reason': reason.text.trim()},
                );
            if (mounted) {
              setState(() => evidence = Map<String, dynamic>.from(data as Map));
            }
            ref.invalidate(
              resourceProvider('/admin/moderation-actions?limit=20&offset=0'),
            );
          },
        ),
        if (evidence != null) ...[
          const SizedBox(height: 20),
          for (final message in (evidence!['messages'] as List? ?? []))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: 12,
                child: Text(
                  '${(message as Map)['text']}',
                  style: const TextStyle(height: 1.6),
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (evidence!['attachments'] as List? ?? [])
                .map(
                  (file) => AttachmentButton(
                    (file as Map)['id'] as int,
                    filename: file['filename'] as String?,
                    path:
                        '/admin/reports/${widget.id}/attachments/${file['id']}',
                  ),
                )
                .toList(),
          ),
          if (evidence!['portfolio'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                '${evidence!['portfolio']}',
                style: const TextStyle(height: 1.7),
              ),
            ),
        ],
      ],
    ),
  );
}
