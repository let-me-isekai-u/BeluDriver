README - Tiếng Việt

Thư mục `models` chứa các model parse response API và đối tượng trung gian trong app.

File cấp gốc:
- `broker_ride_models.dart`: model cho luồng tạo / quản lý đơn đẩy.
- `driver_chat_broker_ride_meta_model.dart`: metadata đơn đẩy hiển thị trong chat.
- `driver_chat_message_model.dart`: model tin nhắn chat.
- `driver_chat_message_page.dart`: model phân trang tin nhắn chat.
- `driver_onboarding_status_dto.dart`: trạng thái onboarding / KYC / route của tài xế.
- `paged_response_model.dart`: model phân trang dùng chung.
- `waiting_ride_model.dart`: model cho danh sách đơn đang chờ nhận.

Thư mục con:
- `KYC/`: model cho KYC.
- `driver/`: model liên quan driver, chuyến xe, ví, lịch sử rút.
- `routes/`: model liên quan đăng ký tuyến.

README - English

The `models` folder contains API response models and intermediate objects used by the app.

Top-level files:
- `broker_ride_models.dart`: models for creating and managing pushed rides.
- `driver_chat_broker_ride_meta_model.dart`: pushed-ride metadata shown in chat.
- `driver_chat_message_model.dart`: chat message model.
- `driver_chat_message_page.dart`: paged chat message model.
- `driver_onboarding_status_dto.dart`: driver onboarding / KYC / route status DTO.
- `paged_response_model.dart`: shared pagination model.
- `waiting_ride_model.dart`: model for waiting rides.

Subfolders:
- `KYC/`: KYC-related models.
- `driver/`: driver, ride, wallet, and withdrawal models.
- `routes/`: route registration models.
