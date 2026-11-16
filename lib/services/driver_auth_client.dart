import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'session_auth.dart';

/// Refresh only this driver's JWT on our own origin. Vehicle QR sessions use
/// their independent transport and must never receive a driver's credentials.
class DriverAuthClient extends http.BaseClient {
  DriverAuthClient({http.Client? inner}) : _inner = inner;
  final http.Client? _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final client = _inner ?? http.Client();
    try {
      final result = await _send(
        request,
        client,
      ).then(http.Response.fromStream).timeout(const Duration(seconds: 30));
      return http.StreamedResponse(
        Stream.value(result.bodyBytes),
        result.statusCode,
        headers: result.headers,
        request: result.request,
        reasonPhrase: result.reasonPhrase,
        persistentConnection: result.persistentConnection,
        isRedirect: result.isRedirect,
      );
    } finally {
      if (_inner == null) client.close();
    }
  }

  Future<http.StreamedResponse> _send(
    http.BaseRequest request,
    http.Client client,
  ) async {
    final origin = Uri.parse(apiOrigin);
    final auth = request.headers['Authorization'];
    if (request.url.origin != origin.origin ||
        auth == null ||
        !auth.startsWith('Bearer ') ||
        request.url.path.endsWith('/logout')) {
      return client.send(request);
    }
    final supplied = auth.substring(7);
    final token = await SessionAuth.tokenFor(supplied);
    if (token == null)
      return _message(
        request,
        401,
        'Phiên đăng nhập đã thay đổi. Vui lòng đăng nhập lại.',
      );
    request.headers['Authorization'] = 'Bearer $token';

    // No automatic replay of writes, even if a key is present: the backend's
    // idempotency guarantee has not been verified. This POST is read-only.
    final replayable =
        request.method == 'GET' ||
        request.method == 'HEAD' ||
        (request.method == 'POST' &&
            request.url.path == '/api/withdrawalapi/history-withdrawal');
    final bytes = replayable ? await request.finalize().toBytes() : null;
    http.Request copy(String access) {
      final next = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..headers['Authorization'] = 'Bearer $access'
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..persistentConnection = request.persistentConnection;
      if (bytes != null) next.bodyBytes = bytes;
      return next;
    }

    var response = await client.send(replayable ? copy(token) : request);
    if (response.statusCode != 401) return response;
    await response.stream.drain<void>();
    String? renewed;
    try {
      renewed = await SessionAuth.refresh(token);
    } catch (_) {
      // Storage/network/5xx failures preserve the session and allow retry.
      return _message(
        request,
        503,
        'Chưa thể làm mới phiên. Vui lòng kiểm tra kết nối và thử lại.',
      );
    }
    if (renewed == null)
      return _message(
        request,
        401,
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    if (!replayable)
      return _message(
        request,
        401,
        'Đã làm mới phiên. Vui lòng kiểm tra trạng thái trước khi thử lại thao tác.',
        code: 'session_renewed_not_replayed',
      );
    response = await client.send(copy(renewed));
    if (response.statusCode == 401) await SessionAuth.reject(renewed);
    return response;
  }

  http.StreamedResponse _message(
    http.BaseRequest request,
    int status,
    String message, {
    String? code,
  }) {
    final bytes = utf8.encode(
      jsonEncode({
        'success': false,
        'message': message,
        if (code != null) 'code': code,
      }),
    );
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      request: request,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  @override
  void close() => _inner?.close();
}
