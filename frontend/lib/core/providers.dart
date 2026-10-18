import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/tasks/data/task_repository.dart';
import '../shared/models/models.dart';
import 'api/api_client.dart';
import 'database/local_database.dart';
import 'telegram/telegram.dart';

final databaseProvider = Provider<LocalDatabase>((ref) {
  final db = LocalDatabase();
  ref.onDispose(db.close);
  return db;
});
final apiProvider = Provider<ApiClient>((ref) {
  final api = ApiClient();
  api.onUnauthorized = () =>
      unawaited(ref.read(sessionProvider.notifier).logout());
  return api;
});
final authRepositoryProvider = Provider(
  (ref) => AuthRepository(ref.watch(apiProvider)),
);
final taskRepositoryProvider = Provider(
  (ref) => TaskRepository(ref.watch(apiProvider), ref.watch(databaseProvider)),
);
final modeProvider = FutureProvider(
  (ref) => ref.watch(authRepositoryProvider).mode(),
);
final demoUsersProvider = FutureProvider(
  (ref) => ref.watch(authRepositoryProvider).demoUsers(),
);
final categoriesProvider = FutureProvider(
  (ref) => ref.watch(taskRepositoryProvider).categories(),
);
final sessionProvider = AsyncNotifierProvider<SessionController, Person?>(
  SessionController.new,
);

class SessionController extends AsyncNotifier<Person?> {
  @override
  Future<Person?> build() async {
    final initData = telegramInitData();
    if (initData == null || initData.isEmpty) return null;
    return ref.read(authRepositoryProvider).signIn(initData: initData);
  }

  Future<void> demo(int id) async {
    final db = ref.read(databaseProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      ref.read(apiProvider).token = null;
      await db.wipePersonal();
      ref.invalidate(resourceProvider);
      return ref.read(authRepositoryProvider).signIn(demoId: id);
    });
  }

  Future<void> updateProfile(Json data) async {
    final user = await ref.read(authRepositoryProvider).update(data);
    state = AsyncData(user);
    ref.invalidate(resourceProvider);
  }

  Future<void> logout() async {
    ref.read(apiProvider).token = null;
    await ref.read(databaseProvider).wipePersonal();
    ref.invalidate(resourceProvider);
    state = const AsyncData(null);
  }
}

// Every server resource is keyed by identity, so a switched account never reuses
// a private response that was fetched for another participant.
final resourceProvider = FutureProvider.autoDispose.family<dynamic, String>((
  ref,
  path,
) async {
  if (RegExp(r'^/orders/\d+$').hasMatch(path)) {
    final timer = Timer(const Duration(seconds: 10), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  ref.watch(sessionProvider.select((session) => session.value?.id));
  return ref.watch(taskRepositoryProvider).resource(path);
});

final themeProvider = NotifierProvider<ThemeController, bool>(
  ThemeController.new,
);

class ThemeController extends Notifier<bool> {
  @override
  bool build() {
    final subscription = telegramThemeChanges.listen((value) {
      state = value;
    });
    ref.onDispose(subscription.cancel);
    Future.microtask(() async {
      final stored = await ref.read(databaseProvider).read('theme');
      if (stored is bool && ref.mounted) state = stored;
    });
    return telegramDark() ?? false;
  }

  void toggle() {
    state = !state;
    ref.read(databaseProvider).write('theme', state);
  }
}
