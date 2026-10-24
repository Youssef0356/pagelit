import 'dart:io';
import 'package:flutter/material.dart';

import 'package:share_plus/share_plus.dart';

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
            color: bgColor,
            child: SafeArea(
              top: false,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                itemCount: _doc!.blocks.length,
                itemBuilder: (context, index) {
                  final block = _doc!.blocks[index];
                  return _buildBlock(block, textColor, scheme);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlock(WordBlock block, Color textColor, ColorScheme scheme) {
    if (block is WordParagraph) {
      if (block.headingLevel != null) {
        final double fontSize = switch (block.headingLevel) {
          1 => 24.0 * _fontScale,
          2 => 20.0 * _fontScale,
          _ => 17.0 * _fontScale,
        };
        return Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(
            block.fullText,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (block.isBullet)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8, top: 4),
                child: Text('•', style: TextStyle(fontSize: 16 * _fontScale, color: textColor)),
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

                    return TextSpan(
                      text: span.text,
                      style: TextStyle(
                        fontSize: 15.0 * _fontScale,
                        height: 1.6,
                        fontWeight: span.bold ? FontWeight.bold : FontWeight.normal,
                        fontStyle: span.italic ? FontStyle.italic : FontStyle.normal,
                        decoration: span.underline ? TextDecoration.underline : TextDecoration.none,
                        color: isMatch ? Colors.black : spanColor,
                        backgroundColor: isMatch ? Colors.yellow : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (block is WordTableBlock) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.all(color: scheme.outlineVariant),
            children: block.rows.map((row) {
              return TableRow(
                children: row.map((cellText) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      cellText,
                      style: TextStyle(fontSize: 13.0 * _fontScale, color: textColor),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      );
    } else if (block is WordImageBlock) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            block.bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

