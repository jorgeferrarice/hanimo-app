# Cache Service

A flexible, provider-based caching system for Flutter applications that supports multiple caching strategies with a unified interface.

## Features

- 🏗️ **Provider-based architecture** - Easily switch between different cache implementations
- 💾 **In-memory caching** - Fast access with automatic expiration and cleanup  
- 📊 **Performance monitoring** - Built-in statistics and hit/miss tracking
- 🔄 **Cache patterns** - Support for cache-aside, write-through, and write-behind patterns
- 🧹 **Automatic cleanup** - Configurable expiration and background cleanup
- 📦 **Batch operations** - Set, get, and remove multiple items at once
- 🚀 **Easy integration** - Simple setup with builder pattern

## Quick Start

### 1. Initialize Cache Service

```dart
import 'package:your_app/services/cache_service.dart';

void main() {
  // Initialize with default in-memory provider
  CacheBuilder()
      .withMemoryProvider(
        maxSize: 1000,
        defaultExpiration: const Duration(hours: 1),
      )
      .build();
      
  runApp(MyApp());
}
```

### 2. Basic Usage

```dart
final cache = CacheService.instance;

// Set a value
await cache.set('user_123', userData, expiration: Duration(minutes: 30));

// Get a value  
final user = await cache.get<UserData>('user_123');

// Cache-aside pattern (get or fetch)
final anime = await cache.getOrSet<Anime>(
  'anime_1',
  () => jikanApi.getAnime(1),
  expiration: Duration(hours: 1),
);
```

### 3. Advanced Usage

```dart
// Batch operations
await cache.setMultiple({
  'anime_1': animeData1,
  'anime_2': animeData2,
}, expiration: Duration(hours: 2));

// Cache warming
await cache.warmUp<Anime>({
  'popular_1': () => jikanApi.getAnime(1),
  'popular_2': () => jikanApi.getAnime(5),
});

// Monitor performance
final stats = cache.stats;
print('Hit ratio: ${stats.hitRatio}%');
```

## Architecture

### Cache Providers

The system uses a provider-based architecture where different cache implementations can be plugged in:

- **MemoryCacheProvider** - In-memory storage with LRU eviction
- **Future providers** - SharedPreferences, Hive, SQLite, Redis, etc.

### Cache Service

The `CacheService` is a singleton that provides a unified interface for all caching operations regardless of the underlying provider.

### Cache Patterns

- **Cache-aside** - Check cache first, fetch from source if miss
- **Write-through** - Write to cache and data source simultaneously  
- **Write-behind** - Write to cache immediately, data source asynchronously

## Configuration Options

```dart
CacheBuilder()
    .withConfig(CacheConfig(
      maxSize: 1000,
      defaultExpiration: Duration(hours: 1),
      cleanupInterval: Duration(minutes: 5),
      enableStats: true,
    ))
    .withMemoryProvider()
    .build();
```

## Provider Switching

```dart
// Switch to a different provider with data migration
final newProvider = MemoryCacheProvider(maxSize: 2000);
await cache.switchProvider(newProvider, migrateData: true);
```

## Flutter Integration

```dart
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final cache = CacheService.instance;
  
  Future<AnimeData> _loadAnime(int id) async {
    return await cache.getOrSet<AnimeData>(
      'anime_$id',
      () => jikanApi.getAnime(id),
      expiration: Duration(hours: 1),
    );
  }
  
  // ... rest of widget
}
```

## File Structure

```
lib/services/
├── cache_provider.dart           # Abstract provider interface
├── memory_cache_provider.dart    # In-memory implementation  
├── cache_service.dart           # Main service class
├── cache_service_example.dart   # Usage examples
└── cache_README.md             # This file
```

## Benefits

- **Performance** - Reduce API calls and improve response times
- **Offline Support** - Cache data for offline access
- **Scalability** - Easy to switch providers as needs grow
- **Maintainability** - Clean separation of concerns
- **Testability** - Mock providers for testing

## Best Practices

1. **Set appropriate expiration times** based on data freshness requirements
2. **Monitor cache hit ratios** to optimize performance
3. **Use cache warming** for critical data that should always be available
4. **Handle cache failures gracefully** with fallback to data source
5. **Consider memory usage** and set appropriate size limits

## Next Steps

- Add SharedPreferences provider for persistent caching
- Implement Hive provider for structured data
- Add Redis provider for distributed caching
- Create cache invalidation strategies
- Add encryption support for sensitive data 