import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class ChatSession {
  static Future<String>? _refreshInFlight;
  static String? _attemptedRefresh;

  static Future<String> accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty || !_expiresSoon(token)) return token;

    final pending = _refreshInFlight;
    if (pending != null) {
      await pending;
      final latest = prefs.getString('accessToken') ?? '';
      return _expiresSoon(latest) ? '' : latest;
    }
    final refresh = prefs.getString('refreshToken');
    if (refresh == null || refresh.isEmpty || refresh == _attemptedRefresh) {
      return '';
    }

    _attemptedRefresh = refresh;
    final renewal = _renew(prefs, token, refresh);
    _refreshInFlight = renewal;
    try {
      return await renewal;
    } finally {
      _refreshInFlight = null;
    }
  }

  static Future<String> _renew(
    SharedPreferences prefs,
    String token,
    String refresh,
  ) async {
    try {
      final response = await ApiService.refreshToken(refreshToken: refresh);
      if (response.statusCode != 200) return '';
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map) return '';
      final access = data['accessToken'];
      final nextRefresh = data['refreshToken'];
      if (access is! String ||
          access.isEmpty ||
          nextRefresh is! String ||
          nextRefresh.isEmpty ||
          prefs.getString('accessToken') != token ||
          prefs.getString('refreshToken') != refresh) {
        return '';
      }
      if (!await prefs.setString('refreshToken', nextRefresh)) return '';
      if (prefs.getString('accessToken') != token ||
          prefs.getString('refreshToken') != nextRefresh)
        return '';
      return await prefs.setString('accessToken', access) ? access : '';
    } catch (_) {
      return '';
    }
  }

  static bool _expiresSoon(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return false;
    try {
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
