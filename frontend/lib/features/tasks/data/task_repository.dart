import 'dart:convert';

import '../../../core/api/api_client.dart';
import '../../../core/database/local_database.dart';
import '../../../shared/models/models.dart';

class TaskRepository {
  TaskRepository(this.api, this.cache);
  final ApiClient api;
  final LocalDatabase cache;
  Future<List<Json>> categories() async =>
      items(await api.request('/categories'));
  Future<dynamic> resource(String path) async {
    final epoch = api.identityEpoch;
    final language = api.language;
    final uri = Uri.parse(path);
    final cacheable = uri.path == '/tasks' || uri.path.startsWith('/users');
    final key = 'resource:$epoch:$language:$path';
    try {
      final data = await api.request(uri.path, query: uri.queryParameters);
      if (api.identityEpoch == epoch && api.language == language && cacheable) {
        await cache.write(key, data, personal: true);
      }
      return data;
    } on ApiFailure catch (error) {
      if (cacheable &&
          error.status == null &&
          api.identityEpoch == epoch &&
          api.language == language) {
        final cached = await cache.read(key);
        if (cached is Map) return {...cached, '_offline': true};
      }
      rethrow;
    }
  }

  Future<dynamic> mutate(String path, {Json? data, String method = 'POST'}) =>
      api.request(path, method: method, data: data ?? {});

  Future<Json?> draft() async {
    final data = await cache.read('task_draft');
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<void> saveDraft(Json data) =>
      cache.write('task_draft', data, personal: true);
  Future<void> clearDraft() => cache.write('task_draft', null, personal: true);

  Future<PageData<Task>> tasks(Json query, {bool offline = false}) async {
    final epoch = api.identityEpoch;
    final language = api.language;
    final key = 'tasks:$epoch:$language:${jsonEncode(query)}';
    dynamic data;
    try {
      data = await api.request('/tasks', query: query);
      if (api.identityEpoch == epoch && api.language == language) {
        await cache.write(key, data, personal: true);
      }
    } on ApiFailure {
      if (!offline) rethrow;
      data = await cache.read(key);
      if (data == null) rethrow;
    }
    return PageData(items(data).map(Task.new).toList(), data['total'] as int);
  }
}
