import '../../../core/l10n/l10n.dart';

import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../auth/presentation/login_page.dart';
import '../../tasks/presentation/task_card.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});
  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  String tab = 'orders';
  String role = '';
  String status = '';
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).value;
    if (user == null) return requireLogin(context);
    return PageBody(
      children: [
        PageTitle(
          context.l10n.navOrders,
          subtitle: context.l10n.ordersSubtitle,
        ),
        FilterTabs(
          value: tab,
          options: {
            'orders': context.l10n.ordersActiveAndCompleted,
            'tasks': context.l10n.myPublications,
            'applications': context.l10n.myApplications,
          },
          onChange: (v) => setState(() => tab = v),
        ),
        Divider(height: 1, color: edge(context)),
        const SizedBox(height: 24),
        if (tab == 'orders') ...[
          ChoiceField(
            context.l10n.myRole,
            value: role,
            options: {
              '': context.l10n.all,
              'customer': context.l10n.roleCustomer,
              'performer': context.l10n.rolePerformer,
            },
            onChange: (v) => setState(() => role = v),
          ),
          ChoiceField(
            context.l10n.status,
            value: status,
            options: {
              '': context.l10n.all,
              'in_progress': context.l10n.statusInProgress,
              'submitted': context.l10n.statusSubmitted,
              'accepted_pending_review': context.l10n.filterAwaitingReview,
              'completed': context.l10n.filterCompleted,
            },
            onChange: (v) => setState(() => status = v),
          ),
          ResourceView(
            Uri(
              path: '/orders',
              queryParameters: {
                if (role.isNotEmpty) 'role': role,
                if (status.isNotEmpty) 'status': status,
                'limit': '100',
              },
            ).toString(),
            builder: (data) {
              final orders = items(data);
              if (orders.isEmpty) {
                return StateMessage(
                  context.l10n.ordersNoOrders,
                  subtitle: context.l10n.ordersEmptyHint,
                  action: FButton(
                    onPress: () => context.go('/tasks'),
                    child: Flexible(child: Text(context.l10n.navTasks)),
                  ),
                );
              }
              return Column(
                children: orders
                    .map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Panel(
                          onTap: () => context.go('/orders/${order['id']}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (order['task'] as Map)['title'] as String,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    FLucideIcons.arrowUpRight,
                                    size: 17,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  Tag(
                                    statusLabel(
                                      context,
                                      order['status'] as String,
                                    ),
                                  ),
                                  Tag(
                                    order['customer_id'] == user.id
                                        ? context.l10n.iAmCustomer
                                        : context.l10n.iAmPerformer,
                                    color: muted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.l10n.orderDateLabel(
                                  order['id'] as int,
                                  dateLabel(context, order['created_at']),
                                ),
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
        if (tab == 'tasks')
          ResourceView(
            '/tasks?mine=true&limit=100',
            builder: (data) {
              final tasks = items(data).map(Task.new).toList();
              return tasks.isEmpty
                  ? StateMessage(
                      context.l10n.publicationsEmpty,
                      action: FButton(
                        onPress: () => context.go('/tasks/new'),
                        child: Flexible(child: Text(context.l10n.navCreate)),
                      ),
                    )
                  : TaskGrid(tasks);
            },
          ),
        if (tab == 'applications')
          ResourceView(
            '/applications?mine=true&limit=100',
            builder: (data) => items(data).isEmpty
                ? StateMessage(
                    context.l10n.applicationsEmpty,
                    subtitle: context.l10n.applicationsEmptyHint,
                  )
                : Column(
                    children: items(data)
                        .map(
                          (application) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Panel(
                              onTap: () => context.go(
                                '/tasks/${application['task_id']}',
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          context.l10n.applicationTaskLabel(
                                            application['task_id'] as int,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Tag(
                                        statusLabel(
                                          context,
                                          application['status'] as String,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    application['message'] as String,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
      ],
    );
  }
}
