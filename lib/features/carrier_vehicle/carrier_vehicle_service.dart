// Chế độ "Xe nhà xe" (module Nhà xe — Xe limousine / Xe khách).
// Tài xế quét mã QR cố định dán trên xe là vào ngay (không mật khẩu/OTP). Phiên xe tách hẳn khỏi
// tài khoản tài xế xe ghép: access token 15 phút + session token để làm mới, lưu trong Secure Storage.
// Contract: docs/api/carrier-module-api.md (mục 3) của backend.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../services/token_storage.dart';

import '../../config/api_config.dart';

class CarrierVehicleException implements Exception {
  CarrierVehicleException(this.message, {this.sessionEnded = false});
  final String message;
  final bool sessionEnded;
  @override
  String toString() => message;
}

class CarrierVehicleSession {
  CarrierVehicleSession({required this.accessToken, required this.sessionToken, required this.sessionExpiresAt, required this.vehicle});
  String accessToken;
  final String sessionToken;
  final DateTime sessionExpiresAt;
  final Map<String, dynamic> vehicle;

  String get plate => '${vehicle['plateNumber'] ?? ''}';
  String get carrierName => '${vehicle['carrierName'] ?? ''}';
  String get category => vehicle['category'] == 'COACH' ? 'Xe khách' : 'Xe limousine';

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'sessionToken': sessionToken,
        'sessionExpiresAt': sessionExpiresAt.toIso8601String(),
        'vehicle': vehicle,
      };

  static CarrierVehicleSession fromJson(Map<String, dynamic> j) => CarrierVehicleSession(
        accessToken: j['accessToken'] as String,
        sessionToken: j['sessionToken'] as String,
        sessionExpiresAt: DateTime.parse(j['sessionExpiresAt'] as String),
        vehicle: Map<String, dynamic>.from(j['vehicle'] as Map),
      );
}

class CarrierVehicleService {
  static const String baseUrl = '$apiOrigin/api/carrier-vehicle';
  static CarrierVehicleSession? _session;

  static CarrierVehicleSession? get session => _session;

  static Future<CarrierVehicleSession?> load() async {
    final raw = await TokenStorage.instance.readVehicleSession();
    if (raw == null) return null;
    try {
      final s = CarrierVehicleSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (s.sessionExpiresAt.isBefore(DateTime.now())) {
        await _clear();
        return null;
      }
      return _session = s;
    } on TokenStorageException {
      rethrow;
    } catch (_) {
      await _clear();
      return null;
    }
  }

  static Future<void> _save() async {
    if (_session != null) await TokenStorage.instance.writeVehicleSession(jsonEncode(_session!.toJson()));
  }

  static Future<void> _clear() async {
    await TokenStorage.instance.clearVehicleSession();
    _session = null;
  }

  static dynamic _decode(http.Response r) {
    try {
      return r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static String _message(dynamic body, int status) {
    if (body is Map && body['message'] is String) return body['message'] as String;
    if (status == 404) return 'Chức năng xe nhà xe chưa mở hoặc không tìm thấy dữ liệu.';
    if (status == 429) return 'Thao tác quá nhanh, vui lòng thử lại sau.';
    return 'Lỗi máy chủ ($status). Vui lòng thử lại.';
  }

  /// Quét QR → đăng nhập ngay. [qr] là toàn bộ nội dung mã (URL có `#c=...&k=...`).
  static Future<CarrierVehicleSession> exchange(String qr, {String? deviceLabel}) async {
    final r = await http
        .post(Uri.parse('$baseUrl/auth/qr-exchange'),
            headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'qr': qr.trim(), 'deviceLabel': deviceLabel}))
        .timeout(const Duration(seconds: 20));
    final body = _decode(r);
    if (r.statusCode != 200 || body is! Map || body['data'] == null) throw CarrierVehicleException(_message(body, r.statusCode));
    final d = Map<String, dynamic>.from(body['data'] as Map);
    _session = CarrierVehicleSession(
      accessToken: d['accessToken'] as String,
      sessionToken: d['sessionToken'] as String,
      sessionExpiresAt: DateTime.parse(d['sessionExpiresAt'] as String),
      vehicle: Map<String, dynamic>.from(d['vehicle'] as Map),
    );
    await _save();
    return _session!;
  }

  static Future<bool> _refresh() async {
    final s = _session;
    if (s == null) return false;
    try {
      final r = await http
          .post(Uri.parse('$baseUrl/auth/refresh'),
              headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode({'sessionToken': s.sessionToken}))
          .timeout(const Duration(seconds: 20));
      final body = _decode(r);
      if (r.statusCode == 200 && body is Map && body['data'] is Map) {
        s.accessToken = (body['data'] as Map)['accessToken'] as String;
        await _save();
        return true;
      }
    } on TokenStorageException {
      rethrow;
    } catch (_) {
      debugPrint('carrier refresh failed');
    }
    return false;
  }

  static Future<dynamic> _call(String method, String path, {Object? body}) async {
    if (_session == null && await load() == null) {
      throw CarrierVehicleException('Phiên xe đã kết thúc. Vui lòng quét lại mã QR trên xe.', sessionEnded: true);
    }
    Future<http.Response> send() {
      final req = http.Request(method, Uri.parse('$baseUrl$path'))
        ..headers['Accept'] = 'application/json'
        ..headers['Authorization'] = 'Bearer ${_session!.accessToken}';
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      return req.send().then(http.Response.fromStream).timeout(const Duration(seconds: 25));
    }

    var r = await send();
    if (r.statusCode == 401) {
      if (!await _refresh()) {
        await _clear();
        throw CarrierVehicleException('Phiên xe đã kết thúc hoặc mã QR đã được cấp lại. Vui lòng quét lại mã QR trên xe.', sessionEnded: true);
      }
      r = await send();
    }
    final decoded = _decode(r);
    if (r.statusCode < 200 || r.statusCode >= 300) throw CarrierVehicleException(_message(decoded, r.statusCode));
    return decoded is Map ? decoded['data'] : decoded;
  }

  static Future<void> logout() async {
    await CarrierGpsTracker.instance.stop();
    try {
      if (_session != null) await _call('POST', '/auth/logout', body: {});
    } catch (_) {}
    await _clear();
  }

  static Future<List<dynamic>> runsToday() async => (await _call('GET', '/runs/today') as List?) ?? [];
  static Future<Map<String, dynamic>> passengers(int runId) async => Map<String, dynamic>.from(await _call('GET', '/runs/$runId/passengers') as Map);
  static Future<void> start(int runId) => _call('POST', '/runs/$runId/start', body: {});
  static Future<void> stopEvent(int runId, int runStopId, {required bool arrive}) =>
      _call('POST', '/runs/$runId/stops/$runStopId/${arrive ? 'arrive' : 'depart'}', body: {});
  static Future<void> markBooking(int runId, String code, {required bool boarded}) =>
      _call('POST', '/runs/$runId/bookings/${Uri.encodeComponent(code)}/${boarded ? 'board' : 'no-show'}', body: {});
  static Future<void> complete(int runId) => _call('POST', '/runs/$runId/complete', body: {});
  static Future<void> postLocations(int runId, List<Map<String, dynamic>> points) =>
      _call('POST', '/runs/$runId/location', body: {'points': points});
}

/// Gửi GPS của chuyến đang chạy theo lô (tối đa 50 điểm/lần). Mất mạng thì giữ trong bộ đệm và gửi lại;
/// server bỏ qua điểm cũ hơn vị trí mới nhất nên gửi lại không làm "lùi" vị trí xe.
class CarrierGpsTracker extends ChangeNotifier {
  CarrierGpsTracker._();
  static final CarrierGpsTracker instance = CarrierGpsTracker._();

  int? runId;
  DateTime? lastSentAt;
  String? lastError;
  int pending = 0;
  StreamSubscription<Position>? _sub;
  Timer? _timer;
  final List<Map<String, dynamic>> _buffer = [];
  int _sequence = DateTime.now().millisecondsSinceEpoch;
  bool _sending = false;

  bool get active => runId != null && _sub != null;

  /// Trả về thông báo lỗi (quyền/GPS tắt) hoặc null khi đã bắt đầu gửi vị trí.
  Future<String?> start(int run) async {
    if (runId == run && active) return null;
    await stop();
    if (!await Geolocator.isLocationServiceEnabled()) return 'Hãy bật GPS (định vị) trên điện thoại.';
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return 'Ứng dụng cần quyền vị trí để khách theo dõi xe.';
    }
    runId = run;
    final LocationSettings settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
            intervalDuration: const Duration(seconds: 5),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Đang chia sẻ vị trí xe',
              notificationText: 'Khách có vé đang theo dõi vị trí xe của chuyến này.',
              enableWakeLock: true,
            ),
          )
        : defaultTargetPlatform == TargetPlatform.iOS
            ? AppleSettings(accuracy: LocationAccuracy.high, distanceFilter: 15, pauseLocationUpdatesAutomatically: false)
            : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15);
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition, onError: (Object e) {
      lastError = e is LocationServiceDisabledException
          ? 'Vị trí (GPS) trên máy đang tắt. Bật Vị trí để khách theo dõi được xe.'
          : 'Mất tín hiệu GPS. Đang thử lại...';
      debugPrint('carrier gps error: $e');
      notifyListeners();
    });
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => flush());
    notifyListeners();
    return null;
  }

  void _onPosition(Position p) {
    _buffer.add({
      'latitude': double.parse(p.latitude.toStringAsFixed(6)),
      'longitude': double.parse(p.longitude.toStringAsFixed(6)),
      'accuracyMeters': p.accuracy,
      'speedMps': p.speed < 0 ? null : p.speed,
      'headingDegrees': p.heading < 0 ? null : p.heading,
      'capturedAt': p.timestamp.toUtc().toIso8601String(),
      'sequence': ++_sequence,
    });
    if (_buffer.length > 600) _buffer.removeRange(0, _buffer.length - 600); // mất mạng lâu: giữ phần mới nhất
    pending = _buffer.length;
    notifyListeners();
  }

  Future<void> flush() async {
    final run = runId;
    if (run == null || _sending || _buffer.isEmpty) return;
    _sending = true;
    try {
      while (_buffer.isNotEmpty) {
        final batch = _buffer.take(50).toList();
        await CarrierVehicleService.postLocations(run, batch);
        _buffer.removeRange(0, batch.length);
        lastSentAt = DateTime.now();
        lastError = null;
      }
    } on CarrierVehicleException catch (e) {
      lastError = e.message;
      // Phiên hết hạn hoặc chuyến không còn nhận vị trí: bỏ bộ đệm để không gửi mãi.
      _buffer.clear();
    } catch (_) {
      lastError = 'Chưa gửi được vị trí (mạng). Sẽ thử lại.';
    } finally {
      _sending = false;
      pending = _buffer.length;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await flush();
    await _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
    runId = null;
    _buffer.clear();
    pending = 0;
    notifyListeners();
  }
}
