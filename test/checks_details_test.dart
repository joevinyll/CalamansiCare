import 'package:calamansi_care/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Checks details show matching risk and disease type', (tester) async {
    final state = AppState(persistSettings: false);
    addTearDown(state.dispose);
    for (final entry in [
      ['HLB (Greening)', 'High Risk', 'Bacterial disease'],
      ['Melanose', 'Medium Risk', 'Fungal disease'],
      ['Healthy Fruit', 'No Risk', 'Healthy plant'],
      ['Healthy Leaf', 'No Risk', 'Healthy plant'],
    ]) {
      await tester.pumpWidget(AppScope(state: state, child: MaterialApp(
        home: Scaffold(body: FieldSummaryDetailTile(
          row: {'disease': entry[0], 'confidence': .99},
          kind: FieldSummaryKind.checks)))));
      expect(find.text(entry[1]), findsOneWidget);
      expect(find.text(entry[2]), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
