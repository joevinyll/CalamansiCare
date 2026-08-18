import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calamansi_care/main.dart';

void main() {
  testWidgets('CalamansiCare welcome screen loads',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CalamansiCareApp());

    expect(find.text('CalamansiCare'), findsOneWidget);
    expect(find.text('Choose language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Tagalog'), findsOneWidget);
    expect(find.text('Cebuano'), findsOneWidget);
  });

  testWidgets('Start plant check opens home and settings',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CalamansiCareApp());

    await tester.tap(find.text('Start plant check'));
    await tester.pumpAndSettle();

    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('New disease check'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Barangay email'), findsOneWidget);
    expect(find.text('Offline model'), findsOneWidget);
  });

  testWidgets('Language selector translates the visible UI',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CalamansiCareApp());

    await tester.tap(find.text('Tagalog'));
    await tester.pumpAndSettle();

    expect(find.text('Pumili ng wika'), findsOneWidget);
    expect(find.text('Simulan ang pagsusuri'), findsOneWidget);

    await tester.tap(find.text('Simulan ang pagsusuri'));
    await tester.pumpAndSettle();

    expect(find.text('Magandang umaga'), findsOneWidget);
    expect(find.text('Bagong pagsusuri'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cebuano'));
    await tester.pumpAndSettle();

    expect(find.text('Maayong buntag'), findsOneWidget);
    expect(find.text('Bag-ong pagsusi'), findsOneWidget);
  });

  testWidgets('Barangay reports handles large Android text scale',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2.8),
        ),
        child: CalamansiCareApp(),
      ),
    );

    await tester.tap(find.text('Start plant check'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open barangay reports'));
    await tester.tap(find.text('Open barangay reports'));
    await tester.pumpAndSettle();

    expect(find.text('Barangay reports'), findsOneWidget);
    expect(find.text('Open selected report'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
