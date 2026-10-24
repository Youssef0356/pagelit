import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'encoding_utils.dart';

class ExcelCell {
  const ExcelCell({
    required this.row,
    required this.col,
    required this.coordinate,
    required this.value,
    this.formula,
  });

  final int row;
  final int col;
  final String coordinate;
  final String value;
  final String? formula;
}

class ExcelSheet {
  const ExcelSheet({
    required this.name,
    required this.maxRow,
    required this.maxCol,
    required this.cells,
  });

  final String name;
  final int maxRow;
  final int maxCol;
  final Map<String, ExcelCell> cells;

  ExcelCell? cell(int r, int c) => cells['${r}_$c'];
}

class ExcelWorkbook {
  const ExcelWorkbook({required this.sheets});

  final List<ExcelSheet> sheets;
}

class ExcelParser {
  const ExcelParser._();

  static int _colLettersToIndex(String letters) {
    int index = 0;
    for (int i = 0; i < letters.length; i++) {
      index = index * 26 + (letters.codeUnitAt(i) - 64);
    }
    return index - 1;
  }

  static Future<ExcelWorkbook> parse(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final sharedStrings = <String>[];

    // 1. Parse shared strings if present
    final sstFile = archive.findFile('xl/sharedStrings.xml');
    if (sstFile != null) {
      final sstContent = EncodingUtils.decodeDocumentBytes(sstFile.content as List<int>);
      final sstDoc = XmlDocument.parse(sstContent);
      for (final si in sstDoc.findAllElements('si')) {
        final tNodes = si.findAllElements('t');
        final text = tNodes.map((n) => n.innerText).join();
        sharedStrings.add(text);
      }
    }

    // 2. Parse workbook.xml to get sheet names and r:id mapping
    final workbookFile = archive.findFile('xl/workbook.xml');
    final sheetEntries = <({String name, String sheetPath})>[];

    if (workbookFile != null) {
      final wbContent = EncodingUtils.decodeDocumentBytes(workbookFile.content as List<int>);
      final wbDoc = XmlDocument.parse(wbContent);

      // Parse rels to map r:id -> target filename
      final relsFile = archive.findFile('xl/_rels/workbook.xml.rels');
      final relsMap = <String, String>{};
      if (relsFile != null) {
        final relsContent = EncodingUtils.decodeDocumentBytes(relsFile.content as List<int>);
        final relsDoc = XmlDocument.parse(relsContent);
        for (final rel in relsDoc.findAllElements('Relationship')) {
          final id = rel.getAttribute('Id');
          final target = rel.getAttribute('Target');
          if (id != null && target != null) {
            final normalized = target.startsWith('/') ? target.substring(1) : 'xl/$target';
            relsMap[id] = normalized.replaceAll('xl/xl/', 'xl/');
          }
        }
      }

      final sheetNodes = wbDoc.findAllElements('sheet');
      int sheetIndex = 1;
      for (final s in sheetNodes) {
        final name = s.getAttribute('name') ?? 'Sheet$sheetIndex';
        final rId = s.getAttribute('r:id');
        String targetPath = relsMap[rId] ?? 'xl/worksheets/sheet$sheetIndex.xml';
        sheetEntries.add((name: name, sheetPath: targetPath));
        sheetIndex++;
      }
    }

    // If no sheets found from workbook.xml, search archive files directly
    if (sheetEntries.isEmpty) {
      for (final file in archive.files) {
        if (file.name.startsWith('xl/worksheets/sheet') && file.name.endsWith('.xml')) {
          sheetEntries.add((name: 'Sheet ${sheetEntries.length + 1}', sheetPath: file.name));
        }
      }
    }

    final parsedSheets = <ExcelSheet>[];

    for (final entry in sheetEntries) {
      final sheetFile = archive.findFile(entry.sheetPath);
      if (sheetFile == null) continue;

      final sheetXml = EncodingUtils.decodeDocumentBytes(sheetFile.content as List<int>);
      final sheetDoc = XmlDocument.parse(sheetXml);

      final cells = <String, ExcelCell>{};
      int maxR = 0;
      int maxC = 0;

      final cNodes = sheetDoc.findAllElements('c');
      final coordRegExp = RegExp(r'^([A-Z]+)(\d+)$');

      for (final c in cNodes) {
        final rAttr = c.getAttribute('r');
        if (rAttr == null) continue;

        final match = coordRegExp.firstMatch(rAttr);
        if (match == null) continue;

        final colStr = match.group(1)!;
        final rowStr = match.group(2)!;
        final colIdx = _colLettersToIndex(colStr);
        final rowIdx = (int.tryParse(rowStr) ?? 1) - 1;

        if (rowIdx > maxR) maxR = rowIdx;
        if (colIdx > maxC) maxC = colIdx;

        final type = c.getAttribute('t');
        final vElem = c.findElements('v').firstOrNull;
        final fElem = c.findElements('f').firstOrNull;
        final formula = fElem?.innerText;

        String val = '';
        if (type == 's' && vElem != null) {
          final sIndex = int.tryParse(vElem.innerText);
          if (sIndex != null && sIndex >= 0 && sIndex < sharedStrings.length) {
            val = sharedStrings[sIndex];
          }
        } else if (type == 'inlineStr') {
          val = c.findAllElements('t').map((n) => n.innerText).join();
        } else if (type == 'b' && vElem != null) {
          val = vElem.innerText == '1' ? 'TRUE' : 'FALSE';
        } else if (vElem != null) {
          val = vElem.innerText;
        }

        cells['${rowIdx}_$colIdx'] = ExcelCell(
          row: rowIdx,
          col: colIdx,
          coordinate: rAttr,
          value: val,
          formula: formula,
        );
      }

      parsedSheets.add(
        ExcelSheet(
          name: entry.name,
          maxRow: maxR + 1,
          maxCol: maxC + 1,
          cells: cells,
        ),
      );
    }

    return ExcelWorkbook(sheets: parsedSheets);
  }
}
