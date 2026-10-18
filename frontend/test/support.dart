import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firstcase/core/api/api_client.dart';

class TestTransport implements HttpClientAdapter {
  TestTransport(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  final List<RequestOptions> requests = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(dynamic value, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(value),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ApiClient apiWith(TestTransport transport) => ApiClient(
  dio: Dio(BaseOptions(baseUrl: 'https://firstcase.test/api/v1'))
    ..httpClientAdapter = transport,
);

const testUser = {
  'id': 1,
  'display_name': 'Айбек',
  'role': 'user',
  'language': 'ru',
  'onboarding_completed': true,
  'skills': <String>[],
};
