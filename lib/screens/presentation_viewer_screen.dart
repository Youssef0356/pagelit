import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/encoding_utils.dart';
import '../services/gallery_saver.dart';
import '../services/gemini_share_service.dart';
import '../services/presentation_parser.dart';

enum PresentationViewMode {
  slides,
  outline,
}

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
  final TransformationController _transformationController = TransformationController();
  bool _isZoomed = false;
  bool _enableAnimations = true;

  PresentationViewMode _viewMode = PresentationViewMode.slides;
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  double _fontScale = 1.0;
  bool _fillContainer = true;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChanged);
    _loadFile();
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.08;
    if (isZoomed != _isZoomed) {
      setState(() => _isZoomed = isZoomed);
    }
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
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

  void _startSlideshow() {
    if (_deck == null || _deck!.slides.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PresentationSlideshowScreen(
          deck: _deck!,
          initialSlideIndex: _currentSlideIndex,
          title: widget.title,
        ),
      ),
    );
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
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.allSlidesCount(_deck!.slides.length),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${_deck!.aspectRatio > 1.5 ? "16:9" : "4:3"} • ${_deck!.slides.length} slides',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.35,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _deck!.slides.length,
                      itemBuilder: (context, idx) {
                        final slide = _deck!.slides[idx];
                        final isCurrent = idx == _currentSlideIndex;
                        final hasSearchMatch = _searchQuery.isNotEmpty &&
                            (EncodingUtils.searchMatches(slide.title, _searchQuery) ||
                                slide.bulletPoints.any((b) => EncodingUtils.searchMatches(b, _searchQuery)) ||
                                slide.elements.any((e) =>
                                    e is SlideShapeElement && EncodingUtils.searchMatches(e.plainText, _searchQuery)));
                        final scheme = Theme.of(context).colorScheme;

                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            _pageController.jumpToPage(idx);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? scheme.primaryContainer
                                  : hasSearchMatch
                                      ? Colors.amber.withValues(alpha: 0.25)
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        l10n.slideNumber(slide.slideNumber),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isCurrent ? scheme.onPrimaryContainer : scheme.outline,
                                        ),
                                      ),
                                      if (hasSearchMatch)
                                        const Icon(Icons.search_rounded, size: 12, color: Colors.orange),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    color: slide.backgroundColor ?? Colors.white,
                                    padding: const EdgeInsets.all(6),
                                    child: slide.elements.isNotEmpty
                                        ? FittedBox(
                                            fit: BoxFit.contain,
                                            child: SizedBox(
                                              width: 320,
                                              height: 320 / _deck!.aspectRatio,
                                              child: SlideCanvasView(
                                                slide: slide,
                                                aspectRatio: _deck!.aspectRatio,
                                                themeColors: _deck!.themeColors,
                                                fontScale: 0.9,
                                                searchQuery: '',
                                                enableAnimations: false,
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              EncodingUtils.cleanDisplayName(slide.title),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: scheme.onSurface,
                                              ),
                                            ),
                                          ),
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
          // Play Fullscreen Presentation Slideshow
          if (_deck != null && _deck!.slides.isNotEmpty)
            IconButton(
              tooltip: l10n.playSlideshow,
              icon: const Icon(Icons.play_circle_fill_rounded, size: 26),
              color: scheme.primary,
              onPressed: _startSlideshow,
            ),
          if (_deck != null && _deck!.slides.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: ActionChip(
                avatar: const Icon(Icons.grid_view_rounded, size: 16),
                label: Text('${_currentSlideIndex + 1} / ${_deck!.slides.length}'),
                onPressed: _openSlideOverview,
              ),
            ),
          // View Mode Switcher: Visual Slides vs. Outline
          IconButton(
            tooltip: _viewMode == PresentationViewMode.slides
                ? l10n.slideOutlineMode
                : l10n.slidePresentationMode,
            icon: Icon(
              _viewMode == PresentationViewMode.slides
                  ? Icons.format_list_bulleted_rounded
                  : Icons.slideshow_rounded,
            ),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == PresentationViewMode.slides
                    ? PresentationViewMode.outline
                    : PresentationViewMode.slides;
              });
            },
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
                case 'slideshow':
                  _startSlideshow();
                  break;
                case 'mode_toggle':
                  setState(() {
                    _viewMode = _viewMode == PresentationViewMode.slides
                        ? PresentationViewMode.outline
                        : PresentationViewMode.slides;
                  });
                  break;
                case 'animations_toggle':
                  setState(() => _enableAnimations = !_enableAnimations);
                  break;
                case 'reset_zoom':
                  _resetZoom();
                  break;
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
                value: 'slideshow',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.play_arrow_rounded),
                  title: Text(l10n.playSlideshow),
                ),
              ),
              PopupMenuItem(
                value: 'mode_toggle',
                child: ListTile(
                  dense: true,
                  leading: Icon(_viewMode == PresentationViewMode.slides
                      ? Icons.format_list_bulleted_rounded
                      : Icons.slideshow_rounded),
                  title: Text(_viewMode == PresentationViewMode.slides
                      ? l10n.slideOutlineMode
                      : l10n.slidePresentationMode),
                ),
              ),
              PopupMenuItem(
                value: 'animations_toggle',
                child: ListTile(
                  dense: true,
                  leading: Icon(_enableAnimations ? Icons.animation_rounded : Icons.motion_photos_off_rounded),
                  title: Text(l10n.slideAnimations),
                  trailing: Icon(_enableAnimations ? Icons.check_rounded : null, size: 18),
                ),
              ),
              if (_viewMode == PresentationViewMode.slides)
                PopupMenuItem(
                  value: 'reset_zoom',
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.zoom_out_map_rounded),
                    title: Text(l10n.resetZoom),
                  ),
                ),
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
      onPageChanged: (idx) {
        setState(() {
          _currentSlideIndex = idx;
          _resetZoom();
        });
      },
      itemBuilder: (context, index) {
        final slide = _deck!.slides[index];
        final isCurrent = index == _currentSlideIndex;

        final cardWidget = _viewMode == PresentationViewMode.slides
            ? _buildSlidePresentationCard(slide, l10n)
            : _buildSlideOutlineCard(slide, l10n);

        return isCurrent ? RepaintBoundary(key: _slideCardKey, child: cardWidget) : cardWidget;
      },
    );
  }

  /// Authentic visual presentation slide view with exact layout, staggered animations, and pinch-to-zoom.
  Widget _buildSlidePresentationCard(PresentationSlide slide, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final totalSlides = _deck?.slides.length ?? 0;
    final aspectRatio = _deck?.aspectRatio ?? (16 / 9);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 5.0,
              clipBehavior: Clip.none,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: slide.backgroundColor ?? Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AspectRatio(
                      aspectRatio: aspectRatio,
                      child: SlideCanvasView(
                        key: ValueKey('slide_canvas_${slide.slideNumber}'),
                        slide: slide,
                        aspectRatio: aspectRatio,
                        themeColors: _deck?.themeColors ?? const {},
                        searchQuery: _searchQuery,
                        fontScale: _fontScale,
                        enableAnimations: _enableAnimations,
                        onImageTap: _viewImage,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Floating Reset Zoom Button when zoomed in
            if (_isZoomed)
              Positioned(
                top: 16,
                right: 20,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(20),
                  color: scheme.primaryContainer,
                  child: InkWell(
                    onTap: _resetZoom,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_out_map_rounded, size: 16, color: scheme.onPrimaryContainer),
                          const SizedBox(width: 6),
                          Text(
                            l10n.resetZoom,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Bottom Slide Overlay Banner (Title + Slide Number)
            Positioned(
              bottom: 12,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        EncodingUtils.cleanDisplayName(slide.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${slide.slideNumber} / $totalSlides',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Outline / note cards view for text-focused reading and copying.
  Widget _buildSlideOutlineCard(PresentationSlide slide, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final cleanSlideTitle = EncodingUtils.cleanDisplayName(slide.title);
    final totalSlides = _deck?.slides.length ?? 0;
    final densityScale = slide.bulletPoints.length > 6
        ? 0.88
        : (slide.bulletPoints.length > 4 ? 0.94 : 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _highlightedText(
                      cleanSlideTitle,
                      TextStyle(
                        fontSize: 20 * _fontScale,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                        color: scheme.onSurface,
                      ),
                      scheme,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      totalSlides > 0
                          ? '${slide.slideNumber} / $totalSlides'
                          : l10n.slideNumber(slide.slideNumber),
                      style: TextStyle(
                        fontSize: 11 * _fontScale,
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final point in slide.bulletPoints) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 10, top: 3),
                              child: Icon(
                                Icons.arrow_right_rounded,
                                size: 22,
                                color: scheme.primary,
                              ),
                            ),
                            Expanded(
                              child: _highlightedText(
                                point,
                                TextStyle(
                                  fontSize: 14.5 * _fontScale * densityScale,
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
                    if (slide.bulletPoints.isEmpty && slide.images.isEmpty && slide.elements.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
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
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: slide.images.map((img) {
                          return InkWell(
                            onTap: () => _viewImage(img),
                            borderRadius: BorderRadius.circular(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                                  ),
                                ),
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
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
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

/// Renders an authentic PowerPoint presentation slide canvas with full layout fidelity,
/// positioning, typography, colors, borders, and optional staggered entrance animations.
class SlideCanvasView extends StatelessWidget {
  const SlideCanvasView({
    super.key,
    required this.slide,
    required this.aspectRatio,
    required this.themeColors,
    this.searchQuery = '',
    this.fontScale = 1.0,
    this.enableAnimations = true,
    this.onImageTap,
  });

  final PresentationSlide slide;
  final double aspectRatio;
  final Map<String, Color> themeColors;
  final String searchQuery;
  final double fontScale;
  final bool enableAnimations;
  final void Function(Uint8List bytes)? onImageTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasW = constraints.maxWidth;
        final canvasH = constraints.maxHeight;

        // Base unit for PowerPoint coordinate rendering (normalized to 960pt reference)
        const referenceWidth = 960.0;
        final scale = (canvasW / referenceWidth) * fontScale;

        return Container(
          width: canvasW,
          height: canvasH,
          color: slide.backgroundColor ?? Colors.white,
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              // Slide background image if available
              if (slide.backgroundImage != null)
                Positioned.fill(
                  child: Image.memory(
                    slide.backgroundImage!,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),

              // Visual slide elements rendered in z-order
              for (int i = 0; i < slide.elements.length; i++)
                _buildSlideElement(context, slide.elements[i], canvasW, canvasH, scale, i),

              // Fallback if presentation has no visual elements parsed
              if (slide.elements.isEmpty)
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(24 * scale),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slide.title,
                          style: TextStyle(
                            fontSize: 24 * scale,
                            fontWeight: FontWeight.bold,
                            color: themeColors['dk1'] ?? Colors.black87,
                          ),
                        ),
                        SizedBox(height: 16 * scale),
                        for (final point in slide.bulletPoints)
                          Padding(
                            padding: EdgeInsets.only(bottom: 8 * scale),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ', style: TextStyle(fontSize: 16 * scale)),
                                Expanded(
                                  child: Text(
                                    point,
                                    style: TextStyle(fontSize: 16 * scale),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlideElement(
    BuildContext context,
    SlideElement elem,
    double canvasW,
    double canvasH,
    double scale,
    int index,
  ) {
    final left = elem.x * canvasW;
    final top = elem.y * canvasH;
    final width = elem.width * canvasW;
    final height = elem.height * canvasH;

    if (width <= 0 || height <= 0) return const SizedBox.shrink();

    Widget innerContent;

    if (elem is SlidePictureElement) {
      innerContent = Transform.rotate(
        angle: elem.rotation * (pi / 180.0),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () => onImageTap?.call(elem.imageBytes),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(elem.borderRadius * scale),
            child: Image.memory(
              elem.imageBytes,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
    } else if (elem is SlideShapeElement) {
      innerContent = Transform.rotate(
        angle: elem.rotation * (pi / 180.0),
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            color: elem.fillColor,
            border: elem.borderColor != null && elem.borderWidth > 0
                ? Border.all(
                    color: elem.borderColor!,
                    width: (elem.borderWidth * scale).clamp(0.5, 8.0),
                  )
                : null,
            borderRadius: elem.isCircle ? null : BorderRadius.circular(elem.borderRadius * scale),
            shape: elem.isCircle ? BoxShape.circle : BoxShape.rectangle,
          ),
          alignment: elem.verticalAlignment,
          padding: EdgeInsets.symmetric(
            horizontal: (width * 0.03).clamp(2.0, 10.0),
            vertical: (height * 0.03).clamp(2.0, 8.0),
          ),
          child: _buildShapeTextContent(elem, scale),
        ),
      );
    } else if (elem is SlideTableElement) {
      innerContent = _buildTable(elem, scale);
    } else {
      return const SizedBox.shrink();
    }

    final animatedChild = enableAnimations
        ? TweenAnimationBuilder<double>(
            key: ValueKey('anim_slide_${slide.slideNumber}_elem_$index'),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 320 + min(index * 60, 400)),
            curve: Interval(
              min(index * 60, 400) / (320 + min(index * 60, 400)),
              1.0,
              curve: Curves.easeOutCubic,
            ),
            builder: (context, val, child) {
              return Opacity(
                opacity: val.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 12 * (1.0 - val) * scale),
                  child: child,
                ),
              );
            },
            child: innerContent,
          )
        : innerContent;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: animatedChild,
    );
  }

  Widget _buildShapeTextContent(SlideShapeElement elem, double scale) {
    if (elem.paragraphs.isEmpty) return const SizedBox.shrink();

    final isDarkFill = elem.fillColor != null && elem.fillColor!.computeLuminance() < 0.4;
    final defaultColor = isDarkFill ? Colors.white : (themeColors['dk1'] ?? Colors.black87);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final para in elem.paragraphs)
          Padding(
            padding: EdgeInsets.only(
              top: para.spaceBefore * scale,
              bottom: para.spaceAfter * scale,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (para.isBullet)
                  Padding(
                    padding: EdgeInsetsDirectional.only(end: 4 * scale, top: 1 * scale),
                    child: Text(
                      para.bulletChar ?? '•',
                      style: TextStyle(
                        fontSize: (para.spans.firstOrNull?.fontSize ?? 14.0) * scale,
                        color: para.spans.firstOrNull?.fontColor ?? defaultColor,
                      ),
                    ),
                  ),
                Expanded(
                  child: RichText(
                    textAlign: para.alignment,
                    text: TextSpan(
                      children: [
                        for (final span in para.spans)
                          _buildTextSpan(span, scale, defaultColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  TextSpan _buildTextSpan(SlideTextSpan span, double scale, Color defaultColor) {
    final effectiveFontSize = (span.fontSize * scale).clamp(6.0, 72.0);
    final fontColor = span.fontColor ?? defaultColor;

    final baseStyle = TextStyle(
      fontSize: effectiveFontSize,
      color: fontColor,
      fontWeight: span.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: span.italic ? FontStyle.italic : FontStyle.normal,
      decoration: span.underline ? TextDecoration.underline : TextDecoration.none,
      fontFamily: span.fontFamily,
      height: 1.25,
    );

    if (searchQuery.isEmpty || !EncodingUtils.searchMatches(span.text, searchQuery)) {
      return TextSpan(text: span.text, style: baseStyle);
    }

    // Highlighting matching search terms
    final cleanQuery = EncodingUtils.removeDiacritics(searchQuery.toLowerCase());
    final cleanText = EncodingUtils.removeDiacritics(span.text.toLowerCase());
    final childSpans = <TextSpan>[];
    int start = 0;

    while (start < span.text.length) {
      final index = cleanText.indexOf(cleanQuery, start);
      if (index == -1) {
        childSpans.add(TextSpan(text: span.text.substring(start)));
        break;
      }
      if (index > start) {
        childSpans.add(TextSpan(text: span.text.substring(start, index)));
      }
      final matchEnd = index + cleanQuery.length;
      childSpans.add(
        TextSpan(
          text: span.text.substring(index, matchEnd),
          style: const TextStyle(
            backgroundColor: Colors.yellow,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = matchEnd;
    }

    return TextSpan(style: baseStyle, children: childSpans);
  }

  Widget _buildTable(SlideTableElement elem, double scale) {
    if (elem.rows.isEmpty) return const SizedBox.shrink();

    return Table(
      border: TableBorder.all(
        color: Colors.grey.withValues(alpha: 0.5),
        width: (1.0 * scale).clamp(0.5, 3.0),
      ),
      children: [
        for (final row in elem.rows)
          TableRow(
            children: [
              for (final cell in row)
                Container(
                  color: cell.fillColor,
                  padding: EdgeInsets.all(4 * scale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final p in cell.paragraphs)
                        RichText(
                          textAlign: p.alignment,
                          text: TextSpan(
                            children: [
                              for (final span in p.spans)
                                _buildTextSpan(
                                  span,
                                  scale,
                                  cell.fillColor != null && cell.fillColor!.computeLuminance() < 0.4
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Fullscreen immersive Slideshow Screen (Diaporama) with slide transitions and playback timer.
class PresentationSlideshowScreen extends StatefulWidget {
  const PresentationSlideshowScreen({
    super.key,
    required this.deck,
    this.initialSlideIndex = 0,
    required this.title,
  });

  final PresentationDeck deck;
  final int initialSlideIndex;
  final String title;

  @override
  State<PresentationSlideshowScreen> createState() => _PresentationSlideshowScreenState();
}

class _PresentationSlideshowScreenState extends State<PresentationSlideshowScreen> {
  late int _currentIndex;
  bool _showControls = true;
  bool _isAutoPlaying = false;
  Timer? _autoPlayTimer;
  Timer? _hideControlsTimer;
  final int _autoPlayIntervalSeconds = 4;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialSlideIndex.clamp(0, widget.deck.slides.length - 1);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scheduleHideControls();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _hideControlsTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  void _nextSlide() {
    if (_currentIndex < widget.deck.slides.length - 1) {
      setState(() => _currentIndex++);
    } else if (_isAutoPlaying) {
      setState(() => _currentIndex = 0); // loop in autoplay
    }
    if (_showControls) _scheduleHideControls();
  }

  void _prevSlide() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
    if (_showControls) _scheduleHideControls();
  }

  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlaying = !_isAutoPlaying;
      if (_isAutoPlaying) {
        _autoPlayTimer?.cancel();
        _autoPlayTimer = Timer.periodic(
          Duration(seconds: _autoPlayIntervalSeconds),
          (_) => _nextSlide(),
        );
      } else {
        _autoPlayTimer?.cancel();
      }
    });
    if (_showControls) _scheduleHideControls();
  }

  Widget _buildSlideTransition(Widget child, Animation<double> animation, PresentationSlide slide) {
    switch (slide.transitionType) {
      case SlideTransitionType.pushLeft:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
          child: child,
        );
      case SlideTransitionType.pushRight:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
          child: child,
        );
      case SlideTransitionType.pushUp:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
          child: child,
        );
      case SlideTransitionType.pushDown:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, -1.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
          child: child,
        );
      case SlideTransitionType.zoom:
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: FadeTransition(opacity: animation, child: child),
        );
      case SlideTransitionType.fade:
      case SlideTransitionType.wipe:
      default:
        return FadeTransition(opacity: animation, child: child);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slide = widget.deck.slides[_currentIndex];
    final totalSlides = widget.deck.slides.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -200) {
              _nextSlide();
            } else if (details.primaryVelocity! > 200) {
              _prevSlide();
            }
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Slide Canvas with active transition
            Center(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: slide.transitionDurationMs),
                transitionBuilder: (child, animation) => _buildSlideTransition(child, animation, slide),
                child: KeyedSubtree(
                  key: ValueKey('slideshow_slide_$_currentIndex'),
                  child: AspectRatio(
                    aspectRatio: widget.deck.aspectRatio,
                    child: SlideCanvasView(
                      slide: slide,
                      aspectRatio: widget.deck.aspectRatio,
                      themeColors: widget.deck.themeColors,
                      enableAnimations: true,
                    ),
                  ),
                ),
              ),
            ),

            // Tap navigation zones (left side = previous, right side = next)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 60,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _prevSlide,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 60,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _nextSlide,
                child: const SizedBox.expand(),
              ),
            ),

            // Top Overlay Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              top: _showControls ? 0 : -90,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 36, 16, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: l10n.exitSlideshow,
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        EncodingUtils.cleanDisplayName(widget.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / $totalSlides',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Overlay Controls
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              bottom: _showControls ? 0 : -90,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, size: 32, color: Colors.white),
                      onPressed: _currentIndex > 0 ? _prevSlide : null,
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(_isAutoPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      label: Text(_isAutoPlaying ? l10n.autoPlay : l10n.autoPlay),
                      onPressed: _toggleAutoPlay,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 32, color: Colors.white),
                      onPressed: _currentIndex < totalSlides - 1 ? _nextSlide : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
