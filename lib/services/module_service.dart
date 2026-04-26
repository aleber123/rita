import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/modules_catalog.dart';

/// Tracks which paid modules the user has unlocked. Each module is a
/// non-consumable IAP — once bought, it's permanent and restored across
/// devices via [InAppPurchase.restorePurchases].
class ModuleService extends ChangeNotifier {
  static final ModuleService _instance = ModuleService._();
  factory ModuleService() => _instance;
  ModuleService._();

  static const String _unlockedKey = 'unlocked_modules';
  static const String _subProductKey = 'subscription_product';
  static const String _subActivatedAtKey = 'subscription_activated_at';

  /// Local-clock grace window for subscriptions when offline. StoreKit
  /// remains source of truth — every launch we re-call restorePurchases
  /// so renewals/cancellations are picked up.
  static const Duration _monthlyGrace = Duration(days: 32);
  static const Duration _yearlyGrace = Duration(days: 367);

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _storeAvailable = false;
  List<ProductDetails> _products = [];
  Set<String> _unlockedProductIds = {};

  String? _activeSubscriptionId;
  DateTime? _subscriptionActivatedAt;

  bool _purchasing = false;
  String? _lastError;

  bool get storeAvailable => _storeAvailable;
  List<ProductDetails> get products => _products;
  bool get purchasing => _purchasing;
  String? get lastError => _lastError;

  bool get hasActiveSubscription {
    final id = _activeSubscriptionId;
    final at = _subscriptionActivatedAt;
    if (id == null || at == null) return false;
    final grace = id == ModulesCatalog.subscriptionYearly
        ? _yearlyGrace
        : _monthlyGrace;
    return DateTime.now().isBefore(at.add(grace));
  }

  String? get activeSubscriptionId =>
      hasActiveSubscription ? _activeSubscriptionId : null;

  bool isUnlocked(String? productId) {
    if (productId == null) return true;
    if (hasActiveSubscription) return true;
    return _unlockedProductIds.contains(productId);
  }

  String priceFor(String productId, {String fallback = '29 kr'}) {
    final p = _products.where((e) => e.id == productId).firstOrNull;
    return p?.price ?? fallback;
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _unlockedProductIds = (prefs.getStringList(_unlockedKey) ?? []).toSet();
    _activeSubscriptionId = prefs.getString(_subProductKey);
    final activatedMs = prefs.getInt(_subActivatedAtKey);
    _subscriptionActivatedAt = activatedMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(activatedMs);

    try {
      _storeAvailable = await _iap.isAvailable();
      if (_storeAvailable) {
        _sub = _iap.purchaseStream.listen(
          _onPurchaseUpdate,
          onError: (e) => debugPrint('[Module] purchase stream error: $e'),
        );
        await _loadProducts();
        await _iap.restorePurchases();
      }
    } catch (e) {
      debugPrint('[Module] init failed: $e');
      _storeAvailable = false;
    }

    notifyListeners();
  }

  Future<void> _loadProducts() async {
    final ids = <String>{
      ...ModulesCatalog.all
          .map((m) => m.productId)
          .whereType<String>(),
      ...ModulesCatalog.subscriptionIds,
      ModulesCatalog.photoProductId,
      ModulesCatalog.magicPensProductId,
    };
    if (ids.isEmpty) return;
    final response = await _iap.queryProductDetails(ids);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[Module] not found: ${response.notFoundIDs}');
    }
    _products = response.productDetails;
    notifyListeners();
  }

  Future<bool> purchase(String productId) async {
    if (!_storeAvailable) {
      _lastError = 'store_not_available';
      notifyListeners();
      return false;
    }
    final product = _products.where((p) => p.id == productId).firstOrNull;
    if (product == null) {
      _lastError = 'product_not_found';
      notifyListeners();
      return false;
    }
    _purchasing = true;
    _lastError = null;
    notifyListeners();

    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      return true;
    } catch (e) {
      _purchasing = false;
      _lastError = 'purchase_failed';
      notifyListeners();
      return false;
    }
  }

  /// Auto-renewable subscription purchase. The plugin uses the same
  /// `buyNonConsumable` entry point on iOS — StoreKit decides product type
  /// based on App Store Connect configuration.
  Future<bool> purchaseSubscription(String productId) {
    if (!ModulesCatalog.subscriptionIds.contains(productId)) {
      _lastError = 'invalid_subscription';
      notifyListeners();
      return Future.value(false);
    }
    return purchase(productId);
  }

  Future<bool> restore() async {
    if (!_storeAvailable) return false;
    try {
      await _iap.restorePurchases();
      return true;
    } catch (e) {
      debugPrint('[Module] restore error: $e');
      return false;
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _purchasing = true;
          _lastError = null;
          notifyListeners();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _activate(p.productID);
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          _purchasing = false;
          notifyListeners();
          break;
        case PurchaseStatus.error:
          _purchasing = false;
          _lastError = p.error?.message ?? 'purchase_failed';
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          _purchasing = false;
          _lastError = null;
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          notifyListeners();
          break;
      }
    }
  }

  Future<void> _activate(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    if (ModulesCatalog.subscriptionIds.contains(productId)) {
      _activeSubscriptionId = productId;
      _subscriptionActivatedAt = DateTime.now();
      await prefs.setString(_subProductKey, productId);
      await prefs.setInt(
        _subActivatedAtKey,
        _subscriptionActivatedAt!.millisecondsSinceEpoch,
      );
      return;
    }
    if (_unlockedProductIds.add(productId)) {
      await prefs.setStringList(_unlockedKey, _unlockedProductIds.toList());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
