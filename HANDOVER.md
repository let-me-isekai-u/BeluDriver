
## Tiếng Việt

### 1. Mục đích file này

File này dùng để giúp người tiếp theo tiếp nhận dự án nhanh, biết nên bắt đầu từ đâu, các luồng chính nằm ở đâu, và những điểm cần lưu ý trước khi sửa code.

Nếu cần xem chi tiết theo từng thư mục trong `lib`, đọc thêm các file `README.txt` đã có sẵn trong từng thư mục.

### 2. Tổng quan ngắn

- Tên app: `beludriver_app`
- Nền tảng: Flutter
- State management chính: `provider` với `ChangeNotifier`
- API chính: `lib/services/api_service.dart`
- Realtime chat: SignalR
- Notification: Firebase Messaging + local notification
- KYC / camera / face detection: dùng `camera` và Google ML Kit

### 3. Cách chạy dự án

Các lệnh cơ bản:

```bash
flutter pub get
flutter run
flutter analyze
```

Lưu ý môi trường:

- Firebase config đã có sẵn tại:
  - `android/app/google-services.json`
  - `ios/GoogleService-Info.plist`
- App đang gọi API trực tiếp vào domain production:
  - `https://xeghepdongduong.com`
- Có gọi thêm API ngân hàng:
  - `https://api.vietqr.io/v2/banks`

### 4. Điểm vào và điều hướng chính

- `lib/main.dart`
  - khởi tạo Flutter
  - khởi tạo Firebase
  - khởi tạo notification
  - vào route `/splash`

Route chính hiện có:

- `/splash`
- `/login`
- `/home`

Luồng khởi động:

1. `SplashScreen` kiểm tra token trong `SharedPreferences`
2. nếu token hết hạn thì thử refresh
3. lấy profile + trạng thái onboarding
4. điều hướng sang `login` hoặc `home`

### 5. Cấu trúc code hiện tại

Trong `lib` hiện có 2 lớp tổ chức đang song song:

- Cấu trúc cũ:
  - `screens`
  - `providers`
  - `models`
  - `services`
- Cấu trúc mới để tổ chức theo nghiệp vụ:
  - `features/...`

Hiểu ngắn gọn:

- code runtime hiện tại vẫn chủ yếu chạy theo `screens / providers / models / services`
- `features/...` đang là lớp tổ chức mới để gom import theo từng nhóm chức năng
- khi viết code mới, nên ưu tiên import qua `features/...` nếu feature đó đã có barrel file

Ví dụ:

```dart
import 'package:beludriver_app/features/driver/profile/profile.dart';
```

### 6. Các luồng nghiệp vụ chính

#### Đăng nhập / hồ sơ

- `lib/screens/driver/driver_login_screen.dart`
- `lib/providers/driver/login_provider.dart`
- `lib/screens/driver/driver_profile.dart`
- `lib/providers/driver/profile_provider.dart`
- `lib/screens/driver/driver_update_profile_screen.dart`
- `lib/providers/driver/update_profile_provider.dart`

#### Nhận đơn

- `lib/screens/driver/recieve_order_screen.dart`
- `lib/providers/received_order_provider.dart`

Chức năng chính:

- tải danh sách đơn chờ
- lọc / tìm kiếm
- nhận đơn
- quản lý danh sách đơn đã nhận và đơn đã đẩy

Lưu ý:

- `received_order_provider.dart` hiện đang import `lib/services/v2/api_service.dart`
- không nên xóa `services/v2` nếu chưa kiểm tra lại toàn bộ luồng nhận đơn

#### Đẩy đơn

- `lib/screens/driver/driver_booking_screen.dart`
- `lib/providers/broker/order_form_provider.dart`
- `lib/screens/driver/driver_booking_confirm.dart`

Chức năng chính:

- nhập thông tin chuyến
- chọn tỉnh / quận huyện
- xác nhận trước khi tạo / đẩy đơn

#### Hoạt động / lịch sử

- `lib/screens/driver/activity_history.dart`
- `lib/providers/driver/activity_history_provider.dart`
- `lib/screens/driver/ride_detail_screen.dart`
- `lib/providers/driver/ride_detail_provider.dart`

Chức năng chính:

- tab đang diễn ra
- tab lịch sử
- tab đơn đã đẩy
- bắt đầu chuyến
- hoàn thành chuyến
- hủy đơn đã đẩy

#### Tài chính

- `lib/screens/driver/driver_profile.dart`
- `lib/providers/driver/deposit_provider.dart`
- `lib/screens/driver/wallet_history_screen.dart`
- `lib/providers/driver/wallet_history_provider.dart`
- `lib/screens/driver/withdrawal_history_screen.dart`
- `lib/providers/driver/withdrawal_history_provider.dart`

Chức năng chính:

- xem số dư
- nạp tiền
- yêu cầu rút tiền
- lịch sử ví
- lịch sử rút tiền

#### Chat nhóm đơn đẩy

- `lib/screens/chat_to_order/chat_group_list_screen.dart`
- `lib/providers/chat_group_list_provider.dart`
- `lib/screens/chat_to_order/chat_screen.dart`
- `lib/providers/chat_provider.dart`
- `lib/services/api_chat_service.dart`
- `lib/services/signalr_service.dart`

#### KYC / đăng ký tuyến

- `lib/screens/kyc/...`
- `lib/providers/kyc/kyc_provider.dart`
- `lib/services/kyc_service.dart`
- `lib/screens/register_route/register_route_popup.dart`
- `lib/providers/routes/register_route_provider.dart`

### 7. Màn hình nào đã có provider riêng

Các màn hình đã có provider riêng:

- `driver_home` → `HomeProvider`, `DepositProvider`
- `driver_profile` → `ProfileProvider`, `DepositProvider`
- `driver_login_screen` → `LoginProvider`
- `driver_register_screen` → `RegisterProvider`
- `driver_booking_screen` → `OrderFormProvider`
- `recieve_order_screen` → `RecieveOrderProvider`
- `chat_screen` → `ChatProvider`
- `chat_group_list_screen` → `ChatGroupListProvider`
- `register_route_popup` → `RegisterRouteProvider`
- `kyc_popup` → `KycProvider`
- `activity_history` → `ActivityHistoryProvider`
- `ride_detail_screen` → `RideDetailProvider`
- `wallet_history_screen` → `WalletHistoryProvider`
- `withdrawal_history_screen` → `WithdrawalHistoryProvider`
- `driver_update_profile_screen` → `UpdateProfileProvider`

Các màn hình hiện chưa có provider riêng:

- `splash_screen`
- `forgot_password_screen`
- `change_password_screen`
- `driver_booking_confirm`
- các màn hình step nhỏ của KYC
- các màn hình face detection riêng
- một số popup UI đơn giản

### 8. Các file / khu vực cần chú ý khi sửa

#### API

- File chính: `lib/services/api_service.dart`
- Có bản song song: `lib/services/v2/api_service.dart`

Nếu sửa API:

- kiểm tra màn hình nào đang dùng `v2`
- tránh sửa một bên rồi quên bên còn lại

#### Realtime chat

- `lib/services/api_chat_service.dart`
- `lib/services/signalr_service.dart`
- `lib/services/beludriver_signalr_http_client.dart`

#### Notification

- `lib/services/firebase_notification_service.dart`

#### Popup dùng chung

- `lib/screens/popup_list`

#### Feature barrel

- `lib/features/...`

Đây là nơi gom export để giảm import lẻ. Khi thêm model / provider / screen mới cho một nhóm chức năng, có thể export thêm vào file barrel tương ứng.

### 9. Một vài lưu ý kỹ thuật thực tế

- Thư mục asset hiện đang nằm trong `lib/assets`, không phải `assets/` ở root.
- Có import theo kiểu `Screens/splash_screen.dart` trong `main.dart`.
  - Trên máy macOS thường vẫn chạy do filesystem không phân biệt hoa thường.
  - Nếu chuyển sang môi trường phân biệt hoa thường, nên sửa về `screens/splash_screen.dart`.
- Dự án đang là trạng thái chuyển dần sang cấu trúc `feature-based`, nhưng chưa migrate hết toàn bộ màn hình.
- Khi sửa logic cũ, nên kiểm tra provider trước rồi mới sửa trực tiếp trong screen.

### 10. Nên bắt đầu từ đâu khi tiếp nhận

Nếu là người mới vào dự án, thứ tự đọc nên là:

1. `HANDOVER.md`
2. `lib/README.txt`
3. `lib/main.dart`
4. `lib/screens/driver/driver_home.dart`
5. `lib/screens/driver/driver_profile.dart`
6. `lib/screens/driver/activity_history.dart`
7. `lib/providers/...` tương ứng với màn hình cần sửa
8. `lib/services/api_service.dart`

### 11. Gợi ý cách phát triển tiếp

- Khi thêm màn hình mới, ưu tiên tách provider nếu màn hình có state / API riêng.
- Khi thêm file mới theo feature, cân nhắc export vào `lib/features/.../*.dart`.
- Nếu refactor tiếp, nên làm theo từng nhóm:
  - `auth + splash`
  - `kyc`
  - `chat`
  - `finance`

---

## English

### 1. Purpose of this file

This file is meant to help the next developer take over the project quickly, understand where the main flows live, and know what to check before changing code.

For folder-by-folder details inside `lib`, read the `README.txt` files that already exist in each directory.

### 2. Short overview

- App name: `beludriver_app`
- Platform: Flutter
- Main state management: `provider` with `ChangeNotifier`
- Main API layer: `lib/services/api_service.dart`
- Realtime chat: SignalR
- Notifications: Firebase Messaging + local notifications
- KYC / camera / face detection: built with `camera` and Google ML Kit

### 3. How to run the project

Basic commands:

```bash
flutter pub get
flutter run
flutter analyze
```

Environment notes:

- Firebase config already exists at:
  - `android/app/google-services.json`
  - `ios/GoogleService-Info.plist`
- The app currently calls production APIs directly:
  - `https://xeghepdongduong.com`
- Bank list is fetched from:
  - `https://api.vietqr.io/v2/banks`

### 4. Main entry and routing

- `lib/main.dart`
  - initializes Flutter
  - initializes Firebase
  - initializes notifications
  - starts at `/splash`

Current main routes:

- `/splash`
- `/login`
- `/home`

Startup flow:

1. `SplashScreen` checks tokens in `SharedPreferences`
2. if the access token is expired, it tries refresh token flow
3. loads profile + onboarding status
4. routes to `login` or `home`

### 5. Current code structure

There are currently two structures living in parallel inside `lib`:

- Old structure:
  - `screens`
  - `providers`
  - `models`
  - `services`
- Newer feature-oriented structure:
  - `features/...`

In practice:

- the runtime code still mainly follows `screens / providers / models / services`
- `features/...` is the newer organizational layer used to group imports by business domain
- for new code, prefer importing through `features/...` where a barrel file already exists

Example:

```dart
import 'package:beludriver_app/features/driver/profile/profile.dart';
```

### 6. Main business flows

#### Login / profile

- `lib/screens/driver/driver_login_screen.dart`
- `lib/providers/driver/login_provider.dart`
- `lib/screens/driver/driver_profile.dart`
- `lib/providers/driver/profile_provider.dart`
- `lib/screens/driver/driver_update_profile_screen.dart`
- `lib/providers/driver/update_profile_provider.dart`

#### Ride receiving

- `lib/screens/driver/recieve_order_screen.dart`
- `lib/providers/received_order_provider.dart`

Main responsibilities:

- load waiting rides
- filtering / searching
- accept rides
- manage accepted rides and pushed rides

Important note:

- `received_order_provider.dart` currently imports `lib/services/v2/api_service.dart`
- do not remove `services/v2` until the receiving flow is fully rechecked

#### Ride pushing

- `lib/screens/driver/driver_booking_screen.dart`
- `lib/providers/broker/order_form_provider.dart`
- `lib/screens/driver/driver_booking_confirm.dart`

Main responsibilities:

- enter ride information
- choose province / district
- confirm before creating / pushing a ride

#### Activity / history

- `lib/screens/driver/activity_history.dart`
- `lib/providers/driver/activity_history_provider.dart`
- `lib/screens/driver/ride_detail_screen.dart`
- `lib/providers/driver/ride_detail_provider.dart`

Main responsibilities:

- ongoing tab
- history tab
- pushed rides tab
- start ride
- complete ride
- cancel pushed ride

#### Finance

- `lib/screens/driver/driver_profile.dart`
- `lib/providers/driver/deposit_provider.dart`
- `lib/screens/driver/wallet_history_screen.dart`
- `lib/providers/driver/wallet_history_provider.dart`
- `lib/screens/driver/withdrawal_history_screen.dart`
- `lib/providers/driver/withdrawal_history_provider.dart`

Main responsibilities:

- show wallet balance
- deposit
- withdrawal request
- wallet history
- withdrawal history

#### Group chat for pushed rides

- `lib/screens/chat_to_order/chat_group_list_screen.dart`
- `lib/providers/chat_group_list_provider.dart`
- `lib/screens/chat_to_order/chat_screen.dart`
- `lib/providers/chat_provider.dart`
- `lib/services/api_chat_service.dart`
- `lib/services/signalr_service.dart`

#### KYC / route registration

- `lib/screens/kyc/...`
- `lib/providers/kyc/kyc_provider.dart`
- `lib/services/kyc_service.dart`
- `lib/screens/register_route/register_route_popup.dart`
- `lib/providers/routes/register_route_provider.dart`

### 7. Screens that already have dedicated providers

Screens with dedicated providers:

- `driver_home` → `HomeProvider`, `DepositProvider`
- `driver_profile` → `ProfileProvider`, `DepositProvider`
- `driver_login_screen` → `LoginProvider`
- `driver_register_screen` → `RegisterProvider`
- `driver_booking_screen` → `OrderFormProvider`
- `recieve_order_screen` → `RecieveOrderProvider`
- `chat_screen` → `ChatProvider`
- `chat_group_list_screen` → `ChatGroupListProvider`
- `register_route_popup` → `RegisterRouteProvider`
- `kyc_popup` → `KycProvider`
- `activity_history` → `ActivityHistoryProvider`
- `ride_detail_screen` → `RideDetailProvider`
- `wallet_history_screen` → `WalletHistoryProvider`
- `withdrawal_history_screen` → `WithdrawalHistoryProvider`
- `driver_update_profile_screen` → `UpdateProfileProvider`

Screens without their own dedicated provider yet:

- `splash_screen`
- `forgot_password_screen`
- `change_password_screen`
- `driver_booking_confirm`
- smaller KYC step screens
- standalone face detection screens
- some simple UI popups

### 8. Files / areas that need special attention

#### API

- Main file: `lib/services/api_service.dart`
- Parallel version: `lib/services/v2/api_service.dart`

If you change API code:

- check which screens still use `v2`
- avoid updating one side and forgetting the other

#### Realtime chat

- `lib/services/api_chat_service.dart`
- `lib/services/signalr_service.dart`
- `lib/services/beludriver_signalr_http_client.dart`

#### Notifications

- `lib/services/firebase_notification_service.dart`

#### Shared popups

- `lib/screens/popup_list`

#### Feature barrels

- `lib/features/...`

These files re-export related models/providers/screens to reduce scattered imports. When adding new files to a domain, consider exporting them from the matching barrel.

### 9. Practical technical notes

- Assets are currently stored in `lib/assets`, not the more common root-level `assets/`.
- `main.dart` imports `Screens/splash_screen.dart`.
  - This usually still works on macOS because the filesystem is often case-insensitive.
  - On a case-sensitive environment, it should be corrected to `screens/splash_screen.dart`.
- The project is mid-transition toward a feature-based structure, but not every screen has been migrated yet.
- When changing old logic, check the provider first before editing large amounts of code directly in the screen.

### 10. Recommended reading order for a new developer

1. `HANDOVER.md`
2. `lib/README.txt`
3. `lib/main.dart`
4. `lib/screens/driver/driver_home.dart`
5. `lib/screens/driver/driver_profile.dart`
6. `lib/screens/driver/activity_history.dart`
7. the matching `lib/providers/...` files for the screen being changed
8. `lib/services/api_service.dart`

### 11. Suggested direction for future development

- For new screens, prefer creating a provider when the screen owns API calls or non-trivial state.
- For new feature files, consider exporting them from `lib/features/.../*.dart`.
- If you continue refactoring, the cleanest order is probably:
  - `auth + splash`
  - `kyc`
  - `chat`
  - `finance`
