import 'dart:convert';

import 'package:beludriver_app/providers/driver/register_provider.dart';
import 'package:beludriver_app/screens/driver/driver_register_screen.dart';
import 'package:beludriver_app/ui/brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(theme: Brand.theme(), home: const RegisterScreen()),
    );
    await tester.pumpAndSettle();
  }

  RegisterProvider state(WidgetTester tester) =>
      tester.element(find.byType(TextField).first).read<RegisterProvider>();

  Future<void> enter(WidgetTester tester, String label, String value) async {
    await tester.ensureVisible(field(label));
    await tester.pumpAndSettle();
    await tester.enterText(field(label), value);
    await tester.pumpAndSettle();
  }

  Future<void> personal(WidgetTester tester) async {
    await enter(tester, 'Họ và tên', 'Driver Fixture');
    await enter(tester, 'Email', 'driver@example.invalid');
    await enter(tester, 'Biển số xe', '29A-123.45');
    await tester.ensureVisible(find.text('Miền Bắc'));
    await tester.tap(find.text('Miền Bắc'));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
  }

  Future<void> account(WidgetTester tester) async {
    await enter(tester, 'Số điện thoại', '0912345678');
    await enter(tester, 'Nhập lại số điện thoại', '0912345678');
    await enter(tester, 'Mật khẩu', 'Strong@123');
    await enter(tester, 'Nhập lại mật khẩu', 'Strong@123');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
  }

  Future<void> agree(WidgetTester tester) async {
    for (var index = 0; index < 2; index++) {
      final finder = find.byType(Checkbox).at(index);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Continue shows per-field errors, reveals first invalid input and retains data',
    (tester) async {
      await open(tester, size: const Size(320, 568));
      await enter(tester, 'Biển số xe', '29A-123.45');
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('Họ tên không được để trống'), findsOneWidget);
      expect(find.text('Email không hợp lệ'), findsOneWidget);
      expect(find.text('Vui lòng chọn miền hoạt động'), findsOneWidget);
      expect(field('Số điện thoại'), findsNothing);
      expect(state(tester).licenseNumberController.text, '29A-123.45');
      final rect = tester.getRect(field('Họ và tên'));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThan(568));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Next follows fields and keeps focused input plus Continue above keyboard on small screen',
    (tester) async {
      await open(tester, size: const Size(320, 568));
      await tester.tap(field('Họ và tên'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Email')).focusNode!.hasFocus,
        isTrue,
      );
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      final license = tester.widget<TextField>(field('Biển số xe'));
      expect(license.focusNode!.hasFocus, isTrue);
      expect(
        tester.getRect(field('Biển số xe')).bottom,
        lessThanOrEqualTo(318),
      );
      expect(
        tester.getRect(find.text('Tiếp tục')).bottom,
        lessThanOrEqualTo(318),
      );
      expect(license.textInputAction, TextInputAction.done);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(license.focusNode!.hasFocus, isFalse);
      expect(field('Số điện thoại'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account Continue validates every field and Back preserves previous details',
    (tester) async {
      await open(tester);
      await personal(tester);
      await enter(tester, 'Số điện thoại', '123');
      await enter(tester, 'Mật khẩu', 'weak');
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('Số điện thoại không hợp lệ'), findsOneWidget);
      expect(find.text('Chưa nhập lại số điện thoại'), findsOneWidget);
      expect(find.text('Chưa nhập lại mật khẩu'), findsOneWidget);
      expect(find.text('Gửi mã xác minh'), findsNothing);
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Email')).controller!.text,
        'driver@example.invalid',
      );
      expect(
        tester.widget<TextField>(field('Biển số xe')).controller!.text,
        '29A-123.45',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account keyboard Next crosses sections without hiding the focused field',
    (tester) async {
      await open(tester, size: const Size(320, 568));
      await personal(tester);
      await tester.tap(field('Số điện thoại'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      for (final label in [
        'Nhập lại số điện thoại',
        'Mật khẩu',
        'Nhập lại mật khẩu',
      ]) {
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(field(label)).focusNode!.hasFocus,
          isTrue,
        );
        expect(tester.getRect(field(label)).bottom, lessThanOrEqualTo(318));
      }
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(field('Số điện thoại'), findsOneWidget);
      expect(find.text('Gửi mã xác minh'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed challenge keeps confirmation step; missing terms never calls API',
    (tester) async {
      var requests = 0;
      await http.runWithClient(
        () async {
          await open(tester);
          await personal(tester);
          await account(tester);
          await tester.tap(find.text('Gửi mã xác minh'));
          await tester.pumpAndSettle();
          expect(requests, 0);
          expect(
            find.text('Bạn cần đồng ý với Điều khoản sử dụng'),
            findsOneWidget,
          );
          await agree(tester);
          await tester.tap(find.text('Gửi mã xác minh'));
          await tester.pumpAndSettle();
          expect(requests, 1);
          expect(find.text('Không gửi được mã.'), findsOneWidget);
          expect(field('Mã OTP email'), findsNothing);
          expect(find.text('Gửi mã xác minh'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          requests++;
          return http.Response.bytes(
            utf8.encode('{"message":"Không gửi được mã."}'),
            429,
          );
        }),
      );
    },
  );

  testWidgets(
    'challenge to OTP to multipart; invalid OTP stays editable; back retains form and invalidates changed identity',
    (tester) async {
      final requests = <String>[];
      await http.runWithClient(
        () async {
          await open(tester, size: const Size(320, 568));
          await personal(tester);
          await account(tester);
          await agree(tester);
          await tester.tap(find.text('Gửi mã xác minh'));
          await tester.pumpAndSettle();
          expect(field('Mã OTP email'), findsOneWidget);
          expect(
            find.text('Nhập mã OTP gửi tới d***@example.invalid.'),
            findsOneWidget,
          );
          final provider = state(tester);
          await tester.tap(find.text('Đăng ký'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TextField>(field('Mã OTP email'))
                .decoration!
                .errorText,
            'Vui lòng nhập mã OTP email',
          );
          expect(requests.length, 1);
          await enter(tester, 'Mã OTP email', '012345');
          await tester.tap(find.text('Đăng ký'));
          await tester.pumpAndSettle();
          expect(find.text('Mã OTP sai hoặc đã hết hạn.'), findsWidgets);
          expect(field('Mã OTP email'), findsOneWidget);
          expect(requests.length, 2);
          await tester.tap(find.text('Quay lại'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Quay lại'));
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(field('Số điện thoại')).controller!.text,
            '0912345678',
          );
          await enter(tester, 'Số điện thoại', '0912345679');
          expect(provider.challengeId, isNull);
          expect(provider.otpController.text, isEmpty);
          expect(provider.fullNameController.text, 'Driver Fixture');
          expect(tester.takeException(), isNull);
        },
        () => MockClient.streaming((request, body) async {
          requests.add(request.url.path);
          await body.drain<void>();
          if (request is http.MultipartRequest) {
            expect(request.fields['challengeId'], 'challenge-fixture');
            expect(request.fields['otp'], '012345');
            return http.StreamedResponse(
              Stream.value(
                utf8.encode('{"message":"Mã OTP sai hoặc đã hết hạn."}'),
              ),
              400,
            );
          }
          return http.StreamedResponse(
            Stream.value(utf8.encode('{"challengeId":"challenge-fixture"}')),
            200,
          );
        }),
      );
    },
  );
}
