import 'dart:io';
import 'package:calamansi_care/main.dart';
import 'package:calamansi_care/data/diagnosis_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, Object?> row(int id,
        {String? batch, String? status, String disease = 'Citrus Scab'}) =>
    {
      'id': id,
      'batch_id': batch,
      'batch_total_count': batch == null ? 1 : 2,
      'batch_image_index': id % 2,
      'disease': disease,
      'confidence': .95,
      'image_path': File('assets/app_icon.png').absolute.path,
      'created_at': '2026-10-22T01:41:00Z',
      'report_id': status == null ? null : id,
      'report_status': status,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('History labels single images separately from multi-image batches', () {
    expect(ScanHistoryBatch([row(123)]).title, 'Image 123');
    expect(ScanHistoryBatch([row(7)]).title, 'Image 007');
    expect(ScanHistoryBatch([row(124, batch: 'a'), row(125, batch: 'a')]).title,
        'Batch 124');
    expect(ScanHistoryBatch([row(124, batch: 'a')]).title, 'Batch 124');
  });
  testWidgets('Report status distinguishes online queue, offline and failure',
      (tester) async {
    final state = AppState(persistSettings: false)
      ..accountEmail = 'farmer@example.com';
    addTearDown(state.dispose);
    Future<void> show(bool online, String status) async {
      state.isOnline = online;
      await tester.pumpWidget(AppScope(
          state: state,
          child: MaterialApp(
              key: UniqueKey(),
              home: BatchReportSummaryScreen(
                  batch: ScanHistoryBatch([row(1, status: status)])))));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Send Report'), 180,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
    }

    await show(true, reportStatusWaitingInternet);
    expect(find.text('Queued to send'), findsOneWidget);
    expect(find.text('Waiting for internet connection'), findsNothing);
    expect(find.text('Go to Dashboard'), findsNothing);
    await show(false, reportStatusWaitingInternet);
    expect(find.text('Waiting for internet connection'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Go to Dashboard'), 120,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Go to Dashboard'), findsOneWidget);
    await show(true, reportStatusFailedRetry);
    expect(find.text('Waiting for internet connection'), findsOneWidget);
    expect(find.textContaining('check the report service'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final initiallyOffline in [true, false]) {
    testWidgets(
        'Offline report reveals full-width dashboard button (initial: $initiallyOffline)',
        (tester) async {
      tester.view.physicalSize = const Size(390, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState(persistSettings: false)
        ..isOnline = !initiallyOffline;
      addTearDown(state.dispose);
      final batch = ScanHistoryBatch(List.generate(
          9,
          (i) => row(i + 1,
              batch: 'offline',
              status: reportStatusWaitingInternet,
              disease: [
                'Citrus Canker',
                'Melanose',
                'HLB (Greening)'
              ][i % 3])));
      await tester.pumpWidget(AnimatedBuilder(
          animation: state,
          builder: (context, _) => AppScope(
              state: state,
              child:
                  MaterialApp(home: BatchReportSummaryScreen(batch: batch)))));
      await tester.pumpAndSettle();
      if (!initiallyOffline) {
        state.isOnline = false;
        await state.setConsent(false);
        await tester.pumpAndSettle();
      }
      expect(find.text('Go to Dashboard').hitTestable(), findsOneWidget);
      final dashboard = find.widgetWithText(OutlinedButton, 'Go to Dashboard');
      final retry = find.widgetWithText(FilledButton, 'Try sending now');
      expect(tester.getSize(dashboard).width, tester.getSize(retry).width);
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      expect(position.pixels, closeTo(position.maxScrollExtent, 1));
      position.jumpTo(0);
      await tester.pumpAndSettle();
      await state.setConsent(true);
      await tester.pumpAndSettle();
      expect(position.pixels, 0,
          reason: 'Ordinary rebuilds must not force another scroll');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Single batch preview stays square instead of stretching',
      (tester) async {
    final state = AppState(persistSettings: false);
    addTearDown(state.dispose);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(
            home:
                BatchReportSummaryScreen(batch: ScanHistoryBatch([row(1)])))));
    await tester.pumpAndSettle();
    final image = find.byType(Image).first;
    final size = tester.getSize(image);
    expect(size.width, closeTo(size.height, .01));
    expect(size.width, lessThanOrEqualTo(58));
    expect(tester.takeException(), isNull);
  });
  test('Explicit batch IDs group photos and old scans stay separate', () {
    final batches = groupScanHistory(
        [row(1, batch: 'a'), row(2, batch: 'a'), row(3), row(4)]);
    expect(batches.length, 3);
    expect(batches.singleWhere((b) => b.key == 'a').rows.length, 2);
    expect(batches.where((b) => b.rows.length == 1).length, 2);
  });

  test('A batch is sent only when all of its images are sent', () {
    expect(ScanHistoryBatch([row(1, status: reportStatusSynced), row(2)]).sent,
        isFalse);
    expect(ScanHistoryBatch([row(1), row(2)]).status, 'Saved on device');
    expect(
        ScanHistoryBatch([
          row(1, status: reportStatusSynced),
          row(2, status: reportStatusWaitingInternet)
        ]).waiting,
        isTrue);
    expect(
        ScanHistoryBatch([
          row(1, status: reportStatusSynced),
          row(2, status: reportStatusSynced)
        ]).status,
        'Sent');
  });

  testWidgets('Batch details open the real summary on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(persistSettings: false);
    addTearDown(state.dispose);
    final batch = ScanHistoryBatch(
        [row(1, batch: 'a'), row(2, batch: 'a', disease: 'Healthy Fruit')]);
    await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: BatchHistoryDetailsScreen(batch: batch))));
    await tester.pumpAndSettle();
    expect(find.text('Results by condition'), findsOneWidget);
    await tester.ensureVisible(find.text('View report summary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View report summary'));
    await tester.pumpAndSettle();
    expect(find.text('Report summary'), findsOneWidget);
    expect(find.text('Batch results'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Version 6 scans survive migration and new batches persist', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory =
        await Directory.systemTemp.createTemp('calamansi-batches-');
    await databaseFactory.setDatabasesPath(directory.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => directory.path);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null));
    final path = '${directory.path}/calamansi_care.db';
    final old = await openDatabase(path, version: 6, onCreate: (db, _) async {
      await db.execute(
          'CREATE TABLE diagnoses (id INTEGER PRIMARY KEY AUTOINCREMENT, disease TEXT NOT NULL, confidence REAL NOT NULL, image_path TEXT, user_id TEXT, created_at TEXT NOT NULL)');
      await db.execute(
          "CREATE TABLE queued_reports (id INTEGER PRIMARY KEY AUTOINCREMENT, diagnosis_id INTEGER, office_email TEXT NOT NULL, consent INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'waiting_internet', created_at TEXT NOT NULL, synced_at TEXT)");
      await db.insert(
          'diagnoses',
          row(1)
            ..removeWhere((key, _) => ![
                  'id',
                  'disease',
                  'confidence',
                  'image_path',
                  'created_at'
                ].contains(key)));
    });
    await old.close();
    final repo = DiagnosisRepository.instance;
    await repo.initialise();
    final liveDb = await openDatabase(path);
    expect(await liveDb.getVersion(), 7);
    // Simulate new Dart code attached to an already-open pre-batch database.
    for (final column in [
      'batch_id',
      'batch_total_count',
      'batch_image_index'
    ]) {
      await liveDb.execute('ALTER TABLE diagnoses DROP COLUMN $column');
    }
    await repo.saveDiagnosis(
        disease: 'Citrus Scab',
        confidence: .95,
        imagePath: 'fixture',
        batchId: 'new-batch',
        batchTotalCount: 2);
    await repo.saveDiagnosis(
        disease: 'Healthy Fruit',
        confidence: .99,
        imagePath: 'fixture',
        batchId: 'new-batch',
        batchTotalCount: 2,
        batchImageIndex: 1);
    final rows = await repo.getRecentDiagnoses(limit: null);
    expect(rows.length, 3);
    expect(rows.singleWhere((r) => r['id'] == 1)['batch_id'], isNull);
    expect(groupScanHistory(rows).length, 2);
    expect(rows.where((r) => r['batch_id'] == 'new-batch').length, 2);
    final db = await openDatabase(path);
    expect(await db.getVersion(), 7);
    final batchIds = rows
        .where((r) => r['batch_id'] == 'new-batch')
        .map((r) => r['id'] as int)
        .toList();
    for (final id in batchIds) {
      await db.insert('queued_reports', {
        'diagnosis_id': id,
        'office_email': 'office@example.org',
        'consent': 1,
        'status': 'waiting_internet',
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    await repo.deleteDiagnoses(batchIds);
    final remaining = await repo.getRecentDiagnoses(limit: null);
    expect(remaining.map((r) => r['id']), [1]);
    expect(await db.query('queued_reports'), isEmpty);
    await repo.deleteDiagnoses([]);
    expect((await repo.getRecentDiagnoses(limit: null)).length, 1);
    await db.close();
  });
}
