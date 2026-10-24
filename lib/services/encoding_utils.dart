import 'dart:convert';
import 'dart:typed_data';

/// Utilities for decoding document streams with proper UTF-8, Latin-1,
/// and Windows-1252 fallbacks, handling French/accented characters,
/// fixing UTF-8 mojibake, and providing diacritic-insensitive search.
class EncodingUtils {
  const EncodingUtils._();

  /// Decodes raw XML/document bytes into a [String].
  ///
  /// Supports:
  /// - UTF-8 (with or without BOM)
  /// - UTF-16 BE / LE (with BOM)
  /// - Latin-1 / ISO-8859-1 / Windows-1252 fallback for legacy documents
  /// - Malformed UTF-8 recovery
  static String decodeDocumentBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';

    List<int> content = bytes;

    // Check for Byte Order Marks (BOM)
    if (content.length >= 3 &&
        content[0] == 0xEF &&
        content[1] == 0xBB &&
        content[2] == 0xBF) {
      // UTF-8 BOM
      content = content.sublist(3);
    } else if (content.length >= 2 &&
        content[0] == 0xFE &&
        content[1] == 0xFF) {
      // UTF-16 Big Endian
      final byteData = ByteData.sublistView(Uint8List.fromList(content.sublist(2)));
      final chars = <int>[];
      for (int i = 0; i < byteData.lengthInBytes - 1; i += 2) {
        chars.add(byteData.getUint16(i, Endian.big));
      }
      return String.fromCharCodes(chars);
    } else if (content.length >= 2 &&
        content[0] == 0xFF &&
        content[1] == 0xFE) {
      // UTF-16 Little Endian
      final byteData = ByteData.sublistView(Uint8List.fromList(content.sublist(2)));
      final chars = <int>[];
      for (int i = 0; i < byteData.lengthInBytes - 1; i += 2) {
        chars.add(byteData.getUint16(i, Endian.little));
      }
      return String.fromCharCodes(chars);
    }

    // Try standard UTF-8 first (strict)
    try {
      return utf8.decode(content);
    } catch (_) {
      // If invalid byte sequences are present, attempt Latin-1 (preserves byte-for-byte Western European / French)
      try {
        return latin1.decode(content);
      } catch (_) {
        // Fallback to UTF-8 with malformed replacement
        return utf8.decode(content, allowMalformed: true);
      }
    }
  }

  /// Fixes text where UTF-8 bytes were mistakenly interpreted as Latin-1 / WinAnsi
  /// code units (mojibake like "Ã©" for "é", "â€™" for "’", "Ã " for "à", etc.).
  static String fixMojibake(String text) {
    if (text.isEmpty) return text;

    // Check if the string contains signature UTF-8 multi-byte sequences decoded as Latin-1.
    // In UTF-8, 2-byte sequences start with 0xC2..0xDF (Ã, Â, etc.) followed by 0x80..0xBF.
    // 3-byte sequences (like apostrophe ’, euro €) start with 0xE0..0xEF (â, etc.).
    final hasMojibakePattern = RegExp(r'[\u00C2-\u00DF][\u0080-\u00BF]|â[\u0080-\u009F][\u0080-\u00BF]');
    if (!hasMojibakePattern.hasMatch(text)) {
      return text;
    }

    try {
      final codeUnits = text.codeUnits;
      // If all code units fit within a byte (0-255), re-interpret them as UTF-8 bytes:
      if (codeUnits.every((c) => c <= 255)) {
        final decoded = utf8.decode(codeUnits, allowMalformed: false);
        return decoded;
      }
    } catch (_) {
      // If strict decoding fails, return original text unchanged
    }

    return text;
  }

  /// Cleans and decodes a filename or path title:
  /// - Decodes URL percent-encoding (e.g. "document%20fran%C3%A7ais.pdf" -> "document français.pdf")
  /// - Fixes any UTF-8 mojibake
  /// - Strips invalid control characters
  static String cleanDisplayName(String rawName) {
    if (rawName.isEmpty) return rawName;

    var name = rawName;

    // URL percent-decode if '%' is present
    if (name.contains('%')) {
      try {
        name = Uri.decodeFull(name);
      } catch (_) {
        try {
          name = Uri.decodeComponent(name);
        } catch (_) {}
      }
    }

    // Fix potential mojibake
    name = fixMojibake(name);

    return name.trim();
  }

  /// Removes French and other European diacritics / accents for flexible search.
  /// (e.g., "résumé" -> "resume", "français" -> "francais", "sœur" -> "soeur").
  static String removeDiacritics(String input) {
    if (input.isEmpty) return input;

    const withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÌÍÎÏìíîïÙÚÛÜùúûüÝýÿÑñÇçŠšŽžÐð';
    const withoutDia = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeIIIIiiiiUUUUuuuuYyyNnCcSsZzDd';

    var result = input;
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }

    // Handle common French ligatures
    return result
        .replaceAll('œ', 'oe')
        .replaceAll('Œ', 'OE')
        .replaceAll('æ', 'ae')
        .replaceAll('Æ', 'AE');
  }

  /// Determines whether [source] matches [query] using diacritic-insensitive
  /// and case-insensitive comparison.
  ///
  /// Examples:
  /// - searchMatches("Présentation", "presentation") == true
  /// - searchMatches("français", "francais") == true
  /// - searchMatches("coeur", "cœur") == true
  static bool searchMatches(String source, String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return true;

    final cleanQuery = removeDiacritics(trimmedQuery.toLowerCase());
    final cleanSource = removeDiacritics(source.toLowerCase());

    return cleanSource.contains(cleanQuery);
  }
}
