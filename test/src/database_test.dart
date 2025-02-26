import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:smart_cache/src/database.dart';

class MockPathProvider extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '.';

  @override
  Future<String?> getApplicationCachePath() async => '.';

  @override
  Future<String?> getApplicationSupportPath() async => '.';

  @override
  Future<String?> getDownloadsPath() async => '.';

  @override
  Future<List<String>?> getExternalCachePaths() async => ['.'];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async =>
      ['.'];

  @override
  Future<String?> getLibraryPath() async => '.';
}

void main() {
  PathProviderPlatform.instance = MockPathProvider();
  late AppDatabase database;

  setUp(() {
    database = AppDatabase();
    WidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() async {
    await database.close();
  });

  group('AppDatabase', () {
    test('setCache and getCache work correctly', () async {
      final testData = {'name': 'John', 'age': 30};
      await database.setCache('test_key', testData);

      final result = await database.getCache<Map<String, dynamic>>('test_key');
      expect(result, testData);
    });

    test('getCache returns null for non-existent key', () async {
      final result = await database.getCache<Map>('non_existent_key');
      expect(result, null);
    });

    test('getCache returns null for expired data', () async {
      await database.setCache('expired_key', 'test_data');

      final result = await database.getCache<String>(
        'expired_key',
        expirationTime: Duration.zero,
      );
      expect(result, null);
    });

    test('clearCache removes all entries', () async {
      await database.setCache('key1', 'data1');
      await database.setCache('key2', 'data2');

      await database.clearCache();

      final result1 = await database.getCache<String>('key1');
      final result2 = await database.getCache<String>('key2');
      expect(result1, null);
      expect(result2, null);
    });

    test('removeExpiredEntries removes only expired entries', () async {
      await database.setCache('key1', 'data1');
      await Future.delayed(const Duration(seconds: 1));
      await database.setCache('key2', 'data2');

      await database.removeExpiredEntries(const Duration(milliseconds: 50));

      final result1 = await database.getCache<String>('key1');
      final result2 = await database.getCache<String>('key2');
      expect(result1, null);
      expect(result2, 'data2');
    });
  });
}
