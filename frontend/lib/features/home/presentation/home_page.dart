import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/ui.dart';
import '../../tasks/presentation/task_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    return PageBody(
      children: [
        Container(
          padding: EdgeInsets.all(mobile ? 26 : 44),
          decoration: BoxDecoration(
            color: ref.watch(themeProvider)
                ? const Color(0xFF242136)
                : const Color(0xFFF0EDFC),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Tag(
                      'МАЛЕНЬКИЕ ЗАДАЧИ. БОЛЬШОЕ НАЧАЛО.',
                      icon: FLucideIcons.sparkles,
                    ),
                    const SizedBox(height: 25),
                    Text(
                      'Твой первый кейс\nначинается здесь',
                      style: TextStyle(
                        fontSize: mobile ? 35 : 49,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2.1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Помоги с реальной задачей. Получи опыт,\nчестный отзыв и портфолио, которому доверяют.',
                      style: TextStyle(color: muted, fontSize: 15, height: 1.7),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: surface(context),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: FTextField(
                              control: .managed(controller: search),
                              hint: 'Что тебе интересно?',
                              prefixBuilder: (context, style, variants) =>
                                  const Padding(
                                    padding: EdgeInsets.only(
                                      left: 14,
                                      right: 8,
                                    ),
                                    child: Icon(
                                      FLucideIcons.search,
                                      color: muted,
                                      size: 18,
                                    ),
                                  ),
                              onSubmit: (value) => context.go(
                                '/tasks?q=${Uri.encodeQueryComponent(value)}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FButton(
                            onPress: () => context.go(
                              '/tasks?q=${Uri.encodeQueryComponent(search.text)}',
                            ),
                            child: const Text('Найти'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Без опыта — можно. Без первого шага — никак.',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (MediaQuery.sizeOf(context).width >= 1100)
                const Expanded(flex: 5, child: _HeroArt()),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              _Benefit(
                FLucideIcons.badgeCheck,
                'Реальные задачи',
                'Опыт, который имеет значение',
                constraints.maxWidth,
              ),
              _Benefit(
                FLucideIcons.heartHandshake,
                'Безопасное начало',
                'Без комиссий и обязательных платежей',
                constraints.maxWidth,
              ),
              _Benefit(
                FLucideIcons.folderHeart,
                'Подтверждённые кейсы',
                'Репутация строится на деле',
                constraints.maxWidth,
              ),
            ],
          ),
        ),
        const SizedBox(height: 38),
        const _Section(
          'Найди своё направление',
          'Выбери то, в чём хочется расти',
        ),
        ref
            .watch(categoriesProvider)
            .when(
              data: (categories) => LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 900
                      ? 6
                      : constraints.maxWidth > 550
                      ? 3
                      : 2;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: categories
                        .take(6)
                        .map(
                          (category) => SizedBox(
                            width: width,
                            child: Panel(
                              padding: 18,
                              onTap: () => context.go(
                                '/tasks?category_id=${category['id']}',
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: .08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      categoryIcon(category['name'] as String),
                                      size: 22,
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    category['name'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Смотреть задачи ↗',
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 10,
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
              loading: () => const LoadingView(),
              error: (e, _) =>
                  StateMessage('Категории пока недоступны', subtitle: '$e'),
            ),
        const SizedBox(height: 42),
        _Section(
          'Свежие задачи для твоего старта',
          'Здесь важны желание и интерес, а не годы опыта',
          action: FButton(
            variant: .ghost,
            mainAxisSize: MainAxisSize.min,
            onPress: () => context.go('/tasks'),
            suffix: const Icon(FLucideIcons.arrowRight, size: 16),
            child: const Text('Все задачи'),
          ),
        ),
        ResourceView(
          '/tasks?status=published&limit=6&sort=newest',
          builder: (data) {
            final tasks = items(data).map(Task.new).toList();
            return tasks.isEmpty
                ? const StateMessage(
                    'Здесь появится ваша первая задача',
                    subtitle: 'Создайте заказ и найдите человека, которому нужен первый шанс.',
                  )
                : TaskGrid(tasks);
          },
        ),
        const SizedBox(height: 40),
        _Section(
          'Люди, с которыми всё получится',
          'Открыты к первым проектам и новым знакомствам',
          action: FButton(
            variant: .ghost,
            mainAxisSize: MainAxisSize.min,
            onPress: () => context.go('/tasks'),
            child: const Text('Найти задачу →'),
          ),
        ),
        ResourceView(
          '/users?limit=4',
          builder: (data) => LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 900
                  ? 4
                  : constraints.maxWidth > 550
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - 16 * (columns - 1)) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: items(data).map((json) {
                  final person = Person(json);
                  return SizedBox(
                    width: width,
                    child: Panel(
                      padding: 20,
                      onTap: () => context.go('/users/${person.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PersonAvatar(person, size: 44),
                              const Spacer(),
                              Icon(
                                FLucideIcons.star,
                                size: 13,
                                color: const Color(0xFFE5AE42),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                person.rating == 0
                                    ? 'Новичок'
                                    : person.rating.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text(
                            person.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            person.specialty.isEmpty
                                ? 'Открыт к сотрудничеству'
                                : person.specialty,
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                          const SizedBox(height: 15),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: person.skills
                                .take(2)
                                .map((s) => Tag(s, color: muted))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 40),
        Panel(
          color: ref.watch(themeProvider)
              ? const Color(0xFF252C20)
              : const Color(0xFFF1F6E8),
          padding: 28,
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'У тебя есть небольшая задача?',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.7,
                      ),
                    ),
                    SizedBox(height: 9),
                    Text(
                      'Для кого-то она может стать большим первым шагом.',
                      style: TextStyle(color: muted, height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FButton(
                mainAxisSize: MainAxisSize.min,
                onPress: () => context.go('/tasks/new'),
                child: const Text('Создать заказ'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Container(height: 1, color: edge(context)),
        const SizedBox(height: 24),
        const Text(
          'firstcase     Первый заказ. Первый кейс. Реальная репутация.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        const Text(
          'Сделано для тех, кто начинает. Бишкек, Кыргызстан ♡',
          style: TextStyle(color: muted, fontSize: 11),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.subtitle, {this.action});
  final String title;
  final String subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
        if (action != null && MediaQuery.sizeOf(context).width > 550) action!,
      ],
    ),
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.icon, this.title, this.subtitle, this.width);
  final IconData icon;
  final String title;
  final String subtitle;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width > 800 ? (width - 36) / 3 : width,
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HeroArt extends StatelessWidget {
  const _HeroArt();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 330,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 40,
          top: 15,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .07),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 20,
          child: Transform.rotate(
            angle: .13,
            child: Container(
              width: 130,
              height: 145,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: lime,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    FLucideIcons.sparkles,
                    size: 30,
                    color: Color(0xFF393D29),
                  ),
                  Spacer(),
                  Text(
                    'Твой первый\n«Получилось!»',
                    style: TextStyle(
                      color: Color(0xFF393D29),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          top: 53,
          child: Transform.rotate(
            angle: -.08,
            child: Container(
              width: 255,
              height: 238,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: surface(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: .12),
                    blurRadius: 35,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          FLucideIcons.folderCheck,
                          color: accent,
                        ),
                      ),
                      const Spacer(),
                      const Tag('ПОДТВЕРЖДЕНО', color: Color(0xFF5E8B42)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Мой первый кейс',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Container(height: 7, width: 165, color: edge(context)),
                  const SizedBox(height: 8),
                  Container(height: 7, width: 125, color: edge(context)),
                  const Spacer(),
                  const Text(
                    '★ ★ ★ ★ ★',
                    style: TextStyle(
                      color: Color(0xFFEDB94A),
                      fontSize: 22,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Реальная работа. Честный отзыв.',
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: -3,
          bottom: 11,
          child: Transform.rotate(
            angle: .05,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Row(
                children: [
                  Icon(FLucideIcons.badgeCheck, color: lime, size: 24),
                  SizedBox(width: 10),
                  Text(
                    '+1 к опыту\n+100 к уверенности',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
