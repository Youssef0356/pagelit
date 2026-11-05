import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'encoding_utils.dart';

/// Single formatted text run within a slide paragraph.
class SlideTextSpan {
  const SlideTextSpan({
    required this.text,
    this.fontSize = 14.0,
    this.fontColor,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.fontFamily,
  });

  final String text;
  final double fontSize;
  final Color? fontColor;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? fontFamily;
}

/// A paragraph in a slide text frame.
class SlideParagraph {
  const SlideParagraph({
    required this.spans,
    this.alignment = TextAlign.left,
    this.isBullet = false,
    this.bulletChar,
    this.spaceBefore = 0.0,
    this.spaceAfter = 0.0,
  });

  final List<SlideTextSpan> spans;
  final TextAlign alignment;
  final bool isBullet;
  final String? bulletChar;
  final double spaceBefore;
  final double spaceAfter;

  String get plainText => spans.map((s) => s.text).join();
}

/// Base class for all visual slide elements.
abstract class SlideElement {
  const SlideElement({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0.0,
  });

  /// Relative coordinates (0.0 to 1.0) normalized to the slide canvas.
  final double x;
  final double y;
  final double width;
  final double height;

  /// Rotation in degrees clockwise.
  final double rotation;
}

/// A shape or text box on the slide canvas.
class SlideShapeElement extends SlideElement {
  const SlideShapeElement({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotation = 0.0,
    this.fillColor,
    this.borderColor,
    this.borderWidth = 0.0,
    this.borderRadius = 0.0,
    this.isCircle = false,
    this.paragraphs = const [],
    this.verticalAlignment = Alignment.topLeft,
    this.isPlaceholder = false,
  });

  final Color? fillColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final bool isCircle;
  final List<SlideParagraph> paragraphs;
  final Alignment verticalAlignment;
  final bool isPlaceholder;

  String get plainText => paragraphs.map((p) => p.plainText).join('\n').trim();
}

/// An embedded picture positioned on the slide canvas.
class SlidePictureElement extends SlideElement {
  const SlidePictureElement({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotation = 0.0,
    required this.imageBytes,
    this.borderRadius = 0.0,
  });

  final Uint8List imageBytes;
  final double borderRadius;
}

/// Cell in a presentation table.
class SlideTableCell {
  const SlideTableCell({
    required this.paragraphs,
    this.fillColor,
    this.borderColor,
  });

  final List<SlideParagraph> paragraphs;
  final Color? fillColor;
  final Color? borderColor;

  String get plainText => paragraphs.map((p) => p.plainText).join('\n').trim();
}

/// A table positioned on the slide canvas.
class SlideTableElement extends SlideElement {
  const SlideTableElement({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotation = 0.0,
    required this.rows,
    required this.colWidthRatios,
  });

  final List<List<SlideTableCell>> rows;
  final List<double> colWidthRatios;
}

/// Type of transition when moving between slides.
enum SlideTransitionType {
  fade,
  pushLeft,
  pushRight,
  pushUp,
  pushDown,
  wipe,
  zoom,
  none,
}

/// A complete presentation slide containing visual elements, extracted text, and media.
class PresentationSlide {
  const PresentationSlide({
    required this.slideNumber,
    required this.title,
    required this.bulletPoints,
    required this.images,
    this.elements = const [],
    this.backgroundColor,
    this.backgroundImage,
    this.transitionType = SlideTransitionType.fade,
    this.transitionDurationMs = 400,
  });

  final int slideNumber;
  final String title;
  final List<String> bulletPoints;
  final List<Uint8List> images;
  final List<SlideElement> elements;
  final Color? backgroundColor;
  final Uint8List? backgroundImage;
  final SlideTransitionType transitionType;
  final int transitionDurationMs;
}

/// An entire parsed presentation deck with canvas dimensions and slides.
class PresentationDeck {
  const PresentationDeck({
    required this.slides,
    this.slideWidthEmu = 12192000,
    this.slideHeightEmu = 6858000,
    this.themeColors = const {},
  });

  final List<PresentationSlide> slides;
  final int slideWidthEmu;
  final int slideHeightEmu;
  final Map<String, Color> themeColors;

  /// Aspect ratio of the presentation (e.g. 16:9 = ~1.778, 4:3 = ~1.333).
  double get aspectRatio =>
      slideHeightEmu > 0 ? (slideWidthEmu / slideHeightEmu) : (16 / 9);
}

/// Coordinate transformation context for nested group shapes (`p:grpSp`).
class _TransformContext {
  const _TransformContext({
    required this.offX,
    required this.offY,
    required this.extW,
    required this.extH,
    required this.chOffX,
    required this.chOffY,
    required this.chExtW,
    required this.chExtH,
  });

  final int offX;
  final int offY;
  final int extW;
  final int extH;
  final int chOffX;
  final int chOffY;
  final int chExtW;
  final int chExtH;

  int transformX(int x) {
    if (chExtW == 0) return offX + x;
    return (offX + ((x - chOffX) * extW / chExtW)).round();
  }

  int transformY(int y) {
    if (chExtH == 0) return offY + y;
    return (offY + ((y - chOffY) * extH / chExtH)).round();
  }

  int transformW(int w) {
    if (chExtW == 0) return w;
    return (w * extW / chExtW).round();
  }

  int transformH(int h) {
    if (chExtH == 0) return h;
    return (h * extH / chExtH).round();
  }
}

/// Comprehensive parser for PowerPoint (.pptx) presentations.
/// Extracts high-fidelity visual layout (geometry, shapes, styling, fonts, images)
/// and preserves backward-compatible text / bullets for outline and search.
class PresentationParser {
  const PresentationParser._();

  static const int _defaultSlideWidthEmu = 12192000; // 13.33 inches (16:9 widescreen)
  static const int _defaultSlideHeightEmu = 6858000; // 7.5 inches

  static Future<PresentationDeck> parse(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Read slide dimensions from presentation.xml
    int slideWidthEmu = _defaultSlideWidthEmu;
    int slideHeightEmu = _defaultSlideHeightEmu;

    final presFile = archive.findFile('ppt/presentation.xml');
    if (presFile != null) {
      try {
        final content = EncodingUtils.decodeDocumentBytes(presFile.content as List<int>);
        final doc = XmlDocument.parse(content);
        final sldSz = doc.findAllElements('p:sldSz').firstOrNull ??
            doc.findAllElements('sldSz').firstOrNull;
        if (sldSz != null) {
          final cx = int.tryParse(sldSz.getAttribute('cx') ?? '');
          final cy = int.tryParse(sldSz.getAttribute('cy') ?? '');
          if (cx != null && cx > 0) slideWidthEmu = cx;
          if (cy != null && cy > 0) slideHeightEmu = cy;
        }
      } catch (_) {
        // Fall back to 16:9 standard
      }
    }

    // 2. Read Theme colors from ppt/theme/theme1.xml
    final themeColors = <String, Color>{
      'dk1': const Color(0xFF000000),
      'lt1': const Color(0xFFFFFFFF),
      'dk2': const Color(0xFF1F497D),
      'lt2': const Color(0xFFEEECE1),
      'accent1': const Color(0xFF4F81BD),
      'accent2': const Color(0xFFC0504D),
      'accent3': const Color(0xFF9BBB59),
      'accent4': const Color(0xFF8064A2),
      'accent5': const Color(0xFF4BACC6),
      'accent6': const Color(0xFFF79646),
      'hlink': const Color(0xFF0000FF),
      'folHlink': const Color(0xFF800080),
    };

    final themeFile = archive.findFile('ppt/theme/theme1.xml') ??
        archive.files.where((f) => f.name.startsWith('ppt/theme/theme') && f.name.endsWith('.xml')).firstOrNull;
    if (themeFile != null) {
      try {
        final content = EncodingUtils.decodeDocumentBytes(themeFile.content as List<int>);
        final doc = XmlDocument.parse(content);
        final clrScheme = doc.findAllElements('a:clrScheme').firstOrNull ??
            doc.findAllElements('clrScheme').firstOrNull;
        if (clrScheme != null) {
          for (final child in clrScheme.children.whereType<XmlElement>()) {
            final key = child.name.local;
            final color = _parseRawColor(child, themeColors);
            if (color != null) {
              themeColors[key] = color;
            }
          }
        }
      } catch (_) {}
    }

    // 3. Read slide order from presentation.xml.rels and presentation.xml
    final presRelsFile = archive.findFile('ppt/_rels/presentation.xml.rels');
    final slidePathsMap = <String, String>{};
    if (presRelsFile != null) {
      try {
        final content = EncodingUtils.decodeDocumentBytes(presRelsFile.content as List<int>);
        final doc = XmlDocument.parse(content);
        for (final rel in doc.findAllElements('Relationship')) {
          final id = rel.getAttribute('Id');
          final target = rel.getAttribute('Target');
          if (id != null && target != null && target.contains('slide')) {
            final normalized = target.startsWith('/')
                ? target.substring(1)
                : target.startsWith('slides/')
                    ? 'ppt/$target'
                    : target.startsWith('ppt/')
                        ? target
                        : 'ppt/$target';
            slidePathsMap[id] = normalized;
          }
        }
      } catch (_) {}
    }

    final slidePaths = <String>[];
    if (presFile != null) {
      try {
        final content = EncodingUtils.decodeDocumentBytes(presFile.content as List<int>);
        final doc = XmlDocument.parse(content);
        for (final sldId in doc.findAllElements('p:sldId')) {
          final rId = sldId.getAttribute('r:id');
          if (rId != null && slidePathsMap.containsKey(rId)) {
            slidePaths.add(slidePathsMap[rId]!);
          }
        }
      } catch (_) {}
    }

    // Fallback: list slide files in archive
    if (slidePaths.isEmpty) {
      for (final file in archive.files) {
        if (file.name.startsWith('ppt/slides/slide') && file.name.endsWith('.xml') && !file.name.contains('_rels')) {
          slidePaths.add(file.name);
        }
      }
      slidePaths.sort();
    }

    final parsedSlides = <PresentationSlide>[];

    for (int i = 0; i < slidePaths.length; i++) {
      final path = slidePaths[i];
      final slideFile = archive.findFile(path);
      if (slideFile == null) continue;

      // Map slide-specific relationships (media, slide layouts)
      final relsPath = path.replaceFirst('ppt/slides/', 'ppt/slides/_rels/').replaceAll('.xml', '.xml.rels');
      final slideRelsFile = archive.findFile(relsPath);
      final mediaMap = <String, String>{};
      String? layoutPath;

      if (slideRelsFile != null) {
        try {
          final relsXml = EncodingUtils.decodeDocumentBytes(slideRelsFile.content as List<int>);
          final relsDoc = XmlDocument.parse(relsXml);
          for (final rel in relsDoc.findAllElements('Relationship')) {
            final id = rel.getAttribute('Id');
            final target = rel.getAttribute('Target');
            final type = rel.getAttribute('Type') ?? '';
            if (id == null || target == null) continue;

            if (type.contains('slideLayout') || target.contains('slideLayout')) {
              layoutPath = target.startsWith('../')
                  ? 'ppt/${target.substring(3)}'
                  : 'ppt/$target';
            } else if (target.contains('media/')) {
              final fileName = target.split('/').last;
              mediaMap[id] = 'ppt/media/$fileName';
            }
          }
        } catch (_) {}
      }

      // Parse slide XML
      final slideXml = EncodingUtils.decodeDocumentBytes(slideFile.content as List<int>);
      final slideDoc = XmlDocument.parse(slideXml);

      // Slide background
      Color? slideBackgroundColor;
      Uint8List? slideBackgroundImage;

      final bgElem = slideDoc.findAllElements('p:bg').firstOrNull ??
          slideDoc.findAllElements('bg').firstOrNull;
      if (bgElem != null) {
        slideBackgroundColor = _parseColorFromParent(bgElem, themeColors);
        final blip = bgElem.findAllElements('a:blip').firstOrNull ??
            bgElem.findAllElements('blip').firstOrNull;
        if (blip != null) {
          final rEmbed = blip.getAttribute('r:embed');
          if (rEmbed != null && mediaMap.containsKey(rEmbed)) {
            final bgFile = archive.findFile(mediaMap[rEmbed]!);
            if (bgFile != null) {
              slideBackgroundImage = Uint8List.fromList(bgFile.content as List<int>);
            }
          }
        }
      }

      // If no background in slide, check slideLayout background
      if (slideBackgroundColor == null && slideBackgroundImage == null && layoutPath != null) {
        final layoutFile = archive.findFile(layoutPath);
        if (layoutFile != null) {
          try {
            final layoutXml = EncodingUtils.decodeDocumentBytes(layoutFile.content as List<int>);
            final layoutDoc = XmlDocument.parse(layoutXml);
            final layoutBg = layoutDoc.findAllElements('p:bg').firstOrNull ??
                layoutDoc.findAllElements('bg').firstOrNull;
            if (layoutBg != null) {
              slideBackgroundColor = _parseColorFromParent(layoutBg, themeColors);
            }
          } catch (_) {}
        }
      }

      final visualElements = <SlideElement>[];
      final allImages = <Uint8List>[];

      // Parse Shape Tree (p:spTree)
      final spTree = slideDoc.findAllElements('p:spTree').firstOrNull ??
          slideDoc.findAllElements('spTree').firstOrNull;

      if (spTree != null) {
        _parseShapeContainer(
          container: spTree,
          archive: archive,
          mediaMap: mediaMap,
          themeColors: themeColors,
          slideWidthEmu: slideWidthEmu,
          slideHeightEmu: slideHeightEmu,
          elementsOut: visualElements,
          imagesOut: allImages,
        );
      }

      // Extract titles and bullets for backward compatibility and outline mode
      String title = '';
      final bulletPoints = <String>[];

      for (final sp in slideDoc.findAllElements('p:sp')) {
        final isTitle = sp.findAllElements('p:ph').any((ph) {
          final type = ph.getAttribute('type');
          return type == 'title' || type == 'ctrTitle';
        });

        final paragraphs = sp.findAllElements('a:p');
        for (final p in paragraphs) {
          final text = p.findAllElements('a:t').map((e) => e.innerText).join().trim();
          if (text.isEmpty) continue;

          if (isTitle && title.isEmpty) {
            title = text;
          } else {
            bulletPoints.add(text);
          }
        }
      }

      if (title.isEmpty && bulletPoints.isNotEmpty) {
        title = bulletPoints.removeAt(0);
      }
      if (title.isEmpty) {
        title = 'Slide ${i + 1}';
      }

      final transitionType = _parseTransition(slideDoc);
      final transitionDurationMs = _parseTransitionDuration(slideDoc);

      parsedSlides.add(
        PresentationSlide(
          slideNumber: i + 1,
          title: title,
          bulletPoints: bulletPoints,
          images: allImages,
          elements: visualElements,
          backgroundColor: slideBackgroundColor,
          backgroundImage: slideBackgroundImage,
          transitionType: transitionType,
          transitionDurationMs: transitionDurationMs,
        ),
      );
    }

    return PresentationDeck(
      slides: parsedSlides,
      slideWidthEmu: slideWidthEmu,
      slideHeightEmu: slideHeightEmu,
      themeColors: themeColors,
    );
  }

  /// Parses all children of a container (spTree or grpSp) in z-order.
  static void _parseShapeContainer({
    required XmlElement container,
    required Archive archive,
    required Map<String, String> mediaMap,
    required Map<String, Color> themeColors,
    required int slideWidthEmu,
    required int slideHeightEmu,
    required List<SlideElement> elementsOut,
    required List<Uint8List> imagesOut,
    _TransformContext? transformContext,
    int? fallbackIndex,
  }) {
    int autoFlowIndex = fallbackIndex ?? 0;

    for (final child in container.children.whereType<XmlElement>()) {
      final name = child.name.local;

      if (name == 'pic') {
        // ------------------ PICTURE ------------------
        final xfrm = _parseTransform(
          spPr: child.findAllElements('p:spPr').firstOrNull ?? child.findAllElements('spPr').firstOrNull,
          slideWidthEmu: slideWidthEmu,
          slideHeightEmu: slideHeightEmu,
          transformContext: transformContext,
        );

        final blip = child.findAllElements('a:blip').firstOrNull ?? child.findAllElements('blip').firstOrNull;
        Uint8List? imgBytes;
        if (blip != null) {
          final rEmbed = blip.getAttribute('r:embed');
          if (rEmbed != null && mediaMap.containsKey(rEmbed)) {
            final imgFile = archive.findFile(mediaMap[rEmbed]!);
            if (imgFile != null) {
              imgBytes = Uint8List.fromList(imgFile.content as List<int>);
              imagesOut.add(imgBytes);
            }
          }
        }

        if (imgBytes != null) {
          final rect = xfrm?.$1 ??
              _fallbackRectForIndex(autoFlowIndex++, isImage: true);
          final rot = xfrm?.$2 ?? 0.0;

          elementsOut.add(
            SlidePictureElement(
              x: rect.left,
              y: rect.top,
              width: rect.width,
              height: rect.height,
              rotation: rot,
              imageBytes: imgBytes,
            ),
          );
        }
      } else if (name == 'sp') {
        // ------------------ SHAPE / TEXT ------------------
        final spPr = child.findAllElements('p:spPr').firstOrNull ?? child.findAllElements('spPr').firstOrNull;
        final txBody = child.findAllElements('p:txBody').firstOrNull ?? child.findAllElements('txBody').firstOrNull;

        final isPlaceholder = child.findAllElements('p:ph').isNotEmpty || child.findAllElements('ph').isNotEmpty;
        final isTitle = child.findAllElements('p:ph').any((ph) {
          final type = ph.getAttribute('type');
          return type == 'title' || type == 'ctrTitle';
        });

        final xfrm = _parseTransform(
          spPr: spPr,
          slideWidthEmu: slideWidthEmu,
          slideHeightEmu: slideHeightEmu,
          transformContext: transformContext,
        );

        Color? fillColor;
        Color? borderColor;
        double borderWidth = 0.0;
        double borderRadius = 0.0;
        bool isCircle = false;

        if (spPr != null) {
          fillColor = _parseColorFromParent(spPr, themeColors);
          final ln = spPr.findAllElements('a:ln').firstOrNull ?? spPr.findAllElements('ln').firstOrNull;
          if (ln != null) {
            borderColor = _parseColorFromParent(ln, themeColors);
            final wAttr = ln.getAttribute('w');
            if (wAttr != null) {
              final emuW = int.tryParse(wAttr) ?? 0;
              borderWidth = (emuW / 12700.0).clamp(0.5, 12.0);
            } else if (borderColor != null) {
              borderWidth = 1.0;
            }
          }

          final prstGeom = spPr.findAllElements('a:prstGeom').firstOrNull ??
              spPr.findAllElements('prstGeom').firstOrNull;
          if (prstGeom != null) {
            final prst = prstGeom.getAttribute('prst');
            if (prst == 'roundRect') {
              borderRadius = 8.0;
            } else if (prst == 'ellipse') {
              isCircle = true;
            }
          }
        }

        // Parse paragraphs
        final paragraphs = <SlideParagraph>[];
        Alignment verticalAlignment = Alignment.topLeft;

        if (txBody != null) {
          final bodyPr = txBody.findAllElements('a:bodyPr').firstOrNull ??
              txBody.findAllElements('bodyPr').firstOrNull;
          if (bodyPr != null) {
            final anchor = bodyPr.getAttribute('anchor');
            if (anchor == 'ctr') {
              verticalAlignment = Alignment.centerLeft;
            } else if (anchor == 'b') {
              verticalAlignment = Alignment.bottomLeft;
            }
          }

          for (final p in txBody.findAllElements('a:p')) {
            final pPr = p.findAllElements('a:pPr').firstOrNull ?? p.findAllElements('pPr').firstOrNull;
            TextAlign alignment = TextAlign.left;
            bool isBullet = false;
            String? bulletChar;

            if (pPr != null) {
              final algn = pPr.getAttribute('algn');
              if (algn == 'ctr') {
                alignment = TextAlign.center;
              } else if (algn == 'r') {
                alignment = TextAlign.right;
              } else if (algn == 'just') {
                alignment = TextAlign.justify;
              }

              final buChar = pPr.findAllElements('a:buChar').firstOrNull ??
                  pPr.findAllElements('buChar').firstOrNull;
              if (buChar != null) {
                isBullet = true;
                bulletChar = buChar.getAttribute('char') ?? '•';
              } else if (pPr.findAllElements('a:buNone').isEmpty && pPr.getAttribute('lvl') != null) {
                isBullet = true;
                bulletChar = '•';
              }
            }

            final spans = <SlideTextSpan>[];
            for (final childNode in p.children) {
              if (childNode is! XmlElement) continue;
              final nodeName = childNode.name.local;

              if (nodeName == 'r') {
                final rPr = childNode.findAllElements('a:rPr').firstOrNull ??
                    childNode.findAllElements('rPr').firstOrNull;
                final t = childNode.findAllElements('a:t').firstOrNull ??
                    childNode.findAllElements('t').firstOrNull;
                final text = t?.innerText ?? '';
                if (text.isEmpty) continue;

                double fontSize = isTitle ? 28.0 : 16.0;
                bool bold = isTitle;
                bool italic = false;
                bool underline = false;
                Color? fontColor;
                String? fontFamily;

                if (rPr != null) {
                  final sz = rPr.getAttribute('sz');
                  if (sz != null) {
                    final szInt = int.tryParse(sz);
                    if (szInt != null && szInt > 0) {
                      fontSize = szInt / 100.0;
                    }
                  }

                  final b = rPr.getAttribute('b');
                  if (b != null) bold = b == '1' || b == 'true';

                  final i = rPr.getAttribute('i');
                  if (i != null) italic = i == '1' || i == 'true';

                  final u = rPr.getAttribute('u');
                  if (u != null && u != 'none') underline = true;

                  fontColor = _parseColorFromParent(rPr, themeColors);

                  final latin = rPr.findAllElements('a:latin').firstOrNull ??
                      rPr.findAllElements('latin').firstOrNull;
                  if (latin != null) {
                    fontFamily = latin.getAttribute('typeface');
                  }
                }

                spans.add(
                  SlideTextSpan(
                    text: text,
                    fontSize: fontSize,
                    fontColor: fontColor,
                    bold: bold,
                    italic: italic,
                    underline: underline,
                    fontFamily: fontFamily,
                  ),
                );
              } else if (nodeName == 'br') {
                spans.add(const SlideTextSpan(text: '\n'));
              }
            }

            if (spans.isNotEmpty) {
              paragraphs.add(
                SlideParagraph(
                  spans: spans,
                  alignment: alignment,
                  isBullet: isBullet,
                  bulletChar: bulletChar,
                ),
              );
            }
          }
        }

        // Only add if there is visual presence (text or background fill or border)
        final hasText = paragraphs.any((p) => p.plainText.trim().isNotEmpty);
        final hasVisualBox = fillColor != null || borderColor != null;

        if (hasText || hasVisualBox) {
          final rect = xfrm?.$1 ??
              (isTitle
                  ? const Rect.fromLTWH(0.08, 0.08, 0.84, 0.16)
                  : _fallbackRectForIndex(autoFlowIndex++));
          final rot = xfrm?.$2 ?? 0.0;

          elementsOut.add(
            SlideShapeElement(
              x: rect.left,
              y: rect.top,
              width: rect.width,
              height: rect.height,
              rotation: rot,
              fillColor: fillColor,
              borderColor: borderColor,
              borderWidth: borderWidth,
              borderRadius: borderRadius,
              isCircle: isCircle,
              paragraphs: paragraphs,
              verticalAlignment: verticalAlignment,
              isPlaceholder: isPlaceholder,
            ),
          );
        }
      } else if (name == 'graphicFrame') {
        // ------------------ TABLE / GRAPHIC ------------------
        final xfrm = _parseTransform(
          spPr: child.findAllElements('p:spPr').firstOrNull ?? child.findAllElements('spPr').firstOrNull ?? child,
          slideWidthEmu: slideWidthEmu,
          slideHeightEmu: slideHeightEmu,
          transformContext: transformContext,
        );

        final tbl = child.findAllElements('a:tbl').firstOrNull ?? child.findAllElements('tbl').firstOrNull;
        if (tbl != null) {
          final colWidthRatios = <double>[];
          final tblGrid = tbl.findAllElements('a:tblGrid').firstOrNull ?? tbl.findAllElements('tblGrid').firstOrNull;
          if (tblGrid != null) {
            for (final col in tblGrid.findAllElements('a:gridCol')) {
              final w = int.tryParse(col.getAttribute('w') ?? '') ?? 1;
              colWidthRatios.add(w.toDouble());
            }
          }

          final rows = <List<SlideTableCell>>[];
          for (final tr in tbl.findAllElements('a:tr')) {
            final rowCells = <SlideTableCell>[];
            for (final tc in tr.findAllElements('a:tc')) {
              final tcPr = tc.findAllElements('a:tcPr').firstOrNull ?? tc.findAllElements('tcPr').firstOrNull;
              Color? cellFill;
              if (tcPr != null) {
                cellFill = _parseColorFromParent(tcPr, themeColors);
              }

              final cellParagraphs = <SlideParagraph>[];
              for (final p in tc.findAllElements('a:p')) {
                final spans = <SlideTextSpan>[];
                for (final r in p.findAllElements('a:r')) {
                  final t = r.findAllElements('a:t').firstOrNull?.innerText ?? '';
                  if (t.isNotEmpty) {
                    spans.add(SlideTextSpan(text: t, fontSize: 13.0));
                  }
                }
                if (spans.isNotEmpty) {
                  cellParagraphs.add(SlideParagraph(spans: spans));
                }
              }
              rowCells.add(SlideTableCell(paragraphs: cellParagraphs, fillColor: cellFill));
            }
            if (rowCells.isNotEmpty) rows.add(rowCells);
          }

          if (rows.isNotEmpty) {
            final rect = xfrm?.$1 ?? _fallbackRectForIndex(autoFlowIndex++);
            elementsOut.add(
              SlideTableElement(
                x: rect.left,
                y: rect.top,
                width: rect.width,
                height: rect.height,
                rotation: xfrm?.$2 ?? 0.0,
                rows: rows,
                colWidthRatios: colWidthRatios,
              ),
            );
          }
        }
      } else if (name == 'grpSp') {
        // ------------------ GROUP SHAPES ------------------
        final grpSpPr = child.findAllElements('p:grpSpPr').firstOrNull ?? child.findAllElements('grpSpPr').firstOrNull;
        _TransformContext? groupContext;

        if (grpSpPr != null) {
          final xfrm = grpSpPr.findAllElements('a:xfrm').firstOrNull ?? grpSpPr.findAllElements('xfrm').firstOrNull;
          if (xfrm != null) {
            final off = xfrm.findAllElements('a:off').firstOrNull ?? xfrm.findAllElements('off').firstOrNull;
            final ext = xfrm.findAllElements('a:ext').firstOrNull ?? xfrm.findAllElements('ext').firstOrNull;
            final chOff = xfrm.findAllElements('a:chOff').firstOrNull ?? xfrm.findAllElements('chOff').firstOrNull;
            final chExt = xfrm.findAllElements('a:chExt').firstOrNull ?? xfrm.findAllElements('chExt').firstOrNull;

            if (off != null && ext != null && chOff != null && chExt != null) {
              int offX = int.tryParse(off.getAttribute('x') ?? '0') ?? 0;
              int offY = int.tryParse(off.getAttribute('y') ?? '0') ?? 0;
              int extW = int.tryParse(ext.getAttribute('cx') ?? '0') ?? 0;
              int extH = int.tryParse(ext.getAttribute('cy') ?? '0') ?? 0;
              final chOffX = int.tryParse(chOff.getAttribute('x') ?? '0') ?? 0;
              final chOffY = int.tryParse(chOff.getAttribute('y') ?? '0') ?? 0;
              final chExtW = int.tryParse(chExt.getAttribute('cx') ?? '0') ?? 0;
              final chExtH = int.tryParse(chExt.getAttribute('cy') ?? '0') ?? 0;

              if (transformContext != null) {
                offX = transformContext.transformX(offX);
                offY = transformContext.transformY(offY);
                extW = transformContext.transformW(extW);
                extH = transformContext.transformH(extH);
              }

              groupContext = _TransformContext(
                offX: offX,
                offY: offY,
                extW: extW,
                extH: extH,
                chOffX: chOffX,
                chOffY: chOffY,
                chExtW: chExtW,
                chExtH: chExtH,
              );
            }
          }
        }

        // Recurse into group children
        _parseShapeContainer(
          container: child,
          archive: archive,
          mediaMap: mediaMap,
          themeColors: themeColors,
          slideWidthEmu: slideWidthEmu,
          slideHeightEmu: slideHeightEmu,
          elementsOut: elementsOut,
          imagesOut: imagesOut,
          transformContext: groupContext ?? transformContext,
          fallbackIndex: autoFlowIndex,
        );
      }
    }
  }

  /// Parses 2D position, dimensions, and rotation from `<a:xfrm>`.
  static (Rect, double)? _parseTransform({
    required XmlElement? spPr,
    required int slideWidthEmu,
    required int slideHeightEmu,
    _TransformContext? transformContext,
  }) {
    if (spPr == null) return null;
    final xfrm = spPr.findAllElements('a:xfrm').firstOrNull ?? spPr.findAllElements('xfrm').firstOrNull;
    if (xfrm == null) return null;

    final off = xfrm.findAllElements('a:off').firstOrNull ?? xfrm.findAllElements('off').firstOrNull;
    final ext = xfrm.findAllElements('a:ext').firstOrNull ?? xfrm.findAllElements('ext').firstOrNull;
    if (off == null || ext == null) return null;

    int x = int.tryParse(off.getAttribute('x') ?? '') ?? 0;
    int y = int.tryParse(off.getAttribute('y') ?? '') ?? 0;
    int w = int.tryParse(ext.getAttribute('cx') ?? '') ?? 0;
    int h = int.tryParse(ext.getAttribute('cy') ?? '') ?? 0;

    if (w <= 0 || h <= 0) return null;

    if (transformContext != null) {
      x = transformContext.transformX(x);
      y = transformContext.transformY(y);
      w = transformContext.transformW(w);
      h = transformContext.transformH(h);
    }

    double rot = 0.0;
    final rotAttr = xfrm.getAttribute('rot');
    if (rotAttr != null) {
      final rotInt = int.tryParse(rotAttr);
      if (rotInt != null) {
        rot = rotInt / 60000.0; // 60,000ths of a degree
      }
    }

    final normX = (x / slideWidthEmu).clamp(-0.5, 2.0);
    final normY = (y / slideHeightEmu).clamp(-0.5, 2.0);
    final normW = (w / slideWidthEmu).clamp(0.01, 2.0);
    final normH = (h / slideHeightEmu).clamp(0.01, 2.0);

    return (Rect.fromLTWH(normX, normY, normW, normH), rot);
  }

  /// Fallback rectangle for shapes or images that lack explicit `<a:xfrm>`.
  static Rect _fallbackRectForIndex(int index, {bool isImage = false}) {
    final top = 0.28 + (index * 0.14);
    if (isImage) {
      return Rect.fromLTWH(0.55, top.clamp(0.1, 0.7), 0.38, 0.25);
    }
    return Rect.fromLTWH(0.08, top.clamp(0.1, 0.85), 0.84, 0.12);
  }

  /// Extracts color from a parent element (`solidFill`, `gradFill`, etc.).
  static Color? _parseColorFromParent(XmlElement parent, Map<String, Color> themeColors) {
    final solidFill = parent.findAllElements('a:solidFill').firstOrNull ??
        parent.findAllElements('solidFill').firstOrNull;
    if (solidFill != null) {
      return _parseRawColor(solidFill, themeColors);
    }

    final gradFill = parent.findAllElements('a:gradFill').firstOrNull ??
        parent.findAllElements('gradFill').firstOrNull;
    if (gradFill != null) {
      final firstStop = gradFill.findAllElements('a:gs').firstOrNull ??
          gradFill.findAllElements('gs').firstOrNull;
      if (firstStop != null) {
        return _parseRawColor(firstStop, themeColors);
      }
    }

    return null;
  }

  /// Resolves raw color elements (`srgbClr`, `schemeClr`, `sysClr`, `prstClr`).
  static Color? _parseRawColor(XmlElement container, Map<String, Color> themeColors) {
    // 1. Exact RGB Hex
    final srgb = container.findAllElements('a:srgbClr').firstOrNull ??
        container.findAllElements('srgbClr').firstOrNull;
    if (srgb != null) {
      final val = srgb.getAttribute('val');
      if (val != null) {
        final hex = int.tryParse(val, radix: 16);
        if (hex != null) {
          return _applyModifiers(Color(0xFF000000 | hex), srgb);
        }
      }
    }

    // 2. Scheme color lookup
    final scheme = container.findAllElements('a:schemeClr').firstOrNull ??
        container.findAllElements('schemeClr').firstOrNull;
    if (scheme != null) {
      final val = scheme.getAttribute('val');
      if (val != null) {
        Color? base = themeColors[val];
        if (base == null) {
          if (val == 'tx1') base = themeColors['dk1'];
          if (val == 'tx2') base = themeColors['dk2'];
          if (val == 'bg1') base = themeColors['lt1'];
          if (val == 'bg2') base = themeColors['lt2'];
        }
        if (base != null) {
          return _applyModifiers(base, scheme);
        }
      }
    }

    // 3. System color
    final sys = container.findAllElements('a:sysClr').firstOrNull ??
        container.findAllElements('sysClr').firstOrNull;
    if (sys != null) {
      final lastClr = sys.getAttribute('lastClr');
      if (lastClr != null) {
        final hex = int.tryParse(lastClr, radix: 16);
        if (hex != null) {
          return Color(0xFF000000 | hex);
        }
      }
    }

    // 4. Preset color
    final prst = container.findAllElements('a:prstClr').firstOrNull ??
        container.findAllElements('prstClr').firstOrNull;
    if (prst != null) {
      final val = prst.getAttribute('val')?.toLowerCase();
      return _presetColors[val];
    }

    return null;
  }

  /// Applies alpha, luminance modifiers, and tints.
  static Color _applyModifiers(Color base, XmlElement colorElem) {
    double alpha = base.a;
    final alphaElem = colorElem.findAllElements('a:alpha').firstOrNull ??
        colorElem.findAllElements('alpha').firstOrNull;
    if (alphaElem != null) {
      final val = int.tryParse(alphaElem.getAttribute('val') ?? '');
      if (val != null) alpha = (val / 100000.0).clamp(0.0, 1.0);
    }

    final lumMod = int.tryParse(colorElem.findAllElements('a:lumMod').firstOrNull?.getAttribute('val') ??
        colorElem.findAllElements('lumMod').firstOrNull?.getAttribute('val') ?? '');
    final lumOff = int.tryParse(colorElem.findAllElements('a:lumOff').firstOrNull?.getAttribute('val') ??
        colorElem.findAllElements('lumOff').firstOrNull?.getAttribute('val') ?? '');

    if (lumMod != null || lumOff != null) {
      final hsl = HSLColor.fromColor(base);
      double l = hsl.lightness;
      if (lumMod != null) l = l * (lumMod / 100000.0);
      if (lumOff != null) l = l + (lumOff / 100000.0);
      return hsl.withLightness(l.clamp(0.0, 1.0)).toColor().withValues(alpha: alpha);
    }

    return base.withValues(alpha: alpha);
  }

  /// Extracts slide-to-slide transition from `<p:transition>`.
  static SlideTransitionType _parseTransition(XmlDocument slideDoc) {
    final transitionElem = slideDoc.findAllElements('p:transition').firstOrNull ??
        slideDoc.findAllElements('transition').firstOrNull;
    if (transitionElem == null) return SlideTransitionType.none;

    if (transitionElem.findAllElements('p:fade').isNotEmpty ||
        transitionElem.findAllElements('fade').isNotEmpty) {
      return SlideTransitionType.fade;
    }
    final push = transitionElem.findAllElements('p:push').firstOrNull ??
        transitionElem.findAllElements('push').firstOrNull;
    if (push != null) {
      final dir = push.getAttribute('dir');
      if (dir == 'l') return SlideTransitionType.pushLeft;
      if (dir == 'r') return SlideTransitionType.pushRight;
      if (dir == 'u') return SlideTransitionType.pushUp;
      if (dir == 'd') return SlideTransitionType.pushDown;
      return SlideTransitionType.pushLeft;
    }
    if (transitionElem.findAllElements('p:wipe').isNotEmpty ||
        transitionElem.findAllElements('wipe').isNotEmpty) {
      return SlideTransitionType.wipe;
    }
    if (transitionElem.findAllElements('p:zoom').isNotEmpty ||
        transitionElem.findAllElements('zoom').isNotEmpty) {
      return SlideTransitionType.zoom;
    }
    return SlideTransitionType.fade;
  }

  /// Parses transition duration in milliseconds.
  static int _parseTransitionDuration(XmlDocument slideDoc) {
    final transitionElem = slideDoc.findAllElements('p:transition').firstOrNull ??
        slideDoc.findAllElements('transition').firstOrNull;
    if (transitionElem == null) return 400;
    final dur = transitionElem.getAttribute('dur');
    if (dur != null) {
      final durInt = int.tryParse(dur);
      if (durInt != null && durInt > 0) return durInt.clamp(150, 2000);
    }
    final spd = transitionElem.getAttribute('spd');
    if (spd == 'slow') return 600;
    if (spd == 'fast') return 250;
    return 400;
  }

  static const Map<String, Color> _presetColors = {
    'white': Color(0xFFFFFFFF),
    'black': Color(0xFF000000),
    'red': Color(0xFFFF0000),
    'green': Color(0xFF008000),
    'blue': Color(0xFF0000FF),
    'yellow': Color(0xFFFFFF00),
    'gray': Color(0xFF808080),
    'grey': Color(0xFF808080),
    'orange': Color(0xFFFFA500),
    'purple': Color(0xFF800080),
  };
}
