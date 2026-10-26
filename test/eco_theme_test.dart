import 'package:calamansi_care/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
}

void main() {
  test('Eco palette keeps body text and primary actions readable', () {
    for (final surface in [CcColors.bg, CcColors.card, CcColors.soft]) {
      expect(contrast(CcColors.ink, surface), greaterThanOrEqualTo(4.5));
      expect(contrast(CcColors.muted, surface), greaterThanOrEqualTo(4.5));
    }
    expect(contrast(Colors.white, CcColors.green), greaterThanOrEqualTo(4.5));
  });

  testWidgets('Shared eco theme uses flat cards and visible focus borders',
      (tester) async {
    await tester.pumpWidget(const CalamansiCareApp(
        enableInitialStatsRefresh: false,
        enableSettingsPersistence: false,
        enableConnectivityMonitor: false));
    await tester.pumpAndSettle();
    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    expect(theme.cardTheme.elevation, 0);
    expect(theme.appBarTheme.scrolledUnderElevation, 0);
    expect(theme.inputDecorationTheme.focusedBorder!.borderSide.width, 2);
    expect(theme.colorScheme.primary, CcColors.green);
    expect(theme.filledButtonTheme.style!.foregroundColor!.resolve({}),
        Colors.white);
    expect(tester.takeException(), isNull);
  });
}
