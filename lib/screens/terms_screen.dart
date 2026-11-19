import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Điều khoản sử dụng"),
        centerTitle: true,
        automaticallyImplyLeading: true,

      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: const Text(
                  """
🧾 ĐIỀU KHOẢN SỬ DỤNG ỨNG DỤNG BELUCAR

1. Giới thiệu
Belucar là nền tảng kết nối người dùng với tài xế để đặt các chuyến xe cá nhân hoặc vận chuyển. 
Mục tiêu là cung cấp dịch vụ nhanh chóng, minh bạch và an toàn.

Bằng việc cài đặt và sử dụng ứng dụng, bạn đồng ý tuân thủ tất cả các điều khoản dưới đây.

2. Tài khoản người dùng
Người dùng phải cung cấp thông tin chính xác và hợp lệ khi đăng ký.
Bạn chịu trách nhiệm bảo mật thông tin đăng nhập.
Belucar có quyền từ chối hoặc khóa tài khoản nếu phát hiện gian lận hoặc thông tin sai lệch.

3. Đặt chuyến và thanh toán
Người dùng có thể tạo chuyến đi và xem chi phí dự kiến.
Thanh toán được thực hiện qua ví điện tử hoặc các phương thức do ứng dụng cung cấp.
Chính sách huỷ chuyến chỉ áp dụng cho những chuyến chưa có tài xế nhận (trạng thái 1).

4. Huỷ chuyến
Người dùng chỉ có thể huỷ chuyến ở trạng thái chưa có tài xế nhận.
Belucar có quyền từ chối huỷ chuyến nếu vi phạm các điều kiện của dịch vụ.

5. Trách nhiệm
Belucar chỉ là nền tảng kết nối, không trực tiếp vận chuyển hành khách.
Mọi sự cố, trễ giờ hoặc mất mát phát sinh trong chuyến đi được xử lý theo quy định của tài xế hoặc đối tác liên quan.
Ứng dụng không chịu trách nhiệm cho những thiệt hại do thông tin sai lệch của người dùng.

6. Thay đổi và chấm dứt dịch vụ
Belucar có quyền điều chỉnh hoặc tạm ngừng dịch vụ mà không cần báo trước.
Các thay đổi về điều khoản sẽ được thông báo trong ứng dụng; việc tiếp tục sử dụng được xem là đồng ý với các thay đổi đó.

7. Hỗ trợ
Mọi thắc mắc hoặc cần hỗ trợ, vui lòng liên hệ: 
Số điện thoại: 0878 861 324
Email: hotro@datxedongduong.com
                  """,
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Xác nhận", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
