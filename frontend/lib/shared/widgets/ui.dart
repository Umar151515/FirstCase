import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/providers.dart';
import '../../core/media/media_repository.dart';
import '../../core/l10n/l10n.dart';
import '../models/models.dart';
import 'brand.dart';
import 'media.dart';

export 'brand.dart';

const accent = Color(0xFF174687);
const muted = Color(0xFF7D889A);

Color surface(BuildContext context) => context.theme.colors.background;
Color ink(BuildContext context) => context.theme.colors.foreground;
Color edge(BuildContext context) => context.theme.colors.border;
String dateLabel(BuildContext context, dynamic value) =>
    localizedDate(context, value);

class Panel extends StatelessWidget {
  const Panel({
    required this.child,
    this.padding = 24,
    this.color,
    this.onTap,
    super.key,
  });
  final Widget child;
  final double padding;
  final Color? color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: color ?? surface(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: edge(context)),
        ),
        child: child,
      ),
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({required this.children, this.width = 1220, super.key});
  final List<Widget> children;
  final double width;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width < 650 ? 18 : 36,
      vertical: 28,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    ),
  );
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {this.subtitle, this.action, super.key});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.6,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(color: muted, height: 1.5),
                  ),
                ),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class ActionButton extends StatefulWidget {
  const ActionButton(
    this.label, {
    required this.action,
    this.icon,
    this.secondary = false,
    this.destructive = false,
    this.success,
    super.key,
  });
  final String label;
  final Future<void> Function() action;
  final IconData? icon;
  final bool secondary;
  final bool destructive;
  final String? success;
  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => FButton(
    mainAxisSize: MainAxisSize.min,
    variant: widget.destructive
        ? .destructive
        : widget.secondary
        ? .outline
        : .primary,
    onPress: busy
        ? null
        : () async {
            setState(() => busy = true);
            try {
              await widget.action();
              if (context.mounted && widget.success != null) {
                feedback(context, widget.success!);
              }
            } catch (error) {
              if (context.mounted) feedback(context, '$error', error: true);
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
    prefix: busy
        ? const SizedBox(width: 16, height: 16, child: FCircularProgress())
        : widget.icon == null
        ? null
        : Icon(widget.icon, size: 17),
    child: Flexible(
      child: Text(
        busy ? context.l10n.pleaseWait : widget.label,
        textAlign: TextAlign.center,
      ),
    ),
  );
}

void feedback(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFFBA3047) : accent,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class Field extends StatelessWidget {
  const Field(
    this.label,
    this.controller, {
    this.lines = 1,
    this.required = true,
    this.minLength = 1,
    this.hint,
    this.onChange,
    this.validator,
    super.key,
  });
  final String label;
  final TextEditingController controller;
  final int lines;
  final bool required;
  final int minLength;
  final String? hint;
  final ValueChanged<String>? onChange;
  final String? Function(String?)? validator;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: FTextFormField(
      control: .managed(
        controller: controller,
        onChange: (value) => onChange?.call(value.text),
      ),
      label: Text(label),
      hint: hint,
      maxLines: lines,
      validator:
          validator ??
          (value) => required && (value?.trim().length ?? 0) < minLength
              ? context.l10n.minCharacters(minLength)
              : null,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    ),
  );
}

class ChoiceField extends StatelessWidget {
  const ChoiceField(
    this.label, {
    required this.value,
    required this.options,
    required this.onChange,
    super.key,
  });
  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChange;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.entries
              .map(
                (entry) => FButton(
                  size: .sm,
                  mainAxisSize: MainAxisSize.min,
                  variant: value == entry.key ? .primary : .outline,
                  onPress: () => onChange(entry.key),
                  child: Flexible(
                    child: Text(entry.value, textAlign: TextAlign.center),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {this.color = accent, this.icon, super.key});
  final String text;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final tone = color == accent ? context.theme.colors.primary : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Icon(icon, size: 13, color: tone),
            ),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar(this.person, {this.size = 38, super.key});
  final Person person;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .1),
      shape: BoxShape.circle,
    ),
    clipBehavior: Clip.antiAlias,
    child: person.avatarAttachmentId != null
        ? ProtectedImage(
            attachmentId: person.avatarAttachmentId!,
            width: size,
            height: size,
          )
        : person.avatar == null
        ? Center(
            child: Text(
              person.name.isEmpty ? '?' : person.name[0],
              style: TextStyle(
                color: context.theme.colors.primary,
                fontSize: size * .4,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : Image.network(
            person.avatar!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Center(
              child: Text(
                person.name.isEmpty ? '?' : person.name[0],
                style: TextStyle(color: context.theme.colors.primary),
              ),
            ),
          ),
  );
}

class ResourceView extends ConsumerWidget {
  const ResourceView(this.path, {required this.builder, super.key});
  final String path;
  final Widget Function(dynamic) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(resourceProvider(path))
      .when(
        data: (data) => data is Map && data['_offline'] == true
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Tag(
                      context.l10n.offlineData,
                      color: muted,
                      icon: FLucideIcons.wifiOff,
                    ),
                  ),
                  builder(data),
                ],
              )
            : builder(data),
        loading: () => const LoadingView(),
        error: (error, _) => StateMessage(
          context.l10n.loadFailed,
          subtitle: '$error',
          icon: FLucideIcons.wifiOff,
          action: FButton(
            onPress: () => ref.invalidate(resourceProvider(path)),
            child: Text(context.l10n.tryAgain),
          ),
        ),
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: BrandLoading(),
    ),
  );
}

class StateMessage extends StatelessWidget {
  const StateMessage(
    this.title, {
    this.subtitle,
    this.icon = FLucideIcons.inbox,
    this.action,
    super.key,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        children: [
          Icon(icon, color: muted, size: 38),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted),
              ),
            ),
          ?action,
        ],
      ),
    ),
  );
}

Future<dynamic> modal(BuildContext context, Widget child) =>
    showDialog<dynamic>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: surface(context),
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 740),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: child,
          ),
        ),
      ),
    );

Future<bool> confirm(
  BuildContext context,
  String title,
  String description,
) async =>
    await modal(
      context,
      Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(description),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FButton(
                    variant: .outline,
                    onPress: () => Navigator.pop(context, false),
                    child: Text(context.l10n.back),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FButton(
                    onPress: () => Navigator.pop(context, true),
                    child: Text(context.l10n.confirm),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ) ==
    true;

class UploadField extends ConsumerStatefulWidget {
  const UploadField({
    required this.onChange,
    this.imagesOnly = false,
    this.initialIds = const [],
    super.key,
  });
  final ValueChanged<List<int>> onChange;
  final bool imagesOnly;
  final List<int> initialIds;
  @override
  ConsumerState<UploadField> createState() => _UploadFieldState();
}

class _UploadFieldState extends ConsumerState<UploadField> {
  final List<Json> files = [];
  @override
  void initState() {
    super.initState();
    files.addAll(widget.initialIds.map((id) => <String, dynamic>{'id': id}));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Panel(
      padding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActionButton(
            widget.imagesOnly
                ? context.l10n.attachImage
                : context.l10n.attachFiles,
            secondary: true,
            icon: FLucideIcons.paperclip,
            action: () async {
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: !widget.imagesOnly,
                withData: true,
                type: FileType.custom,
                allowedExtensions: widget.imagesOnly
                    ? ['png', 'jpg', 'jpeg', 'webp']
                    : ['png', 'jpg', 'jpeg', 'webp', 'pdf', 'txt', 'zip'],
              );
              if (result == null) return;
              if (!context.mounted) return;
              await withUploadProgress(context, () async {
                for (final file in result.files) {
                  if (!context.mounted) return;
                  if (file.size > 10 * 1024 * 1024) {
                    throw Exception(context.l10n.mediaFileTooLarge);
                  }
                  if (file.bytes == null) continue;
                  final saved = await ref
                      .read(mediaRepositoryProvider)
                      .upload(file.name, file.bytes!);
                  if (!mounted) return;
                  setState(() {
                    if (widget.imagesOnly) files.clear();
                    files.add(saved);
                  });
                  widget.onChange(files.map((f) => f['id'] as int).toList());
                }
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            widget.imagesOnly
                ? context.l10n.mediaUploadHint
                : context.l10n.mediaFilesHint,
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          for (final file in files)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Icon(FLucideIcons.file, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file['filename'] as String? ??
                          context.l10n.mediaFileLabel(file['id'] as int),
                    ),
                  ),
                  FButton.icon(
                    variant: .ghost,
                    semanticsLabel: context.l10n.mediaRemoveFile,
                    onPress: () {
                      setState(() => files.remove(file));
                      widget.onChange(
                        files.map((f) => f['id'] as int).toList(),
                      );
                    },
                    child: const Icon(FLucideIcons.x, size: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

Future<dynamic> mutate(
  WidgetRef ref,
  String path, {
  Json? data,
  String method = 'POST',
}) async {
  final result = await ref
      .read(taskRepositoryProvider)
      .mutate(path, data: data, method: method);
  ref.invalidate(resourceProvider);
  return result;
}

class ReportForm extends ConsumerStatefulWidget {
  const ReportForm(this.type, this.id, {super.key});
  final String type;
  final int id;
  @override
  ConsumerState<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<ReportForm> {
  final form = GlobalKey<FormState>();
  final description = TextEditingController();
  String reason = 'other';
  List<int> files = [];
  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(context.l10n.reportTitle, subtitle: context.l10n.reportIntro),
        ChoiceField(
          context.l10n.reason,
          value: reason,
          options: {
            'spam': context.l10n.reasonSpam,
            'fraud': context.l10n.reasonFraud,
            'abuse': context.l10n.reasonAbuse,
            'prohibited_content': context.l10n.reasonProhibited,
            'agreement_violation': context.l10n.reasonAgreement,
            'rating_manipulation': context.l10n.reasonRating,
            'other': context.l10n.categoryOther,
          },
          onChange: (v) => setState(() => reason = v),
        ),
        Field(
          context.l10n.reportWhatHappened,
          description,
          lines: 4,
          minLength: 10,
        ),
        UploadField(onChange: (v) => files = v),
        ActionButton(
          context.l10n.sendReport,
          action: () async {
            if (!form.currentState!.validate()) return;
            await mutate(
              ref,
              '/reports',
              data: {
                'target_type': widget.type,
                'target_id': widget.id,
                'reason': reason,
                'description': description.text.trim(),
                'attachment_ids': files,
              },
            );
            if (context.mounted) {
              Navigator.pop(context);
              feedback(context, context.l10n.reportSent);
            }
          },
        ),
      ],
    ),
  );
}
