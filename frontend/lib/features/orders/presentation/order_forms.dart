import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';

class SubmitForm extends ConsumerStatefulWidget {
  const SubmitForm(this.id, {super.key});
  final int id;
  @override
  ConsumerState<SubmitForm> createState() => _SubmitFormState();
}

class _SubmitFormState extends ConsumerState<SubmitForm> {
  final form = GlobalKey<FormState>();
  final description = TextEditingController();
  final links = TextEditingController();
  List<int> files = [];
  @override
  void dispose() {
    description.dispose();
    links.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageTitle(
          'Момент «готово»',
          subtitle:
              'Расскажите о результате и приложите материалы для проверки.',
        ),
        Field('Что сделано', description, lines: 5, minLength: 10),
        Field(
          'Ссылки на результат · по одной на строку',
          links,
          lines: 2,
          required: false,
          validator: (value) =>
              parseLinks(value ?? '')
                  .any((link) => Uri.tryParse(link)?.scheme != 'https')
              ? 'Разрешены только HTTPS-ссылки'
              : null,
        ),
        UploadField(onChange: (v) => files = v),
        ActionButton(
          'Сдать работу на проверку',
          icon: FLucideIcons.send,
          action: () async {
            if (!form.currentState!.validate()) return;
            await mutate(
              ref,
              '/orders/${widget.id}/submit',
              data: {
                'description': description.text.trim(),
                'links': parseLinks(links.text),
                'attachment_ids': files,
              },
            );
            if (context.mounted) {
              Navigator.pop(context);
              feedback(context, 'Результат отправлен заказчику');
            }
          },
        ),
      ],
    ),
  );
}

List<String> parseLinks(String value) => value
    .split(RegExp(r'[\n,]'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

class RevisionForm extends ConsumerStatefulWidget {
  const RevisionForm(this.id, {super.key});
  final int id;
  @override
  ConsumerState<RevisionForm> createState() => _RevisionFormState();
}

class _RevisionFormState extends ConsumerState<RevisionForm> {
  final form = GlobalKey<FormState>();
  final reason = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageTitle(
          'Что нужно поправить?',
          subtitle:
              'Опишите изменения подробно и в пределах согласованного задания.',
        ),
        Field('Список правок', reason, minLength: 5, lines: 5),
        ActionButton(
          'Запросить правки',
          action: () async {
            if (!form.currentState!.validate()) return;
            await mutate(
              ref,
              '/orders/${widget.id}/request-revision',
              data: {'reason': reason.text.trim()},
            );
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}

class ReviewForm extends ConsumerStatefulWidget {
  const ReviewForm(this.id, {this.requiredComment = true, super.key});
  final int id;
  final bool requiredComment;
  @override
  ConsumerState<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<ReviewForm> {
  final form = GlobalKey<FormState>();
  final comment = TextEditingController();
  int rating = 5;
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          'Как всё прошло?',
          subtitle: widget.requiredComment
              ? 'Ваш отзыв завершит заказ и станет частью реальной репутации исполнителя.'
              : 'Поблагодарите заказчика за совместную работу. Это необязательно.',
        ),
        Row(
          children: List.generate(
            5,
            (i) => FButton.icon(
              variant: .ghost,
              onPress: () => setState(() => rating = i + 1),
              child: Icon(
                FLucideIcons.star,
                size: 32,
                color: i < rating ? const Color(0xFFEAB548) : muted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Field(
          'Ваш отзыв',
          comment,
          lines: 4,
          required: widget.requiredComment,
          minLength: 5,
        ),
        ActionButton(
          'Опубликовать отзыв',
          action: () async {
            if (!form.currentState!.validate()) return;
            await mutate(
              ref,
              '/orders/${widget.id}/reviews',
              data: {'rating': rating, 'comment': comment.text.trim()},
            );
            if (context.mounted) {
              Navigator.pop(context);
              feedback(context, 'Спасибо! Отзыв опубликован.');
            }
          },
        ),
      ],
    ),
  );
}

class PrivacyForm extends ConsumerStatefulWidget {
  const PrivacyForm(
    this.id, {
    required this.messages,
    required this.attachmentIds,
    super.key,
  });
  final int id;
  final List<Json> messages;
  final List<int> attachmentIds;
  @override
  ConsumerState<PrivacyForm> createState() => _PrivacyFormState();
}

class _PrivacyFormState extends ConsumerState<PrivacyForm> {
  bool identity = false;
  final Set<int> messages = {};
  final Set<int> files = {};
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageTitle(
        'Разрешения на публикацию',
        subtitle: 'Приватность бесплатна. Разрешите только конкретные материалы. Отправка пустого списка отзовёт все разрешения.',
      ),
      _toggle(
        'Разрешить раскрытие моей личности',
        identity,
        () => setState(() => identity = !identity),
      ),
      const SizedBox(height: 18),
      const Text(
        'Фрагменты переписки',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      for (final message in widget.messages)
        _toggle(
          '#${message['id']} · ${message['text']}',
          messages.contains(message['id']),
          () => setState(() {
            final id = message['id'] as int;
            messages.contains(id) ? messages.remove(id) : messages.add(id);
          }),
        ),
      const SizedBox(height: 18),
      const Text('Вложения', style: TextStyle(fontWeight: FontWeight.w700)),
      for (final id in widget.attachmentIds)
        _toggle(
          'Файл #$id',
          files.contains(id),
          () => setState(() {
            files.contains(id) ? files.remove(id) : files.add(id);
          }),
        ),
      const SizedBox(height: 20),
      ActionButton(
        'Сохранить разрешения',
        action: () async {
          await mutate(
            ref,
            '/orders/${widget.id}/privacy-consent',
            method: 'PUT',
            data: {
              'allow_identity': identity,
              'attachment_ids': files.toList(),
              'message_ids': messages.toList(),
            },
          );
          if (context.mounted) {
            Navigator.pop(context);
            feedback(context, 'Разрешения обновлены');
          }
        },
      ),
    ],
  );
  Widget _toggle(String text, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: FButton(
      variant: selected ? .primary : .outline,
      onPress: onTap,
      prefix: Icon(
        selected ? FLucideIcons.squareCheck : FLucideIcons.square,
        size: 17,
      ),
      child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
    ),
  );
}
