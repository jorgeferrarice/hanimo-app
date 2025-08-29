import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/cache_provider.dart';

/// In-memory cache provider implementation
/// Stores cache data in memory with automatic expiration and cleanup
class MemoryCacheProvider implements CacheProvider {
  final Map<String, CacheEntry> _cache = {};
  Timer? _cleanupTimer;
  
  // Statistics tracking
  int _hits = 0;
  int _misses = 0;
  int _sets = 0;
  int _removes = 0;
  DateTime _lastAccess = DateTime.now();
  
  /// Maximum number of items to store in cache
  final int? maxSize;
  
  /// Default expiration duration for cache entries
  final Duration? defaultExpiration;
  
  /// Automatic cleanup interval
  final Duration cleanupInterval;
  
  MemoryCacheProvider({
    this.maxSize,
    this.defaultExpiration,
    this.cleanupInterval = const Duration(minutes: 5),
  }) {
    _startCleanupTimer();
  }
  
  /// Start the automatic cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(cleanupInterval, (_) => cleanup());
  }
  
  /// Stop the cleanup timer (call when disposing)
  void dispose() {
    _cleanupTimer?.cancel();
  }
  
  @override
  Future<T?> get<T>(String key) async {
    _lastAccess = DateTime.now();
    
    debugPrint('🧠 [MemoryCache] GET operation for key: $key');
    debugPrint('   • Cache size: ${_cache.length}');
    
    final entry = _cache[key];
    if (entry == null) {
      _misses++;
      debugPrint('❌ [MemoryCache] GET miss - key not found');
      return null;
    }
    
    // Check if expired
    if (entry.isExpired) {
      _cache.remove(key);
      _misses++;
      debugPrint('❌ [MemoryCache] GET miss - entry expired');
      debugPrint('   • Expired at: ${entry.expiration}');
      return null;
    }
    
    _hits++;
    debugPrint('✅ [MemoryCache] GET hit');
    debugPrint('   • Value type: ${entry.value.runtimeType}');
    debugPrint('   • Created: ${entry.createdAt}');
    return entry.value as T?;
  }
  
  @override
  Future<void> set<T>(String key, T value, {Duration? expiration}) async {
    _lastAccess = DateTime.now();
    
    debugPrint('🧠 [MemoryCache] SET operation for key: $key');
    debugPrint('   • Value type: ${value.runtimeType}');
    debugPrint('   • Cache size before: ${_cache.length}');
    
    // Use provided expiration or default
    final exp = expiration ?? defaultExpiration;
    debugPrint('   • Expiration: ${exp?.toString() ?? 'none'}');
    
    // Check if we need to make room
    if (maxSize != null && _cache.length >= maxSize! && !_cache.containsKey(key)) {
      debugPrint('🧠 [MemoryCache] Cache full, evicting oldest entry');
      _evictOldest();
    }
    
    _cache[key] = CacheEntry(
      value: value,
      createdAt: DateTime.now(),
      expiration: exp,
    );
    
    _sets++;
    debugPrint('✅ [MemoryCache] SET completed');
    debugPrint('   • Cache size after: ${_cache.length}');
  }
  
  @override
  Future<void> remove(String key) async {
    _lastAccess = DateTime.now();
    if (_cache.remove(key) != null) {
      _removes++;
    }
  }
  
  @override
  Future<void> clear() async {
    _lastAccess = DateTime.now();
    final count = _cache.length;
    _cache.clear();
    _removes += count;
  }
  
  @override
  Future<bool> containsKey(String key) async {
    final entry = _cache[key];
    if (entry == null) return false;
    
    // Check if expired
    if (entry.isExpired) {
      _cache.remove(key);
      return false;
    }
    
    return true;
  }
  
  @override
  Future<List<String>> getKeys() async {
    // Remove expired entries first
    await cleanup();
    return _cache.keys.toList();
  }
  
  @override
  Future<int> get size async {
    // Remove expired entries first
    await cleanup();
    return _cache.length;
  }
  
  @override
  Future<void> cleanup() async {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      _removes += expiredKeys.length;
    }
  }
  
  @override
  CacheStats get stats {
    return CacheStats(
      hits: _hits,
      misses: _misses,
      sets: _sets,
      removes: _removes,
      size: _cache.length,
      lastAccess: _lastAccess,
    );
  }
  
  /// Evict the oldest entry to make room for new ones
  void _evictOldest() {
    if (_cache.isEmpty) return;
    
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _cache.entries) {
      if (oldestTime == null || entry.value.createdAt.isBefore(oldestTime)) {
        oldestTime = entry.value.createdAt;
        oldestKey = entry.key;
      }
    }
    
    if (oldestKey != null) {
      _cache.remove(oldestKey);
      _removes++;
    }
  }
  
  /// Get detailed information about cache entries
  Map<String, Map<String, dynamic>> getDebugInfo() {
    final info = <String, Map<String, dynamic>>{};
    
    for (final entry in _cache.entries) {
      info[entry.key] = {
        'createdAt': entry.value.createdAt.toIso8601String(),
        'expiration': entry.value.expiration?.toString(),
        'isExpired': entry.value.isExpired,
        'timeToExpiry': entry.value.timeToExpiry?.toString(),
        'valueType': entry.value.value.runtimeType.toString(),
      };
    }
    
    return info;
  }
  
  /// Reset all statistics
  void resetStats() {
    _hits = 0;
    _misses = 0;
    _sets = 0;
    _removes = 0;
    _lastAccess = DateTime.now();
  }
} 