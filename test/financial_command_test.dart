import 'dart:convert';
import 'support/driver_session_fixture.dart';

import 'package:beludriver_app/services/api_response.dart';
import 'package:beludriver_app/services/v2/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => installDriverSessionFixture('fixture'));
  test(
    'accept keeps its key after an unknown outcome and decodes Vietnamese',
    () async {
      final keys = <String?>[];
      final client = MockClient((request) async {
        keys.add(request.headers['Idempotency-Key']);
        if (keys.length == 1) return http.Response('', 502);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'insufficient_wallet_balance',
              'message': 'Số dư ví không đủ để nhận đơn.',
            }),
          ),
          409,
        );
      });

      await http.runWithClient(() async {
        Future<http.Response> accept() =>
            ApiService.acceptRide(accessToken: 'fixture', id: 7, rideSource: 1);

        expect((await accept()).statusCode, 502);
        final rejected = await accept();
        expect(responseJson(rejected)?['code'], 'insufficient_wallet_balance');
        expect(apiErrorMessage(rejected, ''), 'Số dư ví không đủ để nhận đơn.');
        await accept();
      }, () => client);

      expect(keys.first, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(keys[1], keys.first);
      expect(keys.last, isNot(keys.first));
    },
  );
}
