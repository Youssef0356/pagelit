import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

sealed class WordBlock {
  const WordBlock();
}

class WordParagraph extends WordBlock {
  const WordParagraph({
    required this.spans,
    this.headingLevel,
    this.isBullet = false,
  });

  final List<WordSpan> spans;
  final int? headingLevel;
  final bool isBullet;

  String get fullText => spans.map((s) => s.text).join();
}

class WordSpan {
  const WordSpan({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.colorHex,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? colorHex;
}

class WordTableBlock extends WordBlock {
  const WordTableBlock({required this.rows});

  final List<List<String>> rows;
}

class WordImageBlock extends WordBlock {
  const WordImageBlock({required this.bytes, this.altText});

  final Uint8List bytes;
  final String? altText;
}

class WordDocument {
  const WordDocument({required this.blocks});

  final List<WordBlock> blocks;
}

class WordParser {
  const WordParser._();

  static Future<WordDocument> parse(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    final relsFile = archive.findFile('word/_rels/document.xml.rels');
    final mediaMap = <String, String>{};
    if (relsFile != null) {
      final relsContent = String.fromCharCodes(relsFile.content as List<int>);
      final relsDoc = XmlDocument.parse(relsContent);
      for (final rel in relsDoc.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id != null && target != null) {
          final normalized = target.startsWith('/')
              ? target.substring(1)
              : target.startsWith('media/')
                  ? 'word/$target'
                  : target;
          mediaMap[id] = normalized;
        }
      }
    }

    final docFile = archive.findFile('word/document.xml');
    if (docFile == null) {
      return const WordDocument(blocks: []);
    }

    final docXml = String.fromCharCodes(docFile.content as List<int>);
    final doc = XmlDocument.parse(docXml);
    final body = doc.findAllElements('w:body').firstOrNull;
    if (body == null) return const WordDocument(blocks: []);

    final blocks = <WordBlock>[];

    for (final child in body.children) {
      if (child is! XmlElement) continue;

      if (child.name.local == 'p') {
        final pPr = child.findElements('w:pPr').firstOrNull;
        int? headingLevel;
        bool isBullet = false;

        if (pPr != null) {
          final pStyle = pPr.findElements('w:pStyle').firstOrNull?.getAttribute('w:val')?.toLowerCase();
          if (pStyle != null) {
            if (pStyle.contains('heading1') || pStyle == '1') {
              headingLevel = 1;
            } else if (pStyle.contains('heading2') || pStyle == '2') {
              headingLevel = 2;
            } else if (pStyle.contains('heading3') || pStyle == '3') {
              headingLevel = 3;
            } else if (pStyle.contains('title')) {
              headingLevel = 1;
            } else if (pStyle.contains('subtitle')) {
              headingLevel = 2;
            }
          }
          final numPr = pPr.findElements('w:numPr').firstOrNull;
          if (numPr != null) {
            isBullet = true;
          }
        }

        for (final blip in child.findAllElements('a:blip')) {
          final embedId = blip.getAttribute('r:embed');
          if (embedId != null && mediaMap.containsKey(embedId)) {
            final mediaPath = mediaMap[embedId]!;
            final imgFile = archive.findFile(mediaPath);
            if (imgFile != null) {
              blocks.add(WordImageBlock(bytes: Uint8List.fromList(imgFile.content as List<int>)));
            }
          }
        }

        final spans = <WordSpan>[];
        for (final r in child.findElements('w:r')) {
          final rPr = r.findElements('w:rPr').firstOrNull;
          final bold = rPr?.findElements('w:b').firstOrNull != null;
          final italic = rPr?.findElements('w:i').firstOrNull != null;
          final underline = rPr?.findElements('w:u').firstOrNull != null;
          final colorVal = rPr?.findElements('w:color').firstOrNull?.getAttribute('w:val');

          final t = r.findElements('w:t').map((e) => e.innerText).join();
          if (t.isNotEmpty) {
            spans.add(
              WordSpan(
                text: t,
                bold: bold,
                italic: italic,
                underline: underline,
                colorHex: colorVal,
              ),
            );
          }
        }

        if (spans.isNotEmpty) {
          blocks.add(
            WordParagraph(
              spans: spans,
              headingLevel: headingLevel,
              isBullet: isBullet,
            ),
          );
        }
      } else if (child.name.local == 'tbl') {
        final tableRows = <List<String>>[];
        for (final tr in child.findElements('w:tr')) {
          final rowCells = <String>[];
          for (final tc in tr.findElements('w:tc')) {
            final cellText = tc.findAllElements('w:t').map((e) => e.innerText).join(' ');
            rowCells.add(cellText.trim());
          }
          if (rowCells.isNotEmpty) tableRows.add(rowCells);
        }
        if (tableRows.isNotEmpty) {
          blocks.add(WordTableBlock(rows: tableRows));
        }
      }
    }

    return WordDocument(blocks: blocks);
  }
}
