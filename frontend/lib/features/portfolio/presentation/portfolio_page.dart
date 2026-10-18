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
import '../../tasks/presentation/ai_policy.dart';

class PortfolioGrid extends StatelessWidget {
  const PortfolioGrid(this.cases, {super.key});
  final List<Json> cases;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth > 800
          ? 3
          : constraints.maxWidth > 550
          ? 2
          : 1;
      final width = (constraints.maxWidth - 18 * (columns - 1)) / columns;
      return Wrap(
        spacing: 18,
        runSpacing: 18,
        children: cases
            .map(
              (entry) => SizedBox(
                width: width,
                child: Panel(
                  padding: 20,
                  onTap: () => context.go('/portfolio/${entry['id']}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry['cover_attachment_id'] != null)
                        ProtectedImage(
                          attachmentId: entry['cover_attachment_id'] as int,
                          height: 160,
                          width: double.infinity,
                          borderRadius: BorderRadius.circular(8),
                        )
                      else
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .07),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              entry['verified'] == true
                                  ? FLucideIcons.folderCheck
                                  : FLucideIcons.palette,
                              color: context.theme.colors.primary,
                              size: 44,
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      Text(
                        entry['title'] as String,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        entry['description'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: muted,
                          height: 1.6,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Tag(
                            entry['verified'] == true
                                ? context.l10n.verifiedCase
                                : context.l10n.personalWork,
                            icon: entry['verified'] == true
                                ? FLucideIcons.badgeCheck
                                : FLucideIcons.brush,
                          ),
                          Tag(
                            statusLabel(context, entry['visibility'] as String),
                            color: muted,
                          ),
                          Tag(
                            aiUsageLabel(
                              context,
                              AiUsage.fromCode(entry['ai_usage'] as String?),
                            ),
                            color: muted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class PortfolioDetailPage extends ConsumerWidget {
  const PortfolioDetailPage(this.id, {super.key});
  final int id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    width: 880,
    children: [
      ResourceView(
        '/portfolio/$id',
        builder: (data) {
          final entry = Map<String, dynamic>.from(data as Map);
          final user = ref.watch(sessionProvider).value;
          final own = entry['owner_id'] == user?.id;
          final evidence = entry['evidence'] as Map? ?? {};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Tag(
                    entry['verified'] == true
                        ? context.l10n.verifiedByOrder
                        : context.l10n.personalWork,
                    icon: FLucideIcons.badgeCheck,
                  ),
                  Tag(
                    statusLabel(context, entry['visibility'] as String),
                    color: muted,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PageTitle(
                entry['title'] as String,
                subtitle: context.l10n.completedOn(
                  dateLabel(
                    context,
                    entry['completed_at'] ?? entry['created_at'],
                  ),
                ),
              ),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry['cover_attachment_id'] != null) ...[
                      ProtectedImage(
                        attachmentId: entry['cover_attachment_id'] as int,
                        width: double.infinity,
                        height: 320,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 26),
                    ],
                    Text(
                      context.l10n.projectStory,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SelectableText(
                      entry['description'] as String,
                      style: const TextStyle(height: 1.8),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      context.l10n.result,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SelectableText(
                      entry['result'] as String,
                      style: const TextStyle(height: 1.8),
                    ),
                    const SizedBox(height: 20),
                    Tag(
                      aiUsageLabel(
                        context,
                        AiUsage.fromCode(entry['ai_usage'] as String?),
                      ),
                      color: muted,
                    ),
                    if ('${entry['ai_disclosure'] ?? ''}'.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SelectableText(
                          entry['ai_disclosure'] as String,
                          style: const TextStyle(color: muted, height: 1.6),
                        ),
                      ),
                    if (entry['customer'] != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        context.l10n.customerLabel(
                          (entry['customer'] as Map)['display_name'] as String,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (entry['visibility'] == 'anonymous') ...[
                      const SizedBox(height: 24),
                      Tag(
                        context.l10n.customerIdentityProtected,
                        icon: FLucideIcons.shieldCheck,
                      ),
                    ],
                    if (entry['review'] != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        '★' * ((entry['review'] as Map)['rating'] as int),
                        style: const TextStyle(
                          color: Color(0xFFEAB548),
                          fontSize: 21,
                        ),
                      ),
                      if ((entry['review'] as Map)['comment'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            (entry['review'] as Map)['comment'] as String,
                            style: const TextStyle(height: 1.6),
                          ),
                        ),
                    ],
                    if ((evidence['attachments'] as List? ?? [])
                        .isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        context.l10n.permittedMaterials,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      AttachmentGallery(
                        attachmentIds: (evidence['attachments'] as List)
                            .map((a) => (a as Map)['id'] as int)
                            .where((id) => id != entry['cover_attachment_id'])
                            .toList(),
                      ),
                    ],
                    for (final message in (evidence['messages'] as List? ?? []))
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Panel(
                          color: accent.withValues(alpha: .04),
                          padding: 16,
                          child: Text(
                            '«${(message as Map)['text']}»',
                            style: const TextStyle(height: 1.7),
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FButton(
                          variant: .outline,
                          onPress: () =>
                              context.go('/users/${entry['owner_id']}'),
                          child: Text(context.l10n.authorProfile),
                        ),
                        if (own)
                          FButton(
                            onPress: () => modal(
                              context,
                              VisibilityForm(
                                id,
                                entry['visibility'] as String,
                                coverId: entry['cover_attachment_id'] as int?,
                              ),
                            ),
                            child: Text(context.l10n.privacySettings),
                          ),
                        if (user != null && !own)
                          FButton(
                            variant: .ghost,
                            onPress: () =>
                                modal(context, ReportForm('portfolio', id)),
                            child: Text(context.l10n.report),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class PortfolioFormPage extends ConsumerStatefulWidget {
  const PortfolioFormPage({this.orderId, super.key});
  final int? orderId;
  @override
  ConsumerState<PortfolioFormPage> createState() => _PortfolioFormPageState();
}

class _PortfolioFormPageState extends ConsumerState<PortfolioFormPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final result = TextEditingController();
  final aiDisclosure = TextEditingController();
  AiUsage aiUsage = AiUsage.noAi;
  int? coverId;
  String visibility = 'private';
  bool showCustomer = false;
  List<int> uploads = [];
  final Set<int> messageIds = {};
  final Set<int> attachmentIds = {};
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    result.dispose();
    aiDisclosure.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider).value == null) return requireLogin(context);
    return PageBody(
      width: 800,
      children: [
        PageTitle(
          widget.orderId == null
              ? context.l10n.addPersonalWork
              : context.l10n.caseFromOrder,
          subtitle: widget.orderId == null
              ? context.l10n.personalWorkHint
              : context.l10n.verifiedCaseHint,
        ),
        Panel(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Field(context.l10n.caseTitle, title, minLength: 5),
                Field(
                  context.l10n.caseApproach,
                  description,
                  minLength: 10,
                  lines: 5,
                ),
                Field(context.l10n.caseResult, result, minLength: 5, lines: 4),
                if (widget.orderId == null) ...[
                  ChoiceField(
                    context.l10n.aiUsageLabel,
                    value: aiUsage.code,
                    options: aiUsageOptions(context),
                    onChange: (value) =>
                        setState(() => aiUsage = AiUsage.fromCode(value)),
                  ),
                  if (aiUsage != AiUsage.noAi)
                    Field(
                      context.l10n.aiDisclosureLabel,
                      aiDisclosure,
                      lines: 3,
                      hint: context.l10n.aiDisclosureHint,
                      validator: (value) => (value?.trim().length ?? 0) < 5
                          ? context.l10n.aiDisclosureRequired
                          : null,
                    ),
                ],
                ChoiceField(
                  context.l10n.caseAudience,
                  value: visibility,
                  options: {
                    'private': context.l10n.onlyMe,
                    'anonymous': context.l10n.publicAnonymousCustomer,
                    'public': context.l10n.publicCase,
                  },
                  onChange: (v) => setState(() {
                    visibility = v;
                    coverId = null;
                  }),
                ),
                Text(
                  context.l10n.anonymousCaseHint,
                  style: TextStyle(color: muted, height: 1.7, fontSize: 12),
                ),
                const SizedBox(height: 20),
                if (visibility == 'anonymous')
                  Text(
                    context.l10n.caseCoverAnonymousHint,
                    style: const TextStyle(
                      color: muted,
                      height: 1.6,
                      fontSize: 12,
                    ),
                  )
                else if (widget.orderId == null || visibility == 'private')
                  ImageUploadField(
                    value: coverId,
                    label: context.l10n.coverPhotoLabel,
                    onChange: (value) => setState(() => coverId = value),
                  ),
                if (widget.orderId == null && visibility != 'anonymous')
                  UploadField(onChange: (v) => uploads = v),
                if (visibility == 'public') ...[
                  ChoiceField(
                    context.l10n.revealCustomer,
                    value: '$showCustomer',
                    options: {
                      'false': context.l10n.hide,
                      'true': context.l10n.requestPublicationConsent,
                    },
                    onChange: (v) => setState(() => showCustomer = v == 'true'),
                  ),
                  if (widget.orderId != null) ...[
                    Text(
                      context.l10n.caseCoverConsentHint,
                      style: const TextStyle(
                        color: muted,
                        height: 1.6,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      context.l10n.selectMaterials,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.materialsConsentHint,
                      style: TextStyle(color: muted, height: 1.6, fontSize: 12),
                    ),
                    ResourceView(
                      '/orders/${widget.orderId}/messages?limit=100',
                      builder: (data) => Column(
                        children: items(data)
                            .map(
                              (m) => Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: FButton(
                                  variant: messageIds.contains(m['id'])
                                      ? .primary
                                      : .outline,
                                  onPress: () => setState(() {
                                    final id = m['id'] as int;
                                    messageIds.contains(id)
                                        ? messageIds.remove(id)
                                        : messageIds.add(id);
                                  }),
                                  child: Text(
                                    '#${m['id']} · ${m['text']}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    ResourceView(
                      '/orders/${widget.orderId}/deliverables',
                      builder: (data) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final d in items(data))
                                for (final fileId in List<int>.from(
                                  d['attachment_ids'] as List? ?? [],
                                ))
                                  FButton(
                                    variant: attachmentIds.contains(fileId)
                                        ? .primary
                                        : .outline,
                                    onPress: () => setState(() {
                                      attachmentIds.contains(fileId)
                                          ? attachmentIds.remove(fileId)
                                          : attachmentIds.add(fileId);
                                    }),
                                    child: Text(
                                      context.l10n.mediaFileLabel(fileId),
                                    ),
                                  ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            context.l10n.coverPhotoLabel,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final fileId in {
                                for (final delivery in items(data))
                                  ...List<int>.from(
                                    delivery['attachment_ids'] as List? ?? [],
                                  ),
                              })
                                SizedBox(
                                  width: 150,
                                  child: ResourceView(
                                    '/uploads/$fileId/metadata',
                                    builder: (file) =>
                                        '${file['mime_type']}'.startsWith(
                                          'image/',
                                        )
                                        ? GestureDetector(
                                            onTap: () => setState(() {
                                              coverId = coverId == fileId
                                                  ? null
                                                  : fileId;
                                              if (coverId != null) {
                                                attachmentIds.add(fileId);
                                              }
                                            }),
                                            child: Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: coverId == fileId
                                                      ? accent
                                                      : edge(context),
                                                  width: 2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: ProtectedImage(
                                                attachmentId: fileId,
                                                height: 100,
                                                width: 140,
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                ActionButton(
                  context.l10n.createCase,
                  icon: FLucideIcons.folderCheck,
                  action: () async {
                    if (!form.currentState!.validate()) return;
                    final saved = await mutate(
                      ref,
                      '/portfolio',
                      data: {
                        'order_id': widget.orderId,
                        'title': title.text.trim(),
                        'description': description.text.trim(),
                        'result': result.text.trim(),
                        'ai_usage': aiUsage.code,
                        'ai_disclosure': aiUsage == AiUsage.noAi
                            ? ''
                            : aiDisclosure.text.trim(),
                        'cover_attachment_id': visibility == 'anonymous'
                            ? null
                            : coverId,
                        'visibility': visibility,
                        'attachment_ids': {
                          if (widget.orderId == null &&
                              visibility != 'anonymous')
                            ...uploads,
                          if (visibility == 'public') ...attachmentIds,
                          if (widget.orderId == null &&
                              visibility != 'anonymous' &&
                              coverId != null)
                            coverId!,
                        }.toList(),
                        'message_ids': visibility == 'public'
                            ? messageIds.toList()
                            : [],
                        'show_customer': visibility == 'public' && showCustomer,
                      },
                    );
                    if (context.mounted) {
                      context.go('/portfolio/${saved['id']}');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class VisibilityForm extends ConsumerStatefulWidget {
  const VisibilityForm(this.id, this.initial, {this.coverId, super.key});
  final int id;
  final String initial;
  final int? coverId;
  @override
  ConsumerState<VisibilityForm> createState() => _VisibilityFormState();
}

class _VisibilityFormState extends ConsumerState<VisibilityForm> {
  late String value = widget.initial;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageTitle(
        context.l10n.casePrivacy,
        subtitle: context.l10n.casePrivacyHint,
      ),
      ChoiceField(
        context.l10n.visibility,
        value: value,
        options: {
          'private': context.l10n.visibilityPrivate,
          'anonymous': context.l10n.visibilityAnonymous,
          'public': context.l10n.visibilityPublic,
        },
        onChange: (v) => setState(() => value = v),
      ),
      ActionButton(
        context.l10n.updateVisibility,
        action: () async {
          await mutate(
            ref,
            '/portfolio/${widget.id}/visibility',
            method: 'PATCH',
            data: {
              'visibility': value,
              'show_customer': false,
              'message_ids': [],
              'attachment_ids': [],
              'cover_attachment_id': value == 'anonymous'
                  ? null
                  : widget.coverId,
            },
          );
          if (context.mounted) {
            Navigator.pop(context);
            feedback(context, context.l10n.visibilityUpdated);
          }
        },
      ),
    ],
  );
}
