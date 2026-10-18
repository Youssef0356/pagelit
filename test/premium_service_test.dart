import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:pagelit/services/premium_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal Play Billing stand-in: the product resolves instantly and
/// purchases are delivered through [purchases] like the real store does.
class _FakeStore extends InAppPurchasePlatform {
  final purchases = StreamController<List<PurchaseDetails>>.broadcast();

  /// When true, [restorePurchases] re-delivers an owned product.
  bool owned = false;
  bool available = true;
  int buyCalls = 0;
  int restoreCalls = 0;
  final completed = <String?>[];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => purchases.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
        productDetails: [
          ProductDetails(
            id: PremiumService.productId,
            title: 'Remove ads',
            description: 'Turns off every banner ad',
            price: r'$1.00',
            rawPrice: 1.0,
            currencyCode: 'USD',
            currencySymbol: r'$',
          ),
        ],
        notFoundIDs: identifiers.difference({PremiumService.productId}).toList(),
      );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyCalls++;
    return true;
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async =>
      false;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase.purchaseID);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
    if (owned) purchases.add([_receipt(PurchaseStatus.restored)]);
  }

  @override
  Future<String> countryCode() async => 'US';
}

/// A transaction as Play would deliver it: unacknowledged (so the plugin
/// expects a `completePurchase` call) unless still pending.
PurchaseDetails _receipt(PurchaseStatus status, {String? errorMessage}) {
  return PurchaseDetails(
    purchaseID: 'tx-1',
    productID: PremiumService.productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: '{}',
      serverVerificationData: 'token',
      source: 'google_play',
    ),
    transactionDate: '0',
    status: status,
  )
    ..pendingCompletePurchase = status != PurchaseStatus.pending
    ..error = errorMessage == null
        ? null
        : IAPError(
            source: 'google_play',
            code: 'purchase_error',
            message: errorMessage,
          );
}

/// Lets queued microtasks (stream delivery, prefs writes) settle.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeStore store;

  setUp(() {
    // InAppPurchase.instance registers the *real* platform on its first
    // access (the test binding reports Android, whose constructor opens a
    // method channel). Do that once up-front as iOS — whose registration is
    // side-effect free — then swap in the fake so it is not clobbered.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(InAppPurchase.instance, isNotNull);
    debugDefaultTargetPlatformOverride = null;

    SharedPreferences.setMockInitialValues({});
    PremiumService.debugReset();
    store = _FakeStore();
    InAppPurchasePlatform.instance = store;
  });

  tearDown(() => store.purchases.close());

  test('load() restores the cached premium flag', () async {
    SharedPreferences.setMockInitialValues({'premium_remove_ads': true});
    await PremiumService.load();
    expect(PremiumService.isPremium.value, isTrue);
  });

  test('load() defaults to non-premium', () async {
    await PremiumService.load();
    expect(PremiumService.isPremium.value, isFalse);
  });

  test('init() publishes the price; buy() starts the flow', () async {
    await PremiumService.init();
    expect(PremiumService.priceLabel.value, r'$1.00');

    expect(await PremiumService.buy(), isTrue);
    expect(store.buyCalls, 1);
    expect(PremiumService.isBuying.value, isTrue);

    // A second tap while the sheet is open must not double-bill.
    expect(await PremiumService.buy(), isFalse);
    expect(store.buyCalls, 1);
  });

  test('buy() is refused when billing is unavailable', () async {
    store.available = false;
    await PremiumService.init();
    expect(await PremiumService.buy(), isFalse);
    expect(store.buyCalls, 0);
  });

  test('a completed purchase grants, persists and acknowledges', () async {
    await PremiumService.init();
    await PremiumService.buy();

    store.purchases.add([_receipt(PurchaseStatus.purchased)]);
    await _settle();

    expect(PremiumService.isPremium.value, isTrue);
    expect(PremiumService.isBuying.value, isFalse);
    // Acknowledged, so Play will not auto-refund it after 3 days.
    expect(store.completed, ['tx-1']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('premium_remove_ads'), isTrue);
  });

  test('restore() waits for the delivered purchase before reporting',
      () async {
    await PremiumService.init();
    store.owned = true;

    // Must be `granted`, not `notFound`: the restore arrives on the stream
    // asynchronously and has to be processed before reporting.
    expect(await PremiumService.restore(), RestoreOutcome.granted);
    expect(PremiumService.isPremium.value, isTrue);
    expect(store.restoreCalls, 1);
  });

  test('restore() reports notFound when Play owns nothing', () async {
    await PremiumService.init();
    expect(await PremiumService.restore(), RestoreOutcome.notFound);
    expect(PremiumService.isPremium.value, isFalse);
    expect(store.restoreCalls, 1);
  });

  test('cancelling the sheet stops the spinner without an error', () async {
    await PremiumService.init();
    await PremiumService.buy();

    store.purchases.add([_receipt(PurchaseStatus.canceled)]);
    await _settle();

    expect(PremiumService.isBuying.value, isFalse);
    expect(PremiumService.isPremium.value, isFalse);
    expect(PremiumService.lastError.value, isNull);
  });

  test('a billing failure surfaces a message and stops the spinner',
      () async {
    await PremiumService.init();
    await PremiumService.buy();

    store.purchases.add([
      _receipt(PurchaseStatus.error, errorMessage: 'BillingResponse.error'),
    ]);
    await _settle();

    expect(PremiumService.isBuying.value, isFalse);
    expect(
      PremiumService.lastError.value,
      'Purchase failed. Please try again.',
    );
  });

  test('ITEM_ALREADY_OWNED triggers a silent restore, not an error', () async {
    await PremiumService.init();
    await PremiumService.buy();

    store.purchases.add([
      _receipt(
        PurchaseStatus.error,
        errorMessage: 'BillingResponse.itemAlreadyOwned',
      ),
    ]);
    await _settle();

    expect(PremiumService.lastError.value, isNull);
    expect(store.restoreCalls, 1);
  });

  test('transactions for other products are ignored', () async {
    await PremiumService.init();
    final other = PurchaseDetails(
      purchaseID: 'tx-other',
      productID: 'some_other_product',
      verificationData: PurchaseVerificationData(
        localVerificationData: '{}',
        serverVerificationData: 'token',
        source: 'google_play',
      ),
      transactionDate: '0',
      status: PurchaseStatus.purchased,
    );
    store.purchases.add([other]);
    await _settle();

    expect(PremiumService.isPremium.value, isFalse);
  });
}
