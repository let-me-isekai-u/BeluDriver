import 'dart:async';
import 'dart:convert';
import 'package:beludriver_app/features/driver_location/driver_gps_tracker.dart';
import 'package:beludriver_app/features/driver_location/driver_location_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Position point(double lat, {DateTime? at}) => Position(
  latitude: lat,
  longitude: 105.8,
  timestamp: at ?? DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class FakeDevice implements DriverGpsDevice {
  final positions = StreamController<Position>.broadcast();
  String? denied;
  Position latest = point(21);
  int watches = 0;
  bool failSample = false;
  @override
  Future<String?> permission({required bool request}) async => denied;
  @override
  Stream<Position> watch() {
    watches++;
    return positions.stream;
  }

  @override
  Future<Position> sample() async {
    if (failSample) throw Exception('GPS paused');
    return latest;
  }
}

class FakeApi extends DriverLocationApi {
  bool wasSharing = false;
  bool failReport = false;
  final toggles = <(bool, String?)>[];
  final reports = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? enableGate;
  Completer<Map<String, dynamic>>? reportGate;
  @override
  Future<String> token() async => 'original-account';
  @override
  Future<bool> sharing() async => wasSharing;
  @override
  Future<Map<String, dynamic>> setSharing(
    bool enabled, {
    String? accessToken,
  }) async {
    toggles.add((enabled, accessToken));
    if (enabled && enableGate != null) return enableGate!.future;
    return {'enabled': enabled, 'streamId': enabled ? 'fixture-stream' : null};
  }

  @override
  Future<Map<String, dynamic>> report(Map<String, dynamic> value) async {
    reports.add(value);
    if (failReport) throw Exception('network');
    if (reportGate != null) return reportGate!.future;
    return {'accepted': true};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeApi api;
  late FakeDevice gps;
  late DriverGpsTracker tracker;
  setUp(() {
    api = FakeApi();
    gps = FakeDevice();
    tracker = DriverGpsTracker(api: api, device: gps);
  });
  tearDown(() async {
    await tracker.stop(disableServer: false);
    tracker.dispose();
    await gps.positions.close();
    api.client.close();
  });

  test(
    'does not collect by default; explicit switch starts and stops the GPS stream',
    () async {
      await tracker.restore();
      expect(gps.watches, 0);
      expect(api.toggles, isEmpty);
      await tracker.start();
      expect(tracker.enabled, isTrue);
      expect(gps.watches, 1);
      expect(api.reports.single['streamId'], 'fixture-stream');
      await tracker.stop();
      gps.positions.add(point(22));
      await Future<void>.delayed(Duration.zero);
      await tracker.flush();
      expect(tracker.enabled, isFalse);
      expect(api.toggles.last.$1, isFalse);
      expect(api.reports.length, 1);
    },
  );

  test(
    'network recovery sends only the latest sensor point and preserves capture time',
    () async {
      api.failReport = true;
      await tracker.start();
      final captured = DateTime.now();
      gps.positions.add(point(21.01));
      gps.positions.add(point(21.02, at: captured));
      await Future<void>.delayed(Duration.zero);
      api.failReport = false;
      await tracker.flush();
      expect(api.reports.last['latitude'], 21.02);
      expect(
        api.reports.last['capturedAt'],
        captured.toUtc().toIso8601String(),
      );
      expect(tracker.lastError, isNull);
      expect(tracker.lastSentAt, isNotNull);
    },
  );

  test('a pending upload cannot restart collection after stop', () async {
    api.reportGate = Completer();
    final starting = tracker.start();
    while (api.reports.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await tracker.stop();
    api.reportGate!.complete({'accepted': true});
    await starting;
    expect(tracker.enabled, isFalse);
    expect(tracker.lastSentAt, isNull);
    expect(api.toggles.last.$1, isFalse);
  });

  test('late enable is compensated with the original account token', () async {
    api.enableGate = Completer();
    final starting = tracker.start();
    while (api.toggles.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await tracker.stop();
    api.enableGate!.complete({'enabled': true, 'streamId': 'late-stream'});
    await starting;
    expect(tracker.enabled, isFalse);
    expect(gps.watches, 0);
    expect(api.toggles.last, (false, 'original-account'));
  });

  test('permission denial does not enable server sharing', () async {
    gps.denied = 'Vị trí chưa được cho phép';
    await tracker.start();
    expect(tracker.enabled, isFalse);
    expect(api.toggles, isEmpty);
    expect(gps.watches, 0);
    expect(tracker.lastError, contains('chưa được cho phép'));
  });

  test('GPS pause is not turned into a fake fresh heartbeat', () async {
    gps.latest = point(
      21,
      at: DateTime.now().subtract(const Duration(minutes: 2)),
    );
    gps.failSample = true;
    await tracker.start();
    expect(api.reports, isEmpty);
    expect(tracker.lastError, isNotNull);
  });

  test(
    'API derives identity from JWT and sends the documented contract',
    () async {
      SharedPreferences.setMockInitialValues({'accessToken': 'fixture-access'});
      final client = MockClient((request) async {
        expect(request.url.path, '/api/driver/location/sharing');
        expect(request.headers['Authorization'], 'Bearer fixture-access');
        expect(jsonDecode(request.body), {'enabled': true});
        return http.Response('{"enabled":true,"streamId":"fixture"}', 200);
      });
      final data = await DriverLocationApi(client: client).setSharing(true);
      expect(data['streamId'], 'fixture');
      client.close();
    },
  );
}
