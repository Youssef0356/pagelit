import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pagelit/l10n/app_localizations.dart';
import 'package:pagelit/screens/home_screen.dart';
import 'package:pagelit/screens/onboarding_screen.dart';
import 'package:pagelit/screens/splash_screen.dart';
import 'package:pagelit/services/locale_prefs.dart';
import 'package:pagelit/services/onboarding_prefs.dart';
import 'package:pagelit/services/theme_prefs.dart';
import 'package:pagelit/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({Widget? home}) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocalePrefs.locale,
      builder: (context, locale, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemePrefs.mode,
        builder: (context, themeMode, _) => MaterialApp(
          themeMode: themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: home ?? const SplashScreen(),
        ),
      ),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    const deviceChannel = MethodChannel('pagelit/device_pdfs');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceChannel, (call) async {
      switch (call.method) {
        case 'hasAllFilesAccess':
          return false;
        case 'listPdfs':
          return const [];
        case 'loadFolders':
          return const [];
        default:
          return null;
      }
    });
    const deeplinkChannel = MethodChannel('pagelit/deeplink');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deeplinkChannel, (call) async => null);

    await ThemePrefs.load();
    await LocalePrefs.load();
    await OnboardingPrefs.load();
  });

  group('OnboardingPrefs Service', () {
    test('defaults to false when not set', () async {
      SharedPreferences.setMockInitialValues({});
      await OnboardingPrefs.load();
      expect(OnboardingPrefs.isCompleted.value, isFalse);
    });

    test('marks completed and persists', () async {
      SharedPreferences.setMockInitialValues({});
      await OnboardingPrefs.load();
      expect(OnboardingPrefs.isCompleted.value, isFalse);

      await OnboardingPrefs.complete();
      expect(OnboardingPrefs.isCompleted.value, isTrue);

      // Verify persistence across reload
      await OnboardingPrefs.load();
      expect(OnboardingPrefs.isCompleted.value, isTrue);
    });

    test('can be reset', () async {
      SharedPreferences.setMockInitialValues({'has_completed_onboarding_v1': true});
      await OnboardingPrefs.load();
      expect(OnboardingPrefs.isCompleted.value, isTrue);

      await OnboardingPrefs.reset();
      expect(OnboardingPrefs.isCompleted.value, isFalse);
    });
  });

  group('SplashScreen', () {
    testWidgets('renders brand title and tagline', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const SplashScreen()));
      await tester.pump();

      expect(find.text('Pagelit'), findsOneWidget);
      expect(find.text('100% OFFLINE & PRIVATE'), findsOneWidget);
    });

    testWidgets('navigates to OnboardingScreen when not completed', (tester) async {
      await OnboardingPrefs.reset();
      await tester.pumpWidget(buildTestApp(home: const SplashScreen()));

      // Advance through splash duration
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('navigates to HomeScreen when onboarding was already completed', (tester) async {
      await OnboardingPrefs.complete();
      await tester.pumpWidget(buildTestApp(home: const SplashScreen()));

      // Advance through splash duration & page transition
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('OnboardingScreen flow', () {
    testWidgets('Step 1 allows choosing between Light and Dark mode', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const OnboardingScreen()));
      await tester.pumpAndSettle();

      // Check Step 1 headers
      expect(find.text('Choose appearance'), findsOneWidget);
      expect(find.text('Light Mode'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);

      // Tap Dark Mode
      await tester.tap(find.text('Dark Mode'));
      await tester.pumpAndSettle();
      expect(ThemePrefs.mode.value, equals(ThemeMode.dark));

      // Tap Light Mode
      await tester.tap(find.text('Light Mode'));
      await tester.pumpAndSettle();
      expect(ThemePrefs.mode.value, equals(ThemeMode.light));
    });

    testWidgets('Advances from Step 1 to Step 2 and allows selecting language', (tester) async {
      await tester.pumpWidget(buildTestApp(home: const OnboardingScreen()));
      await tester.pumpAndSettle();

      // Tap Continue to go to Step 2 (Language)
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Choose language'), findsOneWidget);
      expect(find.text('English'), findsWidgets);
      expect(find.text('Français'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);

      // Select French
      await tester.tap(find.byKey(const ValueKey('lang_card_fr')));
      await tester.pumpAndSettle();
      expect(LocalePrefs.locale.value?.languageCode, equals('fr'));

      // The UI immediately updates to French!
      expect(find.text('Choisissez votre langue'), findsOneWidget);
      expect(find.text('Commencer'), findsOneWidget);

      // Select Arabic
      await tester.tap(find.byKey(const ValueKey('lang_card_ar')));
      await tester.pumpAndSettle();
      expect(LocalePrefs.locale.value?.languageCode, equals('ar'));

      // UI immediately updates to Arabic!
      expect(find.text('اختر لغة التطبيق'), findsOneWidget);
      expect(find.text('ابدأ القراءة'), findsOneWidget);

      // Finish Onboarding
      await tester.tap(find.text('ابدأ القراءة'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(OnboardingPrefs.isCompleted.value, isTrue);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
