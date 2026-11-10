import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

Map<String, dynamic>? responseJson(http.Response response) {
  try {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data is Map<String, dynamic> ? data : null;
  } on FormatException {
    return null;
  }
}

String apiErrorMessage(http.Response response, String fallback) {
  final body = responseJson(response);
  final message = body?['message'] ?? body?['title'];
  if (message is String && message.trim().isNotEmpty) return message;
  return switch (response.statusCode) {
    401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    403 => 'Bạn không có quyền thực hiện thao tác này.',
    429 => 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.',
    _ => fallback,
  };
}

http.Response connectionFailure(Object error, {String? message}) {
  final timedOut = error is TimeoutException;
  final body = jsonEncode({
    'success': false,
    'code': timedOut ? 'connection_timeout' : 'connection_failed',
    'message':
        message ??
        (timedOut
            ? 'Máy chủ phản hồi quá chậm. Vui lòng thử lại.'
            : 'Không kết nối được máy chủ. Vui lòng kiểm tra mạng và thử lại.'),
  });
  return http.Response.bytes(
    utf8.encode(body),
    timedOut ? 504 : 503,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

final _pendingKeys = <(String, String, Uri, String?), String>{};

Future<http.Response> sendFinancialCommand(
  String method,
  Uri url,
  String token, {
  String? body,
  String? idempotencyKey,
}) async {
  final operation = (token, method, url, body);
  final key =
      idempotencyKey ??
      _pendingKeys.putIfAbsent(operation, () {
        final random = Random.secure();
        return List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
      });
  final request = http.Request(method, url);
  request.headers.addAll({
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'Idempotency-Key': key,
    if (body != null) 'Content-Type': 'application/json',
  });
  if (body != null) request.body = body;

  final client = http.Client();
  try {
    final response = await client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 20));
    final errorCode = responseJson(response)?['code'];
    if (idempotencyKey == null &&
        _pendingKeys[operation] == key &&
        response.statusCode < 500 &&
        response.statusCode != 401 &&
        errorCode != 'operation_pending' &&
        (response.statusCode != 409 || errorCode != null)) {
      _pendingKeys.remove(operation);
    }
    return response;
  } catch (error) {
    return connectionFailure(
      error,
      message:
          'Chưa xác nhận được kết quả. Vui lòng kiểm tra trạng thái trước khi thử lại.',
    );
  } finally {
    client.close();
  }
}
