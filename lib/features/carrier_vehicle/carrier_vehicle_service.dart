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
import '../../services/active_session_mode.dart';
import '../../services/qr_cooldown.dart';

import '../../config/api_config.dart';

class CarrierVehicleException implements Exception {
  CarrierVehicleException(
    this.message, {
    this.sessionEnded = false,
    this.statusCode,
  });
  final int? statusCode;
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
  static Future<bool>? _refreshInFlight;
  static CarrierVehicleSession? _refreshSession;
  static Future<CarrierVehicleSession>? _exchangeInFlight;
  static Future<CarrierVehicleSession?>? _loadInFlight;
  static Future<List<dynamic>>? _runsInFlight;
  static CarrierVehicleSession? _runsSession;
  static Future<void> _mutationTail = Future<void>.value();
  static int _generation = 0;
  static final _cooldown = QrCooldown();
  static String? sessionEndMessage;

  static CarrierVehicleSession? get session => _session;
  static bool get coolingDown => _cooldown.active;
  static String get cooldownMessage => _cooldown.message;

  static Future<T> _mutate<T>(Future<T> Function() action) {
    final result = _mutationTail.then((_) => action());
    _mutationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  static void _assertSession(CarrierVehicleSession expected) {
    if (!identical(_session, expected)) {
      throw CarrierVehicleException(
        _session == null ? 'Phiên xe đã kết thúc. Vui lòng quét lại mã QR.' : 'Phiên xe đã thay đổi. Vui lòng tải lại.',
        sessionEnded: _session == null,
      );
    }
  }

  static void _checkCooldown() {
    if (_cooldown.active) {
      throw CarrierVehicleException(_cooldown.message, statusCode: 429);
    }
  }

  static void _observe(http.Response response, String method, String path) {
    _cooldown.record(response);
    // No bodies, headers, QR payloads or token values in diagnostics.
    if (kDebugMode) {
      debugPrint('[CARRIER_HTTP] $method $path status=${response.statusCode}');
    }
  }

  static Future<CarrierVehicleSession?> load() async {
    if (_session != null) return _session;
    final pending = _loadInFlight;
    if (pending != null) return pending;
    final generation = _generation;
    final flight = _mutate(() async {
      if (_session != null) return _session;
      final raw = await TokenStorage.instance.readVehicleSession();
      if (generation != _generation || raw == null) return _session;
      // Storage validates shape; never clear a session for a transient read error.
      final stored = CarrierVehicleSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (!stored.sessionExpiresAt.isAfter(DateTime.now())) {
        await TokenStorage.instance.clearVehicleSession();
        sessionEndMessage = 'Phiên xe đã hết hạn. Vui lòng quét lại mã QR trên xe.';
        return null;
      }
      return _session = stored;
    });
    _loadInFlight = flight;
    try {
      return await flight;
    } finally {
      if (identical(_loadInFlight, flight)) _loadInFlight = null;
    }
  }

  static Future<void> _endSession(CarrierVehicleSession expected) =>
      _mutate(() async {
        _assertSession(expected);
        await TokenStorage.instance.clearVehicleSession();
        if (identical(_session, expected)) {
          _session = null;
          sessionEndMessage = 'Phiên xe đã kết thúc hoặc bị thu hồi. Vui lòng quét lại mã QR.';
          _generation++;
          // Do not send another batch using a revoked session.
          await CarrierGpsTracker.instance.stop(sendPending: false);
        }
      });

  static dynamic _decode(http.Response r) {
    try {
      return r.bodyBytes.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static String _message(dynamic body, int status) {
    if (status == 429) return _cooldown.message;
    if (body is Map && body['message'] is String) {
      return body['message'] as String;
    }
    if (status == 404) {
      return 'Chức năng xe nhà xe chưa mở hoặc không tìm thấy dữ liệu.';
    }
    return 'Lỗi máy chủ ($status). Vui lòng thử lại.';
  }

  /// One scan creates one session. The server revokes the previous session on exchange.
  static Future<CarrierVehicleSession> exchange(
    String qr, {
    String? deviceLabel,
    bool Function()? canAccept,
  }) async {
    final pending = _exchangeInFlight;
    if (pending != null) {
      throw CarrierVehicleException('Đang đăng nhập xe. Vui lòng chờ.');
    }
    _checkCooldown();
    final generation = ++_generation;
    final flight = _exchange(qr, generation, deviceLabel, canAccept);
    _exchangeInFlight = flight;
    try {
      return await flight;
    } finally {
      if (identical(_exchangeInFlight, flight)) _exchangeInFlight = null;
    }
  }

  static Future<CarrierVehicleSession> _exchange(
    String qr,
    int generation,
    String? deviceLabel,
    bool Function()? canAccept,
  ) async {
    final r = await http
        .post(
          Uri.parse('$baseUrl/auth/qr-exchange'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'qr': qr.trim(), 'deviceLabel': deviceLabel}),
        )
        .timeout(const Duration(seconds: 20));
    if (generation != _generation || (canAccept != null && !canAccept())) {
      throw CarrierVehicleException('Đã hủy đăng nhập xe.');
    }
    _observe(r, 'POST', '/auth/qr-exchange');
    final body = _decode(r);
    if (r.statusCode != 200 || body is! Map || body['data'] is! Map) {
      throw CarrierVehicleException(
        _message(body, r.statusCode),
        statusCode: r.statusCode,
      );
    }
    final next = CarrierVehicleSession.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
    return _mutate(() async {
      if (generation != _generation || (canAccept != null && !canAccept())) {
        throw CarrierVehicleException(
          'Đã hủy đăng nhập xe. Vui lòng quét lại khi cần.',
        );
      }
      await CarrierGpsTracker.instance.stop(sendPending: false);
      await TokenStorage.instance.writeVehicleSession(
        jsonEncode(next.toJson()),
      );
      if (generation != _generation || (canAccept != null && !canAccept())) {
        // A subsequent logout is queued behind this write and will clear it.
        await TokenStorage.instance.clearVehicleSession();
        throw CarrierVehicleException('Đã hủy đăng nhập xe.');
      }
      _session = next;
      sessionEndMessage = null;
      await ActiveSessionMode.remember(SessionMode.carrier);
      return next;
    });
  }

  static Future<bool> _refresh(
    CarrierVehicleSession expected,
    String rejected,
  ) async {
    _assertSession(expected);
    // A late 401 may refer to the old token after another call already refreshed.
    if (expected.accessToken != rejected) return true;
    final pending = _refreshInFlight;
    if (pending != null && identical(_refreshSession, expected)) return pending;
    final flight = _renewSession(expected);
    _refreshSession = expected;
    _refreshInFlight = flight;
    try {
      return await flight;
    } finally {
      if (identical(_refreshInFlight, flight)) {
        _refreshInFlight = null;
        _refreshSession = null;
      }
    }
  }

  static Future<bool> _renewSession(CarrierVehicleSession expected) async {
    _checkCooldown();
    final r = await http
        .post(
          Uri.parse('$baseUrl/auth/refresh'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'sessionToken': expected.sessionToken}),
        )
        .timeout(const Duration(seconds: 20));
    _assertSession(expected);
    _observe(r, 'POST', '/auth/refresh');
    if (r.statusCode == 401 || r.statusCode == 403) return false;
    final body = _decode(r);
    final access = body is Map && body['data'] is Map
        ? body['data']['accessToken']
        : null;
    if (r.statusCode != 200 || access is! String || access.trim().isEmpty) {
      throw CarrierVehicleException(
        _message(body, r.statusCode),
        statusCode: r.statusCode,
      );
    }
    return _mutate(() async {
      _assertSession(expected);
      final updated = {...expected.toJson(), 'accessToken': access};
      await TokenStorage.instance.writeVehicleSession(jsonEncode(updated));
      _assertSession(expected);
      expected.accessToken = access;
      return true;
    });
  }

  static Future<dynamic> _call(
    String method,
    String path, {
    Object? body,
  }) async {
    if (_session == null && await load() == null) {
      throw CarrierVehicleException(
        'Phiên xe đã kết thúc. Vui lòng quét lại mã QR trên xe.',
        sessionEnded: true,
      );
    }
    final activeSession = _session!;
    Future<http.Response> send() async {
      _assertSession(activeSession);
      _checkCooldown();
      final req = http.Request(method, Uri.parse('$baseUrl$path'))
        ..headers['Accept'] = 'application/json'
        ..headers['Authorization'] = 'Bearer ${activeSession.accessToken}';
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      final client = http.Client();
      try {
        final r = await client
            .send(req)
            .then(http.Response.fromStream)
            .timeout(const Duration(seconds: 25));
        _assertSession(activeSession);
        _observe(r, method, path);
        return r;
      } finally {
        client.close();
      }
    }

    final rejected = activeSession.accessToken;
    var r = await send();
    if (r.statusCode == 401) {
      final renewed = await _refresh(activeSession, rejected);
      _assertSession(activeSession);
      if (!renewed) {
        await _endSession(activeSession);
        throw CarrierVehicleException(
          'Phiên xe đã kết thúc hoặc bị thu hồi. Vui lòng quét lại mã QR trên xe.',
          sessionEnded: true,
        );
      }
      r = await send(); // Backend auth rejects before executing the operation; at most one replay.
      if (r.statusCode == 401) {
        await _endSession(activeSession);
        throw CarrierVehicleException(
          'Phiên xe không còn hợp lệ. Vui lòng quét lại mã QR.',
          sessionEnded: true,
        );
      }
    }
    final decoded = _decode(r);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw CarrierVehicleException(
        _message(decoded, r.statusCode),
        statusCode: r.statusCode,
      );
    }
    return decoded is Map ? decoded['data'] : decoded;
  }

  static Future<void> logout() async {
    final expected = _session;
    ++_generation; // Invalidate pending exchange/load before any await.
    await CarrierGpsTracker.instance.stop(sendPending: false);
    try {
      if (expected != null) {
        _assertSession(expected);
        await _call('POST', '/auth/logout', body: {});
      }
    } catch (_) {
      // Local logout is still available offline; the backend expires the session.
    }
    await _mutate(() async {
      if (_session != null && !identical(_session, expected)) return;
      await TokenStorage.instance.clearVehicleSession();
      _session = null;
      sessionEndMessage = null;
      await ActiveSessionMode.remember(SessionMode.driver);
    });
  }

  static Future<List<dynamic>> runsToday() async {
    if (_session == null) await load();
    final expected = _session;
    final pending = _runsInFlight;
    if (pending != null && identical(_runsSession, expected)) return pending;
    final flight = () async {
      final data = await _call('GET', '/runs/today');
      if (data is! List) {
        throw CarrierVehicleException(
          'Dữ liệu chuyến chưa hợp lệ. Vui lòng tải lại.',
        );
      }
      return data;
    }();
    _runsSession = expected;
    _runsInFlight = flight;
    try {
      return await flight;
    } finally {
      if (identical(_runsInFlight, flight)) _runsInFlight = null;
    }
  }

  static Future<Map<String, dynamic>> passengers(int runId) async =>
      Map<String, dynamic>.from(
        await _call('GET', '/runs/$runId/passengers') as Map,
      );
  static Future<void> start(int runId) =>
      _call('POST', '/runs/$runId/start', body: {});
  static Future<void> stopEvent(
    int runId,
    int runStopId, {
    required bool arrive,
  }) => _call(
    'POST',
    '/runs/$runId/stops/$runStopId/${arrive ? 'arrive' : 'depart'}',
    body: {},
  );
  static Future<void> markBooking(
    int runId,
    String code, {
    required bool boarded,
  }) => _call(
    'POST',
    '/runs/$runId/bookings/${Uri.encodeComponent(code)}/${boarded ? 'board' : 'no-show'}',
    body: {},
  );
  static Future<void> complete(int runId) =>
      _call('POST', '/runs/$runId/complete', body: {});
  static Future<void> postLocations(
    int runId,
    List<Map<String, dynamic>> points,
  ) => _call('POST', '/runs/$runId/location', body: {'points': points});
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
  int _epoch = 0;
  CarrierVehicleSession? _owner;
  Future<String?>? _startFlight;
  int? _startingRun;
  int _startRequest = 0;

  bool get active => runId != null && _sub != null;

  /// Trả về thông báo lỗi (quyền/GPS tắt) hoặc null khi đã bắt đầu gửi vị trí.
  Future<String?> start(int run) async {
    if (runId == run && active) return null;
    final pending = _startFlight;
    if (pending != null && _startingRun == run) return pending;
    final request = ++_startRequest;
    final flight = _startTracking(run, request);
    _startingRun = run;
    _startFlight = flight;
    try { return await flight; } finally {
      if (identical(_startFlight, flight)) { _startFlight = null; _startingRun = null; }
    }
  }

  Future<String?> _startTracking(int run, int request) async {
    await _stopTracking();
    if (request != _startRequest) return null;
    final epoch = _epoch;
    final owner = CarrierVehicleService.session;
    if (owner == null) return 'Phiên xe đã kết thúc.';
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Hãy bật GPS (định vị) trên điện thoại.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return 'Ứng dụng cần quyền vị trí để khách theo dõi xe.';
    }
    if (request != _startRequest || epoch != _epoch || !identical(owner, CarrierVehicleService.session)) {
      return null;
    }
    _owner = owner;
    runId = run;
    lastSentAt = null;
    lastError = null;
    final LocationSettings settings =
        defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
            intervalDuration: const Duration(seconds: 5),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Đang chia sẻ vị trí xe',
              notificationText:
                  'Khách có vé đang theo dõi vị trí xe của chuyến này.',
              enableWakeLock: true,
            ),
          )
        : defaultTargetPlatform == TargetPlatform.iOS
        ? AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
            pauseLocationUpdatesAutomatically: false,
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
          );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) { if (epoch == _epoch) _onPosition(position); },
      onError: (Object e) {
        if (epoch != _epoch) return;
        lastError = e is LocationServiceDisabledException
            ? 'Vị trí (GPS) trên máy đang tắt. Bật Vị trí để khách theo dõi được xe.'
            : 'Mất tín hiệu GPS. Đang thử lại...';
        debugPrint('carrier gps error: ${e.runtimeType}');
        notifyListeners();
      },
    );
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => flush());
    notifyListeners();
    return null;
  }

  void _onPosition(Position p) {
    if (runId == null || !identical(_owner, CarrierVehicleService.session)) {
      return;
    }
    _buffer.add({
      'latitude': double.parse(p.latitude.toStringAsFixed(6)),
      'longitude': double.parse(p.longitude.toStringAsFixed(6)),
      'accuracyMeters': p.accuracy,
      'speedMps': p.speed < 0 ? null : p.speed,
      'headingDegrees': p.heading < 0 ? null : p.heading,
      'capturedAt': p.timestamp.toUtc().toIso8601String(),
      'sequence': ++_sequence,
    });
    if (_buffer.length > 600) {
      _buffer.removeRange(
        0,
        _buffer.length - 600,
      ); // mất mạng lâu: giữ phần mới nhất
    }
    pending = _buffer.length;
    notifyListeners();
  }

  Future<void> flush() async {
    final run = runId;
    final epoch = _epoch;
    if (run == null ||
        _sending ||
        _buffer.isEmpty ||
        CarrierVehicleService.coolingDown) {
      return;
    }
    if (!identical(_owner, CarrierVehicleService.session)) return;
    _sending = true;
    // One batch per tick: avoid a burst after reconnecting.
    final batch = _buffer.take(50).toList();
    try {
      await CarrierVehicleService.postLocations(run, batch);
      if (epoch != _epoch) return;
      // The 600-point cap may have evicted some points during the request.
      final lastSequence = batch.last['sequence'] as int;
      _buffer.removeWhere(
        (point) => (point['sequence'] as int) <= lastSequence,
      );
      lastSentAt = DateTime.now();
      lastError = null;
    } on CarrierVehicleException catch (e) {
      if (epoch != _epoch) return;
      lastError = e.message;
      if (e.sessionEnded || e.statusCode == 404 || e.statusCode == 422) {
        await stop(sendPending: false);
      }
      // Network, 429 and 5xx keep queued points for a later timer tick.
    } catch (_) {
      if (epoch == _epoch) {
        lastError = 'Chưa gửi được vị trí (mạng). Sẽ thử lại.';
      }
    } finally {
      _sending = false;
      pending = _buffer.length;
      notifyListeners();
    }
  }

  Future<void> stop({bool sendPending = false}) async {
    ++_startRequest;
    _startFlight = null;
    _startingRun = null;
    if (sendPending) await flush();
    await _stopTracking();
  }

  Future<void> _stopTracking() async {
    ++_epoch;
    _timer?.cancel();
    _timer = null;
    final subscription = _sub;
    _sub = null;
    runId = null;
    _owner = null;
    _buffer.clear();
    pending = 0;
    await subscription?.cancel();
    notifyListeners();
  }
}
