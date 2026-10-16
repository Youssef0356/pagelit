import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/ad_banner.dart';
import '../services/reading_progress.dart';
import '../services/recent_files.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_stack.dart';
import '../widgets/pdf_glyph.dart';
import 'reader_screen.dart';
import 'settings_screen.dart';

const String _samplePdfPath = String.fromEnvironment('SAMPLE_PDF_PATH');

/// Landing screen: open a PDF or pick a recently opened one.
///
/// Also receives PDFs opened from other apps via the `pagelit/deeplink`
/// method channel (see MainActivity.kt).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _deeplinkChannel = MethodChannel('pagelit/deeplink');

  List<RecentFile> _recents = const [];
  Map<String, ReadingPosition> _progress = const {};

  /// Paths whose file is gone, measured once per load instead of on every
  /// rebuild (`existsSync` is a synchronous platform call).
  Set<String> _missingPaths = const {};
  bool _isLoading = true;
  bool _handledColdStartIntent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecents();
    if (_samplePdfPath.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (File(_samplePdfPath).existsSync()) {
          await _openReader(_samplePdfPath);
        }
      });
    }
    // Ask the platform for a shared PDF straight away: the channel call is
    // asynchronous, so it never delays the first frame, and MainActivity has
    // already started resolving the intent while Flutter was booting.
    _checkForSharedPdf();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle "open with" taps that happen while the app is already running.
    if (state == AppLifecycleState.resumed && _handledColdStartIntent) {
      _checkForSharedPdf();
    }
  }

  Future<void> _loadRecents() async {
    final files = await RecentFilesStore.load();
    final progress = await ReadingProgress.all();
    final missing = <String>{};
    for (final file in files) {
      if (!File(file.path).existsSync()) missing.add(file.path);
    }
    if (mounted) {
      setState(() {
        _recents = files;
        _progress = progress;
        _missingPaths = missing;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkForSharedPdf() async {
    String? path;
    try {
      path = await _deeplinkChannel.invokeMethod<String>('getInitialPdfPath');
    } on PlatformException {
      return;
    }
    _handledColdStartIntent = true;
    if (path != null && mounted && File(path).existsSync()) {
      await _openReader(path);
    }
  }

  Future<void> _pickFile() async {
    final results = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = results.isEmpty ? null : results.first.path;
    if (path != null && mounted) {
      await _openReader(path);
    }
  }

  /// The display name of a file path, decoding percent-encoding when valid.
  String _nameFor(String path) {
    final raw = path.split(RegExp(r'[/\\]')).last;
    try {
      return Uri.decodeComponent(raw);
    } on FormatException {
      // Malformed percent-encoding: keep the raw name instead of crashing.
      return raw;
    }
  }

  Future<void> _openReader(String path) async {
    final name = _nameFor(path);
    // Fire and forget: writing the recents list must never delay opening the
    // document (it re-reads and re-serialises every entry).
    unawaited(RecentFilesStore.add(path, name));
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(filePath: path, title: name),
      ),
    );
    await _loadRecents();
  }

  Future<void> _removeRecent(RecentFile file) async {
    await RecentFilesStore.remove(file.path);
    // Drop the stored position too, so the progress map does not keep
    // entries for documents the user no longer has in the list.
    await ReadingProgress.remove(file.path);
    await _loadRecents();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Small-caps metadata line shown under the file name.
  String _metaFor(RecentFile file) {
    final date = _formatDate(file.openedAt).toUpperCase();
    final pos = _progress[file.path];
    if (pos == null || pos.pages == 0) return date;
    return 'PAGE ${pos.page} OF ${pos.pages} · ${pos.percent}% · $date';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [PdfGlyph(size: 22), SizedBox(width: 10), Text('Pagelit')],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const _RecentsSkeleton()
                : _recents.isEmpty
                ? _EmptyState(onOpen: _pickFile)
                : _buildRecentsList(),
          ),
          _OpenDock(onOpen: _pickFile),
        ],
      ),
      bottomNavigationBar: const AdBanner(),
    );
  }

  Widget _buildRecentsList() {
    return SafeArea(
      bottom: false,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        itemCount: _recents.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                'RECENT FILES',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            );
          }
          final file = _recents[index - 1];
          final exists = !_missingPaths.contains(file.path);
          return Dismissible(
            key: ValueKey(file.path),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _removeRecent(file),
            background: _SwipeToDelete(),
            child: _RecentCard(
              name: file.name,
              meta: exists ? _metaFor(file) : 'FILE NOT FOUND',
              progress: _progress[file.path]?.progress ?? 0,
              exists: exists,
              onOpen: () =>
                  exists ? _openReader(file.path) : _removeRecent(file),
              onRemove: () => _removeRecent(file),
            ),
          );
        },
      ),
    );
  }
}

class _SwipeToDelete extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppShape.radiusLarge),
      ),
      child: Icon(
        Icons.delete_outline_rounded,
        color: scheme.onPrimaryContainer,
      ),
    );
  }
}

enum _CardAction { open, remove }

/// A recent file: page tile, name, small-caps metadata and a progress edge
/// pinned to the bottom of the card.
class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.name,
    required this.meta,
    required this.progress,
    required this.exists,
    required this.onOpen,
    required this.onRemove,
  });

  final String name;
  final String meta;
  final double progress;
  final bool exists;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppShape.radiusLarge),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0x0F17161C),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppShape.radiusLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 6, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FileTile(exists: exists),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(
                              decoration: exists
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(
                              color: exists ? null : scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<_CardAction>(
                      tooltip: 'File options',
                      icon: const Icon(Icons.more_horiz_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      onSelected: (action) => switch (action) {
                        _CardAction.open => onOpen(),
                        _CardAction.remove => onRemove(),
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _CardAction.open,
                          child: Text('Open'),
                        ),
                        PopupMenuItem(
                          value: _CardAction.remove,
                          child: Text('Remove'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (exists && progress > 0)
              SizedBox(
                height: 3,
                width: double.infinity,
                child: ColoredBox(
                  color: scheme.outlineVariant,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0).toDouble(),
                    child: const ColoredBox(color: AppPalette.signal),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The page tile on the left of a card: a tinted block with the Pagelit
/// glyph, echoing the folded-corner motif of the app icon.
class _FileTile extends StatelessWidget {
  const _FileTile({required this.exists});

  final bool exists;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      width: 56,
      height: 70,
      decoration: BoxDecoration(
        color: exists ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          exists
              ? const PdfGlyph(size: 26)
              : Icon(
                  Icons.question_mark_rounded,
                  size: 22,
                  color: scheme.outline,
                ),
          const SizedBox(height: 6),
          Text(
            'PDF',
            style: text.labelSmall?.copyWith(
              color: exists ? scheme.onPrimaryContainer : scheme.outline,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Docked call to action at the bottom of the home screen.
class _OpenDock extends StatelessWidget {
  const _OpenDock({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: EdgeInsets.fromLTRB(
          AppShape.gutter,
          12,
          AppShape.gutter,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        child: FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.folder_open_rounded, size: 20),
          label: const Text('Open PDF'),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PaperStack(),
            const SizedBox(height: 28),
            Text(
              'Welcome to Pagelit',
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Open a PDF to start reading.\n'
              'Highlight, underline, add sticky-note comments, share, '
              'or save pages to your gallery.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.file_open_rounded, size: 20),
              label: const Text('Open your first PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton preview of the recents list shown while it loads, so the layout
/// never pops in.
class _RecentsSkeleton extends StatefulWidget {
  const _RecentsSkeleton();

  @override
  State<_RecentsSkeleton> createState() => _RecentsSkeletonState();
}

class _RecentsSkeletonState extends State<_RecentsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainer;
    final highlight = scheme.surfaceContainerHigh;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final dx = -1.2 + 2.4 * _controller.value;
        final gradient = LinearGradient(
          colors: [base, highlight, base],
          stops: const [0.4, 0.5, 0.6],
          begin: Alignment(dx - 0.6, 0),
          end: Alignment(dx + 0.6, 0),
        );
        Widget block(double width, double height, double radius) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: gradient,
          ),
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 14),
              child: block(120, 12, 6),
            ),
            for (var i = 0; i < 4; i++) ...[
              block(double.infinity, 98, AppShape.radiusLarge),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}
