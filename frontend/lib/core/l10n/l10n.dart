import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';
export 'language_picker.dart';
export 'locale_provider.dart';

extension LocalizedContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  ...FLocalizations.localizationsDelegates,
];

String localizedDate(BuildContext context, dynamic value) {
  final date = value is DateTime ? value : DateTime.tryParse('$value');
  return date == null
      ? '—'
      : DateFormat(
          'd MMM',
          Localizations.localeOf(context).languageCode,
        ).format(date.toLocal());
}

String statusLabel(BuildContext context, String status) {
  final t = context.l10n;
  return switch (status) {
    'published' => t.statusPublished,
    'assigned' => t.statusAssigned,
    'in_progress' => t.statusInProgress,
    'submitted' => t.statusSubmitted,
    'revision_requested' => t.statusRevisionRequested,
    'accepted_pending_review' => t.statusAcceptedPendingReview,
    'completed' => t.statusCompleted,
    'cancelled' => t.statusCancelled,
    'disputed' || 'dispute' => t.statusDisputed,
    'pending' => t.statusPending,
    'accepted' => t.statusAccepted,
    'rejected' => t.statusRejected,
    'withdrawn' => t.statusWithdrawn,
    'in_review' => t.statusInReview,
    'resolved' => t.statusResolved,
    'private' => t.visibilityPrivate,
    'anonymous' => t.visibilityAnonymous,
    'public' => t.visibilityPublic,
    'created' => t.eventCreated,
    'start' => t.eventStart,
    'accept' => t.eventAccept,
    'request_revision' => t.eventRequestRevision,
    'cancel' => t.eventCancel,
    'customer_review' => t.eventCustomerReview,
    'performer_review' => t.eventPerformerReview,
    'dispute_resolved' => t.eventDisputeResolved,
    _ => status,
  };
}

String categoryLabel(BuildContext context, String slug, {String? fallback}) {
  final t = context.l10n;
  return switch (slug) {
    'development' || 'programming' => t.categoryProgramming,
    'design' => t.categoryDesign,
    'video' => t.categoryVideo,
    'text' || 'texts' || 'writing' || 'copywriting' => t.categoryWriting,
    'data' => t.categoryData,
    'marketing' => t.categoryMarketing,
    'illustration' => t.categoryIllustration,
    'other' => t.categoryOther,
    _ => fallback ?? t.categoryOther,
  };
}

String contentTypeLabel(BuildContext context, String type) => switch (type) {
  'user' => context.l10n.contentUser,
  'task' => context.l10n.contentTask,
  'order' => context.l10n.contentOrder,
  'message' => context.l10n.contentMessage,
  'review' => context.l10n.contentReview,
  'portfolio' => context.l10n.contentPortfolio,
  'report' => context.l10n.contentReport,
  _ => context.l10n.contentOther,
};

String moderationLabel(BuildContext context, String action) => switch (action) {
  'block' => context.l10n.userBlocked,
  'unblock' => context.l10n.auditUnblocked,
  'hide' => context.l10n.auditHidden,
  'unhide' => context.l10n.auditRestored,
  'evidence_access' => context.l10n.auditEvidenceAccess,
  'attachment_access' => context.l10n.auditAttachmentAccess,
  'dispute_cancel' => context.l10n.auditDisputeCancelled,
  'dispute_resume' => context.l10n.auditDisputeResumed,
  final String code when code.startsWith('report_') =>
    context.l10n.auditReportStatus(statusLabel(context, code.substring(7))),
  _ => context.l10n.actionDefault,
};
