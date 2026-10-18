import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../shared/models/models.dart';

String aiPolicyLabel(BuildContext context, AiPolicy policy) => switch (policy) {
  AiPolicy.noAi => context.l10n.aiPolicyNoAi,
  AiPolicy.consultation => context.l10n.aiPolicyConsultation,
  AiPolicy.allowed => context.l10n.aiPolicyAllowed,
};

String aiUsageLabel(BuildContext context, AiUsage usage) => switch (usage) {
  AiUsage.noAi => context.l10n.aiUsageNoAi,
  AiUsage.consultation => context.l10n.aiUsageConsultation,
  AiUsage.assisted => context.l10n.aiUsageAssisted,
};

Map<String, String> aiPolicyOptions(BuildContext context) => {
  for (final policy in AiPolicy.values)
    policy.code: aiPolicyLabel(context, policy),
};

Map<String, String> aiUsageOptions(
  BuildContext context, {
  AiPolicy policy = AiPolicy.allowed,
}) => {
  for (final usage in policy.permittedUsages)
    usage.code: aiUsageLabel(context, usage),
};
