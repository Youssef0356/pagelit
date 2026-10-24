import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's language choice (system default, English, French, Arabic).
class LocalePrefs {
  const LocalePrefs._();

  static const _key = 'app_language_code';

  /// Broadcasts the current locale to the app (null = system default).
  static final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  /// Supported locales in the app.
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('fr'),
    Locale('ar'),
  ];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code == null || code.isEmpty || code == 'system') {
      locale.value = null;
    } else {
      locale.value = Locale(code);
    }
  }

  static Future<void> set(Locale? value) async {
    locale.value = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.setString(_key, 'system');
    } else {
      await prefs.setString(_key, value.languageCode);
    }
  }
}
