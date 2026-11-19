import 'package:beludriver_app/features/driver_location/driver_gps_tracker.dart';
import 'package:beludriver_app/features/driver_location/driver_location_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'driver_location_test.dart' show FakeApi, FakeDevice, point;

class _LocationPlatform extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  bool servicesEnabled = true;
  bool settingsAvailable = true;
  final calls = <String>[];
  LocationSettings? watchSettings;
  LocationSettings? sampleSettings;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    watchSettings = locationSettings;
    return const Stream.empty();
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    sampleSettings = locationSettings;
    return point(21);
  }

  @override
  Future<LocationPermission> checkPermission() async {
    calls.add('checkPermission');
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    calls.add('requestPermission');
    return permission = requestedPermission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    calls.add('servicesEnabled');
    return servicesEnabled;
  }

  @override
  Future<bool> openLocationSettings() async {
    calls.add('locationSettings');
    return settingsAvailable;
  }

  @override
  Future<bool> openAppSettings() async {
    calls.add('appSettings');
    return settingsAvailable;
  }
}

class _Device extends FakeDevice {
  @override
  Future<String?> permission({required bool request}) =>
      GeolocatorDriverGpsDevice().permission(request: request);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform originalPlatform;
  late _LocationPlatform platform;
  late FakeApi api;
  late _Device device;
  late DriverGpsTracker tracker;

  setUp(() {
    originalPlatform = GeolocatorPlatform.instance;
    platform = _LocationPlatform();
    GeolocatorPlatform.instance = platform;
    api = FakeApi();
    device = _Device();
    tracker = DriverGpsTracker(api: api, device: device);
  });

  tearDown(() async {
    await tracker.stop(disableServer: false);
    tracker.dispose();
    await device.positions.close();
    await device.statuses.close();
    api.client.close();
    GeolocatorPlatform.instance = originalPlatform;
  });

  test(
    'Android tracking and samples cannot open Google settings dialogs',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final device = GeolocatorDriverGpsDevice();
      await device.watch().drain<void>();
      await device.sample();

      final watch = platform.watchSettings as AndroidSettings;
      final sample = platform.sampleSettings as AndroidSettings;
      expect(watch.forceLocationManager, isTrue);
      expect(sample.forceLocationManager, isTrue);
      expect(watch.foregroundNotificationConfig?.notificationText, isEmpty);
    },
  );

  test(
    'requests missing permission even when GPS is off; collects nothing',
    () async {
      platform.permission = LocationPermission.denied;
      platform.servicesEnabled = false;
      await tracker.start();
      expect(platform.calls, [
        'checkPermission',
        'requestPermission',
        'servicesEnabled',
      ]);
      expect(tracker.setupAction, DriverGpsSetupAction.locationSettings);
      expect(api.toggles, isEmpty);
      expect(device.watches, 0);
      expect(api.reports, isEmpty);
    },
  );

  test('automatic restore never asks for missing permission', () async {
    api.wasSharing = true;
    platform.permission = LocationPermission.denied;
    await tracker.restore();
    expect(platform.calls, ['checkPermission']);
    expect(api.toggles, isEmpty);
    expect(device.watches, 0);
  });

  test(
    'permanent denial routes to app settings without enabling sharing',
    () async {
      platform.permission = LocationPermission.denied;
      platform.requestedPermission = LocationPermission.deniedForever;
      await tracker.start();
      expect(tracker.setupAction, DriverGpsSetupAction.appSettings);
      expect(api.toggles, isEmpty);
      expect(device.watches, 0);
    },
  );

  Future<void> showTile(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DriverLocationTile(tracker: tracker)),
      ),
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.text('Mở Cài đặt'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(api.toggles, isEmpty);
    expect(device.watches, 0);
  }

  Future<void> returnToApp(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  testWidgets('GPS off offers settings; cancel keeps sharing off', (
    tester,
  ) async {
    platform.servicesEnabled = false;
    await showTile(tester);
    expect(find.text('Bật vị trí trên điện thoại?'), findsOneWidget);
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect(platform.calls, isNot(contains('locationSettings')));
    expect(api.toggles, isEmpty);
    expect(tracker.enabled, false);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNotNull,
    );
  });

  testWidgets(
    'grants permission, opens GPS settings, and enables once on return',
    (tester) async {
      platform.permission = LocationPermission.denied;
      platform.servicesEnabled = false;
      await showTile(tester);
      expect(
        platform.calls.where((c) => c == 'requestPermission'),
        hasLength(1),
      );
      await openSettings(tester);
      expect(platform.calls, contains('locationSettings'));
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      platform.servicesEnabled = true;
      await returnToApp(tester);
      expect(tracker.enabled, true);
      expect(api.toggles, [(true, 'original-account')]);
      expect(device.watches, 1);
      await tester.runAsync(() => tracker.stop(disableServer: false));
    },
  );

  testWidgets(
    'returning with GPS still off does not reopen settings or enable',
    (tester) async {
      platform.servicesEnabled = false;
      await showTile(tester);
      await openSettings(tester);
      await returnToApp(tester);
      expect(
        platform.calls.where((c) => c == 'locationSettings'),
        hasLength(1),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(api.toggles, isEmpty);
      expect(tracker.enabled, false);
    },
  );

  testWidgets('permanent denial opens app settings and rechecks on return', (
    tester,
  ) async {
    platform.permission = LocationPermission.deniedForever;
    await showTile(tester);
    expect(find.text('Cho phép truy cập vị trí'), findsOneWidget);
    await openSettings(tester);
    expect(platform.calls, contains('appSettings'));
    platform.permission = LocationPermission.whileInUse;
    await returnToApp(tester);
    expect(tracker.enabled, true);
    expect(api.toggles, [(true, 'original-account')]);
    await tester.runAsync(() => tracker.stop(disableServer: false));
  });

  testWidgets('declining the native permission request keeps sharing off', (
    tester,
  ) async {
    platform.permission = LocationPermission.denied;
    platform.requestedPermission = LocationPermission.denied;
    await showTile(tester);
    expect(
      find.text('Cần quyền vị trí để chia sẻ với điều hành.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(api.toggles, isEmpty);
    expect(device.watches, 0);
  });

  testWidgets('leaving the tile while in settings cannot start sharing later', (
    tester,
  ) async {
    platform.servicesEnabled = false;
    await showTile(tester);
    await openSettings(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    expect(find.byType(DriverLocationTile), findsNothing);
    platform.servicesEnabled = true;
    await returnToApp(tester);
    expect(api.toggles, isEmpty);
    expect(device.watches, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings launch failure leaves the switch available for retry', (
    tester,
  ) async {
    platform.servicesEnabled = false;
    platform.settingsAvailable = false;
    await showTile(tester);
    await tester.tap(find.text('Mở Cài đặt'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa mở được Cài đặt.'), findsOneWidget);
    expect(api.toggles, isEmpty);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNotNull,
    );
  });

  testWidgets('logout while in settings cancels the pending sharing intent', (
    tester,
  ) async {
    platform.servicesEnabled = false;
    await showTile(tester);
    await openSettings(tester);
    await tester.runAsync(() => tracker.stop(disableServer: false));
    platform.servicesEnabled = true;
    await returnToApp(tester);
    expect(api.toggles, isEmpty);
    expect(device.watches, 0);
  });
}
