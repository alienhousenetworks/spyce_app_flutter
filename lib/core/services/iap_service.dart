import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../data/repositories/api_repositories.dart';
import '../network/api_client.dart';

final iapServiceProvider = Provider<IAPService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return IAPService(apiClient);
});

enum IAPProductType {
  subscription,
  callPass,
}

class IAPProductItem {
  final String id;
  final String title;
  final String description;
  final String priceString;
  final double rawPrice;
  final String currencyCode;
  final IAPProductType type;
  final ProductDetails rawDetails;

  IAPProductItem({
    required this.id,
    required this.title,
    required this.description,
    required this.priceString,
    required this.rawPrice,
    required this.currencyCode,
    required this.type,
    required this.rawDetails,
  });
}

class IAPService {
  IAPService(this._apiClient) {
    _initIAPListener();
  }

  final ApiClient _apiClient;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final _purchaseStatusController = StreamController<PurchaseDetails>.broadcast();
  Stream<PurchaseDetails> get purchaseStatusStream => _purchaseStatusController.stream;

  List<ProductDetails> _availableProducts = [];
  List<ProductDetails> get availableProducts => _availableProducts;

  void _initIAPListener() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        _handlePurchaseUpdates(purchaseDetailsList);
      },
      onDone: () => _subscription?.cancel(),
      onError: (dynamic error) {
        debugPrint('[IAP] Stream error: $error');
      },
    );
  }

  /// Initialize and query product offerings from Apple App Store or Google Play
  Future<List<ProductDetails>> loadProducts(Set<String> productIds) async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      debugPrint('[IAP] Store is not available on this device');
      return [];
    }

    final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      debugPrint('[IAP] Error querying products: ${response.error}');
    }

    _availableProducts = response.productDetails;
    return _availableProducts;
  }

  /// Buy a consumable pass (e.g. 1-Hour Pass, 6-Hour Pass)
  Future<bool> buyPass(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    return await _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  /// Buy an auto-renewable subscription (e.g. Monthly Premium)
  Future<bool> buySubscription(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Process incoming purchase updates from StoreKit / Play Billing
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      _purchaseStatusController.add(purchase);

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Verify with backend
        final bool valid = await _verifyWithBackend(purchase);
        if (valid) {
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        }
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('[IAP] Purchase error: ${purchase.error}');
      }
    }
  }

  /// Server-side validation with Django backend
  Future<bool> _verifyWithBackend(PurchaseDetails purchase) async {
    try {
      final platform = Platform.isIOS ? 'apple' : 'google';
      final receiptData = purchase.verificationData.serverVerificationData;

      final payload = {
        'store': platform,
        'receipt': receiptData,
        'product_id': purchase.productID,
        if (Platform.isAndroid) 'package_name': 'com.spyce.dating',
      };

      // Determine endpoint based on product prefix or default
      final endpoint = purchase.productID.contains('pass') || purchase.productID.contains('pkg')
          ? '/call-time/verify-package-purchase/'
          : '/subscription/verify-purchase/';

      final response = await _apiClient.post<dynamic>(endpoint, data: payload);
      return response != null;
    } catch (e) {
      debugPrint('[IAP] Backend verification failed: $e');
      return false;
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void dispose() {
    _subscription?.cancel();
    _purchaseStatusController.close();
  }
}
