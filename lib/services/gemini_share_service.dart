import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';

/// Service to dispatch the current page image and prompt into Google Gemini
/// via Android / platform Share Intent with fallbacks.
class GeminiShareService {
  GeminiShareService._();

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
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.viewerNotReady)),
        );
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.couldNotGenerateSnapshot)),
        );
        return;
      }

      await _shareImageBytesWithMessenger(
        messenger: messenger,
        imageBytes: byteData.buffer.asUint8List(),
        pageTitle: pageTitle,
        customPrompt: customPrompt,
        shareTitle: l10n.askGeminiTitle(pageTitle),
        errorMessage: l10n.couldNotShareToGemini,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.couldNotShareToGemini('$e'))),
      );
    }
  }

  /// Writes [imageBytes] to a temporary file and triggers the share sheet with a prompt.
  static Future<void> shareImageBytesToGemini({
    required BuildContext context,
    required Uint8List imageBytes,
    required String pageTitle,
    String? customPrompt,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await _shareImageBytesWithMessenger(
      messenger: messenger,
      imageBytes: imageBytes,
      pageTitle: pageTitle,
      customPrompt: customPrompt,
      shareTitle: l10n.askGeminiTitle(pageTitle),
      errorMessage: l10n.couldNotShareToGemini,
    );
  }

  static Future<void> _shareImageBytesWithMessenger({
    required ScaffoldMessengerState messenger,
    required Uint8List imageBytes,
    required String pageTitle,
    required String shareTitle,
    required String Function(String error) errorMessage,
    String? customPrompt,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = pageTitle
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .replaceAll(' ', '_');
      final fileName = 'gemini_${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(imageBytes, flush: true);

      final promptText = customPrompt ?? defaultPrompt;

      // Dispatches Android Share Intent containing both the page image and the prompt text.
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: promptText,
          title: shareTitle,
          subject: shareTitle,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessage('$e'))),
      );
    }
  }
}
