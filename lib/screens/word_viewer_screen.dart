import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/encoding_utils.dart';
import '../services/gallery_saver.dart';
import '../services/gemini_share_service.dart';
import '../services/reading_prefs.dart';
import '../services/word_parser.dart';

class WordViewerScreen extends StatefulWidget {
  const WordViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  State<WordViewerScreen> createState() => _WordViewerScreenState();
}

class _WordViewerScreenState extends State<WordViewerScreen> {
  final GlobalKey _documentViewKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final Map<String, TapGestureRecognizer> _linkRecognizers = {};
  WordDocument? _doc;
  bool _isLoading = true;
  bool _isSavingToGallery = false;
  String? _error;
  double _fontScale = 1.0;
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
    for (final rec in _linkRecognizers.values) {
      rec.dispose();
    }
    _linkRecognizers.clear();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  TapGestureRecognizer _recognizerForUrl(String url) {
    return _linkRecognizers.putIfAbsent(url, () {
      return TapGestureRecognizer()..onTap = () => _openLink(url);
    });
  }

  Future<void> _openLink(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $url')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid link URL: $url')),
        );
      }
    }
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final doc = await WordParser.parse(bytes);
      if (!mounted) return;
      setState(() {
        _doc = doc;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load Word document: $e';
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

  Future<void> _saveViewToGallery() async {
    if (_doc == null || _doc!.blocks.isEmpty || _isSavingToGallery) return;
    final l10n = context.l10n;
    setState(() => _isSavingToGallery = true);
    final cleanTitle = EncodingUtils.cleanDisplayName(widget.title);
    try {
      await GallerySaver.saveBoundaryToGallery(
        context: context,
        boundaryKey: _documentViewKey,
        baseName: 'Pagelit_${cleanTitle}_doc',
        successMessage: l10n.documentViewSaved,
      );
    } finally {
      if (mounted) setState(() => _isSavingToGallery = false);
    }
  }

  Future<void> _askGemini() async {
    if (_doc == null || _doc!.blocks.isEmpty) return;
    final cleanTitle = EncodingUtils.cleanDisplayName(widget.title);
    await GeminiShareService.shareBoundaryToGemini(
      context: context,
      boundaryKey: _documentViewKey,
      pageTitle: cleanTitle,
      customPrompt: 'Please summarize, explain the main points, and answer questions about this document excerpt.',
    );
  }

  void _openOutlineSheet() {
    if (_doc == null) return;
    final headings = <({int index, String text, int level})>[];
    for (int i = 0; i < _doc!.blocks.length; i++) {
      final block = _doc!.blocks[i];
      if (block is WordParagraph && block.headingLevel != null && block.fullText.trim().isNotEmpty) {
        headings.add((index: i, text: block.fullText.trim(), level: block.headingLevel!));
      }
    }

    if (headings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.noTableOfContents)),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                context.l10n.tableOfContents,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: headings.length,
                itemBuilder: (context, idx) {
                  final h = headings[idx];
                  final indent = (h.level - 1) * 16.0;
                  return ListTile(
                    contentPadding: EdgeInsetsDirectional.only(start: 20 + indent, end: 20),
                    leading: Icon(
                      h.level == 1 ? Icons.bookmark_rounded : Icons.subdirectory_arrow_right_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      h.text,
                      style: TextStyle(
                        fontWeight: h.level == 1 ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _scrollController.animateTo(
                        (h.index * 68.0).clamp(0.0, _scrollController.position.maxScrollExtent),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewImage(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            IconButton.filled(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Color? _parseColor(String? hexStr) {
    if (hexStr == null || hexStr.isEmpty || hexStr.toLowerCase() == 'auto' || hexStr.toLowerCase() == 'none') {
      return null;
    }
    final clean = hexStr.replaceAll('#', '');
    if (clean.length == 6) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) return Color(0xFF000000 | val);
    } else if (clean.length == 8) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) return Color(val);
    }
    return null;
  }

  Color? _getHighlightColor(String? nameOrHex) {
    if (nameOrHex == null || nameOrHex.isEmpty || nameOrHex.toLowerCase() == 'none') return null;
    final lower = nameOrHex.toLowerCase();
    switch (lower) {
      case 'yellow':
        return const Color(0xFFFFF275).withValues(alpha: 0.85);
      case 'green':
        return const Color(0xFF8CE99A).withValues(alpha: 0.85);
      case 'cyan':
        return const Color(0xFF66D9E8).withValues(alpha: 0.85);
      case 'magenta':
        return const Color(0xFFF783AC).withValues(alpha: 0.85);
      case 'blue':
        return const Color(0xFF74C0FC).withValues(alpha: 0.85);
      case 'red':
        return const Color(0xFFFF8787).withValues(alpha: 0.85);
      case 'darkblue':
        return const Color(0xFF1971C2).withValues(alpha: 0.35);
      case 'darkcyan':
        return const Color(0xFF0C8599).withValues(alpha: 0.35);
      case 'darkgreen':
        return const Color(0xFF2F9E44).withValues(alpha: 0.35);
      case 'darkmagenta':
        return const Color(0xFFA61E4D).withValues(alpha: 0.35);
      case 'darkred':
        return const Color(0xFFC92A2A).withValues(alpha: 0.35);
      case 'darkyellow':
        return const Color(0xFFF59F00).withValues(alpha: 0.45);
      case 'darkgray':
        return const Color(0xFF495057).withValues(alpha: 0.35);
      case 'lightgray':
        return const Color(0xFFCED4DA).withValues(alpha: 0.8);
      case 'black':
        return Colors.black26;
      default:
        final clean = lower.replaceAll('#', '');
        final hex = int.tryParse(clean, radix: 16);
        if (hex != null) return Color(0xFF000000 | hex);
        return const Color(0xFFFFF275);
    }
  }

  TextDecoration _resolveDecoration(bool underline, bool strikethrough) {
    if (underline && strikethrough) {
      return TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough]);
    }
    if (underline) return TextDecoration.underline;
    if (strikethrough) return TextDecoration.lineThrough;
    return TextDecoration.none;
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
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'DOCX',
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
            tooltip: l10n.tableOfContents,
            icon: const Icon(Icons.format_list_bulleted_rounded),
            onPressed: _openOutlineSheet,
          ),
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
            onPressed: _doc == null || _doc!.blocks.isEmpty ? null : _askGemini,
          ),
          PopupMenuButton<String>(
            tooltip: l10n.more,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              switch (val) {
                case 'text_minus':
                  setState(() {
                    if (_fontScale > 0.8) _fontScale -= 0.1;
                  });
                  break;
                case 'text_plus':
                  setState(() {
                    if (_fontScale < 1.8) _fontScale += 0.1;
                  });
                  break;
                case 'gallery':
                  if (!_isSavingToGallery && _doc != null && _doc!.blocks.isNotEmpty) {
                    _saveViewToGallery();
                  }
                  break;
                case 'share':
                  _shareFile();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'text_minus',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.text_decrease_rounded),
                  title: Text(l10n.smallerText),
                ),
              ),
              PopupMenuItem(
                value: 'text_plus',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.text_increase_rounded),
                  title: Text(l10n.largerText),
                ),
              ),
              PopupMenuItem(
                value: 'gallery',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.add_photo_alternate_rounded),
                  title: Text(l10n.saveWordViewToGallery),
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
                  hintText: l10n.searchWordHint,
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
          Expanded(child: _buildBody(l10n)),
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
    if (_doc == null || _doc!.blocks.isEmpty) {
      return Center(child: Text(l10n.wordDocumentEmpty));
    }

    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<ComfortMode>(
      valueListenable: ReadingPrefs.comfortMode,
      builder: (context, comfort, _) {
        Color bgColor = scheme.surface;
        Color textColor = scheme.onSurface;

        if (comfort == ComfortMode.sepia) {
          bgColor = const Color(0xFFFBF0D9);
          textColor = const Color(0xFF3B2E1E);
        } else if (comfort == ComfortMode.dim) {
          bgColor = const Color(0xFF1E1E1E);
          textColor = const Color(0xFFD4D4D4);
        } else if (comfort == ComfortMode.inverted) {
          bgColor = const Color(0xFF121212);
          textColor = const Color(0xFFF0F0F0);
        }

        return RepaintBoundary(
          key: _documentViewKey,
          child: Container(
            color: comfort == ComfortMode.normal
                ? scheme.surfaceContainerLow
                : bgColor,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
                    itemCount: _doc!.blocks.length,
                    itemBuilder: (context, index) {
                      final block = _doc!.blocks[index];
                      return _buildBlock(block, textColor, scheme, comfort);
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlock(WordBlock block, Color textColor, ColorScheme scheme, ComfortMode comfort) {
    if (block is WordParagraph) {
      final align = block.alignment ?? TextAlign.start;

      if (block.headingLevel != null) {
        final double baseSize = switch (block.headingLevel) {
          1 => 24.0,
          2 => 20.0,
          _ => 17.0,
        };
        final double fontSize = (block.spans.firstOrNull?.fontSize ?? baseSize) * _fontScale;
        final isH1 = block.headingLevel == 1;
        final hasCenterOrRight = align == TextAlign.center || align == TextAlign.right;

        Widget headingWidget = Padding(
          padding: EdgeInsets.only(top: isH1 ? 24 : 16, bottom: 8),
          child: Column(
            crossAxisAlignment: align == TextAlign.center
                ? CrossAxisAlignment.center
                : (align == TextAlign.right ? CrossAxisAlignment.end : CrossAxisAlignment.start),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isH1 && !hasCenterOrRight)
                    Container(
                      width: 4,
                      height: 22 * _fontScale,
                      margin: const EdgeInsetsDirectional.only(end: 10),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      block.fullText,
                      textAlign: align,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: isH1 ? -0.3 : -0.1,
                        color: _parseColor(block.spans.firstOrNull?.colorHex) ?? textColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (isH1) ...[
                const SizedBox(height: 6),
                Divider(
                  height: 1,
                  color: scheme.primary.withValues(alpha: 0.25),
                ),
              ],
            ],
          ),
        );

        if (block.backgroundColorHex != null) {
          final calloutBg = _parseColor(block.backgroundColorHex);
          if (calloutBg != null) {
            headingWidget = Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: (comfort == ComfortMode.dim || comfort == ComfortMode.inverted)
                    ? calloutBg.withValues(alpha: 0.25)
                    : calloutBg.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: headingWidget,
            );
          }
        }

        return headingWidget;
      }

      Widget paragraphWidget = Padding(
        padding: EdgeInsetsDirectional.only(
          start: ((block.indent ?? 0.0) * _fontScale).clamp(0.0, 80.0),
          top: 4,
          bottom: 4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (block.isBullet)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 10, top: 4),
                child: Icon(
                  Icons.circle,
                  size: 7 * _fontScale,
                  color: scheme.primary,
                ),
              ),
            Expanded(
              child: SelectableText.rich(
                TextSpan(
                  children: block.spans.map((span) {
                    final isMatch = _searchQuery.isNotEmpty && EncodingUtils.searchMatches(span.text, _searchQuery);
                    Color? spanColor = textColor;
                    if (span.colorHex != null && span.colorHex!.length == 6) {
                      final hex = int.tryParse(span.colorHex!, radix: 16);
                      if (hex != null) spanColor = Color(0xFF000000 | hex);
                    }

                    final isLink = span.linkUrl != null;
                    final effectiveColor = isMatch
                        ? Colors.black
                        : (isLink
                            ? (spanColor != textColor ? spanColor : Colors.blue.shade700)
                            : spanColor);

                    final effectiveDecoration = _resolveDecoration(
                      span.underline || isLink,
                      span.strikethrough,
                    );

                    final effectiveBg = isMatch
                        ? Colors.yellow
                        : _getHighlightColor(span.highlightHex);

                    final double effectiveFontSize = (span.fontSize ?? 15.0) * _fontScale;

                    return TextSpan(
                      text: span.text,
                      recognizer: isLink ? _recognizerForUrl(span.linkUrl!) : null,
                      mouseCursor: isLink ? SystemMouseCursors.click : SystemMouseCursors.text,
                      style: TextStyle(
                        fontSize: effectiveFontSize,
                        height: 1.6,
                        fontWeight: span.bold ? FontWeight.bold : FontWeight.normal,
                        fontStyle: span.italic ? FontStyle.italic : FontStyle.normal,
                        decoration: effectiveDecoration,
                        color: effectiveColor,
                        backgroundColor: effectiveBg,
                        fontFamily: span.fontFamily,
                      ),
                    );
                  }).toList(),
                ),
                textAlign: align,
              ),
            ),
          ],
        ),
      );

      if (block.backgroundColorHex != null) {
        final calloutBg = _parseColor(block.backgroundColorHex);
        if (calloutBg != null) {
          paragraphWidget = Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: (comfort == ComfortMode.dim || comfort == ComfortMode.inverted)
                  ? calloutBg.withValues(alpha: 0.25)
                  : calloutBg.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: paragraphWidget,
          );
        }
      }

      return paragraphWidget;
    } else if (block is WordTableBlock) {
      final richRows = block.richCells;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                  width: 0.8,
                ),
                verticalInside: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              children: (richRows != null && richRows.isNotEmpty)
                  ? richRows.asMap().entries.map((entry) {
                      final rowIndex = entry.key;
                      final rowCells = entry.value;
                      final isFirstRow = rowIndex == 0;
                      final isEvenRow = rowIndex % 2 == 0;
                      final defaultRowBg = isFirstRow
                          ? scheme.surfaceContainerHigh
                          : (isEvenRow ? scheme.surface : scheme.surfaceContainerLowest);

                      return TableRow(
                        decoration: BoxDecoration(color: defaultRowBg),
                        children: rowCells.map((cell) {
                          final isHeader = isFirstRow || cell.isHeader;
                          final cellCustomBg = _parseColor(cell.backgroundColorHex);

                          Widget cellWidget = Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text(
                              cell.text,
                              textAlign: cell.alignment ?? (isHeader ? TextAlign.center : TextAlign.start),
                              style: TextStyle(
                                fontSize: 13.0 * _fontScale,
                                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                                color: textColor,
                              ),
                            ),
                          );

                          if (cellCustomBg != null) {
                            cellWidget = Container(
                              color: (comfort == ComfortMode.dim || comfort == ComfortMode.inverted)
                                  ? cellCustomBg.withValues(alpha: 0.3)
                                  : cellCustomBg.withValues(alpha: 0.8),
                              child: cellWidget,
                            );
                          }

                          return cellWidget;
                        }).toList(),
                      );
                    }).toList()
                  : block.rows.asMap().entries.map((entry) {
                      final isHeader = entry.key == 0;
                      final isEvenRow = entry.key % 2 == 0;
                      final rowBg = isHeader
                          ? scheme.surfaceContainerHigh
                          : (isEvenRow ? scheme.surface : scheme.surfaceContainerLowest);

                      return TableRow(
                        decoration: BoxDecoration(color: rowBg),
                        children: entry.value.map((cellText) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text(
                              cellText,
                              style: TextStyle(
                                fontSize: 13.0 * _fontScale,
                                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                                color: textColor,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }).toList(),
            ),
          ),
        ),
      );
    } else if (block is WordImageBlock) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: InkWell(
          onTap: () => _viewImage(block.bytes),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Image.memory(
                  block.bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
