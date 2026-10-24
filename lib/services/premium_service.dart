/// The one-time "Remove ads" purchase, billed through Google Play.
///
/// Requires a one-time product with the id [PremiumService.productId]
/// created in the Play Console (Monetise → Products → One-time products).
///
/// Flow: [PremiumService.load] restores the cached flag before the first
/// frame so ads are hidden instantly on launch; [PremiumService.init] then
/// talks to Play in the background to fetch the localised price and
/// re-sync ownership (purchases made on another device, reinstalls,
/// unacknowledged purchases). [PremiumService.buy] hands off to the Play
/// purchase sheet; the result arrives on the purchase stream and flips
/// [PremiumService.isPremium], which the whole UI observes.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a [PremiumService.restore] attempt.
enum RestoreOutcome {
  /// The purchase was found and premium is now active.
  granted,

  /// The restore ran cleanly but Play owns nothing for this account.
  notFound,

  /// The restore itself failed; the reason is on [PremiumService.lastError].
  failed,
}

class PremiumService {
  /// Product id configured in the Play Console.
  static const String productId = 'remove_ads';

  /// Candidate product IDs to match against various Play Console setups.
  static const Set<String> productIds = {
    productId,
    'com.the356company.pagelit.remove_ads',
    'pagelit_remove_ads',
  };

  /// Play Billing response name for ITEM_ALREADY_OWNED, as it appears in
  /// [IAPError.message] (e.g. "BillingResponse.itemAlreadyOwned").
  static const _itemAlreadyOwned = 'itemAlreadyOwned';

  static const _ownedKey = 'premium_remove_ads';

  /// True once the user owns "Remove ads" (bought or restored).
  static final ValueNotifier<bool> isPremium = ValueNotifier(false);

  /// True while the Play purchase sheet is open / awaiting confirmation.
  static final ValueNotifier<bool> isBuying = ValueNotifier(false);

  /// Localised price of the product (e.g. "$1.00"); null until queried,
  /// or permanently on devices without the Play Store.
  static final ValueNotifier<String?> priceLabel = ValueNotifier(null);

  /// One-shot failure message for the UI to display (and then clear).
  static final ValueNotifier<String?> lastError = ValueNotifier(null);

  static ProductDetails? _product;
  static Future<void>? _initialising;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// The purchase-stream batch currently being processed, so [restore] can
  /// wait for its own deliveries to be granted before reporting a result.
  static Future<void>? _processing;

  /// Reads the cached flag. Cheap and local — call before `runApp` so the
  /// first frame already hides ads for premium users.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isPremium.value = prefs.getBool(_ownedKey) ?? false;
  }

  /// Connects to Google Play in the background. Safe to call repeatedly;
  /// memoizes the first in-flight initialization.
  static Future<void> init() => _initialising ??= _init();

  static Future<void> _init() async {
    await refreshProductDetails();
  }

  /// Actively queries Google Play Billing for the product details.
  /// Safe to call on demand (e.g. when user taps "Remove ads").
  static Future<bool> refreshProductDetails() async {
    try {
      final iap = InAppPurchase.instance;
      final available = await iap.isAvailable();
      if (!available) {
        lastError.value = 'Google Play Billing is unavailable on this device.';
        return false;
      }

      _subscription ??= iap.purchaseStream.listen(
        (purchases) => _processing = _onPurchases(purchases),
        onError: (Object err) {
          isBuying.value = false;
          lastError.value = 'Billing error: $err';
        },
      );

      final response = await iap.queryProductDetails(productIds);
      if (response.error != null) {
        lastError.value = response.error!.message;
      }

      if (response.productDetails.isNotEmpty) {
        _product = response.productDetails.first;
        priceLabel.value = _product!.price;
        return true;
      }
    } catch (e) {
      lastError.value = 'Billing error: $e';
    }
    return false;
  }

  /// Launches the Play purchase sheet for "Remove ads".
  ///
  /// Dynamically queries product details if not already loaded.
  /// Returns false when the flow could not start (billing unavailable, or
  /// a purchase already in progress).
  static Future<bool> buy() async {
    if (isPremium.value || isBuying.value) return false;

    isBuying.value = true;
    try {
      // If product details aren't loaded yet, try to load them now
      if (_product == null) {
        await refreshProductDetails();
      }

      final product = _product;
      if (product == null) {
        isBuying.value = false;
        return false;
      }

      final started = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );

      if (!started) {
        isBuying.value = false;
      } else {
        // Auto-reset buying state after 30 seconds if dismissed out-of-band
        Future<void>.delayed(const Duration(seconds: 30), () {
          if (isBuying.value && !isPremium.value) {
            isBuying.value = false;
          }
        });
      }
      return started;
    } catch (e) {
      isBuying.value = false;
      lastError.value = 'Could not start purchase: $e';
      return false;
    }
  }

  /// Re-checks ownership with Play — for reinstalls and new devices.
  ///
  /// Waits until any restored purchase delivered by Play has been fully
  /// processed, so the outcome is settled when this returns.
  static Future<RestoreOutcome> restore() async {
    if (isPremium.value) return RestoreOutcome.granted;
    isBuying.value = true;
    try {
      final iap = InAppPurchase.instance;
      if (await iap.isAvailable()) {
        _subscription ??= iap.purchaseStream.listen(
          (purchases) => _processing = _onPurchases(purchases),
          onError: (Object err) {
            isBuying.value = false;
            lastError.value = 'Billing error: $err';
          },
        );
      }
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      isBuying.value = false;
      lastError.value = 'Restore failed: $e';
      return RestoreOutcome.failed;
    }

    // Restored purchases arrive on the stream asynchronously: wait one turn
    // of the event loop for the listener to be invoked, then for it to
    // finish granting.
    await Future<void>.delayed(Duration.zero);
    await _processing;
    isBuying.value = false;
    return isPremium.value ? RestoreOutcome.granted : RestoreOutcome.notFound;
  }

  static Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      // Every store call below is documented to throw on occasion; a bad
      // transaction must never kill the purchase stream listener.
      try {
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            if (productIds.contains(purchase.productID) || purchase.productID == productId) {
              await _grant();
            }
          case PurchaseStatus.pending:
            isBuying.value = true;
          case PurchaseStatus.canceled:
            isBuying.value = false;
          case PurchaseStatus.error:
            isBuying.value = false;
            // ITEM_ALREADY_OWNED: owned but not acked on this device; a
            // restore re-delivers it and grants through the restored branch.
            if (purchase.error?.message.contains(_itemAlreadyOwned) == true) {
              unawaited(InAppPurchase.instance.restorePurchases());
            } else {
              lastError.value = 'Purchase failed. Please try again.';
            }
        }
        // Acknowledge settled purchases so Play does not auto-refund them
        // after 3 days; pending flows are finished once they resolve.
        if (purchase.status != PurchaseStatus.pending &&
            purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
      } catch (_) {
        // Swallow and move on to the next transaction.
      }
    }
  }

  static Future<void> _grant() async {
    await grantPremium(persist: true);
  }

  /// Grants premium status immediately, stops ads, and optionally saves to preferences.
  static Future<void> grantPremium({bool persist = true}) async {
    isPremium.value = true;
    isBuying.value = false;
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_ownedKey, true);
    }
  }

  /// Revokes premium status immediately and removes the persisted preference.
  static Future<void> revokePremium() async {
    isPremium.value = false;
    isBuying.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ownedKey);
  }

  /// Debug helper: sets premium and persists it.
  static void debugSetPremium(bool value) {
    assert(kDebugMode, 'debugSetPremium must only be used in debug builds');
    if (value) {
      grantPremium(persist: true);
    } else {
      revokePremium();
    }
  }

  /// Debug-only: back to a clean, non-premium state (used by tests).
  @visibleForTesting
  static void debugReset() {
    _initialising = null;
    _processing = null;
    _product = null;
    _subscription?.cancel();
    _subscription = null;
    isPremium.value = false;
    isBuying.value = false;
    priceLabel.value = null;
    lastError.value = null;
  }
}
