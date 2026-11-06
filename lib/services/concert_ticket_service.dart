import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/concert_ticket_verification_model.dart';
import 'api_service.dart';
import '../config/api_config.dart';

class ConcertTicketService {
  const ConcertTicketService({http.Client? client}) : _client = client;

  static const String _baseUrl = '$apiOrigin';
  static const String _checkInPath = '/api/v1/concert/driver/tickets/check-in';

  final http.Client? _client;

  Future<ConcertTicketVerification> checkInTicket({
    required String accessToken,
    required String qrPayload,
  }) async {
    final client = _client ?? http.Client();
    final uri = Uri.parse('$_baseUrl$_checkInPath');
    try {
      final response = await client
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({'qrPayload': qrPayload}),
          )
          .timeout(const Duration(seconds: 20));
      final decoded = ApiService.safeDecode(response.body);
      final payload = decoded is Map<String, dynamic>
          ? (decoded['data'] is Map<String, dynamic>
                ? decoded['data'] as Map<String, dynamic>
                : decoded)
          : <String, dynamic>{};

      return ConcertTicketVerification.fromJson({
        ...payload,
        if (payload['success'] == null)
          'success': response.statusCode >= 200 && response.statusCode < 300,
        if (payload['message'] == null && decoded is Map<String, dynamic>)
          'message': decoded['message'],
      });
    } catch (error) {
      return ConcertTicketVerification(
        isValid: false,
        status: 'NETWORK_ERROR',
        message: 'Không kết nối được server kiểm vé: $error',
      );
    } finally {
      if (_client == null) client.close();
    }
  }
}
