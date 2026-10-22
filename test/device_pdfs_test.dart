import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pagelit/services/device_pdfs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('pagelit/device_pdfs');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mock(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, handler);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('listPdfs maps the native rows and sorts newest first', () async {
    mock((call) async {
      expect(call.method, 'listPdfs');
      expect((call.arguments as Map)['folders'], ['content://tree/downloads']);
      return <Object?>[
        {
          'name': 'older.pdf',
          'path': r'C:\docs\older.pdf',
          'uri': null,
          'size': 1024,
          'modified': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        },
        {
          'name': 'newer.pdf',
          'path': null,
          'uri': 'content://media/external/file/42',
          'size': 2048,
          'modified': DateTime(2024, 6, 1).millisecondsSinceEpoch,
        },
      ];
    });

    final pdfs = await DevicePdfLibrary.listPdfs(['content://tree/downloads']);

    expect(pdfs.map((pdf) => pdf.name), ['newer.pdf', 'older.pdf']);
    expect(pdfs.first.uri, 'content://media/external/file/42');
    expect(pdfs.first.path, isNull);
    expect(pdfs.last.path, r'C:\docs\older.pdf');
    expect(pdfs.first.size, 2048);
    expect(pdfs.first.modified, DateTime(2024, 6, 1));
  });

  test('a failing platform call degrades to an empty library', () async {
    mock((call) async => throw PlatformException(code: 'boom'));

    expect(await DevicePdfLibrary.listPdfs(const []), isEmpty);
    expect(await DevicePdfLibrary.hasAllFilesAccess(), isFalse);
    expect(await DevicePdfLibrary.requestAllFilesAccess(), isFalse);
  });

  test('addFolder stores the chosen folder once', () async {
    mock((call) async {
      if (call.method == 'pickFolder') return 'content://tree/downloads';
      return null;
    });

    expect(await DevicePdfLibrary.addFolder(), ['content://tree/downloads']);
    expect(await DevicePdfLibrary.loadFolders(), ['content://tree/downloads']);
    // Choosing the same folder again must not duplicate it.
    expect(await DevicePdfLibrary.addFolder(), ['content://tree/downloads']);
  });

  test('cancelling the folder picker keeps the folders untouched', () async {
    mock((call) async => null);

    expect(await DevicePdfLibrary.addFolder(), isEmpty);
  });

  test('removeFolder forgets the folder and releases its permission', () async {
    SharedPreferences.setMockInitialValues({
      'device_pdf_folders': ['content://tree/a', 'content://tree/b'],
    });
    final released = <Object?>[];
    mock((call) async {
      if (call.method == 'releaseFolder') released.add(call.arguments);
      return true;
    });

    final folders = await DevicePdfLibrary.removeFolder('content://tree/a');

    expect(folders, ['content://tree/b']);
    expect(await DevicePdfLibrary.loadFolders(), ['content://tree/b']);
    expect(released.single, {'uri': 'content://tree/a'});
  });

  test('openPath resolves content URIs through the cache copy', () async {
    mock((call) async {
      if (call.method == 'resolvePdf') {
        expect(call.arguments, {'uri': 'content://doc'});
        return r'C:\cache\shared_pdfs\doc.pdf';
      }
      return null;
    });

    final uriPdf = DevicePdf(
      name: 'doc.pdf',
      size: 10,
      modified: DateTime(2024),
      uri: 'content://doc',
    );
    final directPdf = DevicePdf(
      name: 'direct.pdf',
      size: 10,
      modified: DateTime(2024),
      path: r'C:\docs\direct.pdf',
    );

    expect(
      await DevicePdfLibrary.openPath(uriPdf),
      r'C:\cache\shared_pdfs\doc.pdf',
    );
    // Directly readable files are opened in place, no copy is made.
    expect(await DevicePdfLibrary.openPath(directPdf), r'C:\docs\direct.pdf');
  });
}
