import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class PresentationSlide {
  const PresentationSlide({
    required this.slideNumber,
    required this.title,
    required this.bulletPoints,
    required this.images,
  });

  final int slideNumber;
  final String title;
  final List<String> bulletPoints;
  final List<Uint8List> images;
}

class PresentationDeck {
  const PresentationDeck({required this.slides});

  final List<PresentationSlide> slides;
}

class PresentationParser {
  const PresentationParser._();

  static Future<PresentationDeck> parse(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Read slide order from presentation.xml.rels and presentation.xml
    final presRelsFile = archive.findFile('ppt/_rels/presentation.xml.rels');
    final slidePathsMap = <String, String>{};
    if (presRelsFile != null) {
      final content = String.fromCharCodes(presRelsFile.content as List<int>);
      final doc = XmlDocument.parse(content);
      for (final rel in doc.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id != null && target != null && target.contains('slide')) {
          final normalized = target.startsWith('/')
              ? target.substring(1)
              : target.startsWith('slides/')
                  ? 'ppt/$target'
                  : 'ppt/$target';
          slidePathsMap[id] = normalized;
        }
      }
    }

    final slidePaths = <String>[];
    final presFile = archive.findFile('ppt/presentation.xml');
    if (presFile != null) {
      final content = String.fromCharCodes(presFile.content as List<int>);
      final doc = XmlDocument.parse(content);
      for (final sldId in doc.findAllElements('p:sldId')) {
        final rId = sldId.getAttribute('r:id');
        if (rId != null && slidePathsMap.containsKey(rId)) {
          slidePaths.add(slidePathsMap[rId]!);
        }
      }
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

      // Map slide-specific media relationships
      final relsPath = path.replaceFirst('ppt/slides/', 'ppt/slides/_rels/').replaceAll('.xml', '.xml.rels');
      final slideRelsFile = archive.findFile(relsPath);
      final mediaMap = <String, String>{};
      if (slideRelsFile != null) {
        final relsXml = String.fromCharCodes(slideRelsFile.content as List<int>);
        final relsDoc = XmlDocument.parse(relsXml);
        for (final rel in relsDoc.findAllElements('Relationship')) {
          final id = rel.getAttribute('Id');
          final target = rel.getAttribute('Target');
          if (id != null && target != null && target.contains('media/')) {
            final fileName = target.split('/').last;
            mediaMap[id] = 'ppt/media/$fileName';
          }
        }
      }

      final slideXml = String.fromCharCodes(slideFile.content as List<int>);
      final slideDoc = XmlDocument.parse(slideXml);

      // Extract images
      final images = <Uint8List>[];
      for (final blip in slideDoc.findAllElements('a:blip')) {
        final rEmbed = blip.getAttribute('r:embed');
        if (rEmbed != null && mediaMap.containsKey(rEmbed)) {
          final imgFile = archive.findFile(mediaMap[rEmbed]!);
          if (imgFile != null) {
            images.add(Uint8List.fromList(imgFile.content as List<int>));
          }
        }
      }

      // Extract text
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

      parsedSlides.add(
        PresentationSlide(
          slideNumber: i + 1,
          title: title,
          bulletPoints: bulletPoints,
          images: images,
        ),
      );
    }

    return PresentationDeck(slides: parsedSlides);
  }
}
