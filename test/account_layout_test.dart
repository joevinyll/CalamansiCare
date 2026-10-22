import 'package:calamansi_care/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('Account flows fit $width at maximum font size',
        (tester) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState(persistSettings: false)..authConfigured = true;
      addTearDown(state.dispose);
      await tester.pumpWidget(AppScope(
          state: state,
          child: MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!),
              home: const AuthLandingScreen())));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Create account').first);
      await tester.pumpAndSettle();
      expect(find.text('Farmer name'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
