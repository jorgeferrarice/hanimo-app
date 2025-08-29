import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OneSignalService {
  static const String _appId = 'dd96efea-6c12-40c3-ad8d-9ab8b16bdda2';
  
  // Singleton pattern
  static final OneSignalService _instance = OneSignalService._internal();
  factory OneSignalService() => _instance;
  OneSignalService._internal();
  
  static OneSignalService get instance => _instance;
  
  bool _isInitialized = false;
  
  /// Initialize OneSignal with the provided App ID
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🔔 Initializing OneSignal...');
      
      // Remove this method to stop OneSignal Debugging
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      
      // OneSignal Initialization
      OneSignal.initialize(_appId);
      
      // The promptForPushNotificationsWithUserResponse function will show the iOS or Android push notification prompt.
      // We recommend removing the following code and instead using an In-App Message to prompt for notification permission
      OneSignal.Notifications.requestPermission(true);
      
      // Set up listeners
      _setupListeners();
      
      _isInitialized = true;
      debugPrint('✅ OneSignal initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing OneSignal: $e');
      rethrow;
    }
  }
  
  /// Setup OneSignal event listeners
  void _setupListeners() {
    // User state change listener
    OneSignal.User.addObserver((state) {
      debugPrint('🔔 OneSignal user state changed');
    });
    
    // Push subscription state change listener
    OneSignal.User.pushSubscription.addObserver((state) {
      debugPrint('🔔 OneSignal push subscription changed');
    });
    
    // Notification opened listener
    OneSignal.Notifications.addClickListener((event) {
      debugPrint('🔔 Notification clicked: ${event.notification.notificationId}');
    });
    
    // Notification received listener (while app is in focus)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      debugPrint('🔔 Notification received: ${event.notification.notificationId}');
      // Optionally prevent the notification from displaying
      // event.preventDefault();
    });
  }
  
  /// Register the current authenticated user with OneSignal and save their ID to Firestore
  Future<void> registerUser(User firebaseUser) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      debugPrint('🔔 Registering user with OneSignal: ${firebaseUser.uid}');
      
      // Set external user ID for OneSignal (Firebase UID)
      OneSignal.login(firebaseUser.uid);
      
      // Ensure user is subscribed to notifications (resubscribe if needed)
      await _ensureUserIsSubscribed();
      
      // Wait a bit for OneSignal to process the login
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Get OneSignal user ID
      final oneSignalUserId = await OneSignal.User.getOnesignalId();
      
      if (oneSignalUserId != null && oneSignalUserId.isNotEmpty) {
        // Save OneSignal user ID to Firestore
        await _saveOneSignalUserIdToFirestore(firebaseUser.uid, oneSignalUserId);
        debugPrint('✅ User registered with OneSignal successfully. OneSignal ID: $oneSignalUserId');
      } else {
        debugPrint('⚠️  OneSignal user ID not available yet, will retry later');
        // We can set up a retry mechanism or handle this in the observer
        _retryRegisterUser(firebaseUser);
      }
      
      // Set user properties (optional)
      OneSignal.User.addEmail(firebaseUser.email ?? '');
      if (firebaseUser.displayName != null) {
        OneSignal.User.addTagWithKey('display_name', firebaseUser.displayName!);
      }
      OneSignal.User.addTagWithKey('firebase_uid', firebaseUser.uid);
      OneSignal.User.addTagWithKey('provider', _getProviderName(firebaseUser));
      OneSignal.User.addTagWithKey('user_type', firebaseUser.isAnonymous ? 'anonymous' : 'authenticated');
      OneSignal.User.addTagWithKey('last_login', DateTime.now().toIso8601String());
      
    } catch (e) {
      debugPrint('❌ Error registering user with OneSignal: $e');
      rethrow;
    }
  }
  
  /// Ensure user is subscribed to notifications (resubscribe if needed)
  Future<void> _ensureUserIsSubscribed() async {
    try {
      debugPrint('🔔 Ensuring user is subscribed to OneSignal notifications...');
      
      // Check current subscription status
      final currentlySubscribed = isSubscribed;
      debugPrint('🔔 Current subscription status: $currentlySubscribed');
      
      if (!currentlySubscribed) {
        debugPrint('🔔 User not subscribed, attempting to resubscribe...');
        
        // Request permission and opt in
        final hasPermission = await OneSignal.Notifications.requestPermission(true);
        if (hasPermission) {
          OneSignal.User.pushSubscription.optIn();
          
          // Wait for subscription to be processed
          await Future.delayed(const Duration(milliseconds: 1000));
          
          final newStatus = isSubscribed;
          debugPrint('🔔 Resubscription completed. New status: $newStatus');
        } else {
          debugPrint('⚠️  Notification permission denied, cannot resubscribe');
        }
      } else {
        debugPrint('✅ User already subscribed to OneSignal notifications');
      }
    } catch (e) {
      debugPrint('❌ Error ensuring user subscription: $e');
      // Don't rethrow here, continue with registration
    }
  }
  
  /// Force resubscribe user to OneSignal (useful for migration or account linking)
  Future<void> resubscribeUser(User firebaseUser) async {
    try {
      debugPrint('🔔 Force resubscribing user to OneSignal: ${firebaseUser.uid}');
      
      // First unregister if there's an existing session
      try {
        OneSignal.logout();
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('⚠️  Error during logout (expected for new users): $e');
      }
      
      // Now register the user fresh
      await registerUser(firebaseUser);
      
      debugPrint('✅ User force resubscribed to OneSignal successfully');
    } catch (e) {
      debugPrint('❌ Error force resubscribing user to OneSignal: $e');
      rethrow;
    }
  }
  
  /// Retry registering user if OneSignal ID wasn't available initially
  void _retryRegisterUser(User firebaseUser) {
    // Set up a one-time observer to catch when the OneSignal ID becomes available
    OneSignal.User.addObserver((state) async {
      final oneSignalUserId = await OneSignal.User.getOnesignalId();
      if (oneSignalUserId != null && oneSignalUserId.isNotEmpty) {
        await _saveOneSignalUserIdToFirestore(firebaseUser.uid, oneSignalUserId);
        debugPrint('✅ OneSignal ID obtained on retry: $oneSignalUserId');
      }
    });
  }
  
  /// Save OneSignal user ID to Firestore under users/{firebase_uid}
  Future<void> _saveOneSignalUserIdToFirestore(String firebaseUid, String oneSignalUserId) async {
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(firebaseUid);
      
      await userDoc.set({
        'oneSignalId': oneSignalUserId,
        'oneSignalLastUpdated': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('✅ OneSignal ID saved to Firestore: $oneSignalUserId');
    } catch (e) {
      debugPrint('❌ Error saving OneSignal ID to Firestore: $e');
      rethrow;
    }
  }
  
  /// Get the provider name from Firebase user
  String _getProviderName(User user) {
    if (user.isAnonymous) {
      return 'anonymous';
    }
    
    for (final userInfo in user.providerData) {
      switch (userInfo.providerId) {
        case 'google.com':
          return 'google';
        case 'apple.com':
          return 'apple';
        case 'password':
          return 'email';
        default:
          return userInfo.providerId;
      }
    }
    
    return 'unknown';
  }
  
  /// Unregister user when they sign out
  Future<void> unregisterUser() async {
    try {
      debugPrint('🔔 Unregistering user from OneSignal');
      OneSignal.logout();
      debugPrint('✅ User unregistered from OneSignal');
    } catch (e) {
      debugPrint('❌ Error unregistering user from OneSignal: $e');
    }
  }
  
  /// Get current OneSignal user ID
  Future<String?> get oneSignalUserId => OneSignal.User.getOnesignalId();
  
  /// Get current push subscription ID
  String? get pushSubscriptionId => OneSignal.User.pushSubscription.id;
  
  /// Check if notifications are permission is granted
  Future<bool> get hasNotificationPermission async {
    try {
      if (!_isInitialized) {
        return false;
      }
      
      // This will return the current permission status without requesting
      final permission = await OneSignal.Notifications.permission;
      debugPrint('🔔 Notification permission status: $permission');
      return permission;
    } catch (e) {
      debugPrint('❌ Error checking notification permission: $e');
      return false;
    }
  }
  
  /// Force refresh OneSignal subscription status
  Future<bool> refreshSubscriptionStatus() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      // Wait a moment for any pending operations
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Get fresh status
      final optedIn = OneSignal.User.pushSubscription.optedIn;
      final hasId = OneSignal.User.pushSubscription.id != null;
      final hasToken = OneSignal.User.pushSubscription.token != null;
      final permission = await OneSignal.Notifications.permission;
      
      debugPrint('🔔 Refreshed status - OptedIn: $optedIn, HasId: $hasId, HasToken: $hasToken, Permission: $permission');
      
      return isSubscribed;
    } catch (e) {
      debugPrint('❌ Error refreshing subscription status: $e');
      return false;
    }
  }
  
  /// Check if user is subscribed to push notifications
  bool get isSubscribed {
    try {
      if (!_isInitialized) {
        debugPrint('🔔 OneSignal not initialized yet, returning false');
        return false;
      }
      
      final optedIn = OneSignal.User.pushSubscription.optedIn;
      final hasId = OneSignal.User.pushSubscription.id != null;
      final hasToken = OneSignal.User.pushSubscription.token != null;
      
      debugPrint('🔔 OneSignal subscription status - OptedIn: $optedIn, HasId: $hasId, HasToken: $hasToken');
      
      // Primary check: user is explicitly opted in
      if (optedIn == true) {
        return true;
      }
      
      // Secondary check: even if optedIn is false/null, if we have valid subscription data,
      // it means notifications are working (this handles OneSignal SDK quirks)
      if ((hasId || hasToken)) {
        debugPrint('🔔 OptedIn is $optedIn but has valid subscription data, returning true');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Error checking OneSignal subscription status: $e');
      return false;
    }
  }
  
    /// Enable push notifications
  Future<void> enableNotifications() async {
    try {
      debugPrint('🔔 Enabling OneSignal notifications...');
      
      // Ensure OneSignal is initialized
      if (!_isInitialized) {
        await initialize();
      }
      
      // Request permission first (this is crucial for iOS)
      final hasPermission = await OneSignal.Notifications.requestPermission(true);
      debugPrint('🔔 Permission request result: $hasPermission');
      
      if (!hasPermission) {
        throw Exception('Notification permission was denied');
      }
      
      // Check current status before opting in
      final statusBefore = OneSignal.User.pushSubscription.optedIn;
      debugPrint('🔔 Status before optIn: $statusBefore');
      
      // Opt in to push notifications
      OneSignal.User.pushSubscription.optIn();
      debugPrint('🔔 Called optIn()');
      
      // Wait longer for the status to update and check multiple times
      int attempts = 0;
      bool isSubscribed = false;
      while (attempts < 10 && !isSubscribed) {
        await Future.delayed(const Duration(milliseconds: 500));
        isSubscribed = OneSignal.User.pushSubscription.optedIn ?? false;
        final hasId = OneSignal.User.pushSubscription.id != null;
        final hasToken = OneSignal.User.pushSubscription.token != null;
        
        debugPrint('🔔 Attempt ${attempts + 1}: OptedIn: $isSubscribed, HasId: $hasId, HasToken: $hasToken');
        
        // Consider it successful if we have either opted in status or valid subscription data
        if (isSubscribed || (hasId && hasToken)) {
          isSubscribed = true;
          break;
        }
        
        attempts++;
      }
      
      if (!isSubscribed) {
        // Try alternative approach - check if we have a valid subscription even if optedIn is false
        final hasId = OneSignal.User.pushSubscription.id != null;
        final hasToken = OneSignal.User.pushSubscription.token != null;
        
        if (hasId || hasToken) {
          debugPrint('🔔 OptIn status is false but we have subscription data, considering it enabled');
          isSubscribed = true;
        } else {
          throw Exception('Failed to enable notifications after multiple attempts');
        }
      }
      
      debugPrint('✅ OneSignal notifications enabled. Final status: $isSubscribed');
    } catch (e) {
      debugPrint('❌ Error enabling OneSignal notifications: $e');
      rethrow;
    }
  }

  /// Disable push notifications
  Future<void> disableNotifications() async {
    try {
      debugPrint('🔔 Disabling OneSignal notifications...');
      
      // Opt out of push notifications
      OneSignal.User.pushSubscription.optOut();
      
      // Wait a moment for the status to update
      await Future.delayed(const Duration(milliseconds: 500));
      
      final isSubscribed = OneSignal.User.pushSubscription.optedIn ?? false;
      debugPrint('✅ OneSignal notifications disabled. Subscribed: $isSubscribed');
    } catch (e) {
      debugPrint('❌ Error disabling OneSignal notifications: $e');
      rethrow;
    }
  }
} 