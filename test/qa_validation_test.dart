import 'package:beludriver_app/providers/broker/order_form_provider.dart';
import 'package:beludriver_app/providers/driver/register_provider.dart';
import 'package:beludriver_app/models/location_models.dart';
import 'package:beludriver_app/validation/withdrawal_validation.dart';
import 'package:beludriver_app/services/api_service.dart';
import 'package:beludriver_app/services/api_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'support/driver_session_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => installDriverSessionFixture('fixture'));

  group('Register validation priority', () {
    late RegisterProvider form;
    setUp(() {
      form = RegisterProvider();
      form.fullNameController.text = 'Tài xế QA';
      form.emailController.text = 'qa@example.com';
      form.phoneController.text = '0912345678';
      form.confirmPhoneController.text = '0912345678';
      form.passwordController.text = 'Strong@123';
      form.confirmPasswordController.text = 'Strong@123';
      form.licenseNumberController.text = '29A-123.45';
      form.agreeTerms = true;
      form.agreeCamera = true;
      form.selectedRegion = 1;
    });
    tearDown(() => form.dispose());

    test('valid input reaches registration without bypassing verification', () {
      expect(form.validate(), isNull);
    });
    test('TC_Register_17 empty confirmation precedes mismatch', () {
      form.confirmPhoneController.text = '  ';
      expect(form.validate(), 'Chưa nhập lại số điện thoại');
      form.confirmPhoneController.text = '0912345679';
      expect(form.validate(), 'Số điện thoại nhập lại không trùng');
    });
    test('TC_Register_19 empty confirmation precedes mismatch', () {
      form.confirmPasswordController.clear();
      expect(form.validate(), 'Chưa nhập lại mật khẩu');
      form.confirmPasswordController.text = 'Other@123';
      expect(form.validate(), 'Mật khẩu nhập lại không trùng');
    });
    test('TC_Register_15 empty password precedes strength check', () {
      form.passwordController.clear();
      expect(form.validate(), 'Chưa nhập mật khẩu');
      form.passwordController.text = 'weak';
      expect(form.validate(), startsWith('Mật khẩu quá yếu'));
    });
    test('invalid form never reaches registration HTTP call', () async {
      form.confirmPhoneController.clear();
      final messages = <String>[];
      expect(
        await form.register(
          onSnack: (message, {color}) => messages.add(message),
        ),
        isFalse,
      );
      expect(messages, ['Chưa nhập lại số điện thoại']);
      expect(form.loading, isFalse);
    });
  });

  group('Withdrawal feedback', () {
    String? validate({
      String amount = '100',
      num wallet = 100,
      String? bank = 'VCB',
      String? bankName = 'Vietcombank',
      String account = '123456',
      String name = 'NGUYEN VAN A',
    }) => validateWithdrawal(
      amountText: amount,
      currentWallet: wallet,
      bankCode: bank,
      bankName: bankName,
      accountNumber: account,
      accountName: name,
    );

    test('TC_Home_12 missing fields have explicit messages', () {
      expect(validate(amount: ''), 'Vui lòng nhập số tiền muốn rút');
      expect(validate(bank: null), 'Vui lòng chọn ngân hàng');
      expect(validate(bankName: ''), 'Vui lòng chọn ngân hàng');
      expect(validate(account: ' '), 'Vui lòng nhập số tài khoản');
      expect(validate(name: ' '), 'Vui lòng nhập tên chủ tài khoản');
    });
    test('rejects malformed, zero, negative, and fractional amounts', () {
      for (final amount in ['abc', '0', '-1', '1.5']) {
        expect(
          validate(amount: amount),
          'Số tiền rút phải là số nguyên lớn hơn 0',
        );
      }
      expect(validate(account: 'abc'), 'Số tài khoản chỉ được chứa chữ số');
    });
    test('TC_Home_15 balance boundary and formatted amounts', () {
      expect(validate(amount: '101'), 'Số dư ví không đủ để rút tiền');
      expect(validate(), isNull);
      expect(validate(amount: '1,000', wallet: 1000), isNull);
    });
    test(
      'withdrawal keeps server rejection message and financial command key',
      () async {
        await http.runWithClient(
          () async {
            final response = await ApiService.createWithdrawal(
              accessToken: 'fixture',
              amount: 100,
              bankCode: 'VCB',
              bankName: 'Vietcombank',
              accountNumber: '123456',
              accountName: 'QA',
            );
            expect(response.statusCode, 409);
            expect(apiErrorMessage(response, 'fallback'), 'Số dư ví không đủ');
          },
          () => MockClient((request) async {
            expect(request.url.path, '/api/withdrawalapi/create');
            expect(request.headers['Authorization'], 'Bearer fixture');
            expect(request.headers['Idempotency-Key'], isNotEmpty);
            expect(jsonDecode(request.body)['amount'], 100);
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'success': false,
                  'code': 'insufficient_wallet_balance',
                  'message': 'Số dư ví không đủ',
                }),
              ),
              409,
            );
          }),
        );
      },
    );
  });

  group('Order data', () {
    late OrderFormProvider form;
    setUp(() {
      form = OrderFormProvider();
      form.customerNameController.text = 'Khách QA';
    });
    tearDown(() => form.dispose());
    test('TC_CreateOrder_05 requires exactly 10 phone digits', () {
      form.phoneController.clear();
      expect(form.validate(), 'Vui lòng nhập số điện thoại khách');
      for (final phone in [
        '123',
        '123456789',
        'abcdefghij',
        '09123456789',
        '091234567890',
      ]) {
        form.phoneController.text = phone;
        expect(form.validate(), 'Số điện thoại khách phải gồm đúng 10 chữ số');
      }
      form.phoneController.text = '0912345678';
      expect(form.validate(), contains('điểm đón'));
    });
    test('TC_CreateOrder_11/13 time and complete request survive changes', () {
      form.phoneController.text = '0912345678';
      form.selectedFromPoint = RidePointPayload.placeId('from');
      form.selectedToPoint = RidePointPayload.placeId('to');
      form.fromAddressController.text = 'Nội Bài';
      form.toAddressController.text = 'Hà Nội';
      form.setPickupDate(DateTime(2026, 12, 20));
      form.setPickupTime(const TimeOfDay(hour: 9, minute: 5));
      form.offerPriceController.text = '200000';
      form.creatorEarnController.text = '180000';
      form.noteController.text = 'Hành lý';
      expect(form.validate(), isNull);
      expect(form.pickupTimeController.text, '09:05');
      expect(form.pickupDateController.text, '20/12/2026');
      final request = form.buildRequest(groupId: 7);
      form.setPickupTime(const TimeOfDay(hour: 10, minute: 15));
      expect(request.pickupTime, '2026-12-20T09:05:00');
      expect(request.fromDisplayAddress, 'Nội Bài');
      expect(request.toDisplayAddress, 'Hà Nội');
      expect(request.customerName, 'Khách QA');
      expect(request.customerPhone, '0912345678');
      expect(request.toJson(), containsPair('offerPrice', 200000));
      expect(request.toJson(), containsPair('creatorEarn', 180000));
      expect(request.toJson(), containsPair('note', 'Hành lý'));
      expect(request.toJson(), containsPair('groupId', 7));
    });
  });
}
