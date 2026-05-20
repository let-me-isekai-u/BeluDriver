README - Tiếng Việt

Thư mục `services` chứa các lớp giao tiếp bên ngoài và xử lý hệ thống.

Ý nghĩa các file:
- `api_chat_service.dart`: gọi API cho chat.
- `api_service.dart`: gọi API tổng hợp cho driver, wallet, route, ride, auth.
- `beludriver_signalr_http_client.dart`: HTTP client phụ trợ SignalR.
- `firebase_notification_service.dart`: xử lý push notification Firebase.
- `kyc_service.dart`: gọi API / phụ trợ riêng cho KYC.
- `permission_service.dart`: xin quyền hệ thống.
- `signalr_service.dart`: kết nối realtime SignalR.

Thư mục con:
- `v2/`: phiên bản `api_service` khác, đang tồn tại song song.

README - English

The `services` folder contains external integrations and system-level helpers.

File purposes:
- `api_chat_service.dart`: chat API calls.
- `api_service.dart`: main API service for driver, wallet, route, ride, and auth flows.
- `beludriver_signalr_http_client.dart`: helper HTTP client for SignalR.
- `firebase_notification_service.dart`: Firebase push notification handling.
- `kyc_service.dart`: dedicated API/service support for KYC.
- `permission_service.dart`: system permission helper.
- `signalr_service.dart`: realtime SignalR connection layer.

Subfolder:
- `v2/`: alternate version of `api_service`, still present in parallel.
