import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/providers.dart';
import 'ui.dart';

class AttachmentButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) => ActionButton(
    filename ?? 'Файл #$id',
    secondary: true,
    icon: FLucideIcons.download,
    action: () async {
      final file = await ref.read(apiProvider).download(id, path: path);
      final bytes = file.bytes;
      if (image && context.mounted) {
        await modal(
          context,
          Column(
            children: [
              Image.memory(bytes),
              const SizedBox(height: 16),
              const Text(
                'Чаевые добровольны. FirstCase не принимает и не подтверждает переводы.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.6),
              ),
            ],
          ),
        );
      } else {
        await FilePicker.platform.saveFile(
          fileName: filename ?? file.filename,
          bytes: bytes,
          dialogTitle: 'Сохранить вложение',
        );
      }
    },
  );
}
