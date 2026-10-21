import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../shared/models/models.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/generated/app_localizations_ky.dart';
import '../l10n/generated/app_localizations_ru.dart';

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
                defaultValue: kIsWeb
                    ? '/api/v1'
                    : 'http://localhost:8000/api/v1',
              ),
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );
  final Dio dio;
  String language = 'ru';
  AppLocalizations get messages =>
      language == 'ky' ? AppLocalizationsKy() : AppLocalizationsRu();
  Map<String, String> get _headers => {
    'Accept-Language': language,
    if (token != null) 'Authorization': 'Bearer $token',
  };
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
    bool identityScoped = true,
  }) async {
    final epoch = identityEpoch;
    try {
      final response = await dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          extra: {'identity_epoch': identityScoped ? epoch : null},
          headers: identityScoped ? _headers : {'Accept-Language': language},
        ),
      );
      if (identityScoped && identityEpoch != epoch) {
        throw ApiFailure(messages.errorSessionExpired);
      }
      return response.data;
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
              401 => messages.errorSessionExpired,
              403 => messages.errorForbidden,
              404 => messages.errorNotFound,
              409 => messages.errorConflict,
              422 => messages.errorValidation,
              final int code when code >= 500 => messages.errorServer,
              _ => messages.errorNetwork,
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
    final epoch = identityEpoch;
    try {
      final response = await dio.get<List<int>>(
        path ?? '/uploads/$id',
        options: Options(
          extra: {'identity_epoch': epoch},
          responseType: ResponseType.bytes,
          headers: _headers,
        ),
      );
      if (identityEpoch != epoch) {
        throw ApiFailure(messages.errorSessionExpired);
      }
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
