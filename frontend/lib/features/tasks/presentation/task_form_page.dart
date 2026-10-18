import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../auth/presentation/login_page.dart';

class TaskFormPage extends ConsumerStatefulWidget {
  const TaskFormPage({this.id, super.key});
  final int? id;
  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final result = TextEditingController();
  final city = TextEditingController(text: 'Бишкек');
  final days = TextEditingController(text: '7');
  String category = '';
  String payment = 'tips';
  String revisions = '2';
  List<int> attachments = [];
  bool loaded = false;
  Object? loadError;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loaded = false;
        loadError = null;
      });
    }
    try {
      final repository = ref.read(taskRepositoryProvider);
      final data = widget.id == null
          ? await repository.draft()
          : await repository.resource('/tasks/${widget.id}');
      if (data is Map && mounted) {
        title.text = data['title'] as String? ?? '';
        description.text = data['description'] as String? ?? '';
        result.text = data['expected_result'] as String? ?? '';
        city.text = data['city'] as String? ?? 'Бишкек';
        days.text = '${data['days'] ?? 7}';
        category = '${data['category_id'] ?? ''}';
        payment = data['payment_type'] as String? ?? 'tips';
        revisions = '${data['max_revisions'] ?? 2}';
        attachments = List<int>.from(data['attachment_ids'] as List? ?? []);
      }
    } catch (error) {
      loadError = error;
    }
    if (mounted) setState(() => loaded = true);
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    result.dispose();
    city.dispose();
    days.dispose();
    super.dispose();
  }

  Json values() => {
    'title': title.text.trim(),
    'description': description.text.trim(),
    'expected_result': result.text.trim(),
    'city': city.text.trim(),
    'category_id': int.tryParse(category),
    'payment_type': payment,
    'max_revisions': int.parse(revisions),
    'days': int.tryParse(days.text),
    'attachment_ids': attachments,
  };
  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider).value == null) return requireLogin(context);
    if (!loaded) return const PageBody(children: [LoadingView()]);
    if (loadError != null) {
      return PageBody(
        children: [
          StateMessage(
            'Не удалось открыть задачу',
            subtitle: '$loadError',
            action: FButton(onPress: load, child: const Text('Повторить')),
          ),
        ],
      );
    }
    return PageBody(
      width: 800,
      children: [
        PageTitle(
          widget.id == null
              ? 'Дайте кому-то первый шанс'
              : 'Редактировать задачу',
          subtitle: 'Расскажите о задаче. Исполнителю будет проще сделать всё как надо.',
        ),
        Panel(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Tag('01 · О ЗАДАЧЕ'),
                const SizedBox(height: 24),
                Field(
                  'Название задачи',
                  title,
                  minLength: 5,
                  hint: 'Например, сделать Telegram-бота для кофейни',
                ),
                ref
                    .watch(categoriesProvider)
                    .when(
                      data: (categories) => ChoiceField(
                        'Направление',
                        value: category,
                        options: {
                          for (final c in categories)
                            '${c['id']}': c['name'] as String,
                        },
                        onChange: (v) => setState(() => category = v),
                      ),
                      loading: () => const FCircularProgress(),
                      error: (e, _) => Text('$e'),
                    ),
                Field(
                  'Подробное описание',
                  description,
                  minLength: 20,
                  lines: 5,
                  hint: 'Что нужно сделать, для кого и что уже есть?',
                ),
                Field(
                  'Ожидаемый результат',
                  result,
                  minLength: 5,
                  lines: 3,
                  hint: 'Какие файлы, ссылки или материалы вы хотите получить?',
                ),
                const SizedBox(height: 8),
                const Tag('02 · УСЛОВИЯ'),
                const SizedBox(height: 24),
                Field(
                  'Срок выполнения в днях',
                  days,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 1 || n > 365
                        ? 'Укажите от 1 до 365 дней'
                        : null;
                  },
                ),
                ChoiceField(
                  'Количество согласованных правок',
                  value: revisions,
                  options: const {
                    '0': 'Без правок',
                    '1': '1 правка',
                    '2': '2 правки',
                    '3': '3 правки',
                  },
                  onChange: (v) => setState(() => revisions = v),
                ),
                Field('Город', city, required: false),
                ChoiceField(
                  'Благодарность за работу',
                  value: payment,
                  options: const {
                    'free': 'Бесплатно · за опыт',
                    'tips': 'Добровольные чаевые',
                  },
                  onChange: (v) => setState(() => payment = v),
                ),
                const Text(
                  'Платежей внутри FirstCase нет. Чаевые добровольны и не влияют на завершение заказа или приватность.',
                  style: TextStyle(color: muted, height: 1.6, fontSize: 12),
                ),
                const SizedBox(height: 24),
                UploadField(onChange: (v) => attachments = v),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ActionButton(
                      widget.id == null
                          ? 'Опубликовать задачу'
                          : 'Сохранить изменения',
                      icon: FLucideIcons.arrowUpRight,
                      action: () async {
                        if (!form.currentState!.validate()) return;
                        if (category.isEmpty) {
                          throw Exception('Выберите направление');
                        }
                        final data = values()..remove('days');
                        data['deadline'] = DateTime.now()
                            .add(Duration(days: int.parse(days.text)))
                            .toUtc()
                            .toIso8601String();
                        final saved = await mutate(
                          ref,
                          widget.id == null ? '/tasks' : '/tasks/${widget.id}',
                          method: widget.id == null ? 'POST' : 'PATCH',
                          data: data,
                        );
                        await ref.read(taskRepositoryProvider).clearDraft();
                        if (context.mounted) {
                          context.go('/tasks/${saved['id']}');
                        }
                      },
                    ),
                    if (widget.id == null)
                      ActionButton(
                        'Сохранить черновик',
                        secondary: true,
                        success: 'Черновик сохранён на этом устройстве',
                        action: () => ref
                            .read(taskRepositoryProvider)
                            .saveDraft(values()),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
