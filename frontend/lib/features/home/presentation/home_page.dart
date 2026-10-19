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
      context.go('/tasks?q=${Uri.encodeQueryComponent(search.text.trim())}');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return PageBody(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Padding(
            padding: EdgeInsets.only(
              top: mobile ? 0 : 24,
              bottom: mobile ? 28 : 36,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.homeKicker,
                        style: TextStyle(fontSize: 12, color: quiet(context)),
                      ),
                      const SizedBox(height: 22),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '${l.homeTitle}\n'),
                            TextSpan(
                              text: l.homeTitleAccent,
                              style: TextStyle(
                                color: context.theme.colors.primary,
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: mobile ? 38 : 56,
                          height: 1.08,
                          letterSpacing: mobile ? -1.4 : -2.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 22),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 530),
                        child: Text(
                          l.homeIntro,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: quiet(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 660),
                        child: Row(
                          children: [
                            Expanded(
                              child: FTextField(
                                control: .managed(controller: search),
                                hint: l.homeSearchHint,
                                onSubmit: (_) => findTasks(),
                                prefixBuilder: (_, _, _) => Padding(
                                  padding: const EdgeInsets.only(
                                    left: 14,
                                    right: 10,
                                  ),
                                  child: Icon(
                                    FLucideIcons.search,
                                    size: 18,
                                    color: quiet(context),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FButton(
                              mainAxisSize: MainAxisSize.min,
                              semanticsLabel: l.homeSearch,
                              onPress: findTasks,
                              child: mobile
                                  ? const Icon(
                                      FLucideIcons.arrowRight,
                                      size: 18,
                                    )
                                  : Flexible(child: Text(l.homeSearch)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (constraints.maxWidth > 960) ...[
                  const SizedBox(width: 80),
                  const SizedBox(width: 300, child: _GettingStarted()),
                ],
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: mobile ? 12 : 18),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: edge(context)),
              bottom: BorderSide(color: edge(context)),
            ),
          ),
          child: ref
              .watch(categoriesProvider)
              .when(
                data: (categories) => Wrap(
                  spacing: mobile ? 16 : 28,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        l.homeCategories,
                        style: TextStyle(fontSize: 12, color: quiet(context)),
                      ),
                    ),
                    for (final category in categories) _CategoryLink(category),
                  ],
                ),
                loading: () => const SizedBox(height: 32),
                error: (_, _) => Text(
                  l.homeCategoriesUnavailable,
                  style: TextStyle(color: quiet(context)),
                ),
              ),
        ),
        const SizedBox(height: 34),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 960;
            final tasks = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Section(
                  l.homeRecent,
                  action: FButton(
                    variant: .ghost,
                    size: .sm,
                    mainAxisSize: MainAxisSize.min,
                    onPress: () => context.go('/tasks'),
                    suffix: const Icon(FLucideIcons.arrowRight, size: 15),
                    child: Flexible(child: Text(mobile ? l.all : l.homeSeeAll)),
                  ),
                ),
                ResourceView(
                  '/tasks?status=published&limit=6&sort=newest',
                  builder: (data) {
                    final tasks = items(data).map(Task.new).toList();
                    return tasks.isEmpty
                        ? StateMessage(l.homeEmpty)
                        : TaskGrid(tasks);
                  },
                ),
              ],
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: tasks),
                      const SizedBox(width: 40),
                      const SizedBox(width: 300, child: _Community()),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tasks,
                      const SizedBox(height: 40),
                      const _GettingStarted(),
                      const SizedBox(height: 40),
                      const _Community(),
                    ],
                  );
          },
        ),
        const SizedBox(height: 48),
        Divider(color: edge(context)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 12,
            children: [
              const Brand(width: 110),
              Text(
                l.homeFooter,
                style: TextStyle(fontSize: 12, color: quiet(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryLink extends StatelessWidget {
  const _CategoryLink(this.category);
  final Json category;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(3),
      onTap: () => context.go('/tasks?category_id=${category['id']}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              categoryIcon(category['slug'] as String),
              size: 15,
              color: quiet(context),
            ),
            const SizedBox(width: 8),
            Flexible(
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
  );
}

class _GettingStarted extends StatelessWidget {
  const _GettingStarted();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.only(left: 26, top: 4, bottom: 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: edge(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.homeApproach,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          for (final entry in [
            l.homeStepFind,
            l.homeStepWork,
            l.homeStepKeep,
          ].indexed)
            Padding(
              padding: EdgeInsets.only(bottom: entry.$1 == 2 ? 0 : 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '0${entry.$1 + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.7,
                      color: context.theme.colors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      entry.$2,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: quiet(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Community extends StatelessWidget {
  const _Community();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Panel(
          padding: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                FLucideIcons.notebookPen,
                size: 22,
                color: context.theme.colors.primary,
              ),
              const SizedBox(height: 18),
              Text(
                l.homeForCustomers,
                style: const TextStyle(
                  fontSize: 21,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l.homeForCustomersBody,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  color: quiet(context),
                ),
              ),
              const SizedBox(height: 20),
              FButton(
                variant: .outline,
                size: .sm,
                onPress: () => context.go('/tasks/new'),
                suffix: const Icon(FLucideIcons.arrowRight, size: 15),
                child: Flexible(child: Text(l.homeCreate)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _Section(l.homePeople),
        ResourceView(
          '/users?limit=4',
          builder: (data) {
            final people = items(data).map(Person.new).toList();
            return people.isEmpty
                ? Text(
                    l.homePeopleEmpty,
                    style: TextStyle(color: quiet(context), fontSize: 13),
                  )
                : Column(
                    children: [for (final person in people) _PersonRow(person)],
                  );
          },
        ),
        const SizedBox(height: 28),
        Divider(color: edge(context)),
        const SizedBox(height: 20),
        Text(
          l.homeAiTitle,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          l.homeAiBody,
          style: TextStyle(fontSize: 12, height: 1.8, color: quiet(context)),
        ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow(this.person);
  final Person person;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => context.go('/users/${person.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            PersonAvatar(person, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    person.specialty.isEmpty
                        ? context.l10n.homeOpenToWork
                        : person.specialty,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: quiet(context),
                    ),
                  ),
                ],
              ),
            ),
            if (person.rating > 0) ...[
              const SizedBox(width: 8),
              Icon(FLucideIcons.star, size: 12, color: quiet(context)),
              const SizedBox(width: 4),
              Text(
                person.rating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, {this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heading = Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            letterSpacing: -.6,
            fontWeight: FontWeight.w500,
          ),
        );
        return constraints.maxWidth < 280 && action != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, const SizedBox(height: 8), action!],
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
