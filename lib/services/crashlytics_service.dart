import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashlyticsService {
  static final CrashlyticsService _instance = CrashlyticsService._internal();
  factory CrashlyticsService() => _instance;
  CrashlyticsService._internal();

  static CrashlyticsService get instance => _instance;

  /// Log a custom message to Crashlytics
  void log(String message) {
    try {
      FirebaseCrashlytics.instance.log(message);
      debugPrint('📊 [Crashlytics] Logged: $message');
    } catch (e) {
      debugPrint('❌ [Crashlytics] Failed to log message: $e');
    }
  }

  /// Record a non-fatal error
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
      debugPrint('📊 [Crashlytics] Recorded error: $error');
    } catch (e) {
      debugPrint('❌ [Crashlytics] Failed to record error: $e');
    }
  }

  /// Set custom user information
  void setUserInfo({
    String? userId,
    String? email,
    String? name,
  }) {
    try {
      if (userId != null) {
        FirebaseCrashlytics.instance.setUserIdentifier(userId);
      }
      
      if (email != null || name != null) {
        FirebaseCrashlytics.instance.setCustomKey('user_email', email ?? 'unknown');
        FirebaseCrashlytics.instance.setCustomKey('user_name', name ?? 'unknown');
      }
      
      debugPrint('📊 [Crashlytics] Set user info for: $userId');
    } catch (e) {
      debugPrint('❌ [Crashlytics] Failed to set user info: $e');
    }
  }

  /// Set a custom key-value pair
  void setCustomKey(String key, dynamic value) {
    try {
      FirebaseCrashlytics.instance.setCustomKey(key, value);
      debugPrint('📊 [Crashlytics] Set custom key: $key = $value');
    } catch (e) {
      debugPrint('❌ [Crashlytics] Failed to set custom key: $e');
    }
  }

  /// Force a crash for testing purposes (only in debug mode)
  void testCrash() {
    if (kDebugMode) {
      debugPrint('📊 [Crashlytics] Testing crash (debug mode only)');
      FirebaseCrashlytics.instance.crash();
    } else {
      debugPrint('📊 [Crashlytics] Test crash ignored in release mode');
    }
  }

  /// Check if Crashlytics collection is enabled
  Future<bool> isCrashlyticsCollectionEnabled() async {
    try {
      return FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled;
    } catch (e) {
      debugPrint('❌ [Crashlytics] Failed to check collection status: $e');
      return false;
    }
  }

  /// Enable or disable Crashlytics collection
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
      debugPrint('📊 [Crashlytics] Collection ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      debugPrint('❌ [Crashlytics] Failed to set collection status: $e');
    }
  }
} 