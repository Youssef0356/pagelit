import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagelit/services/encoding_utils.dart';

void main() {
  group('EncodingUtils.decodeDocumentBytes', () {
    test('decodes standard UTF-8 text with French symbols', () {
      const text = "Rapport d'activité : été 2026, présentation & données reçues (français, coût en €)";
      final bytes = utf8.encode(text);
      expect(EncodingUtils.decodeDocumentBytes(bytes), text);
    });

    test('decodes UTF-8 with Byte Order Mark (BOM)', () {
      const text = "Fichier avec BOM : été, noël, août";
      final bom = [0xEF, 0xBB, 0xBF];
      final bytes = [...bom, ...utf8.encode(text)];
      expect(EncodingUtils.decodeDocumentBytes(bytes), text);
    });

    test('falls back to Latin-1 for legacy French documents', () {
      const text = "Société Générale & Électricité de France";
      final bytes = latin1.encode(text);
      expect(EncodingUtils.decodeDocumentBytes(bytes), text);
    });

    test('recovers from malformed UTF-8 gracefully', () {
      final bytes = [0xC3, 0x28]; // Invalid UTF-8 sequence
      final result = EncodingUtils.decodeDocumentBytes(bytes);
      expect(result.isNotEmpty, true);
    });
  });

  group('EncodingUtils.fixMojibake', () {
    test('corrects UTF-8 bytes mistakenly interpreted as Latin-1', () {
      // "RÃ©sumÃ©" is "Résumé" mis-decoded as Latin-1
      expect(EncodingUtils.fixMojibake('RÃ©sumÃ©'), 'Résumé');
      // "FranÃ§ais" -> "Français"
      expect(EncodingUtils.fixMojibake('FranÃ§ais'), 'Français');
      // "DonnÃ©es" -> "Données"
      expect(EncodingUtils.fixMojibake('DonnÃ©es'), 'Données');
    });

    test('leaves regular text untouched', () {
      expect(EncodingUtils.fixMojibake('Hello World!'), 'Hello World!');
      expect(EncodingUtils.fixMojibake('Document PDF'), 'Document PDF');
    });
  });

  group('EncodingUtils.cleanDisplayName', () {
    test('decodes URL percent-encoding', () {
      expect(
        EncodingUtils.cleanDisplayName('Mon%20Projet%20Fran%C3%A7ais.pdf'),
        'Mon Projet Français.pdf',
      );
    });

    test('fixes mojibake in filename', () {
      expect(
        EncodingUtils.cleanDisplayName('RÃ©sumÃ©_2026.docx'),
        'Résumé_2026.docx',
      );
    });
  });

  group('EncodingUtils.searchMatches & removeDiacritics', () {
    test('removes French diacritics', () {
      expect(EncodingUtils.removeDiacritics('résumé'), 'resume');
      expect(EncodingUtils.removeDiacritics('FRANÇAIS'), 'FRANCAIS');
      expect(EncodingUtils.removeDiacritics('sœur et cœur'), 'soeur et coeur');
      expect(EncodingUtils.removeDiacritics('août & noël'), 'aout & noel');
    });

    test('matches queries with or without accents', () {
      expect(EncodingUtils.searchMatches('Présentation projet.pptx', 'presentation'), true);
      expect(EncodingUtils.searchMatches('presentation projet.pptx', 'présentation'), true);
      expect(EncodingUtils.searchMatches('Cours de français.pdf', 'francais'), true);
      expect(EncodingUtils.searchMatches('rapport d\'activité', 'activite'), true);
      expect(EncodingUtils.searchMatches('coeur', 'cœur'), true);
    });
  });
}
