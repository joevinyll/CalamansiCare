import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calamansi_care/data/secure_auth_storage.dart';

void main() {
  test('remote logout error after local session removal still completes',
      () async {
    var active = true;
    var cleared = false;
    await signOutThisDevice(
      revokeSession: () async {
        active = false;
        throw Exception('Offline');
      },
      hasSession: () => active,
      clearPersistedSession: () async {
        cleared = true;
      },
    );
    expect(cleared, isTrue);
  });
  test('logout failure with active session does not clear persisted data',
      () async {
    var cleared = false;
    await expectLater(
        signOutThisDevice(
          revokeSession: () async {
            throw Exception('Session not removed');
          },
          hasSession: () => true,
          clearPersistedSession: () async {
            cleared = true;
          },
        ),
        throwsException);
    expect(cleared, isFalse);
  });
  test('secure storage errors are not hidden', () async {
    await expectLater(
        signOutThisDevice(
          revokeSession: () async {},
          hasSession: () => false,
          clearPersistedSession: () async {
            throw Exception('Storage failure');
          },
        ),
        throwsException);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestFlutterSecureStoragePlatform securePlatform;

  setUp(() async {
    securePlatform = TestFlutterSecureStoragePlatform({});
    FlutterSecureStoragePlatform.instance = securePlatform;
    SharedPreferences.setMockInitialValues({});
  });

  test('PKCE callback clears verifier without preinitializing legacy storage',
      () async {
    const key = 'supabase.auth.token-code-verifier';
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('legacy-verifier', 'old-verifier');
    final storage = SecurePkceStorage(
        legacy: SharedPreferencesLocalStorage(
            persistSessionKey: 'legacy-verifier'));
    await storage.setItem(key: key, value: 'current-verifier');
    expect(await storage.getItem(key: key), 'current-verifier');
    await storage.removeItem(key: key);
    expect(await storage.getItem(key: key), isNull);
    expect(securePlatform.data[key], isNull);
    expect(preferences.getString('legacy-verifier'), isNull);
  });

  test('PKCE fallback initializes once before concurrent legacy reads',
      () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('legacy-verifier', 'old-verifier');
    final storage = SecurePkceStorage(
        legacy: SharedPreferencesLocalStorage(
            persistSessionKey: 'legacy-verifier'));
    expect(
        await Future.wait([
          storage.getItem(key: 'missing-verifier'),
          storage.getItem(key: 'missing-verifier'),
        ]),
        ['old-verifier', 'old-verifier']);
  });

  test('migrates legacy session and PKCE verifier to encrypted-store API',
      () async {
    const sessionKey = 'sb-project-auth-token';
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(sessionKey, '{"access_token":"legacy"}');
    final legacyPkce = SharedPreferencesGotrueAsyncStorage();
    await legacyPkce.setItem(
        key: 'supabase.auth.token-code-verifier', value: 'pkce-verifier');

    final storage = SecureAuthStorage(
      key: sessionKey,
      legacy: SharedPreferencesLocalStorage(persistSessionKey: sessionKey),
      legacyPkce: legacyPkce,
    );
    await storage.initialize();

    expect(await storage.accessToken(), '{"access_token":"legacy"}');
    expect(securePlatform.data[sessionKey], '{"access_token":"legacy"}');
    expect(securePlatform.data['$sessionKey-code-verifier'], 'pkce-verifier');
    expect(preferences.getString(sessionKey), isNull);
    expect(await legacyPkce.getItem(key: 'supabase.auth.token-code-verifier'),
        isNull);
  });

  test('logout removes secure and legacy session values', () async {
    const sessionKey = 'sb-project-auth-token';
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(sessionKey, 'old-session');
    final legacyPkce = SharedPreferencesGotrueAsyncStorage();
    await legacyPkce.setItem(
        key: 'supabase.auth.token-code-verifier', value: 'old-verifier');
    final storage = SecureAuthStorage(
      key: sessionKey,
      legacy: SharedPreferencesLocalStorage(persistSessionKey: sessionKey),
      legacyPkce: legacyPkce,
    );
    await storage.initialize();
    await storage.removePersistedSession();

    expect(await storage.hasAccessToken(), isFalse);
    expect(securePlatform.data, isEmpty);
    expect(preferences.getString(sessionKey), isNull);
  });
}
