import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'ad_service.dart';

class PurchaseService {
  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static bool _available = false;

  // ID do produto no Google Play Console
  // Criar como "produto gerenciado" (in-app product) com este ID
  static const String removeAdsProductId = 'remove_ads';

  static ProductDetails? _removeAdsProduct;
  static ProductDetails? get removeAdsProduct => _removeAdsProduct;

  static Future<void> initialize() async {
    _available = await _iap.isAvailable();
    if (!_available) return;

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (error) {},
    );

    await _loadProducts();
  }

  static Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails({removeAdsProductId});
    if (response.productDetails.isNotEmpty) {
      _removeAdsProduct = response.productDetails.first;
    }
  }

  static Future<bool> buyRemoveAds() async {
    if (!_available || _removeAdsProduct == null) return false;

    final purchaseParam = PurchaseParam(
      productDetails: _removeAdsProduct!,
    );

    return _iap.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: true,
    );
  }

  static void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID == removeAdsProductId) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          AdService.markAdsRemoved();
          _onPurchaseSuccess?.call();
        }
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
      }
    }
  }

  // Callback para notificar a UI
  static Function()? _onPurchaseSuccess;
  static set onPurchaseSuccess(Function()? callback) {
    _onPurchaseSuccess = callback;
  }

  static void dispose() {
    _subscription?.cancel();
  }
}
