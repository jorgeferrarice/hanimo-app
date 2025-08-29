import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'onesignal_service.dart';
import 'crashlytics_service.dart';
import 'analytics_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return null; // User canceled the sign-in
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google [UserCredential]
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Register user with OneSignal, Crashlytics, and Analytics
      if (userCredential.user != null) {
        await OneSignalService.instance.registerUser(userCredential.user!);
        CrashlyticsService.instance.setUserInfo(
          userId: userCredential.user!.uid,
          email: userCredential.user!.email,
          name: userCredential.user!.displayName,
        );
        CrashlyticsService.instance.setCustomKey('auth_provider', 'google');
        
        // Log analytics login event
        await AnalyticsService.instance.logLogin('google');
        await AnalyticsService.instance.setUserProperties(
          userId: userCredential.user!.uid,
          userType: 'authenticated',
        );
      }
      
      return userCredential;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      CrashlyticsService.instance.recordError(e, StackTrace.current, reason: 'Google Sign-In failed');
      rethrow;
    }
  }

  // Sign in with Apple (iOS only)
  Future<UserCredential?> signInWithApple() async {
    try {
      // Check if Apple Sign In is available
      if (!Platform.isIOS) {
        throw UnsupportedError('Apple Sign In is only available on iOS');
      }

      // Request credential for the currently signed in Apple account
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create an `OAuthCredential` from the credential returned by Apple
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in the user with Firebase
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      
      // Register user with OneSignal, Crashlytics, and Analytics
      if (userCredential.user != null) {
        await OneSignalService.instance.registerUser(userCredential.user!);
        CrashlyticsService.instance.setUserInfo(
          userId: userCredential.user!.uid,
          email: userCredential.user!.email,
          name: userCredential.user!.displayName,
        );
        CrashlyticsService.instance.setCustomKey('auth_provider', 'apple');
        
        // Log analytics login event
        await AnalyticsService.instance.logLogin('apple');
        await AnalyticsService.instance.setUserProperties(
          userId: userCredential.user!.uid,
          userType: 'authenticated',
        );
      }
      
      return userCredential;
    } catch (e) {
      debugPrint('Error signing in with Apple: $e');
      CrashlyticsService.instance.recordError(e, StackTrace.current, reason: 'Apple Sign-In failed');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Unregister from OneSignal first
      await OneSignalService.instance.unregisterUser();
      
      // Clear user information from Crashlytics
      CrashlyticsService.instance.setUserInfo(userId: 'signed_out');
      CrashlyticsService.instance.setCustomKey('auth_provider', 'none');
      
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      debugPrint('Error signing out: $e');
      CrashlyticsService.instance.recordError(e, StackTrace.current, reason: 'Sign-out failed');
      rethrow;
    }
  }

  // Sign in anonymously
  Future<UserCredential?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      
      // Register user with OneSignal, Crashlytics, and Analytics
      if (userCredential.user != null) {
        await OneSignalService.instance.registerUser(userCredential.user!);
        CrashlyticsService.instance.setUserInfo(
          userId: userCredential.user!.uid,
          email: 'anonymous',
          name: 'Anonymous User',
        );
        CrashlyticsService.instance.setCustomKey('auth_provider', 'anonymous');
        
        // Log analytics anonymous selection event
        await AnalyticsService.instance.logAnonymousSelection();
        await AnalyticsService.instance.setUserProperties(
          userId: userCredential.user!.uid,
          userType: 'anonymous',
        );
      }
      
      return userCredential;
    } catch (e) {
      debugPrint('Error signing in anonymously: $e');
      CrashlyticsService.instance.recordError(e, StackTrace.current, reason: 'Anonymous Sign-In failed');
      rethrow;
    }
  }

  // Check if Apple Sign In is available
  static Future<bool> isAppleSignInAvailable() async {
    return Platform.isIOS && await SignInWithApple.isAvailable();
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // Unregister from OneSignal first
      await OneSignalService.instance.unregisterUser();
      
      // Clear user information from Crashlytics
      CrashlyticsService.instance.setUserInfo(userId: 'deleted');
      CrashlyticsService.instance.setCustomKey('auth_provider', 'deleted');
      
      // Log analytics account deletion event
      await AnalyticsService.instance.logCustomEvent(
        eventName: 'account_deleted',
        parameters: {
          'user_id': user.uid,
          'auth_provider': user.providerData.isNotEmpty ? user.providerData.first.providerId : 'unknown',
        },
      );
      
      // Soft delete: Sign out instead of deleting the account
      await signOut();
      
      debugPrint('✅ [AuthService] Account soft deleted successfully');
    } catch (e) {
      debugPrint('❌ [AuthService] Error soft deleting account: $e');
      CrashlyticsService.instance.recordError(e, StackTrace.current, reason: 'Account soft deletion failed');
      rethrow;
    }
  }
} 