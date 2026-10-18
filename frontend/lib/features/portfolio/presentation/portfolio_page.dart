import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../../shared/widgets/attachment_button.dart';
import '../../auth/presentation/login_page.dart';

class PortfolioGrid extends StatelessWidget {
  const PortfolioGrid(this.cases, {super.key});
  final List<Json> cases;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth > 800
          ? 3
          : constraints.maxWidth > 550
          ? 2
          : 1;
      final width = (constraints.maxWidth - 18 * (columns - 1)) / columns;
      return Wrap(
        spacing: 18,
        runSpacing: 18,
        children: cases
            .map(
              (entry) => SizedBox(
                width: width,
                child: Panel(
                  padding: 20,
                  onTap: () => context.go('/portfolio/${entry['id']}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            entry['verified'] == true
                                ? FLucideIcons.folderCheck
                                : FLucideIcons.palette,
                            color: accent,
                            size: 44,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        entry['title'] as String,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        entry['description'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: muted,
                          height: 1.6,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Tag(
                            entry['verified'] == true
                                ? 'Подтверждённый кейс'
                                : 'Личная работа',
                            icon: entry['verified'] == true
                                ? FLucideIcons.badgeCheck
                                : FLucideIcons.brush,
                          ),
                          Tag(
                            statusLabel(entry['visibility'] as String),
                            color: muted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class PortfolioDetailPage extends ConsumerWidget {
  const PortfolioDetailPage(this.id, {super.key});
  final int id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    width: 880,
    children: [
      ResourceView(
        '/portfolio/$id',
        builder: (data) {
          final entry = Map<String, dynamic>.from(data as Map);
          final user = ref.watch(sessionProvider).value;
          final own = entry['owner_id'] == user?.id;
          final evidence = entry['evidence'] as Map? ?? {};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Tag(
                    entry['verified'] == true
                        ? 'Подтверждено реальным заказом'
                        : 'Личная работа',
                    icon: FLucideIcons.badgeCheck,
                  ),
                  Tag(statusLabel(entry['visibility'] as String), color: muted),
                ],
              ),
              const SizedBox(height: 20),
              PageTitle(
                entry['title'] as String,
                subtitle:
                    'Завершено ${dateLabel(entry['completed_at'] ?? entry['created_at'])}',
              ),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'История проекта',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SelectableText(
                      entry['description'] as String,
                      style: const TextStyle(height: 1.8),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Результат',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SelectableText(
                      entry['result'] as String,
                      style: const TextStyle(height: 1.8),
                    ),
                    if (entry['customer'] != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Заказчик: ${(entry['customer'] as Map)['display_name']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (entry['visibility'] == 'anonymous') ...[
                      const SizedBox(height: 24),
                      const Tag(
                        'Личность заказчика защищена',
                        icon: FLucideIcons.shieldCheck,
                      ),
                    ],
                    if (entry['review'] != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        '★' * ((entry['review'] as Map)['rating'] as int),
                        style: const TextStyle(
                          color: Color(0xFFEAB548),
                          fontSize: 21,
                        ),
                      ),
                      if ((entry['review'] as Map)['comment'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            (entry['review'] as Map)['comment'] as String,
                            style: const TextStyle(height: 1.6),
                          ),
                        ),
                    ],
                    if ((evidence['attachments'] as List? ?? [])
                        .isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Разрешённые материалы',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (evidence['attachments'] as List)
                            .map(
                              (a) => AttachmentButton(
                                (a as Map)['id'] as int,
                                filename: a['filename'] as String?,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    for (final message in (evidence['messages'] as List? ?? []))
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Panel(
                          color: accent.withValues(alpha: .04),
                          padding: 16,
                          child: Text(
                            '«${(message as Map)['text']}»',
                            style: const TextStyle(height: 1.7),
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FButton(
                          variant: .outline,
                          onPress: () =>
                              context.go('/users/${entry['owner_id']}'),
                          child: const Text('Профиль автора'),
                        ),
                        if (own)
                          FButton(
                            onPress: () => modal(
                              context,
                              VisibilityForm(id, entry['visibility'] as String),
                            ),
                            child: const Text('Настройки приватности'),
                          ),
                        if (user != null && !own)
                          FButton(
                            variant: .ghost,
                            onPress: () =>
                                modal(context, ReportForm('portfolio', id)),
                            child: const Text('Пожаловаться'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class PortfolioFormPage extends ConsumerStatefulWidget {
  const PortfolioFormPage({this.orderId, super.key});
  final int? orderId;
  @override
  ConsumerState<PortfolioFormPage> createState() => _PortfolioFormPageState();
}

class _PortfolioFormPageState extends ConsumerState<PortfolioFormPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final result = TextEditingController();
  String visibility = 'private';
  bool showCustomer = false;
  List<int> uploads = [];
  final Set<int> messageIds = {};
  final Set<int> attachmentIds = {};
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    result.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider).value == null) return requireLogin(context);
    return PageBody(
      width: 800,
      children: [
        PageTitle(
          widget.orderId == null
              ? 'Добавить свою работу'
              : 'Сохраните свой первый успех',
          subtitle: widget.orderId == null
              ? 'Личная работа будет отмечена как неподтверждённая.'
              : 'Кейс будет связан с завершённым заказом и подтверждённым опытом.',
        ),
        Panel(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Field('Название кейса', title, minLength: 5),
                Field(
                  'Задача и ваш подход',
                  description,
                  minLength: 10,
                  lines: 5,
                ),
                Field('Что получилось', result, minLength: 5, lines: 4),
                ChoiceField(
                  'Кто увидит кейс',
                  value: visibility,
                  options: const {
                    'private': 'Только я',
                    'anonymous': 'Публично, анонимный заказчик',
                    'public': 'Публичный кейс',
                  },
                  onChange: (v) => setState(() => visibility = v),
                ),
                const Text(
                  'Для анонимного кейса используйте безопасное описание без имён и личных данных. Исходные файлы и переписка автоматически не публикуются.',
                  style: TextStyle(color: muted, height: 1.7, fontSize: 12),
                ),
                const SizedBox(height: 20),
                if (widget.orderId == null && visibility != 'anonymous')
                  UploadField(onChange: (v) => uploads = v),
                if (visibility == 'public') ...[
                  ChoiceField(
                    'Раскрыть личность заказчика',
                    value: '$showCustomer',
                    options: const {
                      'false': 'Скрыть',
                      'true': 'Запросить публикацию с согласия',
                    },
                    onChange: (v) => setState(() => showCustomer = v == 'true'),
                  ),
                  if (widget.orderId != null) ...[
                    const Text(
                      'Выберите конкретные материалы',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Сервер опубликует их только при действующем согласии заказчика. Согласие на личность и материалы задаётся в пространстве заказа.',
                      style: TextStyle(color: muted, height: 1.6, fontSize: 12),
                    ),
                    ResourceView(
                      '/orders/${widget.orderId}/messages?limit=100',
                      builder: (data) => Column(
                        children: items(data)
                            .map(
                              (m) => Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: FButton(
                                  variant: messageIds.contains(m['id'])
                                      ? .primary
                                      : .outline,
                                  onPress: () => setState(() {
                                    final id = m['id'] as int;
                                    messageIds.contains(id)
                                        ? messageIds.remove(id)
                                        : messageIds.add(id);
                                  }),
                                  child: Text(
                                    '#${m['id']} · ${m['text']}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    ResourceView(
                      '/orders/${widget.orderId}/deliverables',
                      builder: (data) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final d in items(data))
                            for (final fileId
                                in (d['attachment_ids'] as List? ?? []))
                              FButton(
                                variant: attachmentIds.contains(fileId)
                                    ? .primary
                                    : .outline,
                                onPress: () => setState(() {
                                  attachmentIds.contains(fileId)
                                      ? attachmentIds.remove(fileId)
                                      : attachmentIds.add(fileId as int);
                                }),
                                child: Text('Файл #$fileId'),
                              ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                ActionButton(
                  'Создать кейс',
                  icon: FLucideIcons.folderCheck,
                  action: () async {
                    if (!form.currentState!.validate()) return;
                    final saved = await mutate(
                      ref,
                      '/portfolio',
                      data: {
                        'order_id': widget.orderId,
                        'title': title.text.trim(),
                        'description': description.text.trim(),
                        'result': result.text.trim(),
                        'visibility': visibility,
                        'attachment_ids': [
                          if (widget.orderId == null &&
                              visibility != 'anonymous')
                            ...uploads,
                          if (visibility == 'public') ...attachmentIds,
                        ],
                        'message_ids': visibility == 'public'
                            ? messageIds.toList()
                            : [],
                        'show_customer': visibility == 'public' && showCustomer,
                      },
                    );
                    if (context.mounted) {
                      context.go('/portfolio/${saved['id']}');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class VisibilityForm extends ConsumerStatefulWidget {
  const VisibilityForm(this.id, this.initial, {super.key});
  final int id;
  final String initial;
  @override
  ConsumerState<VisibilityForm> createState() => _VisibilityFormState();
}

class _VisibilityFormState extends ConsumerState<VisibilityForm> {
  late String value = widget.initial;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageTitle(
        'Приватность вашего кейса',
        subtitle: 'Вы управляете видимостью. Переход в публичный режим сохраняет личность заказчика скрытой.',
      ),
      ChoiceField(
        'Видимость',
        value: value,
        options: const {
          'private': 'Только мне',
          'anonymous': 'Анонимно',
          'public': 'Публично',
        },
        onChange: (v) => setState(() => value = v),
      ),
      ActionButton(
        'Обновить видимость',
        action: () async {
          await mutate(
            ref,
            '/portfolio/${widget.id}/visibility',
            method: 'PATCH',
            data: {
              'visibility': value,
              'show_customer': false,
              'message_ids': [],
              'attachment_ids': [],
            },
          );
          if (context.mounted) {
            Navigator.pop(context);
            feedback(context, 'Видимость обновлена');
          }
        },
      ),
    ],
  );
}
