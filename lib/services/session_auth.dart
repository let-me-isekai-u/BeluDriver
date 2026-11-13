import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_storage.dart';

/// One renewal coordinator for REST, splash and SignalR token acquisition.
class SessionAuth {
  static Future<String?>? _renewal;
  static String? _renewalAccess;
  static final Map<String, String> _rotated = {};
  static final Map<String, String> _sessionIds = {};
  static void Function()? onExpired;

  static String operationSession(String token) => _sessionIds[token] ?? token;

  static Future<String?> tokenFor(String supplied) async {
    final current = await TokenStorage.instance.readAccessToken();
    if (current == supplied) return current;
    return current != null && _rotated[supplied] == current ? current : null;
  }

  static Future<String?> refresh(String? rejected) async {
    // Set the flight before any storage/network await, including for chat.
    final pending = _renewal;
    if (pending != null) {
      final pendingAccess = _renewalAccess;
      await pending;
      if (pendingAccess != rejected &&
          await TokenStorage.instance.readAccessToken() == rejected) {
        if (identical(_renewal, pending)) _renewal = null;
        return refresh(rejected);
      }
      return rejected == null
          ? TokenStorage.instance.readAccessToken()
          : tokenFor(rejected);
    }
    final flight = _refresh(rejected);
    _renewal = flight;
    _renewalAccess = rejected;
    try {
      return await flight;
    } finally {
      if (identical(_renewal, flight)) _renewal = null;
    }
  }

  static Future<String?> _refresh(String? rejected) async {
    final storage = TokenStorage.instance;
    final (access, refresh) = await storage.readTokens();
    if (access != rejected) {
      if (rejected == null) return access;
      return tokenFor(rejected);
    }
    if (refresh == null || refresh.isEmpty) {
      await _expire(access, refresh);
      return null;
    }

    // Raw client: never intercept the refresh request or recurse on its 401.
    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('$apiOrigin/api/accountdriverapi/refresh-token'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _expire(access, refresh);
        return null;
      }
      // Other 4xx are not assumed to mean revocation without a contract.
      if (response.statusCode != 200) {
        throw const SessionRenewalException();
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final nextAccess = data is Map ? data['accessToken'] : null;
      final nextRefresh = data is Map ? data['refreshToken'] : null;
      if (nextAccess is! String ||
          nextAccess.trim().isEmpty ||
          nextRefresh is! String ||
          nextRefresh.trim().isEmpty) {
        throw const SessionRenewalException();
      }
      final saved = await storage.rotateIfCurrent(
        expectedAccess: access,
        expectedRefresh: refresh,
        accessToken: nextAccess,
        refreshToken: nextRefresh,
      );
      if (!saved) return null;
      _sessionIds[nextAccess] = access == null
          ? nextAccess
          : operationSession(access);
      for (final old in _rotated.keys.toList()) {
        if (_rotated[old] == access) _rotated[old] = nextAccess;
      }
      if (access != null) _rotated[access] = nextAccess;
      return nextAccess;
    } finally {
      client.close();
    }
  }

  static Future<void> reject(String token) async {
    final (access, refresh) = await TokenStorage.instance.readTokens();
    if (access != token) return;
    await _expire(token, refresh);
  }

  static Future<void> _expire(String? access, String? refresh) async {
    if (await TokenStorage.instance.clearIfCurrent(
      expectedAccess: access,
      expectedRefresh: refresh,
    )) {
      _rotated.clear();
      _sessionIds.clear();
      onExpired?.call();
    }
  }

  static bool expiresSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = claims is Map ? claims['exp'] : null;
      return exp is num &&
          exp * 1000 <=
              DateTime.now()
                  .add(const Duration(seconds: 30))
                  .millisecondsSinceEpoch;
    } on FormatException {
      return false;
    }
  }
}

class SessionRenewalException implements Exception {
  const SessionRenewalException();
  @override
  String toString() =>
      'Chưa thể làm mới phiên. Vui lòng thử lại khi có kết nối.';
}
