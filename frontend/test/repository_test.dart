import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firstcase/core/api/api_client.dart';
import 'package:firstcase/core/database/local_database.dart';
import 'package:firstcase/features/tasks/data/task_repository.dart';

import 'support.dart';

void main() {
  late LocalDatabase database;
  setUp(() {
    database = LocalDatabase(NativeDatabase.memory());
  });
  tearDown(() => database.close());

  test('task repository passes filters and pagination to server', () async {
    final transport = TestTransport(
      (request) async => jsonBody({'items': [], 'total': 0}),
    );
    final repository = TaskRepository(apiWith(transport), database);
    final page = await repository.tasks({
      'q': 'бот',
      'category_id': 2,
      'offset': 12,
      'limit': 12,
    });
    expect(page.total, 0);
    expect(transport.requests.single.queryParameters, {
      'q': 'бот',
      'category_id': 2,
      'offset': 12,
      'limit': 12,
    });
  });

  test(
    'offline catalogue uses SQLite and visibly marks cached response',
    () async {
      bool offline = false;
      final transport = TestTransport((request) async {
        if (offline) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          );
        }
        return jsonBody({'items': [], 'total': 3});
      });
      final repository = TaskRepository(apiWith(transport), database);
      await repository.resource('/tasks?limit=12');
      offline = true;
      final data = await repository.resource('/tasks?limit=12');
      expect(data['total'], 3);
      expect(data['_offline'], isTrue);
    },
  );

  test('a forbidden response is never replaced by cached data', () async {
    int status = 200;
    final repository = TaskRepository(
      apiWith(
        TestTransport(
          (request) async => status == 200
              ? jsonBody({'id': 3, 'display_name': 'Диана'})
              : jsonBody({
                  'error': {'message': 'Доступ закрыт'},
                }, status),
        ),
      ),
      database,
    );
    await repository.resource('/users/3');
    status = 403;
    expect(
      () => repository.resource('/users/3'),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 403)),
    );
  });

  test(
    'identity switch clears private caches and drafts, retains theme',
    () async {
      await database.write('task_draft', {
        'title': 'Приватная задача',
      }, personal: true);
      await database.write('chat_draft:2', 'Личное сообщение', personal: true);
      await database.write('theme', true);
      await database.wipePersonal();
      expect(await database.read('task_draft'), isNull);
      expect(await database.read('chat_draft:2'), isNull);
      expect(await database.read('theme'), isTrue);
    },
  );

  test(
    'in-flight response from old identity cannot repopulate cache',
    () async {
      final response = Completer<ResponseBody>();
      final api = apiWith(TestTransport((_) => response.future));
      api.token = 'old-session';
      final repository = TaskRepository(api, database);
      final pending = repository.resource('/users/2');
      await Future<void>.delayed(Duration.zero);
      final previousEpoch = api.identityEpoch;
      api.token = 'new-session';
      await database.wipePersonal();
      response.complete(
        jsonBody({'id': 2, 'display_name': 'Old identity cached profile'}),
      );
      await pending;
      expect(await database.read('resource:$previousEpoch:/users/2'), isNull);
    },
  );

  test('upload sends image MIME type, bytes and authorization', () async {
    final api = apiWith(
      TestTransport((request) async {
        final part = ((request.data as FormData).files.single.value);
        expect(part.contentType.toString(), 'image/png');
        expect(part.filename, 'qr.png');
        expect(request.headers['Authorization'], 'Bearer protected');
        return jsonBody({'id': 42, 'filename': 'qr.png'}, 201);
      }),
    );
    api.token = 'protected';
    expect(
      (await api.upload('qr.png', Uint8List.fromList([137, 80, 78, 71])))['id'],
      42,
    );
  });

  test('server validation and network errors have useful messages', () async {
    final api = apiWith(
      TestTransport(
        (_) async => jsonBody({
          'error': {'message': 'Нельзя откликнуться на свою задачу'},
        }, 409),
      ),
    );
    expect(
      () => api.request('/tasks/1/applications', method: 'POST'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.message,
          'message',
          contains('свою задачу'),
        ),
      ),
    );
  });

  test('private downloads preserve Unicode filename and extension', () async {
    final api = apiWith(
      TestTransport((request) async {
        expect(request.headers['Authorization'], 'Bearer protected');
        return ResponseBody.fromBytes(
          [1, 2, 3],
          200,
          headers: {
            'content-disposition': [
              "attachment; filename*=utf-8''%D0%9C%D0%B5%D0%BD%D1%8E.txt",
            ],
            'content-type': ['text/plain'],
          },
        );
      }),
    );
    api.token = 'protected';
    final file = await api.download(42);
    expect(file.filename, 'Меню.txt');
    expect(file.bytes, [1, 2, 3]);
  });
}
