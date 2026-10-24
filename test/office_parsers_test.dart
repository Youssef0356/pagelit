import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagelit/services/excel_parser.dart';
import 'package:pagelit/services/presentation_parser.dart';
import 'package:pagelit/services/word_parser.dart';

void main() {
  test('ExcelParser parses sheets, rows, and cells', () async {
    final archive = Archive();

    const workbookXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheets>
    <sheet name="Sales" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';

    const sheetXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>0</v></c>
      <c r="B1"><v>100</v></c>
    </row>
  </sheetData>
</worksheet>''';

    const sharedStringsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <si><t>Revenue</t></si>
</sst>''';

    archive.addFile(ArchiveFile('xl/workbook.xml', workbookXml.length, utf8.encode(workbookXml)));
    archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetXml.length, utf8.encode(sheetXml)));
    archive.addFile(ArchiveFile('xl/sharedStrings.xml', sharedStringsXml.length, utf8.encode(sharedStringsXml)));

    final zipBytes = ZipEncoder().encode(archive);
    final wb = await ExcelParser.parse(Uint8List.fromList(zipBytes));

    expect(wb.sheets.length, 1);
    expect(wb.sheets.first.name, 'Sales');
    expect(wb.sheets.first.cell(0, 0)?.value, 'Revenue');
    expect(wb.sheets.first.cell(0, 1)?.value, '100');
  });

  test('WordParser parses headings and paragraphs', () async {
    final archive = Archive();

    const docXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr>
        <w:pStyle w:val="Heading1"/>
      </w:pPr>
      <w:r>
        <w:t>Quarterly Report</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:r>
        <w:rPr><w:b/></w:rPr>
        <w:t>Summary:</w:t>
      </w:r>
      <w:r>
        <w:t> All goals achieved.</w:t>
      </w:r>
    </w:p>
  </w:body>
</w:document>''';

    archive.addFile(ArchiveFile('word/document.xml', docXml.length, utf8.encode(docXml)));

    final zipBytes = ZipEncoder().encode(archive);
    final doc = await WordParser.parse(Uint8List.fromList(zipBytes));

    expect(doc.blocks.length, 2);
    final h1 = doc.blocks[0] as WordParagraph;
    expect(h1.headingLevel, 1);
    expect(h1.fullText, 'Quarterly Report');

    final p = doc.blocks[1] as WordParagraph;
    expect(p.spans.length, 2);
    expect(p.spans[0].bold, true);
    expect(p.spans[0].text, 'Summary:');
    expect(p.spans[1].text, ' All goals achieved.');
  });

  test('PresentationParser parses slides and bullets', () async {
    final archive = Archive();

    const presXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldIdLst>
    <p:sldId id="256" r:id="rId1"/>
  </p:sldIdLst>
</p:presentation>''';

    const presRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="..." Target="slides/slide1.xml"/>
</Relationships>''';

    const slide1Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
        <p:txBody><a:p><a:r><a:t>Introduction to Pagelit</a:t></a:r></a:p></p:txBody>
      </p:sp>
      <p:sp>
        <p:txBody><a:p><a:r><a:t>Key Feature A</a:t></a:r></a:p></p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';

    archive.addFile(ArchiveFile('ppt/presentation.xml', presXml.length, utf8.encode(presXml)));
    archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', presRelsXml.length, utf8.encode(presRelsXml)));
    archive.addFile(ArchiveFile('ppt/slides/slide1.xml', slide1Xml.length, utf8.encode(slide1Xml)));

    final zipBytes = ZipEncoder().encode(archive);
    final deck = await PresentationParser.parse(Uint8List.fromList(zipBytes));

    expect(deck.slides.length, 1);
    expect(deck.slides.first.slideNumber, 1);
    expect(deck.slides.first.title, 'Introduction to Pagelit');
    expect(deck.slides.first.bulletPoints, contains('Key Feature A'));
  });

  test('Office parsers properly preserve French UTF-8 symbols', () async {
    // 1. Word with French text
    final wordArchive = Archive();
    const docXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:r><w:t>Rapport d'activité : été 2026, présentation &amp; données reçues (français)</w:t></w:r>
    </w:p>
  </w:body>
</w:document>''';
    final docBytes = utf8.encode(docXml);
    wordArchive.addFile(ArchiveFile('word/document.xml', docBytes.length, docBytes));
    final doc = await WordParser.parse(Uint8List.fromList(ZipEncoder().encode(wordArchive)));
    final wordP = doc.blocks.first as WordParagraph;
    expect(wordP.fullText, "Rapport d'activité : été 2026, présentation & données reçues (français)");

    // 2. Excel with French text
    final excelArchive = Archive();
    const sstXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <si><t>Chiffre d'affaires &amp; Bénéfice net</t></si>
</sst>''';
    const sheetXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1"><c r="A1" t="s"><v>0</v></c></row>
  </sheetData>
</worksheet>''';
    final sstBytes = utf8.encode(sstXml);
    final sheetBytes = utf8.encode(sheetXml);
    excelArchive.addFile(ArchiveFile('xl/sharedStrings.xml', sstBytes.length, sstBytes));
    excelArchive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetBytes.length, sheetBytes));
    final wb = await ExcelParser.parse(Uint8List.fromList(ZipEncoder().encode(excelArchive)));
    expect(wb.sheets.first.cell(0, 0)?.value, "Chiffre d'affaires & Bénéfice net");

    // 3. Presentation with French text
    final pptArchive = Archive();
    const slideXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
        <p:txBody><a:p><a:r><a:t>Stratégie Numérique &amp; Déploiement</a:t></a:r></a:p></p:txBody>
      </p:sp>
      <p:sp>
        <p:txBody><a:p><a:r><a:t>• Première étape : conformité &amp; sécurité</a:t></a:r></a:p></p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
    final slideBytes = utf8.encode(slideXml);
    pptArchive.addFile(ArchiveFile('ppt/slides/slide1.xml', slideBytes.length, slideBytes));
    final deck = await PresentationParser.parse(Uint8List.fromList(ZipEncoder().encode(pptArchive)));
    expect(deck.slides.first.title, 'Stratégie Numérique & Déploiement');
    expect(deck.slides.first.bulletPoints, contains('• Première étape : conformité & sécurité'));
  });
}
