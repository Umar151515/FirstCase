import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import 'task_card.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({this.initialQuery = '', this.category, super.key});
  final String initialQuery;
  final String? category;
  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  late final search = TextEditingController(text: widget.initialQuery);
  final city = TextEditingController();
  late String category = widget.category ?? '';
  late String query = widget.initialQuery;
  String status = 'published';
  String sort = 'newest';
  String period = '';
  int offset = 0;
  @override
  void dispose() {
    search.dispose();
    city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = Uri(
      path: '/tasks',
      queryParameters: {
        'q': query,
        if (category.isNotEmpty) 'category_id': category,
        if (status.isNotEmpty) 'status': status,
        if (city.text.isNotEmpty) 'city': city.text.trim(),
        if (period.isNotEmpty)
          'created_after': DateTime.now()
              .subtract(Duration(days: int.parse(period)))
              .toUtc()
              .toIso8601String(),
        'sort': sort,
        'offset': '$offset',
        'limit': '12',
      },
    ).toString();
    return PageBody(
      children: [
        PageTitle(
          'Найди свой первый заказ',
          subtitle: 'Небольшие задачи, с которых начинаются большие истории.',
          action: MediaQuery.sizeOf(context).width > 700
              ? FButton(
                  onPress: () => context.go('/tasks/new'),
                  child: const Text('Создать заказ'),
                )
              : null,
        ),
        Row(
          children: [
            Expanded(
              child: FTextField(
                control: .managed(controller: search),
                hint: 'Название, навык или ключевое слово',
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
              prefix: const Icon(FLucideIcons.search, size: 16),
              child: const Text('Найти'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        ref
            .watch(categoriesProvider)
            .when(
              data: (categories) => ChoiceField(
                'Направление',
                value: category,
                options: {
                  '': 'Все направления',
                  for (final c in categories) '${c['id']}': c['name'] as String,
                },
                onChange: (v) => setState(() {
                  category = v;
                  offset = 0;
                }),
              ),
              loading: () => const SizedBox(height: 35),
              error: (_, _) => const SizedBox.shrink(),
            ),
        Wrap(
          spacing: 28,
          children: [
            ChoiceField(
              'Дата публикации',
              value: period,
              options: const {
                '': 'За всё время',
                '1': 'Сегодня',
                '7': 'За неделю',
                '30': 'За месяц',
              },
              onChange: (v) => setState(() {
                period = v;
                offset = 0;
              }),
            ),
            ChoiceField(
              'Статус',
              value: status,
              options: const {
                'published': 'Открытые',
                'assigned': 'В работе',
                'completed': 'Завершённые',
                '': 'Все',
              },
              onChange: (v) => setState(() {
                status = v;
                offset = 0;
              }),
            ),
            ChoiceField(
              'Сортировка',
              value: sort,
              options: const {
                'newest': 'Сначала новые',
                'oldest': 'Сначала старые',
                'deadline': 'Ближайший срок',
              },
              onChange: (v) => setState(() {
                sort = v;
                offset = 0;
              }),
            ),
          ],
        ),
        SizedBox(
          width: 300,
          child: FTextField(
            control: .managed(controller: city),
            hint: 'Город · например, Бишкек',
            onSubmit: (_) => setState(() => offset = 0),
          ),
        ),
        const SizedBox(height: 28),
        ResourceView(
          path,
          builder: (data) {
            final tasks = items(data).map(Task.new).toList();
            final total = data['total'] as int;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Найдено задач: $total',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                if (tasks.isEmpty)
                  const StateMessage(
                    'Пока ничего не нашлось',
                    subtitle:
                        'Попробуйте другое слово или выберите все направления.',
                  )
                else
                  TaskGrid(tasks),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FButton(
                      variant: .outline,
                      onPress: offset == 0
                          ? null
                          : () => setState(() => offset -= 12),
                      child: const Text('Назад'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        '${offset ~/ 12 + 1} / ${(total / 12).ceil().clamp(1, 9999)}',
                      ),
                    ),
                    FButton(
                      variant: .outline,
                      onPress: offset + 12 >= total
                          ? null
                          : () => setState(() => offset += 12),
                      child: const Text('Дальше'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
