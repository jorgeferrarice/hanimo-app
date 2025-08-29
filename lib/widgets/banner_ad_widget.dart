import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';
import '../services/app_config_service.dart';

enum BannerAdType {
  home,
  animeDetails,
}

class BannerAdWidget extends StatefulWidget {
  final AdSize adSize;
  final EdgeInsets? margin;
  final BannerAdType adType;
  
  const BannerAdWidget({
    super.key,
    this.adSize = AdSize.banner,
    this.margin,
    this.adType = BannerAdType.home,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;
  bool _isAdMobEnabled = false;
  bool _isCheckingEnabled = true;

  @override
  void initState() {
    super.initState();
    _checkAdMobEnabledAndLoad();
  }

  Future<void> _checkAdMobEnabledAndLoad() async {
    try {
      final isEnabled = await AppConfigService.instance.isAdMobEnabled();
      setState(() {
        _isAdMobEnabled = isEnabled;
        _isCheckingEnabled = false;
      });
      
      if (isEnabled) {
        _loadBannerAd();
      } else {
        debugPrint('📱 [BannerAd] AdMob disabled via Remote Config, not loading ad (${widget.adType.name})');
      }
    } catch (e) {
      debugPrint('❌ [BannerAd] Error checking AdMob enabled status: $e, defaulting to disabled');
      setState(() {
        _isAdMobEnabled = false;
        _isCheckingEnabled = false;
      });
    }
  }

  void _loadBannerAd() {
    final listener = BannerAdListener(
      onAdLoaded: (ad) {
        setState(() {
          _isAdLoaded = true;
          _isAdFailed = false;
        });
        debugPrint('✅ Banner ad loaded successfully (${widget.adType.name})');
      },
      onAdFailedToLoad: (ad, error) {
        setState(() {
          _isAdLoaded = false;
          _isAdFailed = true;
        });
        debugPrint('❌ Banner ad failed to load (${widget.adType.name}): $error');
        ad.dispose();
      },
      onAdOpened: (ad) {
        debugPrint('📱 Banner ad opened (${widget.adType.name})');
      },
      onAdClosed: (ad) {
        debugPrint('📱 Banner ad closed (${widget.adType.name})');
      },
    );

    switch (widget.adType) {
      case BannerAdType.home:
        _bannerAd = AdMobService.createHomeBannerAd(
          adSize: widget.adSize,
          listener: listener,
        );
        break;
      case BannerAdType.animeDetails:
        _bannerAd = AdMobService.createAnimeDetailsBannerAd(
          adSize: widget.adSize,
          listener: listener,
        );
        break;
    }

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if we're still checking if AdMob is enabled
    if (_isCheckingEnabled) {
      return const SizedBox.shrink();
    }

    // Don't show anything if AdMob is disabled
    if (!_isAdMobEnabled) {
      return const SizedBox.shrink();
    }

    if (_isAdFailed) {
      return const SizedBox.shrink(); // Don't show anything if ad failed
    }

    if (!_isAdLoaded || _bannerAd == null) {
      return Container(
        margin: widget.margin,
        height: widget.adSize.height.toDouble(),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      margin: widget.margin,
      alignment: Alignment.center,
      width: widget.adSize.width.toDouble(),
      height: widget.adSize.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
} 