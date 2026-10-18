import 'package:flutter/foundation.dart';

/// AdMob identifiers for Pagelit.
///
/// The AdMob app ID is registered in AndroidManifest.xml.
class AdIds {
  static const bool _kDebug = kDebugMode;

  /// Dedicated Pagelit banner unit (Ad units → Banner).
  static const String banner = _kDebug
      ? 'ca-app-pub-3940256099942544/6300978111' // Google TEST banner (debug/dev)
      : 'ca-app-pub-6774620515484669/7829167281'; // production banner
}
