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
  DateTime? createdAfter;
  String aiPolicy = '';
  String cityQuery = '';
  bool filtersOpen = false;
  int offset = 0;

  @override
  void didUpdateWidget(covariant TasksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery ||
        oldWidget.category != widget.category) {
      search.text = query = widget.initialQuery;
      category = widget.category ?? '';
      offset = 0;
    }
  }

  @override
  void dispose() {
    search.dispose();
    city.dispose();
    super.dispose();
  }

  void findTasks() => setState(() {
    query = search.text.trim();
    cityQuery = city.text.trim();
    offset = 0;
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mobile = MediaQuery.sizeOf(context).width < 650;
    final filterCount = [
      aiPolicy.isNotEmpty,
      period.isNotEmpty,
      status != 'published',
      cityQuery.isNotEmpty,
    ].where((active) => active).length;
    final path = Uri(
      path: '/tasks',
      queryParameters: {
        'q': query,
        if (category.isNotEmpty) 'category_id': category,
        if (status.isNotEmpty) 'status': status,
        if (aiPolicy.isNotEmpty) 'ai_policy': aiPolicy,
        if (cityQuery.isNotEmpty) 'city': cityQuery,
        if (period.isNotEmpty)
          'created_after': createdAfter!.toUtc().toIso8601String(),
        'sort': sort,
        'offset': '$offset',
        'limit': '12',
      },
    ).toString();
    return PageBody(
      children: [
        PageTitle(
          l.adminTasks,
          subtitle: l.tasksSubtitle,
          action: !mobile
              ? FButton(
                  mainAxisSize: MainAxisSize.min,
                  onPress: () => context.go('/tasks/new'),
                  prefix: const Icon(FLucideIcons.plus, size: 16),
                  child: Flexible(child: Text(l.navCreate)),
                )
              : null,
        ),
        Row(
          children: [
            Expanded(
              child: FTextField(
                control: .managed(controller: search),
                hint: l.taskSearchHint,
                onSubmit: (_) => findTasks(),
                prefixBuilder: (_, _, _) => Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(
                    FLucideIcons.search,
                    size: 17,
                    color: quiet(context),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FButton(
              mainAxisSize: MainAxisSize.min,
              semanticsLabel: l.search,
              onPress: findTasks,
              child: mobile
                  ? const Icon(FLucideIcons.arrowRight, size: 18)
                  : Text(l.search),
            ),
            const SizedBox(width: 8),
            FButton(
              mainAxisSize: MainAxisSize.min,
              variant: filtersOpen || filterCount > 0 ? .secondary : .outline,
              semanticsLabel:
                  '${l.filter}${filterCount > 0 ? ' · $filterCount' : ''}',
              onPress: () => setState(() => filtersOpen = !filtersOpen),
              prefix: const Icon(FLucideIcons.slidersHorizontal, size: 16),
              child: mobile
                  ? (filterCount > 0
                        ? Text('$filterCount')
                        : const SizedBox.shrink())
                  : Text(
                      '${l.filter}${filterCount > 0 ? ' · $filterCount' : ''}',
                    ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ref
            .watch(categoriesProvider)
            .when(
              data: (categories) => FilterTabs(
                value: category,
                options: {
                  '': l.allCategories,
                  for (final c in categories)
                    '${c['id']}': categoryLabel(
                      context,
                      c['slug'] as String,
                      fallback: c['name'] as String,
                    ),
                },
                onChange: (value) => setState(() {
                  category = value;
                  offset = 0;
                }),
              ),
              loading: () => const SizedBox(height: 46),
              error: (_, _) => const SizedBox.shrink(),
            ),
        Divider(height: 1, color: edge(context)),
        if (filtersOpen) ...[
          const SizedBox(height: 22),
          Panel(
            padding: mobile ? 18 : 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChoiceField(
                  l.aiPolicyLabel,
                  value: aiPolicy,
                  options: {'': l.aiPolicyAny, ...aiPolicyOptions(context)},
                  onChange: (value) => setState(() {
                    aiPolicy = value;
                    offset = 0;
                  }),
                ),
                Wrap(
                  spacing: 32,
                  children: [
                    ChoiceField(
                      l.publicationDate,
                      value: period,
                      options: {
                        '': l.allTime,
                        '1': l.today,
                        '7': l.lastWeek,
                        '30': l.lastMonth,
                      },
                      onChange: (value) => setState(() {
                        period = value;
                        createdAfter = value.isEmpty
                            ? null
                            : DateTime.now().subtract(
                                Duration(days: int.parse(value)),
                              );
                        offset = 0;
                      }),
                    ),
                    ChoiceField(
                      l.status,
                      value: status,
                      options: {
                        'published': l.filterOpen,
                        'assigned': l.statusInProgress,
                        'completed': l.filterCompleted,
                        '': l.all,
                      },
                      onChange: (value) => setState(() {
                        status = value;
                        offset = 0;
                      }),
                    ),
                  ],
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: FTextField(
                    control: .managed(controller: city),
                    label: Text(l.city),
                    hint: l.citySearchHint,
                    onSubmit: (_) => findTasks(),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    FButton(
                      mainAxisSize: MainAxisSize.min,
                      size: .sm,
                      onPress: findTasks,
                      child: Flexible(child: Text(l.filtersApply)),
                    ),
                    FButton(
                      mainAxisSize: MainAxisSize.min,
                      size: .sm,
                      variant: .ghost,
                      onPress: () => setState(() {
                        aiPolicy = period = cityQuery = '';
                        createdAfter = null;
                        city.clear();
                        status = 'published';
                        offset = 0;
                      }),
                      child: Flexible(child: Text(l.filtersReset)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        ResourceView(
          path,
          builder: (data) {
            final tasks = items(data).map(Task.new).toList();
            final total = data['total'] as int;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        l.tasksFound(total),
                        style: TextStyle(color: quiet(context), fontSize: 12),
                      ),
                      Semantics(
                        label: l.sort,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: sort,
                            isDense: true,
                            dropdownColor: paper(context),
                            borderRadius: BorderRadius.circular(6),
                            style: TextStyle(fontSize: 12, color: ink(context)),
                            items: [
                              for (final entry in {
                                'newest': l.newestFirst,
                                'oldest': l.oldestFirst,
                                'deadline': l.deadlineSoonest,
                              }.entries)
                                DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  sort = value;
                                  offset = 0;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (tasks.isEmpty)
                  StateMessage(l.tasksEmpty, subtitle: l.tasksEmptyHint)
                else
                  TaskGrid(tasks),
                const SizedBox(height: 28),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Row(
                      children: [
                        Expanded(
                          child: FButton(
                            variant: .outline,
                            size: .sm,
                            onPress: offset == 0
                                ? null
                                : () => setState(() => offset -= 12),
                            child: Flexible(child: Text(l.back)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Text(
                            '${offset ~/ 12 + 1} / ${(total / 12).ceil().clamp(1, 9999)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: quiet(context),
                            ),
                          ),
                        ),
                        Expanded(
                          child: FButton(
                            variant: .outline,
                            size: .sm,
                            onPress: offset + 12 >= total
                                ? null
                                : () => setState(() => offset += 12),
                            child: Flexible(child: Text(l.next)),
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
