import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import 'l10n.dart';

class LanguagePicker extends ConsumerStatefulWidget {
  const LanguagePicker({this.compact = false, super.key});
  final bool compact;

  @override
  ConsumerState<LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends ConsumerState<LanguagePicker> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(localeProvider).languageCode;
    return Semantics(
      label: context.l10n.navLanguage,
      child: FButton(
        size: .sm,
        mainAxisSize: MainAxisSize.min,
        variant: .outline,
        onPress: busy
            ? null
            : () async {
                setState(() => busy = true);
                try {
                  await ref
                      .read(localeProvider.notifier)
                      .select(Locale(current == 'ru' ? 'ky' : 'ru'));
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.languageSyncFailed('$error'),
                        ),
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
        child: Flexible(
          child: Text(
            widget.compact
                ? (current == 'ru'
                      ? context.l10n.languageKyrgyzShort
                      : context.l10n.languageRussianShort)
                : (current == 'ru'
                      ? context.l10n.languageKyrgyz
                      : context.l10n.languageRussian),
          ),
        ),
      ),
    );
  }
}
