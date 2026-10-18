import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/media/media_repository.dart';

// Keep the selected form and identity stable until its attachments are ready.
// Uploads are bounded by the API timeout and size limit.
Future<T> withUploadProgress<T>(
  BuildContext context,
  Future<T> Function() upload,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 20, height: 20, child: FCircularProgress()),
              const SizedBox(width: 16),
              Text(context.l10n.pleaseWait),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await upload();
  } finally {
    if (navigator.mounted) navigator.pop();
    await dialog;
  }
}

class ProtectedImage extends ConsumerWidget {
  const ProtectedImage({
    required this.attachmentId,
    this.downloadPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.semanticLabel,
    super.key,
  });
  final int attachmentId;
  final String? downloadPath;
  final double? width, height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ClipRRect(
    borderRadius: borderRadius ?? BorderRadius.zero,
    child: SizedBox(
      width: width,
      height: height,
      child: ref
          .watch(mediaBytesProvider((id: attachmentId, path: downloadPath)))
          .when(
            data: (file) => Image.memory(
              file.bytes,
              fit: fit,
              width: width,
              height: height,
              semanticLabel: semanticLabel,
              errorBuilder: (_, _, _) =>
                  _UnavailableImage(label: context.l10n.mediaImageUnavailable),
            ),
            loading: () => ColoredBox(
              color: context.theme.colors.secondary,
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: FCircularProgress(),
                ),
              ),
            ),
            error: (_, _) =>
                _UnavailableImage(label: context.l10n.mediaImageUnavailable),
          ),
    ),
  );
}

class _UnavailableImage extends StatelessWidget {
  const _UnavailableImage({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.theme.colors.secondary,
    child: Center(
      child: Tooltip(
        message: label,
        child: Icon(
          FLucideIcons.imageOff,
          size: 22,
          color: context.theme.colors.mutedForeground,
          semanticLabel: label,
        ),
      ),
    ),
  );
}

class ImageUploadField extends ConsumerStatefulWidget {
  const ImageUploadField({
    required this.value,
    required this.onChange,
    this.label,
    this.previewUrl,
    this.removable = true,
    super.key,
  });
  final int? value;
  final ValueChanged<int?> onChange;
  final String? label;
  final String? previewUrl;
  final bool removable;
  @override
  ConsumerState<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends ConsumerState<ImageUploadField> {
  bool busy = false;
  String? error;

  Future<void> choose() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final selection = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (selection == null) return;
      final file = selection.files.single;
      if (!mounted) return;
      if (file.size > 10 * 1024 * 1024) {
        setState(() => error = context.l10n.mediaFileTooLarge);
        return;
      }
      if (file.bytes == null) return;
      final saved = await withUploadProgress(
        context,
        () => ref.read(mediaRepositoryProvider).upload(file.name, file.bytes!),
      );
      if (mounted) widget.onChange(saved['id'] as int);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
        ],
        if (widget.value != null || widget.previewUrl != null) ...[
          GestureDetector(
            onTap: widget.value == null
                ? null
                : () => previewImage(context, widget.value!),
            child: widget.value != null
                ? ProtectedImage(
                    attachmentId: widget.value!,
                    width: 180,
                    height: 130,
                    borderRadius: BorderRadius.circular(8),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.previewUrl!,
                      width: 180,
                      height: 130,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FButton(
              size: .sm,
              variant: .outline,
              mainAxisSize: MainAxisSize.min,
              onPress: busy ? null : choose,
              prefix: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: FCircularProgress(),
                    )
                  : const Icon(FLucideIcons.imagePlus, size: 16),
              child: Text(
                widget.value == null && widget.previewUrl == null
                    ? context.l10n.mediaChoosePhoto
                    : context.l10n.mediaChangePhoto,
              ),
            ),
            if ((widget.value != null || widget.previewUrl != null) &&
                widget.removable)
              FButton(
                size: .sm,
                variant: .ghost,
                mainAxisSize: MainAxisSize.min,
                onPress: busy ? null : () => widget.onChange(null),
                child: Text(context.l10n.mediaRemovePhoto),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.mediaUploadHint,
          style: TextStyle(
            fontSize: 12,
            color: context.theme.colors.mutedForeground,
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error!,
              style: TextStyle(color: context.theme.colors.error),
            ),
          ),
      ],
    ),
  );
}

Future<void> previewImage(BuildContext context, int id, {String? path}) =>
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: context.theme.colors.background,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(context.l10n.mediaPreview)),
                    FButton.icon(
                      variant: .ghost,
                      semanticsLabel: context.l10n.commonClose,
                      onPress: () => Navigator.pop(context),
                      child: const Icon(FLucideIcons.x, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: InteractiveViewer(
                    child: ProtectedImage(
                      attachmentId: id,
                      downloadPath: path,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: 540,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FileDownloadButton(id, path: path),
              ],
            ),
          ),
        ),
      ),
    );

class FileDownloadButton extends ConsumerStatefulWidget {
  const FileDownloadButton(this.id, {this.filename, this.path, super.key});
  final int id;
  final String? filename, path;
  @override
  ConsumerState<FileDownloadButton> createState() => _FileDownloadButtonState();
}

class _FileDownloadButtonState extends ConsumerState<FileDownloadButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => FButton(
    variant: .outline,
    size: .sm,
    mainAxisSize: MainAxisSize.min,
    onPress: busy
        ? null
        : () async {
            setState(() => busy = true);
            try {
              final file = await ref
                  .read(mediaRepositoryProvider)
                  .download(widget.id, path: widget.path);
              if (!context.mounted) return;
              await FilePicker.platform.saveFile(
                fileName: widget.filename ?? file.filename,
                bytes: file.bytes,
                dialogTitle: context.l10n.mediaDownload,
              );
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$error')));
              }
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
    prefix: busy
        ? const SizedBox(width: 14, height: 14, child: FCircularProgress())
        : const Icon(FLucideIcons.download, size: 15),
    child: Flexible(
      child: Text(
        widget.filename ?? context.l10n.mediaDownload,
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class AttachmentGallery extends ConsumerWidget {
  const AttachmentGallery({
    required this.attachmentIds,
    this.imagesOnly = false,
    super.key,
  });
  final List<int> attachmentIds;
  final bool imagesOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: attachmentIds
        .toSet()
        .map(
          (id) => ref
              .watch(mediaMetadataProvider(id))
              .when(
                loading: () => const SizedBox(
                  width: 24,
                  height: 24,
                  child: FCircularProgress(),
                ),
                error: (_, _) => Text(context.l10n.mediaImageUnavailable),
                data: (metadata) {
                  final image = (metadata['mime_type'] as String? ?? '')
                      .startsWith('image/');
                  if (!image) {
                    return imagesOnly
                        ? const SizedBox.shrink()
                        : FileDownloadButton(
                            id,
                            filename: metadata['filename'] as String?,
                          );
                  }
                  return Semantics(
                    button: true,
                    label: context.l10n.mediaPreview,
                    child: InkWell(
                      onTap: () => previewImage(context, id),
                      child: ProtectedImage(
                        attachmentId: id,
                        width: 160,
                        height: 120,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
              ),
        )
        .toList(),
  );
}
