import 'package:flutter/foundation.dart';
import 'remote_config_service.dart';

/// Service that manages app configuration loaded from Remote Config
/// Provides easy access to all configuration values with caching
class AppConfigService {
  static AppConfigService? _instance;
  static AppConfigService get instance => _instance ??= AppConfigService._();
  
  AppConfigService._();
  
  // Configuration values cache
  Map<String, dynamic> _configCache = {};
  DateTime? _lastLoaded;
  bool _isInitialized = false;
  
  /// Cache duration for configuration values (5 minutes)
  static const Duration _cacheExpiration = Duration(minutes: 5);
  
  /// Initialize Remote Config only (separate from full initialization)
  Future<void> initializeRemoteConfig() async {
    try {
      debugPrint('🔧 [AppConfig] Initializing Remote Config only...');
      
      // Initialize Remote Config and wait for initial fetch
      await RemoteConfigService.instance.initialize();
      
      debugPrint('✅ [AppConfig] Remote Config initialization completed');
      
    } catch (e) {
      debugPrint('❌ [AppConfig] Error initializing Remote Config: $e');
      // Continue - we'll use defaults when full initialization happens
      rethrow;
    }
  }

  /// Initialize and load all configuration values
  Future<void> initialize() async {
    try {
      debugPrint('🔧 [AppConfig] Initializing App Configuration...');
      
      // Remote Config should already be initialized at this point
      // but we'll check if it needs initialization
      if (!RemoteConfigService.instance.isAvailable) {
        debugPrint('⚠️  [AppConfig] Remote Config not available, initializing...');
        await RemoteConfigService.instance.initialize();
      }
      
      // Load all configuration values
      await _loadAllConfigurations();
      
      _isInitialized = true;
      debugPrint('✅ [AppConfig] App Configuration initialized successfully');
      
      // Print debug info if debug mode is enabled
          if (kDebugMode) {
      await _printDebugInfo();
    }
      
    } catch (e) {
      debugPrint('❌ [AppConfig] Error initializing App Configuration: $e');
      // Set defaults if initialization fails
      _setDefaultValues();
      _isInitialized = true;
    }
  }
  
  /// Load all configuration values from Remote Config
  Future<void> _loadAllConfigurations() async {
    debugPrint('📋 [AppConfig] Loading configuration values from Remote Config...');
    
    final remoteConfig = RemoteConfigService.instance;
    _configCache = await remoteConfig.getAllValues();
    _lastLoaded = DateTime.now();
    
          debugPrint('✅ [AppConfig] Loaded ${_configCache.length} configuration values');
      debugPrint('   • Cache providers: ${_configCache['CACHE_PROVIDERS']}');
      debugPrint('   • Maintenance mode: ${_configCache['MAINTENANCE_MODE']}');
  }
  
  /// Set default values if Remote Config fails
  void _setDefaultValues() {
    _configCache = {
          'CACHE_PROVIDERS': 'memory',
    'MAX_CACHE_SIZE': 1000,
    'CACHE_EXPIRATION_HOURS': 24,
    'ADMOB_ENABLED': true,
    'MINIMUM_APP_VERSION': '1.0.0',
    'MAINTENANCE_MODE': false,
    'YOUTUBE_DATA_API_KEY': '',
    };
    _lastLoaded = DateTime.now();
    debugPrint('📋 Using default configuration values');
  }
  
  /// Ensure configuration is fresh (reload if needed)
  Future<void> _ensureConfigFresh() async {
    if (!_isInitialized) {
      await initialize();
      return;
    }
    
    final now = DateTime.now();
    if (_lastLoaded == null || now.difference(_lastLoaded!) >= _cacheExpiration) {
      await _loadAllConfigurations();
    }
  }
  
  /// Force refresh all configuration values
  Future<void> refresh() async {
    debugPrint('🔄 Refreshing App Configuration...');
    await RemoteConfigService.instance.forceRefresh();
    await _loadAllConfigurations();
    debugPrint('✅ App Configuration refreshed');
  }
  
  // =================
  // CACHE CONFIGURATION
  // =================
  
  /// Get cache provider type (returns first provider from CACHE_PROVIDERS)
  Future<CacheProviderType> getCacheProviderType() async {
    await _ensureConfigFresh();
    final value = _configCache['CACHE_PROVIDERS'] as String? ?? 'memory';
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
  
  /// Get maximum cache size
  Future<int> getMaxCacheSize() async {
    await _ensureConfigFresh();
    return _configCache['MAX_CACHE_SIZE'] as int? ?? 1000;
  }
  
  /// Get cache expiration duration
  Future<Duration> getCacheExpirationDuration() async {
    await _ensureConfigFresh();
    final hours = _configCache['CACHE_EXPIRATION_HOURS'] as int? ?? 24;
    return Duration(hours: hours);
  }

  // =================
  // R2 CONFIGURATION
  // =================

  /// Get Cloudflare Account ID
  Future<String?> getCloudflareAccountId() async {
    await _ensureConfigFresh();
    return _configCache['CLOUDFLARE_ACCOUNT_ID'] as String?;
  }

  /// Get Cloudflare Access Key ID
  Future<String?> getCloudflareAccessKeyId() async {
    await _ensureConfigFresh();
    return _configCache['CLOUDFLARE_ACCESS_KEY_ID'] as String?;
  }

  /// Get Cloudflare Secret Access Key
  Future<String?> getCloudflareSecretAccessKey() async {
    await _ensureConfigFresh();
    return _configCache['CLOUDFLARE_SECRET_ACCESS_KEY'] as String?;
  }

  /// Get Cloudflare R2 Bucket name
  Future<String?> getCloudflareR2Bucket() async {
    await _ensureConfigFresh();
    return _configCache['CLOUDFLARE_R2_BUCKET'] as String?;
  }

  /// Check if all R2 credentials are configured
  Future<bool> areR2CredentialsConfigured() async {
    await _ensureConfigFresh();
    final accountId = await getCloudflareAccountId();
    final accessKeyId = await getCloudflareAccessKeyId();
    final secretAccessKey = await getCloudflareSecretAccessKey();
    
    return accountId != null && accountId.isNotEmpty &&
           accessKeyId != null && accessKeyId.isNotEmpty &&
           secretAccessKey != null && secretAccessKey.isNotEmpty;
  }
  
  // =================
  // API CONFIGURATION
  // =================
  
  /// Get YouTube Data API key
  Future<String> getYouTubeDataApiKey() async {
    await _ensureConfigFresh();
    return _configCache['YOUTUBE_DATA_API_KEY'] as String? ?? '';
  }

  /// Check if YouTube Data API key is configured
  Future<bool> isYouTubeDataApiKeyConfigured() async {
    final apiKey = await getYouTubeDataApiKey();
    return apiKey.isNotEmpty;
  }
  
  // =================
  // FEATURE FLAGS
  // =================
  
  /// Check if AdMob ads are enabled
  Future<bool> isAdMobEnabled() async {
    await _ensureConfigFresh();
    return _configCache['ADMOB_ENABLED'] as bool? ?? true;
  }
  
  // =================
  // APP CONTROL
  // =================
  
  /// Get minimum app version
  Future<String> getMinimumAppVersion() async {
    await _ensureConfigFresh();
    return _configCache['MINIMUM_APP_VERSION'] as String? ?? '1.0.0';
  }
  
  /// Check if maintenance mode is enabled
  Future<bool> isMaintenanceModeEnabled() async {
    await _ensureConfigFresh();
    return _configCache['MAINTENANCE_MODE'] as bool? ?? false;
  }
  
  // =================
  // UTILITY METHODS
  // =================
  
  /// Get a custom configuration value
  Future<T?> getCustomValue<T>(String key, {T? defaultValue}) async {
    await _ensureConfigFresh();
    return _configCache[key] as T? ?? defaultValue;
  }
  
  /// Get all configuration values
  Future<Map<String, dynamic>> getAllValues() async {
    await _ensureConfigFresh();
    return Map.from(_configCache);
  }
  
  /// Check if configuration is initialized
  bool get isInitialized => _isInitialized;
  
  /// Get last loaded time
  DateTime? get lastLoaded => _lastLoaded;
  
  /// Print debug information
  Future<void> _printDebugInfo() async {
    debugPrint('\n📊 App Configuration Debug Info:');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    final sortedKeys = _configCache.keys.toList()..sort();
    for (final key in sortedKeys) {
      final value = _configCache[key];
      final emoji = _getEmojiForKey(key);
      debugPrint('$emoji $key: $value');
    }
    
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('⏰ Last loaded: $_lastLoaded');
    debugPrint('🔄 Cache expires in: ${_cacheExpiration.inMinutes} minutes\n');
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

      default:
        return '⚙️';
    }
  }
  
  /// Print configuration summary for startup
  Future<void> printStartupSummary() async {
    if (!kDebugMode) return;
    
    debugPrint('\n🚀 App Configuration Summary:');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('💾 Cache Providers: ${_configCache['CACHE_PROVIDERS']} (using: ${(await getCacheProviderType()).name})');
    debugPrint('📦 Max Cache Size: ${await getMaxCacheSize()}');
    debugPrint('⏱️  Cache Expiration: ${(await getCacheExpirationDuration()).inHours}h');
    debugPrint('📱 AdMob Enabled: ${await isAdMobEnabled()}');
    debugPrint('🚧 Maintenance Mode: ${await isMaintenanceModeEnabled()}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }
} 