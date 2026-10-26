import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has finished the first-launch setup
/// (appearance and language configuration).
class OnboardingPrefs {
  const OnboardingPrefs._();

  static const String _key = 'has_completed_onboarding_v1';

  /// Broadcasts the completion state.
  static final ValueNotifier<bool> isCompleted = ValueNotifier<bool>(false);

  /// Loads the persisted state from SharedPreferences.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isCompleted.value = prefs.getBool(_key) ?? false;
  }

  /// Marks the onboarding setup as completed.
  static Future<void> complete() async {
    isCompleted.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// Resets the onboarding state (useful for testing or re-running setup).
  static Future<void> reset() async {
    isCompleted.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
