import 'dart:async';
import 'dart:io';

import 'package:calamansi_care/main.dart';
import 'package:calamansi_care/disease_classifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('Scanning paints queued rows and advances after each image',
      (tester) async {
    final state = AppState(persistSettings: false);
    addTearDown(state.dispose);
    final first = Completer<DiseasePrediction>();
    final second = Completer<DiseasePrediction>();
    var calls = 0;
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(
            home: BatchCheckingScreen(
          images: [
            XFile(File('assets/app_icon.png').absolute.path),
            XFile(File('assets/app_icon.png').absolute.path)
          ],
          classifyImage: (_) => calls++ == 0 ? first.future : second.future,
        ))));
    await tester.pump();
    await tester.pump();
    expect(find.text('0 / 2 images processed'), findsOneWidget);
    expect(find.text('Queued'), findsOneWidget);
    expect(calls, 1);
    first.complete(
        const DiseasePrediction(label: 'Citrus Scab', confidence: .4));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('1 / 2 images processed'), findsOneWidget);
    expect(find.text('Image 1: Needs another scan'), findsOneWidget);
    expect(find.text('Analyzing image 2 of 2'), findsOneWidget);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    second.complete(
        const DiseasePrediction(label: 'Citrus Scab', confidence: .4));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
