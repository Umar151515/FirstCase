import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/ui.dart';
import '../../../shared/widgets/media.dart';
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
  int? avatarId;
  bool avatarChanged = false;
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
      avatarId = user.avatarAttachmentId;
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
    final user = ref.watch(sessionProvider).value;
    if (user == null) return requireLogin(context);
    return PageBody(
      width: 760,
      children: [
        PageTitle(
          widget.onboarding
              ? context.l10n.profileOnboardingTitle
              : context.l10n.profileEditTitle,
          subtitle: context.l10n.profileFormSubtitle,
        ),
        Panel(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ImageUploadField(
                  value: avatarId,
                  previewUrl: avatarChanged ? null : user.avatar,
                  label: context.l10n.profilePhotoLabel,
                  onChange: (value) => setState(() {
                    avatarChanged = true;
                    avatarId = value;
                  }),
                ),
                Field(context.l10n.profileName, name, minLength: 2),
                Field(
                  context.l10n.specialization,
                  specialization,
                  required: false,
                  hint: context.l10n.specializationHint,
                ),
                Field(
                  context.l10n.skillsLabel,
                  skills,
                  required: false,
                  hint: context.l10n.skillsHint,
                ),
                Field(
                  context.l10n.bio,
                  bio,
                  lines: 4,
                  required: false,
                  hint: context.l10n.bioHint,
                ),
                Field(context.l10n.city, city, required: false),
                Field(
                  context.l10n.workLinks,
                  links,
                  lines: 2,
                  required: false,
                  validator: (v) =>
                      parseLinks(v ?? '')
                          .any((link) => Uri.tryParse(link)?.scheme != 'https')
                      ? context.l10n.useHttpsLinks
                      : null,
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ActionButton(
                      context.l10n.saveProfile,
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
                          if (avatarChanged) 'avatar_attachment_id': avatarId,
                        });
                        if (context.mounted) context.go('/profile');
                      },
                    ),
                    if (widget.onboarding)
                      ActionButton(
                        context.l10n.fillLater,
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
        PageTitle(
          context.l10n.tipsSettingsTitle,
          subtitle: context.l10n.tipsSettingsIntro,
        ),
        Panel(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Field(
                  context.l10n.paymentMethod,
                  method,
                  hint: context.l10n.paymentMethodHint,
                  required: enabled,
                ),
                Field(
                  context.l10n.optionalPaymentLink,
                  url,
                  required: false,
                  validator: (v) =>
                      v != null &&
                          v.isNotEmpty &&
                          Uri.tryParse(v)?.scheme != 'https'
                      ? context.l10n.httpsLinkOnly
                      : null,
                ),
                ImageUploadField(
                  value: qr,
                  label: context.l10n.tipsQrImageLabel,
                  onChange: (value) => setState(() => qr = value),
                ),
                ChoiceField(
                  context.l10n.acceptTips,
                  value: '$enabled',
                  options: {
                    'true': context.l10n.enabled,
                    'false': context.l10n.disabled,
                  },
                  onChange: (v) => setState(() => enabled = v == 'true'),
                ),
                ChoiceField(
                  context.l10n.publishQr,
                  value: '$consent',
                  options: {
                    'true': context.l10n.yesAllow,
                    'false': context.l10n.completedCustomersOnly,
                  },
                  onChange: (v) => setState(() => consent = v == 'true'),
                ),
                Text(
                  context.l10n.qrPrivacyHint,
                  style: TextStyle(color: muted, fontSize: 12, height: 1.7),
                ),
                const SizedBox(height: 24),
                ActionButton(
                  context.l10n.saveSettings,
                  success: context.l10n.tipsSettingsSaved,
                  action: () async {
                    if (!form.currentState!.validate()) return;
                    if (enabled && qr == null && url.text.isEmpty) {
                      throw Exception(context.l10n.qrOrLinkRequired);
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
