import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/purchase_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _showBanner = false;
  bool _showRemoveOffer = false;
  Timer? _hideTimer;
  Timer? _offerTimer;

  @override
  void initState() {
    super.initState();
    if (AdService.adsRemoved) return;
    _bannerAd = AdService.createBannerAd(
      onLoaded: () {
        if (mounted) {
          setState(() {
            _isLoaded = true;
          });
        }
      },
      onFailed: () {
        // Falha silenciosa, não mostra nada
      },
    );
    _bannerAd!.load();

    AdService.onInterstitialDismissed = () {
      if (mounted) {
        setState(() {
          _showBanner = true;
          _showRemoveOffer = true;
        });
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() => _showBanner = false);
          }
        });
        _offerTimer?.cancel();
        _offerTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() => _showRemoveOffer = false);
          }
        });
      }
    };
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _offerTimer?.cancel();
    _bannerAd?.dispose();
    AdService.onInterstitialDismissed = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AdService.adsRemoved) return const SizedBox.shrink();

    if (_showRemoveOffer) {
      return SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border(top: BorderSide(color: Colors.orange.shade300)),
          ),
          child: Row(
            children: [
              Icon(Icons.block, size: 18, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cansado de anúncios?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  PurchaseService.buyRemoveAds();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Remover Anúncios',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_showBanner || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
