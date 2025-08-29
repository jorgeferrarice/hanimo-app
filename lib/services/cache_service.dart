import 'package:flutter/foundation.dart';
import 'cache_provider.dart';
import '../providers/cache_provider_factory.dart';
import 'remote_config_service.dart';

/// Cache service that provides a unified interface for caching operations
/// Supports multiple cache providers in priority order defined by Remote Config
class CacheService {
  static CacheService? _instance;
  static CacheService get instance => _instance ??= CacheService._();
  
  CacheService._();
  
  List<CacheProvider> _providers = [];
  DateTime? _lastProviderCheck;
  
  /// Duration to check for provider changes (every 30 seconds)
  static const Duration _providerCheckInterval = Duration(seconds: 30);
  
  /// Initialize the cache service with Remote Config
  Future<void> initialize() async {
    debugPrint('💾 [CacheService] Initializing multi-provider cache service...');
    
    try {
      // Initialize Remote Config first
      debugPrint('💾 [CacheService] Initializing Remote Config...');
      await RemoteConfigService.instance.initialize();
      debugPrint('✅ [CacheService] Remote Config initialized');
      
      // Create initial providers
      debugPrint('💾 [CacheService] Creating initial cache providers...');
      await _ensureProviders();
      debugPrint('✅ [CacheService] Cache service initialization completed');
      debugPrint('   • Active providers: ${_providers.map((p) => p.runtimeType.toString()).join(', ')}');
    } catch (e, stackTrace) {
      debugPrint('❌ [CacheService] Failed to initialize cache service: $e');
      debugPrint('   • Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Ensure we have valid providers, checking Remote Config periodically
  Future<void> _ensureProviders() async {
    final now = DateTime.now();
    
    // Check if we need to update the providers
    bool shouldUpdate = _providers.isEmpty ||
        _lastProviderCheck == null ||
        now.difference(_lastProviderCheck!) >= _providerCheckInterval;
    
    if (shouldUpdate) {
      debugPrint('💾 [CacheService] Checking providers status...');
      debugPrint('   • Current providers: ${_providers.length}');
      debugPrint('   • Last check: ${_lastProviderCheck?.toString() ?? 'never'}');
      debugPrint('   • Should update: $shouldUpdate');
      
      // Get cache providers configuration from Remote Config
      final providersConfig = await _getCacheProvidersConfig();
      debugPrint('   • Providers config: $providersConfig');
      
      // Check if we need to recreate providers
      final needsRecreation = await _shouldRecreateProviders(providersConfig);
      debugPrint('   • Needs recreation: $needsRecreation');
      
      if (needsRecreation) {
        debugPrint('💾 [CacheService] Creating/recreating cache providers...');
        try {
          await _createProviders(providersConfig);
          debugPrint('✅ [CacheService] Providers created successfully');
          debugPrint('   • Active providers: ${_providers.map((p) => p.runtimeType.toString()).join(', ')}');
        } catch (e, stackTrace) {
          debugPrint('❌ [CacheService] Failed to create providers: $e');
          debugPrint('   • Stack trace: $stackTrace');
          rethrow;
        }
      }
      
      _lastProviderCheck = now;
    }
  }
  
  /// Get cache providers configuration from Remote Config
  Future<List<CacheProviderType>> _getCacheProvidersConfig() async {
    try {
      // Get the comma-separated list of cache providers from Remote Config
      final remoteConfig = RemoteConfigService.instance;
      final providersString = await remoteConfig.getString('CACHE_PROVIDERS', defaultValue: 'memory');
      
      debugPrint('💾 [CacheService] Raw providers config: "$providersString"');
      
      // Parse the comma-separated string
      final providerNames = providersString
          .split(',')
          .map((name) => name.trim().toLowerCase())
          .where((name) => name.isNotEmpty)
          .toList();
      
      debugPrint('💾 [CacheService] Parsed provider names: $providerNames');
      
      // Convert to enum values
      final providers = <CacheProviderType>[];
      for (final name in providerNames) {
        switch (name) {
          case 'memory':
            providers.add(CacheProviderType.memory);
            break;
          case 'r2':
            providers.add(CacheProviderType.r2);
            break;
          case 'sqlite':
            providers.add(CacheProviderType.sqlite);
            break;
          default:
            debugPrint('⚠️  [CacheService] Unknown provider type: $name, skipping');
        }
      }
      
      // Fallback to memory if no valid providers found
      if (providers.isEmpty) {
        debugPrint('⚠️  [CacheService] No valid providers found, falling back to memory');
        providers.add(CacheProviderType.memory);
      }
      
      debugPrint('💾 [CacheService] Final provider types: ${providers.map((p) => p.name).join(', ')}');
      return providers;
    } catch (e, stackTrace) {
      debugPrint('❌ [CacheService] Error getting providers config: $e');
      debugPrint('   • Stack trace: $stackTrace');
      // Fallback to memory provider
      return [CacheProviderType.memory];
    }
  }
  
  /// Check if providers need to be recreated
  Future<bool> _shouldRecreateProviders(List<CacheProviderType> configTypes) async {
    if (_providers.isEmpty) return true;
    
    // Check if the number of providers changed
    if (_providers.length != configTypes.length) return true;
    
    // Check if provider types changed (order matters)
    for (int i = 0; i < _providers.length; i++) {
      final currentType = _getProviderType(_providers[i]);
      final configType = configTypes[i];
      if (currentType != configType) return true;
    }
    
    return false;
  }
  
  /// Get the provider type from a provider instance
  CacheProviderType _getProviderType(CacheProvider provider) {
    if (provider.toString().contains('R2CacheProvider')) {
      return CacheProviderType.r2;
    } else if (provider.toString().contains('SQLiteCacheProvider')) {
      return CacheProviderType.sqlite;
    } else {
      return CacheProviderType.memory;
    }
  }
  
  /// Create providers based on configuration
  Future<void> _createProviders(List<CacheProviderType> providerTypes) async {
    // Dispose existing providers
    await _disposeProviders();
    
    final factory = CacheProviderFactory.instance;
    final newProviders = <CacheProvider>[];
    
    for (final providerType in providerTypes) {
      try {
        debugPrint('💾 [CacheService] Creating ${providerType.name} provider...');
        final provider = await factory.createProviderOfType(providerType);
        newProviders.add(provider);
        debugPrint('✅ [CacheService] ${providerType.name} provider created successfully');
      } catch (e, stackTrace) {
        debugPrint('❌ [CacheService] Failed to create ${providerType.name} provider: $e');
        debugPrint('   • Stack trace: $stackTrace');
        
        // For R2 provider, we can continue without it (graceful degradation)
        if (providerType == CacheProviderType.r2) {
          debugPrint('⚠️  [CacheService] Continuing without R2 provider');
          continue;
        }
        
        // For SQLite provider, we can continue without it (graceful degradation)
        if (providerType == CacheProviderType.sqlite) {
          debugPrint('⚠️  [CacheService] Continuing without SQLite provider');
          continue;
        }
        
        // For memory provider, this is critical - rethrow
        if (providerType == CacheProviderType.memory) {
          rethrow;
        }
      }
    }
    
    // Ensure we have at least one provider (memory as fallback)
    if (newProviders.isEmpty) {
      debugPrint('⚠️  [CacheService] No providers created, creating fallback memory provider');
      final memoryProvider = await factory.createProviderOfType(CacheProviderType.memory);
      newProviders.add(memoryProvider);
    }
    
    _providers = newProviders;
  }
  
  /// Dispose all providers
  Future<void> _disposeProviders() async {
    for (final provider in _providers) {
      try {
        if (provider.toString().contains('MemoryCacheProvider')) {
          (provider as dynamic).dispose();
        } else if (provider.toString().contains('SQLiteCacheProvider')) {
          await (provider as dynamic).dispose();
        }
      } catch (e) {
        debugPrint('⚠️  [CacheService] Error disposing provider: $e');
      }
    }
    _providers.clear();
  }
  
  /// Store a value in ALL cache providers to ensure consistency
  Future<void> set<T>(String key, T value, {Duration? expiration}) async {
    await _ensureProviders();
    
    if (_providers.isEmpty) {
      throw Exception('No cache providers available');
    }
    
    debugPrint('💾 [CacheService] SET operation for key: $key');
    debugPrint('   • Value type: ${value.runtimeType}');
    debugPrint('   • Expiration: ${expiration?.toString() ?? 'default'}');
    debugPrint('   • Providers: ${_providers.map((p) => p.runtimeType.toString()).join(', ')}');
    
    final startTime = DateTime.now();
    final results = <String, dynamic>{};
    
    // Set value in all providers in parallel
    final futures = _providers.asMap().entries.map((entry) async {
      final index = entry.key;
      final provider = entry.value;
      final providerType = _getProviderType(provider).name;
      
      try {
        debugPrint('💾 [CacheService] Setting in ${providerType} provider (${index + 1}/${_providers.length})...');
        final providerStartTime = DateTime.now();
        
        await provider.set(key, value, expiration: expiration);
        
        final providerDuration = DateTime.now().difference(providerStartTime);
        results[providerType] = 'success (${providerDuration.inMilliseconds}ms)';
        debugPrint('✅ [CacheService] SET successful in ${providerType} provider');
      } catch (e, stackTrace) {
        debugPrint('❌ [CacheService] SET failed in ${providerType} provider: $e');
        results[providerType] = 'failed: $e';
        
        // Check if this is a serialization error with R2 cache
        if (providerType == 'r2' && (
            e is UnsupportedError || 
            e.toString().contains('built_value objects cannot be serialized') ||
            e.toString().contains('Converting object to an encodable object failed') ||
            e.toString().contains('Complex object cannot be JSON encoded'))) {
          debugPrint('⚠️  [CacheService] R2 cache serialization issue for key: $key');
          debugPrint('   • Object type: ${value.runtimeType}');
          debugPrint('   • This is expected for complex objects');
        }
        // Continue with other providers even if one fails
      }
    });
    
    await Future.wait(futures);
    
    final totalDuration = DateTime.now().difference(startTime);
    debugPrint('💾 [CacheService] SET operation completed for key: $key');
    debugPrint('   • Total duration: ${totalDuration.inMilliseconds}ms');
    debugPrint('   • Results: $results');
  }
  
  /// Retrieve a value from cache providers in priority order (first hit wins)
  /// When data is found in a lower-priority provider, it's promoted to higher-priority providers
  Future<T?> get<T>(String key) async {
    await _ensureProviders();
    
    if (_providers.isEmpty) {
      debugPrint('❌ [CacheService] No cache providers available for key: "$key"');
      _debugLogCacheQuery(key, null, 'NO_PROVIDERS', 0);
      return null;
    }
    
    debugPrint('🔍 [CacheService] QUERY: "$key"');
    debugPrint('   • Providers: ${_providers.map((p) => _getProviderType(p).name).join(' → ')}');
    
    final startTime = DateTime.now();
    final providerResults = <String>[];
    final missProviders = <CacheProvider>[];
    
    // Try providers in order until we find the value
    for (int i = 0; i < _providers.length; i++) {
      final provider = _providers[i];
      final providerType = _getProviderType(provider).name;
      
      try {
        debugPrint('🔍 [CacheService] Checking ${providerType} provider (${i + 1}/${_providers.length}) for key: "$key"');
        final providerStartTime = DateTime.now();
        
        final result = await provider.get<T>(key);
        final providerDuration = DateTime.now().difference(providerStartTime);
        
        if (result != null) {
          final totalDuration = DateTime.now().difference(startTime);
          providerResults.add('${providerType}:HIT');
          
          debugPrint('🎯 [CacheService] CACHE HIT! Key: "$key" found in ${providerType} provider');
          debugPrint('   • Provider duration: ${providerDuration.inMilliseconds}ms');
          debugPrint('   • Total duration: ${totalDuration.inMilliseconds}ms');
          debugPrint('   • Result type: ${result.runtimeType}');
          debugPrint('   • Hit at priority level: ${i + 1}/${_providers.length}');
          
          // Cache promotion: back-fill higher-priority providers that had misses
          if (missProviders.isNotEmpty) {
            debugPrint('🔄 [CacheService] CACHE PROMOTION: Back-filling ${missProviders.length} higher-priority providers');
            _promoteCacheValue(key, result, missProviders);
          }
          
          // Log the successful query with debug information
          _debugLogCacheQuery(key, providerType, 'HIT', totalDuration.inMilliseconds);
          
          return result;
        } else {
          providerResults.add('${providerType}:MISS');
          missProviders.add(provider);
          debugPrint('❌ [CacheService] Cache MISS in ${providerType} provider for key: "$key"');
          debugPrint('   • Duration: ${providerDuration.inMilliseconds}ms');
        }
      } catch (e, stackTrace) {
        providerResults.add('${providerType}:ERROR');
        debugPrint('💥 [CacheService] ERROR in ${providerType} provider for key: "$key": $e');
        // Continue to next provider
      }
    }
    
    final totalDuration = DateTime.now().difference(startTime);
    debugPrint('💀 [CacheService] CACHE MISS! Key: "$key" not found in any provider');
    debugPrint('   • Total duration: ${totalDuration.inMilliseconds}ms');
    debugPrint('   • Provider results: ${providerResults.join(', ')}');
    
    // Log the failed query with debug information
    _debugLogCacheQuery(key, null, 'MISS_ALL', totalDuration.inMilliseconds);
    
    return null;
  }
  
  /// Promote cache value to higher-priority providers that had misses
  /// This runs asynchronously in the background to avoid blocking the get operation
  void _promoteCacheValue<T>(String key, T value, List<CacheProvider> targetProviders) {
    // Run promotion asynchronously in the background
    Future.microtask(() async {
      final promotionStartTime = DateTime.now();
      final promotionResults = <String>[];
      
      // Promote to all target providers in parallel
      final futures = targetProviders.map((provider) async {
        final providerType = _getProviderType(provider).name;
        try {
          final providerStartTime = DateTime.now();
          await provider.set(key, value);
          final providerDuration = DateTime.now().difference(providerStartTime);
          
          promotionResults.add('${providerType}:SUCCESS');
          debugPrint('⬆️  [CacheService] PROMOTION SUCCESS: "$key" → ${providerType} (${providerDuration.inMilliseconds}ms)');
        } catch (e) {
          promotionResults.add('${providerType}:ERROR');
          debugPrint('❌ [CacheService] PROMOTION ERROR: "$key" → ${providerType}: $e');
        }
      });
      
      await Future.wait(futures);
      
      final totalPromotionDuration = DateTime.now().difference(promotionStartTime);
      debugPrint('🔄 [CacheService] CACHE PROMOTION COMPLETED for "$key"');
      debugPrint('   • Promoted to: ${targetProviders.map((p) => _getProviderType(p).name).join(', ')}');
      debugPrint('   • Duration: ${totalPromotionDuration.inMilliseconds}ms');
      debugPrint('   • Results: ${promotionResults.join(', ')}');
      
      // Debug log the promotion operation
      final timestamp = DateTime.now().toIso8601String().substring(11, 23);
      debugPrint('📊 [CACHE_DEBUG] $timestamp | KEY: "$key" | STATUS: 🔄 PROMOTION | ${totalPromotionDuration.inMilliseconds}ms | ${promotionResults.length} providers');
    });
  }
  
  /// Debug log cache query results with key, provider, and hit/miss status
  void _debugLogCacheQuery(String key, String? hitProvider, String status, int durationMs) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23); // HH:mm:ss.SSS
    final providerInfo = hitProvider != null ? ' from $hitProvider' : '';
    
    switch (status) {
      case 'HIT':
        debugPrint('📊 [CACHE_DEBUG] $timestamp | KEY: "$key" | STATUS: ✅ HIT$providerInfo | ${durationMs}ms');
        break;
      case 'MISS_ALL':
        debugPrint('📊 [CACHE_DEBUG] $timestamp | KEY: "$key" | STATUS: ❌ MISS_ALL | ${durationMs}ms');
        break;
      case 'NO_PROVIDERS':
        debugPrint('📊 [CACHE_DEBUG] $timestamp | KEY: "$key" | STATUS: ⚠️  NO_PROVIDERS | ${durationMs}ms');
        break;
      case 'ERROR':
        debugPrint('📊 [CACHE_DEBUG] $timestamp | KEY: "$key" | STATUS: 💥 ERROR$providerInfo | ${durationMs}ms');
        break;
      default:
        debugPrint('📊 [CACHE_DEBUG] $timestamp | KEY: "$key" | STATUS: ❓ $status$providerInfo | ${durationMs}ms');
    }
  }
  
  /// Remove a specific item from ALL cache providers
  Future<void> remove(String key) async {
    await _ensureProviders();
    
    debugPrint('💾 [CacheService] REMOVE operation for key: $key');
    
    // Remove from all providers in parallel
    final futures = _providers.map((provider) async {
      final providerType = _getProviderType(provider).name;
      try {
        await provider.remove(key);
        debugPrint('✅ [CacheService] REMOVE successful from ${providerType} provider');
      } catch (e) {
        debugPrint('❌ [CacheService] REMOVE failed from ${providerType} provider: $e');
      }
    });
    
    await Future.wait(futures);
  }
  
  /// Clear all items from ALL cache providers
  Future<void> clear() async {
    await _ensureProviders();
    
    debugPrint('💾 [CacheService] CLEAR operation on all providers');
    
    // Clear all providers in parallel
    final futures = _providers.map((provider) async {
      final providerType = _getProviderType(provider).name;
      try {
        await provider.clear();
        debugPrint('✅ [CacheService] CLEAR successful on ${providerType} provider');
      } catch (e) {
        debugPrint('❌ [CacheService] CLEAR failed on ${providerType} provider: $e');
      }
    });
    
    await Future.wait(futures);
  }
  
  /// Check if a key exists in ANY cache provider
  Future<bool> containsKey(String key) async {
    await _ensureProviders();
    
    // Check providers in order
    for (final provider in _providers) {
      try {
        if (await provider.containsKey(key)) {
          return true;
        }
      } catch (e) {
        // Continue to next provider
      }
    }
    
    return false;
  }
  
  /// Get all keys from the FIRST provider (to avoid duplicates)
  Future<List<String>> getKeys() async {
    await _ensureProviders();
    
    if (_providers.isEmpty) return [];
    
    try {
      return await _providers.first.getKeys();
    } catch (e) {
      debugPrint('❌ [CacheService] Error getting keys from first provider: $e');
      return [];
    }
  }
  
  /// Get the number of items in the FIRST provider
  Future<int> get size async {
    await _ensureProviders();
    
    if (_providers.isEmpty) return 0;
    
    try {
      return await _providers.first.size;
    } catch (e) {
      debugPrint('❌ [CacheService] Error getting size from first provider: $e');
      return 0;
    }
  }
  
  /// Remove expired items from ALL cache providers
  Future<void> cleanup() async {
    await _ensureProviders();
    
    debugPrint('💾 [CacheService] CLEANUP operation on all providers');
    
    // Cleanup all providers in parallel
    final futures = _providers.map((provider) async {
      final providerType = _getProviderType(provider).name;
      try {
        await provider.cleanup();
        debugPrint('✅ [CacheService] CLEANUP successful on ${providerType} provider');
      } catch (e) {
        debugPrint('❌ [CacheService] CLEANUP failed on ${providerType} provider: $e');
      }
    });
    
    await Future.wait(futures);
  }
  
  /// Get cache statistics from ALL providers
  Future<CacheStats> get stats async {
    await _ensureProviders();
    
    if (_providers.isEmpty) {
      return CacheStats(
        hits: 0,
        misses: 0,
        sets: 0,
        removes: 0,
        size: 0,
        lastAccess: DateTime.now(),
      );
    }
    
    // Aggregate stats from all providers
    int totalHits = 0;
    int totalMisses = 0;
    int totalSets = 0;
    int totalRemoves = 0;
    int totalSize = 0;
    DateTime? latestAccess;
    
    for (final provider in _providers) {
      try {
        final providerStats = provider.stats;
        totalHits += providerStats.hits;
        totalMisses += providerStats.misses;
        totalSets += providerStats.sets;
        totalRemoves += providerStats.removes;
        totalSize += providerStats.size;
        
        // Track the latest access time
        if (latestAccess == null || providerStats.lastAccess.isAfter(latestAccess)) {
          latestAccess = providerStats.lastAccess;
        }
      } catch (e) {
        debugPrint('⚠️  [CacheService] Error getting stats from provider: $e');
      }
    }
    
    return CacheStats(
      hits: totalHits,
      misses: totalMisses,
      sets: totalSets,
      removes: totalRemoves,
      size: totalSize,
      lastAccess: latestAccess ?? DateTime.now(),
    );
  }
  
  /// Force a provider recreation (useful for testing Remote Config changes)
  Future<void> forceProviderUpdate() async {
    debugPrint('💾 [CacheService] Forcing provider update...');
    _lastProviderCheck = null;
    await _ensureProviders();
    debugPrint('✅ [CacheService] Provider update completed');
  }
  
  /// Get information about all current cache providers
  Future<Map<String, dynamic>> getProviderInfo() async {
    await _ensureProviders();
    
    final providersInfo = <Map<String, dynamic>>[];
    
    for (int i = 0; i < _providers.length; i++) {
      final provider = _providers[i];
      final providerType = _getProviderType(provider).name;
      
      final info = {
        'priority': i + 1,
        'type': providerType,
        'stats': provider.stats.toString(),
      };
      
      // Add provider-specific info if available
      try {
        if (providerType == 'r2') {
          final r2Provider = provider as dynamic;
          info['bucketInfo'] = await r2Provider.getBucketInfo();
        }
      } catch (e) {
        info['error'] = e.toString();
      }
      
      providersInfo.add(info);
    }
    
    return {
      'totalProviders': _providers.length,
      'lastProviderCheck': _lastProviderCheck?.toIso8601String(),
      'providers': providersInfo,
    };
  }
  
  /// Get Remote Config debug info
  Future<Map<String, dynamic>> getRemoteConfigInfo() async {
    final remoteConfig = RemoteConfigService.instance;
    return {
      'isAvailable': remoteConfig.isAvailable,
      'lastFetchTime': remoteConfig.lastFetchTime?.toIso8601String(),
      'allValues': await remoteConfig.getAllValues(),
    };
  }
  
  /// Dispose of the cache service
  void dispose() {
    _disposeProviders();
    _lastProviderCheck = null;
  }

  // =================
  // UTILITY METHODS FOR BACKWARD COMPATIBILITY
  // =================

  /// Get or set a value (cache-aside pattern)
  /// If the key exists in any provider, return the cached value
  /// If not, call the factory function and cache the result in all providers
  Future<T> getOrSet<T>(
    String key,
    Future<T> Function() factory, {
    Duration? expiration,
  }) async {
    await _ensureProviders();
    final startTime = DateTime.now();
    
    debugPrint('💾 [CacheService] getOrSet called for key: $key');
    debugPrint('   • Providers: ${_providers.map((p) => _getProviderType(p).name).join(' → ')}');
    debugPrint('   • Expiration: ${expiration?.toString() ?? 'default'}');
    
    try {
      // Try to get from cache first (will check providers in priority order)
      debugPrint('💾 [CacheService] Checking cache for key: $key');
      final cached = await get<T>(key);
      
      if (cached != null) {
        final duration = DateTime.now().difference(startTime);
        debugPrint('✅ [CacheService] Cache HIT for key: $key');
        debugPrint('   • Duration: ${duration.inMilliseconds}ms');
        debugPrint('   • Data type: ${cached.runtimeType}');
        return cached;
      }
      
      debugPrint('❌ [CacheService] Cache MISS for key: $key');
      debugPrint('💾 [CacheService] Calling factory function...');
      
      // Not in cache, call factory function
      final factoryStartTime = DateTime.now();
      final value = await factory();
      final factoryDuration = DateTime.now().difference(factoryStartTime);
      
      debugPrint('✅ [CacheService] Factory function completed');
      debugPrint('   • Duration: ${factoryDuration.inMilliseconds}ms');
      debugPrint('   • Result type: ${value.runtimeType}');
      
      // Store in all cache providers for next time
      debugPrint('💾 [CacheService] Storing value in all cache providers for key: $key');
      try {
        await set<T>(key, value, expiration: expiration);
        debugPrint('✅ [CacheService] Value stored successfully in cache providers');
      } catch (cacheError) {
        debugPrint('❌ [CacheService] Failed to store in some cache providers: $cacheError');
        // Return the value even if caching fails partially
      }
      
      final totalDuration = DateTime.now().difference(startTime);
      debugPrint('💾 [CacheService] getOrSet completed for key: $key');
      debugPrint('   • Total duration: ${totalDuration.inMilliseconds}ms');
      
      return value;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      debugPrint('❌ [CacheService] getOrSet failed for key: $key');
      debugPrint('   • Duration: ${duration.inMilliseconds}ms');
      debugPrint('   • Error: $e');
      debugPrint('   • Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Cache multiple values at once in ALL providers
  Future<void> setMultiple<T>(Map<String, T> values, {Duration? expiration}) async {
    for (final entry in values.entries) {
      await set<T>(entry.key, entry.value, expiration: expiration);
    }
  }

  /// Get multiple values at once (checks providers in priority order for each key)
  Future<Map<String, T?>> getMultiple<T>(List<String> keys) async {
    final results = <String, T?>{};
    for (final key in keys) {
      results[key] = await get<T>(key);
    }
    return results;
  }

  /// Remove multiple keys at once from ALL providers
  Future<void> removeMultiple(List<String> keys) async {
    for (final key in keys) {
      await remove(key);
    }
  }
}

 