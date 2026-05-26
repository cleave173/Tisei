import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/env.dart';
import '../utils/auth_event_bus.dart';
import 'cache_interceptor.dart';

const String kAccessTokenKey = 'access_token';
const String kRefreshTokenKey = 'refresh_token';

final Provider<FlutterSecureStorage> secureStorageProvider =
    Provider<FlutterSecureStorage>((Ref ref) => const FlutterSecureStorage());

final Provider<Dio> dioProvider = Provider<Dio>((Ref ref) {
  final FlutterSecureStorage storage = ref.read(secureStorageProvider);

  // A plain Dio used only for the refresh call (avoids recursive interceptors)
  final Dio refreshDio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: <String, String>{'Content-Type': 'application/json'},
    ),
  );

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: <String, String>{'Content-Type': 'application/json'},
    ),
  );

  // Attach access token to every request
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
        final String? token = await storage.read(key: kAccessTokenKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  // Auto-refresh on 401 — uses a QueuedInterceptorsWrapper so parallel
  // requests are serialised and only one refresh call is made.
  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onError: (DioException error, ErrorInterceptorHandler handler) async {
        // Skip 401s on the refresh endpoint itself to avoid infinite loop
        final String path = error.requestOptions.path;
        if (error.response?.statusCode != 401 ||
            path.contains('/auth/refresh') ||
            path.contains('/auth/login')) {
          return handler.next(error);
        }

        try {
          final String? refreshToken = await storage.read(key: kRefreshTokenKey);
          if (refreshToken == null || refreshToken.isEmpty) {
            throw Exception('No refresh token stored');
          }

          final Response<dynamic> resp = await refreshDio.post(
            '/api/v1/auth/refresh',
            data: <String, String>{'refresh_token': refreshToken},
          );

          final String newAccess = resp.data['access_token'] as String;
          final String newRefresh = resp.data['refresh_token'] as String;

          await storage.write(key: kAccessTokenKey, value: newAccess);
          await storage.write(key: kRefreshTokenKey, value: newRefresh);

          // Retry the original request with the new access token
          final RequestOptions opts = error.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccess';
          final Response<dynamic> retried = await dio.fetch(opts);
          return handler.resolve(retried);
        } catch (_) {
          // Both tokens invalid — clear storage and signal the app to log out
          await storage.deleteAll();
          AuthEventBus.sessionExpired();
          return handler.next(error);
        }
      },
    ),
  );

  dio.interceptors.add(CacheInterceptor());

  dio.interceptors.add(
    PrettyDioLogger(
      requestHeader: false,
      requestBody: true,
      responseBody: false,
      responseHeader: false,
      compact: true,
    ),
  );

  return dio;
});
