import 'package:flutter/material.dart';

class ResubmitKycNotification extends StatelessWidget {
  final String? rejectReason;
  final VoidCallback? onConfirmed;

  const ResubmitKycNotification({
    super.key,
    this.rejectReason,
    this.onConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String reason =
    (rejectReason != null && rejectReason!.trim().isNotEmpty)
        ? rejectReason!.trim()
        : "Hồ sơ KYC của bạn cần được cập nhật và gửi lại. Vui lòng kiểm tra lại thông tin và hình ảnh đã tải lên.";

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
                color: Colors.orange.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "KYC cần bổ sung",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Hồ sơ xác minh của bạn chưa được duyệt. Vui lòng kiểm tra lý do bên dưới và cập nhật lại hồ sơ.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFFD28D),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Lý do cần chỉnh sửa",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9A5B00),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B4A00),
                      height: 1.45,
                    ),
                  ),
                ],
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
                  "Xác nhận",
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