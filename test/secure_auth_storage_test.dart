import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calamansi_care/data/secure_auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestFlutterSecureStoragePlatform securePlatform;

  setUp(() async {
    securePlatform = TestFlutterSecureStoragePlatform({});
    FlutterSecureStoragePlatform.instance = securePlatform;
    SharedPreferences.setMockInitialValues({});
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
