import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloudflare_r2/cloudflare_r2.dart';
import 'package:jikan_api/jikan_api.dart';
import 'package:built_collection/built_collection.dart';
import '../services/cache_provider.dart';

/// Cloudflare R2 cache provider implementation
/// Stores cache data in Cloudflare R2 object storage with automatic expiration
class R2CacheProvider implements CacheProvider {
  final String _bucket;
  final String _keyPrefix;
  bool _initialized = false;
  
  // Statistics tracking
  int _hits = 0;
  int _misses = 0;
  int _sets = 0;
  int _removes = 0;
  DateTime _lastAccess = DateTime.now();
  
  /// Default expiration duration for cache entries
  final Duration? defaultExpiration;
  
  R2CacheProvider({
    required String accountId,
    required String accessKeyId,
    required String secretAccessKey,
    required String bucket,
    String keyPrefix = 'cache/',
    this.defaultExpiration,
  }) : _bucket = bucket,
        _keyPrefix = keyPrefix {
    // Initialize CloudFlareR2
    CloudFlareR2.init(
      accoundId: accountId,
      accessKeyId: accessKeyId,
      secretAccessKey: secretAccessKey,
    );
    _initialized = true;
  }
  
  /// Generate the full key for R2 storage
  String _getFullKey(String key) => '$_keyPrefix$key';
  
  /// Generate metadata key for storing expiration info
  String _getMetadataKey(String key) => '${_keyPrefix}meta_$key';
  
  /// Serialize a value to JSON string - now handles simple Map/List objects
  String _serializeValue<T>(T value) {
    debugPrint('🔧 [R2Cache] Serializing: ${value.runtimeType}');
    
    try {
      // All values should now be simple JSON-serializable types (Map, List, String, int, etc.)
      final result = json.encode(value);
      debugPrint('✅ [R2Cache] Successfully serialized ${value.runtimeType}');
      return result;
    } catch (e) {
      debugPrint('❌ [R2Cache] Serialization failed for ${value.runtimeType}: $e');
      rethrow;
    }
  }
  
  /// Serialize an Anime object to a Map
  Map<String, dynamic> _serializeAnime(dynamic anime) {
    try {
      return {
        'malId': anime.malId,
        'url': anime.url,
        'imageUrl': anime.imageUrl,
        'title': anime.title,
        'titleEnglish': anime.titleEnglish,
        'titleJapanese': anime.titleJapanese,
        'episodes': anime.episodes,
        'status': anime.status,
        'aired': anime.aired,
        'score': anime.score,
        'scoredBy': anime.scoredBy,
        'rank': anime.rank,
        'popularity': anime.popularity,
        'members': anime.members,
        'favorites': anime.favorites,
        'synopsis': anime.synopsis,
        'background': anime.background,
        'season': anime.season,
        'year': anime.year,
        'broadcast': anime.broadcast,
        'source': anime.source,
        'duration': anime.duration,
        'rating': anime.rating,
        'genres': anime.genres?.map((g) => {
          'malId': g.malId,
          'name': g.name,
        })?.toList() ?? [],
        'studios': anime.studios?.map((s) => {
          'malId': s.malId,
          'name': s.name,
        })?.toList() ?? [],
      };
    } catch (e) {
      debugPrint('❌ [R2Cache] Failed to serialize Anime: $e');
      // Fallback to basic serialization
      return {
        'malId': anime.malId ?? 0,
        'title': anime.title ?? 'Unknown',
        'imageUrl': anime.imageUrl ?? '',
        'error': 'Partial serialization due to: $e',
      };
    }
  }
  
  /// Serialize generic built_value objects
  Map<String, dynamic> _serializeGenericBuiltValue(dynamic item) {
    try {
      // Try to extract basic properties that most Jikan objects have
      final Map<String, dynamic> result = {};
      
      // Common properties
      if (item.toString().contains('malId')) result['malId'] = item.malId ?? 0;
      if (item.toString().contains('name')) result['name'] = item.name ?? '';
      if (item.toString().contains('title')) result['title'] = item.title ?? '';
      if (item.toString().contains('url')) result['url'] = item.url ?? '';
      
      // Add type information for reconstruction
      result['_originalType'] = item.runtimeType.toString();
      
      return result;
    } catch (e) {
      return {
        '_originalType': item.runtimeType.toString(),
        '_error': 'Failed to serialize: $e',
        '_toString': item.toString(),
      };
    }
  }
  

  
  /// Extract properties from generic built_value objects
  Map<String, dynamic> _extractBuiltValueProperties(dynamic obj) {
    try {
      // Try to access common properties that built_value objects might have
      final Map<String, dynamic> data = {};
      
      // Use reflection-like approach to get properties
      final objString = obj.toString();
      
      // For now, return a basic representation
      data['_originalType'] = obj.runtimeType.toString();
      data['_stringRepresentation'] = objString;
      
      // Try to extract malId and name if they exist (common in Jikan objects)
      try {
        data['malId'] = obj.malId;
      } catch (e) {
        // malId doesn't exist, ignore
      }
      
      try {
        data['name'] = obj.name;
      } catch (e) {
        // name doesn't exist, ignore
      }
      
      try {
        data['title'] = obj.title;
      } catch (e) {
        // title doesn't exist, ignore
      }
      
      return data;
    } catch (e) {
      return {
        '_originalType': obj.runtimeType.toString(),
        '_stringRepresentation': obj.toString(),
        '_extractionError': e.toString(),
      };
    }
  }

  /// Deserialize a JSON string back to the original value type
  T? _deserializeValue<T>(String jsonStr) {
    try {
      final decoded = json.decode(jsonStr);
      debugPrint('✅ [R2Cache] Successfully deserialized ${decoded.runtimeType}');
      
      // Handle List<Map<String, dynamic>> specifically
      if (T.toString().contains('List<Map<String, dynamic>>') && decoded is List) {
        debugPrint('🔧 [R2Cache] Converting List<dynamic> to List<Map<String, dynamic>>');
        final List<Map<String, dynamic>> convertedList = decoded
            .map((item) => item is Map<String, dynamic> ? item : <String, dynamic>{})
            .toList();
        debugPrint('✅ [R2Cache] Converted to List<Map<String, dynamic>> with ${convertedList.length} items');
        return convertedList as T?;
      }
      
      // Handle Map<String, dynamic> specifically
      if (T.toString().contains('Map<String, dynamic>') && decoded is Map) {
        debugPrint('🔧 [R2Cache] Converting Map to Map<String, dynamic>');
        final Map<String, dynamic> convertedMap = Map<String, dynamic>.from(decoded);
        return convertedMap as T?;
      }
      
      return decoded as T?;
    } catch (e) {
      debugPrint('❌ [R2Cache] Failed to deserialize JSON: $e');
      return null;
    }
  }
  
  /// Reconstruct a BuiltList<Anime> from serialized data
  BuiltList<Anime>? _reconstructBuiltListAnime(List<dynamic> data) {
    try {
      final List<Anime> animeList = [];
      
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          final anime = _reconstructAnime(item);
          if (anime != null) {
            animeList.add(anime);
          }
        }
      }
      
      final result = BuiltList<Anime>(animeList);
      debugPrint('✅ [R2Cache] Successfully reconstructed BuiltList<Anime> with ${result.length} items');
      return result;
    } catch (e) {
      debugPrint('❌ [R2Cache] Failed to reconstruct BuiltList<Anime>: $e');
      return null;
    }
  }
  
  /// Reconstruct an Anime object from serialized data
  Anime? _reconstructAnime(Map<String, dynamic> data) {
    try {
      // Create mock anime object that matches the expected interface
      // This is a simplified reconstruction - may not have all built_value features
      final anime = _createAnimeFromData(data);
      return anime;
    } catch (e) {
      debugPrint('❌ [R2Cache] Failed to reconstruct Anime: $e');
      return null;
    }
  }
  
  /// Create an Anime object from serialized data
  /// Note: This creates a compatible object but may not be a true built_value object
  Anime? _createAnimeFromData(Map<String, dynamic> data) {
    try {
      // For now, we'll return null and let the system fetch fresh data
      // This ensures we don't create incompatible objects
      debugPrint('⚠️  [R2Cache] Anime reconstruction is complex - triggering fresh fetch');
      return null;
    } catch (e) {
      debugPrint('❌ [R2Cache] Error creating Anime from data: $e');
      return null;
    }
  }
  

  
  @override
  Future<T?> get<T>(String key) async {
    if (!_initialized) return null;
    
    _lastAccess = DateTime.now();
    
    try {
      // First check if the item has expired by checking metadata
      final metadataKey = _getMetadataKey(key);
      final metadataResult = await CloudFlareR2.getObject(
        bucket: _bucket,
        objectName: metadataKey,
      );
      
      if (metadataResult != null) {
        final metadata = json.decode(utf8.decode(metadataResult));
        final expirationStr = metadata['expiration'] as String?;
        
        if (expirationStr != null) {
          final expiration = DateTime.parse(expirationStr);
          if (DateTime.now().isAfter(expiration)) {
            // Item has expired, remove it and return null
            await remove(key);
            _misses++;
            return null;
          }
        }
      }
      
      // Get the actual cached value
      final fullKey = _getFullKey(key);
      final result = await CloudFlareR2.getObject(
        bucket: _bucket,
        objectName: fullKey,
      );
      
      if (result == null) {
        _misses++;
        return null;
      }
      
      _hits++;
      final jsonStr = utf8.decode(result);
      return _deserializeValue<T>(jsonStr);
    } catch (e) {
      _misses++;
      return null;
    }
  }
  
  @override
  Future<void> set<T>(String key, T value, {Duration? expiration}) async {
    if (!_initialized) return;
    
    _lastAccess = DateTime.now();
    
    try {
      final fullKey = _getFullKey(key);
      
      // Handle serialization of complex objects
      String jsonStr;
      try {
        jsonStr = _serializeValue(value);
      } catch (serializationError) {
        debugPrint('❌ [R2Cache] Serialization failed for key: $key');
        debugPrint('   • Value type: ${value.runtimeType}');
        debugPrint('   • Error: $serializationError');
        rethrow;
      }
      
      final data = utf8.encode(jsonStr);
      
      // Store the value
      await CloudFlareR2.putObject(
        bucket: _bucket,
        objectName: fullKey,
        objectBytes: Uint8List.fromList(data),
        contentType: 'application/json',
      );
      
      // Store metadata with expiration info if provided
      final exp = expiration ?? defaultExpiration;
      if (exp != null) {
        final expirationTime = DateTime.now().add(exp);
        final metadataKey = _getMetadataKey(key);
        final metadata = json.encode({
          'expiration': expirationTime.toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        });
        
        await CloudFlareR2.putObject(
          bucket: _bucket,
          objectName: metadataKey,
          objectBytes: Uint8List.fromList(utf8.encode(metadata)),
          contentType: 'application/json',
        );
      }
      
      _sets++;
    } catch (e) {
      rethrow;
    }
  }
  
  @override
  Future<void> remove(String key) async {
    if (!_initialized) return;
    
    _lastAccess = DateTime.now();
    
    try {
      final fullKey = _getFullKey(key);
      final metadataKey = _getMetadataKey(key);
      
      // Remove both the value and metadata
      await Future.wait([
        CloudFlareR2.deleteObject(bucket: _bucket, objectName: fullKey),
        CloudFlareR2.deleteObject(bucket: _bucket, objectName: metadataKey),
      ]);
      
      _removes++;
    } catch (e) {
      // Ignore errors when removing (object might not exist)
    }
  }
  
  @override
  Future<void> clear() async {
    if (!_initialized) return;
    
    _lastAccess = DateTime.now();
    
    try {
      // List all objects with our prefix
      final objects = await CloudFlareR2.listObjectsV2(
        bucket: _bucket,
        prefix: _keyPrefix,
      );
      
              if (objects.isNotEmpty) {
          // Delete all objects - extract just the names
          final objectNames = <String>[];
          for (final obj in objects) {
            // Try to get the object name/key
            if (obj.toString().isNotEmpty) {
              objectNames.add(obj.toString());
            }
          }
          
          if (objectNames.isNotEmpty) {
            await CloudFlareR2.deleteObjects(
              bucket: _bucket,
              objectNames: objectNames,
            );
            _removes += objectNames.length;
          }
        }
    } catch (e) {
      rethrow;
    }
  }
  
  @override
  Future<bool> containsKey(String key) async {
    try {
      // Check if the item exists and is not expired
      final value = await get(key);
      return value != null;
    } catch (e) {
      return false;
    }
  }
  
  @override
  Future<List<String>> getKeys() async {
    if (!_initialized) return [];
    
    try {
      final objects = await CloudFlareR2.listObjectsV2(
        bucket: _bucket,
        prefix: _keyPrefix,
      );
      
      // Filter out metadata keys and remove prefix
      final keys = <String>[];
      for (final obj in objects) {
        final objStr = obj.toString();
        if (objStr.isNotEmpty && !objStr.contains('meta_') && objStr.startsWith(_keyPrefix)) {
          keys.add(objStr.substring(_keyPrefix.length));
        }
      }
      
      // Filter out expired keys
      final validKeys = <String>[];
      for (final key in keys) {
        if (await containsKey(key)) {
          validKeys.add(key);
        }
      }
      
      return validKeys;
    } catch (e) {
      return [];
    }
  }
  
  @override
  Future<int> get size async {
    final keys = await getKeys();
    return keys.length;
  }
  
  @override
  Future<void> cleanup() async {
    if (!_initialized) return;
    
    try {
      final keys = await getKeys();
      
      // Get all keys that need to be checked for expiration
      final expiredKeys = <String>[];
      
      for (final key in keys) {
        final metadataKey = _getMetadataKey(key);
        try {
          final metadataResult = await CloudFlareR2.getObject(
            bucket: _bucket,
            objectName: metadataKey,
          );
          
          if (metadataResult != null) {
            final metadata = json.decode(utf8.decode(metadataResult));
            final expirationStr = metadata['expiration'] as String?;
            
            if (expirationStr != null) {
              final expiration = DateTime.parse(expirationStr);
              if (DateTime.now().isAfter(expiration)) {
                expiredKeys.add(key);
              }
            }
          }
        } catch (e) {
          // If we can't read metadata, consider the key expired
          expiredKeys.add(key);
        }
      }
      
      // Remove expired keys
      for (final key in expiredKeys) {
        await remove(key);
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }
  
  @override
  CacheStats get stats {
    return CacheStats(
      hits: _hits,
      misses: _misses,
      sets: _sets,
      removes: _removes,
      size: 0, // Size is expensive to calculate for R2, set to 0
      lastAccess: _lastAccess,
    );
  }
  
  /// Reset all statistics
  void resetStats() {
    _hits = 0;
    _misses = 0;
    _sets = 0;
    _removes = 0;
    _lastAccess = DateTime.now();
  }
  
  /// Get detailed information about R2 bucket usage
  Future<Map<String, dynamic>> getBucketInfo() async {
    if (!_initialized) return {'error': 'R2 provider not initialized'};
    
    try {
      final objects = await CloudFlareR2.listObjectsV2(
        bucket: _bucket,
        prefix: _keyPrefix,
      );
      
      final totalSize = objects.fold<int>(
        0,
        (sum, obj) => sum + (obj.size ?? 0),
      );
      
      return {
        'bucket': _bucket,
        'keyPrefix': _keyPrefix,
        'objectCount': objects.length,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }
} 