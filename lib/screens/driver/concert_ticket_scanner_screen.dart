import 'package:beludriver_app/services/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app_theme.dart';
import '../../models/concert_ticket_verification_model.dart';
import '../../services/concert_ticket_service.dart';
import '../../ui/ui.dart';

class ConcertTicketScannerScreen extends StatefulWidget {
  const ConcertTicketScannerScreen({super.key});

  @override
  State<ConcertTicketScannerScreen> createState() =>
      _ConcertTicketScannerScreenState();
}

class _ConcertTicketScannerScreenState
    extends State<ConcertTicketScannerScreen> {
  final TextEditingController _codeController = TextEditingController();
  final ConcertTicketService _service = const ConcertTicketService();
  ConcertTicketVerification? _result;
  bool _checking = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _openScanner() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ConcertQrScannerPage()),
    );
    if (!mounted || code == null || code.trim().isEmpty) return;
    _codeController.text = code.trim();
    await _verify(code);
  }

  Future<void> _verify([String? rawCode]) async {
    final qrPayload = (rawCode ?? _codeController.text).trim();
    if (qrPayload.isEmpty) {
      _showMessage('Vui lòng quét hoặc nhập mã QR vé concert.');
      return;
    }

    final accessToken = (await TokenStorage.instance.readAccessToken()) ?? '';
    if (!mounted) return;
    if (accessToken.isEmpty) {
      _showMessage('Không tìm thấy phiên đăng nhập tài xế.');
      return;
    }

    setState(() => _checking = true);
    final result = await _service.checkInTicket(
      accessToken: accessToken,
      qrPayload: qrPayload,
    );
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = result;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Brand.navy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F0DA),
      appBar: AppBar(
        title: const Text(
          'Quét QR vé concert',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Brand.navy,
        foregroundColor: Colors.white,
        leading: BackButton(
          color: Colors.white,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _HeaderCard(onScan: _checking ? null : _openScanner),
            const SizedBox(height: 18),
            _ManualInputCard(
              controller: _codeController,
              checking: _checking,
              onVerify: () => _verify(),
            ),
            const SizedBox(height: 18),
            if (_checking)
              const _CheckingCard()
            else if (_result != null)
              _VerificationResultCard(result: _result!),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.onScan});

  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Brand.navy),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.qr_code_scanner_rounded,
            color: Brand.navy,
            size: 42,
          ),
          const SizedBox(height: 14),
          const Text(
            'Kiểm vé lên xe',
            style: TextStyle(
              color: Brand.navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Quét mã QR trên vé của khách.',
            style: TextStyle(color: Brand.navy, height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.center_focus_strong_rounded),
              label: const Text('Quét QR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Brand.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualInputCard extends StatelessWidget {
  const _ManualInputCard({
    required this.controller,
    required this.checking,
    required this.onVerify,
  });

  final TextEditingController controller;
  final bool checking;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nhập mã thủ công',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'Dán toàn bộ chuỗi QR',
              hintStyle: TextStyle(color: Brand.inkMuted),
              prefixIcon: const Icon(
                Icons.confirmation_num,
                color: Colors.black,
              ),
              filled: true,
              fillColor: const Color(0xFFFFF8E7),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.black),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.black, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: checking ? null : onVerify,
              icon: const Icon(Icons.fact_check_rounded),
              label: const Text('Kiểm vé'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Brand.navy,
                side: const BorderSide(color: Brand.navy),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckingCard extends StatelessWidget {
  const _CheckingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Brand.navy),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Brand.navy,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Đang kiểm tra vé...',
              style: TextStyle(color: Brand.navy, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationResultCard extends StatelessWidget {
  const _VerificationResultCard({required this.result});

  final ConcertTicketVerification result;

  @override
  Widget build(BuildContext context) {
    final borderColor = result.isValid ? Brand.navy : Colors.black;
    final resultColor = result.isValid ? Brand.success : Brand.danger;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.isValid
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: resultColor,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.isValid ? 'Vé hợp lệ' : 'Vé không hợp lệ',
                  style: TextStyle(
                    color: resultColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.message,
            style: TextStyle(
              color: resultColor,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _ResultLine(
            label: 'Mã vé',
            value: result.ticketCode,
            isValid: result.isValid,
          ),
          _ResultLine(
            label: 'Mã đơn',
            value: result.orderCode,
            isValid: result.isValid,
          ),
          _ResultLine(
            label: 'Khách',
            value: result.customerName,
            isValid: result.isValid,
          ),
          _ResultLine(
            label: 'Số điện thoại',
            value: result.customerPhone,
            isValid: result.isValid,
          ),
          _ResultLine(
            label: 'Hành trình',
            value: result.directionLabel,
            isValid: result.isValid,
          ),
          _ResultLine(
            label: 'Lượt xe',
            value: result.serviceName,
            isValid: result.isValid,
          ),
          _ResultLine(
            label: 'Tuyến',
            value: result.routeName,
            isValid: result.isValid,
          ),
          _ResultLine(
            label: 'Điểm đón/trả',
            value: result.stopName,
            isValid: result.isValid,
          ),
          _ResultLine(
            label: 'Loại vé',
            value: result.vehicleTypeName,
            isValid: result.isValid,
          ),
          _ResultLine(
            label: 'Số khách còn lại',
            value: result.remainingGuests?.toString(),
            isValid: result.isValid,
          ),
          _ResultLine(
            label: 'Mã kết quả',
            value: result.resultCode,
            isValid: result.isValid,
          ),
          _ResultLine(
            label: 'Thời điểm dùng',
            value: result.usedAt,
            isValid: result.isValid,
          ),
        ],
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({
    required this.label,
    required this.value,
    required this.isValid,
  });

  final String label;
  final String? value;
  final bool isValid;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    final textColor = isValid ? Brand.navy : Colors.black;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConcertQrScannerPage extends StatefulWidget {
  const _ConcertQrScannerPage();

  @override
  State<_ConcertQrScannerPage> createState() => _ConcertQrScannerPageState();
}

class _ConcertQrScannerPageState extends State<_ConcertQrScannerPage> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            // Internal controller owns camera start/stop/dispose, including app lifecycle.
            useAppLifecycleState: true,
            onDetect: (capture) {
              if (_scanned) return;
              final code = capture.barcodes.firstOrNull?.rawValue;
              if (!mounted || code == null || code.trim().isEmpty) return;
              _scanned = true;
              Navigator.of(context).pop(code.trim());
            },
          ),
          IgnorePointer(
            child: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      backgroundColor: Brand.navy,
                      child: IconButton(
                        tooltip: "Đóng camera",
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const CircleAvatar(
                      backgroundColor: Brand.navy,
                      child: Icon(Icons.qr_code_scanner, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 108,
            left: 28,
            right: 28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Brand.navy,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.confirmation_num, color: Colors.white),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Đưa QR vé concert vào giữa khung',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(painter: _ConcertScannerFramePainter()),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 126,
            child: Text(
              'Mã được kiểm tra trực tuyến',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Positioned(
            left: 36,
            right: 36,
            bottom: 40,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.keyboard),
              label: const Text('Nhập mã thủ công'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Brand.navy,
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConcertScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frameSize = size.width * 0.78;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2.28),
      width: frameSize,
      height: frameSize * 1.18,
    );
    final corner = Paint()
      ..color = Brand.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const length = 64.0;
    for (final points in [
      [
        rect.topLeft,
        Offset(rect.left + length, rect.top),
        Offset(rect.left, rect.top + length),
      ],
      [
        rect.topRight,
        Offset(rect.right - length, rect.top),
        Offset(rect.right, rect.top + length),
      ],
      [
        rect.bottomLeft,
        Offset(rect.left + length, rect.bottom),
        Offset(rect.left, rect.bottom - length),
      ],
      [
        rect.bottomRight,
        Offset(rect.right - length, rect.bottom),
        Offset(rect.right, rect.bottom - length),
      ],
    ]) {
      canvas.drawLine(points[0], points[1], corner);
      canvas.drawLine(points[0], points[2], corner);
    }
    final line = Paint()
      ..color = Brand.navy.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
