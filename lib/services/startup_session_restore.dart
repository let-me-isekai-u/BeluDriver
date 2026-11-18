import '../features/carrier_vehicle/carrier_vehicle_service.dart';
import 'active_session_mode.dart';
import 'api_service.dart';
import 'session_auth.dart';
import 'token_storage.dart';

class RestoredAppSession {
  const RestoredAppSession.carrier(this.runs)
    : mode = SessionMode.carrier,
      driverToken = null;
  const RestoredAppSession.driver(this.driverToken)
    : mode = SessionMode.driver,
      runs = null;

  final SessionMode mode;
  final List<dynamic>? runs;
  final String? driverToken;
}

/// Credentials on disk are candidates; a protected API validates them before routing.
class StartupSessionRestore {
  static Future<RestoredAppSession?>? _inFlight;

  static Future<RestoredAppSession?> restore() async {
    final pending = _inFlight;
    if (pending != null) return pending;
    final flight = _restore();
    _inFlight = flight;
    try {
      return await flight;
    } finally {
      if (identical(_inFlight, flight)) _inFlight = null;
    }
  }

  static Future<RestoredAppSession?> _restore() async {
    final order = await ActiveSessionMode.readOrder();
    for (final mode in order) {
      if (mode == SessionMode.carrier) {
        final vehicle = await CarrierVehicleService.load();
        if (vehicle == null) continue;
        try {
          final runs = await CarrierVehicleService.runsToday();
          return RestoredAppSession.carrier(runs);
        } on CarrierVehicleException catch (error) {
          if (error.sessionEnded) continue;
          rethrow; // Network/429/5xx are not evidence that the session ended.
        }
      } else {
        final tokens = await TokenStorage.instance.readTokens();
        var token = tokens.$1;
        if (token == null && tokens.$2 == null) continue;
        token ??= await SessionAuth.refresh(null);
        if (token == null) continue;
        final response = await ApiService.getDriverProfile(accessToken: token);
        if (response.statusCode == 401) {
          // DriverAuthClient only clears a session on authoritative rejection.
          // A failed/malformed renewal preserves it and must stay retryable.
          if (await TokenStorage.instance.readAccessToken() == null) continue;
          throw const SessionRenewalException();
        }
        if (response.statusCode != 200) throw const SessionRenewalException();
        final current = await SessionAuth.tokenFor(token);
        if (current == null) throw const SessionRenewalException();
        return RestoredAppSession.driver(current);
      }
    }
    return null;
  }
}
