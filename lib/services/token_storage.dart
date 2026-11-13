import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deliberately excludes native errors, which may contain credential values.
class TokenStorageException implements Exception {
  const TokenStorageException();

  @override
  String toString() => 'Không thể truy cập bộ nhớ bảo mật. Vui lòng thử lại.';
}

/// All credential reads, migrations, updates and removals share one queue.
/// The backend, not this service, decides whether a token is still authorized.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? secureStorage})
    : _secure =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
          );

  static final TokenStorage instance = TokenStorage();
  static const String sessionKey = 'auth_tokens_v1';
  static const String _legacyAccessKey = 'accessToken';
  static const String _legacyRefreshKey = 'refreshToken';
  final FlutterSecureStorage _secure;
  Future<void> _tail = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<String?> readAccessToken() =>
      _serialized(() async => (await _readSession()).accessToken);

  Future<String?> readRefreshToken() =>
      _serialized(() async => (await _readSession()).refreshToken);

  Future<(String?, String?)> readTokens() => _serialized(() async {
    final session = await _readSession();
    return (session.accessToken, session.refreshToken);
  });

  /// Store the pair in a single Keychain/Keystore-backed value so rotation
  /// cannot leave an access token paired with an older refresh token.
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
  }) => _serialized(() async {
    final access = _token(accessToken);
    if (access == null) throw const TokenStorageException();
    await _writeVerified(_Session(access, _token(refreshToken)));
    await _removeLegacy();
  });

  Future<void> deleteAccessToken() => _serialized(() async {
    final session = await _readSession();
    await _writeVerified(_Session(null, session.refreshToken));
    await _removeLegacy();
  });

  /// Compare and rotate in the same queue as login/logout and migration.
  /// An old HTTP response must never restore a session after logout/login.
  Future<bool> rotateIfCurrent({
    required String? expectedAccess,
    required String? expectedRefresh,
    required String accessToken,
    required String refreshToken,
  }) => _serialized(() async {
    final current = await _readSession();
    if (current.accessToken != expectedAccess ||
        current.refreshToken != expectedRefresh) return false;
    if (_token(accessToken) == null || _token(refreshToken) == null) {
      throw const TokenStorageException();
    }
    await _writeVerified(_Session(accessToken, refreshToken));
    await _removeLegacy();
    return true;
  });

  Future<bool> clearIfCurrent({
    required String? expectedAccess,
    required String? expectedRefresh,
  }) => _serialized(() async {
    final current = await _readSession();
    if (current.accessToken != expectedAccess ||
        current.refreshToken != expectedRefresh) return false;
    await _writeVerified(const _Session(null, null));
    await _removeLegacy(required: true);
    return true;
  });

  Future<void> clear() => _serialized(() async {
    // A token-free tombstone prevents a leftover legacy value from restoring
    // a logged-out session if cleanup is interrupted or fails.
    await _writeVerified(const _Session(null, null));
    await _removeLegacy(required: true);
  });

  Future<_Session> _readSession() async {
    final prefs = await _preferences();
    final legacy = _Session(
      _token(prefs.get(_legacyAccessKey)),
      _token(prefs.get(_legacyRefreshKey)),
    );
    try {
      final value = await _secure.read(key: sessionKey);
      if (value != null) {
        final session = _Session.decode(value);
        await _removeLegacy();
        return session;
      }
    } catch (_) {
      // A temporarily unavailable Keychain must not destroy an old session.
      if (legacy.hasTokens) return legacy;
      throw const TokenStorageException();
    }
    if (!legacy.hasTokens) return const _Session(null, null);
    try {
      await _writeVerified(legacy);
      await _removeLegacy();
    } catch (_) {
      // No new plaintext write: retain the original values and retry on the
      // next read. Do not confuse a migration failure with an expired session.
    }
    return legacy;
  }

  Future<void> _writeVerified(_Session session) =>
      _writeValueVerified(sessionKey, session.encode());

  Future<void> _writeValueVerified(String key, String encoded) async {
    try {
      await _secure.write(key: key, value: encoded);
      if (await _secure.read(key: key) != encoded) {
        throw const TokenStorageException();
      }
    } catch (_) {
      throw const TokenStorageException();
    }
  }

  Future<void> _removeLegacy({bool required = false}) async {
    try {
      final prefs = await _preferences();
      final accessRemoved = await prefs.remove(_legacyAccessKey);
      final refreshRemoved = await prefs.remove(_legacyRefreshKey);
      if (required && (!accessRemoved || !refreshRemoved)) {
        throw const TokenStorageException();
      }
    } catch (_) {
      if (required) throw const TokenStorageException();
      // A verified secure value is authoritative. Retry cleanup on next read.
    }
  }

  static const vehicleSessionKey = 'auth_vehicle_session_v1';
  static const _legacyVehicleKey = 'carrier_vehicle_session_v1';

  /// The QR vehicle session is independent of the driver's login. Preserve its
  /// serialized contract, including metadata, while moving its embedded tokens.
  Future<String?> readVehicleSession() => _serialized(() async {
    final prefs = await _preferences();
    final oldValue = prefs.get(_legacyVehicleKey);
    final legacy = oldValue is String && _validVehicleSession(oldValue)
        ? oldValue
        : null;
    try {
      final value = await _secure.read(key: vehicleSessionKey);
      if (value != null) {
        if (value != 'null' && !_validVehicleSession(value)) {
          throw const TokenStorageException();
        }
        await _removeVehicleLegacy();
        return value == 'null' ? null : value;
      }
    } catch (_) {
      if (legacy != null) return legacy;
      throw const TokenStorageException();
    }
    if (legacy == null) return null;
    try {
      await _writeValueVerified(vehicleSessionKey, legacy);
      await _removeVehicleLegacy();
    } catch (_) {
      // Preserve the old QR session and retry migration on the next read.
    }
    return legacy;
  });

  Future<void> writeVehicleSession(String value) => _serialized(() async {
    if (!_validVehicleSession(value)) throw const TokenStorageException();
    await _writeValueVerified(vehicleSessionKey, value);
    await _removeVehicleLegacy();
  });

  Future<void> clearVehicleSession() => _serialized(() async {
    await _writeValueVerified(vehicleSessionKey, 'null');
    await _removeVehicleLegacy(required: true);
  });

  /// Used only where the previous implementation cleared all preferences.
  Future<void> clearAll() => _serialized(() async {
    await _writeVerified(const _Session(null, null));
    await _writeValueVerified(vehicleSessionKey, 'null');
    await _removeLegacy(required: true);
    await _removeVehicleLegacy(required: true);
  });

  Future<void> _removeVehicleLegacy({bool required = false}) async {
    try {
      final prefs = await _preferences();
      final removed = await prefs.remove(_legacyVehicleKey);
      if (required && !removed) throw const TokenStorageException();
    } catch (_) {
      if (required) throw const TokenStorageException();
    }
  }

  static bool _validVehicleSession(String value) {
    try {
      final data = jsonDecode(value) as Map<String, dynamic>;
      return _token(data['accessToken']) != null &&
          _token(data['sessionToken']) != null &&
          data['sessionExpiresAt'] is String &&
          DateTime.tryParse(data['sessionExpiresAt'] as String) != null &&
          data['vehicle'] is Map;
    } catch (_) {
      return false;
    }
  }

  static Future<SharedPreferences> _preferences() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      throw const TokenStorageException();
    }
  }

  static String? _token(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    if (value.trim().toLowerCase() == 'null') return null;
    return value;
  }
}

class _Session {
  const _Session(this.accessToken, this.refreshToken);
  final String? accessToken;
  final String? refreshToken;
  bool get hasTokens => accessToken != null || refreshToken != null;

  String encode() =>
      jsonEncode({'accessToken': accessToken, 'refreshToken': refreshToken});

  factory _Session.decode(String value) {
    final data = jsonDecode(value) as Map<String, dynamic>;
    if (!data.containsKey('accessToken') || !data.containsKey('refreshToken')) {
      throw const TokenStorageException();
    }
    for (final token in data.values) {
      if (token != null && TokenStorage._token(token) == null) {
        throw const TokenStorageException();
      }
    }
    return _Session(
      data['accessToken'] as String?,
      data['refreshToken'] as String?,
    );
  }
}
