import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagelit/l10n/app_localizations.dart';
import 'package:pagelit/screens/presentation_viewer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File tempPptxFile;

  setUp(() async {
    final archive = Archive();

    const presXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldSz cx="12192000" cy="6858000"/>
  <p:sldIdLst>
    <p:sldId id="256" r:id="rId1"/>
  </p:sldIdLst>
</p:presentation>''';

    const presRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
  <Relationship Id="rIdTheme" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
</Relationships>''';

    const themeXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
  <a:themeElements>
    <a:clrScheme name="Office">
      <a:dk1><a:srgbClr val="000000"/></a:dk1>
      <a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
      <a:accent1><a:srgbClr val="FF4500"/></a:accent1>
    </a:clrScheme>
  </a:themeElements>
</a:theme>''';

    const slide1Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="1000000" y="500000"/><a:ext cx="8000000" cy="1500000"/></a:xfrm>
        </p:spPr>
        <p:txBody>
          <a:p>
            <a:r>
              <a:rPr sz="2800" b="1">
                <a:solidFill><a:schemeClr val="accent1"/></a:solidFill>
              </a:rPr>
              <a:t>MX-LAB Maintenance</a:t>
            </a:r>
          </a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';

    archive.addFile(ArchiveFile('ppt/presentation.xml', presXml.length, utf8.encode(presXml)));
    archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', presRelsXml.length, utf8.encode(presRelsXml)));
    archive.addFile(ArchiveFile('ppt/theme/theme1.xml', themeXml.length, utf8.encode(themeXml)));
    archive.addFile(ArchiveFile('ppt/slides/slide1.xml', slide1Xml.length, utf8.encode(slide1Xml)));

    final zipBytes = ZipEncoder().encode(archive);
    tempPptxFile = File('${Directory.systemTemp.path}/test_presentation.pptx');
    await tempPptxFile.writeAsBytes(zipBytes);
  });

  tearDown(() async {
    try {
      if (await tempPptxFile.exists()) {
        await tempPptxFile.delete();
      }
    } catch (_) {}
  });

  testWidgets('PresentationViewerScreen displays authentic visual slide and toggles to outline view', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PresentationViewerScreen(
            filePath: tempPptxFile.path,
            title: 'test_presentation.pptx',
          ),
        ),
      );

      // Wait for real file I/O to complete
      await Future.delayed(const Duration(milliseconds: 250));
    });
    await tester.pump();

    // 1. In Slide Presentation Mode by default:
    // Finds SlideCanvasView and InteractiveViewer
    expect(find.byType(SlideCanvasView), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('MX-LAB Maintenance'), findsAtLeastNWidgets(1));

    // 2. Toggle to Outline View
    final toggleModeButton = find.byIcon(Icons.format_list_bulleted_rounded);
    expect(toggleModeButton, findsOneWidget);
    await tester.tap(toggleModeButton);
    await tester.pump();

    // Now in Outline Mode: shows outline list/card and switch button turns to slideshow
    expect(find.byIcon(Icons.slideshow_rounded), findsOneWidget);

    // 3. Toggle back to Slide Mode
    await tester.tap(find.byIcon(Icons.slideshow_rounded));
    await tester.pump();

    expect(find.byType(SlideCanvasView), findsOneWidget);

    // 4. Start Fullscreen Slideshow
    final playButton = find.byIcon(Icons.play_circle_fill_rounded);
    expect(playButton, findsOneWidget);
    await tester.tap(playButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // In Slideshow screen
    expect(find.byType(PresentationSlideshowScreen), findsOneWidget);
    expect(find.text('MX-LAB Maintenance'), findsAtLeastNWidgets(1));

    // Exit Slideshow
    final exitButton = find.byIcon(Icons.arrow_back_rounded);
    expect(exitButton, findsOneWidget);
    await tester.tap(exitButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PresentationSlideshowScreen), findsNothing);
  });
}
