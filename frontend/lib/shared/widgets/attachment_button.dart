import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import 'media.dart';
import 'ui.dart';

class AttachmentButton extends StatelessWidget {
  const AttachmentButton(
    this.id, {
    this.filename,
    this.image = false,
    this.path,
    super.key,
  });
  final int id;
  final String? filename;
  final bool image;
  final String? path;
  @override
  Widget build(BuildContext context) => image
      ? ActionButton(
          filename ?? context.l10n.mediaPreview,
          secondary: true,
          action: () => previewImage(context, id, path: path),
        )
      : FileDownloadButton(id, filename: filename, path: path);
}
