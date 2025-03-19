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
/// To use custom cache keys:
/// ```dart
/// dio.get('https://api.example.com/data',
///   options: Options(
///     extra: {
///       'cache': true,
///       'cacheKey': 'custom_key_name',
///     }
///   )
/// );
/// ```
///
/// The interceptor will:
/// * Check if caching is enabled for the request (`options.extra['cache'] == true`)
/// * Use a custom cache key if provided or generate one based on the URL
/// * Use either specific cache expiration time or default one
/// * Serve cached response if available
/// * Store successful responses (status code 200) in cache
///
/// Parameters:
/// * [_smartCache] - The SmartCache instance to use for caching operations
/// * [defaultCacheExpiration] - Optional default duration for cache expiration
/// * [defaultCacheKeyBuilder] - Optional function to customize how cache keys are generated
class CacheInterceptor extends Interceptor {
  CacheInterceptor(
    this._smartCache, {
    this.defaultCacheExpiration,
    this.defaultCacheKeyBuilder,
  });

  final SmartCache _smartCache;
  final Duration? defaultCacheExpiration;

  /// Function to build cache keys based on request options
  final String Function(RequestOptions options)? defaultCacheKeyBuilder;

  /// Builds a cache key for the given request options
  String _buildCacheKey(RequestOptions options) {
    // Use a custom key if provided in request options
    if (options.extra.containsKey('cacheKey')) {
      return options.extra['cacheKey'] as String;
    }

    // Use the custom key builder if provided
    if (defaultCacheKeyBuilder != null) {
      return defaultCacheKeyBuilder!(options);
    }

    // Default to using the URL as the cache key
    return options.uri.toString();
  }

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['cache'] == true) {
      final Duration expiration = options.extra['cacheExpiration'] != null
          ? options.extra['cacheExpiration'] as Duration
          : defaultCacheExpiration ?? _smartCache.defaultExpiration;

      final String cacheKey = _buildCacheKey(options);

      final cachedData = await _smartCache.get(
        cacheKey,
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
            'cacheKey': cacheKey,
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
      final String cacheKey = _buildCacheKey(response.requestOptions);

      await _smartCache.set(
        cacheKey,
        response.data,
      );

      // Add the cache key to the response extra data for reference
      response.extra['cacheKey'] = cacheKey;
    }
    super.onResponse(response, handler);
  }

  /// Invalidates the cache for a specific key.
  ///
  /// This method removes the cached data associated with the given [cacheKey]
  /// from the smart cache. It is an asynchronous operation and will
  /// complete once the cache entry is successfully removed.
  ///
  /// [cacheKey]: The cache key whose entry needs to be invalidated.
  Future<void> invalidateCache(String cacheKey) async {
    await _smartCache.remove(cacheKey);
  }

  /// Invalidates the cache for a specific URL, using the default key generation.
  ///
  /// This method is a convenience method that builds a cache key based on the URL
  /// and removes the corresponding cache entry.
  ///
  /// [url]: The URL whose cache entry needs to be invalidated.
  Future<void> invalidateCacheForUrl(String url) async {
    final RequestOptions dummyOptions = RequestOptions(path: url);
    final String cacheKey = _buildCacheKey(dummyOptions);
    await _smartCache.remove(cacheKey);
  }
}
