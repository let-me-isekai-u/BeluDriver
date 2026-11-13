import 'dart:async';
import 'dart:convert';

import 'package:beludriver_app/providers/driver/register_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

RegisterProvider validRegistration() => RegisterProvider()
  ..fullNameController.text = 'Driver Fixture'
  ..emailController.text = 'driver@example.invalid'
  ..licenseNumberController.text = '29A-123.45'
  ..selectedRegion = 1
  ..phoneController.text = '0912345678'
  ..confirmPhoneController.text = '0912345678'
  ..passwordController.text = 'Strong@123'
  ..confirmPasswordController.text = 'Strong@123'
  ..agreeTerms = true
  ..agreeCamera = true;

http.StreamedResponse reply(Object body, [int status = 200]) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RegisterProvider form;
  final messages = <String>[];
  setUp(() {
    form = validRegistration();
    messages.clear();
  });
  tearDown(() => form.dispose());
  Future<bool> submit() =>
      form.register(onSnack: (message, {color}) => messages.add(message));

  test('step validation shares final rules and preserves entered data', () {
    form.emailController.text = 'invalid';
    form.licenseNumberController.clear();
    form.selectedRegion = null;
    expect(form.validateStep(0), isFalse);
    expect(
      form.fieldErrors.keys,
      containsAll([
        RegistrationField.email,
        RegistrationField.licenseNumber,
        RegistrationField.region,
      ]),
    );
    expect(form.validate(), 'Email không hợp lệ');
    expect(form.fullNameController.text, 'Driver Fixture');
    form.emailController.text = 'fixed@example.invalid';
    form.fieldChanged(RegistrationField.email);
    expect(form.fieldErrors.containsKey(RegistrationField.email), isFalse);
    expect(
      form.fieldErrors.containsKey(RegistrationField.licenseNumber),
      isTrue,
    );
  });

  test(
    'account step rejects mismatches and weak passwords before confirmation',
    () {
      form.confirmPhoneController.clear();
      form.passwordController.text = 'weak';
      form.confirmPasswordController.clear();
      expect(form.validateStep(1), isFalse);
      expect(
        form.fieldErrors[RegistrationField.confirmPhone],
        'Chưa nhập lại số điện thoại',
      );
      expect(
        form.fieldErrors[RegistrationField.password],
        startsWith('Mật khẩu quá yếu'),
      );
      expect(
        form.fieldErrors[RegistrationField.confirmPassword],
        'Chưa nhập lại mật khẩu',
      );
    },
  );

  test(
    'challenge uses driver owner, register purpose and validated identity',
    () async {
      await http.runWithClient(
        () async {
          expect(await form.requestRegistrationChallenge(), isTrue);
          expect(form.challengeId, 'challenge-one');
          expect(form.hasMatchingChallenge, isTrue);
        },
        () => MockClient.streaming((request, stream) async {
          expect(request.url.path, '/api/identity/challenges');
          expect(request.method, 'POST');
          expect(jsonDecode(await stream.bytesToString()), {
            'ownerType': 2,
            'purpose': 'register',
            'email': 'driver@example.invalid',
            'phone': '0912345678',
          });
          return reply({'challengeId': 'challenge-one'});
        }),
      );
    },
  );

  for (final body in [
    <String, Object?>{},
    {'challengeId': ''},
    {'challengeId': ' '},
    {'challengeId': 42},
    {
      'data': {'challengeId': 'nested'},
    },
  ]) {
    test('rejects missing or incompatible challenge schema: $body', () async {
      await http.runWithClient(() async {
        expect(await form.requestRegistrationChallenge(), isFalse);
        expect(form.challengeId, isNull);
        expect(form.apiError, isNotEmpty);
      }, () => MockClient.streaming((_, _) async => reply(body)));
    });
  }

  for (final status in [400, 429, 503]) {
    test('challenge error $status never activates verification', () async {
      await http.runWithClient(
        () async {
          expect(await form.requestRegistrationChallenge(), isFalse);
          expect(form.hasMatchingChallenge, isFalse);
          expect(form.apiError, 'Không thể gửi mã.');
          expect(form.loading, isFalse);
        },
        () => MockClient.streaming(
          (_, _) async => reply({'message': 'Không thể gửi mã.'}, status),
        ),
      );
    });
  }

  test('challenge double tap sends only one request', () async {
    final gate = Completer<void>();
    var calls = 0;
    await http.runWithClient(
      () async {
        final pending = form.requestRegistrationChallenge();
        expect(form.loading, isTrue);
        expect(await form.requestRegistrationChallenge(), isFalse);
        gate.complete();
        expect(await pending, isTrue);
        expect(calls, 1);
      },
      () => MockClient.streaming((_, _) async {
        calls++;
        await gate.future;
        return reply({'challengeId': 'one'});
      }),
    );
  });

  test(
    'editing identity while challenge pending discards even a changed-back identity',
    () async {
      final gate = Completer<void>();
      await http.runWithClient(
        () async {
          final pending = form.requestRegistrationChallenge();
          form.phoneController.text = '0912345679';
          form.phoneController.text = '0912345678';
          gate.complete();
          expect(await pending, isFalse);
          expect(form.challengeId, isNull);
          expect(form.apiError, contains('đã thay đổi'));
        },
        () => MockClient.streaming((_, _) async {
          await gate.future;
          return reply({'challengeId': 'old'});
        }),
      );
    },
  );

  test(
    'email or phone edits invalidate challenge and clear OTP, preserving other fields',
    () async {
      await http.runWithClient(
        () async {
          for (final controller in [
            form.emailController,
            form.phoneController,
          ]) {
            expect(await form.requestRegistrationChallenge(), isTrue);
            form.otpController.text = '012345';
            controller.text = '${controller.text}x';
            expect(form.challengeId, isNull);
            expect(form.otpController.text, isEmpty);
            expect(form.fullNameController.text, 'Driver Fixture');
            expect(form.licenseNumberController.text, '29A-123.45');
            controller.text = controller == form.emailController
                ? 'driver@example.invalid'
                : '0912345678';
          }
        },
        () =>
            MockClient.streaming((_, _) async => reply({'challengeId': 'one'})),
      );
    },
  );

  test('missing challenge or invalid OTP never sends registration', () async {
    var registrations = 0;
    await http.runWithClient(
      () async {
        expect(await submit(), isFalse);
        expect(await form.requestRegistrationChallenge(), isTrue);
        for (final otp in ['', '12345', '1234567', 'abcdef']) {
          form.otpController.text = otp;
          expect(await submit(), isFalse);
          expect(form.fieldErrors[RegistrationField.otp], isNotEmpty);
        }
        expect(registrations, 0);
      },
      () => MockClient.streaming((request, _) async {
        if (request is http.MultipartRequest) registrations++;
        return reply({'challengeId': 'one'});
      }),
    );
  });

  test(
    'multipart contains every original field and identity-matched challenge/OTP',
    () async {
      Map<String, String>? fields;
      await http.runWithClient(
        () async {
          expect(await form.requestRegistrationChallenge(), isTrue);
          form.otpController.text = '012345';
          expect(await submit(), isTrue);
          expect(fields, {
            'fullName': 'Driver Fixture',
            'phone': '0912345678',
            'email': 'driver@example.invalid',
            'password': 'Strong@123',
            'licenseNumber': '29A-123.45',
            'region': '1',
            'challengeId': 'one',
            'otp': '012345',
          });
        },
        () => MockClient.streaming((request, _) async {
          if (request is http.MultipartRequest) {
            expect(
              request.url.path,
              '/api/accountdriverapi/driver-register-ver2',
            );
            fields = Map.of(request.fields);
            return reply({'success': true}, 201);
          }
          return reply({'challengeId': 'one'});
        }),
      );
    },
  );

  test(
    'resend replaces challenge, clears OTP, and uses no invented cooldown',
    () async {
      var sent = 0;
      await http.runWithClient(
        () async {
          expect(await form.requestRegistrationChallenge(), isTrue);
          form.otpController.text = '012345';
          expect(await form.requestRegistrationChallenge(), isTrue);
          expect(form.challengeId, 'challenge-2');
          expect(form.otpController.text, isEmpty);
        },
        () => MockClient.streaming(
          (_, _) async => reply({'challengeId': 'challenge-${++sent}'}),
        ),
      );
    },
  );

  test('failed resend cannot reuse the previous challenge', () async {
    var sent = 0;
    await http.runWithClient(
      () async {
        expect(await form.requestRegistrationChallenge(), isTrue);
        form.otpController.text = '012345';
        expect(await form.requestRegistrationChallenge(), isFalse);
        expect(form.challengeId, isNull);
        expect(await submit(), isFalse);
      },
      () => MockClient.streaming(
        (_, _) async => ++sent == 1
            ? reply({'challengeId': 'one'})
            : reply({'message': 'Yêu cầu quá nhiều.'}, 429),
      ),
    );
  });

  test('final registration revalidates all data', () async {
    var registrations = 0;
    await http.runWithClient(
      () async {
        expect(await form.requestRegistrationChallenge(), isTrue);
        form.otpController.text = '012345';
        form.fullNameController.clear();
        expect(await submit(), isFalse);
        expect(form.firstInvalidField, RegistrationField.fullName);
        expect(registrations, 0);
      },
      () => MockClient.streaming((request, _) async {
        if (request is http.MultipartRequest) registrations++;
        return reply({'challengeId': 'one'});
      }),
    );
  });

  test(
    'wrong or expired OTP is shown and allows explicit correction',
    () async {
      await http.runWithClient(
        () async {
          expect(await form.requestRegistrationChallenge(), isTrue);
          form.otpController.text = '012345';
          expect(await submit(), isFalse);
          expect(messages.last, 'Mã OTP sai hoặc đã hết hạn.');
          expect(form.canSubmit, isTrue);
          expect(form.challengeId, 'one');
        },
        () => MockClient.streaming(
          (request, _) async => request is http.MultipartRequest
              ? reply({'message': 'Mã OTP sai hoặc đã hết hạn.'}, 400)
              : reply({'challengeId': 'one'}),
        ),
      );
    },
  );

  test(
    'double submit and repeated submit after success create only one account request',
    () async {
      final gate = Completer<void>();
      var registrations = 0;
      await http.runWithClient(
        () async {
          expect(await form.requestRegistrationChallenge(), isTrue);
          form.otpController.text = '012345';
          final pending = submit();
          expect(await submit(), isFalse);
          gate.complete();
          expect(await pending, isTrue);
          expect(await submit(), isFalse);
          expect(registrations, 1);
        },
        () => MockClient.streaming((request, _) async {
          if (request is http.MultipartRequest) {
            registrations++;
            await gate.future;
            return reply({'success': true}, 201);
          }
          return reply({'challengeId': 'one'});
        }),
      );
    },
  );

  test(
    'unknown registration outcome disables retries without automatically creating account again',
    () async {
      var registrations = 0;
      await http.runWithClient(
        () async {
          expect(await form.requestRegistrationChallenge(), isTrue);
          form.otpController.text = '012345';
          expect(await submit(), isFalse);
          expect(form.registrationOutcomeUnknown, isTrue);
          expect(form.loading, isFalse);
          expect(await submit(), isFalse);
          expect(registrations, 1);
        },
        () => MockClient.streaming((request, _) async {
          if (request is http.MultipartRequest) {
            registrations++;
            throw TimeoutException('fixture');
          }
          return reply({'challengeId': 'one'});
        }),
      );
    },
  );
}
