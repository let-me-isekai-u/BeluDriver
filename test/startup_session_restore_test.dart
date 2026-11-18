// Prepared for the owner's next authorized test run. No production calls.
import 'dart:convert';

import 'package:beludriver_app/features/carrier_vehicle/carrier_vehicle_screens.dart';
import 'package:beludriver_app/features/carrier_vehicle/carrier_vehicle_service.dart';
import 'package:beludriver_app/services/active_session_mode.dart';
import 'package:beludriver_app/services/session_auth.dart';
import 'package:beludriver_app/services/startup_session_restore.dart';
import 'package:beludriver_app/services/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/driver_session_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = TokenStorage.instance;

  setUp(() async {
    await installDriverSessionFixture('driver-startup');
    SessionAuth.onExpired = null;
    await http.runWithClient(
      () => CarrierVehicleService.logout(),
      () => MockClient((_) async => http.Response('{}', 200)),
    );
    await storage.writeVehicleSession(
      jsonEncode({
        'accessToken': 'vehicle-old',
        'sessionToken': 'vehicle-session',
        'sessionExpiresAt': '2035-01-01T00:00:00Z',
        'vehicle': {'plateNumber': 'TEST'},
      }),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ActiveSessionMode.preferenceKey);
  });

  test(
    'persisted vehicle session restores without another QR exchange',
    () async {
      final paths = <String>[];
      final result = await http.runWithClient(
        StartupSessionRestore.restore,
        () => MockClient((r) async {
          paths.add(r.url.path);
          expect(r.headers['Authorization'], 'Bearer vehicle-old');
          return http.Response('{"data":[{"id":12}]}', 200);
        }),
      );
      expect(result?.mode, SessionMode.carrier);
      expect(result?.runs?.single['id'], 12);
      expect(paths, ['/api/carrier-vehicle/runs/today']);
      expect(await storage.readAccessToken(), 'driver-startup');
    },
  );

  test('the last driver choice wins when both sessions exist', () async {
    await ActiveSessionMode.remember(SessionMode.driver);
    final result = await http.runWithClient(
      StartupSessionRestore.restore,
      () => MockClient((r) async {
        expect(r.url.path, isNot(contains('carrier-vehicle')));
        expect(r.headers['Authorization'], 'Bearer driver-startup');
        return http.Response('{}', 200);
      }),
    );
    expect(result?.mode, SessionMode.driver);
    expect(await storage.readVehicleSession(), isNotNull);
  });

  test(
    'parallel startup requests share validation and vehicle renewal',
    () async {
      var refreshes = 0;
      var reads = 0;
      await http.runWithClient(
        () async {
          final results = await Future.wait(
            List.generate(5, (_) => StartupSessionRestore.restore()),
          );
          expect(
            results.map((r) => r?.mode),
            everyElement(SessionMode.carrier),
          );
        },
        () => MockClient((r) async {
          if (r.url.path.endsWith('/auth/refresh')) {
            refreshes++;
            expect(jsonDecode(r.body), {'sessionToken': 'vehicle-session'});
            return http.Response('{"data":{"accessToken":"vehicle-new"}}', 200);
          }
          reads++;
          return r.headers['Authorization'] == 'Bearer vehicle-old'
              ? http.Response('', 401)
              : http.Response('{"data":[]}', 200);
        }),
      );
      expect(refreshes, 1);
      expect(reads, 2);
      expect(await storage.readAccessToken(), 'driver-startup');
    },
  );

  test(
    'revoked vehicle falls back to Driver without clearing Driver tokens',
    () async {
      final result = await http.runWithClient(
        StartupSessionRestore.restore,
        () => MockClient((r) async {
          return r.url.path.contains('carrier-vehicle')
              ? http.Response('', 401)
              : http.Response('{}', 200);
        }),
      );
      expect(result?.mode, SessionMode.driver);
      expect(await storage.readVehicleSession(), isNull);
      expect(await storage.readAccessToken(), 'driver-startup');
    },
  );

  test('expired Driver falls back to vehicle using its own token', () async {
    await ActiveSessionMode.remember(SessionMode.driver);
    final result = await http.runWithClient(
      StartupSessionRestore.restore,
      () => MockClient((r) async {
        if (r.url.path.contains('carrier-vehicle')) {
          expect(r.headers['Authorization'], 'Bearer vehicle-old');
          return http.Response('{"data":[]}', 200);
        }
        return http.Response('', 401);
      }),
    );
    expect(result?.mode, SessionMode.carrier);
    expect(await storage.readAccessToken(), isNull);
    expect(await storage.readVehicleSession(), isNotNull);
  });

  test(
    'network and 5xx keep the preferred session instead of switching modes',
    () async {
      for (final network in [true, false]) {
        await http.runWithClient(
          () async {
            await expectLater(
              StartupSessionRestore.restore(),
              throwsA(anything),
            );
          },
          () => MockClient((r) async {
            expect(r.url.path, contains('carrier-vehicle'));
            if (network) throw http.ClientException('synthetic offline');
            return http.Response('', 503);
          }),
        );
        expect(await storage.readVehicleSession(), isNotNull);
        expect(await storage.readAccessToken(), 'driver-startup');
      }
    },
  );

  test('vehicle logout cannot restore the old stored session', () async {
    await storage.clear();
    await CarrierVehicleService.load();
    await http.runWithClient(
      () => CarrierVehicleService.logout(),
      () => MockClient((_) async => http.Response('{}', 200)),
    );
    final result = await http.runWithClient(
      StartupSessionRestore.restore,
      () => MockClient((_) async {
        fail(
          'No authenticated request is allowed after both sessions are absent.',
        );
      }),
    );
    expect(result, isNull);
    expect(await storage.readVehicleSession(), isNull);
  });

  test('the most recent explicit choice is persisted in call order', () async {
    await Future.wait([
      ActiveSessionMode.remember(SessionMode.carrier),
      ActiveSessionMode.remember(SessionMode.driver),
    ]);
    expect((await ActiveSessionMode.readOrder()).first, SessionMode.driver);
    expect(await storage.readVehicleSession(), isNotNull);
  });

  testWidgets('restored root vehicle Home can return to normal Login', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const CarrierVehicleHomeScreen(initialRuns: []),
        routes: {'/login': (_) => const Scaffold(body: Text('normal-login'))},
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('normal-login'), findsOneWidget);
    expect((await ActiveSessionMode.readOrder()).first, SessionMode.driver);
    expect(await storage.readVehicleSession(), isNotNull);
  });

  // Last: a server cooldown deliberately survives local logout/re-entry.
  test(
    '429 during startup neither falls back nor deletes either session',
    () async {
      var requests = 0;
      await http.runWithClient(
        () async {
          for (var i = 0; i < 2; i++) {
            await expectLater(
              StartupSessionRestore.restore(),
              throwsA(
                isA<CarrierVehicleException>().having(
                  (e) => e.statusCode,
                  'HTTP',
                  429,
                ),
              ),
            );
          }
        },
        () => MockClient((_) async {
          requests++;
          return http.Response('', 429, headers: {'retry-after': '120'});
        }),
      );
      expect(requests, 1);
      expect(await storage.readVehicleSession(), isNotNull);
      expect(await storage.readAccessToken(), 'driver-startup');
    },
  );
}
