import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/locale_prefs.dart';
import '../services/onboarding_prefs.dart';
import '../services/theme_prefs.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// First-launch setup screen where users configure their preferred appearance
/// (Light/White mode vs Dark mode) and interface language.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0; // 0 = Theme, 1 = Language
  late ThemeMode _selectedTheme;
  Locale? _selectedLocale;

  @override
  void initState() {
    super.initState();
    _selectedTheme = ThemePrefs.mode.value;
    if (_selectedTheme == ThemeMode.system) {
      _selectedTheme = ThemeMode.light;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ThemePrefs.set(ThemeMode.light);
      });
    }
    _selectedLocale = LocalePrefs.locale.value;
  }

  void _onThemeSelected(ThemeMode mode) {
    setState(() => _selectedTheme = mode);
    ThemePrefs.set(mode);
  }

  void _onLocaleSelected(Locale? locale) {
    setState(() => _selectedLocale = locale);
    LocalePrefs.set(locale);
  }

  Future<void> _completeOnboarding() async {
    await OnboardingPrefs.complete();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final bg = isDark ? AppPalette.night : AppPalette.paper;
    final ink = isDark ? AppPalette.inkNight : AppPalette.inkLight;
    final muted = isDark ? AppPalette.mutedNight : AppPalette.mutedLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Progress & Step Indicators
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStepHeader(isDark, ink, muted, l10n),
                        const SizedBox(height: 28),
                        // Animated Switcher between Step 1 (Theme) and Step 2 (Language)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: _currentStep == 0
                              ? _buildThemeStep(isDark, ink, muted, l10n)
                              : _buildLanguageStep(isDark, ink, muted, l10n),
                        ),
                      ],
                    ),

                    // Bottom Navigation Bar
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 8),
                      child: _buildBottomActions(isDark, ink, muted, l10n),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStepHeader(
    bool isDark,
    Color ink,
    Color muted,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        // App Glyph Icon
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppPalette.signal,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppPalette.signal.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.welcomeToPagelit,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ink,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _currentStep == 0
                    ? '${l10n.stepTheme} • 1 / 2'
                    : '${l10n.stepLanguage} • 2 / 2',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
        // Step progress pill bars
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProgressPill(active: _currentStep >= 0, isDark: isDark),
            const SizedBox(width: 6),
            _buildProgressPill(active: _currentStep >= 1, isDark: isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressPill({required bool active, required bool isDark}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: active ? 24 : 10,
      height: 6,
      decoration: BoxDecoration(
        color: active
            ? AppPalette.signal
            : (isDark ? AppPalette.hairlineNight : AppPalette.hairlineLight),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildThemeStep(
    bool isDark,
    Color ink,
    Color muted,
    AppLocalizations l10n,
  ) {
    return Column(
      key: const ValueKey('step_theme'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.chooseThemeTitle,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: ink,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.chooseThemeSubtitle,
          style: TextStyle(
            fontSize: 14,
            color: muted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),

        // Light (White) Card
        _ThemeSelectionCard(
          isSelected: _selectedTheme == ThemeMode.light,
          isDarkThemeCard: false,
          title: l10n.themeLightTitle,
          subtitle: l10n.themeLightSubtitle,
          icon: Icons.light_mode_rounded,
          onTap: () => _onThemeSelected(ThemeMode.light),
        ),
        const SizedBox(height: 16),

        // Dark Card
        _ThemeSelectionCard(
          isSelected: _selectedTheme == ThemeMode.dark,
          isDarkThemeCard: true,
          title: l10n.themeDarkTitle,
          subtitle: l10n.themeDarkSubtitle,
          icon: Icons.dark_mode_rounded,
          onTap: () => _onThemeSelected(ThemeMode.dark),
        ),
        const SizedBox(height: 14),

        // System Default quick toggle chip
        Center(
          child: TextButton.icon(
            onPressed: () => _onThemeSelected(ThemeMode.system),
            icon: Icon(
              Icons.brightness_auto_rounded,
              size: 18,
              color: _selectedTheme == ThemeMode.system ? AppPalette.signal : muted,
            ),
            label: Text(
              l10n.themeSystem,
              style: TextStyle(
                fontSize: 13,
                fontWeight: _selectedTheme == ThemeMode.system
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: _selectedTheme == ThemeMode.system ? AppPalette.signal : muted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageStep(
    bool isDark,
    Color ink,
    Color muted,
    AppLocalizations l10n,
  ) {
    final currentCode = _selectedLocale?.languageCode ??
        Localizations.localeOf(context).languageCode;

    return Column(
      key: const ValueKey('step_language'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.chooseLanguageTitle,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: ink,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.chooseLanguageSubtitle,
          style: TextStyle(
            fontSize: 14,
            color: muted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),

        // English Card
        _LanguageSelectionCard(
          key: const ValueKey('lang_card_en'),
          isSelected: currentCode == 'en',
          flagEmoji: '🇬🇧',
          nativeName: 'English',
          englishName: 'English',
          onTap: () => _onLocaleSelected(const Locale('en')),
        ),
        const SizedBox(height: 14),

        // Français Card
        _LanguageSelectionCard(
          key: const ValueKey('lang_card_fr'),
          isSelected: currentCode == 'fr',
          flagEmoji: '🇫🇷',
          nativeName: 'Français',
          englishName: 'French',
          onTap: () => _onLocaleSelected(const Locale('fr')),
        ),
        const SizedBox(height: 14),

        // العربية Card
        _LanguageSelectionCard(
          key: const ValueKey('lang_card_ar'),
          isSelected: currentCode == 'ar',
          flagEmoji: '🇸🇦',
          nativeName: 'العربية',
          englishName: 'Arabic',
          isRtlBadge: true,
          onTap: () => _onLocaleSelected(const Locale('ar')),
        ),
      ],
    );
  }

  Widget _buildBottomActions(
    bool isDark,
    Color ink,
    Color muted,
    AppLocalizations l10n,
  ) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Row(
      children: [
        if (_currentStep > 0) ...[
          OutlinedButton(
            onPressed: () {
              setState(() => _currentStep = 0);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              side: BorderSide(
                color: isDark ? AppPalette.hairlineNight : AppPalette.hairlineLight,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isRtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                  size: 18,
                  color: ink,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.previous,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (_currentStep == 0) {
                setState(() => _currentStep = 1);
              } else {
                _completeOnboarding();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.signal,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              shadowColor: AppPalette.signal.withValues(alpha: 0.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currentStep == 0 ? l10n.continueButton : l10n.getStarted,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _currentStep == 0
                      ? (isRtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded)
                      : Icons.check_circle_rounded,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Interactive card for picking Light (White) or Dark mode with preview.
class _ThemeSelectionCard extends StatelessWidget {
  const _ThemeSelectionCard({
    required this.isSelected,
    required this.isDarkThemeCard,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final bool isSelected;
  final bool isDarkThemeCard;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currentThemeIsDark = Theme.of(context).brightness == Brightness.dark;

    // The card preview background color
    final cardBg = isDarkThemeCard ? const Color(0xFF1E1D24) : Colors.white;
    final cardBorder = isSelected
        ? AppPalette.signal
        : (currentThemeIsDark ? AppPalette.hairlineNight : AppPalette.hairlineLight);
    final textInk = isDarkThemeCard ? Colors.white : const Color(0xFF1B1A22);
    final textMuted = isDarkThemeCard
        ? const Color(0xFFA5A1B0)
        : const Color(0xFF6B6675);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: cardBorder,
            width: isSelected ? 2.2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppPalette.signal.withValues(alpha: 0.16)
                  : Colors.black.withValues(alpha: currentThemeIsDark ? 0.25 : 0.05),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Theme Icon Badge with mini document preview
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDarkThemeCard
                    ? Colors.black26
                    : const Color(0xFFF3EFEA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDarkThemeCard
                      ? Colors.white12
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: 26,
                    color: isDarkThemeCard
                        ? const Color(0xFFFFB74D)
                        : const Color(0xFFE5453B),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Card Text Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textInk,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            // Radio Indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppPalette.signal : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppPalette.signal : textMuted.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive card for picking Language.
class _LanguageSelectionCard extends StatelessWidget {
  const _LanguageSelectionCard({
    super.key,
    required this.isSelected,
    required this.flagEmoji,
    required this.nativeName,
    required this.englishName,
    required this.onTap,
    this.isRtlBadge = false,
  });

  final bool isSelected;
  final String flagEmoji;
  final String nativeName;
  final String englishName;
  final VoidCallback onTap;
  final bool isRtlBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? AppPalette.cardNight : AppPalette.cardLight;
    final ink = isDark ? AppPalette.inkNight : AppPalette.inkLight;
    final muted = isDark ? AppPalette.mutedNight : AppPalette.mutedLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppPalette.signal
                : (isDark ? AppPalette.hairlineNight : AppPalette.hairlineLight),
            width: isSelected ? 2.2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppPalette.signal.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: isSelected ? 14 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Flag Icon Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF282732) : const Color(0xFFF3EFEA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  flagEmoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Language Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        nativeName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ink,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                      if (isRtlBadge) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppPalette.signal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'RTL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.signal,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    englishName,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),

            // Radio Checkmark
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppPalette.signal : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppPalette.signal : muted.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
