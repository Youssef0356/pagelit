import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Empty-state illustration: a small stack of pages carrying Pagelit's
/// signature folded corner and highlighter stroke. Drawn with [CustomPaint]
/// so it stays crisp and theme-aware (light/dark) at any size.
class PaperStack extends StatelessWidget {
  const PaperStack({super.key, this.size = const Size(172, 140)});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return RepaintBoundary(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: CustomPaint(
          painter: _PaperStackPainter(
            back: isDark ? const Color(0xFF26252E) : const Color(0xFFF1ECE3),
            sheet: isDark ? AppPalette.cardNight : Colors.white,
            hairline: scheme.outlineVariant,
            lines: isDark ? const Color(0xFF383743) : const Color(0xFFE9E3D8),
            stroke: AppPalette.signal,
            shadow: isDark ? Colors.transparent : const Color(0x1A17161C),
          ),
        ),
      ),
    );
  }
}

class _PaperStackPainter extends CustomPainter {
  const _PaperStackPainter({
    required this.back,
    required this.sheet,
    required this.hairline,
    required this.lines,
    required this.stroke,
    required this.shadow,
  });

  final Color back;
  final Color sheet;
  final Color hairline;
  final Color lines;
  final Color stroke;
  final Color shadow;

  static const _radius = Radius.circular(16);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Two sheets peeking out behind the front one.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, 2, w * 0.82, h - 26),
        _radius,
      ),
      Paint()..color = back,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.07, 8, w * 0.84, h - 26),
        _radius,
      ),
      Paint()..color = sheet,
    );

    // The front page, lifted off the stack by a soft shadow.
    final front = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 16, w * 0.84, h - 22),
      _radius,
    );
    canvas.drawRRect(
      front,
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(front, Paint()..color = sheet);
    canvas.drawRRect(
      front,
      Paint()
        ..color = hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Folded top-right corner.
    final right = front.right;
    final top = front.top;
    const fold = 30.0;
    canvas.drawPath(
      Path()
        ..moveTo(right - fold, top)
        ..lineTo(right, top + fold)
        ..lineTo(right, top)
        ..close(),
      Paint()..color = back,
    );
    canvas.drawLine(
      Offset(right - fold, top),
      Offset(right, top + fold),
      Paint()
        ..color = hairline
        ..strokeWidth = 1,
    );

    // Faint body lines.
    final linePaint = Paint()..color = lines;
    for (final y in [44.0, 58.0, 72.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(20, y, w * 0.56, 6),
          const Radius.circular(3),
        ),
        linePaint,
      );
    }

    // The highlighter stroke — the signature of Pagelit.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, 92, w * 0.46, 10),
        const Radius.circular(5),
      ),
      Paint()..color = stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _PaperStackPainter oldDelegate) =>
      oldDelegate.back != back ||
      oldDelegate.sheet != sheet ||
      oldDelegate.hairline != hairline ||
      oldDelegate.lines != lines ||
      oldDelegate.stroke != stroke ||
      oldDelegate.shadow != shadow;
}
