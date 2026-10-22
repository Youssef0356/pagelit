import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pagelit/screens/home_screen.dart';
import 'package:pagelit/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const deviceChannel = MethodChannel('pagelit/device_pdfs');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Answers the device library channel so the home screen stops loading.
  void mockDeviceLibrary({
    bool hasAccess = false,
    List<Object?> pdfs = const [],
  }) {
    messenger.setMockMethodCallHandler(deviceChannel, (call) async {
      switch (call.method) {
        case 'hasAllFilesAccess':
          return hasAccess;
        case 'listPdfs':
          return pdfs;
        case 'requestAllFilesAccess':
          return false;
        case 'pickFolder':
          return null;
        default:
          return null;
      }
    });
  }

  /// A recents entry, enough to leave the first-run welcome screen.
  Map<String, Object> recentEntry() => {
    'recent_files': [
      jsonEncode({
        'path': r'C:\docs\Recent.pdf',
        'name': 'Recent.pdf',
        'openedAt': DateTime(2024, 1, 1).toIso8601String(),
      }),
    ],
  };

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const HomeScreen()),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDeviceLibrary();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(deviceChannel, null);
  });

  testWidgets('the Open PDF dock clears the system navigation bar', (
    tester,
  ) async {
    // Simulate a phone using on-screen navigation buttons. FakeViewPadding
    // values are physical pixels, hence the devicePixelRatio conversion.
    const navBarInset = 48.0;
    tester.view.padding = FakeViewPadding(
      bottom: navBarInset * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPadding);

    await pumpHome(tester);

    final openPdf = find.widgetWithText(FilledButton, 'Open PDF');
    expect(openPdf, findsOneWidget);

    final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    // The docked call to action must end above the navigation bar; sitting
    // underneath it is what hid the button before the SafeArea fix.
    expect(
      tester.getBottomLeft(openPdf).dy,
      lessThanOrEqualTo(screenSize.height - navBarInset),
      reason: 'Open PDF must not be drawn under the screen buttons',
    );

    // The dock is a full-width bar, not a shrink-wrapped centred pill (a
    // Column centres its children by default), so the button spans the body
    // width minus the two gutters.
    expect(tester.getSize(openPdf).width, screenSize.width - 32);
  });

  testWidgets('device PDFs are listed above recent files', (tester) async {
    SharedPreferences.setMockInitialValues(recentEntry());
    mockDeviceLibrary(
      hasAccess: true,
      pdfs: [
        {
          'name': 'Device Doc.pdf',
          'size': 4096,
          'modified': DateTime(2024, 5, 1).millisecondsSinceEpoch,
          'path': r'C:\docs\Device Doc.pdf',
          'uri': null,
        },
      ],
    );

    await pumpHome(tester);

    expect(find.text('ON THIS DEVICE'), findsOneWidget);
    expect(find.text('RECENT FILES'), findsOneWidget);
    expect(find.text('Device Doc.pdf'), findsOneWidget);
    expect(find.textContaining('4.0 KB'), findsOneWidget);
    // "ON THIS DEVICE" comes before "RECENT FILES".
    expect(
      tester.getTopLeft(find.text('Device Doc.pdf')).dy,
      lessThan(tester.getTopLeft(find.text('Recent.pdf')).dy),
    );
  });

  testWidgets('offers storage access when device PDFs are not available', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(recentEntry());

    await pumpHome(tester);

    expect(find.text('Show PDFs on this device'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Allow access'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Choose folder'),
      findsOneWidget,
    );
  });

  testWidgets('first run offers both opening a file and scanning the phone', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Open your first PDF'), findsOneWidget);
    expect(find.text('Find PDFs on this device'), findsOneWidget);
  });
}
