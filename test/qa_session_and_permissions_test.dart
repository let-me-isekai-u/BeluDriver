import 'dart:async';
import 'dart:convert';

import 'package:beludriver_app/config/api_config.dart';
import 'package:beludriver_app/features/carrier_vehicle/carrier_vehicle_service.dart';
import 'package:beludriver_app/services/api_response.dart';
import 'package:beludriver_app/services/api_service.dart';
import 'package:beludriver_app/services/driver_auth_client.dart';
import 'package:beludriver_app/services/session_auth.dart';
import 'package:beludriver_app/services/token_storage.dart';
import 'package:beludriver_app/services/v2/api_service.dart' as v2;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Prepared for the next authorized Flutter test run. No production calls.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = TokenStorage.instance;
  late Map<String, String> secure;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    secure = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = call.arguments as Map;
            final key = args['key'] as String?;
            switch (call.method) {
              case 'read':
                return secure[key];
              case 'write':
                secure[key!] = args['value'] as String;
                return null;
              case 'delete':
                secure.remove(key);
                return null;
              case 'deleteAll':
                secure.clear();
                return null;
              case 'readAll':
                return secure;
              case 'containsKey':
                return secure.containsKey(key);
            }
            return null;
          },
        );
    SessionAuth.onExpired = null;
    await storage.writeTokens(accessToken: 'old', refreshToken: 'refresh-old');
  });

  Map<String, String> getHeaders() => {'Authorization': 'Bearer old'};
  Uri profile() => Uri.parse('$apiOrigin/api/accountdriverapi/profile');
  http.Response renewed() => http.Response(
    jsonEncode({'accessToken': 'new', 'refreshToken': 'refresh-new'}),
    200,
  );

  test('parallel 401s rotate one pair and retry each read only once', () async {
    var refreshes = 0;
    var retried = 0;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/refresh-token')) {
        refreshes++;
        await Future<void>.delayed(Duration.zero);
        expect(jsonDecode(request.body), {'refreshToken': 'refresh-old'});
        return renewed();
      }
      if (request.headers['Authorization'] == 'Bearer old') {
        return http.Response('', 401);
      }
      retried++;
      expect(request.headers['Authorization'], 'Bearer new');
      return http.Response('{}', 200);
    });
    await http.runWithClient(() async {
      final client = DriverAuthClient();
      final results = await Future.wait(
        List.generate(8, (_) => client.get(profile(), headers: getHeaders())),
      );
      expect(results.map((r) => r.statusCode), everyElement(200));
    }, () => mock);
    expect(refreshes, 1);
    expect(retried, 8);
    expect(await storage.readTokens(), ('new', 'refresh-new'));
  });

  for (final failure in [401, 403, 500]) {
    test('refresh $failure expires only on authoritative refusal', () async {
      var expired = 0;
      SessionAuth.onExpired = () => expired++;
      final mock = MockClient(
        (r) async => http.Response(
          '',
          r.url.path.endsWith('/refresh-token') ? failure : 401,
        ),
      );
      await http.runWithClient(() async {
        final response = await DriverAuthClient().get(
          profile(),
          headers: getHeaders(),
        );
        expect(response.statusCode, failure == 500 ? 503 : 401);
      }, () => mock);
      expect(expired, failure == 500 ? 0 : 1);
      expect(await storage.readAccessToken(), failure == 500 ? 'old' : null);
    });
  }

  test(
    'an outage during refresh keeps tokens and permits a later attempt',
    () async {
      var refreshes = 0;
      final mock = MockClient((r) async {
        if (r.url.path.endsWith('/refresh-token')) {
          if (++refreshes == 1) throw http.ClientException('offline');
          return renewed();
        }
        return http.Response(
          '{}',
          r.headers['Authorization'] == 'Bearer new' ? 200 : 401,
        );
      });
      await http.runWithClient(() async {
        final client = DriverAuthClient();
        expect(
          (await client.get(profile(), headers: getHeaders())).statusCode,
          503,
        );
        expect(await storage.readAccessToken(), 'old');
        expect(
          (await client.get(profile(), headers: getHeaders())).statusCode,
          200,
        );
      }, () => mock);
      expect(refreshes, 2);
    },
  );

  test(
    'a second read 401 expires the renewed session without looping',
    () async {
      var refreshes = 0;
      var reads = 0;
      final mock = MockClient((r) async {
        if (r.url.path.endsWith('/refresh-token')) {
          refreshes++;
          return renewed();
        }
        reads++;
        return http.Response('', 401);
      });
      await http.runWithClient(() async {
        expect(
          (await DriverAuthClient().get(
            profile(),
            headers: getHeaders(),
          )).statusCode,
          401,
        );
      }, () => mock);
      expect(refreshes, 1);
      expect(reads, 2);
      expect(await storage.readAccessToken(), isNull);
    },
  );

  test(
    'financial write is not replayed and its key survives token rotation',
    () async {
      final keys = <String?>[];
      final mock = MockClient((r) async {
        if (r.url.path.endsWith('/refresh-token')) return renewed();
        keys.add(r.headers['Idempotency-Key']);
        return http.Response('{}', keys.length == 1 ? 401 : 200);
      });
      await http.runWithClient(() async {
        final uri = Uri.parse('$apiOrigin/api/withdrawalapi/create');
        final first = await sendFinancialCommand(
          'POST',
          uri,
          'old',
          body: '{}',
        );
        expect(responseJson(first)?['code'], 'session_renewed_not_replayed');
        expect(keys, hasLength(1));
        await sendFinancialCommand('POST', uri, 'new', body: '{}');
      }, () => mock);
      expect(keys[0], keys[1]);
    },
  );

  test(
    'logout/new login during refresh cannot be overwritten or cleared',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final mock = MockClient((r) async {
        started.complete();
        await release.future;
        return renewed();
      });
      await http.runWithClient(() async {
        final pending = SessionAuth.refresh('old');
        await started.future;
        await storage.clear();
        await storage.writeTokens(
          accessToken: 'other',
          refreshToken: 'other-refresh',
        );
        release.complete();
        expect(await pending, isNull);
      }, () => mock);
      expect(await storage.readTokens(), ('other', 'other-refresh'));
    },
  );

  for (final status in [401, 500]) {
    test('vehicle refresh $status clears only a rejected vehicle session', () async {
      await storage.writeVehicleSession(jsonEncode({
        'accessToken': 'vehicle-old', 'sessionToken': 'vehicle-session',
        'sessionExpiresAt': '2035-01-01T00:00:00Z', 'vehicle': {},
      }));
      await CarrierVehicleService.load();
      final mock = MockClient((r) async => http.Response('{}',
          r.url.path.endsWith('/auth/refresh') ? status : 401));
      await http.runWithClient(() async {
        await expectLater(CarrierVehicleService.runsToday(),
            throwsA(isA<CarrierVehicleException>().having(
              (e) => e.sessionEnded, 'sessionEnded', status == 401)));
      }, () => mock);
      expect(await storage.readVehicleSession(), status == 401 ? isNull : isNotNull);
      expect(await storage.readAccessToken(), 'old');
    });
  }

  for (final source in [1, 2]) {
    for (final start in [true, false]) {
      test(
        'source $source ${start ? 'start' : 'complete'} requires assigned ride and status',
        () async {
          var writes = 0;
          var assigned = false;
          var sameSource = true;
          var sameStatus = true;
          final status = start ? 2 : 3;
          final mock = MockClient((r) async {
            if (r.method == 'PUT') {
              writes++;
              return http.Response('{}', 200);
            }
            return http.Response(
              jsonEncode({
                'success': true,
                'data': assigned
                    ? [
                        {
                          'rideId': 12,
                          'rideSource': sameSource ? source : 3 - source,
                          'status': sameStatus ? status : 5,
                        },
                      ]
                    : [],
              }),
              200,
            );
          });
          await http.runWithClient(() async {
            Future<http.Response> action() => start
                ? ApiService.startRide(
                    accessToken: 'old',
                    rideId: 12,
                    rideSource: source,
                  )
                : v2.ApiService.completeRide(
                    accessToken: 'old',
                    rideId: 12,
                    rideSource: source,
                  );
            expect(
              (await action()).statusCode,
              403,
            ); // Creator can view, not execute.
            assigned = true;
            sameSource = false;
            expect((await action()).statusCode, 403);
            sameSource = true;
            sameStatus = false;
            expect((await action()).statusCode, 403);
            sameStatus = true;
            expect((await action()).statusCode, 200);
          }, () => mock);
          expect(writes, 1);
        },
      );
    }
  }
}
