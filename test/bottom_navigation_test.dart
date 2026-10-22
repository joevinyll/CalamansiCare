import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:calamansi_care/main.dart';

void main() {
  testWidgets('Feed paints behind the raised camera without a background strip',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(persistSettings: false);
    addTearDown(state.dispose);
    const frame = ValueKey('navigation-pixels');
    const content = ValueKey('feed-content');
    await tester.pumpWidget(MaterialApp(
        home: AppScope(
            state: state,
            child: const RepaintBoundary(
                key: frame,
                child: ScreenFrame(
                    allowCameraOverlap: true,
                    child: ColoredBox(
                        key: content,
                        color: Color(0xFFFF0000),
                        child: SizedBox.expand()))))));
    await tester.pumpAndSettle();
    final nav = tester.getRect(find.byType(AppBottomNav));
    expect(
        tester.getRect(find.byKey(content)).bottom, closeTo(nav.top + 26, 1));
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(frame));
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final offset = ((nav.top + 12).toInt() * image.width + 40) * 4;
      expect(bytes!.buffer.asUint8List().sublist(offset, offset + 4),
          [255, 0, 0, 255]);
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/camera'),
            (call) async => call.method == 'availableCameras' ? [] : null);
  });
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Navigation fits a narrow phone with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(persistSettings: false);
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
        home: AppScope(
      state: state,
      child: const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Scaffold(bottomNavigationBar: AppBottomNav()),
      ),
    )));
    expect(find.text('Community'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [430.0]) {
    testWidgets('Navigation layout and actions at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const CalamansiCareApp(
        enableInitialStatsRefresh: false,
        enableSettingsPersistence: false,
        enableConnectivityMonitor: false,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start plant check'));
      await tester.pumpAndSettle();
      final nav = find.byType(AppBottomNav);
      Finder label(String name) =>
          find.descendant(of: nav, matching: find.text(name));
      expect(label('Check'), findsNothing);
      expect(tester.getCenter(label('Home')).dx,
          lessThan(tester.getCenter(label('History')).dx));
      expect(tester.getCenter(label('Community')).dx,
          lessThan(tester.getCenter(label('Settings')).dx));
      expect(tester.takeException(), isNull);
      await tester.tap(label('Community'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityFeedScreen), findsOneWidget);
      expect(find.text('Sign in to view and share updates with other farmers.'),
          findsOneWidget);
      await tester.tap(label('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      await tester.tap(find.byTooltip('Camera'));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
