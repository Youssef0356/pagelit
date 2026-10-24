import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';

/// Reusable utility to save snapshots or image bytes directly to the device photo gallery.
class GallerySaver {
  GallerySaver._();

  /// Captures a [GlobalKey] pointing to a [RepaintBoundary] and saves the PNG to the gallery.
  static Future<bool> saveBoundaryToGallery({
    required BuildContext context,
    required GlobalKey boundaryKey,
    required String baseName,
    String? successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);

    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Viewer is not ready to capture')),
        );
        return false;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not generate image snapshot')),
        );
        return false;
      }

      return await _saveBytesWithMessenger(
        messenger: messenger,
        imageBytes: byteData.buffer.asUint8List(),
        name: baseName,
        successMessage: successMessage ?? 'Saved snapshot to gallery',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save to gallery: $e')),
      );
      return false;
    }
  }

  /// Saves raw image bytes (PNG, JPEG, etc.) directly to the device gallery using [Gal].
  static Future<bool> saveBytesToGallery({
    required BuildContext context,
    required Uint8List imageBytes,
    required String name,
    String? successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    return _saveBytesWithMessenger(
      messenger: messenger,
      imageBytes: imageBytes,
      name: name,
      successMessage: successMessage,
    );
  }

  static Future<bool> _saveBytesWithMessenger({
    required ScaffoldMessengerState messenger,
    required Uint8List imageBytes,
    required String name,
    String? successMessage,
  }) async {
    try {
      final hasAccess = await Gal.hasAccess() || await Gal.requestAccess();
      if (!hasAccess) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Gallery permission denied')),
        );
        return false;
      }

      // Sanitize name: remove illegal file characters
      final sanitizedName = name
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .replaceAll(' ', '_');

      await Gal.putImageBytes(
        imageBytes,
        name: sanitizedName,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text(successMessage ?? 'Saved to gallery successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    } on GalException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save to gallery: ${e.type.message}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save to gallery: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }
}
