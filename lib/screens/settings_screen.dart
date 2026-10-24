import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/device_pdfs.dart';
import '../services/locale_prefs.dart';
import '../services/premium_service.dart';
import '../services/reading_prefs.dart';
import '../services/reading_progress.dart';
import '../services/recent_files.dart';
import '../services/theme_prefs.dart';

/// Published GitHub Pages site (see docs/README.md).
const _privacyUrl = 'https://the356company.github.io/pagelit/privacy.html';

/// App settings: appearance, language, reading behaviour, annotation defaults,
/// stored data and about info. Everything here is also reachable from the reader.
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
    if (bytes <= 0) return context.l10n.formatBytes(0);
    return context.l10n.formatBytes(bytes);
  }

  Future<void> _manageFolders() async {
    final l10n = context.l10n;
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
                      l10n.scannedFolders,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: l10n.addFolder,
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
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      l10n.noCustomFolders,
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
                          tooltip: l10n.removeFolder,
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
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearCacheTitle),
        content: Text(l10n.clearCacheContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DevicePdfLibrary.clearCache();
    await _loadStorageInfo();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.cacheClearedSnackbar)),
    );
  }

  Future<void> _confirmClearData(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearRecentsConfirmTitle),
        content: Text(l10n.clearRecentsConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.clear),
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
      SnackBar(content: Text(l10n.recentsClearedSnackbar)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          _Section(
            label: l10n.appearance,
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemePrefs.mode,
              builder: (context, mode, _) => _ChoiceRow<ThemeMode>(
                value: mode,
                options: {
                  ThemeMode.system: l10n.themeSystem,
                  ThemeMode.light: l10n.themeLight,
                  ThemeMode.dark: l10n.themeDark,
                },
                onChanged: ThemePrefs.set,
              ),
            ),
          ),
          _Section(
            label: l10n.language,
            child: ValueListenableBuilder<Locale?>(
              valueListenable: LocalePrefs.locale,
              builder: (context, currentLocale, _) {
                final selectedCode = currentLocale?.languageCode ?? 'system';
                return _ChoiceRow<String>(
                  value: selectedCode,
                  options: {
                    'system': l10n.languageSystem,
                    'en': 'English',
                    'fr': 'Français',
                    'ar': 'العربية',
                  },
                  onChanged: (code) {
                    if (code == 'system') {
                      LocalePrefs.set(null);
                    } else {
                      LocalePrefs.set(Locale(code));
                    }
                  },
                );
              },
            ),
          ),
          _Section(
            label: l10n.reading,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: ReadingPrefs.keepScreenOn,
                  builder: (context, keepAwake, _) => SwitchListTile(
                    value: keepAwake,
                    onChanged: ReadingPrefs.setKeepScreenOn,
                    title: Text(l10n.keepScreenOn),
                    subtitle: Text(l10n.whileDocumentIsOpen),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l10n.pageLayout, style: text.titleSmall),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<PdfPageLayoutMode>(
                  valueListenable: ReadingPrefs.layoutMode,
                  builder: (context, mode, _) => _ChoiceRow<PdfPageLayoutMode>(
                    value: mode,
                    options: {
                      PdfPageLayoutMode.continuous: l10n.layoutContinuous,
                      PdfPageLayoutMode.single: l10n.layoutSingle,
                    },
                    onChanged: ReadingPrefs.setLayoutMode,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l10n.scrollDirection, style: text.titleSmall),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<PdfScrollDirection>(
                  valueListenable: ReadingPrefs.scrollDirection,
                  builder: (context, dir, _) => _ChoiceRow<PdfScrollDirection>(
                    value: dir,
                    options: {
                      PdfScrollDirection.vertical: l10n.scrollVertical,
                      PdfScrollDirection.horizontal: l10n.scrollHorizontal,
                    },
                    onChanged: ReadingPrefs.setScrollDirection,
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l10n.comfortMode, style: text.titleSmall),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<ComfortMode>(
                  valueListenable: ReadingPrefs.comfortMode,
                  builder: (context, mode, _) => _ChoiceRow<ComfortMode>(
                    value: mode,
                    options: {
                      ComfortMode.normal: l10n.comfortNormal,
                      ComfortMode.sepia: l10n.comfortSepia,
                      ComfortMode.dim: l10n.comfortDim,
                      ComfortMode.inverted: l10n.comfortNight,
                    },
                    onChanged: ReadingPrefs.setComfortMode,
                  ),
                ),
              ],
            ),
          ),
          _Section(
            label: l10n.annotations,
            child: ValueListenableBuilder<Color>(
              valueListenable: ReadingPrefs.annotationColor,
              builder: (context, color, _) => Row(
                children: [
                  for (final swatch in _annotationPalette)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12),
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
            label: l10n.storageAndFolders,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_special_outlined),
                  title: Text(l10n.scannedFolders),
                  subtitle: Text(
                    _folders.isEmpty
                        ? l10n.noCustomFoldersSelected
                        : l10n.scannedFoldersCount(_folders.length),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _manageFolders,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: Text(l10n.clearSharedCache),
                  subtitle: Text(l10n.temporaryCopies(_formatSize(_cacheSizeBytes))),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _cacheSizeBytes > 0 ? _clearCache : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: scheme.primary,
                  ),
                  title: Text(l10n.clearRecentsTitle),
                  subtitle: Text(l10n.clearRecentsSubtitle),
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

/// One row of mutually exclusive choices (appearance, language, layout, comfort).
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SegmentedButton<T>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: [
                for (final entry in options.entries)
                  ButtonSegment<T>(
                    value: entry.key,
                    label: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              selected: {value},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => onChanged(selection.first),
            ),
          ),
        );
      },
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
    final l10n = context.l10n;
    final started = await PremiumService.buy();
    if (started || !mounted) return;

    if (kDebugMode && !PremiumService.isPremium.value) {
      final shouldSimulate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.playBillingUnavailableTitle),
          content: Text(l10n.playBillingUnavailableContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.activatePremium),
            ),
          ],
        ),
      );
      if (shouldSimulate == true && mounted) {
        await PremiumService.grantPremium(persist: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.premiumActivatedSnackbar)),
          );
        }
      }
      return;
    }

    final errorMessage = PremiumService.lastError.value ??
        (PremiumService.priceLabel.value == null
            ? l10n.billingConnectError
            : l10n.billingPurchaseError);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  }

  Future<void> _restore() async {
    final l10n = context.l10n;
    final outcome = await PremiumService.restore();
    if (!mounted) return;
    if (outcome == RestoreOutcome.notFound) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noPreviousPurchase)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return _Section(
      label: l10n.premium,
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
                title: Text(l10n.removeAds),
                subtitle: premium
                    ? Text(l10n.premiumActiveSubtitle)
                    : ValueListenableBuilder<String?>(
                        valueListenable: PremiumService.priceLabel,
                        builder: (context, price, _) => Text(
                          price == null
                              ? l10n.oneTimePurchase
                              : l10n.oneTimePurchaseWithPrice(price),
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
                alignment: AlignmentDirectional.centerEnd,
                child: ValueListenableBuilder<bool>(
                  valueListenable: PremiumService.isBuying,
                  builder: (context, buying, _) => TextButton(
                    onPressed: buying ? null : _restore,
                    child: Text(l10n.restorePurchases),
                  ),
                ),
              ),
            if (kDebugMode) ...[
              const Divider(height: 28),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(l10n.simulatePremium),
                subtitle: Text(l10n.simulatePremiumSubtitle),
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
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return _Section(
      label: l10n.about,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(l10n.version),
            trailing: Text(
              _version,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacyPolicy),
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
