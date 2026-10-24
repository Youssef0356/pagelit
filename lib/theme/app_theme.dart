import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pagelit's colours: warm paper surfaces, ink text and one Signal-red accent
/// (the red of the app glyph). Nothing else is allowed to be a brand colour.
class AppPalette {
  const AppPalette._();

  /// The single accent: the red of the Pagelit glyph.
  static const signal = Color(0xFFE5453B);
  static const signalDeep = Color(0xFFC33A31);

  // Light ("paper") surfaces.
  static const paper = Color(0xFFFBF8F4);
  static const cardLight = Color(0xFFFFFFFF);
  static const hairlineLight = Color(0xFFE9E2D8);
  static const inkLight = Color(0xFF17161C);
  static const mutedLight = Color(0xFF6E6A77);
  static const signalWashLight = Color(0xFFFBE6E3);
  static const washLight = Color(0xFFF4F0E8);

  // Dark ("night") surfaces.
  static const night = Color(0xFF121117);
  static const cardNight = Color(0xFF1C1B23);
  static const hairlineNight = Color(0xFF2C2B35);
  static const inkNight = Color(0xFFEDEAF2);
  static const mutedNight = Color(0xFFA6A2B1);
  static const signalWashNight = Color(0xFF3A2320);
}

/// Spacing, radius and stroke scale used across the app.
class AppShape {
  const AppShape._();

  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 22;
  static const double hairline = 1;
  static const double gap = 8;
  static const double gutter = 16;
}

class AppTheme {
  const AppTheme._();

  static const String fontFamily = 'Poppins';
  static const List<String> fontFamilyFallback = [
    'Noto Sans Arabic',
    'Roboto',
    'Segoe UI',
    'Tahoma',
    'Arial',
    'sans-serif',
  ];

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// A page transition with a soft fade + 1.5 % scale: calmer than the
  /// default Material push and shared by every route in the app.
  static PageTransitionsBuilder get pageTransition =>
      const _FadeScalePageTransitionsBuilder();

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final ink = isDark ? AppPalette.inkNight : AppPalette.inkLight;
    final muted = isDark ? AppPalette.mutedNight : AppPalette.mutedLight;
    final card = isDark ? AppPalette.cardNight : AppPalette.cardLight;
    final hairline = isDark
        ? AppPalette.hairlineNight
        : AppPalette.hairlineLight;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppPalette.signal,
          brightness: brightness,
        ).copyWith(
          primary: AppPalette.signal,
          onPrimary: Colors.white,
          primaryContainer: isDark
              ? AppPalette.signalWashNight
              : AppPalette.signalWashLight,
          onPrimaryContainer: isDark
              ? const Color(0xFFFFDBD6)
              : AppPalette.signalDeep,
          secondary: muted,
          onSecondary: Colors.white,
          surface: isDark ? AppPalette.night : AppPalette.paper,
          onSurface: ink,
          surfaceContainerLowest: isDark ? const Color(0xFF0D0C12) : card,
          surfaceContainerLow: card,
          surfaceContainer: isDark
              ? const Color(0xFF232229)
              : AppPalette.washLight,
          surfaceContainerHigh: isDark
              ? const Color(0xFF292830)
              : const Color(0xFFEFEAE1),
          surfaceContainerHighest: hairline,
          outline: isDark ? const Color(0xFF8A8593) : const Color(0xFF8B8792),
          outlineVariant: hairline,
        );

    final textTheme = TextTheme(
      headlineSmall: _text(
        24,
        FontWeight.w600,
        32 / 24,
        tracking: -0.4,
        color: ink,
      ),
      titleLarge: _text(
        20,
        FontWeight.w600,
        26 / 20,
        tracking: -0.3,
        color: ink,
      ),
      titleMedium: _text(
        16,
        FontWeight.w600,
        22 / 16,
        tracking: -0.1,
        color: ink,
      ),
      titleSmall: _text(13.5, FontWeight.w600, 18 / 13.5, color: ink),
      bodyLarge: _text(16, FontWeight.w400, 24 / 16, color: ink),
      bodyMedium: _text(14, FontWeight.w400, 21 / 14, color: ink),
      bodySmall: _text(12.5, FontWeight.w400, 17 / 12.5, color: muted),
      labelLarge: _text(
        15,
        FontWeight.w600,
        20 / 15,
        tracking: 0.1,
        color: ink,
      ),
      labelMedium: _text(
        13,
        FontWeight.w600,
        18 / 13,
        tracking: 0.2,
        color: muted,
      ),
      // Small caps eyebrow used for metadata rows.
      labelSmall: _text(
        11,
        FontWeight.w600,
        14 / 11,
        tracking: 0.9,
        color: muted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(
          bottom: BorderSide(color: hairline, width: AppShape.hairline),
        ),
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: ink, size: 22),
        actionsIconTheme: IconThemeData(color: ink, size: 22),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.signal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark
              ? AppPalette.signalWashNight
              : const Color(0xFFF7DBD7),
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: _text(15, FontWeight.w600, 20 / 15, color: Colors.white),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShape.radiusSmall),
          ),
          textStyle: _text(14, FontWeight.w600, 20 / 14, color: muted),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: ink),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppPalette.signal
              : scheme.surfaceContainerHigh,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppPalette.signal
                : scheme.surfaceContainerLow,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? Colors.white : ink,
          ),
          side: WidgetStateProperty.all(BorderSide(color: hairline)),
          textStyle: WidgetStateProperty.all(
            _text(13, FontWeight.w600, 18 / 13, color: null),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppShape.radiusSmall),
            ),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: AppPalette.signal,
        inactiveTrackColor: hairline,
        thumbColor: AppPalette.signal,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 7,
          elevation: 2,
        ),
        overlayColor: AppPalette.signal.withValues(alpha: 0.10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        trackShape: const RoundedRectSliderTrackShape(),
        showValueIndicator: ShowValueIndicator.never,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.radiusMedium),
          side: BorderSide(color: hairline),
        ),
        textStyle: textTheme.bodyMedium,
        iconColor: ink,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppPalette.inkNight : AppPalette.inkLight,
        contentTextStyle: _text(
          14,
          FontWeight.w500,
          20 / 14,
          color: isDark ? AppPalette.night : Colors.white,
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.radiusMedium),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.radiusMedium),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: _text(
          12,
          FontWeight.w500,
          16 / 12,
          color: isDark ? AppPalette.night : Colors.white,
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: pageTransition,
          TargetPlatform.iOS: pageTransition,
        },
      ),
    );
  }

  static TextStyle _text(
    double size,
    FontWeight weight,
    double height, {
    double tracking = 0,
    Color? color,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: tracking,
    color: color,
  );
}

class _FadeScalePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeScalePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}
