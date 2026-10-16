import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Last reading position for a document.
class ReadingPosition {
  final int page;
  final int pages;

  const ReadingPosition({required this.page, required this.pages});

  double get progress => pages > 0 ? page / pages : 0;

  int get percent => (progress * 100).round();
}

/// Persists per-document reading positions (path -> [page, pages]).
class ReadingProgress {
  static const _key = 'reading_progress';

  static Future<Map<String, ReadingPosition>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      final positions = <String, ReadingPosition>{};
      for (final entry in decoded.entries) {
        final pair = entry.value;
        if (pair is! List || pair.length < 2) continue;
        positions[entry.key] = ReadingPosition(
          page: (pair[0] as num).toInt(),
          pages: (pair[1] as num).toInt(),
        );
      }
      return positions;
    } catch (_) {
      // Corrupted data must never crash the home screen: start fresh.
      return {};
    }
  }

  static Future<ReadingPosition?> get(String path) async {
    final map = await all();
    return map[path];
  }

  static Future<void> save(String path, int page, int pages) async {
    if (pages <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final map = await all();
    map[path] = ReadingPosition(page: page, pages: pages);
    await prefs.setString(_key, _encode(map));
  }

  static Future<void> remove(String path) async {
    await removeAll([path]);
  }

  /// Drops the stored positions of every path in [paths] in one round trip,
  /// so clearing the recents list does not leave orphaned entries behind.
  static Future<void> removeAll(Iterable<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await all();
    var changed = false;
    for (final path in paths) {
      if (map.remove(path) != null) changed = true;
    }
    if (!changed) return;
    await prefs.setString(_key, _encode(map));
  }

  static String _encode(Map<String, ReadingPosition> map) =>
      jsonEncode(map.map((k, v) => MapEntry(k, [v.page, v.pages])));
}
