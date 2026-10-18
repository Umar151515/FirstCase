import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../../shared/widgets/media.dart';
import 'ai_policy.dart';

class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage(this.id, {super.key});
  final int id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    width: 940,
    children: [
      FButton(
        variant: .ghost,
        mainAxisSize: MainAxisSize.min,
        prefix: const Icon(FLucideIcons.arrowLeft, size: 15),
        onPress: () => context.go('/tasks'),
        child: Text(context.l10n.homeSeeAll),
      ),
      const SizedBox(height: 20),
      ResourceView(
        '/tasks/$id',
        builder: (data) {
          final task = Task(Map<String, dynamic>.from(data as Map));
          final user = ref.watch(sessionProvider).value;
          final owner = user?.id == task.customerId;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  Tag(task.category),
                  Tag(aiPolicyLabel(context, task.aiPolicy), color: muted),
                  Tag(
                    statusLabel(context, task.status),
                    color: const Color(0xFF5E8B42),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PageTitle(
                task.title,
                subtitle: context.l10n.publishedAt(
                  dateLabel(context, task.json['created_at']),
                  task.json['city'] as String? ?? context.l10n.remote,
                ),
              ),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task.coverId != null) ...[
                      ProtectedImage(
                        attachmentId: task.coverId!,
                        height: 300,
                        width: double.infinity,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 26),
                    ],
                    Row(
                      children: [
                        PersonAvatar(task.customer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.customer.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                context.l10n.roleCustomer,
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        FButton(
                          variant: .outline,
                          mainAxisSize: MainAxisSize.min,
                          onPress: () =>
                              context.go('/users/${task.customerId}'),
                          child: Text(context.l10n.navProfile),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      context.l10n.taskDescription,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      task.description,
                      style: const TextStyle(height: 1.8),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      context.l10n.taskExpectedResult,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      task.result,
                      style: const TextStyle(height: 1.8),
                    ),
                    const SizedBox(height: 26),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        Tag(
                          context.l10n.deadlineLabel(
                            dateLabel(context, task.deadline),
                          ),
                          icon: FLucideIcons.calendarDays,
                        ),
                        Tag(
                          context.l10n.revisionCount(task.revisions),
                          icon: FLucideIcons.refreshCw,
                        ),
                        Tag(
                          task.tips
                              ? context.l10n.voluntaryTips
                              : context.l10n.freeForExperience,
                          icon: FLucideIcons.heart,
                        ),
                      ],
                    ),
                    if ((task.json['attachment_ids'] as List? ?? [])
                        .isNotEmpty) ...[
                      const SizedBox(height: 22),
                      AttachmentGallery(
                        attachmentIds: List<int>.from(
                          task.json['attachment_ids'] as List,
                        ).where((id) => id != task.coverId).toList(),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (task.status == 'published' && !owner)
                          FButton(
                            onPress: () => user == null
                                ? context.go('/login')
                                : modal(
                                    context,
                                    ApplicationForm(
                                      id,
                                      aiPolicy: task.aiPolicy,
                                    ),
                                  ),
                            prefix: const Icon(FLucideIcons.send, size: 16),
                            child: Text(context.l10n.applyForTask),
                          ),
                        if (task.status == 'published' && owner) ...[
                          FButton(
                            onPress: () => context.go('/tasks/$id/edit'),
                            child: Text(context.l10n.edit),
                          ),
                          ActionButton(
                            context.l10n.cancelTask,
                            secondary: true,
                            action: () async {
                              if (await confirm(
                                context,
                                context.l10n.cancelTaskTitle,
                                context.l10n.cancelTaskHint,
                              )) {
                                await mutate(ref, '/tasks/$id/cancel');
                              }
                            },
                          ),
                        ],
                        if (user != null && !owner)
                          FButton(
                            variant: .ghost,
                            onPress: () =>
                                modal(context, ReportForm('task', id)),
                            child: Text(context.l10n.report),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              if (user != null) ...[
                Text(
                  owner
                      ? context.l10n.performerApplications
                      : context.l10n.myApplication,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                ResourceView(
                  '/tasks/$id/applications',
                  builder: (data) {
                    final applications = items(data);
                    if (applications.isEmpty) {
                      return StateMessage(
                        owner
                            ? context.l10n.taskApplicationsEmpty
                            : context.l10n.taskNotApplied,
                        subtitle: owner
                            ? context.l10n.applicationsComingHint
                            : context.l10n.joinStoryHint,
                      );
                    }
                    return Column(
                      children: applications.map((application) {
                        final person = Person(
                          Map<String, dynamic>.from(
                            application['performer'] as Map,
                          ),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Panel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    PersonAvatar(person),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        person.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Tag(
                                      statusLabel(
                                        context,
                                        application['status'] as String,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  application['message'] as String,
                                  style: const TextStyle(height: 1.6),
                                ),
                                if ('${application['comment'] ?? ''}'
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      application['comment'] as String,
                                      style: const TextStyle(color: muted),
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                Text(
                                  context.l10n.proposedDeadlineLabel(
                                    dateLabel(
                                      context,
                                      application['proposed_deadline'],
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    FButton(
                                      variant: .outline,
                                      mainAxisSize: MainAxisSize.min,
                                      onPress: () =>
                                          context.go('/users/${person.id}'),
                                      child: Text(
                                        context.l10n.profileAndPortfolio,
                                      ),
                                    ),
                                    if (application['status'] == 'pending' &&
                                        owner) ...[
                                      ActionButton(
                                        context.l10n.choosePerformer,
                                        action: () async {
                                          if (!await confirm(
                                            context,
                                            context.l10n.choosePerformerTitle,
                                            context.l10n.choosePerformerHint,
                                          )) {
                                            return;
                                          }
                                          final order = await mutate(
                                            ref,
                                            '/applications/${application['id']}/accept',
                                          );
                                          if (context.mounted) {
                                            context.go(
                                              '/orders/${order['id']}',
                                            );
                                          }
                                        },
                                      ),
                                      ActionButton(
                                        context.l10n.reject,
                                        secondary: true,
                                        action: () async {
                                          await mutate(
                                            ref,
                                            '/applications/${application['id']}/reject',
                                          );
                                        },
                                      ),
                                    ],
                                    if (application['status'] == 'pending' &&
                                        !owner)
                                      ActionButton(
                                        context.l10n.withdrawApplication,
                                        secondary: true,
                                        action: () async {
                                          await mutate(
                                            ref,
                                            '/applications/${application['id']}/withdraw',
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    ],
  );
}

class ApplicationForm extends ConsumerStatefulWidget {
  const ApplicationForm(this.id, {this.aiPolicy = AiPolicy.allowed, super.key});
  final int id;
  final AiPolicy aiPolicy;
  @override
  ConsumerState<ApplicationForm> createState() => _ApplicationFormState();
}

class _ApplicationFormState extends ConsumerState<ApplicationForm> {
  final form = GlobalKey<FormState>();
  final message = TextEditingController();
  final comment = TextEditingController();
  final days = TextEditingController(text: '5');
  @override
  void dispose() {
    message.dispose();
    comment.dispose();
    days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          context.l10n.applicationDialogTitle,
          subtitle: context.l10n.applicationIntro,
        ),
        Tag(aiPolicyLabel(context, widget.aiPolicy), color: muted),
        const SizedBox(height: 12),
        Text(
          context.l10n.aiPolicyTerms,
          style: const TextStyle(color: muted, height: 1.5, fontSize: 12),
        ),
        const SizedBox(height: 20),
        Field(context.l10n.applicationWhyYou, message, minLength: 10, lines: 4),
        Field(
          context.l10n.applicationDays,
          days,
          validator: (v) =>
              (int.tryParse(v ?? '') ?? 0) < 1 ||
                  (int.tryParse(v ?? '') ?? 0) > 365
              ? context.l10n.daysValidation
              : null,
        ),
        Field(
          context.l10n.additionalComment,
          comment,
          lines: 2,
          required: false,
        ),
        ActionButton(
          context.l10n.sendApplication,
          action: () async {
            if (!form.currentState!.validate()) return;
            await mutate(
              ref,
              '/tasks/${widget.id}/applications',
              data: {
                'message': message.text.trim(),
                'comment': comment.text.trim(),
                'proposed_deadline': DateTime.now()
                    .add(Duration(days: int.parse(days.text)))
                    .toUtc()
                    .toIso8601String(),
              },
            );
            if (context.mounted) {
              Navigator.pop(context);
              feedback(context, context.l10n.applicationSent);
            }
          },
        ),
      ],
    ),
  );
}
