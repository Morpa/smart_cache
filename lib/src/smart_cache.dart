import 'dart:async';

import 'database.dart';

/// A singleton cache management class that provides caching functionality with automatic maintenance.
///
/// The [SmartCache] class implements a caching mechanism with the following features:
/// * Singleton pattern ensuring only one instance exists
/// * Automatic periodic maintenance to clear expired entries
/// * Configurable default expiration time for cached items
/// * Configurable maintenance interval
///
/// Example usage:
/// ```dart
/// final cache = SmartCache(
///   defaultExpiration: Duration(minutes: 10),
///   maintenanceInterval: Duration(minutes: 30)
/// );
///
/// // Store data
/// await cache.set('key', someData);
///
/// // Retrieve data
/// final data = await cache.get<SomeType>('key');
/// ```
///
/// The cache automatically performs maintenance at regular intervals to remove expired entries.
/// You can also manually trigger maintenance by calling [maintenance()].
///
/// Don't forget to call [close()] when the cache is no longer needed to properly
/// dispose of resources and stop the maintenance timer.
class SmartCache {
  final AppDatabase _database = AppDatabase();
  final Duration defaultExpiration;
  Timer? _maintenanceTimer;
  final Duration _maintenanceInterval;

  static SmartCache? _instance;

  factory SmartCache({
    Duration defaultExpiration = const Duration(minutes: 10),
    Duration maintenanceInterval = const Duration(minutes: 30),
  }) {
    _instance ??= SmartCache._internal(
      defaultExpiration,
      maintenanceInterval,
    );
    return _instance!;
  }

  SmartCache._internal(this.defaultExpiration, this._maintenanceInterval) {
    _startPeriodicMaintenance();
  }

  void _startPeriodicMaintenance() {
    _maintenanceTimer?.cancel();
    _maintenanceTimer = Timer.periodic(_maintenanceInterval, (_) {
      maintenance();
    });
  }

  /// Stores data in the cache using a key-value pair.
  ///
  /// [key] The unique identifier for the cached data.
  /// [data] The data to be stored in the cache. Can be of any type.
  ///
  /// This method is asynchronous and returns a [Future] that completes
  /// when the data has been successfully stored in the cache.
  Future<void> set(String key, dynamic data) async {
    await _database.setCache(key, data);
  }

  /// Retrieves a cached value of type [T] associated with the given [key].
  ///
  /// Parameters:
  /// - [key]: The unique identifier for the cached value.
  /// - [expiration]: Optional custom expiration duration for this specific get operation.
  ///   If not provided, uses the default expiration time set for the cache.
  ///
  /// Returns a [Future] that completes with:
  /// - The cached value of type [T] if found and not expired
  /// - `null` if the key doesn't exist or the value has expired
  Future<T?> get<T>(String key, {Duration? expiration}) async {
    return await _database.getCache<T>(
      key,
      expirationTime: expiration ?? defaultExpiration,
    );
  }

  /// Clears all cached data from the database.
  ///
  /// This method removes all entries stored in the cache storage.
  /// Use this method when you need to invalidate the entire cache.
  /// Returns a [Future] that completes when the operation is finished.
  Future<void> clear() async {
    await _database.clearCache();
  }

  /// Performs maintenance operations on the cache.
  ///
  /// This method removes all expired entries from the cache storage based on
  /// the default expiration time. It should be called periodically to prevent
  /// the cache from growing indefinitely with stale data.
  ///
  /// This operation is asynchronous and returns a [Future] that completes
  /// when the maintenance is done.
  Future<void> maintenance() async {
    await _database.removeExpiredEntries(defaultExpiration);
  }

  /// Closes the cache and releases all resources.
  ///
  /// This method cancels the maintenance timer if it exists and closes the underlying database.
  /// Should be called when the cache is no longer needed to prevent memory leaks.
  ///
  /// The method is asynchronous and returns a [Future] that completes when all resources
  /// have been released.
  Future<void> close() async {
    _maintenanceTimer?.cancel();
    await _database.close();
  }

  /// Removes an entry from the database associated with the given [key].
  ///
  /// This method asynchronously deletes the entry identified by the [key]
  /// from the underlying database. If the key does not exist, no action
  /// is taken.
  ///
  /// [key]: The unique identifier for the entry to be removed.
  ///
  /// Returns a [Future] that completes when the removal operation is finished.
  Future<void> remove(String key) async {
    await _database.removeEntry(key);
  }

  /// Removes all entries from the database whose keys match the given pattern.
  ///
  /// This method retrieves all keys that match the specified [pattern] and
  /// iterates through them, removing each corresponding entry from the database.
  ///
  /// [pattern]: A string pattern used to match keys in the database.
  ///
  /// Returns a [Future] that completes when all matching entries have been removed.
  Future<void> removeByPattern(String pattern) async {
    final keys = await getKeysByPrefix(pattern);
    for (final key in keys) {
      await _database.removeEntry(key);
    }
  }

  /// Returns a list of all cache keys that start with the given prefix.
  ///
  /// This can be useful for finding all keys related to a specific category
  /// or feature in your application.
  ///
  /// [prefix]: The prefix to search for.
  ///
  /// Returns a [Future] that completes with a list of matching keys.
  Future<List<String>> getKeysByPrefix(String prefix) async {
    return await _database.getKeysByPattern('$prefix%');
  }
}
