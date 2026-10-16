import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../ads/ad_banner.dart';
import '../services/reading_prefs.dart';
import '../services/reading_progress.dart';
import '../theme/app_theme.dart';
import '../widgets/pdf_glyph.dart';
import 'settings_screen.dart';

/// Colours offered for new and selected annotations.
const _annotationPalette = [
  Colors.yellow,
  Colors.orange,
  Colors.green,
  Colors.cyan,
  Colors.pink,
  Colors.purple,
  Colors.red,
];

/// Tool button size. 48px is Material's minimum comfortable touch target, and
/// six of them still fit a 360dp-wide card with gaps to aim at.
const _toolButtonSize = 48.0;

/// The PDF reader: viewing, annotating (highlight/underline/strikethrough/
/// squiggly/comment), sharing and saving pages to the gallery.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.filePath, required this.title});

  final String filePath;
  final String title;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

enum _Tool { pan, highlight, underline, strikethrough, squiggly, comment }

class _ReaderScreenState extends State<ReaderScreen> {
  final PdfViewerController _controller = PdfViewerController();
  final GlobalKey _viewerKey = GlobalKey();
  final TextEditingController _commentInput = TextEditingController();
  final TextEditingController _searchFieldController = TextEditingController();
  final TextEditingController _jumpInput = TextEditingController();

  /// Annotations added in this session, newest last (for undo).
  final List<Annotation> _addedAnnotations = [];

  _Tool _tool = _Tool.pan;
  Color _color = ReadingPrefs.annotationColor.value;
  int _pageNumber = 1;
  int _pageCount = 0;
  bool _isLoaded = false;
  bool _isBusy = false;
  bool _isSearchOpen = false;

  /// Annotation currently selected in pan mode (offered for recolour/delete).
  Annotation? _selectedAnnotation;

  /// Full-screen reading: no app bar, no toolbar, no system bars.
  bool _immersive = false;
  PdfTextSearchResult? _searchResult;
  Timer? _progressDebounce;

  static const List<Color> _palette = [
    Colors.yellow,
    Colors.orange,
    Colors.green,
    Colors.cyan,
    Colors.pink,
    Colors.purple,
    Colors.red,
  ];

  /// Built once and never rebuilt by parent [setState] calls — the viewer is
  /// the most expensive subtree on this screen, and rebuilding it on every
  /// page change / search tick / annotation would be pure waste.
  late final SfPdfViewer _viewer = SfPdfViewer.file(
    File(widget.filePath),
    controller: _controller,
    // Applied at open time: changing the layout later would rebuild the
    // viewer and lose in-session annotations, so Settings says as much.
    pageLayoutMode: ReadingPrefs.layoutMode.value,
    onDocumentLoaded: (details) {
      _controller.annotationSettings.author = 'Pagelit';
      _applyColorToSettings(_color);
      setState(() {
        _isLoaded = true;
        _pageCount = _controller.pageCount;
      });
      _restorePosition();
    },
    onDocumentLoadFailed: (details) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open PDF: ${details.error}')),
      );
      // Don't leave the user staring at a blank reader.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    },
    onPageChanged: (details) {
      setState(() => _pageNumber = details.newPageNumber);
      _scheduleProgressSave();
    },
    onAnnotationAdded: _onAnnotationAdded,
    onAnnotationRemoved: _onAnnotationRemoved,
    onAnnotationSelected: _onAnnotationSelected,
    onAnnotationDeselected: _onAnnotationDeselected,
  );

  @override
  void initState() {
    super.initState();
    ReadingPrefs.keepScreenOn.addListener(_applyKeepScreenOn);
    _applyKeepScreenOn();
  }

  @override
  void dispose() {
    ReadingPrefs.keepScreenOn.removeListener(_applyKeepScreenOn);
    unawaited(WakelockPlus.disable());
    _progressDebounce?.cancel();
    _saveProgress(); // Persist the final position on exit.
    _commentInput.dispose();
    _searchFieldController.dispose();
    _jumpInput.dispose();
    _searchResult?.removeListener(_onSearchResultChanged);
    super.dispose();
  }

  /// "Keep screen on" only applies while a document is actually open.
  void _applyKeepScreenOn() {
    if (ReadingPrefs.keepScreenOn.value) {
      unawaited(WakelockPlus.enable());
    } else {
      unawaited(WakelockPlus.disable());
    }
  }

  // ------------------------------------------------------------- progress

  void _saveProgress() {
    if (_pageCount > 0) {
      ReadingProgress.save(widget.filePath, _pageNumber, _pageCount);
    }
  }

  void _scheduleProgressSave() {
    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(milliseconds: 700), _saveProgress);
  }

  Future<void> _restorePosition() async {
    final saved = await ReadingProgress.get(widget.filePath);
    if (!mounted || saved == null || saved.page <= 1) return;
    if (saved.page <= _controller.pageCount) {
      _controller.jumpToPage(saved.page);
    }
  }

  /// Jump-to-page prompt, opened by tapping the page pill in the app bar.
  Future<void> _promptJumpToPage() async {
    if (!_isLoaded || _pageCount <= 1) return;
    _jumpInput.text = '$_pageNumber';
    final target = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          controller: _jumpInput,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: 'Page number',
            border: OutlineInputBorder(),
            suffixText: 'of',
          ),
          onSubmitted: (value) =>
              Navigator.of(context).pop(int.tryParse(value)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(_jumpInput.text)),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (!mounted || target == null) return;
    if (target < 1 || target > _pageCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Page must be between 1 and $_pageCount')),
      );
      return;
    }
    HapticFeedback.selectionClick();
    _controller.jumpToPage(target);
  }

  // ---------------------------------------------------------------- search

  void _toggleSearch() {
    if (_isSearchOpen) {
      _closeSearch();
      return;
    }
    setState(() => _isSearchOpen = true);
  }

  void _performSearch(String query) {
    final trimmed = query.trim();
    if (!_isLoaded || trimmed.isEmpty) return;
    _searchResult?.removeListener(_onSearchResultChanged);
    _searchResult?.clear();
    final result = _controller.searchText(trimmed);
    _searchResult = result;
    result.addListener(_onSearchResultChanged);
    if (mounted) setState(() {});
  }

  void _onSearchResultChanged() {
    if (mounted) setState(() {});
  }

  void _closeSearch() {
    _searchResult?.removeListener(_onSearchResultChanged);
    _searchResult?.clear();
    _searchResult = null;
    _searchFieldController.clear();
    if (mounted) setState(() => _isSearchOpen = false);
  }

  // ---------------------------------------------------------------- tools

  void _setTool(_Tool tool) {
    if (!_isLoaded) return;
    HapticFeedback.selectionClick();
    setState(() => _tool = tool);
    _controller.annotationMode = switch (tool) {
      _Tool.pan => PdfAnnotationMode.none,
      _Tool.highlight => PdfAnnotationMode.highlight,
      _Tool.underline => PdfAnnotationMode.underline,
      _Tool.strikethrough => PdfAnnotationMode.strikethrough,
      _Tool.squiggly => PdfAnnotationMode.squiggly,
      _Tool.comment => PdfAnnotationMode.stickyNote,
    };
  }

  void _setColor(Color color) {
    HapticFeedback.selectionClick();
    setState(() => _color = color);
    if (_isLoaded) _applyColorToSettings(color);
  }

  /// Applies the palette color to every annotation type, so the chosen color
  /// sticks when the user switches between tools.
  void _applyColorToSettings(Color color) {
    final settings = _controller.annotationSettings;
    settings.highlight.color = color;
    settings.underline.color = color;
    settings.strikethrough.color = color;
    settings.squiggly.color = color;
    settings.stickyNote.color = color;
  }

  // ------------------------------------------------------------- selection

  /// Tapping an existing annotation in pan mode selects it and offers
  /// recolour / delete, instead of leaving it undeletable until undo.
  void _onAnnotationSelected(Annotation annotation) {
    if (mounted) setState(() => _selectedAnnotation = annotation);
  }

  void _onAnnotationDeselected(Annotation annotation) {
    if (mounted && identical(_selectedAnnotation, annotation)) {
      setState(() => _selectedAnnotation = null);
    }
  }

  void _deleteSelected() {
    final annotation = _selectedAnnotation;
    if (annotation == null) return;
    HapticFeedback.mediumImpact();
    // Also drops it from the undo stack via onAnnotationRemoved.
    _controller.removeAnnotation(annotation);
    setState(() => _selectedAnnotation = null);
  }

  void _recolorSelected(Color color) {
    final annotation = _selectedAnnotation;
    if (annotation == null) return;
    HapticFeedback.selectionClick();
    annotation.color = color;
    setState(() => _color = color);
  }

  // ------------------------------------------------------------- reading

  /// Full-screen reading: hides the app bar, the toolbar and the system bars.
  void _toggleImmersive() {
    if (!_isLoaded) return;
    HapticFeedback.selectionClick();
    if (!_immersive && _tool != _Tool.pan) _setTool(_Tool.pan);
    if (!_immersive && _isSearchOpen) _closeSearch();
    setState(() => _immersive = !_immersive);
    SystemChrome.setEnabledSystemUIMode(
      _immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  void _undo() {
    if (_addedAnnotations.isEmpty) return;
    final annotation = _addedAnnotations.removeLast();
    _controller.removeAnnotation(annotation);
    _refreshCommentCount();
  }

  // ------------------------------------------------------------ annotations

  void _onAnnotationAdded(Annotation annotation) {
    _addedAnnotations.add(annotation);
    if (annotation is StickyNoteAnnotation) {
      // A tap in comment mode creates an empty note: let the user write the
      // actual comment. Cancelling removes the note again.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _promptCommentText(annotation),
      );
    }
    _refreshCommentCount();
  }

  void _onAnnotationRemoved(Annotation annotation) {
    _addedAnnotations.remove(annotation);
    _refreshCommentCount();
  }

  Future<void> _promptCommentText(StickyNoteAnnotation annotation) async {
    _commentInput.clear();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add comment'),
        content: TextField(
          controller: _commentInput,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Write a note about this spot…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_commentInput.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final trimmed = text?.trim();
    if (!mounted) return;
    if (trimmed == null || trimmed.isEmpty) {
      _controller.removeAnnotation(annotation);
      _addedAnnotations.remove(annotation);
      _refreshCommentCount();
    } else {
      annotation.text = trimmed;
      _refreshCommentCount();
    }
  }

  List<StickyNoteAnnotation> get _comments =>
      _controller.getAnnotations().whereType<StickyNoteAnnotation>().toList();

  void _refreshCommentCount() {
    if (mounted) setState(() {});
  }

  Future<void> _openCommentsSheet() async {
    if (!mounted) return;
    if (_comments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No comments yet. Tap with the comment tool to add one.',
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) =>
          SafeArea(child: _CommentsSheet(controller: _controller)),
    );
    // The sheet deletes notes without closing: refresh the comment badge.
    _refreshCommentCount();
  }

  // ----------------------------------------------------------------- share

  String get _baseName =>
      widget.title.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');

  Future<void> _sharePdf() async {
    if (!_isLoaded || _isBusy) return;
    setState(() => _isBusy = true);
    try {
      // saveDocument returns the document bytes including all annotations.
      final bytes = await _controller.saveDocument();
      final dir = await getTemporaryDirectory();
      final outFile = File(
        '${dir.path}${Platform.pathSeparator}${_baseName}_annotated.pdf',
      );
      await outFile.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(outFile.path, mimeType: 'application/pdf')],
          title: widget.title,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not share: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Saves a copy of the PDF with all annotations baked in, letting the user
  /// pick the destination via the system save dialog (Storage Access
  /// Framework on Android, so no storage permission is needed).
  Future<void> _saveAnnotatedCopy() async {
    if (!_isLoaded || _isBusy) return;
    setState(() => _isBusy = true);
    try {
      final bytes = await _controller.saveDocument();
      final savedPath = await FileSaver.instance.saveFile(
        name: '${_baseName}_annotated',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to $savedPath'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // --------------------------------------------------------------- gallery

  Future<void> _savePageToGallery() async {
    if (!_isLoaded || _isBusy) return;
    setState(() => _isBusy = true);
    // Read the ratio before the first await: context must not be used after it.
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    try {
      final boundary =
          _viewerKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw 'Viewer is not ready yet';
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? png = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      if (png == null) throw 'Could not capture the page';

      final hasAccess = await Gal.hasAccess() || await Gal.requestAccess();
      if (!hasAccess) throw 'Gallery permission denied';

      await Gal.putImageBytes(
        png.buffer.asUint8List(),
        name: 'Pagelit_page_${_controller.pageNumber}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'View of page ${_controller.pageNumber} saved to gallery',
            ),
          ),
        );
      }
    } on GalException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: ${e.type.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ----------------------------------------------------------------- build

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final result = _searchResult;
    final hasMatches =
        result != null &&
        result.isSearchCompleted &&
        result.totalInstanceCount > 0;
    final status = result == null || !result.isSearchCompleted
        ? ''
        : result.totalInstanceCount == 0
        ? 'No results'
        : '${result.currentInstanceIndex} / ${result.totalInstanceCount}';
    return Material(
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Close search',
              icon: const Icon(Icons.close_rounded, size: 22),
              onPressed: _closeSearch,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: TextField(
                  controller: _searchFieldController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  style: text.bodyMedium,
                  cursorColor: colorScheme.primary,
                  decoration: InputDecoration(
                    hintText: 'Search in document',
                    hintStyle: text.bodyMedium?.copyWith(
                      color: colorScheme.outline,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onSubmitted: _performSearch,
                  onChanged: (value) {
                    // Clear results when the field is emptied.
                    if (value.trim().isEmpty && _searchResult != null) {
                      _searchResult?.removeListener(_onSearchResultChanged);
                      _searchResult?.clear();
                      _searchResult = null;
                      setState(() {});
                    }
                  },
                ),
              ),
            ),
            if (status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _MatchBadge(
                  label: status,
                  empty: status == 'No results',
                ),
              ),
            IconButton(
              tooltip: 'Previous match',
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              onPressed: hasMatches
                  ? () => _searchResult!.previousInstance()
                  : null,
            ),
            IconButton(
              tooltip: 'Next match',
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onPressed: hasMatches
                  ? () => _searchResult!.nextInstance()
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _immersive
          ? null
          : AppBar(
              title: Row(
                children: [
                  const PdfGlyph(size: 22),
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
                if (_pageCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _PagePill(
                      label: '$_pageNumber / $_pageCount',
                      onTap: _promptJumpToPage,
                    ),
                  ),
                IconButton(
                  tooltip: 'Search',
                  icon: Icon(
                    _isSearchOpen
                        ? Icons.search_off_rounded
                        : Icons.search_rounded,
                  ),
                  onPressed: _isLoaded ? _toggleSearch : null,
                ),
                IconButton(
                  tooltip: 'Comments',
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  onPressed: _openCommentsSheet,
                ),
                IconButton(
                  tooltip: 'Share PDF',
                  icon: const Icon(Icons.share_rounded),
                  onPressed: _isBusy ? null : _sharePdf,
                ),
                IconButton(
                  tooltip: 'Full screen',
                  icon: const Icon(Icons.fullscreen_rounded),
                  onPressed: _isLoaded ? _toggleImmersive : null,
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert_rounded),
                  enabled: _isLoaded && !_isBusy,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'save_copy',
                      child: ListTile(
                        leading: Icon(Icons.save_as_rounded),
                        title: Text('Save annotated copy'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'gallery',
                      child: ListTile(
                        leading: Icon(Icons.add_photo_alternate_rounded),
                        // The viewer exposes no per-page geometry, so what is
                        // captured is the current view (which may span two pages).
                        title: Text('Save current view to gallery'),
                      ),
                    ),
                    const PopupMenuDivider(),
                    for (final entry in const {
                      ComfortMode.normal: 'Normal',
                      ComfortMode.sepia: 'Sepia',
                      ComfortMode.dim: 'Dim',
                    }.entries)
                      PopupMenuItem(
                        value: 'comfort_${entry.key.name}',
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: ReadingPrefs.comfortMode.value == entry.key
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    )
                                  : null,
                            ),
                            Text(entry.value),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'settings',
                      child: ListTile(
                        leading: Icon(Icons.settings_outlined),
                        title: Text('Settings'),
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'save_copy':
                        _saveAnnotatedCopy();
                      case 'gallery':
                        _savePageToGallery();
                      case 'comfort_normal':
                        ReadingPrefs.setComfortMode(ComfortMode.normal);
                      case 'comfort_sepia':
                        ReadingPrefs.setComfortMode(ComfortMode.sepia);
                      case 'comfort_dim':
                        ReadingPrefs.setComfortMode(ComfortMode.dim);
                      case 'settings':
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                    }
                  },
                ),
              ],
            ),
      body: Column(
        children: [
          if (_isSearchOpen && !_immersive) _buildSearchBar(),
          Expanded(child: _buildViewerArea()),
        ],
      ),
      bottomNavigationBar: _immersive ? null : _buildBottomBar(),
    );
  }

  /// The PDF plus its comfort tint and, in full-screen mode, the two minimal
  /// controls needed to read (exit and page position).
  Widget _buildViewerArea() {
    return ValueListenableBuilder<ComfortMode>(
      valueListenable: ReadingPrefs.comfortMode,
      builder: (context, comfort, _) => Stack(
        fit: StackFit.expand,
        children: [
          // The viewer widget is created once and reused: every setState in
          // this screen (page changes, search results, annotations) then
          // skips rebuilding the PDF view entirely.
          RepaintBoundary(key: _viewerKey, child: _viewer),
          // Comfort tints: cheap translucent layers over the page only, so
          // the toolbar keeps its exact colours.
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: comfort == ComfortMode.sepia ? 0.20 : 0,
            child: const IgnorePointer(
              child: ColoredBox(color: Color(0xFFE0C489)),
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: comfort == ComfortMode.dim ? 0.42 : 0,
            child: const IgnorePointer(child: ColoredBox(color: Colors.black)),
          ),
          if (!_isLoaded) const _OpeningPlaceholder(),
          if (_immersive) ...[
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: IconButton(
                  tooltip: 'Exit full screen',
                  style: IconButton.styleFrom(backgroundColor: Colors.black38),
                  icon: const Icon(
                    Icons.fullscreen_exit_rounded,
                    color: Colors.white,
                  ),
                  onPressed: _toggleImmersive,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: _PagePill(
                    label: '$_pageNumber / $_pageCount',
                    onTap: _promptJumpToPage,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Shown while an annotation is selected in pan mode: recolour it or throw
  /// it away, so a stray highlight no longer needs an undo to get rid of.
  Widget _buildSelectionBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppShape.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: colorScheme.brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.35)
                  : const Color(0x1A17161C),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: colorScheme.surfaceContainerLowest,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShape.radiusLarge),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 36px hit targets (7 × 36 + a 44px delete fits a 360dp card).
                for (final color in _annotationPalette)
                  InkWell(
                    onTap: () => _recolorSelected(color),
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 36,
                      height: 44,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  _selectedAnnotation?.color.toARGB32() ==
                                          color.toARGB32() ||
                                      (_selectedAnnotation == null &&
                                          _color.toARGB32() == color.toARGB32())
                                  ? colorScheme.onSurface
                                  : colorScheme.outlineVariant,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    tooltip: 'Delete annotation',
                    icon: const Icon(Icons.delete_outline_rounded, size: 21),
                    onPressed: _deleteSelected,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final colorScheme = Theme.of(context).colorScheme;
    Widget toolButton(_Tool tool, IconData icon, String tooltip) {
      final selected = _tool == tool;
      return Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: () => _setTool(tool),
          // IconButton's default constraints + 8px padding would pad the
          // target *inside* the button, stealing space from every gap; the
          // AnimatedContainer below is the whole (48px) hit target.
          constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          icon: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: _toolButtonSize,
            height: _toolButtonSize,
            decoration: BoxDecoration(
              color: selected ? colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppShape.radiusSmall),
            ),
            child: Icon(
              icon,
              size: 21,
              color: selected ? Colors.white : colorScheme.onSurface,
            ),
          ),
        ),
      );
    }

    /// 24px dot, 36px hit target — the visible swatch stays small while the
    /// finger gets something comfortable to land on. Seven of them plus Undo
    /// have to fit a 360dp card, which leaves ~36px each after the icon.
    Widget swatch(Color color) {
      final selected = _color.toARGB32() == color.toARGB32();
      return InkWell(
        onTap: () => _setColor(color),
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? colorScheme.onSurface
                      : colorScheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final selected = _selectedAnnotation;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: selected == null
                ? const SizedBox(width: double.infinity, height: 0)
                : _buildSelectionBar(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppShape.radiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.35)
                        : const Color(0x1A17161C),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: colorScheme.surfaceContainerLowest,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppShape.radiusLarge),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoaded && _pageCount > 1) _buildScrubber(),
                    if (_isLoaded && _pageCount > 1)
                      Divider(
                        indent: 14,
                        endIndent: 14,
                        color: colorScheme.outlineVariant,
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      // Tools sit on their own row so every button is a real
                      // 46px tap target that never scrolls out from under the
                      // finger: 6 tools + palette + undo overflowed a 360dp
                      // card by ~180px when forced into a single strip.
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          toolButton(
                            _Tool.pan,
                            Icons.pan_tool_alt_rounded,
                            'Read / pan',
                          ),
                          toolButton(
                            _Tool.highlight,
                            Icons.highlight_rounded,
                            'Highlight',
                          ),
                          toolButton(
                            _Tool.underline,
                            Icons.format_underlined_rounded,
                            'Underline',
                          ),
                          toolButton(
                            _Tool.strikethrough,
                            Icons.format_strikethrough_rounded,
                            'Strikethrough',
                          ),
                          toolButton(
                            _Tool.squiggly,
                            Icons.waves_rounded,
                            'Squiggly',
                          ),
                          toolButton(
                            _Tool.comment,
                            Icons.sticky_note_2_rounded,
                            'Comment',
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      indent: 14,
                      endIndent: 14,
                      height: 1,
                      color: colorScheme.outlineVariant,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Tooltip(
                            message: 'Annotation colour',
                            child: Icon(
                              Icons.palette_outlined,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 6),
                          for (final color in _palette) swatch(color),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Undo',
                            icon: const Icon(Icons.undo_rounded, size: 21),
                            onPressed: _addedAnnotations.isEmpty ? null : _undo,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const AdBanner(),
        ],
      ),
    );
  }

  Widget _buildScrubber() {
    final page = _pageNumber.clamp(1, _pageCount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          Text('$_pageNumber', style: Theme.of(context).textTheme.labelSmall),
          Expanded(
            child: Slider(
              value: page.toDouble(),
              min: 1,
              max: _pageCount.toDouble(),
              divisions: _pageCount > 1 ? _pageCount - 1 : null,
              onChanged: (value) => setState(() => _pageNumber = value.round()),
              onChangeEnd: (value) => _controller.jumpToPage(value.round()),
            ),
          ),
          Text('$_pageCount', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Lists the document's sticky notes. Deleting one refreshes the list in
/// place instead of dismissing the sheet.
class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.controller});

  final PdfViewerController controller;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  late final List<StickyNoteAnnotation> _notes = widget.controller
      .getAnnotations()
      .whereType<StickyNoteAnnotation>()
      .toList();

  void _delete(StickyNoteAnnotation note) {
    // Also drops the note from the undo stack via onAnnotationRemoved.
    widget.controller.removeAnnotation(note);
    setState(() => _notes.remove(note));
    if (_notes.isEmpty) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_notes.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('No comments left')),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        return ListTile(
          leading: Icon(Icons.sticky_note_2_rounded, color: note.color),
          title: Text(note.text, maxLines: 3, overflow: TextOverflow.ellipsis),
          subtitle: Text('Page ${note.pageNumber}'),
          trailing: IconButton(
            tooltip: 'Delete comment',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _delete(note),
          ),
          onTap: () {
            Navigator.of(context).pop();
            widget.controller.jumpToPage(note.pageNumber);
          },
        );
      },
    );
  }
}

/// Tappable "12 / 340" pill in the reader app bar; opens the jump-to-page
/// prompt.
class _PagePill extends StatelessWidget {
  const _PagePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Tooltip(
      message: 'Go to page',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Text(
            label,
            style: text.labelMedium?.copyWith(color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Small pill showing the search match counter.
class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.label, required this.empty});

  final String label;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: empty ? scheme.surfaceContainer : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        label,
        style: text.labelSmall?.copyWith(
          color: empty ? scheme.outline : scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// Shown over the viewer while the document is being parsed, so opening a
/// large PDF feels instant instead of showing a blank page.
class _OpeningPlaceholder extends StatelessWidget {
  const _OpeningPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PdfGlyph(size: 40),
            const SizedBox(height: 18),
            Text('Opening document…', style: text.titleSmall),
            const SizedBox(height: 14),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHigh,
                minHeight: 3,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
