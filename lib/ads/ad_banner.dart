import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/premium_service.dart';
import 'ad_ids.dart';

/// A responsive anchored adaptive banner shown at the bottom of every screen.
///
/// Renders nothing (zero height) until/unless the ad loads, so a missing
/// network or a failed ad never breaks the layout.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    PremiumService.isPremium.addListener(_onPremiumChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad == null && !_loading && !PremiumService.isPremium.value) _load();
  }

  /// The premium state flipped. Granted: drop the live ad immediately so it
  /// stops being displayed and never loads again. Revoked (debug preview
  /// only — real purchases are permanent): start requesting ads again.
  void _onPremiumChanged() {
    if (!mounted) return;
    if (PremiumService.isPremium.value) {
      final ad = _ad;
      _ad = null;
      _loaded = false;
      _loading = false;
      if (ad != null) {
        // The AdWidget is still attached this frame (the build rebuild
        // removes it in the same pass); dispose after the frame so the ad
        // is never released while on screen.
        WidgetsBinding.instance.addPostFrameCallback((_) => ad.dispose());
      }
    } else if (_ad == null && !_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    _loading = true;
    try {
      // Read the width first (context must not be used after an await).
      final width = MediaQuery.sizeOf(context).width.round().clamp(320, 100000);
      // Main() initialises this in the background; wait so the first
      // banner request never races an uninitialised SDK.
      await MobileAds.instance.initialize();
      final AdSize size =
          await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width) ??
          AdSize.banner;

      var failed = false;
      final ad = BannerAd(
        adUnitId: AdIds.banner,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            failed = true;
            ad.dispose();
            if (mounted) setState(() => _ad = null);
          },
        ),
      );
      await ad.load();
      if (!mounted || PremiumService.isPremium.value) {
        // Disposed, or the user turned premium while this ad was loading:
        // dispose() only covers a stored _ad, so release it here instead.
        if (!failed) ad.dispose();
        return;
      }
      if (!failed) _ad = ad;
    } catch (_) {
      // Surface (or no-) ads never break the layout.
      if (mounted) setState(() => _ad = null);
    }
  }

  @override
  void dispose() {
    PremiumService.isPremium.removeListener(_onPremiumChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Renders nothing (zero height) for premium users and while loading,
    // so the surrounding layout never shifts.
    return ValueListenableBuilder<bool>(
      valueListenable: PremiumService.isPremium,
      builder: (context, premium, _) {
        final ad = _ad;
        if (premium || !_loaded || ad == null) return const SizedBox.shrink();
        return SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        );
      },
    );
  }
}
