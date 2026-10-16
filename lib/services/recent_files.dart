import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A PDF file the user opened recently.
class RecentFile {
  final String path;
  final String name;
  final DateTime openedAt;

  const RecentFile({
    required this.path,
    required this.name,
    required this.openedAt,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'openedAt': openedAt.toIso8601String(),
  };

  factory RecentFile.fromJson(Map<String, dynamic> json) => RecentFile(
    path: json['path'] as String,
    name: json['name'] as String,
    openedAt: DateTime.parse(json['openedAt'] as String),
  );
}

/// Persists the list of recently opened PDFs in [SharedPreferences].
class RecentFilesStore {
  static const _key = 'recent_files';
  static const _maxEntries = 20;

  static Future<List<RecentFile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final files = <RecentFile>[];
    for (final entry in raw) {
      try {
        files.add(
          RecentFile.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        );
      } catch (_) {
        // A corrupted entry is skipped instead of breaking the whole list
        // (this runs on the home screen, so it must never throw).
      }
    }
    return files;
  }

  /// Adds [path] to the top of the list, deduplicating and capping the size.
  static Future<void> add(String path, String name) async {
    final files = await load();
    files.removeWhere((f) => f.path == path);
    files.insert(
      0,
      RecentFile(path: path, name: name, openedAt: DateTime.now()),
    );
    if (files.length > _maxEntries) {
      files.removeRange(_maxEntries, files.length);
    }
    await _save(files);
  }

  static Future<void> remove(String path) async {
    final files = await load();
    files.removeWhere((f) => f.path == path);
    await _save(files);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _save(List<RecentFile> files) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      files.map((f) => jsonEncode(f.toJson())).toList(),
    );
  }
}
