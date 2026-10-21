import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/tasks/data/task_repository.dart';
import '../shared/models/models.dart';
import 'api/api_client.dart';
import 'database/local_database.dart';
import 'l10n/locale_provider.dart';
import 'telegram/telegram.dart';

final databaseProvider = Provider<LocalDatabase>((ref) {
  final db = LocalDatabase();
  ref.onDispose(db.close);
  return db;
});
final Provider<ApiClient> apiProvider = Provider((ref) {
  final api = ApiClient();
  api.language = ref.read(localeProvider).languageCode;
  ref.listen(localeProvider, (_, locale) {
    api.language = locale.languageCode;
    ref.invalidate(resourceProvider);
    ref.invalidate(categoriesProvider);
  });
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
final telegramInitDataProvider = Provider<String?>((ref) => telegramInitData());
final appInitialLocationProvider = Provider<String>((ref) => '/');

class SessionController extends AsyncNotifier<Person?> {
  int _operation = 0;

  bool _isCurrent(int operation) => ref.mounted && operation == _operation;

  @override
  Future<Person?> build() async {
    final operation = ++_operation;
    ref.onDispose(() => _operation++);
    final initData = ref.read(telegramInitDataProvider);
    if (initData == null || initData.isEmpty) return null;
    try {
      return await _signIn(operation, initData: initData);
    } catch (_) {
      if (!_isCurrent(operation)) return ref.mounted ? state.value : null;
      ref.read(apiProvider).token = null;
      rethrow;
    }
  }

  Future<void> demo(int id) async {
    final operation = ++_operation;
    final db = ref.read(databaseProvider);
    final api = ref.read(apiProvider);
    api.token = null;
    state = const AsyncLoading();
    ref.invalidate(resourceProvider);
    try {
      await db.wipePersonal();
      if (!_isCurrent(operation)) return;
      final user = await _signIn(operation, demoId: id);
      if (_isCurrent(operation)) state = AsyncData(user);
    } catch (error, stackTrace) {
      if (!_isCurrent(operation)) return;
      api.token = null;
      state = AsyncError(error, stackTrace);
    }
  }

  Future<Person?> _signIn(
    int operation, {
    int? demoId,
    String? initData,
  }) async {
    final api = ref.read(apiProvider);
    final authenticated = await ref
        .read(authRepositoryProvider)
        .signIn(demoId: demoId, initData: initData);
    if (!_isCurrent(operation)) return ref.mounted ? state.value : null;
    final database = ref.read(databaseProvider);
    final owner = await database.read('personal_owner');
    if (!_isCurrent(operation)) return ref.mounted ? state.value : null;
    if (owner != authenticated.user.id) {
      await database.wipePersonal();
      if (!_isCurrent(operation)) return ref.mounted ? state.value : null;
      await database.write('personal_owner', authenticated.user.id);
      if (!_isCurrent(operation)) return ref.mounted ? state.value : null;
    }
    api.token = authenticated.token;
    final epoch = api.identityEpoch;
    final user = authenticated.user;
    await ref
        .read(localeProvider.notifier)
        .adoptAccountLanguage(user.json['language'] as String?);
    if (!_isCurrent(operation) || api.identityEpoch != epoch) {
      return ref.mounted ? state.value : null;
    }
    final language = ref.read(localeProvider).languageCode;
    final localized = user.json['language'] == language
        ? user
        : await ref.read(authRepositoryProvider).update({'language': language});
    return _isCurrent(operation) && api.identityEpoch == epoch
        ? localized
        : ref.mounted
        ? state.value
        : null;
  }

  Future<void> updateProfile(Json data) async {
    final epoch = ref.read(apiProvider).identityEpoch;
    final userId = state.value?.id;
    final user = await ref.read(authRepositoryProvider).update(data);
    if (!ref.mounted ||
        ref.read(apiProvider).identityEpoch != epoch ||
        state.value?.id != userId) {
      return;
    }
    state = AsyncData(user);
    ref.invalidate(resourceProvider);
  }

  Future<void> logout() async {
    _operation++;
    ref.read(apiProvider).token = null;
    state = const AsyncData(null);
    ref.invalidate(resourceProvider);
    await ref.read(databaseProvider).wipePersonal();
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
  int _revision = 0;

  @override
  bool build() {
    final subscription = telegramThemeChanges.listen((value) {
      _revision++;
      state = value;
    });
    ref.onDispose(subscription.cancel);
    final revision = _revision;
    final database = ref.read(databaseProvider);
    Future.microtask(() async {
      final stored = await database.read('theme');
      if (stored is bool && ref.mounted && revision == _revision) {
        state = stored;
      }
    });
    return telegramDark() ?? false;
  }

  void toggle() {
    _revision++;
    state = !state;
    ref.read(databaseProvider).write('theme', state);
  }
}
