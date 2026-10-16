import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Page tint for comfortable reading (sepia for paper, dim for night).
enum ComfortMode { normal, sepia, dim }

/// Reading preferences shared by the settings screen and the reader.
///
/// Values are hot: the reader listens to these notifiers, so changes made in
/// Settings apply the moment the user comes back — except [layoutMode], which
/// is read once when a document opens (changing it would rebuild the viewer
/// and drop in-session annotations).
class ReadingPrefs {
  static const _keepScreenOnKey = 'keep_screen_on';
  static const _comfortKey = 'comfort_mode';
  static const _layoutKey = 'page_layout_mode';
  static const _colorKey = 'annotation_color';

  /// Keep the screen awake while a document is open.
  static final ValueNotifier<bool> keepScreenOn = ValueNotifier(false);

  /// Warm/dark tint applied over the page.
  static final ValueNotifier<ComfortMode> comfortMode = ValueNotifier(
    ComfortMode.normal,
  );

  /// Continuous scroll or one page at a time. Applied at document open.
  static final ValueNotifier<PdfPageLayoutMode> layoutMode = ValueNotifier(
    PdfPageLayoutMode.continuous,
  );

  /// Colour given to newly created annotations.
  static final ValueNotifier<Color> annotationColor = ValueNotifier(
    Colors.yellow,
  );

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    keepScreenOn.value = prefs.getBool(_keepScreenOnKey) ?? false;
    comfortMode.value = ComfortMode.values.firstWhere(
      (mode) => mode.name == prefs.getString(_comfortKey),
      orElse: () => ComfortMode.normal,
    );
    layoutMode.value = PdfPageLayoutMode.values.firstWhere(
      (mode) => mode.name == prefs.getString(_layoutKey),
      orElse: () => PdfPageLayoutMode.continuous,
    );
    final stored = prefs.getInt(_colorKey);
    annotationColor.value = stored == null ? Colors.yellow : Color(stored);
  }

  static Future<void> setKeepScreenOn(bool value) async {
    keepScreenOn.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepScreenOnKey, value);
  }

  static Future<void> setComfortMode(ComfortMode value) async {
    comfortMode.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_comfortKey, value.name);
  }

  static Future<void> setLayoutMode(PdfPageLayoutMode value) async {
    layoutMode.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_layoutKey, value.name);
  }

  static Future<void> setAnnotationColor(Color value) async {
    annotationColor.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, value.toARGB32());
  }
}
