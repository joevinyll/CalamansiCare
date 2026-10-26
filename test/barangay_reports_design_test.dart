import 'dart:io';
import 'dart:ui' as ui;
import 'package:calamansi_care/main.dart';
import 'package:calamansi_care/data/diagnosis_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const reports = [
  CommunityReport(
      id: 'brown',
      disease: 'Brown Spot',
      confidence: .99,
      farmerName: '',
      location: 'Davao City',
      priority: '',
      deviceSignature: '',
      reportedAt: '2026-10-27T06:15:00Z'),
  CommunityReport(
      id: 'canker',
      disease: 'Citrus Canker',
      confidence: .96,
      farmerName: '',
      location: 'General Santos City',
      priority: '',
      deviceSignature: '',
      reportedAt: '2026-10-26T03:30:00Z'),
  CommunityReport(
      id: 'healthy',
      disease: 'Healthy Fruit',
      confidence: .98,
      farmerName: '',
      location: 'Davao City',
      priority: '',
      deviceSignature: '',
      reportedAt: '2026-10-25T03:30:00Z'),
];

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('Report overview, filters, chart and accordion at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState(persistSettings: false)..isOnline = true;
      addTearDown(state.dispose);
      final capture = GlobalKey();
      if (const bool.fromEnvironment('REPORT_SCREENSHOT')) {
        await tester.runAsync(() async {
          for (final entry in {
            'Roboto': 'roboto-regular.ttf',
            'Ahem': 'roboto-regular.ttf',
            'MaterialIcons': 'materialicons-regular.otf'
          }.entries) {
            final loader = FontLoader(entry.key)
              ..addFont(Future.value(ByteData.sublistView(await File(
                      'D:/flutter/bin/cache/artifacts/material_fonts/${entry.value}')
                  .readAsBytes())));
            await loader.load();
          }
        });
      }
      await tester.pumpWidget(AppScope(
          state: state,
          child: MaterialApp(
              home: RepaintBoundary(
                  key: capture,
                  child: BarangayReportsScreen(
                      loadReports: () async => reports)))));
      await tester.pumpAndSettle();
      expect(find.text('3 shared reports'), findsOneWidget);
      final titleRect = tester.getRect(find.text('Community reports'));
      final badgeRect = tester.getRect(find.text('Internet connected'));
      expect(badgeRect.left, greaterThan(titleRect.right));
      expect(badgeRect.top, lessThan(titleRect.bottom));
      expect(find.text('1 High risk'), findsOneWidget);
      expect(find.text('1 Medium risk'), findsOneWidget);
      expect(find.text('1 Low risk'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Disease information'), 100);
      expect(find.text('Disease information'), findsOneWidget);
      final riskSegment = find.byWidgetPredicate((widget) =>
          widget is ColoredBox && widget.color == const Color(0xFFF59E0B));
      expect(tester.getSize(riskSegment).height, 10);
      expect(find.textContaining('AI Verified'), findsNothing);
      expect(tester.takeException(), isNull);
      if (width == 430 && const bool.fromEnvironment('REPORT_SCREENSHOT')) {
        final boundary =
            capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/barangay-reports-design.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.text('Show Chart'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show Chart'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('risk-chart-High')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('risk-chart-High')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('report-brown')), findsNothing);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('report-canker')), 100);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-canker')));
      await tester.pumpAndSettle();
      final viewportTop = tester.getRect(find.byType(ListView)).top;
      expect(tester.getRect(find.byKey(const ValueKey('report-canker'))).top,
          closeTo(viewportTop, 1),
          reason: 'Expanded card aligns below the fixed header');
      await tester.ensureVisible(find.text('Review selected report'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Review selected report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review selected report'));
      await tester.pumpAndSettle();
      expect(find.text('Diagnosis details'), findsOneWidget);
      expect(find.text('Citrus Canker'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Last short report aligns at the top and collapsing stays manual',
      (tester) async {
    final state = AppState(persistSettings: false)..isOnline = true;
    addTearDown(state.dispose);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(
            home: BarangayReportsScreen(loadReports: () async => reports))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('report-healthy')), 200);
    await tester.tap(find.byKey(const ValueKey('report-healthy')));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('report-healthy'));
    expect(tester.getRect(card).top,
        closeTo(tester.getRect(find.byType(ListView)).top, 1));
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Disease information'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reports show failure then recover with Retry', (tester) async {
    final state = AppState(persistSettings: false)..isOnline = true;
    addTearDown(state.dispose);
    var calls = 0;
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: BarangayReportsScreen(loadReports: () async {
          if (++calls == 1) throw const SocketException('offline');
          return reports;
        }))));
    await tester.pumpAndSettle();
    expect(
        find.text('Could not load reports. Please try again.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('3 shared reports'), findsOneWidget);
  });
}
