import 'package:calamansi_care/data/treatment_content.dart';
import 'package:calamansi_care/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supported conditions match the eight-class model output order', () {
    expect(diseaseLabels, const [
      'Anthracnose',
      'Brown Spot',
      'Citrus Canker',
      'Citrus Scab',
      'HLB (Greening)',
      'Healthy Fruit',
      'Healthy Leaf',
      'Melanose',
    ]);
    expect(treatmentAdviceByDisease.keys, unorderedEquals(diseaseLabels));
  });

  test('Every supported condition uses the revised advice in each language',
      () {
    expect(treatmentAdviceByDisease.keys, containsAll(diseaseLabels));
    for (final disease in diseaseLabels) {
      final advice = treatmentAdviceByDisease[disease]!;
      final guidance = guidanceFor(disease);
      expect(guidance.conventionalTreatment, advice.chemical.english);
      expect(guidance.organicTreatment, advice.cultural.english);
      expect(guidance.recommendation, advice.cultural.english);
      for (final text in [advice.cultural, advice.chemical]) {
        expect(AppText.of('Tagalog', text.english), text.tagalog);
        expect(AppText.of('Cebuano', text.english), text.cebuano);
        expect(text.tagalog, isNotEmpty);
        expect(text.cebuano, isNotEmpty);
      }
    }
  });

  for (final language in supportedLanguages) {
    testWidgets('Guide and recommendation show chemical reminder in $language',
        (tester) async {
      final state = AppState(persistSettings: false)..language = language;
      addTearDown(state.dispose);
      final advice = guidanceFor('Citrus Canker');
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.linear(1.8),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      GuideTile(
                        icon: Icons.science_outlined,
                        title: 'Chemical Options',
                        text: advice.conventionalTreatment,
                      ),
                      TreatmentRecommendationCard(guidance: advice),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.text(AppText.of(language, chemicalTreatmentReminder.english)),
        findsNWidgets(2),
      );
      expect(find.text(AppText.of(language, 'Chemical Options')),
          findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
}
