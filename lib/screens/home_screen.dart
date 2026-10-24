import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/ad_banner.dart';
import '../services/device_pdfs.dart';
import '../services/encoding_utils.dart';
import '../services/reading_progress.dart';
import '../services/recent_files.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_stack.dart';
import '../widgets/pdf_glyph.dart';
import 'excel_viewer_screen.dart';
import 'presentation_viewer_screen.dart';
import 'reader_screen.dart';
import 'settings_screen.dart';
import 'word_viewer_screen.dart';

const String _samplePdfPath = String.fromEnvironment('SAMPLE_PDF_PATH');

enum SortMode { date, name, size }

/// Landing screen: open a document or pick a recently opened one.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _deeplinkChannel = MethodChannel('pagelit/deeplink');

  List<RecentFile> _recents = const [];
  Map<String, ReadingPosition> _progress = const {};

  /// Documents found on the device ("ON THIS DEVICE"), newest first.
  List<DevicePdf> _devicePdfs = const [];

  /// Folders the user chose through the system folder picker.
  List<String> _deviceFolders = const [];
  bool _hasAllFilesAccess = false;
  bool _deviceLoading = true;

  /// Paths whose file is gone.
  Set<String> _missingPaths = const {};
  bool _isLoading = true;
  bool _handledColdStartIntent = false;

  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortMode _sortMode = SortMode.date;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecents();
    _loadDevicePdfs();
    if (_samplePdfPath.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (File(_samplePdfPath).existsSync()) {
          await _openReader(_samplePdfPath);
        }
      });
    }
    _checkForSharedPdf();
  }

  @override
  void dispose() {
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_handledColdStartIntent) {
      _checkForSharedPdf();
    }
    _loadDevicePdfs(showSpinner: false);
  }

  Future<void> _loadDevicePdfs({bool showSpinner = true}) async {
    if (mounted && showSpinner) {
      setState(() => _deviceLoading = true);
    }
    final folders = await DevicePdfLibrary.loadFolders();
    final hasAccess = await DevicePdfLibrary.hasAllFilesAccess();
    final pdfs = await DevicePdfLibrary.listPdfs(folders);
    if (!mounted) return;
    setState(() {
      _deviceFolders = folders;
      _hasAllFilesAccess = hasAccess;
      _devicePdfs = pdfs;
      _deviceLoading = false;
    });
  }

  Future<void> _grantAllFilesAccess() async {
    final requested = await DevicePdfLibrary.requestAllFilesAccess();
    if (requested || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Choose a folder so Pagelit can find your PDFs.'),
      ),
    );
    await _addDeviceFolder();
  }

  Future<void> _addDeviceFolder() async {
    await DevicePdfLibrary.addFolder();
    await _loadDevicePdfs();
  }

  Future<void> _manageFolders() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open_rounded, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Scanned Folders',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Add folder',
                      icon: const Icon(Icons.create_new_folder_outlined),
                      onPressed: () async {
                        await DevicePdfLibrary.addFolder();
                        final updated = await DevicePdfLibrary.loadFolders();
                        setSheetState(() => _deviceFolders = updated);
                        await _loadDevicePdfs(showSpinner: false);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_deviceFolders.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No custom folders added yet.\nTap the + button to select a folder to scan.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _deviceFolders.length,
                    itemBuilder: (context, index) {
                      final uri = _deviceFolders[index];
                      final decoded = Uri.decodeComponent(uri.split('/').last);
                      return ListTile(
                        leading: const Icon(Icons.folder_rounded),
                        title: Text(
                          decoded.isEmpty ? uri : decoded,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          uri,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove folder',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            await DevicePdfLibrary.removeFolder(uri);
                            final updated = await DevicePdfLibrary.loadFolders();
                            setSheetState(() => _deviceFolders = updated);
                            await _loadDevicePdfs(showSpinner: false);
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await _loadDevicePdfs(showSpinner: false);
  }

  Future<void> _openDevicePdf(DevicePdf pdf) async {
    final path = await DevicePdfLibrary.openPath(pdf);
    if (!mounted) return;
    if (path == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open that document.')));
      return;
    }
    await _openReader(path);
    await _loadDevicePdfs(showSpinner: false);
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
      allowedExtensions: const ['pdf', 'docx', 'xlsx', 'pptx', 'doc', 'xls', 'ppt'],
    );
    final path = results.isEmpty ? null : results.first.path;
    if (path != null && mounted) {
      await _openReader(path);
    }
  }

  String _nameFor(String path) {
    final raw = path.split(RegExp(r'[/\\]')).last;
    return EncodingUtils.cleanDisplayName(raw);
  }

  Future<void> _openReader(String path) async {
    final name = _nameFor(path);
    unawaited(RecentFilesStore.add(path, name));
    if (!mounted) return;

    final ext = path.split('.').last.toLowerCase();
    if (ext == 'docx' || ext == 'doc') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WordViewerScreen(filePath: path, title: name),
        ),
      );
    } else if (ext == 'xlsx' || ext == 'xls') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExcelViewerScreen(filePath: path, title: name),
        ),
      );
    } else if (ext == 'pptx' || ext == 'ppt') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PresentationViewerScreen(filePath: path, title: name),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReaderScreen(filePath: path, title: name),
        ),
      );
    }
    await _loadRecents();
  }

  Future<void> _removeRecent(RecentFile file) async {
    await RecentFilesStore.remove(file.path);
    await ReadingProgress.remove(file.path);
    await _loadRecents();
  }

  void _showFileDetails({
    required String name,
    required String? path,
    required int size,
    required DateTime? modified,
  }) {
    final ext = name.split('.').last.toUpperCase();
    final typeDesc = switch (ext) {
      'PDF' => 'PDF Document',
      'DOCX' || 'DOC' => 'Microsoft Word Document',
      'XLSX' || 'XLS' => 'Microsoft Excel Spreadsheet',
      'PPTX' || 'PPT' => 'Microsoft PowerPoint Presentation',
      _ => '$ext File',
    };

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Name', name),
            const SizedBox(height: 10),
            _detailRow('Type', typeDesc),
            const SizedBox(height: 10),
            _detailRow('Size', _formatSize(size)),
            if (modified != null) ...[
              const SizedBox(height: 10),
              _detailRow('Modified', '${modified.day}/${modified.month}/${modified.year} ${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}'),
            ],
            if (path != null && path.isNotEmpty) ...[
              const SizedBox(height: 10),
              _detailRow('Location', path, isSelectable: true),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isSelectable = false}) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 2),
        isSelectable
            ? SelectableText(value, style: text.bodyMedium)
            : Text(value, style: text.bodyMedium),
      ],
    );
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

  String _metaFor(RecentFile file) {
    final date = _formatDate(file.openedAt).toUpperCase();
    final pos = _progress[file.path];
    if (pos == null || pos.pages == 0) return date;
    return 'PAGE ${pos.page} OF ${pos.pages} · ${pos.percent}% · $date';
  }

  String _deviceMetaFor(DevicePdf pdf) {
    final size = _formatSize(pdf.size);
    final date = _formatDate(pdf.modified).toUpperCase();
    final path = pdf.path;
    final pos = path == null ? null : _progress[path];
    if (pos == null || pos.pages == 0) return '$size · $date';
    return 'PAGE ${pos.page} OF ${pos.pages} · ${pos.percent}% · $size';
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '—';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = unit == 0 || value >= 100 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unit]}';
  }

  List<DevicePdf> get _filteredDevicePdfs {
    var list = _devicePdfs;
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) => EncodingUtils.searchMatches(p.name, _searchQuery)).toList();
    }
    switch (_sortMode) {
      case SortMode.date:
        list.sort((a, b) => b.modified.compareTo(a.modified));
      case SortMode.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case SortMode.size:
        list.sort((a, b) => b.size.compareTo(a.size));
    }
    return list;
  }

  List<RecentFile> get _filteredRecents {
    var list = _recents;
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) => EncodingUtils.searchMatches(p.name, _searchQuery)).toList();
    }
    switch (_sortMode) {
      case SortMode.date:
        list.sort((a, b) => b.openedAt.compareTo(a.openedAt));
      case SortMode.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case SortMode.size:
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [PdfGlyph(size: 22), SizedBox(width: 10), Text('Pagelit')],
        ),
        actions: [
          IconButton(
            tooltip: 'Search documents',
            icon: Icon(_isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _isSearchOpen = !_isSearchOpen;
              if (!_isSearchOpen) {
                _searchQuery = '';
                _searchController.clear();
              }
            }),
          ),
          PopupMenuButton<SortMode>(
            tooltip: 'Sort by',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sortMode,
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: SortMode.date,
                child: Text('Date (Newest first)'),
              ),
              PopupMenuItem(
                value: SortMode.name,
                child: Text('Name (A–Z)'),
              ),
              PopupMenuItem(
                value: SortMode.size,
                child: Text('File Size (Largest first)'),
              ),
            ],
          ),
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
          if (_isSearchOpen)
            Container(
              color: scheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search files by name...',
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
          _OpenDock(onOpen: _pickFile),
        ],
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        left: false,
        right: false,
        child: AdBanner(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _RecentsSkeleton();
    final nothingYet =
        _recents.isEmpty &&
        _devicePdfs.isEmpty &&
        !_hasAllFilesAccess &&
        _deviceFolders.isEmpty &&
        !_deviceLoading;
    if (nothingYet) {
      return _EmptyState(onOpen: _pickFile, onFindDevice: _grantAllFilesAccess);
    }
    return _buildHomeList();
  }

  Widget _buildHomeList() {
    final text = Theme.of(context).textTheme;
    final devicePdfs = _filteredDevicePdfs;
    final recents = _filteredRecents;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('ON THIS DEVICE', style: text.labelSmall),
                    ),
                    IconButton(
                      tooltip: 'Scanned folders',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.folder_open_rounded, size: 20),
                      onPressed: _manageFolders,
                    ),
                    IconButton(
                      tooltip: 'Add a folder',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.create_new_folder_outlined,
                        size: 20,
                      ),
                      onPressed: _addDeviceFolder,
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: _deviceLoading
                          ? null
                          : () => _loadDevicePdfs(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_deviceLoading)
            const SliverToBoxAdapter(child: _DeviceLoadingRow())
          else if (!_hasAllFilesAccess && _deviceFolders.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _DeviceAccessCard(
                  onAllow: _grantAllFilesAccess,
                  onChooseFolder: _addDeviceFolder,
                ),
              ),
            )
          else if (devicePdfs.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  _searchQuery.isNotEmpty
                      ? 'No matching files found.'
                      : 'No documents found yet. Add another folder to scan.',
                  style: text.bodyMedium,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: devicePdfs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final pdf = devicePdfs[index];
                  return _RecentCard(
                    key: ValueKey(pdf.id),
                    name: pdf.name,
                    meta: _deviceMetaFor(pdf),
                    progress: _progress[pdf.path]?.progress ?? 0,
                    exists: true,
                    onOpen: () => _openDevicePdf(pdf),
                    onDetails: () => _showFileDetails(
                      name: pdf.name,
                      path: pdf.path,
                      size: pdf.size,
                      modified: pdf.modified,
                    ),
                  );
                },
              ),
            ),
          if (recents.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('RECENT FILES', style: text.labelSmall),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: recents.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _buildRecentCard(recents[index]),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
      ),
    );
  }

  Widget _buildRecentCard(RecentFile file) {
    final exists = !_missingPaths.contains(file.path);
    final fileObj = File(file.path);
    final size = exists ? (fileObj.existsSync() ? fileObj.lengthSync() : 0) : 0;

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
        onOpen: () => exists ? _openReader(file.path) : _removeRecent(file),
        onRemove: () => _removeRecent(file),
        onDetails: () => _showFileDetails(
          name: file.name,
          path: file.path,
          size: size,
          modified: file.openedAt,
        ),
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

enum _CardAction { open, details, remove }

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    super.key,
    required this.name,
    required this.meta,
    required this.progress,
    required this.exists,
    required this.onOpen,
    this.onRemove,
    this.onDetails,
  });

  final String name;
  final String meta;
  final double progress;
  final bool exists;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;
  final VoidCallback? onDetails;

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
                    _FileTile(name: name, exists: exists),
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
                        _CardAction.details => onDetails?.call(),
                        _CardAction.remove => onRemove?.call(),
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _CardAction.open,
                          child: Text('Open'),
                        ),
                        if (onDetails != null)
                          const PopupMenuItem(
                            value: _CardAction.details,
                            child: Text('Details'),
                          ),
                        if (onRemove != null)
                          const PopupMenuItem(
                            value: _CardAction.remove,
                            child: Text('Remove from recents'),
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

class _FileTile extends StatelessWidget {
  const _FileTile({required this.name, required this.exists});

  final String name;
  final bool exists;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final ext = name.split('.').last.toLowerCase();
    final (badgeColor, textColor, iconWidget, label) = switch (ext) {
      'docx' || 'doc' => (
          Colors.blue.shade100,
          Colors.blue.shade900,
          Icon(Icons.description_rounded, size: 24, color: Colors.blue.shade800),
          'DOCX',
        ),
      'xlsx' || 'xls' => (
          Colors.green.shade100,
          Colors.green.shade900,
          Icon(Icons.table_chart_rounded, size: 24, color: Colors.green.shade800),
          'XLSX',
        ),
      'pptx' || 'ppt' => (
          Colors.deepOrange.shade100,
          Colors.deepOrange.shade900,
          Icon(Icons.slideshow_rounded, size: 24, color: Colors.deepOrange.shade800),
          'PPTX',
        ),
      _ => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          const PdfGlyph(size: 26),
          'PDF',
        ),
    };

    return Container(
      width: 56,
      height: 70,
      decoration: BoxDecoration(
        color: exists ? badgeColor : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          exists
              ? iconWidget
              : Icon(
                  Icons.question_mark_rounded,
                  size: 22,
                  color: scheme.outline,
                ),
          const SizedBox(height: 6),
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: exists ? textColor : scheme.outline,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenDock extends StatelessWidget {
  const _OpenDock({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppShape.gutter,
          12,
          AppShape.gutter,
          12,
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
  const _EmptyState({required this.onOpen, required this.onFindDevice});

  final VoidCallback onOpen;
  final VoidCallback onFindDevice;

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
              'Open a PDF, Word, Excel or PowerPoint file to start reading.\n'
              'Highlight, annotate, search, share, or save pages to gallery.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.file_open_rounded, size: 20),
              label: const Text('Open your first PDF'),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onFindDevice,
              icon: const Icon(Icons.smartphone_rounded, size: 18),
              label: const Text('Find PDFs on this device'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceAccessCard extends StatelessWidget {
  const _DeviceAccessCard({
    required this.onAllow,
    required this.onChooseFolder,
  });

  final VoidCallback onAllow;
  final VoidCallback onChooseFolder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppShape.radiusLarge),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_open_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Show PDFs on this device', style: text.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pagelit can list every PDF and Office document stored on your phone, newest first. '
            'Allow full storage access, or pick folders to scan.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onAllow,
                  child: const Text('Allow access'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onChooseFolder,
                  child: const Text('Choose folder'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceLoadingRow extends StatelessWidget {
  const _DeviceLoadingRow();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Row(
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Looking for documents…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

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
