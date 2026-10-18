import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../../shared/widgets/media.dart';
import '../../auth/presentation/login_page.dart';
import 'ai_policy.dart';

class TaskFormPage extends ConsumerStatefulWidget {
  const TaskFormPage({this.id, super.key});
  final int? id;
  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final result = TextEditingController();
  final city = TextEditingController();
  final days = TextEditingController(text: '7');
  String category = '';
  String payment = 'tips';
  String revisions = '2';
  AiPolicy aiPolicy = AiPolicy.allowed;
  int? coverId;
  DateTime? originalDeadline;
  String? originalDays;
  List<int> attachments = [];
  bool loaded = false;
  Object? loadError;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loaded = false;
        loadError = null;
      });
    }
    try {
      final repository = ref.read(taskRepositoryProvider);
      final data = widget.id == null
          ? await repository.draft()
          : await repository.resource('/tasks/${widget.id}');
      if (data is Map && mounted) {
        title.text = data['title'] as String? ?? '';
        description.text = data['description'] as String? ?? '';
        result.text = data['expected_result'] as String? ?? '';
        city.text = data['city'] as String? ?? '';
        days.text = '${data['days'] ?? 7}';
        category = '${data['category_id'] ?? ''}';
        payment = data['payment_type'] as String? ?? 'tips';
        revisions = '${data['max_revisions'] ?? 2}';
        aiPolicy = AiPolicy.fromCode(data['ai_policy'] as String?);
        coverId = data['cover_attachment_id'] as int?;
        attachments = List<int>.from(data['attachment_ids'] as List? ?? [])
            .where((id) => id != coverId)
            .toList();
        if (data['deadline'] is String) {
          originalDeadline = DateTime.parse(data['deadline'] as String);
          days.text =
              '${(originalDeadline!.difference(DateTime.now()).inHours / 24).ceil().clamp(1, 365)}';
          originalDays = days.text;
        }
      }
    } catch (error) {
      loadError = error;
    }
    if (mounted) setState(() => loaded = true);
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    result.dispose();
    city.dispose();
    days.dispose();
    super.dispose();
  }

  Json values() => {
    'title': title.text.trim(),
    'description': description.text.trim(),
    'expected_result': result.text.trim(),
    'city': city.text.trim(),
    'category_id': int.tryParse(category),
    'payment_type': payment,
    'max_revisions': int.parse(revisions),
    'days': int.tryParse(days.text),
    'ai_policy': aiPolicy.code,
    'cover_attachment_id': coverId,
    'attachment_ids': {...attachments, ?coverId}.toList(),
  };
  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider).value == null) return requireLogin(context);
    if (!loaded) return const PageBody(children: [LoadingView()]);
    if (loadError != null) {
      return PageBody(
        children: [
          StateMessage(
            context.l10n.taskLoadFailed,
            subtitle: '$loadError',
            action: FButton(onPress: load, child: Text(context.l10n.retry)),
          ),
        ],
      );
    }
    return PageBody(
      width: 800,
      children: [
        PageTitle(
          widget.id == null
              ? context.l10n.taskNewTitle
              : context.l10n.taskEditTitle,
          subtitle: context.l10n.taskFormSubtitle,
        ),
        Panel(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tag(context.l10n.taskSectionAbout),
                const SizedBox(height: 24),
                Field(
                  context.l10n.taskTitle,
                  title,
                  minLength: 5,
                  hint: context.l10n.taskTitleHint,
                ),
                ref
                    .watch(categoriesProvider)
                    .when(
                      data: (categories) => ChoiceField(
                        context.l10n.category,
                        value: category,
                        options: {
                          for (final c in categories)
                            '${c['id']}': c['name'] as String,
                        },
                        onChange: (v) => setState(() => category = v),
                      ),
                      loading: () => const FCircularProgress(),
                      error: (e, _) => Text('$e'),
                    ),
                Field(
                  context.l10n.taskDetailedDescription,
                  description,
                  minLength: 20,
                  lines: 5,
                  hint: context.l10n.taskDescriptionHint,
                ),
                Field(
                  context.l10n.expectedResult,
                  result,
                  minLength: 5,
                  lines: 3,
                  hint: context.l10n.expectedResultHint,
                ),
                ImageUploadField(
                  label: context.l10n.coverPhotoLabel,
                  value: coverId,
                  onChange: (value) => setState(() => coverId = value),
                ),
                const SizedBox(height: 8),
                Tag(context.l10n.taskSectionTerms),
                const SizedBox(height: 24),
                Field(
                  context.l10n.deadlineDays,
                  days,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 1 || n > 365
                        ? context.l10n.daysValidation
                        : null;
                  },
                ),
                ChoiceField(
                  context.l10n.agreedRevisions,
                  value: revisions,
                  options: {
                    '0': context.l10n.noRevisions,
                    '1': context.l10n.oneRevision,
                    '2': context.l10n.twoRevisions,
                    '3': context.l10n.threeRevisions,
                  },
                  onChange: (v) => setState(() => revisions = v),
                ),
                Field(context.l10n.city, city, required: false),
                ChoiceField(
                  context.l10n.aiPolicyLabel,
                  value: aiPolicy.code,
                  options: aiPolicyOptions(context),
                  onChange: (value) =>
                      setState(() => aiPolicy = AiPolicy.fromCode(value)),
                ),
                Text(
                  context.l10n.aiPolicyHint,
                  style: const TextStyle(
                    color: muted,
                    height: 1.6,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
                ChoiceField(
                  context.l10n.workGratitude,
                  value: payment,
                  options: {
                    'free': context.l10n.freeForExperience,
                    'tips': context.l10n.voluntaryTips,
                  },
                  onChange: (v) => setState(() => payment = v),
                ),
                Text(
                  context.l10n.noInAppPayments,
                  style: TextStyle(color: muted, height: 1.6, fontSize: 12),
                ),
                const SizedBox(height: 24),
                UploadField(
                  initialIds: attachments,
                  onChange: (v) => attachments = v,
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ActionButton(
                      widget.id == null
                          ? context.l10n.publishTask
                          : context.l10n.saveChanges,
                      icon: FLucideIcons.arrowUpRight,
                      action: () async {
                        if (!form.currentState!.validate()) return;
                        if (category.isEmpty) {
                          throw Exception(context.l10n.chooseCategory);
                        }
                        final data = values()..remove('days');
                        data['deadline'] =
                            (originalDeadline != null &&
                                        days.text == originalDays
                                    ? originalDeadline!
                                    : DateTime.now().add(
                                        Duration(days: int.parse(days.text)),
                                      ))
                                .toUtc()
                                .toIso8601String();
                        final saved = await mutate(
                          ref,
                          widget.id == null ? '/tasks' : '/tasks/${widget.id}',
                          method: widget.id == null ? 'POST' : 'PATCH',
                          data: data,
                        );
                        await ref.read(taskRepositoryProvider).clearDraft();
                        if (context.mounted) {
                          context.go('/tasks/${saved['id']}');
                        }
                      },
                    ),
                    if (widget.id == null)
                      ActionButton(
                        context.l10n.saveDraft,
                        secondary: true,
                        success: context.l10n.draftSaved,
                        action: () => ref
                            .read(taskRepositoryProvider)
                            .saveDraft(values()),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
