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
```

## Uso

### Uso Básico

```dart
// Storing data
await smartCache.set('chave', meusDados);

// Data recovery
final dados = await smartCache.get<Map<String, dynamic>>('chave');

// Clear all cache
await smartCache.clear();

// Close the database connection
await smartCache.close();
```

### Uso com Dio

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

// Check if the data came from the cache
final fromCache = resposta.extra['fromCache'] == true;
```

### Example with Personalized Client

```dart
class ApiClient {
  final dio = Dio();
  final cache = SmartCache();
  
  ApiClient() {
    dio.interceptors.add(CacheInterceptor(cache));
  }
  
  Future<Map<String, dynamic>> getPerfil(int userId) async {
    // Profile data with 1-hour cache
    final response = await dio.get(
      '/users/$userId',
      options: Options(extra: {
        'cache': true,
        'cacheExpiration': Duration(hours: 1),
      }),
    );
    
    return response.data;
  }
  
  Future<List<Map<String, dynamic>>> getAtualizacoes() async {
    // Short cache updates (30 seconds)
    final response = await dio.get(
      '/updates',
      options: Options(extra: {
        'cache': true,
        'cacheExpiration': Duration(seconds: 30),
      }),
    );
    
    return List<Map<String, dynamic>>.from(response.data);
  }
}
```

## Resources

- ✅ SQLite-based persistent cache
- ✅ Configurable expiration per endpoint
- ✅ Automatic cleaning of expired cache
- ✅ Simple integration with Dio
- ✅ Easy-to-use API

## Notes

- The cache is cleared automatically according to the configured interval
- The connection to the database must be closed when the app is closed
- Default expiration time: 10 minutes
- Default maintenance interval: 30 minutes

## 🚀 Contributing

Contributions are welcome! Please submit pull requests with any improvements or bug fixes.

## 📝 License

This project is licensed under the BSD 3 License - see the [LICENSE](LICENSE) file for details.
