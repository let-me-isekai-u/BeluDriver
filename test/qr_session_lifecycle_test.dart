// Prepared only. Do not run without the owner's authorization.
import 'dart:async';
import 'dart:convert';

import 'package:beludriver_app/features/carrier_vehicle/carrier_vehicle_service.dart';
import 'package:beludriver_app/services/driver_session_navigation.dart';
import 'package:beludriver_app/services/qr_cooldown.dart';
import 'package:beludriver_app/services/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/driver_session_fixture.dart';

http.Response sessionResponse(String access) => http.Response(
  jsonEncode({
    'success': true,
    'data': {
      'accessToken': access,
      'sessionToken': 'synthetic-session',
      'sessionExpiresAt': '2035-01-01T00:00:00Z',
      'vehicle': {'plateNumber': 'TEST'},
    },
  }),
  200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await installDriverSessionFixture('driver-token');
    await http.runWithClient(
      () => CarrierVehicleService.logout(),
      () => MockClient((_) async => http.Response('{}', 200)),
    );
  });

  Future<void> login() => http.runWithClient(() async {
    await CarrierVehicleService.exchange(
      'https://example.invalid/xe/qr#c=TEST&k=synthetic',
    );
  }, () => MockClient((_) async => sessionResponse('vehicle-old')));

  test('parallel exchanges cannot create a second vehicle session', () async {
    final gate = Completer<http.Response>();
    var requests = 0;
    await http.runWithClient(
      () async {
        final first = CarrierVehicleService.exchange('synthetic');
        await expectLater(
          CarrierVehicleService.exchange('synthetic'),
          throwsA(isA<CarrierVehicleException>()),
        );
        gate.complete(sessionResponse('vehicle-old'));
        await first;
      },
      () => MockClient((_) {
        requests++;
        return gate.future;
      }),
    );
    expect(requests, 1);
    expect(await TokenStorage.instance.readAccessToken(), 'driver-token');
  });

  test('parallel reads coalesce and refresh only the vehicle token', () async {
    await login();
    var refreshes = 0;
    var reads = 0;
    await http.runWithClient(
      () async {
        await Future.wait(
          List.generate(6, (_) => CarrierVehicleService.runsToday()),
        );
      },
      () => MockClient((r) async {
        if (r.url.path.endsWith('/auth/refresh')) {
          refreshes++;
          expect(jsonDecode(r.body), {'sessionToken': 'synthetic-session'});
          return http.Response('{"data":{"accessToken":"vehicle-new"}}', 200);
        }
        reads++;
        expect(r.headers['Authorization'], startsWith('Bearer vehicle-'));
        return r.headers['Authorization'] == 'Bearer vehicle-old'
            ? http.Response('', 401)
            : http.Response('{"data":[]}', 200);
      }),
    );
    expect(refreshes, 1);
    expect(reads, 2);
    expect(await TokenStorage.instance.readAccessToken(), 'driver-token');
  });

  test('logout invalidates an exchange response already in flight', () async {
    final gate = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(
      () async {
        final exchange = CarrierVehicleService.exchange('synthetic');
        final assertion = expectLater(
          exchange,
          throwsA(isA<CarrierVehicleException>()),
        );
        await started.future;
        await CarrierVehicleService.logout();
        gate.complete(sessionResponse('late-access'));
        await assertion;
      },
      () => MockClient((_) {
        started.complete();
        return gate.future;
      }),
    );
    expect(CarrierVehicleService.session, isNull);
    expect(await TokenStorage.instance.readVehicleSession(), isNull);
    expect(await TokenStorage.instance.readAccessToken(), 'driver-token');
  });

  test('a transient refresh failure keeps the vehicle session', () async {
    await login();
    await http.runWithClient(
      () async {
        await expectLater(
          CarrierVehicleService.runsToday(),
          throwsA(
            isA<CarrierVehicleException>().having(
              (e) => e.sessionEnded,
              'sessionEnded',
              false,
            ),
          ),
        );
      },
      () => MockClient(
        (r) async =>
            http.Response('', r.url.path.endsWith('/auth/refresh') ? 503 : 401),
      ),
    );
    expect(CarrierVehicleService.session, isNotNull);
    expect(await TokenStorage.instance.readVehicleSession(), isNotNull);
  });

  test('Retry-After supports seconds and HTTP-date', () {
    final cooldown = QrCooldown();
    cooldown.record(http.Response('', 429, headers: {'retry-after': '120'}));
    expect(cooldown.active, true);
    expect(
      cooldown.retryAt!.difference(DateTime.now()).inSeconds,
      inInclusiveRange(118, 120),
    );
    final dateCooldown = QrCooldown();
    dateCooldown.record(
      http.Response(
        '',
        429,
        headers: {'retry-after': 'Mon, 01 Jan 2035 00:00:00 GMT'},
      ),
    );
    expect(dateCooldown.retryAt, DateTime.utc(2035));
  });

  testWidgets(
    'driver expiry preserves vehicle routes, then redirects on exit',
    (tester) async {
      final navigation = DriverSessionNavigation();
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [navigation],
          routes: {
            '/': (_) => const Scaffold(body: Text('driver-home')),
            '/login': (_) => const Scaffold(body: Text('driver-login')),
          },
        ),
      );
      key.currentState!.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: carrierRouteName),
          builder: (_) => const Scaffold(body: Text('vehicle-home')),
        ),
      );
      await tester.pumpAndSettle();
      await TokenStorage.instance.clear();
      navigation.driverExpired();
      await tester.pumpAndSettle();
      expect(find.text('vehicle-home'), findsOneWidget);
      key.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('driver-login'), findsOneWidget);
    },
  );

  // Last: the server cooldown intentionally survives local logout.
  test('429 blocks new requests and preserves both sessions', () async {
    await login();
    var calls = 0;
    await http.runWithClient(
      () async {
        for (var i = 0; i < 2; i++) {
          await expectLater(
            CarrierVehicleService.runsToday(),
            throwsA(
              isA<CarrierVehicleException>().having(
                (e) => e.statusCode,
                'status',
                429,
              ),
            ),
          );
        }
      },
      () => MockClient((_) async {
        calls++;
        return http.Response('', 429, headers: {'retry-after': '120'});
      }),
    );
    expect(calls, 1);
    expect(CarrierVehicleService.session, isNotNull);
    expect(await TokenStorage.instance.readVehicleSession(), isNotNull);
    expect(await TokenStorage.instance.readAccessToken(), 'driver-token');
  });
}
