# SmartCache

A simple and efficient caching solution for Flutter applications using SQLite.

## Installation

```yaml
dependencies:
  smart_cache: ^1.0.0
  dio: ^5.0.0  # If used with the Dio interceptor
```

Execute:

```bash
flutter pub get
```

## Configuration

### Basic Configuration

```dart
// Initialize the cache with default values
final cache = SmartCache();

// Or configure with custom options
final cache = SmartCache(
  defaultExpiration: Duration(minutes: 30),    // Default expiration time
  maintenanceInterval: Duration(hours: 1),     // Automatic cleaning interval
);
```

### Dio Integration

```dart
import 'package:dio/dio.dart';
import 'package:smart_cache/smart_cache.dart';

// Create a Dio instance
final dio = Dio();

// Create and configure SmartCache
final smartCache = SmartCache();

// Add the cache interceptor to Dio
dio.interceptors.add(CacheInterceptor(smartCache));

// Optionally, provide a custom key builder function
dio.interceptors.add(CacheInterceptor(
  smartCache,
  defaultCacheKeyBuilder: (options) => '${options.method}_${options.uri.path}',
));
```

## How to Use

### Basic Usage

```dart
// Storing data
await smartCache.set('chave', meusDados);

// Data recovery
final dados = await smartCache.get<Map<String, dynamic>>('chave');

// Remove specific cache entry
await smartCache.remove('key');

// Remove multiple cache entries by pattern
await smartCache.removeByPattern('%/users/%');

// Clear all cache
await smartCache.clear();

// Close the database connection
await smartCache.close();
```

### Example with Dio

```dart
// Request without cache
final resposta = await dio.get('https://api.exemplo.com/dados');

// Cached request (default expiration)
final resposta = await dio.get(
  'https://api.exemplo.com/dados',
  options: Options(extra: {'cache': true}),
);

// Request with cache and personalized expiration
final resposta = await dio.get(
  'https://api.exemplo.com/dados',
  options: Options(extra: {
    'cache': true,
    'cacheExpiration': Duration(minutes: 5),
  }),
);

// Request with custom cache key
final resposta = await dio.get(
  'https://api.exemplo.com/dados',
  options: Options(extra: {
    'cache': true,
    'cacheKey': 'dados_principais_v1',
  }),
);

// Check if the data came from the cache
final fromCache = resposta.extra['fromCache'] == true;
```

### Cache Invalidation

```dart
// Direct invalidation using SmartCache
final cache = SmartCache();
await cache.remove('https://api.exemplo.com/amigos');

// Using CacheInterceptor with URL-based key
final smartCache = SmartCache();
final cacheInterceptor = CacheInterceptor(smartCache);
dio.interceptors.add(cacheInterceptor);

// Invalidate specific cache entry (URL-based)
await cacheInterceptor.invalidateCacheForUrl('https://api.exemplo.com/amigos');

// Invalidate using custom key
await cacheInterceptor.invalidateCache('dados_principais_v1');

// Or create a dedicated cache manager
class CacheManager {
  final SmartCache _smartCache;

  CacheManager(this._smartCache);

  Future<void> invalidateCache(String key) async {
    await _smartCache.remove(key);
  }

  Future<void> invalidateCachesByPattern(String pattern) async {
    await _smartCache.removeByPattern(pattern);
  }
}
```

### Example with Personalized Client

```dart
class ApiClient {
  final dio = Dio();
  final cache = SmartCache();
  final CacheManager cacheManager;
  
  ApiClient() {
    dio.interceptors.add(CacheInterceptor(cache));
    cacheManager = CacheManager(cache);
  }
  
  Future<Map<String, dynamic>> getPerfil(int userId) async {
    // Profile data with 1-hour cache and custom key
    final response = await dio.get(
      '/users/$userId',
      options: Options(extra: {
        'cache': true,
        'cacheExpiration': Duration(hours: 1),
        'cacheKey': 'user_profile_$userId',
      }),
    );
    
    return response.data;
  }
  
  Future<void> updatePerfil(int userId, Map<String, dynamic> data) async {
    final response = await dio.put('/users/$userId', data: data);
    
    if (response.statusCode == 200) {
      // Invalidate user profile cache after update using custom key
      await cacheManager.invalidateCache('user_profile_$userId');
      
      // Or invalidate all user-related caches
      await cacheManager.invalidateCachesByPattern('%user_profile_%');
    }
  }
  
  Future<List<Map<String, dynamic>>> getAtualizacoes() async {
    // Short cache updates (30 seconds) with versioned key
    final response = await dio.get(
      '/updates',
      options: Options(extra: {
        'cache': true,
        'cacheExpiration': Duration(seconds: 30),
        'cacheKey': 'updates_feed_v2', // Versioned key for easier invalidation
      }),
    );
    
    return List<Map<String, dynamic>>.from(response.data);
  }
}
```

### Dependency Injection Example

```dart
@module
abstract class NetworkModule {
  @singleton
  SmartCache smartCache() => SmartCache(maintenanceInterval: const Duration(days: 1));

  @singleton
  CacheManager cacheManager(SmartCache smartCache) => CacheManager(smartCache);

  @singleton
  CacheInterceptor cacheInterceptor(SmartCache smartCache) => CacheInterceptor(
    smartCache,
    defaultCacheKeyBuilder: (options) {
      // Custom key building strategy for all requests
      final endpoint = options.uri.path.replaceAll('/', '_');
      return '${options.method}$endpoint';
    },
  );

  @singleton
  Dio dio(
    AuthInterceptor authInterceptor,
    CacheInterceptor cacheInterceptor,
    // Other interceptors
  ) {
    final dio = Dio();
    dio.interceptors.add(authInterceptor);
    dio.interceptors.add(cacheInterceptor);
    // Add other interceptors
    return dio;
  }
}
```

## Resources

- ✅ SQLite-based persistent cache
- ✅ Configurable expiration per endpoint
- ✅ Automatic cleaning of expired cache
- ✅ Cache invalidation by key or pattern
- ✅ Custom cache keys for better organization
- ✅ Customizable key generation strategies
- ✅ Simple integration with Dio
- ✅ Easy-to-use API
- ✅ Support for dependency injection

## Notes

- The cache is cleared automatically according to the configured interval
- The connection to the database must be closed when the app is closed
- Default expiration time: 10 minutes
- Default maintenance interval: 30 minutes
- Use cache invalidation after creating or updating resources to ensure fresh data
- Custom cache keys allow for more flexible caching strategies and easier invalidation

## 🚀 Contributing

Contributions are welcome! Please submit pull requests with any improvements or bug fixes.

## 📝 License

This project is licensed under the BSD 3 License - see the [LICENSE](LICENSE) file for details.