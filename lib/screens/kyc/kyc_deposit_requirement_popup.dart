import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class KycDepositRequirementPopup extends StatelessWidget {
  final num amount;
  final VoidCallback? onConfirmed;

  const KycDepositRequirementPopup({
    super.key,
    required this.amount,
    this.onConfirmed,
  });

  String _formatCurrency(num value) {
    final formatter = NumberFormat("#,##0", "vi_VN");
    return "${formatter.format(value)}đ";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountText = _formatCurrency(amount);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4DB),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFFE6A100),
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Yêu cầu ký quỹ",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(
                    text:
                    "Để bắt đầu nhận chuyến, bạn cần nạp khoản ký quỹ tối thiểu ",
                  ),
                  TextSpan(
                    text: amountText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  const TextSpan(
                    text: " vào ví tài xế.",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFD8A8)),
              ),
              child: const Text(
                "Khoản ký quỹ này là điều kiện để tài khoản có thể bắt đầu hoạt động và nhận chuyến trên hệ thống.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7A5600),
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  onConfirmed?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.secondary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Tôi đã hiểu",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}