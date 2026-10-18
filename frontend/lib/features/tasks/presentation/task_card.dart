import '../../../core/l10n/l10n.dart';

import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

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
  Widget build(BuildContext context) => Panel(
    padding: 22,
    onTap: () => context.go('/tasks/${task.id}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (task.coverId != null) ...[
          ProtectedImage(
            attachmentId: task.coverId!,
            width: double.infinity,
            height: 160,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 18),
        ],
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Tag(
                  categoryLabel(
                    context,
                    task.categorySlug,
                    fallback: task.category,
                  ),
                  icon: categoryIcon(task.categorySlug),
                ),
              ),
            ),
            if (task.status == 'published')
              const Icon(FLucideIcons.arrowUpRight, size: 17, color: muted),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            height: 1.35,
            fontWeight: FontWeight.w700,
            letterSpacing: -.3,
          ),
        ),
        const SizedBox(height: 12),
        Tag(aiPolicyLabel(context, task.aiPolicy), color: muted),
        const SizedBox(height: 12),
        Text(
          task.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: muted, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FLucideIcons.calendarDays, size: 13, color: muted),
                const SizedBox(width: 5),
                Text(
                  context.l10n.dueBy(dateLabel(context, task.deadline)),
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FLucideIcons.messagesSquare, size: 13, color: muted),
                const SizedBox(width: 5),
                Text(
                  context.l10n.applicationCount(task.responses),
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
            Text(
              task.tips
                  ? context.l10n.paymentTips
                  : context.l10n.paymentExperience,
              style: TextStyle(
                fontSize: 11,
                color: context.theme.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(height: 1, color: edge(context)),
        const SizedBox(height: 16),
        Row(
          children: [
            PersonAvatar(task.customer, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.customer.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class TaskGrid extends StatelessWidget {
  const TaskGrid(this.tasks, {super.key});
  final List<Task> tasks;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth > 1050
          ? 3
          : constraints.maxWidth > 650
          ? 2
          : 1;
      final width = (constraints.maxWidth - 18 * (columns - 1)) / columns;
      return Wrap(
        spacing: 18,
        runSpacing: 18,
        children: tasks
            .map((task) => SizedBox(width: width, child: TaskCard(task)))
            .toList(),
      );
    },
  );
}
