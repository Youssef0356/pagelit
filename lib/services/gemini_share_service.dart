import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);

    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Viewer is not ready to capture for Gemini')),
        );
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not capture page for Gemini')),
        );
        return;
      }

      await _shareImageBytesWithMessenger(
        messenger: messenger,
        imageBytes: byteData.buffer.asUint8List(),
        pageTitle: pageTitle,
        customPrompt: customPrompt,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not share to Gemini: $e')),
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
    await _shareImageBytesWithMessenger(
      messenger: messenger,
      imageBytes: imageBytes,
      pageTitle: pageTitle,
      customPrompt: customPrompt,
    );
  }

  static Future<void> _shareImageBytesWithMessenger({
    required ScaffoldMessengerState messenger,
    required Uint8List imageBytes,
    required String pageTitle,
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
          title: 'Ask Gemini: $pageTitle',
          subject: 'Ask Gemini: $pageTitle',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not share to Gemini: $e')),
      );
    }
  }
}
