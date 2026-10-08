import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const reportStatusWaitingInternet = 'waiting_internet';
const reportStatusSyncing = 'syncing';
const reportStatusSynced = 'synced';
const reportStatusFailedRetry = 'failed_retry';
const reportImagesBucket = 'report-images';

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
  Future<void>? _initialiseFuture;

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  Future<void> initialise() {
    _initialiseFuture ??= _initialise();
    return _initialiseFuture!;
  }

  Future<void> _initialise() async {
    final databasePath = await getDatabasesPath();
    _database ??= await openDatabase(
      join(databasePath, 'calamansi_care.db'),
      version: 3,
      onCreate: (db, _) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await _createSettingsTable(db);
        }
        if (oldVersion < 3) {
          await _upgradeQueuedReportsForSync(db);
        }
      },
    );
    await _createSettingsTable(_database!);
    await _upgradeQueuedReportsForSync(_database!);

    if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(
        url: _supabaseUrl,
        publishableKey: _supabaseAnonKey,
      );
      _supabase = Supabase.instance.client;
    }
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
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
            local_report_id TEXT UNIQUE,
            diagnosis_id INTEGER,
            office_email TEXT NOT NULL,
            consent INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'waiting_internet',
            device_id TEXT,
            device_signature TEXT,
            device_model TEXT,
            farmer_name TEXT,
            farmer_location TEXT,
            created_at TEXT NOT NULL,
            synced_at TEXT
          )
    ''');
    await _createSettingsTable(db);
  }

  Future<void> _createSettingsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');
  }

  Future<void> _upgradeQueuedReportsForSync(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(queued_reports)');
    final existingColumns =
        columns.map((column) => column['name'] as String).toSet();

    Future<void> addColumn(String name, String statement) async {
      if (!existingColumns.contains(name)) {
        await db.execute(statement);
        existingColumns.add(name);
      }
    }

    await addColumn('local_report_id',
        'ALTER TABLE queued_reports ADD COLUMN local_report_id TEXT');
    await addColumn(
        'device_id', 'ALTER TABLE queued_reports ADD COLUMN device_id TEXT');
    await addColumn('device_signature',
        'ALTER TABLE queued_reports ADD COLUMN device_signature TEXT');
    await addColumn('device_model',
        'ALTER TABLE queued_reports ADD COLUMN device_model TEXT');
    await addColumn('farmer_name',
        'ALTER TABLE queued_reports ADD COLUMN farmer_name TEXT');
    await addColumn('farmer_location',
        'ALTER TABLE queued_reports ADD COLUMN farmer_location TEXT');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_queued_reports_local_report_id
      ON queued_reports(local_report_id)
    ''');
    await db.update(
      'queued_reports',
      {'status': reportStatusWaitingInternet},
      where: "status = 'queued'",
    );
  }

  Future<AppSettings> loadSettings() async {
    final db = await _db;
    final rows = await db.query('app_settings');
    final values = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    if ((values['device_id'] ?? '').isEmpty) {
      final deviceInfo = await _detectDeviceInfo();
      final deviceId = _generateDeviceId();
      final deviceSignature =
          'CC-${_compactDeviceName(deviceInfo.model)}-${deviceId.substring(deviceId.length - 6)}';
      final settings = AppSettings.fromMap({
        ...values,
        'device_id': deviceId,
        'device_signature': deviceSignature,
        'device_model': deviceInfo.model,
        'device_brand': deviceInfo.brand,
        'android_version': deviceInfo.androidVersion,
      });
      await saveSettings(settings, syncOnline: false);
      return settings;
    }
    return AppSettings.fromMap(values);
  }

  Future<void> saveSettings(
    AppSettings settings, {
    bool syncOnline = true,
  }) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (final entry in settings.toMap().entries) {
        await txn.insert(
          'app_settings',
          {
            'key': entry.key,
            'value': entry.value,
            'updated_at': now,
            'synced_at': null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    if (syncOnline) {
      await syncSettings();
    }
  }

  Future<bool> syncSettings() async {
    final client = _supabase;
    if (client == null) return false;
    final db = await _db;
    final rows = await db.query(
      'app_settings',
      where: 'synced_at IS NULL',
    );
    if (rows.isEmpty) return true;
    final values = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    final settings = AppSettings.fromMap(values);
    try {
      await client.from('farmer_settings').upsert({
        'device_id': settings.deviceId,
        'device_signature': settings.deviceSignature,
        'device_model': settings.deviceModel,
        'device_brand': settings.deviceBrand,
        'android_version': settings.androidVersion,
        'farmer_name': settings.farmerName,
        'farmer_location': settings.farmerLocation,
        'office_email': settings.officeEmail,
        'language': settings.language,
        'consent_enabled': settings.consentEnabled,
        'font_scale': settings.fontScale,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'device_id').timeout(const Duration(seconds: 20));
      await db.update(
        'app_settings',
        {'synced_at': DateTime.now().toUtc().toIso8601String()},
        where: 'synced_at IS NULL',
      );
      return true;
    } catch (_) {
      return false;
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
    required AppSettings settings,
  }) async {
    final db = await _db;
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final localReportId = _generateLocalReportId(settings.deviceId, createdAt);
    return db.insert('queued_reports', {
      'local_report_id': localReportId,
      'diagnosis_id': diagnosisId,
      'office_email': officeEmail,
      'consent': consent ? 1 : 0,
      'status': reportStatusWaitingInternet,
      'device_id': settings.deviceId,
      'device_signature': settings.deviceSignature,
      'device_model': settings.deviceModel,
      'farmer_name': settings.farmerName,
      'farmer_location': settings.farmerLocation,
      'created_at': createdAt,
    });
  }

  Future<int> syncQueuedReports() async {
    final client = _supabase;
    if (client == null) return 0;
    await syncSettings();
    final db = await _db;
    final reports = await db.rawQuery('''
      SELECT
        r.id,
        r.local_report_id,
        r.office_email,
        r.created_at,
        r.device_id,
        r.device_signature,
        r.device_model,
        r.farmer_name,
        r.farmer_location,
        r.consent,
        d.disease,
        d.confidence,
        d.image_path
      FROM queued_reports r
      JOIN diagnoses d ON d.id = r.diagnosis_id
      WHERE r.status IN ('waiting_internet', 'failed_retry') AND r.consent = 1
    ''');
    var synced = 0;
    for (final report in reports) {
      final localReportId = (report['local_report_id'] as String?) ??
          _generateLocalReportId(
            (report['device_id'] as String?) ?? 'legacy-device',
            report['created_at'] as String? ?? DateTime.now().toIso8601String(),
          );
      try {
        await db.update(
          'queued_reports',
          {'status': reportStatusSyncing},
          where: 'id = ?',
          whereArgs: [report['id']],
        );
        final imageUrl = await _uploadReportImage(
          client: client,
          localReportId: localReportId,
          imagePath: report['image_path'] as String?,
        );
        await client.from('diagnosis_reports').upsert({
          'local_report_id': localReportId,
          'device_id': report['device_id'],
          'device_signature': report['device_signature'],
          'device_model': report['device_model'],
          'farmer_name': report['farmer_name'],
          'farmer_location': report['farmer_location'],
          'office_email': report['office_email'],
          'disease': report['disease'],
          'confidence': report['confidence'],
          'image_path': report['image_path'],
          'image_url': imageUrl,
          'consent': report['consent'] == 1,
          'status': reportStatusSynced,
          'reported_at': report['created_at'],
          'synced_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'local_report_id').timeout(const Duration(seconds: 20));
        await _requestReportEmail(client, localReportId);
        await db.update(
          'queued_reports',
          {
            'local_report_id': localReportId,
            'status': reportStatusSynced,
            'synced_at': DateTime.now().toUtc().toIso8601String()
          },
          where: 'id = ?',
          whereArgs: [report['id']],
        );
        synced++;
      } catch (_) {
        await db.update(
          'queued_reports',
          {'local_report_id': localReportId, 'status': reportStatusFailedRetry},
          where: 'id = ?',
          whereArgs: [report['id']],
        );
      }
    }
    return synced;
  }

  Future<void> _requestReportEmail(
    SupabaseClient client,
    String localReportId,
  ) async {
    try {
      await client.functions.invoke(
        'send-report-email',
        body: {'local_report_id': localReportId},
      ).timeout(const Duration(seconds: 20));
    } catch (_) {
      // Email delivery is tracked in Supabase. Do not block local sync if the
      // email function is temporarily unavailable.
    }
  }

  Future<String?> _uploadReportImage({
    required SupabaseClient client,
    required String localReportId,
    required String? imagePath,
  }) async {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    final file = File(imagePath);
    if (!await file.exists()) return null;

    final compressedImage = await _compressReportImage(file);
    final storagePath = 'reports/$localReportId.webp';

    await client.storage.from(reportImagesBucket).uploadBinary(
          storagePath,
          compressedImage,
          fileOptions: const FileOptions(
              contentType: 'image/webp', upsert: true, cacheControl: '3600'),
        );
    return client.storage.from(reportImagesBucket).getPublicUrl(storagePath);
  }

  Future<Uint8List> _compressReportImage(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    const maxSide = 1280;
    final longestSide = max(decoded.width, decoded.height);
    final resized = longestSide > maxSide
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxSide : null,
            height: decoded.height > decoded.width ? maxSide : null,
            interpolation: img.Interpolation.average,
          )
        : decoded;

    return img.encodeWebP(resized);
  }

  Future<List<CommunityReport>> fetchCommunityReports() async {
    final client = _supabase;
    if (client == null) return const [];
    try {
      final rows = await client
          .from('community_reports')
          .select()
          .order('reported_at', ascending: false)
          .limit(30)
          .timeout(const Duration(seconds: 20)) as List<dynamic>;
      return rows
          .map((row) => CommunityReport.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Recent scans joined with their latest report status, newest first.
  /// Used by the History screen so it reflects real SQLite data instead of
  /// placeholder rows.
  Future<List<Map<String, Object?>>> getRecentDiagnoses(
      {int limit = 30}) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT
        d.id,
        d.disease,
        d.confidence,
        d.image_path,
        d.created_at,
        (
          SELECT r.status FROM queued_reports r
          WHERE r.diagnosis_id = d.id
          ORDER BY r.id DESC LIMIT 1
        ) AS report_status
        ,
        (
          SELECT r.office_email FROM queued_reports r
          WHERE r.diagnosis_id = d.id
          ORDER BY r.id DESC LIMIT 1
        ) AS report_email,
        (
          SELECT r.consent FROM queued_reports r
          WHERE r.diagnosis_id = d.id
          ORDER BY r.id DESC LIMIT 1
        ) AS report_consent,
        (
          SELECT r.created_at FROM queued_reports r
          WHERE r.diagnosis_id = d.id
          ORDER BY r.id DESC LIMIT 1
        ) AS report_created_at,
        (
          SELECT r.synced_at FROM queued_reports r
          WHERE r.diagnosis_id = d.id
          ORDER BY r.id DESC LIMIT 1
        ) AS report_synced_at
      FROM diagnoses d
      ORDER BY d.created_at DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<void> markDiagnosisReportForRetry(int diagnosisId) async {
    final db = await _db;
    await db.update(
      'queued_reports',
      {'status': reportStatusWaitingInternet},
      where:
          "diagnosis_id = ? AND status IN ('failed_retry', 'syncing', 'waiting_internet')",
      whereArgs: [diagnosisId],
    );
  }

  Future<void> deleteDiagnosis(int diagnosisId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'queued_reports',
        where: 'diagnosis_id = ?',
        whereArgs: [diagnosisId],
      );
      await txn.delete(
        'diagnoses',
        where: 'id = ?',
        whereArgs: [diagnosisId],
      );
    });
  }

  /// Small aggregate used by the Home screen: how many reports are still
  /// waiting to sync, and the confidence of the most recent scan. Called
  /// again after every new scan/queue/sync so the Home cards stay current.
  Future<HomeStats> getHomeStats() async {
    final db = await _db;
    final checksCountRows =
        await db.rawQuery('SELECT COUNT(*) AS count FROM diagnoses');
    final checksCount = (checksCountRows.first['count'] as int?) ?? 0;

    final queuedCountRows = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM queued_reports WHERE status IN ('waiting_internet', 'syncing', 'failed_retry')",
    );
    final queuedCount = (queuedCountRows.first['count'] as int?) ?? 0;

    final sentCountRows = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM queued_reports WHERE status = 'synced'",
    );
    final sentCount = (sentCountRows.first['count'] as int?) ?? 0;

    final lastDiagnosisRows = await db.query(
      'diagnoses',
      columns: ['confidence'],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    final lastConfidence = lastDiagnosisRows.isEmpty
        ? null
        : lastDiagnosisRows.first['confidence'] as double?;

    return HomeStats(
      checks: checksCount,
      queuedReports: queuedCount,
      sentReports: sentCount,
      lastConfidence: lastConfidence,
    );
  }

  Future<Database> get _db async {
    await initialise();
    return _database!;
  }

  String _generateDeviceId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    final code =
        List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
    return 'device-$code';
  }

  String _generateLocalReportId(String deviceId, String createdAt) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    final code =
        List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();
    final stamp = createdAt.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
    return '$deviceId-$stamp-$code';
  }

  String _compactDeviceName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), '-');
    if (cleaned.isEmpty) return 'Device';
    return cleaned.length <= 18 ? cleaned : cleaned.substring(0, 18);
  }

  Future<_DetectedDeviceInfo> _detectDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        return _DetectedDeviceInfo(
          brand: info.brand,
          model: info.model,
          androidVersion: info.version.release,
        );
      }
    } catch (_) {
      // Fall through to generic values.
    }
    return const _DetectedDeviceInfo(
      brand: 'Unknown',
      model: 'Device',
      androidVersion: 'Unknown',
    );
  }
}

class HomeStats {
  const HomeStats({
    required this.checks,
    required this.queuedReports,
    required this.sentReports,
    required this.lastConfidence,
  });

  final int checks;
  final int queuedReports;
  final int sentReports;
  final double? lastConfidence;
}

class AppSettings {
  const AppSettings({
    required this.language,
    required this.consentEnabled,
    required this.termsAccepted,
    required this.fontScale,
    required this.farmerName,
    required this.farmerLocation,
    required this.locationNote,
    required this.officeEmail,
    required this.deviceId,
    required this.deviceSignature,
    required this.deviceModel,
    required this.deviceBrand,
    required this.androidVersion,
  });

  final String language;
  final bool consentEnabled;
  final bool termsAccepted;
  final double fontScale;
  final String farmerName;
  final String farmerLocation;
  final String locationNote;
  final String officeEmail;
  final String deviceId;
  final String deviceSignature;
  final String deviceModel;
  final String deviceBrand;
  final String androidVersion;

  factory AppSettings.fromMap(Map<String, String> map) {
    return AppSettings(
      language: map['language'] ?? 'English',
      consentEnabled: map['consent_enabled'] != 'false',
      termsAccepted: map['terms_accepted'] == 'true',
      fontScale: double.tryParse(map['font_scale'] ?? '') ?? 1,
      farmerName: map['farmer_name'] ?? '',
      farmerLocation: map['farmer_location'] ?? '',
      locationNote: map['location_note'] ?? 'Location not set',
      officeEmail: map['office_email'] ?? '',
      deviceId: map['device_id'] ?? 'device-local',
      deviceSignature: map['device_signature'] ?? 'CC-Device-LOCAL',
      deviceModel: map['device_model'] ?? 'Device',
      deviceBrand: map['device_brand'] ?? 'Unknown',
      androidVersion: map['android_version'] ?? 'Unknown',
    );
  }

  Map<String, String> toMap() {
    return {
      'language': language,
      'consent_enabled': '$consentEnabled',
      'terms_accepted': '$termsAccepted',
      'font_scale': '$fontScale',
      'farmer_name': farmerName,
      'farmer_location': farmerLocation,
      'location_note': locationNote,
      'office_email': officeEmail,
      'device_id': deviceId,
      'device_signature': deviceSignature,
      'device_model': deviceModel,
      'device_brand': deviceBrand,
      'android_version': androidVersion,
    };
  }
}

class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.disease,
    required this.confidence,
    required this.location,
    required this.priority,
    required this.deviceSignature,
    required this.reportedAt,
    this.imageUrl,
  });

  final String id;
  final String disease;
  final double confidence;
  final String location;
  final String priority;
  final String deviceSignature;
  final String reportedAt;
  final String? imageUrl;

  factory CommunityReport.fromMap(Map<String, dynamic> map) {
    return CommunityReport(
      id: '${map['id'] ?? ''}',
      disease: '${map['disease'] ?? 'Unknown'}',
      confidence: ((map['confidence'] as num?)?.toDouble() ?? 0),
      location: '${map['farmer_location'] ?? 'Unknown area'}',
      priority: '${map['priority'] ?? 'Needs review'}',
      deviceSignature: '${map['device_signature'] ?? 'Unknown device'}',
      reportedAt: '${map['reported_at'] ?? ''}',
      imageUrl: (map['image_url'] as String?)?.trim().isEmpty == true
          ? null
          : map['image_url'] as String?,
    );
  }
}

class _DetectedDeviceInfo {
  const _DetectedDeviceInfo({
    required this.brand,
    required this.model,
    required this.androidVersion,
  });

  final String brand;
  final String model;
  final String androidVersion;
}
