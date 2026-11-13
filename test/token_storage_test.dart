import 'dart:async';
import 'dart:convert';

import 'package:beludriver_app/services/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSecureStorage extends FlutterSecureStorage {
  final values = <String, String>{};
  bool failRead = false;
  bool failWrite = false;
  bool failReadAfterWrite = false;
  bool dropWrite = false;
  int writes = 0;
  Completer<void>? writeGate;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failRead) throw StateError('native-error-sensitive-value');
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writes++;
    await writeGate?.future;
    if (failWrite) throw StateError('native-error-sensitive-value');
    if (!dropWrite && value != null) values[key] = value;
    if (failReadAfterWrite) failRead = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSecureStorage secure;
  late TokenStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secure = FakeSecureStorage();
    storage = TokenStorage(secureStorage: secure);
  });

  test(
    'new login writes only secure storage and survives service restart',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fullName', 'Test User');
      await storage.writeTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );
      final restarted = TokenStorage(secureStorage: secure);
      expect(await restarted.readAccessToken(), 'access-1');
      expect(await restarted.readRefreshToken(), 'refresh-1');
      expect(prefs.getString('fullName'), 'Test User');
      expect(prefs.containsKey('accessToken'), isFalse);
      expect(prefs.containsKey('refreshToken'), isFalse);
    },
  );

  test(
    'migrates both legacy keys, verifies and removes plaintext idempotently',
    () async {
      SharedPreferences.setMockInitialValues({
        'accessToken': 'old-access',
        'refreshToken': 'old-refresh',
        'id': 17,
      });
      expect(await storage.readAccessToken(), 'old-access');
      expect(await storage.readRefreshToken(), 'old-refresh');
      expect(await storage.readAccessToken(), 'old-access');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get('accessToken'), isNull);
      expect(prefs.get('refreshToken'), isNull);
      expect(prefs.getInt('id'), 17);
      expect(secure.writes, 1);
    },
  );

  test('keeps legacy tokens until read-back verification completes', () async {
    SharedPreferences.setMockInitialValues({'accessToken': 'old-access'});
    secure.writeGate = Completer<void>();
    final pendingRead = storage.readAccessToken();
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('accessToken'), 'old-access');
    secure.writeGate!.complete();
    expect(await pendingRead, 'old-access');
    expect(prefs.get('accessToken'), isNull);
  });

  test(
    'migration write failure retains session and retries successfully',
    () async {
      SharedPreferences.setMockInitialValues({'accessToken': 'legacy'});
      secure.failWrite = true;
      expect(await storage.readAccessToken(), 'legacy');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('accessToken'), 'legacy');
      secure.failWrite = false;
      expect(await storage.readAccessToken(), 'legacy');
      expect(prefs.get('accessToken'), isNull);
    },
  );

  test(
    'failed read-back preserves legacy until a later verified read',
    () async {
      SharedPreferences.setMockInitialValues({'accessToken': 'legacy'});
      secure.failReadAfterWrite = true;
      expect(await storage.readAccessToken(), 'legacy');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('accessToken'), 'legacy');
      secure.failRead = false;
      secure.failReadAfterWrite = false;
      expect(await storage.readAccessToken(), 'legacy');
      expect(prefs.get('accessToken'), isNull);
      expect(secure.writes, 1);
    },
  );

  test('silent write failure does not remove legacy tokens', () async {
    SharedPreferences.setMockInitialValues({'accessToken': 'legacy'});
    secure.dropWrite = true;
    expect(await storage.readAccessToken(), 'legacy');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('accessToken'), 'legacy');
  });

  test('temporarily unavailable secure storage keeps legacy session', () async {
    SharedPreferences.setMockInitialValues({
      'accessToken': 'legacy',
      'refreshToken': 'legacy-refresh',
    });
    secure.failRead = true;
    expect(await storage.readAccessToken(), 'legacy');
    expect(await storage.readRefreshToken(), 'legacy-refresh');
    expect(secure.writes, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('accessToken'), 'legacy');
  });

  test(
    'invalid legacy types and empty placeholders are not migrated',
    () async {
      for (final value in <Object>['', '  ', 'null', 123, true]) {
        SharedPreferences.setMockInitialValues({'accessToken': value});
        expect(await storage.readAccessToken(), isNull);
      }
      expect(secure.writes, 0);
    },
  );

  test('access-only and refresh-only sessions migrate independently', () async {
    SharedPreferences.setMockInitialValues({'refreshToken': 'refresh-only'});
    expect(await storage.readAccessToken(), isNull);
    expect(await storage.readRefreshToken(), 'refresh-only');
    secure.values.clear();
    SharedPreferences.setMockInitialValues({'accessToken': 'access-only'});
    expect(await storage.readAccessToken(), 'access-only');
    expect(await storage.readRefreshToken(), isNull);
  });

  test(
    'secure session takes precedence over leftover old credentials',
    () async {
      await storage.writeTokens(
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
      );
      SharedPreferences.setMockInitialValues({
        'accessToken': 'stale',
        'refreshToken': 'stale',
      });
      expect(await storage.readAccessToken(), 'new-access');
      expect(await storage.readRefreshToken(), 'new-refresh');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get('accessToken'), isNull);
    },
  );

  test(
    'logout removes tokens in both stores and does not migrate again',
    () async {
      SharedPreferences.setMockInitialValues({
        'accessToken': 'old',
        'refreshToken': 'old-r',
      });
      await storage.clear();
      final restarted = TokenStorage(secureStorage: secure);
      expect(await restarted.readAccessToken(), isNull);
      expect(await restarted.readRefreshToken(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get('accessToken'), isNull);
      expect(prefs.get('refreshToken'), isNull);
      final persisted =
          jsonDecode(secure.values[TokenStorage.sessionKey]!) as Map;
      expect(persisted.values.every((value) => value == null), isTrue);
    },
  );

  test(
    'logout tombstone prevents restoration of leftover legacy data',
    () async {
      await storage.clear();
      SharedPreferences.setMockInitialValues({'accessToken': 'leftover'});
      expect(
        await TokenStorage(secureStorage: secure).readAccessToken(),
        isNull,
      );
    },
  );

  test(
    'access removal preserves refresh for existing expired-token flow',
    () async {
      SharedPreferences.setMockInitialValues({
        'accessToken': 'expired',
        'refreshToken': 'refresh',
      });
      // No local JWT expiry decision: the backend still validates this token.
      expect(await storage.readAccessToken(), 'expired');
      await storage.deleteAccessToken();
      expect(await storage.readAccessToken(), isNull);
      expect(await storage.readRefreshToken(), 'refresh');
      await storage.writeTokens(
        accessToken: 'rotated',
        refreshToken: 'rotated-refresh',
      );
      expect(await storage.readAccessToken(), 'rotated');
      expect(await storage.readRefreshToken(), 'rotated-refresh');
    },
  );

  test('concurrent migration, login and logout execute in order', () async {
    SharedPreferences.setMockInitialValues({'accessToken': 'legacy'});
    final read = storage.readAccessToken();
    final login = storage.writeTokens(
      accessToken: 'new',
      refreshToken: 'new-r',
    );
    final logout = storage.clear();
    expect(await read, 'legacy');
    await login;
    await logout;
    expect(await storage.readAccessToken(), isNull);
    expect(await storage.readRefreshToken(), isNull);
  });

  test('failed login write is sanitized and queue recovers', () async {
    secure.failWrite = true;
    await expectLater(
      storage.writeTokens(accessToken: 'new'),
      throwsA(
        isA<TokenStorageException>().having(
          (e) => e.toString(),
          'safe message',
          isNot(contains('native-error-sensitive-value')),
        ),
      ),
    );
    secure.failWrite = false;
    await storage.writeTokens(accessToken: 'retry');
    expect(await storage.readAccessToken(), 'retry');
  });

  test('secure read failure is not treated as a logged-out session', () async {
    await storage.writeTokens(accessToken: 'saved', refreshToken: 'saved-r');
    secure.failRead = true;
    await expectLater(
      storage.readAccessToken(),
      throwsA(isA<TokenStorageException>()),
    );
    secure.failRead = false;
    expect(await storage.readAccessToken(), 'saved');
  });

  test(
    'corrupt secure payload is preserved instead of silently cleared',
    () async {
      secure.values[TokenStorage.sessionKey] = 'not-json';
      await expectLater(
        storage.readAccessToken(),
        throwsA(isA<TokenStorageException>()),
      );
      expect(secure.values[TokenStorage.sessionKey], 'not-json');
    },
  );

  test(
    'failed logout does not pretend that secure tokens were removed',
    () async {
      await storage.writeTokens(accessToken: 'saved');
      secure.failWrite = true;
      await expectLater(storage.clear(), throwsA(isA<TokenStorageException>()));
      secure.failWrite = false;
      expect(await storage.readAccessToken(), 'saved');
    },
  );
  group('QR vehicle credentials', () {
    String vehicleSession(
      String access, {
      String session = 'vehicle-session',
    }) => jsonEncode({
      'accessToken': access,
      'sessionToken': session,
      'sessionExpiresAt': '2027-01-01T00:00:00.000Z',
      'vehicle': {'plateNumber': 'TEST'},
    });

    test(
      'migrates embedded tokens and metadata without changing the contract',
      () async {
        final original = vehicleSession('vehicle-access');
        SharedPreferences.setMockInitialValues({
          'carrier_vehicle_session_v1': original,
        });
        expect(await storage.readVehicleSession(), original);
        expect(
          await TokenStorage(secureStorage: secure).readVehicleSession(),
          original,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.get('carrier_vehicle_session_v1'), isNull);
        expect(secure.writes, 1);
      },
    );

    test(
      'failed vehicle migration retains the old session for retry',
      () async {
        final original = vehicleSession('vehicle-access');
        SharedPreferences.setMockInitialValues({
          'carrier_vehicle_session_v1': original,
        });
        secure.dropWrite = true;
        expect(await storage.readVehicleSession(), original);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('carrier_vehicle_session_v1'), original);
        secure.dropWrite = false;
        expect(await storage.readVehicleSession(), original);
        expect(prefs.get('carrier_vehicle_session_v1'), isNull);
      },
    );

    test('vehicle login and refresh never write plaintext', () async {
      await storage.writeVehicleSession(vehicleSession('access-1'));
      await storage.writeVehicleSession(vehicleSession('access-2'));
      expect(await storage.readVehicleSession(), vehicleSession('access-2'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get('carrier_vehicle_session_v1'), isNull);
    });

    test(
      'vehicle logout does not clear independent driver credentials',
      () async {
        await storage.writeTokens(accessToken: 'driver-access');
        SharedPreferences.setMockInitialValues({
          'carrier_vehicle_session_v1': vehicleSession('legacy'),
        });
        await storage.clearVehicleSession();
        expect(await storage.readVehicleSession(), isNull);
        expect(await storage.readAccessToken(), 'driver-access');
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.get('carrier_vehicle_session_v1'), isNull);
      },
    );

    test(
      'driver auth rejection preserves vehicle session; logout clears both',
      () async {
        await storage.writeVehicleSession(vehicleSession('vehicle-access'));
        await storage.clear();
        expect(await storage.readVehicleSession(), isNotNull);
        await storage.writeTokens(accessToken: 'driver-access');
        await storage.clearAll();
        expect(await storage.readAccessToken(), isNull);
        expect(await storage.readVehicleSession(), isNull);
      },
    );

    test('migration and vehicle logout share the same queue', () async {
      SharedPreferences.setMockInitialValues({
        'carrier_vehicle_session_v1': vehicleSession('legacy'),
      });
      final read = storage.readVehicleSession();
      final clear = storage.clearVehicleSession();
      expect(await read, isNotNull);
      await clear;
      expect(await storage.readVehicleSession(), isNull);
    });

    test('invalid legacy JSON is not migrated or logged', () async {
      SharedPreferences.setMockInitialValues({
        'carrier_vehicle_session_v1': '{malformed',
      });
      expect(await storage.readVehicleSession(), isNull);
      expect(secure.writes, 0);
    });
  });
}
