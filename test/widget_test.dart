import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:calamansi_care/main.dart';

String expectedGreeting({required String language}) {
  final hour = DateTime.now().hour;
  final timeKey = hour < 12
      ? 'morning'
      : hour < 18
          ? 'afternoon'
          : 'evening';

  return switch ((language, timeKey)) {
    ('Tagalog', 'morning') => 'Magandang umaga',
    ('Tagalog', 'afternoon') => 'Magandang hapon',
    ('Tagalog', 'evening') => 'Magandang gabi',
    ('Cebuano', 'morning') => 'Maayong buntag',
    ('Cebuano', 'afternoon') => 'Maayong hapon',
    ('Cebuano', 'evening') => 'Maayong gabii',
    (_, 'morning') => 'Good morning',
    (_, 'afternoon') => 'Good afternoon',
    _ => 'Good evening',
  };
}

Future<void> pumpCalamansiCare(WidgetTester tester, {Widget? app}) async {
  await tester.pumpWidget(
    app ??
        const CalamansiCareApp(
          enableInitialStatsRefresh: false,
          enableSettingsPersistence: false,
          enableConnectivityMonitor: false,
        ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('CalamansiCare welcome screen loads',
      (WidgetTester tester) async {
    await pumpCalamansiCare(tester);

    expect(find.text('CalamansiCare'), findsOneWidget);
    expect(
      find.text('Choose language / Pumili ng wika / Pili og pinulongan'),
      findsOneWidget,
    );
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Tagalog'), findsOneWidget);
    expect(find.text('Cebuano'), findsOneWidget);
  });

  testWidgets('Start plant check opens home and settings',
      (WidgetTester tester) async {
    await pumpCalamansiCare(tester);

    await tester.tap(find.text('Start plant check'));
    await tester.pumpAndSettle();

    expect(find.text(expectedGreeting(language: 'English')), findsOneWidget);
    expect(find.text('New disease check'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Barangay email'), findsOneWidget);
    expect(find.text('agri.office@barangay.gov.ph'), findsNothing);
    expect(find.text('Offline model'), findsOneWidget);
  });

  testWidgets('Language selector translates the visible UI',
      (WidgetTester tester) async {
    await pumpCalamansiCare(tester);

    await tester.tap(find.text('Tagalog'));
    await tester.pumpAndSettle();

    expect(
      find.text('Choose language / Pumili ng wika / Pili og pinulongan'),
      findsOneWidget,
    );
    expect(find.text('Simulan ang pagsusuri'), findsOneWidget);

    await tester.tap(find.text('Simulan ang pagsusuri'));
    await tester.pumpAndSettle();

    expect(find.text(expectedGreeting(language: 'Tagalog')), findsOneWidget);
    expect(find.text('Bagong pagsusuri'), findsOneWidget);
  });

  testWidgets('Capture screen back button returns to home',
      (WidgetTester tester) async {
    await pumpCalamansiCare(tester);

    await tester.tap(find.text('Start plant check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capture'));
    await tester.pumpAndSettle();

    expect(find.text('Capture image'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('New disease check'), findsOneWidget);
  });

  testWidgets('Barangay reports handles large Android text scale',
      (WidgetTester tester) async {
    await pumpCalamansiCare(
      tester,
      app: const MediaQuery(
        data: MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2.8),
        ),
        child: CalamansiCareApp(
          enableInitialStatsRefresh: false,
          enableSettingsPersistence: false,
          enableConnectivityMonitor: false,
        ),
      ),
    );

    await tester.tap(find.text('Start plant check'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open barangay reports'));
    await tester.tap(find.text('Open barangay reports'));
    await tester.pumpAndSettle();

    expect(find.text('Community reports'), findsOneWidget);
    expect(
      find.text('Please connect to the internet to see barangay reports.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
