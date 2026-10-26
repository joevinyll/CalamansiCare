import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const authSecureStorage = FlutterSecureStorage(
  iOptions:
      IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
);

/// A failed remote revocation must not turn a completed local logout into an error.
Future<void> signOutThisDevice({
  required Future<void> Function() revokeSession,
  required bool Function() hasSession,
  required Future<void> Function() clearPersistedSession,
}) async {
  try {
    await revokeSession();
  } catch (_) {
    if (hasSession()) rethrow;
  }
  if (hasSession()) throw StateError('The local session is still active.');
  await clearPersistedSession();
}

/// Migrate the SDK's existing session only after the encrypted write succeeds.
/// Serialize writes/removal so an in-flight refresh cannot outlive logout.
class SecureAuthStorage extends LocalStorage {
  SecureAuthStorage(
      {required this.key,
      required this.legacy,
      this.storage = authSecureStorage,
      this.freshInstall = false,
      this.legacyPkce,
      this.pkceStorage = authSecureStorage});

  final String key;
  final LocalStorage legacy;
  final FlutterSecureStorage storage;
  final bool freshInstall;
  final GotrueAsyncStorage? legacyPkce;
  final FlutterSecureStorage pkceStorage;
  Future<void> _pending = Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.catchError((Object _) {});
    return result;
  }

  @override
  Future<void> initialize() async {
    await legacy.initialize();
    if (freshInstall) {
      // Keychain entries can survive uninstall; do not resurrect that account.
      await storage.delete(key: key);
      await legacy.removePersistedSession();
      await _clearLegacyPkce();
      return;
    }
    final secure = await storage.read(key: key);
    final old = await legacy.accessToken();
    if (secure == null && old != null) {
      await storage.write(key: key, value: old);
    }
    await legacy.removePersistedSession();
    await _migratePkce();
  }

  Future<void> _migratePkce() async {
    if (legacyPkce == null) return;
    const oldKey = 'supabase.auth.token-code-verifier';
    final verifier = await legacyPkce!.getItem(key: oldKey);
    if (verifier != null) {
      await pkceStorage.write(key: '$key-code-verifier', value: verifier);
    }
    await legacyPkce!.removeItem(key: oldKey);
  }

  Future<void> _clearLegacyPkce() async {
    if (legacyPkce != null) {
      await legacyPkce!.removeItem(key: 'supabase.auth.token-code-verifier');
    }
  }

  @override
  Future<String?> accessToken() async {
    await _pending;
    return storage.read(key: key);
  }

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  @override
  Future<void> persistSession(String persistSessionString) =>
      _enqueue(() => storage.write(key: key, value: persistSessionString));

  @override
  Future<void> removePersistedSession() => _enqueue(() async {
        await storage.delete(key: key);
        await legacy.removePersistedSession();
        await pkceStorage.delete(key: '$key-code-verifier');
        if (legacyPkce != null) {
          await legacyPkce!
              .removeItem(key: 'supabase.auth.token-code-verifier');
        }
      });
}

class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage({this.legacy});
  final LocalStorage? legacy;
  // Supabase initializes session storage, but not this PKCE fallback store.
  late final Future<void> _legacyReady = legacy?.initialize() ?? Future.value();
  @override
  Future<String?> getItem({required String key}) async {
    await _legacyReady;
    return await authSecureStorage.read(key: key) ??
        await legacy?.accessToken();
  }

  @override
  Future<void> setItem({required String key, required String value}) =>
      authSecureStorage.write(key: key, value: value);
  @override
  Future<void> removeItem({required String key}) async {
    await _legacyReady;
    await authSecureStorage.delete(key: key);
    await legacy?.removePersistedSession();
  }
}
