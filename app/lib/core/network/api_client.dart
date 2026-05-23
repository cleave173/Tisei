import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_exception.dart';
import 'dio_client.dart';

/// Thin typed wrapper around `Dio` that converts errors to `ApiException`.
class ApiClient {
  ApiClient(this._dio);
  final Dio _dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final Response<dynamic> r = await _dio.get(path, queryParameters: query);
      return r.data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) async {
    try {
      final Response<dynamic> r =
          await _dio.post(path, data: body, queryParameters: query);
      return r.data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final Response<dynamic> r = await _dio.delete(path);
      return r.data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  return ApiClient(ref.read(dioProvider));
});
