import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/cache_provider.dart';
import '../services/remote_config_service.dart';
import '../services/app_config_service.dart';
import 'memory_cache_provider.dart';
import 'r2_cache_provider.dart';
import 'sqlite_cache_provider.dart';

/// Factory for creating cache providers based on Remote Config
class CacheProviderFactory {
  static CacheProviderFactory? _instance;
  static CacheProviderFactory get instance => _instance ??= CacheProviderFactory._();
  
  CacheProviderFactory._();
  
  CacheProvider? _currentProvider;
  CacheProviderType? _currentProviderType;
  
  // Store created providers by type to avoid recreating them unnecessarily
  final Map<CacheProviderType, CacheProvider> _providerCache = {};
  
  /// Create a cache provider of a specific type
  Future<CacheProvider> createProviderOfType(CacheProviderType providerType) async {
    debugPrint('🏭 [CacheFactory] Creating ${providerType.name} provider...');
    
    // Check if we already have a provider of this type
    if (_providerCache.containsKey(providerType)) {
      debugPrint('🏭 [CacheFactory] Reusing existing ${providerType.name} provider');
      return _providerCache[providerType]!;
    }
    
    debugPrint('🏭 [CacheFactory] Creating new ${providerType.name} provider...');
    
    // Create new provider based on type
    try {
      CacheProvider provider;
      switch (providerType) {
        case CacheProviderType.r2:
          provider = await _createR2Provider();
          break;
        case CacheProviderType.sqlite:
          provider = await _createSQLiteProvider();
          break;
        case CacheProviderType.memory:
        default:
          provider = await _createMemoryProvider();
          break;
      }
      
      // Cache the provider for reuse
      _providerCache[providerType] = provider;
      
      debugPrint('✅ [CacheFactory] Cache provider created successfully: ${providerType.name}');
      
      return provider;
    } catch (e, stackTrace) {
      debugPrint('❌ [CacheFactory] Failed to create ${providerType.name} provider: $e');
      debugPrint('   Stack trace: $stackTrace');
      
      // Fallback to memory provider if R2 fails
      if (providerType == CacheProviderType.r2) {
        debugPrint('🔄 [CacheFactory] Falling back to memory cache provider...');
        return await createProviderOfType(CacheProviderType.memory);
      }
      
      rethrow;
    }
  }
  
  /// Create a cache provider based on Remote Config
  Future<CacheProvider> createProvider() async {
    debugPrint('🏭 [CacheFactory] Creating cache provider...');
    
    final appConfig = AppConfigService.instance;
    final providerType = await appConfig.getCacheProviderType();
    
    debugPrint('🏭 [CacheFactory] Provider type from config: ${providerType.name}');
    
    // If we already have a provider of the same type, return it
    if (_currentProvider != null && _currentProviderType == providerType) {
      debugPrint('🏭 [CacheFactory] Reusing existing ${providerType.name} provider');
      return _currentProvider!;
    }
    
    // Dispose of the previous provider
    if (_currentProvider is MemoryCacheProvider) {
      debugPrint('🏭 [CacheFactory] Disposing previous memory cache provider');
      (_currentProvider as MemoryCacheProvider).dispose();
    } else if (_currentProvider is SQLiteCacheProvider) {
      debugPrint('🏭 [CacheFactory] Disposing previous SQLite cache provider');
      await (_currentProvider as SQLiteCacheProvider).dispose();
    }
    
    // Use the new createProviderOfType method
    _currentProvider = await createProviderOfType(providerType);
    _currentProviderType = providerType;
    
    return _currentProvider!;
  }
  
  /// Create memory cache provider
  Future<MemoryCacheProvider> _createMemoryProvider() async {
    final appConfig = AppConfigService.instance;
    final maxSize = await appConfig.getMaxCacheSize();
    final expiration = await appConfig.getCacheExpirationDuration();
    
    return MemoryCacheProvider(
      maxSize: maxSize,
      defaultExpiration: expiration,
      cleanupInterval: const Duration(minutes: 5),
    );
  }
  
  /// Create SQLite cache provider
  Future<SQLiteCacheProvider> _createSQLiteProvider() async {
    final appConfig = AppConfigService.instance;
    final maxSize = await appConfig.getMaxCacheSize();
    final expiration = await appConfig.getCacheExpirationDuration();
    
    debugPrint('🗄️  [CacheFactory] Creating SQLite cache provider...');
    debugPrint('   • Max size: $maxSize entries');
    debugPrint('   • Expiration: ${expiration.inHours}h');
    
    return SQLiteCacheProvider(
      maxSize: maxSize,
      defaultExpiration: expiration,
      cleanupInterval: const Duration(minutes: 5),
      databaseName: 'hanimo_cache.db',
    );
  }

  /// Create R2 cache provider
  Future<R2CacheProvider> _createR2Provider() async {
    final appConfig = AppConfigService.instance;
    
    debugPrint('🔧 [CacheFactory] Configuring R2 cache provider...');
    
    // Get R2 configuration from Remote Config first, then environment variables
    final accountId = await _getR2ConfigValue('CLOUDFLARE_ACCOUNT_ID');
    final accessKeyId = await _getR2ConfigValue('CLOUDFLARE_ACCESS_KEY_ID');
    final secretAccessKey = await _getR2ConfigValue('CLOUDFLARE_SECRET_ACCESS_KEY');
    final bucket = await _getR2ConfigValue('CLOUDFLARE_R2_BUCKET', defaultValue: 'hanimo-cache');
    final expiration = await appConfig.getCacheExpirationDuration();
    
    debugPrint('🔧 [CacheFactory] R2 configuration:');
    debugPrint('   • Account ID: ${accountId.isNotEmpty ? '***${accountId.substring(accountId.length - 4)}' : 'NOT SET'}');
    debugPrint('   • Access Key ID: ${accessKeyId.isNotEmpty ? '***${accessKeyId.substring(accessKeyId.length - 4)}' : 'NOT SET'}');
    debugPrint('   • Secret Access Key: ${secretAccessKey.isNotEmpty ? '***set' : 'NOT SET'}');
    debugPrint('   • Bucket: $bucket');
    debugPrint('   • Expiration: ${expiration.inHours}h');
    
    if (accountId.isEmpty || accessKeyId.isEmpty || secretAccessKey.isEmpty) {
      throw Exception(
        'R2 provider selected but credentials not configured. '
        'Please configure CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_ACCESS_KEY_ID, '
        'CLOUDFLARE_SECRET_ACCESS_KEY, and CLOUDFLARE_R2_BUCKET in Remote Config '
        'or as environment variables.'
      );
    }
    
    debugPrint('✅ [CacheFactory] R2 provider configured successfully');
    
    return R2CacheProvider(
      accountId: accountId,
      accessKeyId: accessKeyId,
      secretAccessKey: secretAccessKey,
      bucket: bucket,
      keyPrefix: 'hanimo-cache/',
      defaultExpiration: expiration,
    );
  }
  
  /// Get R2 configuration value from Remote Config first, then environment variables
  Future<String> _getR2ConfigValue(String key, {String defaultValue = ''}) async {
    final appConfig = AppConfigService.instance;
    
    // Try Remote Config first (where the credentials are configured)
    final remoteValue = await appConfig.getCustomValue<String>(key);
    if (remoteValue != null && remoteValue.isNotEmpty) {
      debugPrint('🔧 [CacheFactory] Using Remote Config value for $key');
      return remoteValue;
    }
    
    // Try environment variables as fallback
    final envValue = Platform.environment[key];
    if (envValue != null && envValue.isNotEmpty) {
      debugPrint('🔧 [CacheFactory] Using environment variable for $key');
      return envValue;
    }
    
    debugPrint('⚠️  [CacheFactory] No value found for $key, using default: $defaultValue');
    return defaultValue;
  }
  
  /// Get the current provider type
  CacheProviderType? get currentProviderType => _currentProviderType;
  
  /// Get the current provider
  CacheProvider? get currentProvider => _currentProvider;
  
  /// Force recreation of the provider (useful when Remote Config changes)
  Future<CacheProvider> recreateProvider() async {
    _currentProvider = null;
    _currentProviderType = null;
    _providerCache.clear(); // Clear the cache to force recreation
    return await createProvider();
  }
  
  /// Check if provider needs to be recreated based on Remote Config
  Future<bool> shouldRecreateProvider() async {
    if (_currentProviderType == null) return true;
    
    final appConfig = AppConfigService.instance;
    final currentConfigType = await appConfig.getCacheProviderType();
    
    return currentConfigType != _currentProviderType;
  }
  
  /// Dispose of current provider
  Future<void> dispose() async {
    if (_currentProvider is MemoryCacheProvider) {
      (_currentProvider as MemoryCacheProvider).dispose();
    } else if (_currentProvider is SQLiteCacheProvider) {
      await (_currentProvider as SQLiteCacheProvider).dispose();
    }
    
    // Dispose all cached providers
    for (final provider in _providerCache.values) {
      if (provider is MemoryCacheProvider) {
        provider.dispose();
      }
    }
    
    _currentProvider = null;
    _currentProviderType = null;
    _providerCache.clear();
  }
} 