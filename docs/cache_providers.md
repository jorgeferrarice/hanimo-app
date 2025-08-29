# Cache Providers

This directory contains different cache provider implementations that can be used with the cache service.

## Remote Config-Driven Provider Selection

**NEW!** The cache system now uses Firebase Remote Config to dynamically select which provider to use. This allows you to:

- Switch cache providers without app updates
- A/B test different cache strategies
- Gradually roll out new cache providers
- Handle provider failures gracefully

### Configuration

The system reads the `CACHE_PROVIDER` parameter from Firebase Remote Config:
- `"memory"`: Uses MemoryCacheProvider
- `"r2"`: Uses R2CacheProvider (requires environment variables)

Remote Config is fetched at most every minute, ensuring quick response to configuration changes.

### Usage

The cache service is automatically initialized in `main.dart`:

```dart
// Automatic initialization - no manual provider selection needed
final cacheService = CacheService.instance;

// Use normally - provider is selected automatically based on Remote Config
await cacheService.set('key', 'value');
final value = await cacheService.get('key');
```

### Monitoring Provider Changes

```dart
// Get current provider info
final providerInfo = await CacheService.instance.getProviderInfo();
print('Current provider: ${providerInfo['providerType']}');

// Force provider update (useful for testing)
await CacheService.instance.forceProviderUpdate();

// Get Remote Config debug info
final configInfo = await CacheService.instance.getRemoteConfigInfo();
```

## Available Providers

### MemoryCacheProvider

An in-memory cache provider that stores data in the device's RAM. Data is lost when the app is restarted.

**Features:**
- Fast access times
- Automatic expiration and cleanup
- Statistics tracking
- Configurable max size and cleanup intervals
- Zero external dependencies

**Best for:**
- Development and testing
- Temporary caching of small data
- Scenarios where persistence is not required

### R2CacheProvider

A Cloudflare R2 cache provider that stores data in Cloudflare R2 object storage. Data persists across app restarts and can be shared between devices.

**Features:**
- Persistent storage
- Scalable and reliable
- Automatic expiration
- Statistics tracking
- Cross-device synchronization
- Cost-effective object storage

**Best for:**
- Production environments
- Large cache data
- Cross-device data sharing
- Persistent caching requirements

## Setup

### Firebase Remote Config Setup

1. Go to Firebase Console → Remote Config
2. Create parameter: `CACHE_PROVIDER`
3. Set default value: `memory`
4. Optionally create conditions for different platforms/versions
5. Publish the configuration

### R2 Provider Setup (Required only if using R2)

Set these environment variables:
```bash
CLOUDFLARE_ACCOUNT_ID=your_account_id
CLOUDFLARE_ACCESS_KEY_ID=your_access_key_id
CLOUDFLARE_SECRET_ACCESS_KEY=your_secret_access_key
CLOUDFLARE_R2_BUCKET=hanimo-cache
```

## Migration from Manual Provider Selection

If you previously initialized the cache service manually:

**Old way:**
```dart
// Manual provider selection - NO LONGER NEEDED
final provider = MemoryCacheProvider();
CacheService.instance.initialize(provider: provider);
```

**New way:**
```dart
// Automatic Remote Config-driven selection
await CacheService.instance.initialize();
```

The system will automatically handle provider selection and switching based on Remote Config.

## Examples

See `docs/examples/remote_config_cache_example.dart` for comprehensive usage examples. 