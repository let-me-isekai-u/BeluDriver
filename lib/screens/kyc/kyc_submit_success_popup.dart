import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class KycSubmitSuccessPopup extends StatelessWidget {
  const KycSubmitSuccessPopup({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'lib/assets/animations/Thanks.json',
              height: 180,
              repeat: true,
            ),
            const SizedBox(height: 12),
            Text(
              'Cảm ơn bạn đã hoàn tất hồ sơ KYC',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Chúng tôi đã ghi nhận đầy đủ thông tin của bạn.\n'
                  'Tài khoản của bạn sẽ được xét duyệt chậm nhất trong vòng 3 ngày tới.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tôi đã hiểu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}