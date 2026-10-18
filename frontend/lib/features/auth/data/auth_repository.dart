import '../../../core/api/api_client.dart';
import '../../../shared/models/models.dart';

class AuthRepository {
  AuthRepository(this.api);
  final ApiClient api;
  Future<String> mode() async =>
      (await api.request('/config'))['mode'] as String;
  Future<List<Person>> demoUsers() async =>
      items(await api.request('/auth/demo-users')).map(Person.new).toList();
  Future<Person> signIn({int? demoId, String? initData}) async {
    final data = await api.request(
      demoId == null ? '/auth/telegram' : '/auth/demo-login',
      method: 'POST',
      data: demoId == null ? {'init_data': initData} : {'user_id': demoId},
    );
    api.token = data['access_token'] as String;
    return Person(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<Person> me() async =>
      Person(Map<String, dynamic>.from(await api.request('/auth/me') as Map));
  Future<Person> update(Json data) async => Person(
    Map<String, dynamic>.from(
      await api.request('/users/me', method: 'PATCH', data: data) as Map,
    ),
  );
}
