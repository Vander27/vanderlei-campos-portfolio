import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static bool _initialized = false;
  static bool _adsRemoved = false;
  static InterstitialAd? _interstitialAd;
  static int _actionCount = 0;
  static DateTime? _lastInterstitialTime;

  // IDs de teste (debug) vs produção (release)
  static String get _bannerAdUnitId => kDebugMode
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-5310808113651390/2320420508';
  static String get _interstitialAdUnitId => kDebugMode
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-5310808113651390/1007338835';

  static const String _adsRemovedKey = 'macefo_ads_removed';

  static bool get adsRemoved => _adsRemoved;

  static Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();

    MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.t,
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    _adsRemoved = prefs.getBool(_adsRemovedKey) ?? false;
    _initialized = true;
    if (!_adsRemoved) {
      _loadInterstitialAd();
    }
  }

  static Future<void> markAdsRemoved() async {
    _adsRemoved = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adsRemovedKey, true);
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  static BannerAd createBannerAd({required Function() onLoaded, Function()? onFailed}) {
    return BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => onLoaded(),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onFailed?.call();
        },
      ),
    );
  }

  static Function()? onInterstitialDismissed;

  static void _loadInterstitialAd() {
    if (_adsRemoved) return;
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              onInterstitialDismissed?.call();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          Future.delayed(const Duration(seconds: 60), () {
            _loadInterstitialAd();
          });
        },
      ),
    );
  }

  /// Chame ao navegar entre telas. Mostra intersticial a cada 6 ações
  /// com intervalo mínimo de 6 minutos entre exibições.
  static void onAction() {
    if (_adsRemoved) return;
    _actionCount++;
    if (_actionCount >= 6) {
      final agora = DateTime.now();
      if (_lastInterstitialTime != null &&
          agora.difference(_lastInterstitialTime!).inMinutes < 6) {
        return;
      }
      _actionCount = 0;
      _lastInterstitialTime = agora;
      showInterstitial();
    }
  }

  static void showInterstitial() {
    if (_adsRemoved) return;
    if (_interstitialAd != null) {
      _interstitialAd!.show();
    }
  }
}
