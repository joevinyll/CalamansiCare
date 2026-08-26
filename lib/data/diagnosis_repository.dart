import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Local-first persistence for diagnoses and farmer reports.
///
/// SQLite remains the source of truth on the device. When Supabase has been
/// configured, queued reports are copied to the `diagnosis_reports` table and
/// marked as synced only after the insert succeeds.
class DiagnosisRepository {
  DiagnosisRepository._();

  static final instance = DiagnosisRepository._();
  Database? _database;
  SupabaseClient? _supabase;

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  Future<void> initialise() async {
    final databasePath = await getDatabasesPath();
    _database ??= await openDatabase(
      join(databasePath, 'calamansi_care.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE diagnoses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            disease TEXT NOT NULL,
            confidence REAL NOT NULL,
            image_path TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE queued_reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            diagnosis_id INTEGER,
            office_email TEXT NOT NULL,
            consent INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'queued',
            created_at TEXT NOT NULL,
            synced_at TEXT
          )
        ''');
      },
    );

    if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
      _supabase = Supabase.instance.client;
    }
  }

  Future<int> saveDiagnosis({
    required String disease,
    required double confidence,
    required String imagePath,
  }) async {
    final db = await _db;
    return db.insert('diagnoses', {
      'disease': disease,
      'confidence': confidence,
      'image_path': imagePath,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<int> queueReport({
    required int diagnosisId,
    required String officeEmail,
    required bool consent,
  }) async {
    final db = await _db;
    return db.insert('queued_reports', {
      'diagnosis_id': diagnosisId,
      'office_email': officeEmail,
      'consent': consent ? 1 : 0,
      'status': 'queued',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<int> syncQueuedReports() async {
    final client = _supabase;
    if (client == null) return 0;
    final db = await _db;
    final reports = await db.rawQuery('''
      SELECT r.id, r.office_email, r.created_at, d.disease, d.confidence
      FROM queued_reports r
      JOIN diagnoses d ON d.id = r.diagnosis_id
      WHERE r.status = 'queued' AND r.consent = 1
    ''');
    var synced = 0;
    for (final report in reports) {
      try {
        await client.from('diagnosis_reports').insert({
          'local_report_id': report['id'],
          'office_email': report['office_email'],
          'disease': report['disease'],
          'confidence': report['confidence'],
          'reported_at': report['created_at'],
        });
        await db.update(
          'queued_reports',
          {'status': 'synced', 'synced_at': DateTime.now().toUtc().toIso8601String()},
          where: 'id = ?',
          whereArgs: [report['id']],
        );
        synced++;
      } catch (_) {
        // Keep this record queued: intermittent connectivity must not lose it.
      }
    }
    return synced;
  }

  /// Recent scans joined with their latest report status, newest first.
  /// Used by the History screen so it reflects real SQLite data instead of
  /// placeholder rows.
  Future<List<Map<String, Object?>>> getRecentDiagnoses({int limit = 30}) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT
        d.id,
        d.disease,
        d.confidence,
        d.created_at,
        (
          SELECT r.status FROM queued_reports r
          WHERE r.diagnosis_id = d.id
          ORDER BY r.id DESC LIMIT 1
        ) AS report_status
      FROM diagnoses d
      ORDER BY d.created_at DESC
      LIMIT ?
    ''', [limit]);
  }

  /// Small aggregate used by the Home screen: how many reports are still
  /// waiting to sync, and the confidence of the most recent scan. Called
  /// again after every new scan/queue/sync so the Home cards stay current.
  Future<HomeStats> getHomeStats() async {
    final db = await _db;
    final queuedCountRows = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM queued_reports WHERE status = 'queued'",
    );
    final queuedCount = (queuedCountRows.first['count'] as int?) ?? 0;

    final lastDiagnosisRows = await db.query(
      'diagnoses',
      columns: ['confidence'],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    final lastConfidence = lastDiagnosisRows.isEmpty
        ? null
        : lastDiagnosisRows.first['confidence'] as double?;

    return HomeStats(queuedReports: queuedCount, lastConfidence: lastConfidence);
  }

  Future<Database> get _db async {
    await initialise();
    return _database!;
  }
}

class HomeStats {
  const HomeStats({required this.queuedReports, required this.lastConfidence});

  final int queuedReports;
  final double? lastConfidence;
}
