import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';

import '../../core/l10n/l10n.dart';

class Brand extends StatelessWidget {
  const Brand({this.width = 142, this.mark = false, super.key});
  final double width;
  final bool mark;

  @override
  Widget build(BuildContext context) {
    final dark = context.theme.colors.brightness == Brightness.dark;
    final variant = dark ? 'dark' : 'light';
    return Image.asset(
      'assets/brand/${mark ? 'mark' : 'wordmark'}-$variant.png',
      width: width,
      height: mark ? width : width / 3,
      fit: BoxFit.contain,
      semanticLabel: context.l10n.appName,
    );
  }
}

class BrandLoading extends StatelessWidget {
  const BrandLoading({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.brandLoading,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: const Brand(width: 64, mark: true),
        ),
        const SizedBox(height: 20),
        const SizedBox(width: 20, height: 20, child: FCircularProgress()),
      ],
    ),
  );
}
