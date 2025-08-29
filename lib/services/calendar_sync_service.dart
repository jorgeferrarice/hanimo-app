import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';

/// Service for syncing anime release schedules to device calendar
class CalendarSyncService {
  static final CalendarSyncService _instance = CalendarSyncService._internal();
  static CalendarSyncService get instance => _instance;
  
  CalendarSyncService._internal();
  
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  
  /// Request calendar permissions
  Future<bool> requestPermissions() async {
    try {
      debugPrint('📅 [CalendarSync] Requesting calendar permissions...');
      
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      
      if (permissionsGranted.isSuccess && permissionsGranted.data == false) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      }
      
      final hasPermission = permissionsGranted.isSuccess && (permissionsGranted.data ?? false);
      debugPrint('📅 [CalendarSync] Permissions granted: $hasPermission');
      
      return hasPermission;
    } catch (e) {
      debugPrint('❌ [CalendarSync] Failed to request permissions: $e');
      return false;
    }
  }
  
  /// Get available calendars for selection
  Future<List<Calendar>> getAvailableCalendars() async {
    try {
      debugPrint('📅 [CalendarSync] Getting available calendars...');
      
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (!calendarsResult.isSuccess) {
        debugPrint('❌ [CalendarSync] Failed to retrieve calendars: ${calendarsResult.errors}');
        return [];
      }
      
      final calendars = calendarsResult.data?.cast<Calendar>() ?? <Calendar>[];
      debugPrint('📅 [CalendarSync] Found ${calendars.length} calendars');
      
      // Filter to only writable calendars
      final writableCalendars = calendars.where((cal) => cal.isReadOnly == false).toList();
      debugPrint('📅 [CalendarSync] Found ${writableCalendars.length} writable calendars');
      
      return writableCalendars;
    } catch (e) {
      debugPrint('❌ [CalendarSync] Error getting calendars: $e');
      return [];
    }
  }
  
  /// Sync anime releases to device calendar
  Future<bool> syncAnimeReleases({
    required String calendarId,
    required Map<String, List<Map<String, dynamic>>> weeklySchedule,
    required List<String> selectedDays,
    required TimeOfDay syncTime,
    required bool showOnlyFollowed,
    required Function(int malId) isAnimeFollowed,
  }) async {
    try {
      debugPrint('📅 [CalendarSync] Starting anime releases sync...');
      debugPrint('   • Calendar ID: $calendarId');
      debugPrint('   • Selected days: $selectedDays');
      debugPrint('   • Sync time: ${syncTime.hour}:${syncTime.minute.toString().padLeft(2, '0')}');
      debugPrint('   • Show only followed: $showOnlyFollowed');
      
      // Request permissions
      if (!await requestPermissions()) {
        debugPrint('❌ [CalendarSync] Calendar permissions not granted');
        return false;
      }
      
      // Clear existing Hanimo events
      await _clearExistingEvents(calendarId);
      
      int totalEvents = 0;
      int successfulEvents = 0;
      
      // Get current week start (Monday)
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      
      // Create events for selected days
      for (final dayName in selectedDays) {
        final daySchedule = weeklySchedule[dayName];
        if (daySchedule == null || daySchedule.isEmpty) continue;
        
        // Filter anime based on followed status
        final filteredSchedule = showOnlyFollowed
            ? daySchedule.where((anime) => isAnimeFollowed(anime['malId'] ?? 0)).toList()
            : daySchedule;
        
        if (filteredSchedule.isEmpty) continue;
        
        // Calculate the date for this day
        final dayIndex = _getDayIndex(dayName);
        final eventDate = startOfWeek.add(Duration(days: dayIndex));
        final eventDateTime = DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day,
          syncTime.hour,
          syncTime.minute,
        );
        
        // Create events for each anime
        for (final animeData in filteredSchedule) {
          totalEvents++;
          
          final success = await _createAnimeEvent(
            calendarId: calendarId,
            animeData: animeData,
            eventDateTime: eventDateTime,
            dayName: dayName,
          );
          
          if (success) {
            successfulEvents++;
          }
        }
      }
      
      debugPrint('✅ [CalendarSync] Sync completed:');
      debugPrint('   • Total events: $totalEvents');
      debugPrint('   • Successful: $successfulEvents');
      debugPrint('   • Failed: ${totalEvents - successfulEvents}');
      
      return successfulEvents > 0;
    } catch (e, stackTrace) {
      debugPrint('❌ [CalendarSync] Failed to sync anime releases:');
      debugPrint('   • Error: $e');
      debugPrint('   • Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// Clear existing Hanimo events from the calendar
  Future<void> _clearExistingEvents(String calendarId) async {
    try {
      debugPrint('📅 [CalendarSync] Clearing existing events...');
      
      // Get events from the past week to next week
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 7));
      final endDate = now.add(const Duration(days: 7));
      
      final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(
          startDate: startDate,
          endDate: endDate,
        ),
      );
      
      if (!eventsResult.isSuccess) {
        debugPrint('⚠️ [CalendarSync] Failed to retrieve existing events: ${eventsResult.errors}');
        return;
      }
      
      final events = eventsResult.data ?? [];
      int deletedCount = 0;
      
      for (final event in events) {
        // Only delete events that were created by Hanimo (check title or description)
        if (event.title?.contains('[Hanimo]') == true || 
            event.description?.contains('Hanimo app') == true) {
          final deleteResult = await _deviceCalendarPlugin.deleteEvent(calendarId, event.eventId);
          if (deleteResult?.isSuccess == true) {
            deletedCount++;
          }
        }
      }
      
      debugPrint('✅ [CalendarSync] Cleared $deletedCount existing events');
    } catch (e) {
      debugPrint('⚠️ [CalendarSync] Error clearing existing events: $e');
    }
  }
  
  /// Create a calendar event for an anime release
  Future<bool> _createAnimeEvent({
    required String calendarId,
    required Map<String, dynamic> animeData,
    required DateTime eventDateTime,
    required String dayName,
  }) async {
    try {
      final animeTitle = animeData['title'] ?? 'Unknown Anime';
      
      // Create event title and description
      final eventTitle = '[Hanimo] $animeTitle';
      final eventDescription = _buildEventDescription(animeData, dayName);
      
      // Convert to timezone-aware datetime
      final location = tz.local;
      final startTZ = tz.TZDateTime.from(eventDateTime, location);
      final endTZ = tz.TZDateTime.from(eventDateTime.add(const Duration(hours: 1)), location);
      
      final event = Event(
        calendarId,
        title: eventTitle,
        description: eventDescription,
        start: startTZ,
        end: endTZ,
        allDay: false,
        url: animeData['url'],
      );
      
      final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      
      if (result?.isSuccess == true) {
        debugPrint('✅ [CalendarSync] Created event for: $animeTitle');
        return true;
      } else {
        debugPrint('❌ [CalendarSync] Failed to create event for $animeTitle: ${result?.errors}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [CalendarSync] Error creating event for ${animeData['title']}: $e');
      return false;
    }
  }
  
  /// Build event description with anime details
  String _buildEventDescription(Map<String, dynamic> animeData, String dayName) {
    final buffer = StringBuffer();
    
    buffer.writeln('🎌 Anime Release - $dayName');
    buffer.writeln('');
    
    if (animeData['episodes'] != null) {
      buffer.writeln('📺 Episodes: ${animeData['episodes']}');
    }
    
    if (animeData['score'] != null) {
      buffer.writeln('⭐ Score: ${animeData['score']}/10');
    }
    
    if (animeData['status'] != null) {
      buffer.writeln('📊 Status: ${animeData['status']}');
    }
    
    if (animeData['synopsis'] != null && animeData['synopsis'].toString().isNotEmpty) {
      final synopsis = animeData['synopsis'].toString();
      final truncatedSynopsis = synopsis.length > 200 
          ? '${synopsis.substring(0, 200)}...' 
          : synopsis;
      buffer.writeln('');
      buffer.writeln('📖 Synopsis:');
      buffer.writeln(truncatedSynopsis);
    }
    
    buffer.writeln('');
    buffer.writeln('📱 Created by Hanimo app');
    
    return buffer.toString();
  }
  
  /// Get day index (0 = Monday, 6 = Sunday)
  int _getDayIndex(String dayName) {
    switch (dayName.toLowerCase()) {
      case 'monday': return 0;
      case 'tuesday': return 1;
      case 'wednesday': return 2;
      case 'thursday': return 3;
      case 'friday': return 4;
      case 'saturday': return 5;
      case 'sunday': return 6;
      default: return 0;
    }
  }
  
  /// Check if calendar permissions are available
  Future<bool> hasPermissions() async {
    try {
      final result = await _deviceCalendarPlugin.hasPermissions();
      return result.isSuccess && (result.data ?? false);
    } catch (e) {
      debugPrint('❌ [CalendarSync] Error checking permissions: $e');
      return false;
    }
  }
} 