README - Tiếng Việt

Thư mục `screens` chứa UI chính của app và các màn hình cấp cao.

File cấp gốc:
- `change_password_screen.dart`: đổi mật khẩu cho tài khoản.
- `forgot_password_screen.dart`: quên mật khẩu, gửi OTP và đặt lại mật khẩu.
- `splash_screen.dart`: kiểm tra token, refresh token, điều hướng login/home.
- `terms_screen.dart`: màn hình điều khoản / sử dụng.

Thư mục con:
- `chat_to_order/`: các màn hình chat và liên kết với đơn đẩy.
- `driver/`: bộ màn hình nghiệp vụ chính của tài xế.
- `face_detection/`: các màn hình chụp / xác thực khuôn mặt.
- `kyc/`: popup và bước KYC.
- `popup_list/`: các popup thông báo dùng lại ở nhiều nơi.
- `register_route/`: popup đăng ký tuyến.

README - English

The `screens` folder contains the main app UI and higher-level screens.

Top-level files:
- `change_password_screen.dart`: change-password screen.
- `forgot_password_screen.dart`: forgot-password screen with OTP and reset flow.
- `splash_screen.dart`: token check, token refresh, and login/home navigation.
- `terms_screen.dart`: terms and usage screen.

Subfolders:
- `chat_to_order/`: chat-related screens tied to pushed rides.
- `driver/`: main driver business screens.
- `face_detection/`: face capture and verification screens.
- `kyc/`: KYC popups and steps.
- `popup_list/`: reusable popup screens.
- `register_route/`: route registration popup.
