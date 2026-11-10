import 'dart:convert';

import 'package:beludriver_app/config/api_config.dart';
import 'package:beludriver_app/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'driver login returns a readable Vietnamese error when offline',
    () async {
      Uri? requestedUrl;
      final client = MockClient((request) async {
        requestedUrl = request.url;
        throw http.ClientException('Connection refused', request.url);
      });

      final response = await http.runWithClient(
        () => ApiService.driverLogin(
          phone: '0000000000',
          password: 'Test-only',
          deviceToken: '',
        ),
        () => client,
      );

      expect(
        requestedUrl,
        Uri.parse('$apiOrigin/api/accountdriverapi/driver/login'),
      );
      expect(response.statusCode, 503);
      expect(jsonDecode(response.body)['code'], 'connection_failed');
      expect(
        jsonDecode(response.body)['message'],
        'Không kết nối được máy chủ. Vui lòng kiểm tra mạng và thử lại.',
      );
    },
  );
}
