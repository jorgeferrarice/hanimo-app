import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app_config_service.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  static AdMobService get instance => _instance;

  // Production Ad Unit IDs
  // Home Bottom Banner
  static const String _androidHomeBannerAdUnitId = 'ca-app-pub-2399788828426633/8268438419';
  static const String _iosHomeBannerAdUnitId = 'ca-app-pub-2399788828426633/1968406335';
  
  // Anime Details Bottom Banner
  static const String _androidAnimeDetailsBannerAdUnitId = 'ca-app-pub-2399788828426633/7131187383';
  static const String _iosAnimeDetailsBannerAdUnitId = 'ca-app-pub-2399788828426633/1667107712';
  
  // Test Ad Unit IDs (for development)
  static const String _testAndroidBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testIosBannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716';

  // Initialize AdMob (only if enabled via Remote Config)
  static Future<void> initialize() async {
    final isEnabled = await isAdMobEnabled();
    if (isEnabled) {
      debugPrint('📱 [AdMob] Initializing AdMob (enabled via Remote Config)');
      await MobileAds.instance.initialize();
      debugPrint('✅ [AdMob] AdMob initialized successfully');
    } else {
      debugPrint('⚠️  [AdMob] AdMob disabled via Remote Config, skipping initialization');
    }
  }

  // Check if AdMob is enabled via Remote Config
  static Future<bool> isAdMobEnabled() async {
    try {
      return await AppConfigService.instance.isAdMobEnabled();
    } catch (e) {
      debugPrint('❌ [AdMob] Error checking AdMob enabled status: $e');
      // Default to enabled if we can't check Remote Config
      return true;
    }
  }

  // Get Home Banner Ad Unit ID
  static String get homeBannerAdUnitId {
    if (kDebugMode) {
      // Use test ads in debug mode
      if (Platform.isAndroid) {
        return _testAndroidBannerAdUnitId;
      } else if (Platform.isIOS) {
        return _testIosBannerAdUnitId;
      }
    } else {
      // Use production ads in release mode
      if (Platform.isAndroid) {
        return _androidHomeBannerAdUnitId;
      } else if (Platform.isIOS) {
        return _iosHomeBannerAdUnitId;
      }
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Get Anime Details Banner Ad Unit ID
  static String get animeDetailsBannerAdUnitId {
    if (kDebugMode) {
      // Use test ads in debug mode
      if (Platform.isAndroid) {
        return _testAndroidBannerAdUnitId;
      } else if (Platform.isIOS) {
        return _testIosBannerAdUnitId;
      }
    } else {
      // Use production ads in release mode
      if (Platform.isAndroid) {
        return _androidAnimeDetailsBannerAdUnitId;
      } else if (Platform.isIOS) {
        return _iosAnimeDetailsBannerAdUnitId;
      }
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Get Banner Ad Unit ID (generic - defaults to home banner)
  static String get bannerAdUnitId => homeBannerAdUnitId;

  // Create Home Banner Ad
  static BannerAd createHomeBannerAd({
    required AdSize adSize,
    required BannerAdListener listener,
  }) {
    return BannerAd(
      adUnitId: homeBannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: listener,
    );
  }

  // Create Anime Details Banner Ad
  static BannerAd createAnimeDetailsBannerAd({
    required AdSize adSize,
    required BannerAdListener listener,
  }) {
    return BannerAd(
      adUnitId: animeDetailsBannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: listener,
    );
  }

  // Create Banner Ad (generic - defaults to home banner)
  static BannerAd createBannerAd({
    required AdSize adSize,
    required BannerAdListener listener,
  }) {
    return createHomeBannerAd(
      adSize: adSize,
      listener: listener,
    );
  }
} 