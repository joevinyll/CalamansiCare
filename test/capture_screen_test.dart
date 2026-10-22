import 'dart:io';

import 'package:calamansi_care/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/camera'),
            (call) async => call.method == 'availableCameras' ? [] : null);
  });

  testWidgets('Gallery selection is capped at ten and photos can be removed',
      (tester) async {
    final state = AppState(persistSettings: false);
    addTearDown(state.dispose);
    var galleryCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/image_picker'),
            (call) async {
      if (call.method == 'pickMultiImage') {
        galleryCalls++;
        return List.filled(12, File('assets/app_icon.png').absolute.path);
      }
      return null;
    });
    await tester.pumpWidget(MaterialApp(
        home: AppScope(state: state, child: const CaptureScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Camera unavailable'), findsOneWidget);
    final emptyScan = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Scan images'));
    expect(emptyScan.onPressed, isNull);

    await tester.ensureVisible(find.text('Upload'));
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(galleryCalls, 1);
    expect(find.text('10 / 10'), findsOneWidget);
    expect(find.text('Scan 10 images'), findsOneWidget);
    expect(find.textContaining('The limit is 10.'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Remove image 1'));
    await tester.tap(find.byTooltip('Remove image 1'));
    await tester.pumpAndSettle();
    expect(find.text('9 / 10'), findsOneWidget);
    expect(find.text('Scan 9 images'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets('Camera controls fit without vertical scrolling at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState(persistSettings: false);
      addTearDown(state.dispose);
      await tester.pumpWidget(MaterialApp(
          home: AppScope(state: state, child: const CaptureScreen())));
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsNothing);
      for (final text in [
        'Capture images',
        'Selected images',
        'Upload',
        'Flip',
        'Scan images'
      ]) {
        final rect = tester.getRect(find.text(text));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
