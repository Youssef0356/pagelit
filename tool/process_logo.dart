// Converts assets/logo/logo.jpg into the Android icon inputs WITHOUT
// recoloring anything - the exact artwork the user supplied is preserved.
//
// Outputs:
//   pagelit_icon.png          exact PNG (legacy launcher icon, Android < 8)
//   pagelit_foreground.png    exact PNG (adaptive 8+ foreground; inset set
//                             to 0 in pubspec so it stays full-bleed)
//   pagelit_splash_logo.png   down-scaled 780x780 PNG (centered splash,
//                             ~260 dp wide on every screen)
//
// Run: dart run tool/process_logo.dart
import 'dart:io';

import 'package:image/image.dart' as img;

const int canvas = 1024;
const int splash = 780;

void main() {
  final input = File('assets/logo/logo.jpg');
  if (!input.existsSync()) {
    stderr.writeln('assets/logo/logo.jpg not found');
    exit(1);
  }
  final decoded = img.decodeImage(input.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Could not decode logo.jpg');
    exit(1);
  }
  var src = decoded;
  if (src.width != src.height) {
    final side = (src.width < src.height ? src.width : src.height);
    src = img.copyCrop(
      src,
      x: (src.width - side) ~/ 2,
      y: (src.height - side) ~/ 2,
      width: side,
      height: side,
    );
  }
  if (src.width != canvas || src.height != canvas) {
    src = img.copyResize(src, width: canvas, height: canvas,
        interpolation: img.Interpolation.linear);
  }

  final png = img.encodePng(src);
  File('assets/logo/pagelit_icon.png').writeAsBytesSync(png);
  File('assets/logo/pagelit_foreground.png').writeAsBytesSync(png);
  final spl = img.copyResize(src, width: splash, height: splash,
      interpolation: img.Interpolation.linear);
  File('assets/logo/pagelit_splash_logo.png').writeAsBytesSync(img.encodePng(spl));

  stdout.writeln('Wrote pagelit_icon.png, pagelit_foreground.png, '
      'pagelit_splash_logo.png (colors untouched)');
}
