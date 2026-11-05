import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagelit/l10n/app_localizations.dart';
import 'package:pagelit/screens/word_viewer_screen.dart';
import 'package:pagelit/services/word_parser.dart';

Uint8List createSampleDocx() {
  final archive = Archive();

  const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rIdLink1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://pagelit.app" TargetMode="External"/>
</Relationships>''';

  const docXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    <!-- Centered heading with background shading -->
    <w:p>
      <w:pPr>
        <w:pStyle w:val="Heading1"/>
        <w:jc w:val="center"/>
        <w:shd w:fill="EBF3FB"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:sz w:val="48"/>
          <w:color w:val="0055AA"/>
        </w:rPr>
        <w:t>Project Specification</w:t>
      </w:r>
    </w:p>

    <!-- Paragraph with strikethrough, highlight, and line break -->
    <w:p>
      <w:pPr>
        <w:jc w:val="both"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:strike/>
        </w:rPr>
        <w:t>Old requirement.</w:t>
      </w:r>
      <w:r>
        <w:br/>
      </w:r>
      <w:r>
        <w:rPr>
          <w:highlight w:val="yellow"/>
          <w:b/>
        </w:rPr>
        <w:t>New requirement: High performance.</w:t>
      </w:r>
    </w:p>

    <!-- Paragraph with nested hyperlink -->
    <w:p>
      <w:r>
        <w:t>Visit our website: </w:t>
      </w:r>
      <w:hyperlink r:id="rIdLink1">
        <w:r>
          <w:rPr>
            <w:color w:val="0000FF"/>
            <w:u w:val="single"/>
          </w:rPr>
          <w:t>Pagelit Official Site</w:t>
        </w:r>
      </w:hyperlink>
    </w:p>
  </w:body>
</w:document>''';

  archive.addFile(ArchiveFile('word/_rels/document.xml.rels', relsXml.length, utf8.encode(relsXml)));
  archive.addFile(ArchiveFile('word/document.xml', docXml.length, utf8.encode(docXml)));

  final zipBytes = ZipEncoder().encode(archive);
  return Uint8List.fromList(zipBytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File tempDocxFile;

  setUp(() async {
    tempDocxFile = File('${Directory.systemTemp.path}/test_styling.docx');
    await tempDocxFile.writeAsBytes(createSampleDocx());
  });

  tearDown(() async {
    try {
      if (await tempDocxFile.exists()) {
        await tempDocxFile.delete();
      }
    } catch (_) {}
  });

  test('WordParser parses alignments, hyperlinks, font sizes, strikethrough, highlights, and line breaks', () async {
    final zipBytes = createSampleDocx();
    final doc = await WordParser.parse(zipBytes);

    expect(doc.blocks.length, 3);

    // Block 0: Heading 1, centered, font size 24pt (48 / 2), background shading EBF3FB
    final h1 = doc.blocks[0] as WordParagraph;
    expect(h1.headingLevel, 1);
    expect(h1.alignment, TextAlign.center);
    expect(h1.backgroundColorHex, 'EBF3FB');
    expect(h1.spans.first.fontSize, 24.0);
    expect(h1.spans.first.colorHex, '0055AA');

    // Block 1: Justified paragraph, strikethrough, line break, yellow highlight
    final p2 = doc.blocks[1] as WordParagraph;
    expect(p2.alignment, TextAlign.justify);
    expect(p2.spans[0].text, 'Old requirement.');
    expect(p2.spans[0].strikethrough, true);
    expect(p2.spans[1].text, '\n');
    expect(p2.spans[2].text, 'New requirement: High performance.');
    expect(p2.spans[2].bold, true);
    expect(p2.spans[2].highlightHex, 'yellow');

    // Block 2: Hyperlink extracted with URL target
    final p3 = doc.blocks[2] as WordParagraph;
    expect(p3.fullText, contains('Visit our website: Pagelit Official Site'));
    final linkSpan = p3.spans.firstWhere((s) => s.text == 'Pagelit Official Site');
    expect(linkSpan.linkUrl, 'https://pagelit.app');
    expect(linkSpan.underline, true);
    expect(linkSpan.colorHex, '0000FF');
  });

  testWidgets('WordViewerScreen renders styled headings, highlights, and hyperlinks', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: WordViewerScreen(
            filePath: tempDocxFile.path,
            title: 'test_styling.docx',
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));
    });

    await tester.pump();

    expect(find.text('Project Specification'), findsOneWidget);
    expect(find.byType(SelectableText), findsWidgets);
  });
}
