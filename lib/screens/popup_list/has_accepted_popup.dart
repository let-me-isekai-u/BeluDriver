//Popup hiện thông báo nếu đơn đã có tài xế nhận
import 'package:flutter/material.dart';

class HasAcceptedPopup extends StatelessWidget {
  const HasAcceptedPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange),
          SizedBox(width: 8),
          Text('Thông báo'),
        ],
      ),
      content: const Text(
        'Đơn hàng này đã có tài xế khác nhận, bạn không thể thực hiện thao tác này nữa. Xin cám ơn!',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Đóng popup
          },
          child: const Text('Đã hiểu'),
        ),
      ],
    );
  }

  // Hàm tiện ích để gọi nhanh
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const HasAcceptedPopup(),
    );
  }
}