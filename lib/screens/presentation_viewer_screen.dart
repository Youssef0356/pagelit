import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/encoding_utils.dart';
import '../services/gallery_saver.dart';
import '../services/gemini_share_service.dart';
import '../services/presentation_parser.dart';

class PresentationViewerScreen extends StatefulWidget {
  const PresentationViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  State<PresentationViewerScreen> createState() => _PresentationViewerScreenState();
}

class _PresentationViewerScreenState extends State<PresentationViewerScreen> {
  final GlobalKey _slideCardKey = GlobalKey();
  PresentationDeck? _deck;
  bool _isLoading = true;
  bool _isSavingToGallery = false;
  String? _error;
  int _currentSlideIndex = 0;
  final PageController _pageController = PageController();
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  double _fontScale = 1.0;
  bool _fillContainer = true;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _pageController.dispose();
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
      final deck = await PresentationParser.parse(bytes);
      if (!mounted) return;
      setState(() {
        _deck = deck;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load presentation: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _shareFile() async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(widget.filePath)],
        title: EncodingUtils.cleanDisplayName(widget.title),
      ),
    );
  }

  Future<void> _saveSlideToGallery() async {
    if (_deck == null || _deck!.slides.isEmpty || _isSavingToGallery) return;
    final l10n = context.l10n;
    setState(() => _isSavingToGallery = true);
    final cleanTitle = EncodingUtils.cleanDisplayName(widget.title);
    final slideNum = _currentSlideIndex + 1;
    try {
      await GallerySaver.saveBoundaryToGallery(
        context: context,
        boundaryKey: _slideCardKey,
        baseName: 'Pagelit_${cleanTitle}_slide_$slideNum',
        successMessage: l10n.slideSaved(slideNum),
      );
    } finally {
      if (mounted) setState(() => _isSavingToGallery = false);
    }
  }

  Future<void> _askGemini() async {
    if (_deck == null || _deck!.slides.isEmpty) return;
    final cleanTitle = EncodingUtils.cleanDisplayName(widget.title);
    final slideNum = _currentSlideIndex + 1;
    await GeminiShareService.shareBoundaryToGemini(
      context: context,
      boundaryKey: _slideCardKey,
      pageTitle: '$cleanTitle (Slide $slideNum)',
      customPrompt: 'Please summarize, explain the key points, and provide insights for this presentation slide.',
    );
  }

  void _openSlideOverview() {
    if (_deck == null || _deck!.slides.isEmpty) return;
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      l10n.allSlidesCount(_deck!.slides.length),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _deck!.slides.length,
                  itemBuilder: (context, idx) {
                    final slide = _deck!.slides[idx];
                    final isCurrent = idx == _currentSlideIndex;
                    final hasSearchMatch = _searchQuery.isNotEmpty &&
                        (EncodingUtils.searchMatches(slide.title, _searchQuery) ||
                            slide.bulletPoints.any((b) => EncodingUtils.searchMatches(b, _searchQuery)));
                    final scheme = Theme.of(context).colorScheme;

                    return InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        _pageController.jumpToPage(idx);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? scheme.primaryContainer
                              : hasSearchMatch
                                  ? Colors.yellow.withValues(alpha: 0.25)
                                  : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent
                                ? scheme.primary
                                : hasSearchMatch
                                    ? Colors.orange
                                    : scheme.outlineVariant,
                            width: isCurrent || hasSearchMatch ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.slideNumber(slide.slideNumber),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent ? scheme.onPrimaryContainer : scheme.outline,
                                  ),
                                ),
                                if (hasSearchMatch)
                                  const Icon(Icons.search_rounded, size: 14, color: Colors.orange),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Text(
                                EncodingUtils.cleanDisplayName(slide.title),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewImage(Uint8List imageBytes) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(imageBytes, fit: BoxFit.contain),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  tooltip: l10n.saveImageToGallery,
                  icon: const Icon(Icons.download_rounded),
                  onPressed: () async {
                    final cleanTitle = EncodingUtils.cleanDisplayName(widget.title);
                    await GallerySaver.saveBytesToGallery(
                      context: dialogCtx,
                      imageBytes: imageBytes,
                      name: 'Pagelit_${cleanTitle}_img_${DateTime.now().millisecondsSinceEpoch}',
                      successMessage: l10n.imageSavedToGallery,
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _highlightedText(String text, TextStyle baseStyle, ColorScheme scheme) {
    if (_searchQuery.isEmpty || !EncodingUtils.searchMatches(text, _searchQuery)) {
      return SelectableText(text, style: baseStyle);
    }

    final cleanQuery = EncodingUtils.removeDiacritics(_searchQuery.toLowerCase());
    final cleanText = EncodingUtils.removeDiacritics(text.toLowerCase());
    final spans = <TextSpan>[];
    int start = 0;

    while (start < text.length) {
      final index = cleanText.indexOf(cleanQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      final matchEnd = index + cleanQuery.length;
      spans.add(TextSpan(
        text: text.substring(index, matchEnd),
        style: const TextStyle(
          backgroundColor: Colors.yellow,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = matchEnd;
    }

    return SelectableText.rich(
      TextSpan(style: baseStyle, children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final cleanTitle = EncodingUtils.cleanDisplayName(widget.title);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade700,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PPTX',
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
                cleanTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_deck != null && _deck!.slides.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: ActionChip(
                avatar: const Icon(Icons.grid_view_rounded, size: 16),
                label: Text('${_currentSlideIndex + 1} / ${_deck!.slides.length}'),
                onPressed: _openSlideOverview,
              ),
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
            onPressed: _deck == null || _deck!.slides.isEmpty ? null : _askGemini,
          ),
          PopupMenuButton<String>(
            tooltip: l10n.more,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              switch (val) {
                case 'aspect':
                  setState(() => _fillContainer = !_fillContainer);
                  break;
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
                  if (!_isSavingToGallery && _deck != null && _deck!.slides.isNotEmpty) {
                    _saveSlideToGallery();
                  }
                  break;
                case 'share':
                  _shareFile();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'aspect',
                child: ListTile(
                  dense: true,
                  leading: Icon(_fillContainer ? Icons.aspect_ratio_rounded : Icons.fullscreen_rounded),
                  title: Text(_fillContainer ? l10n.aspectRatioMode : l10n.expandedBigContainer),
                ),
              ),
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
                  title: Text(l10n.saveSlideToGallery),
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
                  hintText: l10n.searchPresentationHint,
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
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),
          Expanded(child: _buildBody(l10n)),
          if (_deck != null && _deck!.slides.length > 1)
            _buildBottomControls(l10n)
          else
            const SafeArea(top: false, child: SizedBox(height: 8)),
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
    if (_deck == null || _deck!.slides.isEmpty) {
      return Center(child: Text(l10n.presentationHasNoSlides));
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _deck!.slides.length,
      onPageChanged: (idx) => setState(() => _currentSlideIndex = idx),
      itemBuilder: (context, index) {
        final slide = _deck!.slides[index];
        final isCurrent = index == _currentSlideIndex;
        final card = _buildSlideCard(slide, l10n);
        return isCurrent ? RepaintBoundary(key: _slideCardKey, child: card) : card;
      },
    );
  }

  Widget _buildSlideCard(PresentationSlide slide, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;

    if (_fillContainer) {
      // Big container mode: fills the entire available viewport height and width!
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: _buildCardContent(slide, scheme, l10n),
      );
    } else {
      // Classic 16:10 aspect ratio mode
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: _buildCardContent(slide, scheme, l10n),
          ),
        ),
      );
    }
  }

  Widget _buildCardContent(PresentationSlide slide, ColorScheme scheme, AppLocalizations l10n) {
    final cleanSlideTitle = EncodingUtils.cleanDisplayName(slide.title);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _highlightedText(
                  cleanSlideTitle,
                  TextStyle(
                    fontSize: 20 * _fontScale,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                  scheme,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.slideNumber(slide.slideNumber),
                  style: TextStyle(
                    fontSize: 11 * _fontScale,
                    fontWeight: FontWeight.bold,
                    color: scheme.outline,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final point in slide.bulletPoints) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 10, top: 4),
                            child: Transform.flip(
                              flipX: Directionality.of(context) == TextDirection.rtl,
                              child: Icon(Icons.arrow_right_rounded, size: 20, color: scheme.primary),
                            ),
                          ),
                          Expanded(
                            child: _highlightedText(
                              point,
                              TextStyle(
                                fontSize: 14.5 * _fontScale,
                                height: 1.55,
                                color: scheme.onSurface,
                              ),
                              scheme,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (slide.bulletPoints.isEmpty && slide.images.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          l10n.slideTitleOnly,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: scheme.outline,
                            fontSize: 13 * _fontScale,
                          ),
                        ),
                      ),
                    ),
                  if (slide.images.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: slide.images.map((img) {
                        return InkWell(
                          onTap: () => _viewImage(img),
                          borderRadius: BorderRadius.circular(10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              color: scheme.surfaceContainerHigh,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Image.memory(
                                    img,
                                    height: _fillContainer ? 200 : 130,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.all(6),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(6),
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
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(AppLocalizations l10n) {
    final hasPrev = _currentSlideIndex > 0;
    final hasNext = _deck != null && _currentSlideIndex < _deck!.slides.length - 1;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton.filledTonal(
              icon: Transform.flip(
                flipX: Directionality.of(context) == TextDirection.rtl,
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
              onPressed: hasPrev
                  ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
            Flexible(
              child: TextButton.icon(
                icon: const Icon(Icons.grid_view_rounded, size: 16),
                label: Text(
                  l10n.slideXOfY(_currentSlideIndex + 1, _deck!.slides.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: _openSlideOverview,
              ),
            ),
            IconButton.filledTonal(
              icon: Transform.flip(
                flipX: Directionality.of(context) == TextDirection.rtl,
                child: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              ),
              onPressed: hasNext
                  ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
