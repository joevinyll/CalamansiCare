import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, visibleForTesting;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_security.dart';
import 'secure_auth_storage.dart';

const reportStatusWaitingInternet = 'waiting_internet';
const reportStatusSyncing = 'syncing';
const reportStatusSynced = 'synced';
const reportStatusFailedRetry = 'failed_retry';
const reportImagesBucket = 'report-images';
const maxAvatarBytes = 5 * 1024 * 1024;

String reportSyncErrorMessage(Object error) {
  if (error is PostgrestException && error.code == 'PGRST202') {
    return 'Batch reporting is not set up on the server. Apply the batch email migration and deploy send-report-email. Your images are saved.';
  }
  if (error is StorageException &&
      (error.statusCode == '403' || error.statusCode == '400')) {
    return 'Image upload was rejected. Check the report-images storage policies and file size limit. Your images are saved.';
  }
  if (error is FunctionException) {
    return 'The report email service rejected delivery. Check the deployed send-report-email function and its logs. Your images are saved.';
  }
  return 'Could not finish sending. Your images are saved; try again or check the report service.';
}

String reportImageStoragePath(String farmerName, String reportId) {
  final name = farmerName
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final folder =
      name.isEmpty ? 'farmer' : name.substring(0, min(name.length, 64));
  final id = sha256.convert(utf8.encode(reportId)).toString();
  return 'reports/$folder/report-$id.webp';
}

/// Local-first persistence for diagnoses and farmer reports.
///
/// SQLite remains the source of truth on the device. When Supabase has been
/// configured, queued reports are copied to the `diagnosis_reports` table and
/// marked as synced only after the insert succeeds.
class DiagnosisRepository {
  String? lastReportSyncError;
  DiagnosisRepository._();

  static final instance = DiagnosisRepository._();
  Database? _database;
  SupabaseClient? _supabase;
  Future<void>? _initialiseFuture;
  Future<void>? _batchSchemaFuture;
  SecureAuthStorage? _authStorage;

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  bool get isSupabaseConfigured => _supabase != null;
  SupabaseClient get communityClient => _requireSupabase();
  User? get currentUser => _supabase?.auth.currentUser;
  Stream<AuthState>? get authStateChanges => _supabase?.auth.onAuthStateChange;

  Future<void> initialise() {
    _initialiseFuture ??= _initialise();
    return _initialiseFuture!;
  }

  Future<void> _initialise() async {
    var freshInstall = false;
    final databasePath = await getDatabasesPath();
    _database ??= await openDatabase(
      join(databasePath, 'calamansi_care.db'),
      version: 7,
      onCreate: (db, _) async {
        freshInstall = true;
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
        if (oldVersion < 6) {
          await _upgradeQueuedReportsForCoordinates(db);
        }
        if (oldVersion < 7) {
          await _upgradeDiagnosisBatches(db);
        }
      },
    );
    await _createSettingsTable(_database!);
    await _upgradeQueuedReportsForSync(_database!);
    await _upgradeQueuedReportsForAuth(_database!);
    await _upgradeDiagnosesForAuth(_database!);
    await _upgradeQueuedReportsForCoordinates(_database!);

    if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
      final sessionKey =
          'sb-${Uri.parse(_supabaseUrl).host.split('.').first}-auth-token';
      _authStorage = SecureAuthStorage(
          key: sessionKey,
          legacy: SharedPreferencesLocalStorage(persistSessionKey: sessionKey),
          freshInstall: freshInstall,
          legacyPkce: SharedPreferencesGotrueAsyncStorage());
      await Supabase.initialize(
        url: _supabaseUrl,
        publishableKey: _supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          localStorage: _authStorage,
          pkceAsyncStorage: SecurePkceStorage(
            legacy: SharedPreferencesLocalStorage(
              persistSessionKey: '$sessionKey-code-verifier',
            ),
          ),
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
        batch_id TEXT,
        batch_total_count INTEGER NOT NULL DEFAULT 1,
        batch_image_index INTEGER NOT NULL DEFAULT 0,
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
            latitude REAL,
            longitude REAL,
            created_at TEXT NOT NULL,
            synced_at TEXT
          )
    ''');
    await _createSettingsTable(db);
  }

  Future<void> _upgradeDiagnosisBatches(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(diagnoses)');
    final names = columns.map((row) => row['name']).toSet();
    for (final entry in {
      'batch_id': 'TEXT',
      'batch_total_count': 'INTEGER NOT NULL DEFAULT 1',
      'batch_image_index': 'INTEGER NOT NULL DEFAULT 0',
    }.entries) {
      if (!names.contains(entry.key)) {
        await db.execute(
            'ALTER TABLE diagnoses ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
  }

  Future<void> _ensureBatchSchema(Database db) async {
    final pending = _batchSchemaFuture ??= _upgradeDiagnosisBatches(db);
    try {
      await pending;
    } catch (_) {
      if (identical(_batchSchemaFuture, pending)) _batchSchemaFuture = null;
      rethrow;
    }
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
    await addColumn(
        'latitude', 'ALTER TABLE queued_reports ADD COLUMN latitude REAL');
    await addColumn(
        'longitude', 'ALTER TABLE queued_reports ADD COLUMN longitude REAL');
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

  Future<void> _upgradeQueuedReportsForCoordinates(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(queued_reports)');
    final existingColumns =
        columns.map((column) => column['name'] as String).toSet();
    if (!existingColumns.contains('latitude')) {
      await db.execute('ALTER TABLE queued_reports ADD COLUMN latitude REAL');
    }
    if (!existingColumns.contains('longitude')) {
      await db.execute('ALTER TABLE queued_reports ADD COLUMN longitude REAL');
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
      for (final entry in {
        ...settings.toMap(),
        'account_user_id': currentUser?.id ?? '',
      }.entries) {
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

  Future<bool> hasLocalAccountData() async {
    final db = await _db;
    final account = await db.query('app_settings',
        columns: ['key'],
        where: "key = 'account_user_id' AND value != ''",
        limit: 1);
    if (account.isNotEmpty) return true;
    if ((await db.query('queued_reports',
            columns: ['id'], where: 'user_id IS NOT NULL', limit: 1))
        .isNotEmpty) {
      return true;
    }
    return (await db.query('diagnoses',
            columns: ['id'], where: 'user_id IS NOT NULL', limit: 1))
        .isNotEmpty;
  }

  Future<void> clearLocalAccountData(AppSettings settingsToKeep) async {
    final db = await _db;
    final avatars = await db
        .query('app_settings', where: 'key = ?', whereArgs: ['avatar_path']);
    for (final row in avatars) {
      await deleteProfileAvatar(row['value'] as String? ?? '');
    }
    final images = await db.query('diagnoses', columns: ['image_path']);
    await _deleteCachedDiagnosisImages(images);
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
    var didSync = false;
    var profileSynced = false;
    try {
      await upsertFarmerProfile(settings);
      profileSynced = client.auth.currentUser != null;
      didSync = true;
    } catch (_) {
      // Profile sync can retry later when Supabase/RLS is ready.
    }
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
        'latitude': settings.latitude,
        'longitude': settings.longitude,
        'office_email': settings.officeEmail,
        'language': settings.language,
        'consent_enabled': settings.consentEnabled,
        'font_scale': settings.fontScale,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'device_id').timeout(const Duration(seconds: 20));
      didSync = true;
    } catch (_) {
      // Device settings sync can retry later. Profile sync above is enough for
      // account restore and Supabase farmer details.
    }
    if (!didSync || !profileSynced) return false;
    await db.update(
      'app_settings',
      {'synced_at': DateTime.now().toUtc().toIso8601String()},
      where: 'synced_at IS NULL',
    );
    return true;
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

  Future<bool> signInWithGoogle() async {
    final client = _requireSupabase();
    final opened = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.calamansicare://login-callback/',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    if (!opened) throw StateError('Could not open Google sign-in.');
    return opened;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final client = _requireSupabase();
    await client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'io.supabase.calamansicare://reset-password/',
    );
  }

  Future<void> signOut() async {
    final client = _supabase;
    await signOutThisDevice(
        revokeSession: () async {
          await client?.auth.signOut(scope: SignOutScope.local);
        },
        hasSession: () => client?.auth.currentSession != null,
        clearPersistedSession: () async {
          await _authStorage?.removePersistedSession();
        });
  }

  Future<void> upsertFarmerProfile(AppSettings settings) async {
    final client = _supabase;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    final db = await _db;
    final markers = await db.query('app_settings',
        where: 'key = ?', whereArgs: ['avatar_uploaded_path']);
    final uploadedPath =
        markers.isEmpty ? null : markers.first['value'] as String?;
    final includeAvatar =
        settings.avatarPath.isNotEmpty || uploadedPath != null;
    String? avatarObjectPath;
    if (settings.avatarPath.isNotEmpty) {
      avatarObjectPath = '${user.id}/${basename(settings.avatarPath)}';
      if (settings.avatarPath != uploadedPath) {
        final bytes = await compute(
            encodeReportImage, await File(settings.avatarPath).readAsBytes());
        await client.storage.from('profile-avatars').uploadBinary(
            avatarObjectPath, bytes,
            fileOptions:
                const FileOptions(contentType: 'image/webp', upsert: true));
      }
    }
    if (client.auth.currentUser?.id != user.id) return;
    await client.from('farmer_profiles').upsert({
      'user_id': user.id,
      'farmer_name': settings.farmerName,
      'farmer_location': settings.farmerLocation,
      'latitude': settings.latitude,
      'longitude': settings.longitude,
      'office_email': settings.officeEmail,
      'language': settings.language,
      'consent_enabled': settings.consentEnabled,
      'font_scale': settings.fontScale,
      if (includeAvatar) 'avatar_object_path': avatarObjectPath,
      'device_id': settings.deviceId,
      'device_signature': settings.deviceSignature,
      'device_model': settings.deviceModel,
      'device_brand': settings.deviceBrand,
      'android_version': settings.androidVersion,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id').timeout(const Duration(seconds: 20));
    if (includeAvatar && client.auth.currentUser?.id == user.id) {
      await db.insert(
          'app_settings',
          {
            'key': 'avatar_uploaded_path',
            'value': settings.avatarPath,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'synced_at': DateTime.now().toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<String?> restoreProfileAvatar(String? objectPath) async {
    final client = _supabase;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return null;
    final db = await _db;
    final markers = await db.query('app_settings',
        where: 'key = ?', whereArgs: ['avatar_uploaded_path']);
    // A marker means this device has an existing photo or a pending removal.
    if (markers.isNotEmpty) return null;
    if (objectPath == null ||
        !objectPath.startsWith('${user.id}/') ||
        objectPath.split('/').length != 2 ||
        objectPath.contains('..')) {
      return null;
    }
    final bytes =
        await client.storage.from('profile-avatars').download(objectPath);
    if (bytes.length > maxAvatarBytes) {
      throw const FormatException('Avatar is too large.');
    }
    final encoded = await compute(encodeReportImage, bytes);
    if (client.auth.currentUser?.id != user.id) return null;
    final support = await getApplicationSupportDirectory();
    final directory = await Directory(join(support.path, 'profile_avatars'))
        .create(recursive: true);
    final path = join(directory.path, basename(objectPath));
    await File(path).writeAsBytes(encoded, flush: true);
    if (client.auth.currentUser?.id != user.id) {
      await deleteProfileAvatar(path);
      return null;
    }
    await db.insert(
        'app_settings',
        {
          'key': 'avatar_uploaded_path',
          'value': path,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'synced_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    return path;
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
        .select(
            'farmer_name, farmer_location, office_email, latitude, longitude')
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
      if (currentUser?.id != user.id) return restored;
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
        'latitude': (row['latitude'] as num?)?.toDouble(),
        'longitude': (row['longitude'] as num?)?.toDouble(),
        'created_at': createdAt,
        'synced_at':
            '${row['synced_at'] ?? DateTime.now().toUtc().toIso8601String()}',
      });
      restored++;
    }
    return restored;
  }

  Future<void> attachLocalRowsToCurrentUser() async {
    final user = _supabase?.auth.currentUser;
    if (user == null) return;
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'diagnoses',
        {'user_id': user.id},
        where: 'user_id IS NULL',
      );
      await txn.update(
        'queued_reports',
        {'user_id': user.id},
        where: 'user_id IS NULL',
      );
    });
  }

  Future<int> saveDiagnosis({
    required String disease,
    required double confidence,
    required String imagePath,
    String? batchId,
    int batchTotalCount = 1,
    int batchImageIndex = 0,
  }) async {
    final db = await _db;
    await _ensureBatchSchema(db);
    return db.insert('diagnoses', {
      'disease': disease,
      'confidence': confidence,
      'image_path': imagePath,
      'batch_id': batchId,
      'batch_total_count': batchTotalCount,
      'batch_image_index': batchImageIndex,
      'user_id': _supabase?.auth.currentUser?.id,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<String> cacheDiagnosisImage(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists() || await source.length() > maxSourceImageBytes) {
      throw const FormatException(
          'Image is unavailable or exceeds the size limit.');
    }
    final bytes = await compute(encodeReportImage, await source.readAsBytes(),
        debugLabel: 'CalamansiCare photo compression');
    final cache = await getTemporaryDirectory();
    final filename =
        'calamansi-${Random.secure().nextInt(0x7fffffff).toRadixString(16)}.webp';
    return (await File(join(cache.path, filename))
            .writeAsBytes(bytes, flush: true))
        .path;
  }

  Future<String> cacheProfileAvatar(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists() || await source.length() > maxAvatarBytes) {
      throw const FormatException(
          'Please choose a profile photo of 5 MB or less.');
    }
    final bytes = await compute(encodeReportImage, await source.readAsBytes());
    final support = await getApplicationSupportDirectory();
    final directory = await Directory(join(support.path, 'profile_avatars'))
        .create(recursive: true);
    final path = join(directory.path,
        'avatar-${Random.secure().nextInt(0x7fffffff).toRadixString(16)}.webp');
    return (await File(path).writeAsBytes(bytes, flush: true)).path;
  }

  Future<void> deleteProfileAvatar(String path) async {
    if (path.isEmpty) return;
    final support = await getApplicationSupportDirectory();
    await deleteCachedImages(
        [path], Directory(join(support.path, 'profile_avatars')));
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
    await db.update(
      'diagnoses',
      {'user_id': user.id},
      where: 'id = ? AND user_id IS NULL',
      whereArgs: [diagnosisId],
    );
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
      'latitude': settings.latitude,
      'longitude': settings.longitude,
      'created_at': createdAt,
    });
  }

  Future<void> queueBatchReports({
    required List<int> diagnosisIds,
    required AppSettings settings,
  }) async {
    if (!settings.consentEnabled) {
      throw StateError('Report consent is required.');
    }
    final user = currentUser;
    if (user == null) throw const AuthRequiredException();
    final db = await _db;
    await db.transaction((txn) async {
      for (final id in diagnosisIds.toSet()) {
        final rows = await txn.query('diagnoses',
            where: 'id = ? AND (user_id = ? OR user_id IS NULL)',
            whereArgs: [id, user.id]);
        if (rows.isEmpty) {
          throw StateError('Scan is unavailable for this account.');
        }
        await txn.update('diagnoses', {'user_id': user.id},
            where: 'id = ? AND user_id IS NULL', whereArgs: [id]);
        final reports = await txn.query('queued_reports',
            where: 'diagnosis_id = ? AND user_id = ?',
            whereArgs: [id, user.id],
            limit: 1);
        if (reports.isNotEmpty) continue;
        final createdAt = DateTime.now().toUtc().toIso8601String();
        await txn.insert('queued_reports', {
          'local_report_id':
              _generateLocalReportId(settings.deviceId, createdAt),
          'diagnosis_id': id,
          'office_email': settings.officeEmail,
          'consent': 1,
          'status': reportStatusWaitingInternet,
          'device_id': settings.deviceId,
          'device_signature': settings.deviceSignature,
          'device_model': settings.deviceModel,
          'user_id': user.id,
          'farmer_name': settings.farmerName,
          'farmer_location': settings.farmerLocation,
          'latitude': settings.latitude,
          'longitude': settings.longitude,
          'created_at': createdAt,
        });
      }
    });
  }

  Future<int> syncQueuedReports() async {
    lastReportSyncError = null;
    final client = _supabase;
    if (client == null) return 0;
    final user = client.auth.currentUser;
    if (user == null) return 0;
    await attachLocalRowsToCurrentUser();
    await syncSettings();
    final db = await _db;
    await _ensureBatchSchema(db);
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
        r.latitude,
        r.longitude,
        r.consent,
        d.disease,
        d.confidence,
        d.batch_id,
        d.created_at AS scanned_at,
        d.image_path
      FROM queued_reports r
      JOIN diagnoses d ON d.id = r.diagnosis_id
      WHERE r.status IN ('waiting_internet', 'failed_retry')
        AND r.consent = 1
        AND r.user_id = ?
    ''', [user.id]);
    if (reports.isEmpty) return 0;
    try {
      // An empty batch is rejected before any claims or email side effects.
      await client.rpc('claim_batch_report_email', params: {
        'report_ids': <String>[]
      }).timeout(const Duration(seconds: 20));
    } catch (error) {
      lastReportSyncError = reportSyncErrorMessage(error);
      return 0;
    }
    var synced = 0;
    final uploaded = <String, List<({int id, String reportId})>>{};
    String deliveryGroup(Map<String, Object?> row) =>
        '${row['batch_id'] ?? 'scan-${row['id']}'}:${row['office_email']}';
    for (final report in reports) {
      final localReportId = (report['local_report_id'] as String?) ??
          _generateLocalReportId(
            (report['device_id'] as String?) ?? 'legacy-device',
            report['created_at'] as String? ?? DateTime.now().toIso8601String(),
          );
      try {
        await db.update(
          'queued_reports',
          {'status': reportStatusSyncing, 'local_report_id': localReportId},
          where: 'id = ?',
          whereArgs: [report['id']],
        );
        final imageUrl = await _uploadReportImage(
          client: client,
          localReportId: localReportId,
          farmerName: report['farmer_name'] as String? ?? '',
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
          'latitude': report['latitude'],
          'longitude': report['longitude'],
          'office_email': report['office_email'],
          'disease': report['disease'],
          'confidence': report['confidence'],
          'image_path': report['image_path'],
          'image_url': imageUrl,
          'consent': report['consent'] == 1,
          'status': reportStatusSynced,
          'reported_at': report['created_at'],
          'scanned_at': report['scanned_at'],
          'synced_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'local_report_id').timeout(const Duration(seconds: 20));
        uploaded
            .putIfAbsent(deliveryGroup(report), () => [])
            .add((id: report['id'] as int, reportId: localReportId));
        await db.update(
          'queued_reports',
          {
            'local_report_id': localReportId,
            'status': reportStatusWaitingInternet,
          },
          where: 'id = ?',
          whereArgs: [report['id']],
        );
      } catch (error) {
        lastReportSyncError = reportSyncErrorMessage(error);
        await db.update(
          'queued_reports',
          {'local_report_id': localReportId, 'status': reportStatusFailedRetry},
          where: 'id = ?',
          whereArgs: [report['id']],
        );
      }
    }
    for (final entry in uploaded.entries) {
      if (entry.value.length !=
          reports.where((r) => deliveryGroup(r) == entry.key).length) {
        continue;
      }
      try {
        await _requestReportEmail(
            client, entry.value.map((r) => r.reportId).toList());
        await db.transaction((txn) async {
          for (final row in entry.value) {
            await txn.update(
                'queued_reports',
                {
                  'status': reportStatusSynced,
                  'synced_at': DateTime.now().toUtc().toIso8601String(),
                },
                where: 'id = ?',
                whereArgs: [row.id]);
          }
        });
        synced += entry.value.length;
      } catch (error) {
        lastReportSyncError = reportSyncErrorMessage(error);
        for (final row in entry.value) {
          await db.update('queued_reports', {'status': reportStatusFailedRetry},
              where: 'id = ?', whereArgs: [row.id]);
        }
      }
    }
    return synced;
  }

  Future<void> _requestReportEmail(
    SupabaseClient client,
    List<String> localReportIds,
  ) async {
    final response = await client.functions.invoke(
      'send-report-email',
      body: {'local_report_ids': localReportIds},
    ).timeout(const Duration(seconds: 20));
    if (response.status >= 300 ||
        response.data is! Map ||
        response.data['ok'] != true) {
      throw StateError('Report email was not accepted.');
    }
  }

  Future<String?> _uploadReportImage({
    required SupabaseClient client,
    required String localReportId,
    required String farmerName,
    required String? imagePath,
  }) async {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    final file = File(imagePath);
    if (!await file.exists()) return null;

    final compressedImage = await compressReportImage(file);
    final storagePath = reportImageStoragePath(farmerName, localReportId);

    await client.storage.from(reportImagesBucket).uploadBinary(
          storagePath,
          compressedImage,
          fileOptions: const FileOptions(
              contentType: 'image/webp', upsert: true, cacheControl: '3600'),
        );
    return client.storage.from(reportImagesBucket).getPublicUrl(storagePath);
  }

  @visibleForTesting
  Future<Uint8List> compressReportImage(File file) async {
    if (await file.length() > maxSourceImageBytes) {
      throw const FormatException('Image exceeds the size limit.');
    }
    return compute(encodeReportImage, await file.readAsBytes(),
        debugLabel: 'CalamansiCare report compression');
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
      {int? limit = 30}) async {
    final db = await _db;
    await _ensureBatchSchema(db);
    final userId = _supabase?.auth.currentUser?.id;
    final userFilter = userId == null ? 'd.user_id IS NULL' : 'd.user_id = ?';
    return db.rawQuery('''
      SELECT
        d.id,
        d.batch_id,
        d.batch_total_count,
        d.batch_image_index,
        d.disease,
        d.confidence,
        d.image_path,
        d.created_at,
        (
          SELECT r.id FROM queued_reports r
          WHERE r.diagnosis_id = d.id
          ORDER BY r.id DESC LIMIT 1
        ) AS report_id,
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
        , (SELECT r.farmer_name FROM queued_reports r WHERE r.diagnosis_id = d.id ORDER BY r.id DESC LIMIT 1) AS report_farmer_name
        , (SELECT r.farmer_location FROM queued_reports r WHERE r.diagnosis_id = d.id ORDER BY r.id DESC LIMIT 1) AS report_farmer_location
      FROM diagnoses d
      WHERE $userFilter
      ORDER BY d.created_at DESC
      ${limit == null ? '' : 'LIMIT ?'}
    ''', [if (userId != null) userId, if (limit != null) limit]);
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

  Future<String?> getReportStatus(int reportId) async {
    final db = await _db;
    final rows = await db.query(
      'queued_reports',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [reportId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['status'] as String?;
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
        r.latitude,
        r.longitude,
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
    await deleteDiagnoses([diagnosisId]);
  }

  Future<void> deleteDiagnoses(List<int> diagnosisIds) async {
    if (diagnosisIds.isEmpty) return;
    final db = await _db;
    final placeholders = List.filled(diagnosisIds.length, '?').join(',');
    final images = await db.query('diagnoses',
        columns: ['image_path'],
        where: 'id IN ($placeholders)',
        whereArgs: diagnosisIds);
    await db.transaction((txn) async {
      await txn.delete(
        'queued_reports',
        where: 'diagnosis_id IN ($placeholders)',
        whereArgs: diagnosisIds,
      );
      await txn.delete(
        'diagnoses',
        where: 'id IN ($placeholders)',
        whereArgs: diagnosisIds,
      );
    });
    await _deleteCachedDiagnosisImages(images);
  }

  Future<void> _deleteCachedDiagnosisImages(
      List<Map<String, Object?>> rows) async {
    final paths =
        rows.map((row) => row['image_path']).whereType<String>().toList();
    if (paths.isEmpty) return;
    try {
      await deleteCachedImages(paths, await getTemporaryDirectory());
    } on FileSystemException {
      // Database cleanup must continue if the operating system evicts the cache.
    }
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
    required this.latitude,
    required this.longitude,
    required this.officeEmail,
    required this.language,
    required this.consentEnabled,
    required this.fontScale,
    this.avatarObjectPath,
  });

  final String farmerName;
  final String farmerLocation;
  final double? latitude;
  final double? longitude;
  final String officeEmail;
  final String language;
  final bool consentEnabled;
  final double fontScale;
  final String? avatarObjectPath;

  factory FarmerProfile.fromMap(Map<String, dynamic> map) {
    return FarmerProfile(
      farmerName: '${map['farmer_name'] ?? ''}',
      avatarObjectPath: map['avatar_object_path'] as String?,
      farmerLocation: '${map['farmer_location'] ?? ''}',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
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
    required this.latitude,
    required this.longitude,
    required this.locationNote,
    required this.officeEmail,
    required this.deviceId,
    required this.deviceSignature,
    required this.deviceModel,
    required this.deviceBrand,
    required this.androidVersion,
    this.avatarPath = '',
  });

  final String language;
  final bool consentEnabled;
  final bool termsAccepted;
  final double fontScale;
  final String farmerName;
  final String farmerLocation;
  final double? latitude;
  final double? longitude;
  final String locationNote;
  final String officeEmail;
  final String deviceId;
  final String deviceSignature;
  final String deviceModel;
  final String deviceBrand;
  final String androidVersion;
  final String avatarPath;

  factory AppSettings.fromMap(Map<String, String> map) {
    return AppSettings(
      language: map['language'] ?? 'English',
      consentEnabled: map['consent_enabled'] != 'false',
      termsAccepted: map['terms_accepted'] == 'true',
      fontScale: double.tryParse(map['font_scale'] ?? '') ?? 1,
      farmerName: map['farmer_name'] ?? '',
      avatarPath: map['avatar_path'] ?? '',
      farmerLocation: map['farmer_location'] ?? '',
      latitude: double.tryParse(map['latitude'] ?? ''),
      longitude: double.tryParse(map['longitude'] ?? ''),
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
      'avatar_path': avatarPath,
      'farmer_location': farmerLocation,
      'latitude': latitude?.toString() ?? '',
      'longitude': longitude?.toString() ?? '',
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
