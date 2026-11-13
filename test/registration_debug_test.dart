import 'dart:convert';

import 'package:beludriver_app/services/v2/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final logs = <String>[];
  late DebugPrintCallback original;

  setUp(() {
    logs.clear();
    original = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });
  tearDown(() => debugPrint = original);

  Future<http.Response> register() => ApiService.driverRegister(
    fullName: 'Driver Fixture',
    phone: '0912345678',
    email: 'driver@example.com',
    password: 'Secret@123',
    licenseNumber: '29A-123.45',
    region: 1,
    challengeId: 'challenge-fixture',
    otp: '012345',
  );

  test(
    'registration diagnostics preserve error without exposing submitted data or tokens',
    () async {
      await http.runWithClient(
        () async {
          final response = await register();
          expect(response.statusCode, 400);
          expect(
            responseJsonForTest(response)['message'],
            contains('Email chưa được xác minh'),
          );
        },
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/accountdriverapi/driver-register-ver2',
          );
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data'),
          );
          expect(request.body, contains('Secret@123'));
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'success': false,
                'code': 'email_not_verified',
                'message': 'Email chưa được xác minh: driver@example.com',
                'errors': {
                  'password': 'Secret@123',
                  'accessToken': 'private-token',
                  'otp': '012345',
                  'challengeId': 'challenge-fixture',
                },
                'data': {'accessToken': 'returned-token'},
              }),
            ),
            400,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final output = logs.join('\n');
      expect(output, contains('REQUEST POST'));
      expect(output, contains('status=400'));
      expect(output, contains('elapsedMs='));
      expect(output, contains('email_not_verified'));
      expect(output, contains('Email chưa được xác minh'));
      for (final value in [
        'Driver Fixture',
        '0912345678',
        'driver@example.com',
        'Secret@123',
        '29A-123.45',
        'private-token',
        'returned-token',
        '012345',
        'challenge-fixture',
      ]) {
        expect(output, isNot(contains(value)));
      }
    },
  );

  test(
    'non-JSON response is not dumped and preserves original response',
    () async {
      await http.runWithClient(
        () async {
          final response = await register();
          expect(response.body, '<html>private-server-content</html>');
          expect(response.statusCode, 502);
        },
        () => MockClient(
          (_) async =>
              http.Response('<html>private-server-content</html>', 502),
        ),
      );
      expect(logs.join('\n'), contains('Non-JSON response'));
      expect(logs.join('\n'), isNot(contains('private-server-content')));
    },
  );

  test('network exception logs type and keeps failure response', () async {
    await http.runWithClient(() async {
      expect((await register()).statusCode, 503);
    }, () => MockClient((_) async => throw http.ClientException('Secret@123')));
    expect(logs.join('\n'), contains('ERROR type=ClientException'));
    expect(logs.join('\n'), isNot(contains('Secret@123')));
  });

  test(
    'challenge diagnostics redact echoed challenge and OTP returned by server',
    () async {
      await http.runWithClient(
        () async {
          final response = await ApiService.requestRegistrationChallenge(
            email: 'driver@example.invalid',
            phone: '0912345678',
          );
          expect(
            responseJsonForTest(response)['challengeId'],
            'challenge-secret',
          );
        },
        () => MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'challengeId': 'challenge-secret',
                'otp': '654321',
                'message': 'driver@example.invalid challenge-secret 654321',
                'errors': {
                  'nested': {
                    'otp': '654321',
                    'challengeId': 'challenge-secret',
                  },
                },
              }),
            ),
            200,
          ),
        ),
      );
      final output = logs.join('\n');
      expect(output, contains('REGISTER_CHALLENGE'));
      for (final secret in [
        'driver@example.invalid',
        '0912345678',
        'challenge-secret',
        '654321',
      ]) {
        expect(output, isNot(contains(secret)));
      }
    },
  );
}

Map<String, dynamic> responseJsonForTest(http.Response response) =>
    jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
