import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../models/models.dart';

const accent = Color(0xFF6554E8);
const lime = Color(0xFFDDF78E);
const muted = Color(0xFF8B8B9C);

Color surface(BuildContext context) => context.theme.colors.background;
Color ink(BuildContext context) => context.theme.colors.foreground;
Color edge(BuildContext context) => context.theme.colors.border;
String dateLabel(dynamic value) {
  final date = value is DateTime ? value : DateTime.tryParse('$value');
  return date == null ? '—' : DateFormat('d MMM', 'ru').format(date.toLocal());
}

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
          borderRadius: BorderRadius.circular(20),
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
                  fontSize: 30,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
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
    child: Text(busy ? 'Подождите…' : widget.label),
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
              ? 'Введите минимум $minLength символов'
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
                  child: Text(entry.value),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Icon(icon, size: 13, color: color),
          ),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
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
      color: [
        const Color(0xFFECE5FA),
        const Color(0xFFE2F0DC),
        const Color(0xFFFFE6D5),
      ][person.id % 3],
      shape: BoxShape.circle,
    ),
    clipBehavior: Clip.antiAlias,
    child: person.avatar == null
        ? Center(
            child: Text(
              person.name.isEmpty ? '?' : person.name[0],
              style: TextStyle(
                color: accent,
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
                person.name[0],
                style: const TextStyle(color: accent),
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
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Tag(
                      'Нет сети · показаны сохранённые данные',
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
          'Не получилось загрузить',
          subtitle: '$error',
          icon: FLucideIcons.wifiOff,
          action: FButton(
            onPress: () => ref.invalidate(resourceProvider(path)),
            child: const Text('Попробовать снова'),
          ),
        ),
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      3,
      (i) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 15, width: 180, color: edge(context)),
              const SizedBox(height: 18),
              Container(height: 12, color: edge(context)),
              const SizedBox(height: 10),
              Container(height: 12, width: 240, color: edge(context)),
            ],
          ),
        ),
      ),
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
                    child: const Text('Назад'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FButton(
                    onPress: () => Navigator.pop(context, true),
                    child: const Text('Подтвердить'),
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
    super.key,
  });
  final ValueChanged<List<int>> onChange;
  final bool imagesOnly;
  @override
  ConsumerState<UploadField> createState() => _UploadFieldState();
}

class _UploadFieldState extends ConsumerState<UploadField> {
  final List<Json> files = [];
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Panel(
      padding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActionButton(
            'Прикрепить ${widget.imagesOnly ? 'изображение' : 'файлы'}',
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
              for (final file in result.files) {
                if (file.size > 10 * 1024 * 1024) {
                  throw Exception('Файл должен быть меньше 10 МБ');
                }
                if (file.bytes == null) continue;
                final saved = await ref
                    .read(apiProvider)
                    .upload(file.name, file.bytes!);
                if (!mounted) return;
                setState(() {
                  if (widget.imagesOnly) files.clear();
                  files.add(saved);
                });
                widget.onChange(files.map((f) => f['id'] as int).toList());
              }
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'PNG, JPG, WebP, PDF, TXT, ZIP · до 10 МБ',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          for (final file in files)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Icon(FLucideIcons.file, size: 15),
                  const SizedBox(width: 8),
                  Expanded(child: Text(file['filename'] as String)),
                  FButton.icon(
                    variant: .ghost,
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
        const PageTitle(
          'Сообщить о нарушении',
          subtitle: 'Жалобу рассмотрит команда FirstCase.',
        ),
        ChoiceField(
          'Причина',
          value: reason,
          options: const {
            'spam': 'Спам',
            'fraud': 'Мошенничество',
            'abuse': 'Оскорбления',
            'prohibited_content': 'Запрещённый контент',
            'agreement_violation': 'Нарушение договорённостей',
            'rating_manipulation': 'Накрутка',
            'other': 'Другое',
          },
          onChange: (v) => setState(() => reason = v),
        ),
        Field('Что произошло?', description, lines: 4, minLength: 10),
        UploadField(onChange: (v) => files = v),
        ActionButton(
          'Отправить жалобу',
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
              feedback(context, 'Жалоба отправлена');
            }
          },
        ),
      ],
    ),
  );
}
