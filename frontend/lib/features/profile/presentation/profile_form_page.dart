import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../shared/widgets/ui.dart';
import '../../auth/presentation/login_page.dart';
import '../../orders/presentation/order_forms.dart';

class ProfileFormPage extends ConsumerStatefulWidget {
  const ProfileFormPage({this.onboarding = false, super.key});
  final bool onboarding;
  @override
  ConsumerState<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends ConsumerState<ProfileFormPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final specialization = TextEditingController();
  final skills = TextEditingController();
  final bio = TextEditingController();
  final city = TextEditingController();
  final links = TextEditingController();
  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider).value;
    if (user != null) {
      name.text = user.name;
      specialization.text = user.specialty;
      skills.text = user.skills.join(', ');
      bio.text = user.bio;
      city.text = user.city;
      links.text = (user.json['work_links'] as List? ?? []).join('\n');
    }
  }

  @override
  void dispose() {
    for (final controller in [name, specialization, skills, bio, city, links]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider).value == null) return requireLogin(context);
    return PageBody(
      width: 760,
      children: [
        PageTitle(
          widget.onboarding ? 'Расскажем о вас миру?' : 'Ваш профиль',
          subtitle: 'Хороший профиль помогает найти своих людей. Необязательные поля можно заполнить позже.',
        ),
        Panel(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Field('Как к вам обращаться?', name, minLength: 2),
                Field(
                  'Специализация',
                  specialization,
                  required: false,
                  hint: 'Flutter-разработчик, дизайнер, видеомонтажёр…',
                ),
                Field(
                  'Навыки · через запятую',
                  skills,
                  required: false,
                  hint: 'Dart, Figma, монтаж, иллюстрация',
                ),
                Field(
                  'О себе',
                  bio,
                  lines: 4,
                  required: false,
                  hint: 'Что любите делать и чему хотите научиться?',
                ),
                Field('Город', city, required: false),
                Field(
                  'Ссылки на работы · по одной на строку',
                  links,
                  lines: 2,
                  required: false,
                  validator: (v) =>
                      parseLinks(v ?? '')
                          .any((link) => Uri.tryParse(link)?.scheme != 'https')
                      ? 'Используйте HTTPS-ссылки'
                      : null,
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ActionButton(
                      'Сохранить профиль',
                      action: () async {
                        if (!form.currentState!.validate()) return;
                        await ref.read(sessionProvider.notifier).updateProfile({
                          'display_name': name.text.trim(),
                          'specialization': specialization.text.trim(),
                          'skills': skills.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList(),
                          'bio': bio.text.trim(),
                          'city': city.text.trim(),
                          'work_links': parseLinks(links.text),
                          'onboarding_completed': true,
                        });
                        if (context.mounted) context.go('/profile');
                      },
                    ),
                    if (widget.onboarding)
                      ActionButton(
                        'Заполню позже',
                        secondary: true,
                        action: () async {
                          await ref
                              .read(sessionProvider.notifier)
                              .updateProfile({'onboarding_completed': true});
                          if (context.mounted) context.go('/');
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class TipsPage extends ConsumerStatefulWidget {
  const TipsPage({super.key});
  @override
  ConsumerState<TipsPage> createState() => _TipsPageState();
}

class _TipsPageState extends ConsumerState<TipsPage> {
  final form = GlobalKey<FormState>();
  final method = TextEditingController();
  final url = TextEditingController();
  int? qr;
  bool enabled = false;
  bool consent = false;
  bool loaded = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final data = await ref
            .read(taskRepositoryProvider)
            .resource('/tips/settings');
        if (mounted && data is Map) {
          setState(() {
            method.text = '${data['payment_method'] ?? ''}';
            url.text = '${data['payment_url'] ?? ''}';
            qr = data['qr_attachment_id'] as int?;
            enabled = data['enabled'] == true;
            consent = data['public_consent'] == true;
          });
        }
      } catch (e) {
        if (mounted) feedback(context, '$e', error: true);
      }
      if (mounted) setState(() => loaded = true);
    });
  }

  @override
  void dispose() {
    method.dispose();
    url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider).value == null) return requireLogin(context);
    if (!loaded) return const PageBody(children: [LoadingView()]);
    return PageBody(
      width: 720,
      children: [
        const PageTitle(
          'Маленькое «спасибо»',
          subtitle:
              'Добавьте QR, чтобы заказчик мог добровольно поблагодарить вас.',
        ),
        Panel(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Field(
                  'Название платёжного метода',
                  method,
                  hint: 'Например, MBank',
                  required: enabled,
                ),
                Field(
                  'Безопасная платёжная ссылка · необязательно',
                  url,
                  required: false,
                  validator: (v) =>
                      v != null &&
                          v.isNotEmpty &&
                          Uri.tryParse(v)?.scheme != 'https'
                      ? 'Разрешена только HTTPS-ссылка'
                      : null,
                ),
                if (qr != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Tag(
                      'QR-файл #$qr сохранён',
                      icon: FLucideIcons.qrCode,
                    ),
                  ),
                UploadField(
                  imagesOnly: true,
                  onChange: (v) => setState(() => qr = v.firstOrNull),
                ),
                ChoiceField(
                  'Принимать добровольные чаевые',
                  value: '$enabled',
                  options: const {'true': 'Включено', 'false': 'Выключено'},
                  onChange: (v) => setState(() => enabled = v == 'true'),
                ),
                ChoiceField(
                  'Публиковать QR в профиле',
                  value: '$consent',
                  options: const {
                    'true': 'Да, разрешаю',
                    'false': 'Только заказчикам завершённых заказов',
                  },
                  onChange: (v) => setState(() => consent = v == 'true'),
                ),
                const Text(
                  'QR может раскрывать ваше имя или платёжные данные. Включайте публичный показ осознанно. FirstCase не принимает платежи и не подтверждает переводы.',
                  style: TextStyle(color: muted, fontSize: 12, height: 1.7),
                ),
                const SizedBox(height: 24),
                ActionButton(
                  'Сохранить настройки',
                  success: 'Настройки чаевых сохранены',
                  action: () async {
                    if (!form.currentState!.validate()) return;
                    if (enabled && qr == null && url.text.isEmpty) {
                      throw Exception('Добавьте QR или платёжную ссылку');
                    }
                    await mutate(
                      ref,
                      '/tips/settings',
                      method: 'PUT',
                      data: {
                        'payment_method': method.text.trim(),
                        'qr_attachment_id': qr,
                        'payment_url': url.text.trim().isEmpty
                            ? null
                            : url.text.trim(),
                        'enabled': enabled,
                        'public_consent': consent,
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
