import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'screens/home_screen.dart';
import 'services/reading_prefs.dart';
import 'services/theme_prefs.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemePrefs.load();
  await ReadingPrefs.load();
  runApp(const PagelitApp());
  // Initialise the ad SDK in the background: it only needs to finish before
  // the first banner is loaded (AdBanner awaits this same call).
  unawaited(MobileAds.instance.initialize());
}

class PagelitApp extends StatelessWidget {
  const PagelitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemePrefs.mode,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'Pagelit',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const HomeScreen(),
      ),
    );
  }
}
