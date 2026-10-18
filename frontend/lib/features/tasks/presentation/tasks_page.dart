import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import 'task_card.dart';
import 'ai_policy.dart';

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
  String aiPolicy = '';
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
        if (aiPolicy.isNotEmpty) 'ai_policy': aiPolicy,
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
          context.l10n.adminTasks,
          subtitle: context.l10n.tasksSubtitle,
          action: MediaQuery.sizeOf(context).width > 700
              ? FButton(
                  onPress: () => context.go('/tasks/new'),
                  child: Text(context.l10n.createOrder),
                )
              : null,
        ),
        Row(
          children: [
            Expanded(
              child: FTextField(
                control: .managed(controller: search),
                hint: context.l10n.taskSearchHint,
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
              child: Text(context.l10n.search),
            ),
          ],
        ),
        const SizedBox(height: 22),
        ref
            .watch(categoriesProvider)
            .when(
              data: (categories) => ChoiceField(
                context.l10n.category,
                value: category,
                options: {
                  '': context.l10n.allCategories,
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
              context.l10n.aiPolicyLabel,
              value: aiPolicy,
              options: {
                '': context.l10n.aiPolicyAny,
                ...aiPolicyOptions(context),
              },
              onChange: (value) => setState(() {
                aiPolicy = value;
                offset = 0;
              }),
            ),
            ChoiceField(
              context.l10n.publicationDate,
              value: period,
              options: {
                '': context.l10n.allTime,
                '1': context.l10n.today,
                '7': context.l10n.lastWeek,
                '30': context.l10n.lastMonth,
              },
              onChange: (v) => setState(() {
                period = v;
                offset = 0;
              }),
            ),
            ChoiceField(
              context.l10n.status,
              value: status,
              options: {
                'published': context.l10n.filterOpen,
                'assigned': context.l10n.statusInProgress,
                'completed': context.l10n.filterCompleted,
                '': context.l10n.all,
              },
              onChange: (v) => setState(() {
                status = v;
                offset = 0;
              }),
            ),
            ChoiceField(
              context.l10n.sort,
              value: sort,
              options: {
                'newest': context.l10n.newestFirst,
                'oldest': context.l10n.oldestFirst,
                'deadline': context.l10n.deadlineSoonest,
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
            hint: context.l10n.citySearchHint,
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
                  context.l10n.tasksFound(total),
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                if (tasks.isEmpty)
                  StateMessage(
                    context.l10n.tasksEmpty,
                    subtitle: context.l10n.tasksEmptyHint,
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
                      child: Text(context.l10n.back),
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
                      child: Text(context.l10n.next),
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
