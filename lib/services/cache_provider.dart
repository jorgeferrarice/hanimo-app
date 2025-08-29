/// Abstract interface for cache providers
/// Defines the contract that all cache implementations must follow
abstract class CacheProvider {
  /// Get a value from the cache by key
  /// Returns null if the key doesn't exist or has expired
  Future<T?> get<T>(String key);
  
  /// Store a value in the cache with an optional expiration duration
  /// If no duration is provided, the item will not expire
  Future<void> set<T>(String key, T value, {Duration? expiration});
  
  /// Remove a specific item from the cache
  Future<void> remove(String key);
  
  /// Clear all items from the cache
  Future<void> clear();
  
  /// Check if a key exists in the cache and is not expired
  Future<bool> containsKey(String key);
  
  /// Get all keys in the cache
  Future<List<String>> getKeys();
  
  /// Get the number of items in the cache
  Future<int> get size;
  
  /// Remove all expired items from the cache
  Future<void> cleanup();
  
  /// Get cache statistics (hits, misses, etc.)
  CacheStats get stats;
}

/// Cache statistics for monitoring cache performance
class CacheStats {
  final int hits;
  final int misses;
  final int sets;
  final int removes;
  final int size;
  final DateTime lastAccess;
  
  const CacheStats({
    required this.hits,
    required this.misses,
    required this.sets,
    required this.removes,
    required this.size,
    required this.lastAccess,
  });
  
  /// Calculate hit ratio as a percentage
  double get hitRatio {
    final total = hits + misses;
    return total > 0 ? (hits / total) * 100 : 0.0;
  }
  
  @override
  String toString() {
    return 'CacheStats(hits: $hits, misses: $misses, hitRatio: ${hitRatio.toStringAsFixed(2)}%, size: $size)';
  }
}

/// Cache entry with expiration support
class CacheEntry<T> {
  final T value;
  final DateTime createdAt;
  final Duration? expiration;
  
  CacheEntry({
    required this.value,
    required this.createdAt,
    this.expiration,
  });
  
  /// Check if this cache entry has expired
  bool get isExpired {
    if (expiration == null) return false;
    return DateTime.now().difference(createdAt) > expiration!;
  }
  
  /// Get the remaining time until expiration
  Duration? get timeToExpiry {
    if (expiration == null) return null;
    final elapsed = DateTime.now().difference(createdAt);
    final remaining = expiration! - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
} 