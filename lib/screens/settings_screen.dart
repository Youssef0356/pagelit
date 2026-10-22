import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/device_pdfs.dart';
import '../services/premium_service.dart';
import '../services/reading_prefs.dart';
import '../services/reading_progress.dart';
import '../services/recent_files.dart';
import '../services/theme_prefs.dart';

/// Published GitHub Pages site (see docs/README.md).
const _privacyUrl = 'https://the356company.github.io/pagelit/privacy.html';

/// App settings: appearance, reading behaviour, annotation defaults, stored
/// data and about info. Everything here is also reachable from the reader.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _cacheSizeBytes = 0;
  List<String> _folders = const [];

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    final size = await DevicePdfLibrary.getCacheSize();
    final folders = await DevicePdfLibrary.loadFolders();
    if (mounted) {
      setState(() {
        _cacheSizeBytes = size;
        _folders = folders;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
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
                        setSheetState(() => _folders = updated);
                        await _loadStorageInfo();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_folders.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No custom folders added yet.\nTap the + button to select a folder.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _folders.length,
                    itemBuilder: (context, index) {
                      final uri = _folders[index];
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
                            setSheetState(() => _folders = updated);
                            await _loadStorageInfo();
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
    await _loadStorageInfo();
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cached files?'),
        content: const Text(
          'This will remove temporary copies of documents opened from other apps (WhatsApp, Downloads, Drive). '
          'Your original files on device are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DevicePdfLibrary.clearCache();
    await _loadStorageInfo();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document cache cleared')),
    );
  }

  Future<void> _confirmClearData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear recents?'),
        content: const Text(
          'This removes your recent files list, cached documents, and every saved reading position. '
          'Your original documents are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final paths = (await RecentFilesStore.load())
        .map((file) => file.path)
        .toList();
    await RecentFilesStore.clear();
    await ReadingProgress.removeAll(paths);
    await DevicePdfLibrary.clearCache();
    await _loadStorageInfo();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recents, cache, and progress cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          _Section(
            label: 'APPEARANCE',
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemePrefs.mode,
              builder: (context, mode, _) => _ChoiceRow<ThemeMode>(
                value: mode,
                options: const {
                  ThemeMode.system: 'System',
                  ThemeMode.light: 'Light',
                  ThemeMode.dark: 'Dark',
                },
                onChanged: ThemePrefs.set,
              ),
            ),
          ),
          _Section(
            label: 'READING',
            child: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: ReadingPrefs.keepScreenOn,
                  builder: (context, keepAwake, _) => SwitchListTile(
                    value: keepAwake,
                    onChanged: ReadingPrefs.setKeepScreenOn,
                    title: const Text('Keep screen on'),
                    subtitle: const Text('While a document is open'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Page layout', style: text.titleSmall),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<PdfPageLayoutMode>(
                  valueListenable: ReadingPrefs.layoutMode,
                  builder: (context, mode, _) => _ChoiceRow<PdfPageLayoutMode>(
                    value: mode,
                    options: const {
                      PdfPageLayoutMode.continuous: 'Continuous',
                      PdfPageLayoutMode.single: 'One page',
                    },
                    onChanged: ReadingPrefs.setLayoutMode,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Scroll direction', style: text.titleSmall),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<PdfScrollDirection>(
                  valueListenable: ReadingPrefs.scrollDirection,
                  builder: (context, dir, _) => _ChoiceRow<PdfScrollDirection>(
                    value: dir,
                    options: const {
                      PdfScrollDirection.vertical: 'Vertical',
                      PdfScrollDirection.horizontal: 'Horizontal',
                    },
                    onChanged: ReadingPrefs.setScrollDirection,
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Comfort & Night mode', style: text.titleSmall),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<ComfortMode>(
                  valueListenable: ReadingPrefs.comfortMode,
                  builder: (context, mode, _) => _ChoiceRow<ComfortMode>(
                    value: mode,
                    options: const {
                      ComfortMode.normal: 'Normal',
                      ComfortMode.sepia: 'Sepia',
                      ComfortMode.dim: 'Dim',
                      ComfortMode.inverted: 'Night',
                    },
                    onChanged: ReadingPrefs.setComfortMode,
                  ),
                ),
              ],
            ),
          ),
          _Section(
            label: 'ANNOTATIONS',
            child: ValueListenableBuilder<Color>(
              valueListenable: ReadingPrefs.annotationColor,
              builder: (context, color, _) => Row(
                children: [
                  for (final swatch in _annotationPalette)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ReadingPrefs.setAnnotationColor(swatch);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: swatch,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color.toARGB32() == swatch.toARGB32()
                                  ? scheme.onSurface
                                  : scheme.outlineVariant,
                              width: color.toARGB32() == swatch.toARGB32()
                                  ? 2.5
                                  : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          _Section(
            label: 'STORAGE & FOLDERS',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_special_outlined),
                  title: const Text('Scanned folders'),
                  subtitle: Text(
                    _folders.isEmpty
                        ? 'No custom folders selected'
                        : '${_folders.length} custom folder${_folders.length == 1 ? '' : 's'} scanned',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _manageFolders,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: const Text('Clear shared document cache'),
                  subtitle: Text('Temporary copies: ${_formatSize(_cacheSizeBytes)}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _cacheSizeBytes > 0 ? _clearCache : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: scheme.primary,
                  ),
                  title: const Text('Clear recents and progress'),
                  subtitle: const Text('Removes the list and reading positions'),
                  onTap: () => _confirmClearData(context),
                ),
              ],
            ),
          ),
          const _PremiumSection(),
          const _AboutSection(),
        ],
      ),
    );
  }
}

/// Colour used for new highlights, underlines, … and remembered per device.
const _annotationPalette = [
  Colors.yellow,
  Colors.orange,
  Colors.green,
  Colors.cyan,
  Colors.pink,
  Colors.purple,
  Colors.red,
];

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// One row of mutually exclusive choices (appearance, layout, comfort).
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: [
        for (final entry in options.entries)
          ButtonSegment<T>(value: entry.key, label: Text(entry.value, style: const TextStyle(fontSize: 12))),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// "Remove ads" — a one-time Play Billing purchase (see PremiumService).
class _PremiumSection extends StatefulWidget {
  const _PremiumSection();

  @override
  State<_PremiumSection> createState() => _PremiumSectionState();
}

class _PremiumSectionState extends State<_PremiumSection> {
  @override
  void initState() {
    super.initState();
    PremiumService.lastError.addListener(_onError);
  }

  @override
  void dispose() {
    PremiumService.lastError.removeListener(_onError);
    super.dispose();
  }

  void _onError() {
    final message = PremiumService.lastError.value;
    PremiumService.lastError.value = null;
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _buy() async {
    final started = await PremiumService.buy();
    if (started || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          PremiumService.priceLabel.value == null
              ? 'Purchases are not available on this device.'
              : 'Could not start the purchase. Please try again.',
        ),
      ),
    );
  }

  Future<void> _restore() async {
    final outcome = await PremiumService.restore();
    if (!mounted) return;
    if (outcome == RestoreOutcome.notFound) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No previous purchase found.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _Section(
      label: 'PREMIUM',
      child: ValueListenableBuilder<bool>(
        valueListenable: PremiumService.isPremium,
        builder: (context, premium, _) => Column(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: PremiumService.isBuying,
              builder: (context, buying, _) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  premium
                      ? Icons.verified_outlined
                      : Icons.workspace_premium_outlined,
                  color: colorScheme.primary,
                ),
                title: const Text('Remove ads'),
                subtitle: premium
                    ? const Text('Thank you! Ads are off everywhere.')
                    : ValueListenableBuilder<String?>(
                        valueListenable: PremiumService.priceLabel,
                        builder: (context, price, _) => Text(
                          price == null
                              ? 'One-time purchase'
                              : 'One-time purchase · $price',
                        ),
                      ),
                trailing: premium
                    ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                    : buying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.outline,
                      ),
                onTap: premium || buying ? null : _buy,
              ),
            ),
            if (!premium)
              Align(
                alignment: Alignment.centerRight,
                child: ValueListenableBuilder<bool>(
                  valueListenable: PremiumService.isBuying,
                  builder: (context, buying, _) => TextButton(
                    onPressed: buying ? null : _restore,
                    child: const Text('Restore purchases'),
                  ),
                ),
              ),
            if (kDebugMode) ...[
              const Divider(height: 28),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Simulate premium (debug)'),
                subtitle: const Text(
                  'Preview the ad-free UI — not saved, resets on restart',
                ),
                value: premium,
                onChanged: PremiumService.debugSetPremium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends StatefulWidget {
  const _AboutSection();

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version}+${info.buildNumber}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _Section(
      label: 'ABOUT',
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Version'),
            trailing: Text(
              _version,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            trailing: Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: colorScheme.outline,
            ),
            onTap: _openPrivacyPolicy,
          ),
        ],
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(_privacyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

