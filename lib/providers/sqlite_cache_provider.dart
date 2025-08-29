import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../services/cache_provider.dart';

/// SQLite-based cache provider implementation with comprehensive debugging
/// Stores cache data persistently in a SQLite database with automatic expiration
class SQLiteCacheProvider implements CacheProvider {
  Database? _database;
  Timer? _cleanupTimer;
  Timer? _statsTimer;
  
  // Enhanced statistics tracking
  int _hits = 0;
  int _misses = 0;
  int _sets = 0;
  int _removes = 0;
  DateTime _lastAccess = DateTime.now();
  
  // Performance tracking
  final List<Duration> _queryTimes = [];
  final List<Duration> _writeTimes = [];
  int _totalQueries = 0;
  int _totalWrites = 0;
  double _avgQueryTime = 0.0;
  double _avgWriteTime = 0.0;
  
  // Database health metrics
  int _databaseSize = 0;
  int _pageCount = 0;
  int _pageSize = 0;
  DateTime _lastHealthCheck = DateTime.now();
  
  /// Maximum number of items to store in cache
  final int? maxSize;
  
  /// Default expiration duration for cache entries
  final Duration? defaultExpiration;
  
  /// Automatic cleanup interval
  final Duration cleanupInterval;
  
  /// Statistics reporting interval
  final Duration statsInterval;
  
  /// Database file name
  final String databaseName;
  
  /// Enable detailed debugging
  final bool enableDebugLogging;
  
  /// Enable performance tracking
  final bool enablePerformanceTracking;
  
  SQLiteCacheProvider({
    this.maxSize,
    this.defaultExpiration,
    this.cleanupInterval = const Duration(minutes: 5),
    this.statsInterval = const Duration(minutes: 10),
    this.databaseName = 'hanimo_cache.db',
    this.enableDebugLogging = true,
    this.enablePerformanceTracking = true,
  });
  
  /// Initialize the SQLite database with comprehensive debugging
  Future<void> _initDatabase() async {
    if (_database != null) return;
    
    _debugLog('🗄️  [SQLiteCache] Initializing SQLite cache database...', isImportant: true);
    final startTime = DateTime.now();
    
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, databaseName);
      
      _debugLog('🗄️  [SQLiteCache] Database path: $path');
      _debugLog('🗄️  [SQLiteCache] Max size: ${maxSize ?? "unlimited"}');
      _debugLog('🗄️  [SQLiteCache] Default expiration: ${defaultExpiration ?? "none"}');
      _debugLog('🗄️  [SQLiteCache] Cleanup interval: $cleanupInterval');
      
      _database = await openDatabase(
        path,
        version: 1,
        onCreate: _createTables,
        onUpgrade: _upgradeDatabase,
      );
      
      // Get initial database metrics
      await _updateDatabaseMetrics();
      
      // Start timers
      _startCleanupTimer();
      _startStatsTimer();
      
      final initDuration = DateTime.now().difference(startTime);
      _debugLog('✅ [SQLiteCache] SQLite cache database initialized successfully', isImportant: true);
      _debugLog('   • Initialize duration: ${initDuration.inMilliseconds}ms');
      _debugLog('   • Initial size: $_databaseSize bytes');
      _debugLog('   • Page count: $_pageCount');
      _debugLog('   • Page size: $_pageSize bytes');
      
      // Print startup summary
      await _printStartupSummary();
      
    } catch (e, stackTrace) {
      _debugLog('❌ [SQLiteCache] Failed to initialize database: $e', isError: true);
      _debugLog('   Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Create database tables with enhanced schema
  Future<void> _createTables(Database db, int version) async {
    _debugLog('🗄️  [SQLiteCache] Creating cache tables...', isImportant: true);
    final startTime = DateTime.now();
    
    await db.execute('''
      CREATE TABLE cache_entries (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        value_type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER,
        access_count INTEGER DEFAULT 0,
        last_accessed INTEGER NOT NULL,
        value_size INTEGER DEFAULT 0
      )
    ''');
    
    // Create optimized indexes
    await db.execute('CREATE INDEX idx_cache_expires_at ON cache_entries(expires_at)');
    await db.execute('CREATE INDEX idx_cache_last_accessed ON cache_entries(last_accessed)');
    await db.execute('CREATE INDEX idx_cache_created_at ON cache_entries(created_at)');
    await db.execute('CREATE INDEX idx_cache_access_count ON cache_entries(access_count DESC)');
    
    final duration = DateTime.now().difference(startTime);
    _debugLog('✅ [SQLiteCache] Cache tables created successfully');
    _debugLog('   • Creation duration: ${duration.inMilliseconds}ms');
  }
  
  /// Upgrade database schema
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    _debugLog('🗄️  [SQLiteCache] Upgrading database from v$oldVersion to v$newVersion', isImportant: true);
    // Handle future schema upgrades here
  }
  
  /// Start the automatic cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(cleanupInterval, (_) async {
      _debugLog('🧹 [SQLiteCache] Running scheduled cleanup...');
      await cleanup();
    });
    _debugLog('⏰ [SQLiteCache] Cleanup timer started (interval: $cleanupInterval)');
  }
  
  /// Start the statistics reporting timer
  void _startStatsTimer() {
    if (!enableDebugLogging) return;
    
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(statsInterval, (_) async {
      _debugLog('📊 [SQLiteCache] Periodic statistics report...', isImportant: true);
      await _printDetailedStats();
    });
    _debugLog('⏰ [SQLiteCache] Statistics timer started (interval: $statsInterval)');
  }
  
  /// Dispose of the provider and close database
  Future<void> dispose() async {
    _debugLog('🗄️  [SQLiteCache] Disposing SQLite cache provider...', isImportant: true);
    final startTime = DateTime.now();
    
    _cleanupTimer?.cancel();
    _statsTimer?.cancel();
    
    if (_database != null) {
      // Print final statistics
      await _printFinalStats();
      
      await _database!.close();
      _database = null;
    }
    
    final duration = DateTime.now().difference(startTime);
    _debugLog('✅ [SQLiteCache] SQLite cache provider disposed');
    _debugLog('   • Dispose duration: ${duration.inMilliseconds}ms');
  }
  
  @override
  Future<T?> get<T>(String key) async {
    await _initDatabase();
    _lastAccess = DateTime.now();
    
    final startTime = DateTime.now();
    _debugLog('🔍 [SQLiteCache] GET operation for key: "$key"');
    
    try {
      final result = await _database!.query(
        'cache_entries',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      
      final queryDuration = DateTime.now().difference(startTime);
      _trackQueryPerformance(queryDuration);
      
      if (result.isEmpty) {
        _misses++;
        _debugLog('❌ [SQLiteCache] GET miss - key not found');
        _debugLog('   • Query duration: ${queryDuration.inMicroseconds}μs');
        return null;
      }
      
      final row = result.first;
      final expiresAt = row['expires_at'] as int?;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check if expired
      if (expiresAt != null && now > expiresAt) {
        await _removeExpiredEntry(key);
        _misses++;
        _debugLog('❌ [SQLiteCache] GET miss - entry expired');
        _debugLog('   • Expired at: ${DateTime.fromMillisecondsSinceEpoch(expiresAt)}');
        _debugLog('   • Query duration: ${queryDuration.inMicroseconds}μs');
        return null;
      }
      
      // Update access statistics
      await _updateAccessStats(key);
      
      final valueStr = row['value'] as String;
      final valueType = row['value_type'] as String;
      final valueSize = row['value_size'] as int? ?? valueStr.length;
      final accessCount = row['access_count'] as int? ?? 0;
      final createdAt = row['created_at'] as int?;
      
      // Deserialize value based on type
      final value = _deserializeValue<T>(valueStr, valueType);
      
      _hits++;
      _debugLog('✅ [SQLiteCache] GET hit');
      _debugLog('   • Value type: $valueType');
      _debugLog('   • Value size: ${valueSize} bytes');
      _debugLog('   • Access count: ${accessCount + 1}');
      _debugLog('   • Age: ${createdAt != null ? DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(createdAt)).inMinutes : "unknown"} minutes');
      _debugLog('   • Query duration: ${queryDuration.inMicroseconds}μs');
      
      return value;
    } catch (e, stackTrace) {
      final queryDuration = DateTime.now().difference(startTime);
      _debugLog('❌ [SQLiteCache] Error in GET operation: $e', isError: true);
      _debugLog('   • Query duration: ${queryDuration.inMicroseconds}μs');
      _debugLog('   • Stack trace: $stackTrace');
      _misses++;
      return null;
    }
  }
  
  @override
  Future<void> set<T>(String key, T value, {Duration? expiration}) async {
    await _initDatabase();
    _lastAccess = DateTime.now();
    
    final startTime = DateTime.now();
    _debugLog('💾 [SQLiteCache] SET operation for key: "$key"');
    _debugLog('   • Value type: ${value.runtimeType}');
    
    try {
      // Use provided expiration or default
      final exp = expiration ?? defaultExpiration;
      final now = DateTime.now();
      final expiresAt = exp != null ? now.add(exp).millisecondsSinceEpoch : null;
      
      _debugLog('   • Expiration: ${exp?.toString() ?? 'none'}');
      if (expiresAt != null) {
        _debugLog('   • Expires at: ${DateTime.fromMillisecondsSinceEpoch(expiresAt)}');
      }
      
      // Check if we need to make room
      if (maxSize != null) {
        await _enforceMaxSize();
      }
      
      // Serialize value
      final serializedValue = _serializeValue(value);
      final valueType = _getValueType(value);
      final valueSize = serializedValue.length;
      
      _debugLog('   • Serialized size: $valueSize bytes');
      
      // Insert or replace entry
      await _database!.insert(
        'cache_entries',
        {
          'key': key,
          'value': serializedValue,
          'value_type': valueType,
          'created_at': now.millisecondsSinceEpoch,
          'expires_at': expiresAt,
          'access_count': 1,
          'last_accessed': now.millisecondsSinceEpoch,
          'value_size': valueSize,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      final writeDuration = DateTime.now().difference(startTime);
      _trackWritePerformance(writeDuration);
      
      _sets++;
      _debugLog('✅ [SQLiteCache] SET completed');
      _debugLog('   • Write duration: ${writeDuration.inMicroseconds}μs');
      
      // Update database metrics periodically
      if (_sets % 10 == 0) {
        await _updateDatabaseMetrics();
      }
      
    } catch (e, stackTrace) {
      final writeDuration = DateTime.now().difference(startTime);
      _debugLog('❌ [SQLiteCache] Error in SET operation: $e', isError: true);
      _debugLog('   • Write duration: ${writeDuration.inMicroseconds}μs');
      _debugLog('   • Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  @override
  Future<void> remove(String key) async {
    await _initDatabase();
    _lastAccess = DateTime.now();
    
    final startTime = DateTime.now();
    _debugLog('🗑️  [SQLiteCache] REMOVE operation for key: "$key"');
    
    try {
      final count = await _database!.delete(
        'cache_entries',
        where: 'key = ?',
        whereArgs: [key],
      );
      
      final duration = DateTime.now().difference(startTime);
      
      if (count > 0) {
        _removes++;
        _debugLog('✅ [SQLiteCache] Removed key: "$key"');
        _debugLog('   • Remove duration: ${duration.inMicroseconds}μs');
      } else {
        _debugLog('⚠️  [SQLiteCache] Key not found: "$key"');
        _debugLog('   • Remove duration: ${duration.inMicroseconds}μs');
      }
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      _debugLog('❌ [SQLiteCache] Error removing key "$key": $e', isError: true);
      _debugLog('   • Remove duration: ${duration.inMicroseconds}μs');
      _debugLog('   • Stack trace: $stackTrace');
    }
  }
  
  @override
  Future<void> clear() async {
    await _initDatabase();
    _lastAccess = DateTime.now();
    
    final startTime = DateTime.now();
    _debugLog('🧹 [SQLiteCache] CLEAR operation - removing all entries', isImportant: true);
    
    try {
      final count = await _database!.delete('cache_entries');
      final duration = DateTime.now().difference(startTime);
      
      _removes += count;
      _debugLog('✅ [SQLiteCache] Cleared all entries');
      _debugLog('   • Entries removed: $count');
      _debugLog('   • Clear duration: ${duration.inMilliseconds}ms');
      
      // Update database metrics after clear
      await _updateDatabaseMetrics();
      
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      _debugLog('❌ [SQLiteCache] Error clearing cache: $e', isError: true);
      _debugLog('   • Clear duration: ${duration.inMilliseconds}ms');
      _debugLog('   • Stack trace: $stackTrace');
    }
  }
  
  @override
  Future<bool> containsKey(String key) async {
    await _initDatabase();
    
    final startTime = DateTime.now();
    _debugLog('🔍 [SQLiteCache] CONTAINS_KEY operation for key: "$key"');
    
    try {
      final result = await _database!.query(
        'cache_entries',
        columns: ['expires_at'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      
      final queryDuration = DateTime.now().difference(startTime);
      _trackQueryPerformance(queryDuration);
      
      if (result.isEmpty) {
        _debugLog('❌ [SQLiteCache] Key not found: "$key"');
        _debugLog('   • Query duration: ${queryDuration.inMicroseconds}μs');
        return false;
      }
      
      final expiresAt = result.first['expires_at'] as int?;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check if expired
      if (expiresAt != null && now > expiresAt) {
        await _removeExpiredEntry(key);
        _debugLog('❌ [SQLiteCache] Key expired: "$key"');
        _debugLog('   • Query duration: ${queryDuration.inMicroseconds}μs');
        return false;
      }
      
      _debugLog('✅ [SQLiteCache] Key exists: "$key"');
      _debugLog('   • Query duration: ${queryDuration.inMicroseconds}μs');
      return true;
    } catch (e) {
      final queryDuration = DateTime.now().difference(startTime);
      _debugLog('❌ [SQLiteCache] Error checking key "$key": $e', isError: true);
      _debugLog('   • Query duration: ${queryDuration.inMicroseconds}μs');
      return false;
    }
  }
  
  @override
  Future<List<String>> getKeys() async {
    await _initDatabase();
    await cleanup(); // Remove expired entries first
    
    final startTime = DateTime.now();
    _debugLog('📋 [SQLiteCache] GET_KEYS operation');
    
    try {
      final result = await _database!.query(
        'cache_entries',
        columns: ['key'],
      );
      
      final queryDuration = DateTime.now().difference(startTime);
      _trackQueryPerformance(queryDuration);
      
      final keys = result.map((row) => row['key'] as String).toList();
      _debugLog('✅ [SQLiteCache] Retrieved ${keys.length} keys');
      _debugLog('   • Query duration: ${queryDuration.inMicroseconds}μs');
      
      return keys;
    } catch (e) {
      final queryDuration = DateTime.now().difference(startTime);
      _debugLog('❌ [SQLiteCache] Error getting keys: $e', isError: true);
      _debugLog('   • Query duration: ${queryDuration.inMicroseconds}μs');
      return [];
    }
  }
  
  @override
  Future<int> get size async {
    await _initDatabase();
    await cleanup(); // Remove expired entries first
    
    final startTime = DateTime.now();
    _debugLog('📏 [SQLiteCache] GET_SIZE operation');
    
    try {
      final result = await _database!.rawQuery('SELECT COUNT(*) as count FROM cache_entries');
      final queryDuration = DateTime.now().difference(startTime);
      _trackQueryPerformance(queryDuration);
      
      final count = result.first['count'] as int;
      _debugLog('✅ [SQLiteCache] Current size: $count entries');
      _debugLog('   • Query duration: ${queryDuration.inMicroseconds}μs');
      
      return count;
    } catch (e) {
      final queryDuration = DateTime.now().difference(startTime);
      _debugLog('❌ [SQLiteCache] Error getting size: $e', isError: true);
      _debugLog('   • Query duration: ${queryDuration.inMicroseconds}μs');
      return 0;
    }
  }
  
  @override
  Future<void> cleanup() async {
    await _initDatabase();
    
    final startTime = DateTime.now();
    _debugLog('🧹 [SQLiteCache] CLEANUP operation - removing expired entries');
    
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Get count of expired entries first for logging
      final expiredCountResult = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM cache_entries WHERE expires_at IS NOT NULL AND expires_at <= ?',
        [now],
      );
      final expiredCount = expiredCountResult.first['count'] as int;
      
      if (expiredCount > 0) {
        final count = await _database!.delete(
          'cache_entries',
          where: 'expires_at IS NOT NULL AND expires_at <= ?',
          whereArgs: [now],
        );
        
        final cleanupDuration = DateTime.now().difference(startTime);
        _removes += count;
        _debugLog('✅ [SQLiteCache] Cleaned up $count expired entries');
        _debugLog('   • Cleanup duration: ${cleanupDuration.inMilliseconds}ms');
        
        // Update database metrics after cleanup
        await _updateDatabaseMetrics();
      } else {
        final cleanupDuration = DateTime.now().difference(startTime);
        _debugLog('✅ [SQLiteCache] No expired entries to clean up');
        _debugLog('   • Cleanup duration: ${cleanupDuration.inMilliseconds}ms');
      }
    } catch (e) {
      final cleanupDuration = DateTime.now().difference(startTime);
      _debugLog('❌ [SQLiteCache] Error during cleanup: $e', isError: true);
      _debugLog('   • Cleanup duration: ${cleanupDuration.inMilliseconds}ms');
    }
  }
  
  @override
  CacheStats get stats {
    final hitRate = _hits + _misses > 0 ? _hits / (_hits + _misses) : 0.0;
    _debugLog('📊 [SQLiteCache] Current statistics:');
    _debugLog('   • Hits: $_hits');
    _debugLog('   • Misses: $_misses');
    _debugLog('   • Hit rate: ${(hitRate * 100).toStringAsFixed(1)}%');
    _debugLog('   • Sets: $_sets');
    _debugLog('   • Removes: $_removes');
    _debugLog('   • Avg query time: ${_avgQueryTime.toStringAsFixed(0)}μs');
    _debugLog('   • Avg write time: ${_avgWriteTime.toStringAsFixed(0)}μs');
    
    return CacheStats(
      hits: _hits,
      misses: _misses,
      sets: _sets,
      removes: _removes,
      size: 0, // Will be updated async
      lastAccess: _lastAccess,
    );
  }
  
  /// Remove expired entry with debugging
  Future<void> _removeExpiredEntry(String key) async {
    _debugLog('🗑️  [SQLiteCache] Removing expired entry: "$key"');
    
    try {
      await _database!.delete(
        'cache_entries',
        where: 'key = ?',
        whereArgs: [key],
      );
      _removes++;
      _debugLog('✅ [SQLiteCache] Expired entry removed: "$key"');
    } catch (e) {
      _debugLog('❌ [SQLiteCache] Error removing expired entry "$key": $e', isError: true);
    }
  }
  
  /// Update access statistics for a key with debugging
  Future<void> _updateAccessStats(String key) async {
    try {
      await _database!.rawUpdate(
        'UPDATE cache_entries SET access_count = access_count + 1, last_accessed = ? WHERE key = ?',
        [DateTime.now().millisecondsSinceEpoch, key],
      );
      _debugLog('📈 [SQLiteCache] Updated access stats for key: "$key"');
    } catch (e) {
      _debugLog('❌ [SQLiteCache] Error updating access stats for "$key": $e', isError: true);
    }
  }
  
  /// Enforce maximum cache size by removing least recently used entries
  Future<void> _enforceMaxSize() async {
    try {
      final currentSize = await size;
      
      if (currentSize >= maxSize!) {
        final entriesToRemove = currentSize - maxSize! + 1;
        
        _debugLog('🚫 [SQLiteCache] Enforcing max size limit');
        _debugLog('   • Current size: $currentSize');
        _debugLog('   • Max size: $maxSize');
        _debugLog('   • Entries to remove: $entriesToRemove');
        
        // Remove least recently used entries
        final result = await _database!.query(
          'cache_entries',
          columns: ['key'],
          orderBy: 'last_accessed ASC',
          limit: entriesToRemove,
        );
        
        for (final row in result) {
          await remove(row['key'] as String);
        }
        
        _debugLog('✅ [SQLiteCache] Removed $entriesToRemove entries to enforce max size');
      }
    } catch (e) {
      _debugLog('❌ [SQLiteCache] Error enforcing max size: $e', isError: true);
    }
  }
  
  /// Serialize value to string for storage
  String _serializeValue(dynamic value) {
    if (value == null) return '';
    
    try {
      if (value is String) {
        return value;
      } else if (value is Map || value is List) {
        return jsonEncode(value);
      } else {
        return value.toString();
      }
    } catch (e) {
      _debugLog('❌ [SQLiteCache] Error serializing value: $e', isError: true);
      return value.toString();
    }
  }
  
  /// Deserialize value from string with type-safe handling
  T? _deserializeValue<T>(String valueStr, String valueType) {
    if (valueStr.isEmpty) return null;
    
    try {
      dynamic decoded;
      
      switch (valueType) {
        case 'String':
          decoded = valueStr;
          break;
        case 'int':
          decoded = int.parse(valueStr);
          break;
        case 'double':
          decoded = double.parse(valueStr);
          break;
        case 'bool':
          decoded = valueStr.toLowerCase() == 'true';
          break;
        case 'Map':
        case 'List':
        case '_InternalLinkedHashMap':
        case '_GrowableList':
          decoded = jsonDecode(valueStr);
          break;
        default:
          // Try JSON decode first, fallback to string
          try {
            decoded = jsonDecode(valueStr);
          } catch (_) {
            decoded = valueStr;
          }
      }
      
      // Type-safe casting with special handling for common generic types
      return _safeCast<T>(decoded, valueType);
      
    } catch (e) {
      _debugLog('❌ [SQLiteCache] Error deserializing value of type $valueType: $e', isError: true);
      return null;
    }
  }
  
  /// Safely cast decoded value to the expected type
  T? _safeCast<T>(dynamic decoded, String valueType) {
    if (decoded == null) return null;
    
    try {
      // Handle List<Map<String, dynamic>> specifically
      if (T.toString().contains('List<Map<String, dynamic>>') && decoded is List) {
        _debugLog('🔧 [SQLiteCache] Converting List<dynamic> to List<Map<String, dynamic>>');
        final List<Map<String, dynamic>> convertedList = decoded
            .map((item) => item is Map<String, dynamic> 
                ? item 
                : item is Map 
                    ? Map<String, dynamic>.from(item)
                    : <String, dynamic>{})
            .toList();
        _debugLog('✅ [SQLiteCache] Converted to List<Map<String, dynamic>> with ${convertedList.length} items');
        return convertedList as T?;
      }
      
      // Handle Map<String, dynamic> specifically
      if (T.toString().contains('Map<String, dynamic>') && decoded is Map) {
        _debugLog('🔧 [SQLiteCache] Converting Map to Map<String, dynamic>');
        final Map<String, dynamic> convertedMap = Map<String, dynamic>.from(decoded);
        return convertedMap as T?;
      }
      
      // Handle List<String> specifically
      if (T.toString().contains('List<String>') && decoded is List) {
        _debugLog('🔧 [SQLiteCache] Converting List<dynamic> to List<String>');
        final List<String> convertedList = decoded
            .map((item) => item?.toString() ?? '')
            .toList();
        return convertedList as T?;
      }
      
      // Handle List<int> specifically
      if (T.toString().contains('List<int>') && decoded is List) {
        _debugLog('🔧 [SQLiteCache] Converting List<dynamic> to List<int>');
        final List<int> convertedList = decoded
            .map((item) => item is int ? item : int.tryParse(item?.toString() ?? '') ?? 0)
            .toList();
        return convertedList as T?;
      }
      
      // Generic List handling
      if (T.toString().startsWith('List<') && decoded is List) {
        _debugLog('🔧 [SQLiteCache] Converting List<dynamic> to ${T.toString()}');
        return decoded as T?;
      }
      
      // Generic Map handling
      if (T.toString().startsWith('Map<') && decoded is Map) {
        _debugLog('🔧 [SQLiteCache] Converting Map to ${T.toString()}');
        return decoded as T?;
      }
      
      // Direct casting for primitive types and other objects
      return decoded as T?;
      
    } catch (e) {
      _debugLog('❌ [SQLiteCache] Error casting to type ${T.toString()}: $e', isError: true);
      _debugLog('   • Decoded type: ${decoded.runtimeType}');
      _debugLog('   • Decoded value: $decoded');
      return null;
    }
  }
  
  /// Get value type string for storage
  String _getValueType(dynamic value) {
    if (value == null) return 'null';
    return value.runtimeType.toString();
  }
  
  /// Track query performance
  void _trackQueryPerformance(Duration duration) {
    if (!enablePerformanceTracking) return;
    
    _queryTimes.add(duration);
    _totalQueries++;
    
    // Calculate rolling average
    _avgQueryTime = (_avgQueryTime * (_totalQueries - 1) + duration.inMicroseconds) / _totalQueries;
    
    // Keep only recent query times (last 100) to prevent memory bloat
    if (_queryTimes.length > 100) {
      _queryTimes.removeAt(0);
    }
  }
  
  /// Track write performance
  void _trackWritePerformance(Duration duration) {
    if (!enablePerformanceTracking) return;
    
    _writeTimes.add(duration);
    _totalWrites++;
    
    // Calculate rolling average
    _avgWriteTime = (_avgWriteTime * (_totalWrites - 1) + duration.inMicroseconds) / _totalWrites;
    
    // Keep only recent write times (last 100) to prevent memory bloat
    if (_writeTimes.length > 100) {
      _writeTimes.removeAt(0);
    }
  }
  
  /// Update database metrics
  Future<void> _updateDatabaseMetrics() async {
    try {
      if (_database?.path != null) {
        final file = File(_database!.path!);
        if (await file.exists()) {
          _databaseSize = await file.length();
        }
      }
      
      // Get database page information
      final pageCountResult = await _database!.rawQuery('PRAGMA page_count');
      _pageCount = pageCountResult.first['page_count'] as int? ?? 0;
      
      final pageSizeResult = await _database!.rawQuery('PRAGMA page_size');
      _pageSize = pageSizeResult.first['page_size'] as int? ?? 0;
      
      _lastHealthCheck = DateTime.now();
      
      _debugLog('📊 [SQLiteCache] Database metrics updated:');
      _debugLog('   • Database size: ${(_databaseSize / 1024).toStringAsFixed(1)} KB');
      _debugLog('   • Page count: $_pageCount');
      _debugLog('   • Page size: $_pageSize bytes');
      
    } catch (e) {
      _debugLog('❌ [SQLiteCache] Error updating database metrics: $e', isError: true);
    }
  }
  
  /// Print startup summary
  Future<void> _printStartupSummary() async {
    if (!enableDebugLogging) return;
    
    _debugLog('🚀 [SQLiteCache] Startup Summary:', isImportant: true);
    _debugLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _debugLog('💾 Database: ${_database?.path ?? "unknown"}');
    _debugLog('📊 Initial size: ${(_databaseSize / 1024).toStringAsFixed(1)} KB');
    _debugLog('📄 Pages: $_pageCount × $_pageSize bytes');
    _debugLog('⚙️  Max entries: ${maxSize ?? "unlimited"}');
    _debugLog('⏱️  Default expiration: ${defaultExpiration ?? "none"}');
    _debugLog('🧹 Cleanup interval: $cleanupInterval');
    _debugLog('📈 Stats interval: $statsInterval');
    _debugLog('🔍 Debug logging: $enableDebugLogging');
    _debugLog('⚡ Performance tracking: $enablePerformanceTracking');
    _debugLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
  
  /// Print detailed statistics
  Future<void> _printDetailedStats() async {
    if (!enableDebugLogging) return;
    
    try {
      final currentSize = await size;
      final hitRate = _hits + _misses > 0 ? _hits / (_hits + _misses) : 0.0;
      final expiredCount = await _getExpiredCount();
      
      _debugLog('📊 [SQLiteCache] Detailed Statistics:', isImportant: true);
      _debugLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _debugLog('🎯 Cache Performance:');
      _debugLog('   • Hits: $_hits');
      _debugLog('   • Misses: $_misses');
      _debugLog('   • Hit Rate: ${(hitRate * 100).toStringAsFixed(1)}%');
      _debugLog('   • Sets: $_sets');
      _debugLog('   • Removes: $_removes');
      _debugLog('');
      _debugLog('⚡ Performance Metrics:');
      _debugLog('   • Total queries: $_totalQueries');
      _debugLog('   • Avg query time: ${_avgQueryTime.toStringAsFixed(0)}μs');
      _debugLog('   • Total writes: $_totalWrites');
      _debugLog('   • Avg write time: ${_avgWriteTime.toStringAsFixed(0)}μs');
      _debugLog('');
      _debugLog('💾 Database Health:');
      _debugLog('   • Current entries: $currentSize');
      _debugLog('   • Expired entries: $expiredCount');
      _debugLog('   • Database size: ${(_databaseSize / 1024).toStringAsFixed(1)} KB');
      _debugLog('   • Page count: $_pageCount');
      _debugLog('   • Last health check: ${_formatDateTime(_lastHealthCheck)}');
      _debugLog('   • Last access: ${_formatDateTime(_lastAccess)}');
      _debugLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
    } catch (e) {
      _debugLog('❌ [SQLiteCache] Error generating detailed stats: $e', isError: true);
    }
  }
  
  /// Print final statistics on disposal
  Future<void> _printFinalStats() async {
    if (!enableDebugLogging) return;
    
    try {
      final currentSize = await size;
      final hitRate = _hits + _misses > 0 ? _hits / (_hits + _misses) : 0.0;
      
      _debugLog('🏁 [SQLiteCache] Final Statistics:', isImportant: true);
      _debugLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _debugLog('📈 Session Summary:');
      _debugLog('   • Total hits: $_hits');
      _debugLog('   • Total misses: $_misses');
      _debugLog('   • Final hit rate: ${(hitRate * 100).toStringAsFixed(1)}%');
      _debugLog('   • Total sets: $_sets');
      _debugLog('   • Total removes: $_removes');
      _debugLog('   • Final size: $currentSize entries');
      _debugLog('');
      _debugLog('⚡ Performance Summary:');
      _debugLog('   • Total queries executed: $_totalQueries');
      _debugLog('   • Average query time: ${_avgQueryTime.toStringAsFixed(0)}μs');
      _debugLog('   • Total writes executed: $_totalWrites');
      _debugLog('   • Average write time: ${_avgWriteTime.toStringAsFixed(0)}μs');
      _debugLog('   • Final database size: ${(_databaseSize / 1024).toStringAsFixed(1)} KB');
      _debugLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
    } catch (e) {
      _debugLog('❌ [SQLiteCache] Error generating final stats: $e', isError: true);
    }
  }
  
  /// Debug logging helper
  void _debugLog(String message, {bool isImportant = false, bool isError = false}) {
    if (!enableDebugLogging) return;
    
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    
    if (isError) {
      debugPrint('[$timestamp] $message');
    } else if (isImportant) {
      debugPrint('[$timestamp] $message');
    } else {
      debugPrint('[$timestamp] $message');
    }
  }
  
  /// Format DateTime for logging
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}:'
           '${dateTime.second.toString().padLeft(2, '0')}';
  }
  
  /// Get count of expired entries
  Future<int> _getExpiredCount() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final result = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM cache_entries WHERE expires_at IS NOT NULL AND expires_at <= ?',
        [now],
      );
      return result.first['count'] as int;
    } catch (e) {
      _debugLog('❌ [SQLiteCache] Error getting expired count: $e', isError: true);
      return 0;
    }
  }
  
  /// Get detailed cache information for debugging
  Future<Map<String, dynamic>> getDebugInfo() async {
    await _initDatabase();
    
    try {
      final totalEntries = await size;
      final expiredCount = await _getExpiredCount();
      final sizeInfo = await _getSizeInfo();
      final hitRate = _hits + _misses > 0 ? _hits / (_hits + _misses) : 0.0;
      
      return {
        'provider': 'SQLite',
        'database_path': _database?.path ?? 'not initialized',
        'database_size_bytes': _databaseSize,
        'database_size_kb': (_databaseSize / 1024).toStringAsFixed(1),
        'page_count': _pageCount,
        'page_size': _pageSize,
        'total_entries': totalEntries,
        'expired_entries': expiredCount,
        'stats': {
          'hits': _hits,
          'misses': _misses,
          'hit_rate': '${(hitRate * 100).toStringAsFixed(1)}%',
          'sets': _sets,
          'removes': _removes,
          'last_access': _lastAccess.toIso8601String(),
        },
        'performance': {
          'total_queries': _totalQueries,
          'avg_query_time_us': _avgQueryTime.toStringAsFixed(0),
          'total_writes': _totalWrites,
          'avg_write_time_us': _avgWriteTime.toStringAsFixed(0),
        },
        'size_info': sizeInfo,
        'config': {
          'max_size': maxSize,
          'default_expiration': defaultExpiration?.toString(),
          'cleanup_interval': cleanupInterval.toString(),
          'stats_interval': statsInterval.toString(),
          'debug_logging': enableDebugLogging,
          'performance_tracking': enablePerformanceTracking,
        },
        'health': {
          'last_health_check': _lastHealthCheck.toIso8601String(),
          'database_accessible': _database != null,
        }
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'provider': 'SQLite',
        'debug_logging': enableDebugLogging,
      };
    }
  }
  
  /// Get cache size information
  Future<Map<String, dynamic>> _getSizeInfo() async {
    try {
      final result = await _database!.rawQuery('''
        SELECT 
          COUNT(*) as total_entries,
          AVG(value_size) as avg_value_size,
          MAX(value_size) as max_value_size,
          MIN(value_size) as min_value_size,
          SUM(value_size) as total_value_size,
          MIN(created_at) as oldest_entry,
          MAX(created_at) as newest_entry,
          AVG(access_count) as avg_access_count,
          MAX(access_count) as max_access_count
        FROM cache_entries
      ''');
      
      final row = result.first;
      final oldestEntry = row['oldest_entry'] as int?;
      final newestEntry = row['newest_entry'] as int?;
      
      return {
        'total_entries': row['total_entries'],
        'avg_value_size': (row['avg_value_size'] as double?)?.toStringAsFixed(1) ?? '0',
        'max_value_size': row['max_value_size'],
        'min_value_size': row['min_value_size'],
        'total_value_size': row['total_value_size'],
        'oldest_entry': oldestEntry != null 
            ? DateTime.fromMillisecondsSinceEpoch(oldestEntry).toIso8601String() 
            : null,
        'newest_entry': newestEntry != null 
            ? DateTime.fromMillisecondsSinceEpoch(newestEntry).toIso8601String() 
            : null,
        'avg_access_count': (row['avg_access_count'] as double?)?.toStringAsFixed(1) ?? '0',
        'max_access_count': row['max_access_count'],
      };
    } catch (e) {
      _debugLog('❌ [SQLiteCache] Error getting size info: $e', isError: true);
      return {'error': e.toString()};
    }
  }
} 