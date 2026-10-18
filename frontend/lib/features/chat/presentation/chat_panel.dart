import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../../shared/widgets/attachment_button.dart';

class ChatPanel extends ConsumerStatefulWidget {
  const ChatPanel(this.orderId, {super.key});
  final int orderId;
  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  final text = TextEditingController();
  final scroll = ScrollController();
  Timer? polling;
  Timer? draftSave;
  List<int> attachments = [];
  int limit = 50;
  int offset = 0;
  bool followLatest = true;
  int lastCount = -1;
  int uploadVersion = 0;
  String get path =>
      '/orders/${widget.orderId}/messages?limit=$limit&offset=$offset';
  String get draftKey => 'chat_draft:${widget.orderId}';
  @override
  void initState() {
    super.initState();
    polling = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) ref.invalidate(resourceProvider(path));
    });
    Future.microtask(() async {
      final saved = await ref.read(databaseProvider).read(draftKey);
      if (saved is String && mounted) text.text = saved;
    });
  }

  @override
  void dispose() {
    polling?.cancel();
    draftSave?.cancel();
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  void saveDraft(String value) {
    draftSave?.cancel();
    draftSave = Timer(
      const Duration(milliseconds: 500),
      () => ref.read(databaseProvider).write(draftKey, value, personal: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).value;
    final messages = ref.watch(resourceProvider(path));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(FLucideIcons.messagesSquare, size: 20, color: accent),
              SizedBox(width: 10),
              Text(
                'Рабочий чат',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              Spacer(),
              Tag('Личный', color: muted, icon: FLucideIcons.lockKeyhole),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Видят только участники заказа. Обновляется каждые 5 секунд.',
            style: TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 20),
          if (!followLatest)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FButton(
                variant: .outline,
                onPress: () => setState(() {
                  followLatest = true;
                  ref.invalidate(resourceProvider(path));
                }),
                child: const Text('К новым сообщениям ↓'),
              ),
            ),
          SizedBox(
            height: 350,
            child: messages.when(
              skipLoadingOnRefresh: true,
              data: (data) {
                final list = items(data);
                final latestOffset = ((data['total'] as int) - limit).clamp(
                  0,
                  1000000000,
                );
                if (followLatest && offset != latestOffset) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && followLatest) {
                      setState(() {
                        offset = latestOffset;
                        lastCount = -1;
                      });
                    }
                  });
                }
                if (lastCount != list.length) {
                  lastCount = list.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (scroll.hasClients) {
                      scroll.animateTo(
                        scroll.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }
                if (list.isEmpty) {
                  return const StateMessage(
                    'Начните разговор',
                    subtitle: 'Уточните детали и договоритесь о первом шаге.',
                    icon: FLucideIcons.messagesSquare,
                  );
                }
                return ListView(
                  controller: scroll,
                  children: [
                    for (final message in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Align(
                          alignment: message['author_id'] == user?.id
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 570),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: message['author_id'] == user?.id
                                  ? accent.withValues(alpha: .1)
                                  : edge(context).withValues(alpha: .5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${(message['author'] as Map)['display_name']}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if ('${message['text'] ?? ''}'.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: SelectableText(
                                      message['text'] as String,
                                      style: const TextStyle(
                                        height: 1.55,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                if ((message['attachment_ids'] as List? ?? [])
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Wrap(
                                      spacing: 7,
                                      runSpacing: 7,
                                      children:
                                          (message['attachment_ids'] as List)
                                              .map(
                                                (id) =>
                                                    AttachmentButton(id as int),
                                              )
                                              .toList(),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateFormat('HH:mm · d MMM', 'ru').format(
                                        DateTime.parse(
                                          message['created_at'] as String,
                                        ).toLocal(),
                                      ),
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 9,
                                      ),
                                    ),
                                    if (message['author_id'] != user?.id) ...[
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                        onTap: () => modal(
                                          context,
                                          ReportForm(
                                            'message',
                                            message['id'] as int,
                                          ),
                                        ),
                                        child: const Icon(
                                          FLucideIcons.flag,
                                          size: 11,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FButton(
                            variant: .outline,
                            mainAxisSize: MainAxisSize.min,
                            onPress: offset == 0
                                ? null
                                : () => setState(() {
                                    offset -= limit;
                                    if (offset < 0) offset = 0;
                                    followLatest = false;
                                    lastCount = -1;
                                  }),
                            child: const Text('Раньше'),
                          ),
                          const SizedBox(width: 12),
                          FButton(
                            variant: .outline,
                            mainAxisSize: MainAxisSize.min,
                            onPress:
                                offset + list.length >= (data['total'] as int)
                                ? null
                                : () => setState(() {
                                    offset += limit;
                                    followLatest =
                                        offset + limit >=
                                        (data['total'] as int);
                                    lastCount = -1;
                                  }),
                            child: const Text('Позже'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: FCircularProgress()),
              error: (e, _) => StateMessage(
                'Чат недоступен',
                subtitle: '$e',
                action: FButton(
                  onPress: () => ref.invalidate(resourceProvider(path)),
                  child: const Text('Повторить'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FTextField(
            control: .managed(
              controller: text,
              onChange: (v) => saveDraft(v.text),
            ),
            hint: 'Напишите сообщение…',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          UploadField(
            key: ValueKey(uploadVersion),
            onChange: (v) => attachments = v,
          ),
          ActionButton(
            'Отправить',
            icon: FLucideIcons.send,
            action: () async {
              if (text.text.trim().isEmpty && attachments.isEmpty) {
                throw Exception('Напишите сообщение или прикрепите файл');
              }
              await ref
                  .read(taskRepositoryProvider)
                  .mutate(
                    '/orders/${widget.orderId}/messages',
                    data: {
                      'text': text.text.trim(),
                      'attachment_ids': attachments,
                    },
                  );
              text.clear();
              attachments = [];
              await ref
                  .read(databaseProvider)
                  .write(draftKey, '', personal: true);
              ref.invalidate(resourceProvider(path));
              if (mounted) {
                setState(() {
                  uploadVersion++;
                  followLatest = true;
                });
              }
            },
          ),
        ],
      ),
    );
  }
}
