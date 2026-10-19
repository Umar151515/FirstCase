import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/media.dart';
import '../../../shared/widgets/ui.dart';
import 'telegram_invite.dart';

class ChatPanel extends ConsumerStatefulWidget {
  const ChatPanel(this.orderId, {this.peer, this.readOnly = false, super.key});
  final int orderId;
  final Person? peer;
  final bool readOnly;
  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  final text = TextEditingController();
  final scroll = ScrollController();
  final composerFocus = FocusNode();
  final Map<int, Json> known = {};
  final List<Json> attachments = [];
  Timer? polling;
  Timer? draftSave;
  bool atBottom = true;
  bool sending = false;
  bool uploading = false;
  bool loadingOlder = false;
  bool refreshing = false;
  int newestId = -1;
  String get path => '/orders/${widget.orderId}/messages?limit=50&latest=true';
  String get draftKey => 'chat_draft:${widget.orderId}';

  @override
  void initState() {
    super.initState();
    text.addListener(onTextChanged);
    scroll.addListener(() {
      if (!scroll.hasClients) return;
      final near = scroll.position.extentAfter < 80;
      if (near != atBottom && mounted) setState(() => atBottom = near);
    });
    polling = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      refreshMessages();
    });
    Future.microtask(() async {
      final saved = await ref.read(databaseProvider).read(draftKey);
      if (mounted && text.text.isEmpty && saved is String) text.text = saved;
    });
  }

  Future<void> refreshMessages() async {
    if (refreshing || !mounted) return;
    refreshing = true;
    try {
      if (newestId > 0 && known.isNotEmpty) {
        var after = known.keys.reduce((a, b) => a > b ? a : b);
        while (mounted) {
          final data = await ref
              .read(taskRepositoryProvider)
              .resource(
                '/orders/${widget.orderId}/messages?after_id=$after&limit=100',
              );
          if (!mounted) return;
          final incoming = items(data);
          if (incoming.isEmpty) break;
          final follow = atBottom;
          setState(() {
            for (final message in incoming) {
              known[message['id'] as int] = message;
            }
          });
          if (follow) toLatest();
          after = incoming.last['id'] as int;
          if (incoming.length >= (data['total'] as int)) break;
        }
      }
    } catch (_) {
      // The regular history refresh below exposes connection errors and retry.
    } finally {
      refreshing = false;
      if (mounted) {
        ref.invalidate(resourceProvider(path));
        ref.invalidate(resourceProvider(telegramChatPath(widget.orderId)));
      }
    }
  }

  void onTextChanged() {
    if (!mounted) return;
    setState(() {});
    draftSave?.cancel();
    final value = text.text;
    draftSave = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(databaseProvider).write(draftKey, value, personal: true);
      }
    });
  }

  @override
  void dispose() {
    polling?.cancel();
    draftSave?.cancel();
    text.removeListener(onTextChanged);
    text.dispose();
    scroll.dispose();
    composerFocus.dispose();
    super.dispose();
  }

  void toLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void insertNewLine() {
    if (sending) return;
    final selection = text.selection;
    final start = selection.isValid ? selection.start : text.text.length;
    final end = selection.isValid ? selection.end : text.text.length;
    text.value = TextEditingValue(
      text: text.text.replaceRange(start, end, '\n'),
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  Future<void> loadOlder() async {
    if (known.isEmpty || loadingOlder) return;
    final oldest = known.keys.reduce((a, b) => a < b ? a : b);
    final previousExtent = scroll.hasClients
        ? scroll.position.maxScrollExtent
        : 0.0;
    final previousOffset = scroll.hasClients ? scroll.offset : 0.0;
    setState(() => loadingOlder = true);
    try {
      final page = await ref
          .read(taskRepositoryProvider)
          .resource(
            '/orders/${widget.orderId}/messages?limit=50&latest=true&before_id=$oldest',
          );
      if (!mounted) return;
      setState(() {
        for (final message in items(page)) {
          known[message['id'] as int] = message;
        }
        loadingOlder = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !scroll.hasClients) return;
        scroll.jumpTo(
          (previousOffset + scroll.position.maxScrollExtent - previousExtent)
              .clamp(0, scroll.position.maxScrollExtent),
        );
      });
    } catch (error) {
      if (mounted) {
        setState(() => loadingOlder = false);
        feedback(context, '$error', error: true);
      }
    }
  }

  Future<void> attach() async {
    if (uploading || sending || widget.readOnly) return;
    setState(() => uploading = true);
    try {
      final selection = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf', 'txt', 'zip'],
      );
      if (selection == null || !mounted) return;
      if (attachments.length + selection.files.length > 10) {
        throw Exception(context.l10n.chatTooManyAttachments);
      }
      for (final file in selection.files) {
        if (!mounted) return;
        if (file.size > 10 * 1024 * 1024) {
          throw Exception(context.l10n.mediaFileTooLarge);
        }
        if (file.bytes == null) continue;
        final saved = await ref
            .read(mediaRepositoryProvider)
            .upload(file.name, file.bytes!);
        if (!mounted) return;
        setState(() => attachments.add(saved));
      }
    } catch (error) {
      if (mounted) feedback(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> send() async {
    if (sending ||
        uploading ||
        widget.readOnly ||
        (text.text.trim().isEmpty && attachments.isEmpty)) {
      return;
    }
    draftSave?.cancel();
    final database = ref.read(databaseProvider);
    final api = ref.read(apiProvider);
    final epoch = api.identityEpoch;
    setState(() => sending = true);
    try {
      final saved = await ref
          .read(taskRepositoryProvider)
          .mutate(
            '/orders/${widget.orderId}/messages',
            data: {
              'text': text.text.trim(),
              'attachment_ids': attachments.map((f) => f['id'] as int).toList(),
            },
          );
      if (api.identityEpoch != epoch) return;
      await database.write(draftKey, '', personal: true);
      if (!mounted) return;
      setState(() {
        known[saved['id'] as int] = Map<String, dynamic>.from(saved as Map);
        attachments.clear();
        text.clear();
        atBottom = true;
      });
      ref.invalidate(resourceProvider(path));
      toLatest();
      composerFocus.requestFocus();
    } catch (error) {
      if (mounted) feedback(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mobile = MediaQuery.sizeOf(context).width < 650;
    final user = ref.watch(sessionProvider).value;
    final messages = ref.watch(resourceProvider(path));
    final historyHeight =
        (MediaQuery.sizeOf(context).height * (mobile ? .45 : .5)).clamp(
          300.0,
          520.0,
        );
    return Container(
      decoration: BoxDecoration(
        color: paper(context),
        border: Border.all(color: edge(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(mobile ? 16 : 22),
            child: Row(
              children: [
                if (widget.peer != null)
                  PersonAvatar(widget.peer!, size: 38)
                else
                  Icon(
                    FLucideIcons.messagesSquare,
                    size: 24,
                    color: context.theme.colors.primary,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.peer?.name ?? l.chatTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.chatWith,
                        style: TextStyle(fontSize: 11, color: quiet(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TelegramChatAction(
                  widget.orderId,
                  readOnly: widget.readOnly,
                  compact:
                      MediaQuery.sizeOf(context).width < 360 ||
                      MediaQuery.textScalerOf(context).scale(14) > 18,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: edge(context)),
          TelegramInviteBanner(widget.orderId, readOnly: widget.readOnly),
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) {
              if (notification.depth == 0 && atBottom && !loadingOlder) {
                toLatest();
              }
              return false;
            },
            child: SizedBox(
              height: historyHeight,
              child: ColoredBox(
                color: surface(context),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: messages.when(
                        skipLoadingOnRefresh: true,
                        data: (data) {
                          final latest = items(data);
                          final lastId = latest.isEmpty
                              ? 0
                              : latest.last['id'] as int;
                          final firstLoad = newestId == -1;
                          if (lastId != newestId) {
                            newestId = lastId;
                            if (firstLoad || atBottom) toLatest();
                          }
                          for (final message in latest) {
                            known[message['id'] as int] = message;
                          }
                          final list = known.values.toList()
                            ..sort(
                              (a, b) =>
                                  (a['id'] as int).compareTo(b['id'] as int),
                            );
                          if (list.isEmpty) {
                            return StateMessage(
                              l.chatEmpty,
                              subtitle: l.chatEmptyHint,
                              icon: FLucideIcons.messagesSquare,
                            );
                          }
                          return ListView(
                            key: const ValueKey('chat-messages'),
                            controller: scroll,
                            padding: EdgeInsets.fromLTRB(
                              mobile ? 12 : 24,
                              12,
                              mobile ? 12 : 24,
                              22,
                            ),
                            children: [
                              if (list.length < (data['total'] as int))
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: FButton(
                                      size: .sm,
                                      variant: .ghost,
                                      mainAxisSize: MainAxisSize.min,
                                      onPress: loadingOlder ? null : loadOlder,
                                      prefix: loadingOlder
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: FCircularProgress(),
                                            )
                                          : const Icon(
                                              FLucideIcons.chevronUp,
                                              size: 14,
                                            ),
                                      child: Flexible(child: Text(l.chatOlder)),
                                    ),
                                  ),
                                ),
                              for (var i = 0; i < list.length; i++) ...[
                                if (i == 0 || !_sameDay(list[i - 1], list[i]))
                                  _DateDivider(
                                    DateTime.parse(
                                      list[i]['created_at'] as String,
                                    ).toLocal(),
                                  ),
                                _MessageBubble(
                                  list[i],
                                  own: list[i]['author_id'] == user?.id,
                                  grouped:
                                      i > 0 &&
                                      list[i - 1]['author_id'] ==
                                          list[i]['author_id'] &&
                                      _sameDay(list[i - 1], list[i]),
                                ),
                              ],
                            ],
                          );
                        },
                        loading: () => const Center(child: FCircularProgress()),
                        error: (error, _) => StateMessage(
                          l.chatUnavailable,
                          subtitle: '$error',
                          action: FButton(
                            onPress: () =>
                                ref.invalidate(resourceProvider(path)),
                            child: Flexible(child: Text(l.retry)),
                          ),
                        ),
                      ),
                    ),
                    if (!atBottom)
                      Positioned(
                        bottom: 12,
                        left: 16,
                        right: 16,
                        child: Center(
                          child: FButton(
                            size: .sm,
                            mainAxisSize: MainAxisSize.min,
                            onPress: toLatest,
                            prefix: const Icon(
                              FLucideIcons.arrowDown,
                              size: 14,
                            ),
                            child: Flexible(child: Text(l.chatLatest)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: edge(context)),
          if (widget.readOnly)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                l.chatCancelled,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: quiet(context),
                ),
              ),
            )
          else ...[
            if (attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final file in attachments)
                      Container(
                        constraints: const BoxConstraints(maxWidth: 230),
                        padding: const EdgeInsets.only(left: 10),
                        decoration: BoxDecoration(
                          color: context.theme.colors.muted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FLucideIcons.file,
                              size: 13,
                              color: quiet(context),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                file['filename'] as String? ??
                                    l.mediaFileLabel(file['id'] as int),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            FButton.icon(
                              variant: .ghost,
                              semanticsLabel: l.chatRemoveAttachment,
                              onPress: sending || uploading
                                  ? null
                                  : () => setState(
                                      () => attachments.remove(file),
                                    ),
                              child: const Icon(FLucideIcons.x, size: 13),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                mobile ? 8 : 16,
                14,
                mobile ? 8 : 16,
                8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FButton.icon(
                    variant: .ghost,
                    semanticsLabel: l.chatAttach,
                    onPress: sending || uploading ? null : attach,
                    child: uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: FCircularProgress(),
                          )
                        : const Icon(FLucideIcons.paperclip, size: 20),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: CallbackShortcuts(
                      bindings: mobile
                          ? {}
                          : {
                              const SingleActivator(LogicalKeyboardKey.enter):
                                  send,
                              const SingleActivator(
                                LogicalKeyboardKey.enter,
                                shift: true,
                              ): insertNewLine,
                            },
                      child: FTextField(
                        focusNode: composerFocus,
                        control: .managed(controller: text),
                        hint: l.chatMessageHint,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        readOnly: sending,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FButton.icon(
                    semanticsLabel: l.send,
                    onPress:
                        sending ||
                            uploading ||
                            (text.text.trim().isEmpty && attachments.isEmpty)
                        ? null
                        : send,
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: FCircularProgress(),
                          )
                        : const Icon(FLucideIcons.arrowUp, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(mobile ? 16 : 22, 0, 16, 14),
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        FLucideIcons.lockKeyhole,
                        size: 10,
                        color: quiet(context),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          l.chatPrivacyHint,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.5,
                            color: quiet(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!mobile)
                    Text(
                      l.chatKeyboardHint,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.5,
                        color: quiet(context),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

bool _sameDay(Json a, Json b) {
  final first = DateTime.parse(a['created_at'] as String).toLocal();
  final second = DateTime.parse(b['created_at'] as String).toLocal();
  return DateUtils.isSameDay(first, second);
}

class _DateDivider extends StatelessWidget {
  const _DateDivider(this.date);
  final DateTime date;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = DateUtils.isSameDay(date, now)
        ? context.l10n.chatToday
        : DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))
        ? context.l10n.chatYesterday
        : DateFormat(
            'd MMMM',
            Localizations.localeOf(context).languageCode,
          ).format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: quiet(context)),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble(
    this.message, {
    required this.own,
    required this.grouped,
  });
  final Json message;
  final bool own;
  final bool grouped;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final author = Person(
        Map<String, dynamic>.from(message['author'] as Map),
      );
      final primary = context.theme.colors.primary;
      return Padding(
        padding: EdgeInsets.only(top: grouped ? 4 : 12),
        child: Align(
          alignment: own ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  constraints.maxWidth *
                  (constraints.maxWidth < 500 ? .92 : .78),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!own) ...[
                  grouped
                      ? const SizedBox(width: 26)
                      : PersonAvatar(author, size: 26),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
                    decoration: BoxDecoration(
                      color: own
                          ? primary.withValues(alpha: .10)
                          : paper(context),
                      border: own
                          ? null
                          : Border.all(
                              color: edge(context).withValues(alpha: .65),
                            ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(own ? 12 : 3),
                        bottomRight: Radius.circular(own ? 3 : 12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!own && !grouped) ...[
                          Text(
                            author.name,
                            style: TextStyle(
                              fontSize: 11,
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        if ((message['text'] as String? ?? '').isNotEmpty)
                          SelectableText(
                            message['text'] as String,
                            style: const TextStyle(fontSize: 14, height: 1.6),
                          ),
                        if ((message['attachment_ids'] as List? ?? [])
                            .isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: AttachmentGallery(
                              attachmentIds: List<int>.from(
                                message['attachment_ids'] as List,
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(
                                DateTime.parse(message['created_at'] as String)
                                    .toLocal(),
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                color: quiet(context),
                              ),
                            ),
                            const SizedBox(width: 5),
                            if (own)
                              Icon(
                                FLucideIcons.check,
                                size: 12,
                                color: quiet(context),
                                semanticLabel: context.l10n.chatSent,
                              )
                            else
                              SizedBox(
                                height: 26,
                                width: 28,
                                child: FButton.icon(
                                  variant: .ghost,
                                  semanticsLabel: context.l10n.report,
                                  onPress: () => modal(
                                    context,
                                    ReportForm('message', message['id'] as int),
                                  ),
                                  child: Icon(
                                    FLucideIcons.flag,
                                    size: 11,
                                    color: quiet(context),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
