Pagelit - image assets (current)
================================

Source artwork: logo.jpg (generated 2026-10-15, red PDF glyph on logo-blue).

1) pagelit_icon.png
   - Exact PNG of the supplied artwork: /no color normalization/.
   - Used for the legacy launcher icons (Android < 8).
   - Adaptive icon background color is the artwork's sampled blue:
     #3E3DCD (set in pubspec flutter_launcher_icons).

2) pagelit_foreground.png
   - Exact PNG (no inset cropping) so the adaptive icon keeps the
     exact proportions of the supplied artwork. Adaptive artwork is
     published full-bleed (inset = 0).

3) pagelit_splash_logo.png
   - The same artwork down-scaled to 780 x 780 (~260 dp).
   - Shown centered on a splash background of the sampled brand color
     (#3E3DCD) so the square blends edge-to-edge with the background.

Regenerate everything (after replacing logo.jpg) with:
    dart run tool/process_logo.dart
    dart run flutter_launcher_icons
    # also refresh the web copy with: dart run tool/make_web_icon.dart
