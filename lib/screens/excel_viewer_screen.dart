import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/encoding_utils.dart';
import '../services/excel_parser.dart';
import '../services/gallery_saver.dart';
import '../services/gemini_share_service.dart';


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
  final GlobalKey _sheetTableKey = GlobalKey();
  ExcelWorkbook? _workbook;
  int _activeSheetIndex = 0;
  bool _isLoading = true;
  bool _isSavingToGallery = false;
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

  Future<void> _saveSheetToGallery() async {
    if (_workbook == null || _workbook!.sheets.isEmpty || _isSavingToGallery) return;
    final l10n = context.l10n;
    setState(() => _isSavingToGallery = true);
    final cleanTitle = EncodingUtils.cleanDisplayName(widget.title);
    final sheet = _workbook!.sheets[_activeSheetIndex];
    try {
      await GallerySaver.saveBoundaryToGallery(
        context: context,
        boundaryKey: _sheetTableKey,
        baseName: 'Pagelit_${cleanTitle}_${sheet.name}',
        successMessage: l10n.sheetViewSaved(sheet.name),
      );
    } finally {
      if (mounted) setState(() => _isSavingToGallery = false);
    }
  }

  Future<void> _askGemini() async {
    if (_workbook == null || _workbook!.sheets.isEmpty) return;
    final cleanTitle = EncodingUtils.cleanDisplayName(widget.title);
    final sheet = _workbook!.sheets[_activeSheetIndex];
    await GeminiShareService.shareBoundaryToGemini(
      context: context,
      boundaryKey: _sheetTableKey,
      pageTitle: '$cleanTitle (Sheet "${sheet.name}")',
      customPrompt: 'Please analyze this spreadsheet table, summarize trends, compute totals or key ratios, and highlight any anomalies.',
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
    final l10n = context.l10n;
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
                EncodingUtils.cleanDisplayName(widget.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.search,
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
            tooltip: l10n.askGemini,
            icon: const Icon(Icons.auto_awesome_rounded),
            color: Theme.of(context).colorScheme.primary,
            onPressed: _workbook == null || _workbook!.sheets.isEmpty ? null : _askGemini,
          ),
          PopupMenuButton<String>(
            tooltip: l10n.more,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              switch (val) {
                case 'gallery':
                  if (!_isSavingToGallery && _workbook != null && _workbook!.sheets.isNotEmpty) {
                    _saveSheetToGallery();
                  }
                  break;
                case 'share':
                  _shareFile();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'gallery',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.add_photo_alternate_rounded),
                  title: Text(l10n.saveSheetViewToGallery),
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.share_rounded),
                  title: Text(l10n.share),
                ),
              ),
            ],
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
                  hintText: l10n.searchCellContents,
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
          _buildFormulaBar(l10n),
          Expanded(child: _buildBody(l10n)),
          if (_workbook != null && _workbook!.sheets.length > 1)
            SafeArea(
              top: false,
              child: _buildSheetTabBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildFormulaBar(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final cell = _selectedCell;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cell != null ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              cell?.coordinate ?? 'fx',
              style: TextStyle(
                color: cell != null ? Colors.white : scheme.outline,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cell != null && cell.value.isNotEmpty
                  ? (cell.formula != null ? '=${cell.formula} (${cell.value})' : cell.value)
                  : 'Tap any cell to inspect',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: cell != null && cell.value.isNotEmpty
                    ? scheme.onSurface
                    : scheme.outline,
              ),
            ),
          ),
          if (cell != null && cell.value.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: MaterialLocalizations.of(context).copyButtonLabel,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: cell.value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.copiedCellText),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.auto_awesome_rounded, size: 18, color: scheme.primary),
              tooltip: l10n.askGemini,
              onPressed: () {
                GeminiShareService.askGeminiAboutText(
                  context: context,
                  selectedText: 'Cell ${cell.coordinate}: ${cell.value}',
                  pageTitle: widget.title,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
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
              FilledButton(onPressed: _loadFile, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }
    if (_workbook == null || _workbook!.sheets.isEmpty) {
      return Center(child: Text(l10n.emptyWorkbook));
    }

    final sheet = _workbook!.sheets[_activeSheetIndex];
    if (sheet.maxRow == 0 || sheet.maxCol == 0) {
      return Center(child: Text(l10n.sheetContainsNoData));
    }

    final scheme = Theme.of(context).colorScheme;
    final rowCount = sheet.maxRow.clamp(1, 2000);
    final colCount = sheet.maxCol.clamp(1, 100);

    final Map<int, TableColumnWidth> colWidths = {0: const FixedColumnWidth(48)};
    for (int c = 0; c < colCount; c++) {
      int maxLen = _colIndexToLetters(c).length;
      final checkRows = rowCount.clamp(0, 30);
      for (int r = 0; r < checkRows; r++) {
        final len = sheet.cell(r, c)?.value.length ?? 0;
        if (len > maxLen) maxLen = len;
      }
      final width = (maxLen * 8.5 + 28.0).clamp(72.0, 240.0);
      colWidths[c + 1] = FixedColumnWidth(width);
    }

    return RepaintBoundary(
      key: _sheetTableKey,
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(200),
        minScale: 0.5,
        maxScale: 2.5,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(110),
          columnWidths: colWidths,
          border: TableBorder.all(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
            width: 0.8,
          ),
          children: [
            // Header Row: A, B, C...
            TableRow(
              decoration: BoxDecoration(color: scheme.surfaceContainerHigh),
              children: [
                Container(
                  alignment: Alignment.center,
                  height: 32,
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: scheme.primary,
                    ),
                  ),
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
                    color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
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
      ),
    );
  }

  bool _isNumericValue(String text) {
    if (text.isEmpty) return false;
    final cleaned = text.replaceAll(RegExp(r'[\$,€,£,¥,%,\s]'), '');
    return double.tryParse(cleaned) != null;
  }

  Widget _buildCellWidget(ExcelSheet sheet, int r, int c) {
    final cell = sheet.cell(r, c);
    final val = cell?.value ?? '';
    final isSelected = _selectedCell != null && _selectedCell!.row == r && _selectedCell!.col == c;
    final isMatch = _searchQuery.isNotEmpty && EncodingUtils.searchMatches(val, _searchQuery);
    final scheme = Theme.of(context).colorScheme;
    final isNumeric = _isNumericValue(val);

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: bgColor,
        alignment: isNumeric
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
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

  Widget _buildSheetTabBar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _workbook!.sheets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final isSelected = idx == _activeSheetIndex;
          final sheet = _workbook!.sheets[idx];
          return ActionChip(
            avatar: Icon(
              Icons.table_chart_rounded,
              size: 16,
              color: isSelected ? scheme.onPrimaryContainer : scheme.outline,
            ),
            backgroundColor: isSelected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            side: BorderSide(
              color: isSelected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 1.5 : 1.0,
            ),
            label: Text(
              sheet.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
            ),
            onPressed: () {
              if (!isSelected) {
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

