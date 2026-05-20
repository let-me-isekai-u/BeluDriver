README - Tiếng Việt

Thư mục `lib` là nơi chứa toàn bộ source chính của ứng dụng Flutter.

Ý nghĩa các file và thư mục cấp cao:
- `main.dart`: điểm vào của app, khởi tạo ứng dụng và route chính.
- `app_theme.dart`: cấu hình theme, màu sắc, style dùng chung.
- `dashed_line_vertical.dart`: widget vẽ đường gạch dọc.
- `assets/`: ảnh, icon, animation đang được nhúng trực tiếp từ thư mục `lib`.
- `models/`: model parse dữ liệu API và DTO dùng trong app.
- `providers/`: state management theo `ChangeNotifier`.
- `screens/`: màn hình và popup UI.
- `services/`: lớp gọi API, notification, SignalR, permission, KYC.
- `widgets/`: widget dùng chung.
- `features/`: lớp tổ chức mới theo feature, chủ yếu là các file barrel `export`.

Lưu ý bàn giao:
- Cấu trúc cũ vẫn đang song song với cấu trúc `features`.
- Code mới nên ưu tiên nhìn theo feature, nhưng import cũ vẫn hoạt động bình thường.

README - English

The `lib` folder contains the main Flutter application source code.

Main files and top-level directories:
- `main.dart`: application entry point and route setup.
- `app_theme.dart`: shared theme, colors, and visual styles.
- `dashed_line_vertical.dart`: reusable vertical dashed line widget.
- `assets/`: images, icons, and animations currently stored under `lib`.
- `models/`: API models and DTOs.
- `providers/`: `ChangeNotifier`-based state management.
- `screens/`: screens and popup UI.
- `services/`: API, notifications, SignalR, permission, and KYC services.
- `widgets/`: shared UI widgets.
- `features/`: newer feature-based organization layer, mostly barrel export files.

Handover note:
- The old structure still exists in parallel with the `features` structure.
- New code should preferably follow the feature view, but old imports still work.
