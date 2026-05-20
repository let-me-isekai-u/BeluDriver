README - Tiếng Việt

Thư mục `providers` chứa state management theo `ChangeNotifier`.

File cấp gốc:
- `chat_group_list_provider.dart`: provider cho danh sách nhóm chat.
- `chat_provider.dart`: provider cho màn hình chat nhóm.
- `home_provider.dart`: provider tổng hợp cho màn hình home của tài xế.
- `received_order_provider.dart`: provider cho màn hình nhận đơn.

Thư mục con:
- `broker/`: provider cho luồng đẩy đơn / tạo đơn.
- `driver/`: provider riêng cho các màn hình driver.
- `kyc/`: provider cho KYC và face detection.
- `routes/`: provider cho đăng ký tuyến.

README - English

The `providers` folder contains `ChangeNotifier`-based state management.

Top-level files:
- `chat_group_list_provider.dart`: provider for the chat group list.
- `chat_provider.dart`: provider for the group chat screen.
- `home_provider.dart`: aggregated provider for the driver home screen.
- `received_order_provider.dart`: provider for the receive-order screen.

Subfolders:
- `broker/`: providers for pushed-ride creation flows.
- `driver/`: providers dedicated to driver screens.
- `kyc/`: providers for KYC and face detection.
- `routes/`: providers for route registration.
