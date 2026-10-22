import 'dart:io';
import 'package:calamansi_care/main.dart';
import 'package:calamansi_care/disease_classifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('Scan details return button restores the previous page',
      (tester) async {
    final state = AppState(persistSettings: false);
    addTearDown(state.dispose);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                        body: TextButton(
                      child: const Text('Open scan details'),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => DiagnosisScreen(
                                  prediction: const DiseasePrediction(
                                      label: 'Brown Spot', confidence: .99),
                                  imageFile: XFile(File('assets/app_icon.png')
                                      .absolute
                                      .path),
                                  diagnosisId: 1,
                                  imageNumber: 4))),
                    ))))));
    await tester.tap(find.text('Open scan details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Image 4 Result'), findsOneWidget);
    expect(find.text('Analyzed photo'), findsNothing);
    final frame =
        tester.getSize(find.byKey(const ValueKey('diagnosis-photo-frame')));
    expect(frame.width, frame.height);
    final photo = tester.widget<LeafImage>(find.byType(LeafImage));
    expect(photo.fit, BoxFit.contain);
    await tester.scrollUntilVisible(find.text('Likely disease'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(find.text('Likely disease'), findsOneWidget);
    expect(find.text(diseaseDescriptionFor('Brown Spot')), findsOneWidget);
    expect(find.textContaining('common HLB symptoms'), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open scan details'), findsOneWidget);
    expect(find.byType(DiagnosisScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
