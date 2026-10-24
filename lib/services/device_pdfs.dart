import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'encoding_utils.dart';

/// A document found on the device — either through "All files access" or inside a
/// folder the user picked with the system folder picker.
class DevicePdf {
  const DevicePdf({
    required this.name,
    required this.size,
    required this.modified,
    this.path,
    this.uri,
  });

  final String name;
  final int size;
  final DateTime modified;

  /// A path Dart can read directly (only available with "All files access").
  final String? path;

  /// A `content://` URI, copied into the cache when the document is opened.
  final String? uri;

  /// Stable identity for list keys and de-duplication.
  String get id => path ?? uri ?? name;

  factory DevicePdf.fromMap(Map<Object?, Object?> map) {
    final milliseconds = (map['modified'] as num?)?.toInt() ?? 0;
    final rawName = map['name'] as String? ?? 'document';
    return DevicePdf(
      name: EncodingUtils.cleanDisplayName(rawName),
      size: (map['size'] as num?)?.toInt() ?? 0,
      modified: DateTime.fromMillisecondsSinceEpoch(milliseconds),
      path: map['path'] as String?,
      uri: map['uri'] as String?,
    );
  }
}

/// Lists documents stored on the device, newest first.
///
/// Supports PDF, Word (.docx, .doc), Excel (.xlsx, .xls), and PowerPoint (.pptx, .ppt).
class DevicePdfLibrary {
  const DevicePdfLibrary._();

  static const _channel = MethodChannel('pagelit/device_pdfs');
  static const _foldersKey = 'device_pdf_folders';

  /// Whether "All files access" is granted (Android 11+ only).
  static Future<bool> hasAllFilesAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the system screen where "All files access" can be granted.
  static Future<bool> requestAllFilesAccess() async {
    try {
      return await _channel.invokeMethod<bool>('requestAllFilesAccess') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Folders the user added, as persisted tree URIs.
  static Future<List<String>> loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    return List<String>.of(prefs.getStringList(_foldersKey) ?? const []);
  }

  /// Shows the system folder picker and stores the chosen folder.
  static Future<List<String>> addFolder() async {
    String? uri;
    try {
      uri = await _channel.invokeMethod<String>('pickFolder');
    } on PlatformException {
      uri = null;
    } on MissingPluginException {
      uri = null;
    }
    final folders = await loadFolders();
    if (uri == null || uri.isEmpty || folders.contains(uri)) return folders;
    folders.add(uri);
    await _saveFolders(folders);
    return folders;
  }

  /// Forgets a folder and drops its persisted read permission.
  static Future<List<String>> removeFolder(String uri) async {
    final folders = await loadFolders()
      ..remove(uri);
    await _saveFolders(folders);
    try {
      await _channel.invokeMethod<bool>('releaseFolder', {'uri': uri});
    } on PlatformException {
      // The permission may already be gone: nothing to clean up.
    } on MissingPluginException {
      // Running outside Android.
    }
    return folders;
  }

  /// Every document inside [folders], plus all device documents when access is granted.
  static Future<List<DevicePdf>> listPdfs(List<String> folders) async {
    List<Object?>? raw;
    try {
      raw = await _channel.invokeMethod<List<Object?>>('listPdfs', {
        'folders': folders,
      });
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
    if (raw == null) return const [];
    final pdfs =
        raw.whereType<Map<Object?, Object?>>().map(DevicePdf.fromMap).toList()
          ..sort((a, b) => b.modified.compareTo(a.modified));
    return pdfs;
  }

  /// A path the reader can open for [pdf].
  static Future<String?> openPath(DevicePdf pdf) async {
    final path = pdf.path;
    if (path != null && path.isNotEmpty) return path;
    final uri = pdf.uri;
    if (uri == null) return null;
    try {
      return await _channel.invokeMethod<String>('resolvePdf', {'uri': uri});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Gets the total size of cached shared documents in bytes.
  static Future<int> getCacheSize() async {
    try {
      return await _channel.invokeMethod<int>('getCacheSize') ?? 0;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  /// Clears the cached shared documents folder.
  static Future<bool> clearCache() async {
    try {
      return await _channel.invokeMethod<bool>('clearCache') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Prints a document file using the system print spooler.
  static Future<bool> printFile(String path) async {
    try {
      return await _channel.invokeMethod<bool>('printFile', {'path': path}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> _saveFolders(List<String> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_foldersKey, folders);
  }
}
