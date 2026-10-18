/// The one-time "Remove ads" purchase, billed through Google Play.
///
/// Requires a one-time product with the id [PremiumService.productId]
/// created in the Play Console (Monetise → Products → One-time products)
/// and priced at $1.
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

  /// The purchase-stream batch currently being processed, so [restore] can
  /// wait for its own deliveries to be granted before reporting a result.
  static Future<void>? _processing;

  /// Reads the cached flag. Cheap and local — call before `runApp` so the
  /// first frame already hides ads for premium users.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isPremium.value = prefs.getBool(_ownedKey) ?? false;
  }

  /// Connects to Google Play in the background. Safe to call once and only
  /// once; repeats return the same future.
  static Future<void> init() => _initialising ??= _init();

  static Future<void> _init() async {
    try {
      final iap = InAppPurchase.instance;
      // False on devices without the Play Store (some emulators, Huawei).
      if (!await iap.isAvailable()) return;
      iap.purchaseStream.listen(
        (purchases) => _processing = _onPurchases(purchases),
        onError: (Object _) {},
      );
      final response = await iap.queryProductDetails({productId});
      if (response.productDetails.isEmpty) return;
      _product = response.productDetails.first;
      priceLabel.value = _product!.price;
    } catch (_) {
      // Billing trouble must never crash the app; the UI simply shows no
      // price and the purchase option does nothing.
    }
  }

  /// Launches the Play purchase sheet for "Remove ads".
  ///
  /// Returns false when the flow could not start (billing unavailable, or
  /// a purchase already in progress). Failures that happen after the sheet
  /// opens arrive asynchronously through [lastError].
  static Future<bool> buy() async {
    final product = _product;
    if (product == null || isPremium.value || isBuying.value) return false;
    isBuying.value = true;
    try {
      final started = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) isBuying.value = false;
      return started;
    } catch (_) {
      isBuying.value = false;
      return false;
    }
  }

  /// Re-checks ownership with Play — for reinstalls and new devices.
  ///
  /// Waits until any restored purchase delivered by Play has been fully
  /// processed, so the outcome is settled when this returns.
  static Future<RestoreOutcome> restore() async {
    if (isPremium.value) return RestoreOutcome.granted;
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {
      isBuying.value = false;
      lastError.value = 'Restore failed. Please try again.';
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
            if (purchase.productID == productId) await _grant();
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
        // See above: swallow and move on to the next transaction.
      }
    }
  }

  static Future<void> _grant() async {
    isPremium.value = true;
    isBuying.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ownedKey, true);
  }

  /// Debug-only: simulate ownership without touching Play or the persisted
  /// cache, so the ad-free experience can be previewed on builds that cannot
  /// reach the store (emulators, sideloaded debug installs). Not saved —
  /// the flag resets on the next launch.
  static void debugSetPremium(bool value) {
    assert(kDebugMode, 'debugSetPremium must only be used in debug builds');
    isPremium.value = value;
    if (value) isBuying.value = false;
  }

  /// Debug-only: back to a clean, non-premium state (used by tests).
  @visibleForTesting
  static void debugReset() {
    _initialising = null;
    _processing = null;
    _product = null;
    isPremium.value = false;
    isBuying.value = false;
    priceLabel.value = null;
    lastError.value = null;
  }
}
