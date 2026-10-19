import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../../shared/widgets/media.dart';
import 'ai_policy.dart';

IconData categoryIcon(String slug) => switch (slug) {
  'design' => FLucideIcons.penTool,
  'video' => FLucideIcons.clapperboard,
  'text' => FLucideIcons.notebookPen,
  'illustration' => FLucideIcons.palette,
  'data' => FLucideIcons.chartNoAxesCombined,
  _ => FLucideIcons.codeXml,
};

class TaskCard extends StatelessWidget {
  const TaskCard(this.task, {super.key});
  final Task task;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth > 740;
      final compact = constraints.maxWidth < 400;
      return Material(
        color: paper(context),
        child: InkWell(
          onTap: () => context.go('/tasks/${task.id}'),
          hoverColor: context.theme.colors.primary.withValues(alpha: .035),
          child: Padding(
            padding: EdgeInsets.all(compact ? 18 : 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                categoryIcon(task.categorySlug),
                                size: 14,
                                color: quiet(context),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  categoryLabel(
                                    context,
                                    task.categorySlug,
                                    fallback: task.category,
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: quiet(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (task.status != 'published')
                            Tag(statusLabel(context, task.status)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 17 : 18,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.3,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: quiet(context),
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Meta(
                            FLucideIcons.calendarDays,
                            context.l10n.dueBy(
                              dateLabel(context, task.deadline),
                            ),
                          ),
                          _Meta(
                            FLucideIcons.messagesSquare,
                            context.l10n.applicationCount(task.responses),
                          ),
                          Text(
                            aiPolicyLabel(context, task.aiPolicy),
                            style: TextStyle(
                              fontSize: 11,
                              color: quiet(context),
                            ),
                          ),
                        ],
                      ),
                      if (!wide) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(child: _Customer(task.customer)),
                            const SizedBox(width: 12),
                            Flexible(child: _Payment(task)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (wide) ...[
                  const SizedBox(width: 28),
                  SizedBox(
                    width: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Payment(task),
                        const SizedBox(height: 16),
                        if (task.coverId != null) ...[
                          ProtectedImage(
                            attachmentId: task.coverId!,
                            width: 112,
                            height: 62,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          const SizedBox(height: 14),
                        ],
                        _Customer(task.customer, alignEnd: true),
                      ],
                    ),
                  ),
                ] else if (task.coverId != null && !compact) ...[
                  const SizedBox(width: 18),
                  ProtectedImage(
                    attachmentId: task.coverId!,
                    width: 76,
                    height: 76,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Customer extends StatelessWidget {
  const _Customer(this.person, {this.alignEnd = false});
  final Person person;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: alignEnd
        ? MainAxisAlignment.end
        : MainAxisAlignment.start,
    children: [
      PersonAvatar(person, size: 24),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          person.name,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: quiet(context)),
        ),
      ),
    ],
  );
}

class _Payment extends StatelessWidget {
  const _Payment(this.task);
  final Task task;

  @override
  Widget build(BuildContext context) => Text(
    task.tips ? context.l10n.paymentTips : context.l10n.paymentExperience,
    style: TextStyle(
      fontSize: 12,
      color: context.theme.colors.primary,
      fontWeight: FontWeight.w500,
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: quiet(context)),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          style: TextStyle(fontSize: 11, color: quiet(context)),
        ),
      ),
    ],
  );
}

class TaskGrid extends StatelessWidget {
  const TaskGrid(this.tasks, {super.key});
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: paper(context),
      border: Border.all(color: edge(context)),
      borderRadius: BorderRadius.circular(6),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (final (index, task) in tasks.indexed) ...[
          if (index > 0) Divider(height: 1, thickness: 1, color: edge(context)),
          TaskCard(task),
        ],
      ],
    ),
  );
}
