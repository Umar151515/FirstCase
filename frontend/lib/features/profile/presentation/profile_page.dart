import '../../../core/l10n/l10n.dart';

import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../auth/presentation/login_page.dart';
import '../../portfolio/presentation/portfolio_page.dart';
import '../../orders/presentation/order_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({this.id, super.key});
  final int? id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    if (id == null && session == null) return requireLogin(context);
    final userId = id ?? session!.id;
    final own = userId == session?.id;
    return PageBody(
      width: 1000,
      children: [
        ResourceView(
          own ? '/auth/me' : '/users/$userId',
          builder: (data) {
            final person = Person(Map<String, dynamic>.from(data as Map));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PersonAvatar(person, size: 84),
                          const SizedBox(width: 22),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person.name,
                                  style: const TextStyle(
                                    fontSize: 29,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  person.specialty.isEmpty
                                      ? context.l10n.openToOpportunities
                                      : person.specialty,
                                  style: const TextStyle(color: muted),
                                ),
                                const SizedBox(height: 10),
                                Tag(
                                  person.city,
                                  icon: FLucideIcons.mapPin,
                                  color: muted,
                                ),
                              ],
                            ),
                          ),
                          if (own && MediaQuery.sizeOf(context).width > 600)
                            FButton(
                              variant: .outline,
                              mainAxisSize: MainAxisSize.min,
                              onPress: () => context.go('/profile/edit'),
                              child: Text(context.l10n.edit),
                            ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Wrap(
                        spacing: 28,
                        runSpacing: 18,
                        children: [
                          _Stat(
                            person.rating == 0
                                ? '—'
                                : person.rating.toStringAsFixed(1),
                            context.l10n.rating,
                          ),
                          _Stat(
                            '${person.json['review_count'] ?? 0}',
                            context.l10n.statReviews,
                          ),
                          _Stat(
                            '${person.json['completed_orders'] ?? 0}',
                            context.l10n.completedOrders,
                          ),
                          _Stat(
                            '${person.json['verified_cases'] ?? 0}',
                            context.l10n.statVerifiedCases,
                          ),
                        ],
                      ),
                      if (person.bio.isNotEmpty) ...[
                        const SizedBox(height: 25),
                        Text(person.bio, style: const TextStyle(height: 1.8)),
                      ],
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: person.skills.map((s) => Tag(s)).toList(),
                      ),
                      if ((person.json['work_links'] as List? ?? [])
                          .isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          children: (person.json['work_links'] as List)
                              .map(
                                (link) => FButton(
                                  variant: .outline,
                                  mainAxisSize: MainAxisSize.min,
                                  onPress: () => launchUrl(
                                    Uri.parse(link),
                                    mode: LaunchMode.externalApplication,
                                  ),
                                  child: Text(Uri.parse(link as String).host),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (own) ...[
                            FButton(
                              variant: .outline,
                              onPress: () => context.go('/profile/edit'),
                              child: Text(context.l10n.configureProfile),
                            ),
                            FButton(
                              variant: .outline,
                              onPress: () => context.go('/tips'),
                              child: Text(context.l10n.tipsQr),
                            ),
                            FButton(
                              variant: .ghost,
                              onPress: () => context.go('/reports'),
                              child: Text(context.l10n.myReports),
                            ),
                            if (person.admin)
                              FButton(
                                onPress: () => context.go('/admin'),
                                prefix: const Icon(
                                  FLucideIcons.shieldCheck,
                                  size: 16,
                                ),
                                child: Text(context.l10n.adminSection),
                              ),
                            ActionButton(
                              context.l10n.signOut,
                              secondary: true,
                              action: () async {
                                await ref
                                    .read(sessionProvider.notifier)
                                    .logout();
                                if (context.mounted) context.go('/');
                              },
                            ),
                          ] else ...[
                            FButton(
                              variant: .outline,
                              onPress: () => modal(context, TipsViewer(userId)),
                              child: Text(context.l10n.thankShort),
                            ),
                            if (session != null)
                              FButton(
                                variant: .ghost,
                                onPress: () =>
                                    modal(context, ReportForm('user', userId)),
                                child: Text(context.l10n.report),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                PageTitle(
                  own ? context.l10n.myPortfolio : context.l10n.portfolio,
                  subtitle: context.l10n.portfolioSubtitle,
                  action: own
                      ? FButton(
                          variant: .outline,
                          onPress: () => context.go('/portfolio/new'),
                          child: Text(context.l10n.addWork),
                        )
                      : null,
                ),
                ResourceView(
                  own
                      ? '/portfolio?mine=true&limit=100'
                      : '/portfolio?user_id=$userId&limit=100',
                  builder: (data) {
                    final cases = items(data);
                    return cases.isEmpty
                        ? StateMessage(
                            context.l10n.portfolioNoWorks,
                            subtitle: context.l10n.portfolioNoWorksHint,
                            icon: FLucideIcons.folderHeart,
                          )
                        : PortfolioGrid(cases);
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: context.theme.colors.primary,
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: muted, fontSize: 11)),
    ],
  );
}
