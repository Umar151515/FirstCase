import '../../../core/api/api_client.dart';
import '../../../shared/models/models.dart';

class AuthRepository {
  AuthRepository(this.api);
  final ApiClient api;
  Future<String> mode() async =>
      (await api.request('/config', identityScoped: false))['mode'] as String;
  Future<List<Person>> demoUsers() async =>
      items(await api.request('/auth/demo-users', identityScoped: false))
          .map(Person.new)
          .toList();
  Future<({String token, Person user})> signIn({
    int? demoId,
    String? initData,
  }) async {
    final data = await api.request(
      demoId == null ? '/auth/telegram' : '/auth/demo-login',
      method: 'POST',
      data: demoId == null ? {'init_data': initData} : {'user_id': demoId},
    );
    // The controller commits credentials only while this login is current.
    // A completed request must never restore an account after logout.
    return (
      token: data['access_token'] as String,
      user: Person(Map<String, dynamic>.from(data['user'] as Map)),
    );
  }

  Future<Person> me() async =>
      Person(Map<String, dynamic>.from(await api.request('/auth/me') as Map));
  Future<Person> update(Json data) async => Person(
    Map<String, dynamic>.from(
      await api.request('/users/me', method: 'PATCH', data: data) as Map,
    ),
  );
}
