import 'package:flutter/material.dart';

/// Small brand glyph: a bold red PDF sheet with a folded white corner and
/// a yellow highlighter stroke. Rendered with CustomPaint so it stays crisp
/// at every size (toolbar dots, app bars, favicons).
class PdfGlyph extends StatelessWidget {
  const PdfGlyph({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PdfGlyphPainter()),
    );
  }
}

class _PdfGlyphPainter extends CustomPainter {
  static const _red = Color(0xFFE5453B);
  static const _white = Color(0xFFFFFFFF);
  static const _line = Color(0xFFD2D2E0);
  static const _yellow = Color(0xFFFFD93D);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);

    final sheet = Path()
      ..moveTo(20, 13)
      ..lineTo(62, 13)
      ..lineTo(76, 27)
      ..lineTo(76, 87)
      ..lineTo(20, 87)
      ..close();
    canvas.drawPath(sheet, Paint()..color = _red);

    final fold = Path()
      ..moveTo(62, 13)
      ..lineTo(76, 27)
      ..lineTo(62, 27)
      ..close();
    canvas.drawPath(fold, Paint()..color = _white);

    // Faint text lines, like the body of a page.
    final linePaint = Paint()..color = _line;
    for (final y in [32, 41, 50]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(28, y.toDouble(), 34, 4),
          const Radius.circular(2),
        ),
        linePaint,
      );
    }
    // The yellow "highlight" stroke - the signature of Pagelit.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(28, 59, 30, 6),
        const Radius.circular(3),
      ),
      Paint()..color = _yellow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
