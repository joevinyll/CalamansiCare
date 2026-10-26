import 'package:calamansi_care/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final online in [true, false]) {
    testWidgets('Connection badge uses real connectivity colour: $online',
        (tester) async {
      final state = AppState(persistSettings: false)..isOnline = online;
      addTearDown(state.dispose);
      await tester.pumpWidget(AppScope(
          state: state,
          child: MaterialApp(
              home: Scaffold(body: OfflinePill(label: state.readinessLabel)))));
      final text = tester.widget<Text>(find.text(state.readinessLabel));
      expect(
          text.style!.color, online ? CcColors.green : const Color(0xFF94510B));
      final container = tester.widget<Container>(find.descendant(
          of: find.byType(OfflinePill), matching: find.byType(Container)));
      expect((container.decoration as BoxDecoration).color,
          online ? CcColors.soft : CcColors.orangeSoft);
      expect(tester.takeException(), isNull);
    });
  }
}
