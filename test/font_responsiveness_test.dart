import 'dart:io';
import 'package:calamansi_care/main.dart';
import 'package:calamansi_care/disease_classifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0]) {
    for (final scale in [.9, 1.0, 1.1, 1.2, 1.3]) {
      testWidgets('Screens fit width $width at font $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
                const MethodChannel('plugins.flutter.io/camera'),
                (call) async => call.method == 'availableCameras' ? [] : null);
        final state = AppState(persistSettings: false)
          ..fontScale = scale
          ..farmerName = 'Joevinyll Jan Palabrica'
          ..farmerLocation = 'Poblacion District, Davao City, Davao del Sur'
          ..officeEmail = 'agriculture@example.org'
          ..accountEmail = 'farmer@example.com';
        addTearDown(state.dispose);
        final photo = File('assets/app_icon.png').absolute.path;
        final results = List<BatchScanResult>.generate(
            10,
            (i) => (
                  file: XFile(photo),
                  prediction: DiseasePrediction(
                      label: i < 4 ? 'Citrus Scab' : 'Melanose',
                      confidence: .96),
                  id: i + 1,
                  error: null
                ));
        final batch = ScanHistoryBatch(List.generate(
            10,
            (i) => <String, Object?>{
                  'id': i + 1,
                  'batch_id': 'test',
                  'batch_total_count': 10,
                  'batch_image_index': i,
                  'disease': results[i].prediction!.label,
                  'confidence': .96,
                  'image_path': photo,
                  'created_at': '2026-10-22T01:41:00Z'
                }));
        for (final screen in <Widget>[
          const SettingsScreen(),
          const EditProfileScreen(),
          const CaptureScreen(),
          BatchResultsScreen(results: results),
          BatchHistoryDetailsScreen(batch: batch),
          BatchReportSummaryScreen(batch: batch),
        ]) {
          await tester.pumpWidget(AppScope(
              state: state,
              child: MaterialApp(
                  key: UniqueKey(),
                  theme: ThemeData(fontFamily: 'Roboto'),
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!),
                  home: screen)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '${screen.runtimeType}');
          if (screen is BatchResultsScreen) {
            await tester.scrollUntilVisible(find.text('Recommendations'), 180,
                scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'Recommendations');
          }
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
}
