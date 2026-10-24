import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';

import '../l10n/app_localizations.dart';

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
    final l10n = context.l10n;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);

    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.viewerNotReady)),
        );
        return false;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.couldNotGenerateSnapshot)),
        );
        return false;
      }

      return await _saveBytesWithMessenger(
        messenger: messenger,
        imageBytes: byteData.buffer.asUint8List(),
        name: baseName,
        successMessage: successMessage ?? l10n.savedToGallerySuccess,
        permissionDeniedMessage: l10n.galleryPermissionDenied,
        couldNotSaveMessage: l10n.couldNotSaveToGallery,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.couldNotSaveToGallery('$e'))),
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
    final l10n = context.l10n;
    return _saveBytesWithMessenger(
      messenger: messenger,
      imageBytes: imageBytes,
      name: name,
      successMessage: successMessage ?? l10n.savedToGallerySuccess,
      permissionDeniedMessage: l10n.galleryPermissionDenied,
      couldNotSaveMessage: l10n.couldNotSaveToGallery,
    );
  }

  static Future<bool> _saveBytesWithMessenger({
    required ScaffoldMessengerState messenger,
    required Uint8List imageBytes,
    required String name,
    required String successMessage,
    required String permissionDeniedMessage,
    required String Function(String error) couldNotSaveMessage,
  }) async {
    try {
      final hasAccess = await Gal.hasAccess() || await Gal.requestAccess();
      if (!hasAccess) {
        messenger.showSnackBar(
          SnackBar(content: Text(permissionDeniedMessage)),
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
          content: Text(successMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    } on GalException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(couldNotSaveMessage(e.type.message)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(couldNotSaveMessage('$e')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }
}
