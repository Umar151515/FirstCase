import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../shared/models/models.dart';

class ApiFailure implements Exception {
  ApiFailure(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: '/api/v1',
              ),
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );
  final Dio dio;
  String? _token;
  int identityEpoch = 0;
  void Function()? onUnauthorized;
  String? get token => _token;
  set token(String? value) {
    _token = value;
    identityEpoch++;
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    dynamic data,
    Json? query,
  }) async {
    try {
      return (await dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          extra: {'identity_epoch': identityEpoch},
          headers: token == null ? {} : {'Authorization': 'Bearer $token'},
        ),
      )).data;
    } on DioException catch (error) {
      throw failure(error);
    }
  }

  ApiFailure failure(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 &&
        token != null &&
        error.requestOptions.extra['identity_epoch'] == identityEpoch) {
      onUnauthorized?.call();
    }
    final data = error.response?.data;
    final server = data is Map
        ? (data['error'] is Map ? data['error']['message'] : data['detail'])
        : null;
    return ApiFailure(
      server is String
          ? server
          : switch (status) {
              401 => 'Сессия завершилась. Войдите заново.',
              403 => 'У вас нет доступа к этому действию.',
              404 => 'Объект не найден или недоступен.',
              409 => 'Состояние изменилось. Обновите страницу.',
              422 => 'Проверьте введённые данные.',
              final int code when code >= 500 =>
                'Сервер временно недоступен. Попробуйте ещё раз.',
              _ => 'Не удалось подключиться к серверу. Проверьте интернет.',
            },
      status,
    );
  }

  Future<Json> upload(String name, Uint8List bytes) async =>
      Map<String, dynamic>.from(
        await request(
          '/uploads',
          method: 'POST',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(
              bytes,
              filename: name,
              contentType: DioMediaType.parse(
                const {
                      'png': 'image/png',
                      'jpg': 'image/jpeg',
                      'jpeg': 'image/jpeg',
                      'webp': 'image/webp',
                      'pdf': 'application/pdf',
                      'txt': 'text/plain',
                      'zip': 'application/zip',
                    }[name.split('.').last.toLowerCase()] ??
                    'application/octet-stream',
              ),
            ),
          }),
        ) as Map,
      );

  Future<({Uint8List bytes, String filename})> download(
    int id, {
    String? path,
  }) async {
    try {
      final response = await dio.get<List<int>>(
        path ?? '/uploads/$id',
        options: Options(
          extra: {'identity_epoch': identityEpoch},
          responseType: ResponseType.bytes,
          headers: token == null ? {} : {'Authorization': 'Bearer $token'},
        ),
      );
      final disposition = response.headers.value('content-disposition') ?? '';
      final encoded = RegExp(
        "filename\\*=utf-8''([^;]+)",
        caseSensitive: false,
      ).firstMatch(disposition)?.group(1);
      final plain = RegExp(r'filename="([^"]+)"')
          .firstMatch(disposition)
          ?.group(1);
      String filename = plain ?? 'firstcase-$id';
      if (encoded != null) {
        try {
          filename = Uri.decodeComponent(encoded);
        } on FormatException {
          // Use the safe fallback if an intermediary corrupts the header.
        }
      }
      filename = filename.replaceAll('\\', '/').split('/').last;
      return (bytes: Uint8List.fromList(response.data!), filename: filename);
    } on DioException catch (error) {
      throw failure(error);
    }
  }
}
