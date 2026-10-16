import 'package:flutter/foundation.dart';

/// AdMob identifiers for Pagelit.
///
/// The AdMob app ID is registered in AndroidManifest.xml.
class AdIds {
  static const bool _kDebug = kDebugMode;

  /// ⚠️ This banner unit is currently shared with Battle Cows.
  /// For clean per-app reporting, create a dedicated banner unit for Pagelit
  /// in the AdMob console (Ad units → New ad unit → Banner) and replace it.
  static const String banner = _kDebug
      ? 'ca-app-pub-3940256099942544/6300978111' // Google TEST banner (debug/dev)
      : 'ca-app-pub-6774620515484669/1564457516'; // production banner
}
