import 'package:beludriver_app/models/broker_ride_models.dart';
import 'package:beludriver_app/models/location_models.dart';
import 'package:beludriver_app/providers/broker/order_form_provider.dart';
import 'package:beludriver_app/screens/driver/concert_ticket_scanner_screen.dart';
import 'package:beludriver_app/screens/driver/driver_booking_confirm.dart';
import 'package:beludriver_app/screens/driver/driver_booking_screen.dart';
import 'package:beludriver_app/screens/driver/driver_home.dart';
import 'package:beludriver_app/screens/driver/driver_register_screen.dart';
import 'package:beludriver_app/screens/chat_to_order/chat_group_list_screen.dart';
import 'package:beludriver_app/ui/brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class _CameraPlatform extends MobileScannerPlatform {
  int starts = 0;
  int stops = 0;
  int disposals = 0;
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(390, 844),
    );
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });
  Future<void> show(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: Brand.theme(), home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('TC_Register_01 visible header and working back', (tester) async {
    await show(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
            ),
            child: const Text('Mở đăng ký'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở đăng ký'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Đăng ký tài khoản')).style?.color,
      Brand.ink,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton &&
                  widget.tooltip == 'Quay lại đăng nhập',
            ),
          )
          .color,
      Brand.navy,
    );
    await tester.tap(find.byTooltip('Quay lại đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Mở đăng ký'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TC_Home_03 ticket page has visible title and back', (
    tester,
  ) async {
    await show(tester, const ConcertTicketScannerScreen());
    expect(
      tester.widget<Text>(find.text('Quét QR vé concert')).style?.color,
      Colors.white,
    );
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Kiểm vé lên xe'), findsOneWidget);
    await tester.tap(find.text('Kiểm vé'));
    await tester.pump();
    expect(
      find.text('Vui lòng quét hoặc nhập mã QR vé concert.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TC_Home_05 close is at top and stops camera', (tester) async {
    final original = MobileScannerPlatform.instance;
    final camera = _CameraPlatform();
    MobileScannerPlatform.instance = camera;
    addTearDown(() => MobileScannerPlatform.instance = original);
    await show(tester, const ConcertTicketScannerScreen());
    await tester.tap(find.text('Quét QR'));
    await tester.pumpAndSettle();
    expect(camera.starts, greaterThan(0));
    final scanner = tester.state(find.byType(MobileScanner));
    expect(scanner.mounted, isTrue);
    expect(tester.getTopLeft(find.byTooltip('Đóng camera')).dy, lessThan(100));
    await tester.tap(find.byTooltip('Đóng camera'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();
    expect(find.text('Kiểm vé lên xe'), findsOneWidget);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    expect(camera.stops, greaterThan(0));
    expect(scanner.mounted, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TC_Home_07 chat back returns to caller', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await show(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DriverChatGroupListScreen(),
              ),
            ),
            child: const Text('Trang chủ'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<BackButton>(find.byType(BackButton)).color,
      Colors.white,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TC_Home_12/15 invalid withdrawals show feedback without POST', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await http.runWithClient(
      () async {
        await show(
          tester,
          const Scaffold(
            body: WithdrawDialogContent(currentWallet: 100, driverId: 1),
          ),
        );
        await tester.tap(find.text('Gửi yêu cầu rút tiền'));
        await tester.pumpAndSettle();
        expect(find.text('Vui lòng nhập số tiền muốn rút'), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, '101');
        await tester.tap(find.text('Gửi yêu cầu rút tiền'));
        await tester.pumpAndSettle();
        expect(find.text('Số dư ví không đủ để rút tiền'), findsOneWidget);
        expect(requests.where((request) => request.method == 'POST'), isEmpty);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        requests.add(request);
        return http.Response('{"code":"00","data":[]}', 200);
      }),
    );
  });

  testWidgets('TC_CreateOrder_10/11 date and time selections remain visible', (
    tester,
  ) async {
    await show(tester, const DriverBookingScreen());
    final context = tester.element(find.text('Đẩy đơn'));
    final form = context.read<OrderFormProvider>();
    final futureDate = DateTime.now().add(const Duration(days: 2));
    form.setPickupDate(futureDate);
    form.setPickupTime(const TimeOfDay(hour: 9, minute: 5));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, '09:05'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '09:05'))
          .style
          ?.color,
      Brand.ink,
    );
    await tester.ensureVisible(find.widgetWithText(TextField, '09:05'));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .ancestor(
            of: find.widgetWithText(TextField, '09:05'),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    expect(form.pickupTimeController.text, '09:05');
    await tester.ensureVisible(
      find.widgetWithText(TextField, form.formatDate(futureDate)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .ancestor(
            of: find.widgetWithText(TextField, form.formatDate(futureDate)),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(form.pickupDateController.text, form.formatDate(futureDate));
  });

  testWidgets('TC_CreateOrder_13 displays complete trip with readable values', (
    tester,
  ) async {
    final request = CreateBrokerRideRequest(
      from: RidePointPayload.placeId('from'),
      to: RidePointPayload.placeId('to'),
      fromDisplayAddress: 'Nội Bài',
      toDisplayAddress: 'Hà Nội',
      type: BrokerRideType.passenger,
      customerName: 'Khách QA',
      customerPhone: '0912345678',
      quantity: 2,
      pickupTime: '2026-12-20T09:05:00',
      offerPrice: 200000,
      creatorEarn: 180000,
      note: 'Hành lý',
      groupId: 7,
    );
    await show(tester, DriverBookingConfirmScreen(request: request));
    for (final value in [
      'Chở người',
      '2',
      'Khách QA',
      '0912345678',
      'Hành lý',
      '20/12/2026 - 09:05',
      'Nội Bài',
      'Hà Nội',
    ]) {
      expect(find.text(value), findsOneWidget);
      expect(tester.widget<Text>(find.text(value)).style?.color, Brand.ink);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('TC_CreateOrder_06/07 dropdown and suggestions keep selections', (
    tester,
  ) async {
    await show(tester, const DriverBookingScreen());
    final form = tester.element(find.text('Đẩy đơn')).read<OrderFormProvider>();
    await tester.scrollUntilVisible(
      find.byType(DropdownButtonFormField<int>),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bao xe 7 chỗ').last);
    await tester.pumpAndSettle();
    expect(form.selectedType, BrokerRideType.charter7Seats);
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .decoration
          .labelText,
      'Loại chuyến',
    );
    form.fromSuggestions = [
      TrackAsiaAutocompleteSuggestion.fromJson({
        'placeId': 'airport',
        'name': 'Sân bay QA',
        'address': 'Sóc Sơn',
      }),
    ];
    form.setPickupTime(const TimeOfDay(hour: 9, minute: 5));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sân bay QA'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.widget<Text>(find.text('Sân bay QA')).style?.color,
      Brand.ink,
    );
    await tester.tap(find.text('Sân bay QA'));
    await tester.pumpAndSettle();
    expect(form.selectedFromPoint?.placeId, 'airport');
    expect(form.fromAddressController.text, 'Sân bay QA, Sóc Sơn');
    expect(tester.takeException(), isNull);
  });
}
