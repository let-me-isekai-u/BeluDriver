import 'package:beludriver_app/screens/driver/concert_ticket_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('concert ticket scanner screen renders entry actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ConcertTicketScannerScreen()),
    );

    expect(find.text('Quét QR vé concert'), findsOneWidget);
    expect(find.text('Quét QR'), findsOneWidget);
    expect(find.text('Nhập mã thủ công'), findsOneWidget);
    expect(find.text('Kiểm vé'), findsOneWidget);
  });
}
