import 'dart:convert';
import 'support/driver_session_fixture.dart';

import 'package:beludriver_app/services/concert_ticket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => installDriverSessionFixture('driver-token'));
  test('check-in ticket posts raw qrPayload to driver concert API', () async {
    final service = ConcertTicketService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/concert/driver/tickets/check-in');
        expect(request.headers['Authorization'], 'Bearer driver-token');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(
          body,
          equals({'qrPayload': 'BBT1.BBT261024D1FB346B501.Lny5fETexq2V9OJ'}),
        );

        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Đã kiểm vé.',
            'data': {
              'isValid': true,
              'resultCode': 'VALID_AND_CHECKED_IN',
              'ticketCode': 'BBT261024D1FB346B501',
              'status': 'USED',
              'serviceName': 'Chiều đi ngày 24/10/2026',
              'usedAt': '2026-08-24T16:20:00.5845552+07:00',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.checkInTicket(
      accessToken: 'driver-token',
      qrPayload: 'BBT1.BBT261024D1FB346B501.Lny5fETexq2V9OJ',
    );

    expect(result.isValid, isTrue);
    expect(result.resultCode, 'VALID_AND_CHECKED_IN');
    expect(result.ticketCode, 'BBT261024D1FB346B501');
    expect(result.status, 'USED');
    expect(result.usedAt, '2026-08-24T16:20:00.5845552+07:00');
  });

  test('verify ticket keeps invalid result returned by server', () async {
    final service = ConcertTicketService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'message': 'Vé đã được sử dụng.',
            'data': {'isValid': false, 'status': 'COMPLETED'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final result = await service.checkInTicket(
      accessToken: 'driver-token',
      qrPayload: 'BBT1.BBT261024D1FB346B501.Lny5fETexq2V9OJ',
    );

    expect(result.isValid, isFalse);
    expect(result.status, 'COMPLETED');
    expect(result.message, 'Vé đã được sử dụng.');
  });
}
