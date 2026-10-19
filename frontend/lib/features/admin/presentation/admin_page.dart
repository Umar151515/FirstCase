import '../../../core/l10n/l10n.dart';

import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../../shared/widgets/attachment_button.dart';

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});
  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  String tab = 'stats';
  String status = '';
  String query = '';
  int offset = 0;
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider).value?.admin != true) {
      return StateMessage(
        context.l10n.adminRestricted,
        subtitle: context.l10n.adminRestrictedHint,
        icon: FLucideIcons.lockKeyhole,
      );
    }
    final path = Uri(
      path: '/admin/$tab',
      queryParameters: {
        'limit': '20',
        'offset': '$offset',
        if (query.isNotEmpty) 'q': query,
        if (status.isNotEmpty) 'status': status,
      },
    ).toString();
    return PageBody(
      children: [
        PageTitle(
          context.l10n.adminSection,
          subtitle: context.l10n.adminSubtitle,
        ),
        ChoiceField(
          context.l10n.adminSection,
          value: tab,
          options: {
            'stats': context.l10n.adminOverview,
            'users': context.l10n.adminUsers,
            'tasks': context.l10n.adminTasks,
            'orders': context.l10n.adminOrders,
            'reports': context.l10n.adminReports,
            'moderation-actions': context.l10n.adminAudit,
          },
          onChange: (v) => setState(() {
            tab = v;
            status = '';
            query = '';
            offset = 0;
            search.clear();
          }),
        ),
        if (tab == 'stats')
          ResourceView(
            '/admin/stats',
            builder: (data) => LayoutBuilder(
              builder: (context, constraints) {
                final labels = {
                  'users': context.l10n.statUsers,
                  'active_tasks': context.l10n.statActiveTasks,
                  'completed_orders': context.l10n.statCompletedOrders,
                  'applications': context.l10n.statApplications,
                  'reviews': context.l10n.statReviews,
                  'verified_cases': context.l10n.statVerifiedCases,
                  'open_reports': context.l10n.statOpenReports,
                };
                final columns = constraints.maxWidth > 900
                    ? 4
                    : constraints.maxWidth > 550
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - 16 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: labels.entries
                      .map(
                        (entry) => SizedBox(
                          width: width,
                          child: Panel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${data[entry.key] ?? 0}',
                                  style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                    color: context.theme.colors.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  entry.value,
                                  style: const TextStyle(color: muted),
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
          )
        else ...[
          if (tab == 'users')
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  Expanded(
                    child: FTextField(
                      control: .managed(controller: search),
                      hint: context.l10n.adminSearchUsers,
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
                    child: Flexible(child: Text(context.l10n.search)),
                  ),
                ],
              ),
            ),
          if (tab != 'moderation-actions')
            ChoiceField(
              context.l10n.filter,
              value: status,
              options: {
                '': context.l10n.all,
                ...switch (tab) {
                  'users' => {
                    'active': context.l10n.filterActive,
                    'blocked': context.l10n.filterBlocked,
                  },
                  'reports' => {
                    'pending': context.l10n.filterNew,
                    'in_review': context.l10n.statusInReview,
                    'resolved': context.l10n.filterResolved,
                    'rejected': context.l10n.filterRejected,
                  },
                  'tasks' => {
                    'published': context.l10n.filterOpen,
                    'assigned': context.l10n.statusInProgress,
                    'completed': context.l10n.filterCompleted,
                    'cancelled': context.l10n.filterCancelled,
                  },
                  _ => {
                    'assigned': context.l10n.filterAssigned,
                    'in_progress': context.l10n.statusInProgress,
                    'submitted': context.l10n.statusSubmitted,
                    'completed': context.l10n.filterCompleted,
                    'disputed': context.l10n.filterDisputed,
                  },
                },
              },
              onChange: (v) => setState(() {
                status = v;
                offset = 0;
              }),
            ),
          ResourceView(
            path,
            builder: (data) {
              final list = items(data);
              return Column(
                children: [
                  if (list.isEmpty)
                    StateMessage(
                      context.l10n.emptyTitle,
                      subtitle: context.l10n.emptyFilterHint,
                    ),
                  for (final row in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Panel(child: _row(context, row)),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FButton(
                        variant: .outline,
                        onPress: offset == 0
                            ? null
                            : () => setState(() => offset -= 20),
                        child: Flexible(child: Text(context.l10n.back)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(15),
                        child: Text('${offset ~/ 20 + 1}'),
                      ),
                      FButton(
                        variant: .outline,
                        onPress: offset + 20 >= (data['total'] as int)
                            ? null
                            : () => setState(() => offset += 20),
                        child: Flexible(child: Text(context.l10n.next)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, Json row) {
    if (tab == 'users') {
      final person = Person(row);
      final blocked = row['status'] == 'blocked';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PersonAvatar(person),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  person.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Tag(
                blocked ? context.l10n.userBlocked : context.l10n.userActive,
                color: blocked
                    ? const Color(0xFFBE4354)
                    : context.theme.colors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FButton(
                variant: .outline,
                onPress: () => context.go('/users/${person.id}'),
                child: Flexible(child: Text(context.l10n.navProfile)),
              ),
              FButton(
                onPress: () => modal(
                  context,
                  AdminActionForm(
                    title: blocked
                        ? context.l10n.adminUnblockUser
                        : context.l10n.adminBlockUser,
                    path: '/admin/users/${person.id}',
                    data: {'status': blocked ? 'active' : 'blocked'},
                  ),
                ),
                child: Flexible(
                  child: Text(
                    blocked ? context.l10n.unblock : context.l10n.block,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    if (tab == 'tasks') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row['title'] as String,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              Tag(statusLabel(context, row['status'] as String)),
              if (row['is_hidden'] == true)
                Tag(context.l10n.hidden, color: Color(0xFFBE4354)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FButton(
                variant: .outline,
                onPress: () => context.go('/tasks/${row['id']}'),
                child: Flexible(child: Text(context.l10n.openTask)),
              ),
              FButton(
                onPress: () => modal(
                  context,
                  AdminActionForm(
                    title: row['is_hidden'] == true
                        ? context.l10n.adminRestoreTask
                        : context.l10n.adminHideTask,
                    path: '/admin/tasks/${row['id']}',
                    data: {'is_hidden': row['is_hidden'] != true},
                  ),
                ),
                child: Flexible(
                  child: Text(
                    row['is_hidden'] == true
                        ? context.l10n.restore
                        : context.l10n.hide,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    if (tab == 'orders') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${row['id']} · ${(row['task'] as Map)['title']}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Tag(statusLabel(context, row['status'] as String)),
          const SizedBox(height: 12),
          Text(
            context.l10n.orderParticipants(
              (row['customer'] as Map)['display_name'] as String,
              (row['performer'] as Map)['display_name'] as String,
            ),
            style: const TextStyle(height: 1.8),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.adminChatPrivacy,
            style: TextStyle(color: muted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FButton(
                variant: .outline,
                onPress: () => modal(
                  context,
                  ResourceView(
                    '/admin/orders/${row['id']}/events',
                    builder: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PageTitle(context.l10n.orderHistory),
                        for (final event in items(data))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '${statusLabel(context, event['type'] as String)} · ${dateLabel(context, event['created_at'])}',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                child: Flexible(child: Text(context.l10n.eventHistory)),
              ),
              if (row['status'] == 'disputed') ...[
                FButton(
                  onPress: () => modal(
                    context,
                    AdminActionForm(
                      title: context.l10n.adminResumeDisputed,
                      path: '/admin/orders/${row['id']}/resolve-dispute',
                      data: const {'action': 'resume'},
                      method: 'POST',
                    ),
                  ),
                  child: Flexible(child: Text(context.l10n.resumeWork)),
                ),
                FButton(
                  variant: .outline,
                  onPress: () => modal(
                    context,
                    AdminActionForm(
                      title: context.l10n.adminCancelDisputed,
                      path: '/admin/orders/${row['id']}/resolve-dispute',
                      data: const {'action': 'cancel'},
                      method: 'POST',
                    ),
                  ),
                  child: Flexible(child: Text(context.l10n.cancelOrder)),
                ),
              ],
            ],
          ),
        ],
      );
    }
    if (tab == 'reports') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.adminReportLabel(
                    row['id'] as int,
                    contentTypeLabel(context, row['target_type'] as String),
                    row['target_id'] as int,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Tag(statusLabel(context, row['status'] as String)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            row['description'] as String,
            style: const TextStyle(height: 1.7),
          ),
          if ('${row['moderator_comment'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                context.l10n.decisionLabel(row['moderator_comment'] as String),
                style: TextStyle(color: context.theme.colors.primary),
              ),
            ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FButton(
                onPress: () =>
                    modal(context, ReportDecisionForm(row['id'] as int)),
                child: Flexible(child: Text(context.l10n.adminProcessReport)),
              ),
              if (['pending', 'in_review'].contains(row['status']))
                FButton(
                  variant: .outline,
                  onPress: () => modal(context, EvidenceForm(row['id'] as int)),
                  child: Flexible(
                    child: Text(context.l10n.adminInspectEvidence),
                  ),
                ),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          moderationLabel(context, row['action'] as String? ?? ''),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.auditTarget(
            contentTypeLabel(context, row['target_type'] as String),
            row['target_id'] as int,
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(
          row['reason'] as String,
          style: const TextStyle(height: 1.5),
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.auditModerator(row['admin_id'] as int),
          style: const TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 4),
        Text(
          dateLabel(context, row['created_at']),
          style: const TextStyle(fontSize: 12, color: muted),
        ),
      ],
    );
  }
}

class AdminActionForm extends ConsumerStatefulWidget {
  const AdminActionForm({
    required this.title,
    required this.path,
    required this.data,
    this.method = 'PATCH',
    super.key,
  });
  final String title;
  final String path;
  final Json data;
  final String method;
  @override
  ConsumerState<AdminActionForm> createState() => _AdminActionFormState();
}

class _AdminActionFormState extends ConsumerState<AdminActionForm> {
  final form = GlobalKey<FormState>();
  final reason = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(widget.title, subtitle: context.l10n.adminActionAuditHint),
        Field(context.l10n.reasonBasis, reason, lines: 3, minLength: 10),
        ActionButton(
          context.l10n.confirmAction,
          action: () async {
            if (!form.currentState!.validate()) return;
            await mutate(
              ref,
              widget.path,
              method: widget.method,
              data: {...widget.data, 'reason': reason.text.trim()},
            );
            if (context.mounted) {
              Navigator.pop(context);
              feedback(context, context.l10n.actionCompleted);
            }
          },
        ),
      ],
    ),
  );
}

class ReportDecisionForm extends ConsumerStatefulWidget {
  const ReportDecisionForm(this.id, {super.key});
  final int id;
  @override
  ConsumerState<ReportDecisionForm> createState() => _ReportDecisionFormState();
}

class _ReportDecisionFormState extends ConsumerState<ReportDecisionForm> {
  final form = GlobalKey<FormState>();
  final comment = TextEditingController();
  String status = 'in_review';
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(context.l10n.adminReportDecisionTitle(widget.id)),
        ChoiceField(
          context.l10n.status,
          value: status,
          options: {
            'in_review': context.l10n.statusInReview,
            'resolved': context.l10n.statusResolved,
            'rejected': context.l10n.statusRejectedReport,
          },
          onChange: (v) => setState(() => status = v),
        ),
        Field(context.l10n.moderatorComment, comment, lines: 4, minLength: 5),
        ActionButton(
          context.l10n.saveDecision,
          action: () async {
            if (!form.currentState!.validate()) return;
            await mutate(
              ref,
              '/admin/reports/${widget.id}',
              method: 'PATCH',
              data: {
                'status': status,
                'moderator_comment': comment.text.trim(),
              },
            );
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}

class EvidenceForm extends ConsumerStatefulWidget {
  const EvidenceForm(this.id, {super.key});
  final int id;
  @override
  ConsumerState<EvidenceForm> createState() => _EvidenceFormState();
}

class _EvidenceFormState extends ConsumerState<EvidenceForm> {
  final form = GlobalKey<FormState>();
  final reason = TextEditingController();
  Json? evidence;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          context.l10n.evidenceAccess,
          subtitle: context.l10n.evidenceAccessHint,
        ),
        Field(
          context.l10n.evidenceAccessReason,
          reason,
          lines: 3,
          minLength: 10,
        ),
        ActionButton(
          context.l10n.openMaterials,
          action: () async {
            if (!form.currentState!.validate()) return;
            final data = await ref
                .read(taskRepositoryProvider)
                .mutate(
                  '/admin/reports/${widget.id}/evidence-access',
                  data: {'reason': reason.text.trim()},
                );
            if (mounted) {
              setState(() => evidence = Map<String, dynamic>.from(data as Map));
            }
            ref.invalidate(
              resourceProvider('/admin/moderation-actions?limit=20&offset=0'),
            );
          },
        ),
        if (evidence != null) ...[
          const SizedBox(height: 20),
          for (final message in (evidence!['messages'] as List? ?? []))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: 12,
                child: Text(
                  '${(message as Map)['text']}',
                  style: const TextStyle(height: 1.6),
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (evidence!['attachments'] as List? ?? [])
                .map(
                  (file) => AttachmentButton(
                    (file as Map)['id'] as int,
                    filename: file['filename'] as String?,
                    path:
                        '/admin/reports/${widget.id}/attachments/${file['id']}',
                  ),
                )
                .toList(),
          ),
          if (evidence!['portfolio'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                '${evidence!['portfolio']}',
                style: const TextStyle(height: 1.7),
              ),
            ),
        ],
      ],
    ),
  );
}
