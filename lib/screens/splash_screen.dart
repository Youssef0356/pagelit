import 'dart:async';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/onboarding_prefs.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

/// Animated splash screen shown on app launch.
///
/// Features a smooth brand entrance animation, displays the app glyph and
/// localized tagline, and automatically directs the user to either the
/// first-time [OnboardingScreen] or the [HomeScreen].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.70, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOut),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.90, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.20),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.90, curve: Curves.easeOutCubic),
      ),
    );

    _animController.forward();

    // Allow the splash animation to finish cleanly (~1.7s) before transitioning.
    _navTimer = Timer(const Duration(milliseconds: 1750), _proceedToNextScreen);
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _proceedToNextScreen() {
    if (!mounted) return;

    final targetScreen = OnboardingPrefs.isCompleted.value
        ? const HomeScreen()
        : const OnboardingScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
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
        child: Stack(
          children: [
            // Center Brand Visuals
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Logo with subtle soft ambient glow
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoFade.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppPalette.signal.withValues(alpha: 0.12),
                          boxShadow: [
                            BoxShadow(
                              color: AppPalette.signal.withValues(alpha: isDark ? 0.25 : 0.18),
                              blurRadius: 36,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset(
                              'assets/logo/pagelit_icon512.png',
                              width: 80,
                              height: 80,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppPalette.signal,
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: const Icon(
                                    Icons.auto_stories_rounded,
                                    color: Colors.white,
                                    size: 44,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // App Title & Localized Tagline
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textFade,
                        child: Column(
                          children: [
                            Text(
                              l10n.appTitle,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: ink,
                                fontFamily: AppTheme.fontFamily,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.splashTagline,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: muted,
                                letterSpacing: 0.2,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Brand Footnote
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: FadeTransition(
                opacity: _textFade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppPalette.signal.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '100% OFFLINE & PRIVATE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                        color: muted.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
