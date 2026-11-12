import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/chat_session.dart';

class DriverLocationException implements Exception {
  final int status;
  final String message;
  const DriverLocationException(this.status, this.message);
  @override
  String toString() => message;
}

class DriverLocationApi {
  final http.Client client;
  DriverLocationApi({http.Client? client}) : client = client ?? http.Client();

  Future<String> token() async {
    final value = await ChatSession.accessToken();
    if (value.isEmpty) {
      throw const DriverLocationException(
        401,
        'Phiên đã hết hạn. Đăng nhập lại để chia sẻ vị trí.',
      );
    }
    return value;
  }

  Future<Map<String, dynamic>> _call(
    String method,
    String suffix, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final request = http.Request(
      method,
      Uri.parse('$apiOrigin/api/driver/location$suffix'),
    );
    request.headers.addAll({
      'Authorization': 'Bearer ${accessToken ?? await token()}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await client.send(request).timeout(const Duration(seconds: 10)),
    );
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      /* A proxy error need not contain JSON. */
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DriverLocationException(
        response.statusCode,
        data['message'] as String? ?? 'Chưa gửi được vị trí. Vui lòng thử lại.',
      );
    }
    return data;
  }

  Future<bool> sharing() async =>
      (await _call('GET', '/sharing'))['enabled'] == true;
  Future<Map<String, dynamic>> setSharing(
    bool enabled, {
    String? accessToken,
  }) => _call(
    'PUT',
    '/sharing',
    body: {'enabled': enabled},
    accessToken: accessToken,
  );
  Future<Map<String, dynamic>> report(Map<String, dynamic> point) =>
      _call('POST', '', body: point);
}
