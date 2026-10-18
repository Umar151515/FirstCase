import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';

IconData categoryIcon(String name) {
  final s = name.toLowerCase();
  if (s.contains('дизайн')) return FLucideIcons.penTool;
  if (s.contains('видео')) return FLucideIcons.clapperboard;
  if (s.contains('текст')) return FLucideIcons.notebookPen;
  if (s.contains('маркет')) return FLucideIcons.megaphone;
  if (s.contains('иллюстр')) return FLucideIcons.palette;
  return FLucideIcons.codeXml;
}

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
        Row(
          children: [
            Tag(task.category, icon: categoryIcon(task.category)),
            const Spacer(),
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
        Text(
          task.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: muted, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(FLucideIcons.calendarDays, size: 13, color: muted),
            const SizedBox(width: 5),
            Text(
              'до ${dateLabel(task.deadline)}',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(width: 16),
            const Icon(FLucideIcons.messagesSquare, size: 13, color: muted),
            const SizedBox(width: 5),
            Text(
              '${task.responses} откликов',
              style: const TextStyle(fontSize: 11, color: muted),
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
            const SizedBox(width: 8),
            Text(
              task.tips ? 'За чаевые ♡' : 'За опыт ✦',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accent,
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
