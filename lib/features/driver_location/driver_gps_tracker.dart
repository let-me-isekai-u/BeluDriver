import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'driver_location_api.dart';

enum DriverGpsSetupAction { locationSettings, appSettings }

class DriverGpsSetupException extends DriverLocationException {
  final DriverGpsSetupAction action;
  const DriverGpsSetupException(this.action, String message)
    : super(422, message);
}

const _locationDisabled = DriverGpsSetupException(
  DriverGpsSetupAction.locationSettings,
  'Hãy bật vị trí (GPS) trên điện thoại để chia sẻ khi làm việc.',
);

abstract interface class DriverGpsDevice {
  Future<String?> permission({required bool request});
  Future<bool> isServiceEnabled();
  Stream<ServiceStatus> serviceStatus();
  Stream<Position> watch();
  Future<Position> sample();
}

class GeolocatorDriverGpsDevice implements DriverGpsDevice {
  @override
  Future<String?> permission({required bool request}) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && request) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DriverGpsSetupException(
        DriverGpsSetupAction.appSettings,
        'Cho phép vị trí trong Cài đặt ứng dụng để chia sẻ khi làm việc.',
      );
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return 'Cần quyền vị trí để chia sẻ với điều hành.';
    }
    if (!await isServiceEnabled()) throw _locationDisabled;
    return null;
  }

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Stream<ServiceStatus> serviceStatus() => Geolocator.getServiceStatusStream();

  @override
  Stream<Position> watch() {
    final LocationSettings settings =
        defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            // Background reads must not launch Google's settings dialog.
            forceLocationManager: true,
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            intervalDuration: const Duration(seconds: 5),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Đang chia sẻ vị trí khi làm việc',
              notificationText: '',
              enableWakeLock: true,
            ),
          )
        : defaultTargetPlatform == TargetPlatform.iOS
        ? AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          );
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  @override
  Future<Position> sample() => Geolocator.getCurrentPosition(
    locationSettings: defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            forceLocationManager: true,
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 8),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
  );
}

/// One current point in memory; no offline route history. Sensor time is never replaced by send time.
class DriverGpsTracker extends ChangeNotifier {
  static final instance = DriverGpsTracker();
  final DriverLocationApi api;
  final DriverGpsDevice device;
  DriverGpsTracker({DriverLocationApi? api, DriverGpsDevice? device})
    : api = api ?? DriverLocationApi(),
      device = device ?? GeolocatorDriverGpsDevice();
  bool enabled = false;
  bool busy = false;
  String? lastError;
  DriverGpsSetupAction? setupAction;
  DateTime? lastSentAt;
  StreamSubscription<Position>? _subscription;
  StreamSubscription<ServiceStatus>? _serviceSubscription;
  Timer? _timer;
  Position? _latest;
  String? _stream;
  int _generation = 0;
  int _sequence = DateTime.now().millisecondsSinceEpoch;
  bool _sending = false;
  bool _sampling = false;

  Future<void> restore() async {
    final generation = _generation;
    try {
      final shouldResume = await api.sharing();
      if (generation == _generation && shouldResume && !enabled && !busy) {
        await start(requestPermission: false);
      }
    } catch (_) {
      /* Initial render stays off; a manual toggle can retry. */
    }
  }

  Future<void> start({bool requestPermission = true}) async {
    if (busy || enabled) return;
    final generation = ++_generation;
    busy = true;
    lastError = null;
    setupAction = null;
    notifyListeners();
    String? access;
    try {
      final error = await device.permission(request: requestPermission);
      if (error != null) throw DriverLocationException(422, error);
      if (generation != _generation) return;
      access = await api.token();
      if (generation != _generation) return;
      final response = await api.setSharing(true, accessToken: access);
      if (generation != _generation) {
        // Disable a late enable using the original account token, never the next logged-in account.
        try {
          await api.setSharing(false, accessToken: access);
        } catch (_) {}
        return;
      }
      _stream = response['streamId'] as String?;
      if (_stream == null) {
        throw const DriverLocationException(
          503,
          'Máy chủ chưa mở được phiên chia sẻ vị trí.',
        );
      }
      _serviceSubscription = device.serviceStatus().listen(
        (status) {
          if (status == ServiceStatus.disabled && generation == _generation) {
            unawaited(stop());
          }
        },
        // flush also checks the current service state if the stream is unavailable.
        onError: (Object _) {},
      );
      final serviceEnabled = await device.isServiceEnabled();
      if (generation != _generation) return;
      if (!serviceEnabled) {
        await stop();
        return;
      }
      enabled = true;
      _subscription = device.watch().listen(
        (position) {
          if (enabled && generation == _generation) {
            _latest = position;
          }
        },
        onError: (Object _) {
          if (generation != _generation) return;
          lastError =
              'Chưa lấy được GPS mới. Kiểm tra quyền vị trí và GPS trên máy.';
          notifyListeners();
        },
      );
      _timer = Timer.periodic(const Duration(seconds: 10), (_) => flush());
      // The toggle represents an open session. Sampling and sending can finish later.
      unawaited(flush());
    } catch (error) {
      if (generation == _generation) {
        enabled = false;
        _stream = null;
        await _stopWatching();
        if (access != null) {
          try {
            await api.setSharing(false, accessToken: access);
          } catch (_) {}
        }
        if (generation == _generation) {
          lastError = error is DriverLocationException
              ? error.message
              : 'Chưa bật được chia sẻ vị trí. Kiểm tra mạng và thử lại.';
          setupAction = error is DriverGpsSetupException ? error.action : null;
        }
      }
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> flush() async {
    if (!enabled || _sending || _stream == null) return;
    final generation = _generation;
    _sending = true;
    try {
      final serviceEnabled = await device.isServiceEnabled();
      if (generation != _generation) return;
      if (!serviceEnabled) {
        await stop();
        return;
      }
      // A stationary phone still needs a fresh sensor sample; do not fake a heartbeat by changing
      // the timestamp of an old point. The server can show a stale state when the OS pauses GPS.
      if ((_latest == null ||
              DateTime.now().difference(_latest!.timestamp).inSeconds > 25) &&
          !_sampling) {
        _sampling = true;
        try {
          final point = await device.sample();
          if (generation == _generation && enabled) _latest = point;
        } finally {
          _sampling = false;
        }
      }
      final point = _latest;
      if (point == null || generation != _generation || !enabled) return;
      final response = await api.report({
        'streamId': _stream,
        'latitude': point.latitude,
        'longitude': point.longitude,
        'accuracyMeters': point.accuracy,
        'speedMps': point.speed < 0 ? null : point.speed,
        'headingDegrees': point.heading < 0 ? null : point.heading,
        'capturedAt': point.timestamp.toUtc().toIso8601String(),
        'sequence': ++_sequence,
      });
      if (generation != _generation) return;
      if (response['accepted'] == true) {
        lastSentAt = DateTime.now();
        lastError = null;
      } else if (response['reason'] == 'low_accuracy' ||
          response['reason'] == 'outlier') {
        lastError = 'GPS chưa đủ chính xác. Đang chờ vị trí tốt hơn.';
      }
    } on DriverLocationException catch (error) {
      if (generation != _generation) return;
      lastError = error.message;
      if (error.status == 401 || error.status == 403) {
        await stop(disableServer: false);
      }
    } catch (_) {
      if (generation == _generation) {
        lastError =
            'Chưa gửi được GPS mới. Sẽ thử lại; vị trí cũ có thể hiện trên bản đồ.';
      }
    } finally {
      _sending = false;
      if (generation == _generation) notifyListeners();
    }
  }

  Future<void> _stopWatching() async {
    _timer?.cancel();
    _timer = null;
    final position = _subscription;
    final service = _serviceSubscription;
    _subscription = null;
    _serviceSubscription = null;
    await Future.wait([
      if (position != null) position.cancel(),
      if (service != null) service.cancel(),
    ]);
  }

  Future<void> stop({bool disableServer = true}) async {
    final generation = ++_generation;
    enabled = false;
    busy = disableServer;
    setupAction = null;
    _stream = null;
    _latest = null;
    notifyListeners();
    try {
      final stopWatching = _stopWatching();
      if (disableServer) {
        await Future.wait([stopWatching, api.setSharing(false)]);
        if (generation == _generation) lastError = null;
      } else {
        await stopWatching;
      }
    } catch (_) {
      if (disableServer && generation == _generation) {
        lastError = 'Chưa đồng bộ trạng thái tắt chia sẻ.';
      }
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }
}
