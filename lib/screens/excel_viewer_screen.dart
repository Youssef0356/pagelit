import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/excel_parser.dart';


class ExcelViewerScreen extends StatefulWidget {
  const ExcelViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  State<ExcelViewerScreen> createState() => _ExcelViewerScreenState();
}

class _ExcelViewerScreenState extends State<ExcelViewerScreen> {
  ExcelWorkbook? _workbook;
  int _activeSheetIndex = 0;
  bool _isLoading = true;
  String? _error;
  ExcelCell? _selectedCell;
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final wb = await ExcelParser.parse(bytes);
      if (!mounted) return;
      setState(() {
        _workbook = wb;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load spreadsheet: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _shareFile() async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(widget.filePath)],
        title: widget.title,
      ),
    );
  }

  String _colIndexToLetters(int index) {
    String res = '';
    int temp = index + 1;
    while (temp > 0) {
      int rem = (temp - 1) % 26;
      res = String.fromCharCode(65 + rem) + res;
      temp = (temp - 1) ~/ 26;
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;


    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'XLSX',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: Icon(_isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _isSearchOpen = !_isSearchOpen;
              if (!_isSearchOpen) {
                _searchQuery = '';
                _searchController.clear();
              }
            }),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareFile,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearchOpen)
            Container(
              color: scheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search cell contents...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          }),
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),
          Expanded(child: _buildBody()),
          if (_selectedCell != null) _buildCellInspector(),
          if (_workbook != null && _workbook!.sheets.length > 1) _buildSheetTabBar(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadFile, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_workbook == null || _workbook!.sheets.isEmpty) {
      return const Center(child: Text('Empty workbook'));
    }

    final sheet = _workbook!.sheets[_activeSheetIndex];
    if (sheet.maxRow == 0 || sheet.maxCol == 0) {
      return const Center(child: Text('This sheet contains no data.'));
    }

    final scheme = Theme.of(context).colorScheme;
    final rowCount = sheet.maxRow.clamp(1, 2000);
    final colCount = sheet.maxCol.clamp(1, 100);

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(200),
      minScale: 0.5,
      maxScale: 2.5,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(110),
        columnWidths: const {0: FixedColumnWidth(48)},
        border: TableBorder.all(color: scheme.outlineVariant, width: 0.8),
        children: [
          // Header Row: A, B, C...
          TableRow(
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh),
            children: [
              Container(
                alignment: Alignment.center,
                height: 32,
                child: const Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              for (int c = 0; c < colCount; c++)
                Container(
                  alignment: Alignment.center,
                  height: 32,
                  child: Text(
                    _colIndexToLetters(c),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
            ],
          ),
          // Data Rows
          for (int r = 0; r < rowCount; r++)
            TableRow(
              decoration: BoxDecoration(
                color: r.isEven ? scheme.surface : scheme.surfaceContainerLowest,
              ),
              children: [
                // Row Header
                Container(
                  alignment: Alignment.center,
                  height: 36,
                  color: scheme.surfaceContainerHigh,
                  child: Text(
                    '${r + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // Cells
                for (int c = 0; c < colCount; c++) _buildCellWidget(sheet, r, c),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCellWidget(ExcelSheet sheet, int r, int c) {
    final cell = sheet.cell(r, c);
    final val = cell?.value ?? '';
    final isSelected = _selectedCell != null && _selectedCell!.row == r && _selectedCell!.col == c;
    final isMatch = _searchQuery.isNotEmpty && val.toLowerCase().contains(_searchQuery);
    final scheme = Theme.of(context).colorScheme;

    Color? bgColor;
    if (isSelected) {
      bgColor = scheme.primaryContainer.withValues(alpha: 0.6);
    } else if (isMatch) {
      bgColor = Colors.yellow.withValues(alpha: 0.45);
    }

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedCell = cell ?? ExcelCell(row: r, col: c, coordinate: '${_colIndexToLetters(c)}${r + 1}', value: ''));
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        color: bgColor,
        alignment: Alignment.centerLeft,
        child: Text(
          val,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isMatch ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? scheme.onPrimaryContainer : scheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildCellInspector() {
    final cell = _selectedCell!;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              cell.coordinate,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cell.formula != null)
                  Text(
                    'fx: =${cell.formula}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: scheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                SelectableText(
                  cell.value.isEmpty ? '(Empty)' : cell.value,
                  style: TextStyle(
                    fontSize: 13,
                    color: cell.value.isEmpty ? scheme.outline : scheme.onSurface,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          if (cell.value.isNotEmpty)
            IconButton(
              tooltip: 'Copy value',
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: cell.value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied cell text to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => setState(() => _selectedCell = null),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetTabBar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      color: scheme.surfaceContainerLowest,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _workbook!.sheets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final isSelected = idx == _activeSheetIndex;
          final sheet = _workbook!.sheets[idx];
          return ChoiceChip(
            label: Text(sheet.name),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                HapticFeedback.selectionClick();
                setState(() {
                  _activeSheetIndex = idx;
                  _selectedCell = null;
                });
              }
            },
          );
        },
      ),
    );
  }
}

