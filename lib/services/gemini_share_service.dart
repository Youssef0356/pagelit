import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

/// Service to dispatch the current page image and prompt into Google Gemini
/// directly via explicit Android intent, with web/clipboard fallbacks.
class GeminiShareService {
  GeminiShareService._();

  static const MethodChannel _platformChannel =
      MethodChannel('pagelit/device_pdfs');

  /// Default prompt accompanying the page image
  static const String defaultPrompt =
      'Please summarize, explain, and extract the key points from this page.';

  /// Captures a [GlobalKey] boundary as a PNG image and shares it with a prompt for Gemini.
  static Future<void> shareBoundaryToGemini({
    required BuildContext context,
    required GlobalKey boundaryKey,
    required String pageTitle,
    String? customPrompt,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);

    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.viewerNotReady)),
        );
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.couldNotGenerateSnapshot)),
        );
        return;
      }

      await _dispatchGemini(
        messenger: messenger,
        imageBytes: byteData.buffer.asUint8List(),
        pageTitle: pageTitle,
        customPrompt: customPrompt,
        shareTitle: l10n.askGeminiTitle(pageTitle),
        l10n: l10n,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.couldNotShareToGemini('$e'))),
      );
    }
  }

  /// Writes [imageBytes] to a temporary file and triggers Gemini.
  static Future<void> shareImageBytesToGemini({
    required BuildContext context,
    required Uint8List imageBytes,
    required String pageTitle,
    String? customPrompt,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await _dispatchGemini(
      messenger: messenger,
      imageBytes: imageBytes,
      pageTitle: pageTitle,
      customPrompt: customPrompt,
      shareTitle: l10n.askGeminiTitle(pageTitle),
      l10n: l10n,
    );
  }

  /// Queries Gemini directly about an excerpt / highlighted text.
  static Future<void> askGeminiAboutText({
    required BuildContext context,
    required String selectedText,
    required String pageTitle,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final promptText =
        'Please explain, summarize, and highlight the key takeaways of this passage from "$pageTitle":\n\n"$selectedText"';

    try {
      if (Platform.isAndroid) {
        try {
          final bool? launchedDirectly =
              await _platformChannel.invokeMethod<bool>(
            'openGemini',
            {
              'filePath': null,
              'prompt': promptText,
            },
          );
          if (launchedDirectly == true) return;
        } catch (_) {}
      }

      await Clipboard.setData(ClipboardData(text: promptText));
      final geminiWebUri = Uri.parse('https://gemini.google.com');
      if (await canLaunchUrl(geminiWebUri)) {
        await launchUrl(geminiWebUri, mode: LaunchMode.externalApplication);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.geminiOpeningInBrowser),
          action: Platform.isAndroid
              ? SnackBarAction(
                  label: l10n.getGeminiApp,
                  onPressed: () {
                    final playStoreUri = Uri.parse(
                      'https://play.google.com/store/apps/details?id=com.google.android.apps.bard',
                    );
                    launchUrl(playStoreUri,
                        mode: LaunchMode.externalApplication);
                  },
                )
              : null,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.couldNotShareToGemini('$e'))),
      );
    }
  }

  static Future<void> _dispatchGemini({
    required ScaffoldMessengerState messenger,
    required Uint8List imageBytes,
    required String pageTitle,
    required String shareTitle,
    required AppLocalizations l10n,
    String? customPrompt,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = pageTitle
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .replaceAll(' ', '_');
      final fileName =
          'gemini_${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(imageBytes, flush: true);

      final promptText = customPrompt ?? defaultPrompt;

      // 1. Try launching Google Gemini directly on Android (no contact chooser dialog)
      if (Platform.isAndroid) {
        try {
          final bool? launchedDirectly =
              await _platformChannel.invokeMethod<bool>(
            'openGemini',
            {
              'filePath': file.path,
              'prompt': promptText,
            },
          );

          if (launchedDirectly == true) {
            return;
          }
        } catch (_) {}
      }

      // 2. If Gemini app is not installed, open Gemini on the web with prompt copied
      await Clipboard.setData(ClipboardData(text: promptText));
      final geminiWebUri = Uri.parse('https://gemini.google.com');
      if (await canLaunchUrl(geminiWebUri)) {
        await launchUrl(geminiWebUri, mode: LaunchMode.externalApplication);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.geminiOpeningInBrowser),
          action: Platform.isAndroid
              ? SnackBarAction(
                  label: l10n.getGeminiApp,
                  onPressed: () {
                    final playStoreUri = Uri.parse(
                      'https://play.google.com/store/apps/details?id=com.google.android.apps.bard',
                    );
                    launchUrl(playStoreUri,
                        mode: LaunchMode.externalApplication);
                  },
                )
              : null,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.couldNotShareToGemini('$e'))),
      );
    }
  }
}
