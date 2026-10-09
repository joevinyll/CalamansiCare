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

  bool get isSupabaseConfigured => _supabase != null;
  User? get currentUser => _supabase?.auth.currentUser;
  Stream<AuthState>? get authStateChanges => _supabase?.auth.onAuthStateChange;

  Future<void> initialise() {
    _initialiseFuture ??= _initialise();
    return _initialiseFuture!;
  }

  Future<void> _initialise() async {
    final databasePath = await getDatabasesPath();
    _database ??= await openDatabase(
      join(databasePath, 'calamansi_care.db'),
      version: 5,
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
        if (oldVersion < 4) {
          await _upgradeQueuedReportsForAuth(db);
        }
        if (oldVersion < 5) {
          await _upgradeDiagnosesForAuth(db);
        }
      },
    );
    await _createSettingsTable(_database!);
    await _upgradeQueuedReportsForSync(_database!);
    await _upgradeQueuedReportsForAuth(_database!);
    await _upgradeDiagnosesForAuth(_database!);

    if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(
        url: _supabaseUrl,
        publishableKey: _supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
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
        user_id TEXT,
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
            user_id TEXT,
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

  Future<void> _upgradeQueuedReportsForAuth(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(queued_reports)');
    final existingColumns =
        columns.map((column) => column['name'] as String).toSet();
    if (!existingColumns.contains('user_id')) {
      await db.execute('ALTER TABLE queued_reports ADD COLUMN user_id TEXT');
    }
  }

  Future<void> _upgradeDiagnosesForAuth(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(diagnoses)');
    final existingColumns =
        columns.map((column) => column['name'] as String).toSet();
    if (!existingColumns.contains('user_id')) {
      await db.execute('ALTER TABLE diagnoses ADD COLUMN user_id TEXT');
    }
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

  Future<void> clearLocalAccountData(AppSettings settingsToKeep) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('queued_reports');
      await txn.delete('diagnoses');
      await txn.delete('app_settings');
      for (final entry in settingsToKeep.toMap().entries) {
        await txn.insert(
          'app_settings',
          {
            'key': entry.key,
            'value': entry.value,
            'updated_at': now,
            'synced_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
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
        'user_id': client.auth.currentUser?.id,
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
      await upsertFarmerProfile(settings);
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

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required AppSettings settings,
  }) async {
    final client = _requireSupabase();
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'farmer_name': settings.farmerName,
        'farmer_location': settings.farmerLocation,
        'office_email': settings.officeEmail,
        'device_signature': settings.deviceSignature,
      },
    );
    return response;
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    final client = _requireSupabase();
    return client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<bool> signInWithGoogle() {
    final client = _requireSupabase();
    return client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.calamansicare://login-callback/',
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final client = _requireSupabase();
    await client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'io.supabase.calamansicare://reset-password/',
    );
  }

  Future<void> signOut() async {
    final client = _requireSupabase();
    await client.auth.signOut();
  }

  Future<void> upsertFarmerProfile(AppSettings settings) async {
    final client = _supabase;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    await client.from('farmer_profiles').upsert({
      'user_id': user.id,
      'farmer_name': settings.farmerName,
      'farmer_location': settings.farmerLocation,
      'office_email': settings.officeEmail,
      'language': settings.language,
      'consent_enabled': settings.consentEnabled,
      'font_scale': settings.fontScale,
      'device_id': settings.deviceId,
      'device_signature': settings.deviceSignature,
      'device_model': settings.deviceModel,
      'device_brand': settings.deviceBrand,
      'android_version': settings.androidVersion,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id').timeout(const Duration(seconds: 20));
  }

  Future<FarmerProfile?> fetchFarmerProfile() async {
    final client = _supabase;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return null;
    final rows = await client
        .from('farmer_profiles')
        .select()
        .eq('user_id', user.id)
        .limit(1)
        .timeout(const Duration(seconds: 20)) as List<dynamic>;
    if (rows.isEmpty) return null;
    return FarmerProfile.fromMap(Map<String, dynamic>.from(rows.first));
  }

  Future<FarmerProfile?> fetchLatestReportProfile() async {
    final client = _supabase;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return null;
    final rows = await client
        .from('diagnosis_reports')
        .select('farmer_name, farmer_location, office_email')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .timeout(const Duration(seconds: 20)) as List<dynamic>;
    if (rows.isEmpty) return null;
    return FarmerProfile.fromMap({
      ...Map<String, dynamic>.from(rows.first as Map),
      'language': 'English',
      'consent_enabled': true,
      'font_scale': 1.0,
    });
  }

  Future<int> restoreSignedInReports() async {
    final client = _supabase;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return 0;
    final db = await _db;
    final rows = await client
        .from('diagnosis_reports')
        .select()
        .eq('user_id', user.id)
        .order('reported_at', ascending: false)
        .limit(100)
        .timeout(const Duration(seconds: 20)) as List<dynamic>;
    var restored = 0;
    for (final item in rows) {
      final row = Map<String, dynamic>.from(item as Map);
      final localReportId = '${row['local_report_id'] ?? ''}';
      if (localReportId.trim().isEmpty) continue;
      final existing = await db.query(
        'queued_reports',
        columns: ['id'],
        where: 'local_report_id = ?',
        whereArgs: [localReportId],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;
      final createdAt =
          '${row['reported_at'] ?? row['created_at'] ?? DateTime.now().toUtc().toIso8601String()}';
      final diagnosisId = await db.insert('diagnoses', {
        'disease': '${row['disease'] ?? 'Unknown'}',
        'confidence': ((row['confidence'] as num?)?.toDouble() ?? 0),
        'image_path': null,
        'user_id': user.id,
        'created_at': createdAt,
      });
      await db.insert('queued_reports', {
        'local_report_id': localReportId,
        'diagnosis_id': diagnosisId,
        'office_email': '${row['office_email'] ?? ''}',
        'consent': row['consent'] == true ? 1 : 0,
        'status': reportStatusSynced,
        'device_id': '${row['device_id'] ?? ''}',
        'device_signature': '${row['device_signature'] ?? ''}',
        'device_model': '${row['device_model'] ?? ''}',
        'user_id': user.id,
        'farmer_name': '${row['farmer_name'] ?? ''}',
        'farmer_location': '${row['farmer_location'] ?? ''}',
        'created_at': createdAt,
        'synced_at':
            '${row['synced_at'] ?? DateTime.now().toUtc().toIso8601String()}',
      });
      restored++;
    }
    return restored;
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
      'user_id': _supabase?.auth.currentUser?.id,
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
    final user = _supabase?.auth.currentUser;
    if (user == null) {
      throw const AuthRequiredException();
    }
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
      'user_id': user.id,
      'farmer_name': settings.farmerName,
      'farmer_location': settings.farmerLocation,
      'created_at': createdAt,
    });
  }

  Future<int> syncQueuedReports() async {
    final client = _supabase;
    if (client == null) return 0;
    final user = client.auth.currentUser;
    if (user == null) return 0;
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
        r.user_id,
        r.farmer_name,
        r.farmer_location,
        r.consent,
        d.disease,
        d.confidence,
        d.image_path
      FROM queued_reports r
      JOIN diagnoses d ON d.id = r.diagnosis_id
      WHERE r.status IN ('waiting_internet', 'failed_retry')
        AND r.consent = 1
        AND r.user_id = ?
    ''', [user.id]);
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
          'user_id': report['user_id'] ?? user.id,
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
    final userId = _supabase?.auth.currentUser?.id;
    final userFilter = userId == null ? 'd.user_id IS NULL' : 'd.user_id = ?';
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
      WHERE $userFilter
      ORDER BY d.created_at DESC
      LIMIT ?
    ''', userId == null ? [limit] : [userId, limit]);
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

  Future<Map<String, Object?>?> getLatestReportSummary() async {
    final db = await _db;
    final userId = _supabase?.auth.currentUser?.id;
    final userFilter = userId == null ? 'r.user_id IS NULL' : 'r.user_id = ?';
    final rows = await db.rawQuery('''
      SELECT
        r.id,
        r.local_report_id,
        r.office_email,
        r.consent,
        r.status,
        r.farmer_name,
        r.farmer_location,
        r.created_at AS report_created_at,
        r.synced_at AS report_synced_at,
        d.id AS diagnosis_id,
        d.disease,
        d.confidence,
        d.image_path,
        d.created_at AS scan_created_at
      FROM queued_reports r
      JOIN diagnoses d ON d.id = r.diagnosis_id
      WHERE $userFilter
      ORDER BY r.created_at DESC, r.id DESC
      LIMIT 1
    ''', userId == null ? const [] : [userId]);
    if (rows.isEmpty) return null;
    return rows.first;
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
    final userId = _supabase?.auth.currentUser?.id;
    final diagnosisFilter = userId == null ? 'user_id IS NULL' : 'user_id = ?';
    final reportFilter = userId == null ? 'user_id IS NULL' : 'user_id = ?';
    final userArgs = userId == null ? const <Object?>[] : <Object?>[userId];

    final checksCountRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM diagnoses WHERE $diagnosisFilter',
      userArgs,
    );
    final checksCount = (checksCountRows.first['count'] as int?) ?? 0;

    final queuedCountRows = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM queued_reports WHERE $reportFilter AND status IN ('waiting_internet', 'syncing', 'failed_retry')",
      userArgs,
    );
    final queuedCount = (queuedCountRows.first['count'] as int?) ?? 0;

    final sentCountRows = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM queued_reports WHERE $reportFilter AND status = 'synced'",
      userArgs,
    );
    final sentCount = (sentCountRows.first['count'] as int?) ?? 0;

    final lastDiagnosisRows = await db.rawQuery(
      'SELECT confidence FROM diagnoses WHERE $diagnosisFilter ORDER BY created_at DESC LIMIT 1',
      userArgs,
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

  SupabaseClient _requireSupabase() {
    final client = _supabase;
    if (client == null) {
      throw const SupabaseUnavailableException();
    }
    return client;
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

class SupabaseUnavailableException implements Exception {
  const SupabaseUnavailableException();
}

class AuthRequiredException implements Exception {
  const AuthRequiredException();
}

class FarmerProfile {
  const FarmerProfile({
    required this.farmerName,
    required this.farmerLocation,
    required this.officeEmail,
    required this.language,
    required this.consentEnabled,
    required this.fontScale,
  });

  final String farmerName;
  final String farmerLocation;
  final String officeEmail;
  final String language;
  final bool consentEnabled;
  final double fontScale;

  factory FarmerProfile.fromMap(Map<String, dynamic> map) {
    return FarmerProfile(
      farmerName: '${map['farmer_name'] ?? ''}',
      farmerLocation: '${map['farmer_location'] ?? ''}',
      officeEmail: '${map['office_email'] ?? ''}',
      language: '${map['language'] ?? 'English'}',
      consentEnabled: map['consent_enabled'] != false,
      fontScale: ((map['font_scale'] as num?)?.toDouble() ?? 1).clamp(.9, 1.3),
    );
  }
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
    required this.farmerName,
    required this.location,
    required this.priority,
    required this.deviceSignature,
    required this.reportedAt,
    this.imageUrl,
  });

  final String id;
  final String disease;
  final double confidence;
  final String farmerName;
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
      farmerName: '${map['farmer_name'] ?? ''}',
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
