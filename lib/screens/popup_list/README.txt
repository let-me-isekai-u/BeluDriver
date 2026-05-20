README - Tiếng Việt

Thư mục này chứa các popup thông báo dùng lại ở nhiều nơi.

Ý nghĩa các file:
- `action_success_popup.dart`: popup thành công dùng chung cho nhiều thao tác.
- `deposit_request_failed_popup.dart`: popup thất bại cho nạp tiền. Hiện tại đang để dự phòng, không còn đang được gọi.
- `deposit_request_success_popup.dart`: popup thành công cho nạp tiền. Hiện tại đang để dự phòng, không còn đang được gọi.
- `has_accepted_popup.dart`: popup báo đơn đã có tài xế khác nhận.
- `insufficient_balance_popup.dart`: popup báo số dư không đủ.
- `received_success_popup.dart`: popup nhận đơn thành công.
- `withdraw_request_failed_popup.dart`: popup thất bại cho rút tiền.
- `withdraw_request_success_popup.dart`: popup thành công cho rút tiền.

Lưu ý:
- Nếu muốn đồng bộ trải nghiệm thông báo, nên ưu tiên tái sử dụng popup trong thư mục này trước khi tạo mới.

README - English

This folder contains reusable popup dialogs used in multiple places.

File purposes:
- `action_success_popup.dart`: shared success popup for multiple actions.
- `deposit_request_failed_popup.dart`: deposit failure popup. Currently kept for reference and no longer used.
- `deposit_request_success_popup.dart`: deposit success popup. Currently kept for reference and no longer used.
- `has_accepted_popup.dart`: popup shown when another driver already accepted the ride.
- `insufficient_balance_popup.dart`: popup for insufficient wallet balance.
- `received_success_popup.dart`: popup for successful ride acceptance.
- `withdraw_request_failed_popup.dart`: withdrawal failure popup.
- `withdraw_request_success_popup.dart`: withdrawal success popup.

Note:
- To keep notifications consistent, prefer reusing popups from this folder before creating a new one.
