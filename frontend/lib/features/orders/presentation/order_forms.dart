import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/ui.dart';
import '../../tasks/presentation/ai_policy.dart';

class SubmitForm extends ConsumerStatefulWidget {
  const SubmitForm(this.id, {this.aiPolicy = AiPolicy.allowed, super.key});
  final int id;
  final AiPolicy aiPolicy;
  @override
  ConsumerState<SubmitForm> createState() => _SubmitFormState();
}

class _SubmitFormState extends ConsumerState<SubmitForm> {
  final form = GlobalKey<FormState>();
  final description = TextEditingController();
  final links = TextEditingController();
  final aiDisclosure = TextEditingController();
  AiUsage aiUsage = AiUsage.noAi;
  List<int> files = [];
  @override
  void dispose() {
    description.dispose();
    links.dispose();
    aiDisclosure.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(context.l10n.workResult, subtitle: context.l10n.submitIntro),
        Tag(aiPolicyLabel(context, widget.aiPolicy), color: muted),
        const SizedBox(height: 18),
        Field(
          context.l10n.workDescription,
          description,
          lines: 5,
          minLength: 10,
        ),
        Field(
          context.l10n.resultLinks,
          links,
          lines: 2,
          required: false,
          validator: (value) =>
              parseLinks(value ?? '')
                  .any((link) => Uri.tryParse(link)?.scheme != 'https')
              ? context.l10n.httpsLinksOnly
              : null,
        ),
        UploadField(onChange: (v) => files = v),
        ChoiceField(
          context.l10n.aiUsageLabel,
          value: aiUsage.code,
          options: aiUsageOptions(context, policy: widget.aiPolicy),
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
        ActionButton(
          context.l10n.submitForReview,
          icon: FLucideIcons.send,
          action: () async {
            if (!form.currentState!.validate()) return;
            await mutate(
              ref,
              '/orders/${widget.id}/submit',
              data: {
                'description': description.text.trim(),
                'links': parseLinks(links.text),
                'attachment_ids': files,
                'ai_usage': aiUsage.code,
                'ai_disclosure': aiUsage == AiUsage.noAi
                    ? ''
                    : aiDisclosure.text.trim(),
              },
            );
            if (context.mounted) {
              Navigator.pop(context);
              feedback(context, context.l10n.resultSubmitted);
            }
          },
        ),
      ],
    ),
  );
}

List<String> parseLinks(String value) => value
    .split(RegExp(r'[\n,]'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

class RevisionForm extends ConsumerStatefulWidget {
  const RevisionForm(this.id, {super.key});
  final int id;
  @override
  ConsumerState<RevisionForm> createState() => _RevisionFormState();
}

class _RevisionFormState extends ConsumerState<RevisionForm> {
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
        PageTitle(
          context.l10n.revisionTitle,
          subtitle: context.l10n.revisionIntro,
        ),
        Field(context.l10n.revisionList, reason, minLength: 5, lines: 5),
        ActionButton(
          context.l10n.requestRevision,
          action: () async {
            if (!form.currentState!.validate()) return;
            await mutate(
              ref,
              '/orders/${widget.id}/request-revision',
              data: {'reason': reason.text.trim()},
            );
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}

class ReviewForm extends ConsumerStatefulWidget {
  const ReviewForm(this.id, {this.requiredComment = true, super.key});
  final int id;
  final bool requiredComment;
  @override
  ConsumerState<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<ReviewForm> {
  final form = GlobalKey<FormState>();
  final comment = TextEditingController();
  int rating = 5;
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
        PageTitle(
          context.l10n.reviewTitle,
          subtitle: widget.requiredComment
              ? context.l10n.reviewCustomerHint
              : context.l10n.reviewPerformerHint,
        ),
        ResourceView(
          '/orders/${widget.id}/deliverables',
          builder: (data) {
            final deliveries = items(data);
            if (deliveries.isEmpty) return const SizedBox.shrink();
            final finalDelivery = deliveries.last;
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tag(
                    aiUsageLabel(
                      context,
                      AiUsage.fromCode(finalDelivery['ai_usage'] as String?),
                    ),
                    color: muted,
                  ),
                  if ('${finalDelivery['ai_disclosure'] ?? ''}'.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        finalDelivery['ai_disclosure'] as String,
                        style: const TextStyle(color: muted, height: 1.5),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        Row(
          children: List.generate(
            5,
            (i) => Expanded(
              child: FButton.icon(
                size: .sm,
                variant: .ghost,
                onPress: () => setState(() => rating = i + 1),
                child: Icon(
                  FLucideIcons.star,
                  size: 24,
                  color: i < rating ? const Color(0xFFEAB548) : muted,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Field(
          context.l10n.yourReview,
          comment,
          lines: 4,
          required: widget.requiredComment,
          minLength: 5,
        ),
        ActionButton(
          context.l10n.publishReview,
          action: () async {
            if (!form.currentState!.validate()) return;
            await mutate(
              ref,
              '/orders/${widget.id}/reviews',
              data: {'rating': rating, 'comment': comment.text.trim()},
            );
            if (context.mounted) {
              Navigator.pop(context);
              feedback(context, context.l10n.reviewPublished);
            }
          },
        ),
      ],
    ),
  );
}

class PrivacyForm extends ConsumerStatefulWidget {
  const PrivacyForm(
    this.id, {
    required this.messages,
    required this.attachmentIds,
    super.key,
  });
  final int id;
  final List<Json> messages;
  final List<int> attachmentIds;
  @override
  ConsumerState<PrivacyForm> createState() => _PrivacyFormState();
}

class _PrivacyFormState extends ConsumerState<PrivacyForm> {
  bool identity = false;
  final Set<int> messages = {};
  final Set<int> files = {};
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageTitle(
        context.l10n.publicationPermissions,
        subtitle: context.l10n.publicationPermissionsHint,
      ),
      _toggle(
        context.l10n.allowIdentity,
        identity,
        () => setState(() => identity = !identity),
      ),
      const SizedBox(height: 18),
      Text(
        context.l10n.messageExcerpts,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      for (final message in widget.messages)
        _toggle(
          '#${message['id']} · ${message['text']}',
          messages.contains(message['id']),
          () => setState(() {
            final id = message['id'] as int;
            messages.contains(id) ? messages.remove(id) : messages.add(id);
          }),
        ),
      const SizedBox(height: 18),
      Text(
        context.l10n.attachments,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      for (final id in widget.attachmentIds)
        _toggle(
          context.l10n.mediaFileLabel(id),
          files.contains(id),
          () => setState(() {
            files.contains(id) ? files.remove(id) : files.add(id);
          }),
        ),
      const SizedBox(height: 20),
      ActionButton(
        context.l10n.savePermissions,
        action: () async {
          await mutate(
            ref,
            '/orders/${widget.id}/privacy-consent',
            method: 'PUT',
            data: {
              'allow_identity': identity,
              'attachment_ids': files.toList(),
              'message_ids': messages.toList(),
            },
          );
          if (context.mounted) {
            Navigator.pop(context);
            feedback(context, context.l10n.permissionsUpdated);
          }
        },
      ),
    ],
  );
  Widget _toggle(String text, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: edge(context)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: FCheckbox(
        value: selected,
        onChange: (_) => onTap(),
        label: Text(text, softWrap: true, style: const TextStyle(height: 1.5)),
      ),
    ),
  );
}
