import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:jikan_api/jikan_api.dart';
import 'jikan_service.dart';
import 'cache_service.dart';

/// Service for managing anime release schedules
/// Preloads the next week's schedule on app startup and caches it for 1 day
class ReleaseScheduleService {
  static final ReleaseScheduleService _instance = ReleaseScheduleService._internal();
  static ReleaseScheduleService get instance => _instance;
  
  ReleaseScheduleService._internal();
  
  final JikanService _jikanService = JikanService();
  final CacheService _cacheService = CacheService.instance;
  
  static const String _cacheKeyPrefix = 'release_schedule_';
  static const Duration _cacheDuration = Duration(days: 1);
  
  bool _isInitialized = false;
  bool _isPreloading = false;
  
  /// Initialize the release schedule service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('📅 [ReleaseSchedule] Service already initialized');
      return;
    }
    
    try {
      debugPrint('📅 [ReleaseSchedule] Initializing Release Schedule Service...');
      final startTime = DateTime.now();
      
      // Start preloading in background without blocking
      _startBackgroundPreloading();
      
      _isInitialized = true;
      
      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ [ReleaseSchedule] Service initialized successfully (${duration.inMilliseconds}ms)');
    } catch (e, stackTrace) {
      debugPrint('❌ [ReleaseSchedule] Failed to initialize service:');
      debugPrint('   • Error: $e');
      debugPrint('   • Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Start background preloading of release schedules
  void _startBackgroundPreloading() {
    if (_isPreloading) {
      debugPrint('📅 [ReleaseSchedule] Preloading already in progress');
      return;
    }
    
    // Run preloading in background
    Future.microtask(() async {
      await _preloadNextWeekSchedules();
    });
  }
  
  /// Preload the next week's release schedules
  Future<void> _preloadNextWeekSchedules() async {
    if (_isPreloading) {
      debugPrint('📅 [ReleaseSchedule] Preloading already in progress, skipping...');
      return;
    }
    
    _isPreloading = true;
    
    try {
      debugPrint('📅 [ReleaseSchedule] Starting preload of next week\'s schedules...');
      final startTime = DateTime.now();
      
      // Get all weekdays for the next week
      final weekdays = _getNextWeekDays();
      int successCount = 0;
      int errorCount = 0;
      
      // Preload schedules for each day in parallel
      final futures = weekdays.map((weekday) => _preloadDaySchedule(weekday));
      final results = await Future.wait(futures, eagerError: false);
      
      // Count successes and failures
      for (final result in results) {
        if (result) {
          successCount++;
        } else {
          errorCount++;
        }
      }
      
      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ [ReleaseSchedule] Preloading completed:');
      debugPrint('   • Duration: ${duration.inMilliseconds}ms');
      debugPrint('   • Success: $successCount days');
      debugPrint('   • Errors: $errorCount days');
      debugPrint('   • Total days processed: ${weekdays.length}');
      
    } catch (e, stackTrace) {
      debugPrint('❌ [ReleaseSchedule] Failed to preload schedules:');
      debugPrint('   • Error: $e');
      debugPrint('   • Stack trace: $stackTrace');
    } finally {
      _isPreloading = false;
    }
  }
  
  /// Preload schedule for a specific day
  Future<bool> _preloadDaySchedule(WeekDay weekday) async {
    try {
      final cacheKey = '$_cacheKeyPrefix${weekday.name}';
      
      // Check if data is already cached and still valid
      final cachedData = await _cacheService.get<List<Map<String, dynamic>>>(cacheKey);
      if (cachedData != null) {
        debugPrint('📅 [ReleaseSchedule] ${weekday.name} schedule already cached, skipping...');
        return true;
      }
      
      debugPrint('📅 [ReleaseSchedule] Preloading ${weekday.name} schedule...');
      final dayStartTime = DateTime.now();
      
      // Fetch schedule data from Jikan API
      final scheduleData = await _jikanService.getSchedules(weekday: weekday, page: 1);
      
      // Cache the data with 1-day expiration
      await _cacheService.set(
        cacheKey,
        scheduleData,
        expiration: _cacheDuration,
      );
      
      final dayDuration = DateTime.now().difference(dayStartTime);
      debugPrint('✅ [ReleaseSchedule] ${weekday.name} schedule cached (${scheduleData.length} anime, ${dayDuration.inMilliseconds}ms)');
      
      return true;
    } catch (e) {
      debugPrint('❌ [ReleaseSchedule] Failed to preload ${weekday.name} schedule: $e');
      return false;
    }
  }
  
  /// Get the next 7 days as WeekDay enum values
  List<WeekDay> _getNextWeekDays() {
    final today = DateTime.now();
    final weekdays = <WeekDay>[];
    
    for (int i = 0; i < 7; i++) {
      final date = today.add(Duration(days: i));
      final weekday = _dateTimeToWeekDay(date);
      if (weekday != null) {
        weekdays.add(weekday);
      }
    }
    
    return weekdays;
  }
  
  /// Convert DateTime weekday to Jikan WeekDay enum
  WeekDay? _dateTimeToWeekDay(DateTime dateTime) {
    switch (dateTime.weekday) {
      case DateTime.monday:
        return WeekDay.monday;
      case DateTime.tuesday:
        return WeekDay.tuesday;
      case DateTime.wednesday:
        return WeekDay.wednesday;
      case DateTime.thursday:
        return WeekDay.thursday;
      case DateTime.friday:
        return WeekDay.friday;
      case DateTime.saturday:
        return WeekDay.saturday;
      case DateTime.sunday:
        return WeekDay.sunday;
      default:
        return null;
    }
  }
  
  /// Get cached schedule for a specific day
  /// Returns null if not cached or expired
  Future<List<Map<String, dynamic>>?> getCachedSchedule(WeekDay weekday) async {
    try {
      final cacheKey = '$_cacheKeyPrefix${weekday.name}';
      final cachedData = await _cacheService.get<List<Map<String, dynamic>>>(cacheKey);
      
      if (cachedData != null) {
        debugPrint('📅 [ReleaseSchedule] Retrieved cached ${weekday.name} schedule (${cachedData.length} anime)');
      }
      
      return cachedData;
    } catch (e) {
      debugPrint('❌ [ReleaseSchedule] Failed to get cached ${weekday.name} schedule: $e');
      return null;
    }
  }
  
  /// Get schedule for a specific day (cached first, then API if needed)
  Future<List<Map<String, dynamic>>> getSchedule(WeekDay weekday) async {
    // Try to get from cache first
    final cachedData = await getCachedSchedule(weekday);
    if (cachedData != null) {
      return cachedData;
    }
    
    // Not in cache, fetch from API and cache it
    debugPrint('📅 [ReleaseSchedule] ${weekday.name} not in cache, fetching from API...');
    final scheduleData = await _jikanService.getSchedules(weekday: weekday, page: 1);
    
    // Cache for future use
    final cacheKey = '$_cacheKeyPrefix${weekday.name}';
    await _cacheService.set(
      cacheKey,
      scheduleData,
      expiration: _cacheDuration,
    );
    
    debugPrint('✅ [ReleaseSchedule] ${weekday.name} schedule fetched and cached (${scheduleData.length} anime)');
    return scheduleData;
  }
  
  /// Force refresh all cached schedules
  Future<void> refreshAllSchedules() async {
    debugPrint('📅 [ReleaseSchedule] Force refreshing all schedules...');
    
    // Clear existing cache
    final weekdays = _getNextWeekDays();
    for (final weekday in weekdays) {
      final cacheKey = '$_cacheKeyPrefix${weekday.name}';
      await _cacheService.remove(cacheKey);
    }
    
    // Preload fresh data
    await _preloadNextWeekSchedules();
  }
  
  /// Get cache status for debugging
  Future<Map<String, dynamic>> getCacheStatus() async {
    final status = <String, dynamic>{};
    final weekdays = _getNextWeekDays();
    
    for (final weekday in weekdays) {
      final cacheKey = '$_cacheKeyPrefix${weekday.name}';
      final cachedData = await _cacheService.get<List<Map<String, dynamic>>>(cacheKey);
      
      status[weekday.name] = {
        'cached': cachedData != null,
        'count': cachedData?.length ?? 0,
      };
    }
    
    return status;
  }
  
  /// Print debug information about cached schedules
  Future<void> printCacheStatus() async {
    debugPrint('📅 [ReleaseSchedule] Cache Status:');
    final status = await getCacheStatus();
    
    for (final entry in status.entries) {
      final weekday = entry.key;
      final data = entry.value as Map<String, dynamic>;
      final cached = data['cached'] as bool;
      final count = data['count'] as int;
      
      debugPrint('   • $weekday: ${cached ? 'Cached ($count anime)' : 'Not cached'}');
    }
  }
  
  /// Check if the service is currently preloading schedules
  bool get isPreloading => _isPreloading;
  
  /// Check if the service has been initialized
  bool get isInitialized => _isInitialized;
  
  /// Get service status for debugging
  Map<String, dynamic> getServiceStatus() {
    return {
      'initialized': _isInitialized,
      'preloading': _isPreloading,
      'cache_duration_hours': _cacheDuration.inHours,
    };
  }
} 