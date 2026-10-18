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
        const PageTitle(
          'Мои заказы',
          subtitle: 'Здесь задачи превращаются в опыт.',
        ),
        ChoiceField(
          'Раздел',
          value: tab,
          options: const {
            'orders': 'В работе и завершённые',
            'tasks': 'Мои публикации',
            'applications': 'Мои отклики',
          },
          onChange: (v) => setState(() => tab = v),
        ),
        if (tab == 'orders') ...[
          ChoiceField(
            'Моя роль',
            value: role,
            options: const {
              '': 'Все',
              'customer': 'Заказчик',
              'performer': 'Исполнитель',
            },
            onChange: (v) => setState(() => role = v),
          ),
          ChoiceField(
            'Статус',
            value: status,
            options: const {
              '': 'Все',
              'in_progress': 'В работе',
              'submitted': 'На проверке',
              'accepted_pending_review': 'Ждут отзыв',
              'completed': 'Завершённые',
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
                  'Совместные проекты ещё впереди',
                  subtitle: 'Выберите исполнителя или откликнитесь на задачу.',
                  action: FButton(
                    onPress: () => context.go('/tasks'),
                    child: const Text('Найти заказ'),
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
                                  Tag(statusLabel(order['status'] as String)),
                                  Tag(
                                    order['customer_id'] == user.id
                                        ? 'Я заказчик'
                                        : 'Я исполнитель',
                                    color: muted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Заказ #${order['id']} · ${dateLabel(order['created_at'])}',
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
                      'Пока нет опубликованных задач',
                      action: FButton(
                        onPress: () => context.go('/tasks/new'),
                        child: const Text('Создать задачу'),
                      ),
                    )
                  : TaskGrid(tasks);
            },
          ),
        if (tab == 'applications')
          ResourceView(
            '/applications?mine=true&limit=100',
            builder: (data) => items(data).isEmpty
                ? const StateMessage(
                    'Вы ещё не откликались',
                    subtitle: 'Найдите задачу по душе и расскажите о себе.',
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
                                          'Отклик на задачу #${application['task_id']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Tag(
                                        statusLabel(
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
