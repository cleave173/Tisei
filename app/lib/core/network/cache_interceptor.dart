import 'package:dio/dio.dart';

import '../offline/connectivity_service.dart';
import '../offline/local_cache.dart';

/// Dio interceptor that:
/// - On GET response (200): stores body in SQLite with 48h TTL
/// - On any request (offline): serves cached body instead of hitting network
class CacheInterceptor extends Interceptor {
  static const Set<String> _skipPaths = <String>{
    '/auth/',
    '/users/me/avatar',
  };

  bool _shouldSkip(String path) =>
      _skipPaths.any((String s) => path.contains(s));

  String _cacheKey(RequestOptions options) {
    final Uri uri = options.uri;
    if (uri.query.isEmpty) return options.path;
    return '${options.path}?${uri.query}';
  }

  Duration _ttlFor(String path) {
    if (path.startsWith('/languages') ||
        path.startsWith('/words') ||
        path.startsWith('/lessons')) {
      return const Duration(days: 90);
    }
    if (path.startsWith('/achievements')) {
      return const Duration(days: 30);
    }
    return const Duration(days: 7);
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.method != 'GET' || _shouldSkip(options.path)) {
      return handler.next(options);
    }

    final bool online = await checkOnline();
    if (!online) {
      final LocalCache cache = await LocalCache.instance;
      final dynamic data = await cache.getStale(_cacheKey(options));
      if (data != null) {
        return handler.resolve(
          Response<dynamic>(requestOptions: options, data: data, statusCode: 200),
        );
      }
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'No internet connection and no cached data available.',
        ),
      );
    }
    return handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    if (response.requestOptions.method == 'GET' &&
        response.statusCode == 200 &&
        !_shouldSkip(response.requestOptions.path)) {
      final LocalCache cache = await LocalCache.instance;
      await cache.put(
        _cacheKey(response.requestOptions),
        response.data,
        ttl: _ttlFor(response.requestOptions.path),
      );
    }
    return handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions options = err.requestOptions;
    if (options.method == 'GET' && !_shouldSkip(options.path)) {
      final LocalCache cache = await LocalCache.instance;
      final dynamic data = await cache.getStale(_cacheKey(options));
      if (data != null) {
        return handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            data: data,
            statusCode: 200,
          ),
        );
      }
    }
    return handler.next(err);
  }
}
