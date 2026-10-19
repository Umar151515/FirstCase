import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/ui.dart';

String telegramChatPath(int orderId) => '/orders/$orderId/telegram';

String normalizeTelegramUsername(String value) => value
    .trim()
    .replaceFirst(RegExp(r'^(https://)?t\.me/'), '')
    .replaceFirst(RegExp(r'^@'), '');

Future<void> openTelegramChat(BuildContext context, String username) async {
  final opened = await launchUrl(
    Uri.https('t.me', '/$username'),
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    throw Exception(context.l10n.chatTelegramLaunchFailed);
  }
}

class TelegramChatAction extends ConsumerWidget {
  const TelegramChatAction(
    this.orderId, {
    this.readOnly = false,
    this.compact = false,
    super.key,
  });
  final int orderId;
  final bool readOnly;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resourceProvider(telegramChatPath(orderId)));
    final invite = state.value;
    final pending = invite is Map && invite['status'] == 'pending';
    final accepted = invite is Map && invite['status'] == 'accepted';
    return FButton(
      size: .sm,
      variant: .outline,
      mainAxisSize: MainAxisSize.min,
      semanticsLabel: pending
          ? context.l10n.chatTelegramPending
          : accepted
          ? context.l10n.chatTelegramOpen
          : context.l10n.chatTelegramPropose,
      onPress: (readOnly && !pending) || (state.isLoading && !state.hasValue)
          ? null
          : () async {
              if (state.hasError) {
                ref.invalidate(resourceProvider(telegramChatPath(orderId)));
                return;
              }
              if (pending) {
                await showTelegramInvite(context, orderId, readOnly: readOnly);
              } else if (accepted) {
                try {
                  await openTelegramChat(
                    context,
                    invite['peer_username'] as String,
                  );
                } catch (error) {
                  if (context.mounted) feedback(context, '$error', error: true);
                }
              } else {
                await modal(context, TelegramContactForm(orderId));
              }
            },
      prefix: Icon(pending ? FLucideIcons.clock3 : FLucideIcons.send, size: 15),
      child: compact
          ? const SizedBox.shrink()
          : Flexible(child: Text(context.l10n.chatTelegram)),
    );
  }
}

Future<dynamic> showTelegramInvite(
  BuildContext context,
  int orderId, {
  bool readOnly = false,
}) => modal(
  context,
  Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      PageTitle(context.l10n.chatTelegram),
      TelegramInviteDetails(orderId, readOnly: readOnly),
      const SizedBox(height: 16),
      FButton(
        variant: .ghost,
        onPress: () => Navigator.pop(context),
        child: Flexible(child: Text(context.l10n.back)),
      ),
    ],
  ),
);

class TelegramInviteBanner extends ConsumerWidget {
  const TelegramInviteBanner(this.orderId, {this.readOnly = false, super.key});
  final int orderId;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = telegramChatPath(orderId);
    final state = ref.watch(resourceProvider(path));
    final invite = state.value;
    if (invite is! Map || !['pending', 'accepted'].contains(invite['status'])) {
      if (!state.hasError) return const SizedBox.shrink();
      return Material(
        color: context.theme.colors.muted,
        child: InkWell(
          onTap: () => ref.invalidate(resourceProvider(path)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              context.l10n.chatTelegramUnavailable,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: quiet(context)),
            ),
          ),
        ),
      );
    }
    final pending = invite['status'] == 'pending';
    final own = invite['requested_by'] == ref.watch(sessionProvider).value?.id;
    final l = context.l10n;
    final label = pending
        ? (own ? l.chatTelegramPending : l.chatTelegramIncoming)
        : l.chatTelegramAccepted;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => showTelegramInvite(context, orderId, readOnly: readOnly),
      child: Material(
        color: context.theme.colors.primary.withValues(alpha: .045),
        child: InkWell(
          key: const ValueKey('telegram-invite-notice'),
          onTap: () => showTelegramInvite(context, orderId, readOnly: readOnly),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: edge(context))),
            ),
            child: Row(
              children: [
                Icon(
                  pending ? FLucideIcons.clock3 : FLucideIcons.check,
                  size: 14,
                  color: quiet(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: quiet(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  FLucideIcons.chevronRight,
                  size: 15,
                  color: quiet(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TelegramInviteDetails extends ConsumerWidget {
  const TelegramInviteDetails(this.orderId, {this.readOnly = false, super.key});
  final int orderId;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = telegramChatPath(orderId);
    return ref
        .watch(resourceProvider(path))
        .when(
          skipLoadingOnRefresh: true,
          loading: () => const SizedBox.shrink(),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.chatTelegramUnavailable,
                    style: TextStyle(fontSize: 12, color: quiet(context)),
                  ),
                ),
                FButton.icon(
                  variant: .ghost,
                  semanticsLabel: context.l10n.retry,
                  onPress: () => ref.invalidate(resourceProvider(path)),
                  child: const Icon(FLucideIcons.rotateCw, size: 15),
                ),
              ],
            ),
          ),
          data: (data) {
            if (data is! Map) return const SizedBox.shrink();
            final invite = Map<String, dynamic>.from(data);
            final own =
                invite['requested_by'] == ref.watch(sessionProvider).value?.id;
            final status = invite['status'];
            final pending = status == 'pending';
            final accepted = status == 'accepted';
            final l = context.l10n;
            Future<void> respond(String action) async {
              await ref
                  .read(taskRepositoryProvider)
                  .mutate(
                    '$path/${invite['id']}/respond',
                    data: {'action': action},
                  );
              ref.invalidate(resourceProvider(path));
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: context.theme.colors.primary.withValues(alpha: .045),
                border: Border(bottom: BorderSide(color: edge(context))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pending
                        ? (own ? l.chatTelegramPending : l.chatTelegramIncoming)
                        : accepted
                        ? l.chatTelegramAccepted
                        : status == 'declined'
                        ? l.chatTelegramDeclined
                        : l.chatTelegramCancelled,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (pending && own) ...[
                    const SizedBox(height: 6),
                    Text(
                      l.chatTelegramWaiting,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: quiet(context),
                      ),
                    ),
                  ],
                  if (pending || accepted) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (pending && !own) ...[
                          if (!readOnly)
                            FButton(
                              size: .sm,
                              mainAxisSize: MainAxisSize.min,
                              onPress: () => modal(
                                context,
                                TelegramContactForm(
                                  orderId,
                                  inviteId: invite['id'] as int,
                                ),
                              ),
                              child: Flexible(
                                child: Text(l.chatTelegramAccept),
                              ),
                            ),
                          ActionButton(
                            l.chatTelegramDecline,
                            secondary: true,
                            action: () => respond('decline'),
                          ),
                        ] else if (pending)
                          ActionButton(
                            l.chatTelegramWithdraw,
                            secondary: true,
                            action: () => respond('cancel'),
                          ),
                        if (accepted) ...[
                          ActionButton(
                            l.chatTelegramOpen,
                            icon: FLucideIcons.arrowUpRight,
                            action: () => openTelegramChat(
                              context,
                              invite['peer_username'] as String,
                            ),
                          ),
                          ActionButton(
                            l.chatTelegramCancel,
                            secondary: true,
                            action: () => respond('cancel'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
  }
}

class TelegramContactForm extends ConsumerStatefulWidget {
  const TelegramContactForm(this.orderId, {this.inviteId, super.key});
  final int orderId;
  final int? inviteId;
  @override
  ConsumerState<TelegramContactForm> createState() =>
      _TelegramContactFormState();
}

class _TelegramContactFormState extends ConsumerState<TelegramContactForm> {
  final form = GlobalKey<FormState>();
  late final username = TextEditingController(
    text: ref.read(sessionProvider).value?.json['username'] as String? ?? '',
  );
  @override
  void dispose() {
    username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final accepting = widget.inviteId != null;
    return Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PageTitle(l.chatTelegramTitle, subtitle: l.chatTelegramIntro),
          Field(
            l.chatTelegramUsername,
            username,
            hint: l.chatTelegramUsernameHint,
            validator: (value) =>
                RegExp(r'^[A-Za-z][A-Za-z0-9_]{2,31}$')
                    .hasMatch(normalizeTelegramUsername(value ?? ''))
                ? null
                : l.chatTelegramInvalid,
          ),
          Text(
            l.chatTelegramNote,
            style: TextStyle(fontSize: 12, height: 1.6, color: quiet(context)),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ActionButton(
                accepting ? l.chatTelegramAccept : l.chatTelegramSend,
                icon: FLucideIcons.send,
                action: () async {
                  if (!form.currentState!.validate()) return;
                  final path = telegramChatPath(widget.orderId);
                  final contact = normalizeTelegramUsername(username.text);
                  await ref
                      .read(taskRepositoryProvider)
                      .mutate(
                        accepting ? '$path/${widget.inviteId}/respond' : path,
                        data: accepting
                            ? {'action': 'accept', 'username': contact}
                            : {'username': contact},
                      );
                  if (!context.mounted) return;
                  ref.invalidate(resourceProvider(path));
                  Navigator.pop(context);
                },
              ),
              FButton(
                variant: .ghost,
                mainAxisSize: MainAxisSize.min,
                onPress: () => Navigator.pop(context),
                child: Flexible(child: Text(l.back)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
