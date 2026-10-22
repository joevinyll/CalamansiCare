import 'dart:io';
import 'package:calamansi_care/main.dart';
import 'package:calamansi_care/disease_classifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

List<BatchScanResult> sampleBatch({bool uncertain = false}) => List.generate(
    10,
    (i) => (
          file: XFile(File('assets/app_icon.png').absolute.path),
          prediction: DiseasePrediction(
              label: i == 0
                  ? 'Healthy Fruit'
                  : i < 4
                      ? 'Citrus Scab'
                      : 'Melanose',
              confidence: uncertain && i == 9 ? .4 : .90 + i / 1000),
          id: uncertain && i == 9 ? null : i + 1,
          error: uncertain && i == 9 ? 'Retake this image.' : null,
        ));

Future<void> showBatch(WidgetTester tester, {bool uncertain = false}) async {
  final state = AppState(persistSettings: false);
  addTearDown(state.dispose);
  await tester.pumpWidget(MaterialApp(
      home: AppScope(
          state: state,
          child:
              BatchResultsScreen(results: sampleBatch(uncertain: uncertain)))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Tab fill tracks partial card swipes', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showBatch(tester);
    await tester.scrollUntilVisible(find.text('Recommendations'), 200,
        scrollable: find.byType(Scrollable).first);
    final tabs = find.widgetWithText(TextButton, 'Conventional');
    await Scrollable.ensureVisible(tester.element(tabs), alignment: .25);
    await tester.pumpAndSettle();
    Color? tabColor() => tester.widget<TextButton>(
        find.byKey(const ValueKey('care-tab-0'))).style!.backgroundColor!.resolve({});
    final start = tabColor();
    final cards = find.byType(PageView);
    final gesture = await tester.startGesture(tester.getCenter(cards));
    await gesture.moveBy(const Offset(-25, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    expect(tabColor(), isNot(start));
    expect(tabColor(), isNot(const Color(0xFFF6F8FA)));
    final controller = tester.widget<PageView>(cards).controller!;
    expect(controller.page, greaterThan(0));
    expect(controller.page, lessThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Condition selector remains pinned and usable while scrolling', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showBatch(tester);
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('sticky-care-selector')), 180, scrollable: scroll);
    await tester.pumpAndSettle();
    await tester.drag(scroll, const Offset(0, -350));
    await tester.pumpAndSettle();
    final header = find.byKey(const ValueKey('sticky-care-selector'));
    expect(tester.getTopLeft(header).dy, greaterThanOrEqualTo(55));
    expect(tester.getTopLeft(header).dy, lessThan(150));
    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Melanose').last);
    await tester.pumpAndSettle();
    expect(find.text('Rain carries spores mainly from dead twigs.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('Spread descriptions exclude healthy results', () {
    expect(diseaseSpreadFor('HLB (Greening)'), contains('psyllid'));
    expect(
        diseaseSpreadFor('Brown Spot'), startsWith('If caused by Alternaria'));
    expect(diseaseSpreadFor('Melanose'), contains('dead twigs'));
    expect(diseaseSpreadFor('Healthy Fruit'), isNull);
    expect(diseaseSpreadFor('Healthy Leaf'), isNull);
  });
  testWidgets('Bottom actions clear Android navigation and gesture insets',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    for (final bottom in [24.0, 48.0]) {
      tester.view.padding = FakeViewPadding(bottom: bottom);
      tester.view.viewPadding = FakeViewPadding(bottom: bottom);
      await showBatch(tester);
      final scroll = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scroll).position;
      for (var step = 0; step < 4; step++) {
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      await tester.pumpAndSettle();
      expect(
          tester
              .getBottomRight(find.widgetWithText(TextButton, 'Back to camera'))
              .dy,
          lessThanOrEqualTo(844 - bottom));
      expect(
          tester
              .getBottomRight(find.widgetWithText(FilledButton, 'Save results'))
              .dy,
          lessThanOrEqualTo(844 - bottom));
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('Healthy fruit and leaf have no care recommendations',
      (tester) async {
    final state = AppState(persistSettings: false);
    addTearDown(state.dispose);
    final file = XFile(File('assets/app_icon.png').absolute.path);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(
            home: BatchResultsScreen(results: [
          for (final label in ['Healthy Fruit', 'Healthy Leaf'])
            (
              file: file,
              prediction: DiseasePrediction(label: label, confidence: .99),
              id: 1,
              error: null
            ),
        ]))));
    await tester.pumpAndSettle();
    expect(find.text('No Risk'), findsNWidgets(2));
    expect(find.text('Recommendations'), findsNothing);
    expect(find.text('Natural care'), findsNothing);
    expect(find.text('Low Risk'), findsNothing);
    await tester.scrollUntilVisible(find.text('View report summary'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'View report summary'))
            .onPressed,
        isNotNull);
  });
  testWidgets('Processing and saving errors are not called low confidence',
      (tester) async {
    final state = AppState(persistSettings: false);
    addTearDown(state.dispose);
    final file = XFile(File('assets/app_icon.png').absolute.path);
    await tester.pumpWidget(MaterialApp(
        home: AppScope(
            state: state,
            child: BatchResultsScreen(results: [
              (
                file: file,
                prediction: null,
                id: null,
                error: 'Could not process image.'
              ),
              (
                file: file,
                prediction: const DiseasePrediction(
                    label: 'Citrus Scab', confidence: .99),
                id: null,
                error: 'Database write failed.'
              ),
            ]))));
    await tester.pumpAndSettle();
    expect(find.text('Could not scan'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Could not save'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Could not save'), findsOneWidget);
    expect(find.text('Needs another scan'), findsNothing);
    expect(find.textContaining('Retake these images'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Batch percentages use the complete batch and photos expand',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showBatch(tester);
    expect(find.text('10 images scanned'), findsOneWidget);
    expect(find.text('10% (1 image)'), findsOneWidget);
    expect(find.text('30% (3 images)'), findsOneWidget);
    expect(find.text('60% (6 images)'), findsOneWidget);
    Finder confidenceRow() => find
        .ancestor(of: find.text('Confidence: 90%'), matching: find.byType(Row))
        .first;
    expect(find.descendant(of: confidenceRow(), matching: find.text('No Risk')),
        findsOneWidget);
    await tester.tap(find.text('View Images').first);
    await tester.pumpAndSettle();
    expect(find.text('Image 1 - 90%'), findsOneWidget);
    expect(find.descendant(of: confidenceRow(), matching: find.text('No Risk')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Uncertain photos remain separate from accepted results',
      (tester) async {
    await showBatch(tester, uncertain: true);
    await tester.scrollUntilVisible(find.text('Needs another scan'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('50% (5 images)'), findsOneWidget);
    expect(
        find.text(
            'Retake these images in good lighting and keep the calamansi fruit or leaf clearly in focus.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Care panels switch on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showBatch(tester);
    await tester.scrollUntilVisible(find.text('Recommendations'), 250,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(find.text('Conventional')),
        alignment: .4);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conventional'));
    await tester.pumpAndSettle();
    expect(find.text('Conventional treatment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
