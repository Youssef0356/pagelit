import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/premium_service.dart';
import '../services/reading_prefs.dart';
import '../services/reading_progress.dart';
import '../services/recent_files.dart';
import '../services/theme_prefs.dart';

/// Published GitHub Pages site (see docs/README.md).
const _privacyUrl = 'https://the356company.github.io/pagelit/privacy.html';

/// App settings: appearance, reading behaviour, annotation defaults, stored
/// data and about info. Everything here is also reachable from the reader.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Applies the next time a document is opened.',
                      style: text.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Comfort', style: text.titleSmall),
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
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
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
            label: 'DATA',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Clear recents and progress'),
              subtitle: const Text('Removes the list and reading positions'),
              onTap: () => _confirmClearData(context),
            ),
          ),
          const _PremiumSection(),
          const _AboutSection(),
        ],
      ),
    );
  }

  Future<void> _confirmClearData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear recents?'),
        content: const Text(
          'This removes your recent files list and every saved reading position. '
          'Your PDFs are not deleted.',
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
    // Read the list before clearing it: the paths are what we need to purge
    // the stored reading positions.
    final paths = (await RecentFilesStore.load())
        .map((file) => file.path)
        .toList();
    await RecentFilesStore.clear();
    await ReadingProgress.removeAll(paths);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recents and progress cleared')),
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
          ButtonSegment<T>(value: entry.key, label: Text(entry.value)),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// "Remove ads" — a one-time Play Billing purchase (see PremiumService).
///
/// Tapping the row opens the Google Play purchase sheet; once the purchase
/// (or a restore) completes, every AdBanner in the app disappears at once
/// through [PremiumService.isPremium].
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
    // buy() only returns false here when billing is unusable on this
    // device (no Play Store / product not published yet) or already busy.
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
    // `granted` flips the section to its thank-you state; `failed` was
    // already surfaced through the lastError listener.
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
