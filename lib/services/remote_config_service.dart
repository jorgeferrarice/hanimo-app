import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Service for managing Firebase Remote Config
/// Handles configuration for cache providers and other app settings
class RemoteConfigService {
  static RemoteConfigService? _instance;
  static RemoteConfigService get instance => _instance ??= RemoteConfigService._();
  
  RemoteConfigService._();
  
  FirebaseRemoteConfig? _remoteConfig;
  DateTime? _lastFetch;
  
  /// Cache duration for Remote Config (1 minute as requested)
  static const Duration _cacheExpiration = Duration(minutes: 1);
  
  /// Default values for Remote Config parameters
  static const Map<String, dynamic> _defaults = {
    'CACHE_PROVIDERS': 'memory', // Default to memory cache
    'MAX_CACHE_SIZE': 1000, // Maximum cache entries
    'CACHE_EXPIRATION_HOURS': 24, // Default cache expiration in hours

    // Feature Flags
    'ADMOB_ENABLED': true, // AdMob ads feature flag

    'MINIMUM_APP_VERSION': '1.0.0', // Minimum supported app version
    'MAINTENANCE_MODE': false, // Maintenance mode toggle


    // R2 Cache Configuration
    'CLOUDFLARE_ACCOUNT_ID': '', // Cloudflare Account ID for R2
    'CLOUDFLARE_ACCESS_KEY_ID': '', // Cloudflare Access Key ID for R2
    'CLOUDFLARE_SECRET_ACCESS_KEY': '', // Cloudflare Secret Access Key for R2
    'CLOUDFLARE_R2_BUCKET': '', // Cloudflare R2 Bucket name

    // API Keys
    'YOUTUBE_DATA_API_KEY': '', // YouTube Data API v3 key for video data
  };
  
  /// Initialize Remote Config and wait for initial fetch
  Future<void> initialize() async {
    debugPrint('🔧 [RemoteConfig] Starting initialization...');
    
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;
      debugPrint('✅ [RemoteConfig] Firebase Remote Config instance obtained');
      
      // Set configuration settings
      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 15), // Increased timeout for initial fetch
          minimumFetchInterval: _cacheExpiration, // Fetch at most every minute
        ),
      );
      debugPrint('✅ [RemoteConfig] Configuration settings applied');
      
      // Set default values
      await _remoteConfig!.setDefaults(_defaults);
      debugPrint('✅ [RemoteConfig] Default values set');
      
      // Initial fetch and activate - this is critical for proper initialization
      debugPrint('🔧 [RemoteConfig] Performing initial fetch from Firebase...');
      await _performInitialFetch();
      
      debugPrint('✅ [RemoteConfig] Initialization completed successfully');
      debugPrint('   • Cache providers: ${await getString('CACHE_PROVIDERS')} (using: ${await getCacheProviderType()})');
      debugPrint('   • Maintenance mode: ${await isMaintenanceModeEnabled()}');
      
    } catch (e, stackTrace) {
      debugPrint('❌ [RemoteConfig] Error during initialization: $e');
      debugPrint('   • Stack trace: $stackTrace');
      debugPrint('🔄 [RemoteConfig] Continuing with default values...');
      // Continue with defaults if Remote Config fails
    }
  }
  
  /// Perform initial fetch with proper error handling and retries
  Future<void> _performInitialFetch() async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('🔧 [RemoteConfig] Fetch attempt $attempt/$maxRetries...');
        
        final fetchStartTime = DateTime.now();
        final success = await _remoteConfig!.fetchAndActivate();
        final fetchDuration = DateTime.now().difference(fetchStartTime);
        
        _lastFetch = DateTime.now();
        
        if (success) {
          debugPrint('✅ [RemoteConfig] Fetch successful');
          debugPrint('   • Duration: ${fetchDuration.inMilliseconds}ms');
          debugPrint('   • Values updated from Firebase');
          
          // Debug print all Remote Config values
          await _debugPrintAllValues();
          return;
        } else {
          debugPrint('⚠️  [RemoteConfig] Fetch completed but no new values');
          debugPrint('   • Duration: ${fetchDuration.inMilliseconds}ms');
          debugPrint('   • Using cached/default values');
          
          // Debug print all Remote Config values even if no new values
          await _debugPrintAllValues();
          return; // Still consider this successful
        }
      } catch (e) {
        debugPrint('❌ [RemoteConfig] Fetch attempt $attempt failed: $e');
        
        if (attempt < maxRetries) {
          debugPrint('🔄 [RemoteConfig] Retrying in ${retryDelay.inSeconds} seconds...');
          await Future.delayed(retryDelay);
        } else {
          debugPrint('❌ [RemoteConfig] All fetch attempts failed, using defaults');
          // Set _lastFetch to indicate we tried
          _lastFetch = DateTime.now();
          rethrow;
        }
      }
    }
  }
  
  /// Fetch and activate Remote Config (for periodic updates)
  Future<void> _fetchAndActivate() async {
    try {
      final now = DateTime.now();
      
      // Only fetch if cache has expired or this is the first fetch
      if (_lastFetch == null || now.difference(_lastFetch!) >= _cacheExpiration) {
        debugPrint('🔧 [RemoteConfig] Performing periodic fetch...');
        final fetchStartTime = DateTime.now();
        
        final success = await _remoteConfig!.fetchAndActivate();
        final fetchDuration = DateTime.now().difference(fetchStartTime);
        
        _lastFetch = now;
        
        if (success) {
          debugPrint('✅ [RemoteConfig] Periodic fetch successful');
          debugPrint('   • Duration: ${fetchDuration.inMilliseconds}ms');
        } else {
          debugPrint('⚠️  [RemoteConfig] Periodic fetch completed but no updates');
          debugPrint('   • Duration: ${fetchDuration.inMilliseconds}ms');
        }
      } else {
        debugPrint('⏰ [RemoteConfig] Skipping fetch - cache still fresh');
        debugPrint('   • Last fetch: ${_lastFetch}');
        debugPrint('   • Cache expires in: ${_cacheExpiration - now.difference(_lastFetch!)}');
      }
    } catch (e) {
      debugPrint('❌ [RemoteConfig] Error during periodic fetch: $e');
      // Continue with cached values if fetch fails
    }
  }
  
  /// Get the configured cache provider type (returns first provider from CACHE_PROVIDERS)
  Future<CacheProviderType> getCacheProviderType() async {
    await _ensureConfigFresh();
    
    final value = _remoteConfig?.getString('CACHE_PROVIDERS') ?? 'memory';
    final firstProvider = value.split(',').first.trim().toLowerCase();
    
    switch (firstProvider) {
      case 'r2':
        return CacheProviderType.r2;
      case 'sqlite':
        return CacheProviderType.sqlite;
      case 'memory':
      default:
        return CacheProviderType.memory;
    }
  }
  
  /// Get a string value from Remote Config
  Future<String> getString(String key, {String defaultValue = ''}) async {
    await _ensureConfigFresh();
    return _remoteConfig?.getString(key) ?? defaultValue;
  }
  
  /// Get a boolean value from Remote Config
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    await _ensureConfigFresh();
    return _remoteConfig?.getBool(key) ?? defaultValue;
  }
  
  /// Get an integer value from Remote Config
  Future<int> getInt(String key, {int defaultValue = 0}) async {
    await _ensureConfigFresh();
    return _remoteConfig?.getInt(key) ?? defaultValue;
  }
  
  /// Get a double value from Remote Config
  Future<double> getDouble(String key, {double defaultValue = 0.0}) async {
    await _ensureConfigFresh();
    return _remoteConfig?.getDouble(key) ?? defaultValue;
  }
  
  /// Ensure Remote Config is fresh (within cache expiration time)
  Future<void> _ensureConfigFresh() async {
    final now = DateTime.now();
    
    if (_lastFetch == null || now.difference(_lastFetch!) >= _cacheExpiration) {
      await _fetchAndActivate();
    }
  }
  
  /// Force refresh Remote Config (ignoring cache)
  Future<void> forceRefresh() async {
    _lastFetch = null;
    await _fetchAndActivate();
  }
  
  /// Get all Remote Config values for debugging
  Future<Map<String, dynamic>> getAllValues() async {
    await _ensureConfigFresh();
    
    if (_remoteConfig == null) return _defaults;
    
    final values = <String, dynamic>{};
    for (final key in _defaults.keys) {
      final value = _remoteConfig!.getValue(key);
      // Get the value in the appropriate type based on the default
      final defaultValue = _defaults[key];
      if (defaultValue is bool) {
        values[key] = value.asBool();
      } else if (defaultValue is int) {
        values[key] = value.asInt();
      } else if (defaultValue is double) {
        values[key] = value.asDouble();
      } else {
        values[key] = value.asString();
      }
    }
    return values;
  }

  // =================
  // SPECIFIC CONFIG GETTERS
  // =================

  /// Get maximum cache size
  Future<int> getMaxCacheSize() async {
    return await getInt('MAX_CACHE_SIZE', defaultValue: 1000);
  }

  /// Get cache expiration in hours
  Future<int> getCacheExpirationHours() async {
    return await getInt('CACHE_EXPIRATION_HOURS', defaultValue: 24);
  }

  /// Get cache expiration as Duration
  Future<Duration> getCacheExpirationDuration() async {
    final hours = await getCacheExpirationHours();
    return Duration(hours: hours);
  }







  /// Get minimum app version
  Future<String> getMinimumAppVersion() async {
    return await getString('MINIMUM_APP_VERSION', defaultValue: '1.0.0');
  }

  /// Check if maintenance mode is enabled
  Future<bool> isMaintenanceModeEnabled() async {
    return await getBool('MAINTENANCE_MODE', defaultValue: false);
  }

  /// Check if AdMob ads are enabled
  Future<bool> isAdMobEnabled() async {
    return await getBool('ADMOB_ENABLED', defaultValue: true);
  }

  // =================
  // API KEYS
  // =================

  /// Get YouTube Data API key
  Future<String> getYouTubeDataApiKey() async {
    return await getString('YOUTUBE_DATA_API_KEY', defaultValue: '');
  }

  /// Check if YouTube Data API key is configured
  Future<bool> isYouTubeDataApiKeyConfigured() async {
    final apiKey = await getYouTubeDataApiKey();
    return apiKey.isNotEmpty;
  }
  
  /// Check if Remote Config is available
  bool get isAvailable => _remoteConfig != null;
  
  /// Get the last fetch time
  DateTime? get lastFetchTime => _lastFetch;
  
  /// Debug print all Remote Config values
  Future<void> _debugPrintAllValues() async {
    try {
      debugPrint('📊 [RemoteConfig] All Remote Config Values:');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      if (_remoteConfig == null) {
        debugPrint('❌ Remote Config instance is null');
        return;
      }
      
      // Get all values using the getAllValues method
      final allValues = await getAllValues();
      
      // Sort keys for consistent output
      final sortedKeys = allValues.keys.toList()..sort();
      
      for (final key in sortedKeys) {
        final value = allValues[key];
        final emoji = _getEmojiForKey(key);
        debugPrint('$emoji $key: $value (${value.runtimeType})');
      }
      
      // Also show raw Firebase Remote Config values for comparison
      debugPrint('');
      debugPrint('🔍 [RemoteConfig] Raw Firebase Values:');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      for (final key in _defaults.keys) {
        try {
          final rawValue = _remoteConfig!.getValue(key);
          final source = rawValue.source.name;
          debugPrint('🔧 $key: ${rawValue.asString()} (source: $source)');
        } catch (e) {
          debugPrint('❌ $key: Error getting value - $e');
        }
      }
      
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
    } catch (e, stackTrace) {
      debugPrint('❌ [RemoteConfig] Error printing debug values: $e');
      debugPrint('   • Stack trace: $stackTrace');
    }
  }
  
  /// Get emoji for configuration key (for better debug output)
  String _getEmojiForKey(String key) {
    switch (key) {
      case 'CACHE_PROVIDERS':
        return '💾';
      case 'MAX_CACHE_SIZE':
      case 'CACHE_EXPIRATION_HOURS':
        return '📦';
      case 'ADMOB_ENABLED':
        return '📱';
      case 'MINIMUM_APP_VERSION':
        return '📱';
      case 'MAINTENANCE_MODE':
        return '🚧';

      case 'CLOUDFLARE_ACCOUNT_ID':
      case 'CLOUDFLARE_ACCESS_KEY_ID':
      case 'CLOUDFLARE_SECRET_ACCESS_KEY':
      case 'CLOUDFLARE_R2_BUCKET':
        return '☁️';
      case 'YOUTUBE_DATA_API_KEY':
        return '🎬';
      default:
        return '⚙️';
    }
  }
}

/// Enum for cache provider types
enum CacheProviderType {
  memory,
  r2,
  sqlite,
}

/// Extension to convert enum to string
extension CacheProviderTypeExtension on CacheProviderType {
  String get name {
    switch (this) {
      case CacheProviderType.memory:
        return 'memory';
      case CacheProviderType.r2:
        return 'r2';
      case CacheProviderType.sqlite:
        return 'sqlite';
    }
  }
} 