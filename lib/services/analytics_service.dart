import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static AnalyticsService get instance => _instance;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Get the analytics observer for navigation tracking
  FirebaseAnalyticsObserver get observer => FirebaseAnalyticsObserver(analytics: _analytics);

  // ==================== AUTHENTICATION EVENTS ====================

  /// Log user login event with platform
  Future<void> logLogin(String method) async {
    try {
      await _analytics.logLogin(loginMethod: method);
      await _analytics.logEvent(
        name: 'user_login_platform',
        parameters: {
          'platform': method,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 [Analytics] Login tracked: $method');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to log login: $e');
    }
  }

  /// Log when user chooses to go anonymous
  Future<void> logAnonymousSelection() async {
    try {
      await _analytics.logEvent(
        name: 'user_select_anonymous',
        parameters: {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 [Analytics] Anonymous selection tracked');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to log anonymous selection: $e');
    }
  }

  // ==================== ANIME INTERACTION EVENTS ====================

  /// Log when user opens anime details
  Future<void> logAnimeDetailsView({
    required String animeId,
    required String animeTitle,
    String? genre,
    String? status,
    int? year,
    double? score,
    bool fromSearch = false,
  }) async {
    try {
      await _analytics.logViewItem(
        currency: 'USD',
        value: score ?? 0.0,
      );
      
      await _analytics.logEvent(
        name: 'anime_details_view',
        parameters: {
          'anime_id': animeId,
          'anime_title': animeTitle,
          'genre': genre ?? 'unknown',
          'status': status ?? 'unknown',
          'year': year ?? 0,
          'score': score ?? 0.0,
          'from_search': fromSearch,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 [Analytics] Anime details view tracked: $animeTitle');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to log anime details view: $e');
    }
  }

  /// Log when user follows an anime
  Future<void> logFollowAnime({
    required String animeId,
    required String animeTitle,
    String? genre,
    String? status,
    int? year,
    double? score,
    int? totalEpisodes,
    String? studio,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'anime_follow',
        parameters: {
          'anime_id': animeId,
          'anime_title': animeTitle,
          'genre': genre ?? 'unknown',
          'status': status ?? 'unknown',
          'year': year ?? 0,
          'score': score ?? 0.0,
          'total_episodes': totalEpisodes ?? 0,
          'studio': studio ?? 'unknown',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 [Analytics] Anime follow tracked: $animeTitle');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to log anime follow: $e');
    }
  }

  /// Log when user unfollows an anime
  Future<void> logUnfollowAnime({
    required String animeId,
    required String animeTitle,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'anime_unfollow',
        parameters: {
          'anime_id': animeId,
          'anime_title': animeTitle,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 [Analytics] Anime unfollow tracked: $animeTitle');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to log anime unfollow: $e');
    }
  }

  // ==================== SEARCH EVENTS ====================

  /// Log when user performs a search
  Future<void> logSearch({
    required String searchTerm,
    int? resultCount,
  }) async {
    try {
      await _analytics.logSearch(searchTerm: searchTerm);
      
      await _analytics.logEvent(
        name: 'anime_search',
        parameters: {
          'search_term': searchTerm,
          'search_length': searchTerm.length,
          'result_count': resultCount ?? 0,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 [Analytics] Search tracked: "$searchTerm" (${resultCount ?? 0} results)');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to log search: $e');
    }
  }

  /// Log when user clicks on a search result
  Future<void> logSearchResultClick({
    required String searchTerm,
    required String animeId,
    required String animeTitle,
    required int position,
    int? totalResults,
  }) async {
    try {
      await _analytics.logSelectContent(
        contentType: 'search_result',
        itemId: animeId,
      );
      
      await _analytics.logEvent(
        name: 'search_result_click',
        parameters: {
          'search_term': searchTerm,
          'anime_id': animeId,
          'anime_title': animeTitle,
          'result_position': position,
          'total_results': totalResults ?? 0,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 [Analytics] Search result click tracked: "$animeTitle" at position $position');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to log search result click: $e');
    }
  }

  // ==================== CALENDAR EVENTS ====================

  /// Log when user opens the calendar screen
  Future<void> logCalendarView() async {
    try {
      await _analytics.logScreenView(
        screenName: 'calendar',
        screenClass: 'CalendarScreen',
      );
      
      await _analytics.logEvent(
        name: 'calendar_view',
        parameters: {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 [Analytics] Calendar view tracked');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to log calendar view: $e');
    }
  }

  /// Log when user attempts to sync calendar
  Future<void> logCalendarSyncAttempt() async {
    try {
      await _analytics.logEvent(
        name: 'calendar_sync_attempt',
        parameters: {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 [Analytics] Calendar sync attempt tracked');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to log calendar sync attempt: $e');
    }
  }

  /// Log calendar sync success
  Future<void> logCalendarSyncSuccess({
    int? eventsAdded,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'calendar_sync_success',
        parameters: {
          'events_added': eventsAdded ?? 0,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 [Analytics] Calendar sync success tracked: ${eventsAdded ?? 0} events');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to log calendar sync success: $e');
    }
  }

  /// Log calendar sync failure
  Future<void> logCalendarSyncFailure({
    required String error,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'calendar_sync_failure',
        parameters: {
          'error': error,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 [Analytics] Calendar sync failure tracked: $error');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to log calendar sync failure: $e');
    }
  }

  // ==================== SCREEN TRACKING ====================

  /// Log screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      debugPrint('📊 [Analytics] Screen view tracked: $screenName');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to log screen view: $e');
    }
  }

  // ==================== USER PROPERTIES ====================

  /// Set user properties
  Future<void> setUserProperties({
    String? userId,
    String? userType,
    String? preferredLanguage,
  }) async {
    try {
      if (userId != null) {
        await _analytics.setUserId(id: userId);
      }
      
      if (userType != null) {
        await _analytics.setUserProperty(name: 'user_type', value: userType);
      }
      
      if (preferredLanguage != null) {
        await _analytics.setUserProperty(name: 'preferred_language', value: preferredLanguage);
      }
      
      debugPrint('📊 [Analytics] User properties set: $userId, $userType');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to set user properties: $e');
    }
  }

  // ==================== CUSTOM EVENTS ====================

  /// Log custom event
  Future<void> logCustomEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: eventName,
        parameters: {
          ...?parameters,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 [Analytics] Custom event tracked: $eventName');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to log custom event: $e');
    }
  }
} 