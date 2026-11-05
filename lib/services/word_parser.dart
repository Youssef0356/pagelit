import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart' show TextAlign;
import 'package:xml/xml.dart';
import 'encoding_utils.dart';

sealed class WordBlock {
  const WordBlock();
}

class WordParagraph extends WordBlock {
  const WordParagraph({
    required this.spans,
    this.headingLevel,
    this.isBullet = false,
    this.alignment,
    this.indent,
    this.backgroundColorHex,
  });

  final List<WordSpan> spans;
  final int? headingLevel;
  final bool isBullet;
  final TextAlign? alignment;
  final double? indent;
  final String? backgroundColorHex;

  String get fullText => spans.map((s) => s.text).join();
}

class WordSpan {
  const WordSpan({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.fontSize,
    this.colorHex,
    this.highlightHex,
    this.linkUrl,
    this.fontFamily,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final double? fontSize;
  final String? colorHex;
  final String? highlightHex;
  final String? linkUrl;
  final String? fontFamily;
}

class WordTableCell {
  const WordTableCell({
    required this.text,
    this.isHeader = false,
    this.backgroundColorHex,
    this.alignment,
  });

  final String text;
  final bool isHeader;
  final String? backgroundColorHex;
  final TextAlign? alignment;
}

class WordTableBlock extends WordBlock {
  const WordTableBlock({
    required this.rows,
    this.richCells,
  });

  final List<List<String>> rows;
  final List<List<WordTableCell>>? richCells;
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
    final linkMap = <String, String>{};

    if (relsFile != null) {
      final relsContent = EncodingUtils.decodeDocumentBytes(relsFile.content as List<int>);
      final relsDoc = XmlDocument.parse(relsContent);
      for (final rel in relsDoc.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        final type = rel.getAttribute('Type') ?? '';
        if (id != null && target != null) {
          if (type.contains('hyperlink') || rel.getAttribute('TargetMode')?.toLowerCase() == 'external') {
            linkMap[id] = target;
          }
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

    final docXml = EncodingUtils.decodeDocumentBytes(docFile.content as List<int>);
    final doc = XmlDocument.parse(docXml);
    final body = doc.findAllElements('w:body').firstOrNull;
    if (body == null) return const WordDocument(blocks: []);

    final blocks = <WordBlock>[];

    for (final child in body.children) {
      if (child is! XmlElement) continue;

      if (child.name.local == 'p') {
        final pPr = child.findElements('w:pPr').firstOrNull ?? child.findElements('pPr').firstOrNull;
        int? headingLevel;
        bool isBullet = false;
        TextAlign? alignment;
        double? indent;
        String? backgroundColorHex;

        if (pPr != null) {
          final pStyle = (pPr.findElements('w:pStyle').firstOrNull?.getAttribute('w:val') ??
                  pPr.findElements('pStyle').firstOrNull?.getAttribute('val'))
              ?.toLowerCase();
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

          final jc = pPr.findElements('w:jc').firstOrNull ?? pPr.findElements('jc').firstOrNull;
          if (jc != null) {
            final val = (jc.getAttribute('w:val') ?? jc.getAttribute('val'))?.toLowerCase();
            alignment = switch (val) {
              'center' => TextAlign.center,
              'right' || 'end' => TextAlign.right,
              'both' || 'justify' || 'distribute' => TextAlign.justify,
              'left' || 'start' => TextAlign.left,
              _ => null,
            };
          }

          final shd = pPr.findElements('w:shd').firstOrNull ?? pPr.findElements('shd').firstOrNull;
          if (shd != null) {
            final fill = shd.getAttribute('w:fill') ?? shd.getAttribute('fill');
            if (fill != null && fill.toLowerCase() != 'auto' && fill.toLowerCase() != 'none') {
              backgroundColorHex = fill;
            }
          }

          final ind = pPr.findElements('w:ind').firstOrNull ?? pPr.findElements('ind').firstOrNull;
          if (ind != null) {
            final leftStr = ind.getAttribute('w:left') ?? ind.getAttribute('left');
            if (leftStr != null) {
              final dxa = double.tryParse(leftStr);
              if (dxa != null) {
                indent = dxa / 20.0;
              }
            }
          }

          final numPr = pPr.findElements('w:numPr').firstOrNull ?? pPr.findElements('numPr').firstOrNull;
          if (numPr != null) {
            isBullet = true;
          }
        }

        // Extract any embedded images in the paragraph
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

        void parseRun(XmlElement r, String? linkUrl) {
          final rPr = r.findElements('w:rPr').firstOrNull ?? r.findElements('rPr').firstOrNull;

          bool bold = false;
          bool italic = false;
          bool underline = false;
          bool strikethrough = false;
          String? colorVal;
          String? highlightVal;
          double? fontSize;
          String? fontFamily;

          if (rPr != null) {
            final b = rPr.findElements('w:b').firstOrNull ?? rPr.findElements('b').firstOrNull;
            if (b != null) {
              final val = (b.getAttribute('w:val') ?? b.getAttribute('val'))?.toLowerCase();
              bold = val == null || val == '1' || val == 'true';
            }

            final i = rPr.findElements('w:i').firstOrNull ?? rPr.findElements('i').firstOrNull;
            if (i != null) {
              final val = (i.getAttribute('w:val') ?? i.getAttribute('val'))?.toLowerCase();
              italic = val == null || val == '1' || val == 'true';
            }

            final u = rPr.findElements('w:u').firstOrNull ?? rPr.findElements('u').firstOrNull;
            if (u != null) {
              final val = (u.getAttribute('w:val') ?? u.getAttribute('val'))?.toLowerCase();
              underline = val == null || (val != 'none' && val != '0' && val != 'false');
            }

            final strike = rPr.findElements('w:strike').firstOrNull ??
                rPr.findElements('strike').firstOrNull ??
                rPr.findElements('w:dstrike').firstOrNull ??
                rPr.findElements('dstrike').firstOrNull;
            if (strike != null) {
              final val = (strike.getAttribute('w:val') ?? strike.getAttribute('val'))?.toLowerCase();
              strikethrough = val == null || val == '1' || val == 'true';
            }

            final color = rPr.findElements('w:color').firstOrNull ?? rPr.findElements('color').firstOrNull;
            if (color != null) {
              final val = color.getAttribute('w:val') ?? color.getAttribute('val');
              if (val != null && val.toLowerCase() != 'auto') {
                colorVal = val;
              }
            }

            final highlight = rPr.findElements('w:highlight').firstOrNull ?? rPr.findElements('highlight').firstOrNull;
            if (highlight != null) {
              final val = highlight.getAttribute('w:val') ?? highlight.getAttribute('val');
              if (val != null && val.toLowerCase() != 'none') {
                highlightVal = val;
              }
            }

            final sz = rPr.findElements('w:sz').firstOrNull ?? rPr.findElements('sz').firstOrNull;
            if (sz != null) {
              final val = sz.getAttribute('w:val') ?? sz.getAttribute('val');
              if (val != null) {
                final halfPoints = double.tryParse(val);
                if (halfPoints != null) {
                  fontSize = halfPoints / 2.0;
                }
              }
            }

            final rFonts = rPr.findElements('w:rFonts').firstOrNull ?? rPr.findElements('rFonts').firstOrNull;
            if (rFonts != null) {
              fontFamily = rFonts.getAttribute('w:ascii') ??
                  rFonts.getAttribute('w:hAnsi') ??
                  rFonts.getAttribute('ascii') ??
                  rFonts.getAttribute('hAnsi');
            }
          }

          for (final rChild in r.children) {
            if (rChild is! XmlElement) continue;
            final childName = rChild.name.local;
            if (childName == 't') {
              final text = rChild.innerText;
              if (text.isNotEmpty) {
                spans.add(WordSpan(
                  text: text,
                  bold: bold,
                  italic: italic,
                  underline: underline,
                  strikethrough: strikethrough,
                  fontSize: fontSize,
                  colorHex: colorVal,
                  highlightHex: highlightVal,
                  linkUrl: linkUrl,
                  fontFamily: fontFamily,
                ));
              }
            } else if (childName == 'br' || childName == 'cr') {
              spans.add(const WordSpan(text: '\n'));
            } else if (childName == 'tab') {
              spans.add(const WordSpan(text: '\t'));
            }
          }
        }

        void parseRunContainer(XmlElement container, String? linkUrl) {
          for (final node in container.children) {
            if (node is! XmlElement) continue;
            final name = node.name.local;
            if (name == 'hyperlink') {
              final rId = node.getAttribute('r:id') ?? node.getAttribute('id');
              final target = rId != null ? linkMap[rId] : null;
              parseRunContainer(node, target ?? linkUrl);
            } else if (name == 'r') {
              parseRun(node, linkUrl);
            } else if (name != 'pPr') {
              parseRunContainer(node, linkUrl);
            }
          }
        }

        parseRunContainer(child, null);

        if (spans.isNotEmpty) {
          blocks.add(
            WordParagraph(
              spans: spans,
              headingLevel: headingLevel,
              isBullet: isBullet,
              alignment: alignment,
              indent: indent,
              backgroundColorHex: backgroundColorHex,
            ),
          );
        }
      } else if (child.name.local == 'tbl') {
        final tableRows = <List<String>>[];
        final richRows = <List<WordTableCell>>[];

        for (final tr in child.findElements('w:tr')) {
          final rowCells = <String>[];
          final richCells = <WordTableCell>[];
          final trPr = tr.findElements('w:trPr').firstOrNull;
          final isTblHeader = trPr?.findElements('w:tblHeader').isNotEmpty ?? false;

          for (final tc in tr.findElements('w:tc')) {
            final cellText = tc.findAllElements('w:t').map((e) => e.innerText).join(' ').trim();
            rowCells.add(cellText);

            final tcPr = tc.findElements('w:tcPr').firstOrNull;
            String? cellBgHex;
            if (tcPr != null) {
              final shd = tcPr.findElements('w:shd').firstOrNull ?? tcPr.findElements('shd').firstOrNull;
              if (shd != null) {
                final fill = shd.getAttribute('w:fill') ?? shd.getAttribute('fill');
                if (fill != null && fill.toLowerCase() != 'auto' && fill.toLowerCase() != 'none') {
                  cellBgHex = fill;
                }
              }
            }

            TextAlign? cellAlignment;
            final p = tc.findElements('w:p').firstOrNull;
            if (p != null) {
              final pPr = p.findElements('w:pPr').firstOrNull;
              if (pPr != null) {
                final jc = pPr.findElements('w:jc').firstOrNull ?? pPr.findElements('jc').firstOrNull;
                if (jc != null) {
                  final val = (jc.getAttribute('w:val') ?? jc.getAttribute('val'))?.toLowerCase();
                  cellAlignment = switch (val) {
                    'center' => TextAlign.center,
                    'right' || 'end' => TextAlign.right,
                    'both' || 'justify' || 'distribute' => TextAlign.justify,
                    'left' || 'start' => TextAlign.left,
                    _ => null,
                  };
                }
              }
            }

            richCells.add(WordTableCell(
              text: cellText,
              isHeader: isTblHeader,
              backgroundColorHex: cellBgHex,
              alignment: cellAlignment,
            ));
          }
          if (rowCells.isNotEmpty) {
            tableRows.add(rowCells);
            richRows.add(richCells);
          }
        }
        if (tableRows.isNotEmpty) {
          blocks.add(WordTableBlock(rows: tableRows, richCells: richRows));
        }
      }
    }

    return WordDocument(blocks: blocks);
  }
}
