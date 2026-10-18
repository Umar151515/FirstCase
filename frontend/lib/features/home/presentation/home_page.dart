import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../tasks/presentation/task_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void findTasks() =>
      context.go('/tasks?q=${Uri.encodeQueryComponent(search.text)}');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final dark = ref.watch(themeProvider);
    return PageBody(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: mobile ? 16 : 32),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.homeKicker,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l.homeTitle,
                      style: TextStyle(
                        fontSize: mobile ? 34 : 48,
                        height: 1.12,
                        letterSpacing: -1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                        l.homeIntro,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.65,
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: FTextField(
                            control: .managed(controller: search),
                            hint: l.homeSearchHint,
                            onSubmit: (_) => findTasks(),
                            prefixBuilder: (_, _, _) => const Padding(
                              padding: EdgeInsets.only(left: 12, right: 8),
                              child: Icon(FLucideIcons.search, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FButton(
                      mainAxisSize: MainAxisSize.min,
                          onPress: findTasks,
                          child: mobile
                              ? const Icon(FLucideIcons.arrowRight, size: 18)
                              : Flexible(child: Text(l.homeSearch)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FButton(
                      variant: .ghost,
                      mainAxisSize: MainAxisSize.min,
                      onPress: () => context.go('/tasks/new'),
                      prefix: const Icon(FLucideIcons.plus, size: 16),
                      child: Flexible(child: Text(l.homeCreate)),
                    ),
                  ],
                ),
              ),
              if (!mobile) ...[
                const SizedBox(width: 64),
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Brand(mark: true, width: 210),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l.brandDescription,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Divider(color: edge(context)),
        const SizedBox(height: 24),
        _Section(l.homeCategories),
        ref
            .watch(categoriesProvider)
            .when(
              data: (categories) => LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth > 950
                      ? 6
                      : constraints.maxWidth > 550
                      ? 3
                      : 2;
                  final width = (constraints.maxWidth - (cols - 1) * 10) / cols;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: categories
                        .map(
                          (category) => SizedBox(
                            width: width,
                            child: Panel(
                              padding: 16,
                              onTap: () => context.go(
                                '/tasks?category_id=${category['id']}',
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    categoryIcon(category['slug'] as String),
                                    size: 18,
                                    color: dark
                                        ? const Color(0xFF9ABDEB)
                                        : accent,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      categoryLabel(
                                        context,
                                        category['slug'] as String,
                                        fallback: category['name'] as String,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
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
              loading: () => const LoadingView(),
              error: (error, _) =>
                  StateMessage(l.homeCategoriesUnavailable, subtitle: '$error'),
            ),
        const SizedBox(height: 42),
        _Section(
          l.homeRecent,
          action: FButton(
            variant: .ghost,
            mainAxisSize: MainAxisSize.min,
            onPress: () => context.go('/tasks'),
            suffix: const Icon(FLucideIcons.arrowRight, size: 16),
            child: Flexible(child: Text(l.homeSeeAll)),
          ),
        ),
        ResourceView(
          '/tasks?status=published&limit=6&sort=newest',
          builder: (data) {
            final tasks = items(data).map(Task.new).toList();
            return tasks.isEmpty ? StateMessage(l.homeEmpty) : TaskGrid(tasks);
          },
        ),
        const SizedBox(height: 42),
        _Section(l.homeApproach),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 24,
            runSpacing: 20,
            children: [l.homeStepFind, l.homeStepWork, l.homeStepKeep].indexed
                .map(
                  (entry) => SizedBox(
                    width: constraints.maxWidth > 700
                        ? (constraints.maxWidth - 48) / 3
                        : constraints.maxWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '0${entry.$1 + 1}',
                          style: TextStyle(
                            fontSize: 22,
                            color: context.theme.colors.mutedForeground,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              entry.$2,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF14243B) : const Color(0xFFF0F4FA),
            border: Border(
              left: BorderSide(
                color: dark ? const Color(0xFF9ABDEB) : accent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.homeAiTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l.homeAiBody,
                style: TextStyle(
                  height: 1.65,
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 42),
        _Section(l.homePeople),
        ResourceView(
          '/users?limit=4',
          builder: (data) => LayoutBuilder(
            builder: (context, constraints) {
              final people = items(data);
              if (people.isEmpty) return StateMessage(l.homePeopleEmpty);
              final cols = constraints.maxWidth > 950
                  ? 4
                  : constraints.maxWidth > 550
                  ? 2
                  : 1;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: people.map((json) {
                  final person = Person(json);
                  return SizedBox(
                    width: (constraints.maxWidth - (cols - 1) * 16) / cols,
                    child: Panel(
                      padding: 20,
                      onTap: () => context.go('/users/${person.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PersonAvatar(person, size: 44),
                              const Spacer(),
                              if (person.rating > 0) ...[
                                const Icon(
                                  FLucideIcons.star,
                                  size: 13,
                                  color: muted,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  person.rating.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ] else
                                Text(
                                  l.homeNewcomer,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            person.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            person.specialty.isEmpty
                                ? l.homeOpenToWork
                                : person.specialty,
                            style: const TextStyle(
                              fontSize: 12,
                              color: muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: person.skills
                                .take(2)
                                .map((s) => Tag(s, color: muted))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 40),
        Divider(color: edge(context)),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 24,
          runSpacing: 12,
          children: [
            const Brand(width: 112),
            Text(
              l.homeFooter,
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heading = Text(
          title,
          style: const TextStyle(
            fontSize: 23,
            letterSpacing: -.4,
            fontWeight: FontWeight.w600,
          ),
        );
        return constraints.maxWidth < 550
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading,
                  if (action != null) ...[const SizedBox(height: 8), action!],
                ],
              )
            : Row(
                children: [
                  Expanded(child: heading),
                  ?action,
                ],
              );
      },
    ),
  );
}
