import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// Represents a database table for caching entries.
///
/// This table stores cached data with the following columns:
/// * [key] - A unique text identifier serving as the primary key
/// * [data] - The cached data stored as text
/// * [timestamp] - The date and time when the cache entry was created/updated
class CacheEntries extends Table {
  TextColumn get key => text()();
  TextColumn get data => text()();
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [CacheEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  /// Stores data in the cache using a key-value pair.
  ///
  /// The [key] is used as a unique identifier for the cached data.
  /// The [data] parameter can be any JSON-serializable object.
  /// Data is stored with a timestamp of when it was cached.
  ///
  /// If an entry with the same key exists, it will be replaced.
  ///
  /// Example:
  /// ```dart
  /// await cache.setCache('user_profile', {
  ///   'name': 'John',
  ///   'age': 30
  /// });
  /// ```
  Future<void> setCache(String key, dynamic data) async {
    final entry = CacheEntriesCompanion.insert(
      key: key,
      data: jsonEncode(data),
      timestamp: DateTime.now(),
    );

    await into(cacheEntries).insert(
      entry,
      mode: InsertMode.replace, // Replaces if it already exists
    );
  }

  /// Retrieves cached data associated with the given [key].
  ///
  /// Returns a Future that completes with the cached value of type [T], or null if:
  /// * The key doesn't exist in the cache
  /// * The cached data has expired based on [expirationTime]
  ///
  /// Parameters:
  /// * [key] - The unique identifier for the cached data
  /// * [expirationTime] - Optional duration after which the cache is considered expired
  ///   (defaults to 10 minutes)
  ///
  /// The method automatically removes expired entries from the cache when detected.
  /// The cached data is stored as JSON and decoded back to type [T] on retrieval.
  Future<T?> getCache<T>(
    String key, {
    Duration expirationTime = const Duration(minutes: 10),
  }) async {
    final query = select(cacheEntries)..where((tbl) => tbl.key.equals(key));
    final entry = await query.getSingleOrNull();

    if (entry == null) return null;

    if (DateTime.now().isAfter(entry.timestamp.add(expirationTime))) {
      await (delete(cacheEntries)..where((tbl) => tbl.key.equals(key))).go();
      return null;
    }

    return jsonDecode(entry.data) as T?;
  }

  /// Removes all entries from the cache by deleting all records from the cache entries table.
  ///
  /// This operation is asynchronous and returns a [Future] that completes when the cache
  /// has been cleared successfully.
  Future<void> clearCache() async {
    await delete(cacheEntries).go();
  }

  /// Removes all entries from the cache that have exceeded their expiration time.
  ///
  /// This method deletes cache entries whose timestamp is older than the current time
  /// minus the specified [expirationTime].
  ///
  /// Parameters:
  ///   - [expirationTime]: The duration after which entries are considered expired
  ///     and should be removed from the cache.
  ///
  /// The deletion is performed asynchronously and returns a [Future] that completes
  /// when the operation is finished.
  Future<void> removeExpiredEntries(Duration expirationTime) async {
    final cutoffTime = DateTime.now().subtract(expirationTime);
    await (delete(cacheEntries)
          ..where((tbl) => tbl.timestamp.isSmallerThanValue(cutoffTime)))
        .go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'smart_cache.sqlite'));
    return NativeDatabase(file);
  });
}
