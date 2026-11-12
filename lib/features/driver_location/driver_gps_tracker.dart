import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'driver_location_api.dart';

abstract interface class DriverGpsDevice {
  Future<String?> permission({required bool request});
  Stream<Position> watch();
  Future<Position> sample();
}

class GeolocatorDriverGpsDevice implements DriverGpsDevice {
  @override
  Future<String?> permission({required bool request}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Hãy bật GPS trên điện thoại.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && request) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Cho phép vị trí trong Cài đặt ứng dụng để chia sẻ khi làm việc.';
    }
    if (permission == LocationPermission.denied) {
      return 'Cần quyền vị trí để chia sẻ với điều hành.';
    }
    return null;
  }

  @override
  Stream<Position> watch() {
    final LocationSettings settings =
        defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            intervalDuration: const Duration(seconds: 5),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Đang chia sẻ vị trí khi làm việc',
              notificationText:
                  'Super admin xem vị trí để hỗ trợ điều hành. Tắt chia sẻ tại Trang chủ khi nghỉ.',
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
    locationSettings: const LocationSettings(
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
  DateTime? lastSentAt;
  StreamSubscription<Position>? _subscription;
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
    notifyListeners();
    String? access;
    try {
      final error = await device.permission(request: requestPermission);
      if (error != null) throw DriverLocationException(422, error);
      if (generation != _generation) return;
      access = await api.token();
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
      enabled = true;
      _subscription = device.watch().listen(
        (position) {
          if (enabled && generation == _generation) {
            _latest = position;
          }
        },
        onError: (Object _) {
          lastError =
              'Chưa lấy được GPS mới. Kiểm tra quyền vị trí và GPS trên máy.';
          notifyListeners();
        },
      );
      _timer = Timer.periodic(const Duration(seconds: 10), (_) => flush());
      await flush();
    } catch (error) {
      if (generation == _generation) {
        enabled = false;
        _stream = null;
        await _subscription?.cancel();
        _subscription = null;
        _timer?.cancel();
        _timer = null;
        if (access != null) {
          try {
            await api.setSharing(false, accessToken: access);
          } catch (_) {}
        }
        lastError = error is DriverLocationException
            ? error.message
            : 'Chưa bật được chia sẻ vị trí. Kiểm tra mạng và thử lại.';
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
      notifyListeners();
    }
  }

  Future<void> stop({bool disableServer = true}) async {
    ++_generation;
    enabled = false;
    busy = false;
    _stream = null;
    _latest = null;
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
    notifyListeners();
    if (disableServer) {
      try {
        await api.setSharing(false);
        lastError = null;
      } catch (_) {
        lastError =
            'Đã dừng GPS trên máy. Chưa báo tắt được tới máy chủ; vị trí gần nhất sẽ chuyển cũ.';
      }
      notifyListeners();
    }
  }
}
