import 'package:dio/dio.dart';
import 'package:smart_cache/src/smart_cache.dart';

/// An interceptor for handling caching in HTTP requests using SmartCache.
///
/// This interceptor works with Dio HTTP client to provide caching capabilities.
/// It can cache responses and serve cached data when available.
///
/// Usage:
/// ```dart
/// final dio = Dio();
/// final smartCache = SmartCache();
/// dio.interceptors.add(CacheInterceptor(smartCache));
/// ```
///
/// The interceptor will:
/// * Check if caching is enabled for the request (`options.extra['cache'] == true`)
/// * Use either specific cache expiration time or default one
/// * Serve cached response if available
/// * Store successful responses (status code 200) in cache
///
/// Parameters:
/// * [_smartCache] - The SmartCache instance to use for caching operations
/// * [defaultCacheExpiration] - Optional default duration for cache expiration
class CacheInterceptor extends Interceptor {
  CacheInterceptor(
    this._smartCache, {
    this.defaultCacheExpiration,
  });

  final SmartCache _smartCache;
  final Duration? defaultCacheExpiration;

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['cache'] == true) {
      final Duration expiration = options.extra['cacheExpiration'] != null
          ? options.extra['cacheExpiration'] as Duration
          : defaultCacheExpiration ?? _smartCache.defaultExpiration;

      final cachedData = await _smartCache.get(
        options.uri.toString(),
        expiration: expiration,
      );

      if (cachedData != null) {
        handler.resolve(Response(
          requestOptions: options,
          data: cachedData,
          statusCode: 200,
          extra: {
            'fromCache': true,
            'cacheTimestamp': DateTime.now(),
          },
        ));
        return;
      }
    }
    super.onRequest(options, handler);
  }

  @override
  Future<void> onResponse(
      Response response, ResponseInterceptorHandler handler) async {
    if (response.requestOptions.extra['cache'] == true &&
        response.statusCode == 200) {
      await _smartCache.set(
        response.requestOptions.uri.toString(),
        response.data,
      );
    }
    super.onResponse(response, handler);
  }
}
