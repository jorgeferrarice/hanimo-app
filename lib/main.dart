import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/maintenance_screen.dart';
import 'services/auth_service.dart';
import 'services/cache_service.dart';
import 'services/app_config_service.dart';
import 'services/onesignal_service.dart';
import 'services/admob_service.dart';
import 'services/analytics_service.dart';
import 'services/theme_service.dart';
import 'services/release_schedule_service.dart';
import 'widgets/connectivity_wrapper.dart';
import 'redux/store.dart';
import 'redux/app_state.dart';
import 'redux/actions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize timezone database for device_calendar
  tz.initializeTimeZones();
  
  debugPrint('🚀 Starting HaniMo App...');
  debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  
  // Initialize theme service
  final themeService = ThemeService();
  try {
    await themeService.initialize();
    debugPrint('✅ [INIT] Theme service initialized successfully');
  } catch (e) {
    debugPrint('⚠️ [INIT] Theme service initialization failed: $e');
    debugPrint('   Continuing with default theme settings');
  }
  
  try {
    // Step 1: Initialize Firebase (required for Remote Config)
    debugPrint('🔥 [INIT] Step 1: Initializing Firebase...');
    final firebaseStartTime = DateTime.now();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final firebaseDuration = DateTime.now().difference(firebaseStartTime);
    debugPrint('✅ [INIT] Firebase initialized successfully (${firebaseDuration.inMilliseconds}ms)');
    
    // Initialize Crashlytics
    debugPrint('📊 [INIT] Step 1.1: Initializing Firebase Crashlytics...');
    final crashlyticsStartTime = DateTime.now();
    
    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    
    final crashlyticsDuration = DateTime.now().difference(crashlyticsStartTime);
    debugPrint('✅ [INIT] Firebase Crashlytics initialized successfully (${crashlyticsDuration.inMilliseconds}ms)');
    
    // Step 2: Initialize Remote Config and wait for initial fetch
    debugPrint('🔧 [INIT] Step 2: Initializing Remote Config...');
    debugPrint('   • This step fetches configuration from Firebase');
    debugPrint('   • All other services depend on this configuration');
    final remoteConfigStartTime = DateTime.now();
    await AppConfigService.instance.initializeRemoteConfig();
    final remoteConfigDuration = DateTime.now().difference(remoteConfigStartTime);
    debugPrint('✅ [INIT] Remote Config initialized successfully (${remoteConfigDuration.inMilliseconds}ms)');
    
    // Step 3: Initialize App Configuration (uses Remote Config values)
    debugPrint('⚙️  [INIT] Step 3: Initializing App Configuration...');
    final appConfigStartTime = DateTime.now();
    await AppConfigService.instance.initialize();
    final appConfigDuration = DateTime.now().difference(appConfigStartTime);
    debugPrint('✅ [INIT] App Configuration initialized successfully (${appConfigDuration.inMilliseconds}ms)');
    
    // Step 4: Initialize Cache Service (uses Remote Config for provider selection)
    debugPrint('💾 [INIT] Step 4: Initializing Cache Service...');
    debugPrint('   • Cache provider will be selected based on Remote Config');
    final cacheStartTime = DateTime.now();
    await CacheService.instance.initialize();
    final cacheDuration = DateTime.now().difference(cacheStartTime);
    debugPrint('✅ [INIT] Cache Service initialized successfully (${cacheDuration.inMilliseconds}ms)');
    
    // Step 5: Initialize OneSignal Service
    debugPrint('🔔 [INIT] Step 5: Initializing OneSignal Service...');
    final oneSignalStartTime = DateTime.now();
    await OneSignalService.instance.initialize();
    final oneSignalDuration = DateTime.now().difference(oneSignalStartTime);
    debugPrint('✅ [INIT] OneSignal Service initialized successfully (${oneSignalDuration.inMilliseconds}ms)');
    
    // Step 6: Initialize AdMob Service
    debugPrint('📱 [INIT] Step 6: Initializing AdMob Service...');
    final adMobStartTime = DateTime.now();
    await AdMobService.initialize();
    final adMobDuration = DateTime.now().difference(adMobStartTime);
    debugPrint('✅ [INIT] AdMob Service initialized successfully (${adMobDuration.inMilliseconds}ms)');
    
    // Step 7: Initialize Release Schedule Service (preload next week's schedules)
    debugPrint('📅 [INIT] Step 7: Initializing Release Schedule Service...');
    final releaseScheduleStartTime = DateTime.now();
    await ReleaseScheduleService.instance.initialize();
    final releaseScheduleDuration = DateTime.now().difference(releaseScheduleStartTime);
    debugPrint('✅ [INIT] Release Schedule Service initialized successfully (${releaseScheduleDuration.inMilliseconds}ms)');
    
    // Print release schedule cache status after a brief delay (to allow background preloading)
    Future.delayed(const Duration(seconds: 2), () async {
      await ReleaseScheduleService.instance.printCacheStatus();
    });
    
    // Print comprehensive startup summary
    debugPrint('📊 [INIT] Printing startup summary...');
    await AppConfigService.instance.printStartupSummary();
    
    final totalDuration = DateTime.now().difference(firebaseStartTime);
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🎉 [INIT] All services initialized successfully!');
    debugPrint('   • Total initialization time: ${totalDuration.inMilliseconds}ms');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
  } catch (e, stackTrace) {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('❌ [INIT] Error during app initialization: $e');
    debugPrint('   • Stack trace: $stackTrace');
    debugPrint('🔄 [INIT] Continuing with default configuration...');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    // Continue with app initialization even if some services fail
  }
  
  // Create Redux store
  final store = createStore();
  
  runApp(MyApp(store: store, themeService: themeService));
}

class MyApp extends StatelessWidget {
  final Store<AppState> store;
  final ThemeService themeService;
  
  const MyApp({super.key, required this.store, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return StoreProvider<AppState>(
      store: store,
      child: ChangeNotifierProvider<ThemeService>(
        create: (_) => themeService,
        child: Consumer<ThemeService>(
          builder: (context, themeService, child) {
            return MaterialApp(
              title: 'HaniMo - Anime Tracker',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeService.themeMode,
              debugShowCheckedModeBanner: false,
              navigatorObservers: [
                AnalyticsService.instance.observer,
              ],
              home: const ConnectivityWrapper(
                child: AuthWrapper(),
              ),
              routes: {
                '/login': (context) => const LoginScreen(),
                '/home': (context) => const HomeScreen(),
              },
            );
          },
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  // Register existing authenticated user with OneSignal and load followed anime data
  void _handleUserAuthenticated(BuildContext context, User user) {
    // Run in background to avoid blocking UI
    Future.microtask(() async {
      try {
        debugPrint('🔐 [AuthWrapper] Handling user authentication for: ${user.uid}');
        debugPrint('   • User type: ${user.isAnonymous ? 'Anonymous' : 'Authenticated'}');
        
        // Handle user authentication and potential migration in Redux store
        // This includes OneSignal registration within the Redux action
        final store = StoreProvider.of<AppState>(context);
        await store.dispatch(handleUserAuthenticationAction(user.uid));
        
        debugPrint('✅ [AuthWrapper] User authenticated and services initialized for: ${user.uid}');
      } catch (e) {
        debugPrint('❌ [AuthWrapper] Error during user authentication setup: $e');
        
        // If Redux authentication fails, still try to register with OneSignal as fallback
        try {
          debugPrint('🔔 [AuthWrapper] Attempting fallback OneSignal registration...');
          await OneSignalService.instance.registerUser(user);
          debugPrint('✅ [AuthWrapper] Fallback OneSignal registration completed');
        } catch (oneSignalError) {
          debugPrint('❌ [AuthWrapper] Fallback OneSignal registration also failed: $oneSignalError');
        }
      }
    });
  }
  
  // Handle user logout
  void _handleUserLoggedOut(BuildContext context) {
    // Clear all user data from Redux store
    Future.microtask(() async {
      try {
        final store = StoreProvider.of<AppState>(context);
        await store.dispatch(handleUserSignOutAction());
        debugPrint('✅ [AuthWrapper] User logged out and state cleared');
      } catch (e) {
        debugPrint('❌ [AuthWrapper] Error during user logout cleanup: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check for maintenance mode first
    return FutureBuilder<bool>(
      future: AppConfigService.instance.isMaintenanceModeEnabled(),
      builder: (context, maintenanceSnapshot) {
        // Show loading while checking maintenance mode
        if (maintenanceSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Show maintenance screen if maintenance mode is enabled
        if (maintenanceSnapshot.data == true) {
          return const MaintenanceScreen();
        }
        
        // Not in maintenance mode, proceed with normal auth flow
        final authService = AuthService();
        
        return StreamBuilder(
          stream: authService.authStateChanges,
          builder: (context, authSnapshot) {
            // Show loading spinner while checking authentication state
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            
            // User is signed in
            if (authSnapshot.hasData && authSnapshot.data != null) {
              // Handle user authentication setup
              _handleUserAuthenticated(context, authSnapshot.data!);
              return const HomeScreen();
            }
            
            // User is not signed in
            _handleUserLoggedOut(context);
            return const LoginScreen();
          },
        );
      },
    );
  }
}
