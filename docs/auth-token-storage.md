# Báo cáo migration authentication token storage

Ngày: 10/11/2026. Phạm vi: mã ứng dụng đang chạy từ `lib/main.dart` trong dự án này.

## Audit và key

- Trước migration, đăng nhập ghi `accessToken` và `refreshToken` vào SharedPreferences; Splash đọc/refresh/xóa; các screen/provider/API client đọc trực tiếp.
- Không phát hiện key `access_token` / `refresh_token`, Dio interceptor, AuthRepository hoặc nơi lưu authentication token bằng Hive/GetStorage trong mã chạy.
- Sau migration, mọi thao tác với hai token đi qua `TokenStorage.instance`. Cặp token nằm trong một giá trị Secure Storage `auth_tokens_v1`, để tránh lưu lệch cặp khi refresh.
- Phát hiện thêm `carrier_vehicle_session_v1`: JSON chứa `accessToken`, `sessionToken`, `sessionExpiresAt`, `vehicle`. Toàn bộ bản ghi này chuyển vào Secure Storage `auth_vehicle_session_v1`, giữ nguyên cấu trúc và metadata phiên xe.
- Phiên xe được thử migrate khi khởi động và khi mở chế độ xe. Xóa riêng phiên driver do backend từ chối không ảnh hưởng phiên xe. Những nơi trước đây dùng `prefs.clear()` chuyển sang xóa cả hai phiên bảo mật trước khi xóa preferences, giữ phạm vi logout cũ.
- Dữ liệu không nhạy cảm khác (tên, số điện thoại, cờ UI, địa chỉ, thông tin onboarding/KYC...) vẫn dùng SharedPreferences.
- Không thay đổi endpoint, payload/response contract hoặc quyết định auth của backend trong migration này. Không thêm cơ chế refresh/401 mới.

## Migration và xử lý lỗi

1. Đọc Secure Storage. Nếu có bản ghi hợp lệ, dùng bản ghi này và thử dọn key legacy còn sót.
2. Nếu chưa có bản ghi bảo mật, kiểm tra dữ liệu legacy: String không rỗng/whitespace, không phải chuỗi `null`. Phiên xe yêu cầu JSON đúng cấu trúc. Không kiểm tra JWT expiry để quyết định migrate; backend tiếp tục xác thực như trước.
3. Ghi bảo mật, đọc lại và so sánh toàn bộ giá trị. Chỉ sau khi khớp mới xóa key legacy.
4. Nếu migration gặp lỗi đọc/ghi/verify, giữ nguyên bản cũ và trả về token legacy hợp lệ để giữ phiên hiện tại. Lần đọc sau thử lại. Không ghi token mới xuống SharedPreferences, không log giá trị hoặc native error.
5. Nếu không có bản legacy để fallback và Secure Storage lỗi, trả `TokenStorageException` có thông báo cố định, không chứa credential. Splash cho phép thử lại và không chạy nhánh xóa phiên do hết hạn. Login/logout hiển thị lỗi lưu trữ an toàn.
6. Đọc/migrate/ghi/xóa được tuần tự hóa qua cùng một queue trong singleton. Các cập nhật cặp token dùng một bản ghi. Logout ghi một bản ghi chỉ chứa giá trị null (không còn token), xác nhận lại, rồi xóa legacy; bản ghi rỗng chặn việc khôi phục lại legacy sau logout bị gián đoạn. Không tự reset kho mã hóa khi gặp lỗi.

## Dependency và cấu hình nền tảng

- Thêm chính xác `flutter_secure_storage: 11.2.0`, bản stable từ pub.dev, không chạy nâng cấp hàng loạt. Pub resolver cập nhật các dependency bắc cầu cần thiết; giữ nguyên dependency trực tiếp khác.
- SDK đã kiểm tra: Flutter 3.41.5 / Dart 3.11.3; Android `flutter.minSdkVersion` hiện là 24, Java 17; iOS deployment target là 15.5. Không thay đổi minSdk, app ID/bundle ID, tên/icon hoặc cấu hình signing.
- Android dùng cipher mặc định của package với `resetOnError: false`. Loại `FlutterSecureStorage.xml`, `FlutterSecureKeyStorage.xml` và `FlutterSharedPreferences.xml` khỏi cloud backup và device transfer (quy tắc trước/sau Android 12).
- Lý do loại cả file preferences legacy: Android backup loại trừ theo file, không theo từng key; file có thể còn token trong khi migration chưa thành công. Dữ liệu preferences khác vẫn giữ trên thiết bị khi cập nhật; chúng cũng không được đưa vào các backup mới của file này.
- iOS: `first_unlock_this_device`, `synchronizable: false`; thêm `keychain-access-groups` rỗng vào Runner.entitlements đang dùng cho các cấu hình build. Không tạo access group dùng chung giữa hai app.
- Loại log response đăng nhập, token dạng substring và log HTTP headers/payload của SignalR có thể chứa Bearer token. Không thay đổi request được gửi lên server.

Nguồn: [package stable và hướng dẫn nền tảng](https://pub.dev/packages/flutter_secure_storage/versions/11.2.0), [Android backup rules](https://developer.android.com/identity/data/autobackup#IncludingFiles).

## Kiểm thử

- PASS: `flutter test` — 28 test (25 test storage/migration + 3 test service/widget hiện có).
- PASS: `flutter build ios --debug --no-codesign --no-pub` — build được Runner.app cho thiết bị iOS.
- Analyzer: không có lỗi; còn các warning/lint có sẵn (face detection, KYC UI, animation Splash). Không thêm loại diagnostic mới.
- PASS: audit tĩnh toàn bộ `lib/`: không còn đọc/ghi key authentication bằng `getString`/`setString`; chỉ service đọc legacy bằng `get` để migrate và dọn key cũ. Kiểm tra log auth, XML backup, entitlements và không đổi cấu hình app/signing.
- PASS: `git diff --check`.
- BLOCKED/FAIL môi trường: `flutter build apk --debug --no-pub` không tải được các artifact hiện có như Google Services 4.4.2/Gson/Guava từ `dl.google.com` / `repo.maven.apache.org` (DNS/network). Chưa xác minh hoàn tất build Android.
- Các test migration bao phủ: user cũ, user mới, khởi tạo service lại, token chỉ có access/refresh, dữ liệu sai kiểu/rỗng, ghi thất bại, ghi im lặng không lưu, đọc xác nhận thất bại, retry/idempotence, logout, refresh giữ/xoay cặp, queue concurrent và thông báo lỗi đã ẩn dữ liệu.

## Giới hạn và việc cần QA trên thiết bị

- Chưa chạy nâng cấp bản release trên thiết bị thật với phiên backend đang còn hiệu lực, kill/relaunch, hoặc backup/restore thực tế. Build iOS không codesign chỉ xác minh compile/link, không xác minh provisioning/runtime Keychain.
- Cần QA: đăng nhập bản cũ → cập nhật giữ nguyên app data → khôi phục phiên; đăng nhập mới → tắt/mở; backend trả 401 → refresh thành công/thất bại; logout → mở lại; thử lại khi Keychain/Keystore tạm thời không truy cập được.
- Lỗi Secure Storage sau khi legacy đã được xóa được báo an toàn; không tự xóa/reset token để ép đăng nhập. Logout không báo thành công nếu không xác minh được việc xóa token.
- Luồng cũ có thể xóa token khi lỗi mạng hoặc refresh thất bại; migration giữ nguyên chính sách này, không refactor ngoài phạm vi. Các giới hạn xử lý 401 của luồng cũ cũng được giữ nguyên.
- Không sửa hoặc thu hồi credential ở backend; không tạo commit/push.
- Cảnh báo MLKit đã có về arm64 simulator iOS mới vẫn còn; build thiết bị iOS thành công. Không thay đổi MLKit trong task này.
- `backup/` không nằm trong entrypoint/import của ứng dụng đang chạy: chỉ audit, không sửa bản backup. FCM device token khác authentication token, không thuộc migration này.

## File đã sửa/thêm

Các plugin registrant là file tự sinh sau khi thêm package. Danh sách gồm cả file đã có thay đổi trong workspace mà task này tiếp tục chỉnh:

- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/xml/auth_backup_rules.xml`
- `android/app/src/main/res/xml/auth_data_extraction_rules.xml`
- `docs/auth-token-storage.md`
- `ios/Podfile.lock`
- `ios/Runner/Runner.entitlements`
- `lib/features/carrier_vehicle/carrier_vehicle_screens.dart`
- `lib/features/carrier_vehicle/carrier_vehicle_service.dart`
- `lib/main.dart`
- `lib/providers/chat_group_list_provider.dart`
- `lib/providers/driver/activity_history_provider.dart`
- `lib/providers/driver/login_provider.dart`
- `lib/providers/driver/profile_provider.dart`
- `lib/providers/driver/ride_detail_provider.dart`
- `lib/providers/driver/update_profile_provider.dart`
- `lib/providers/driver/wallet_history_provider.dart`
- `lib/providers/driver/withdrawal_history_provider.dart`
- `lib/providers/home_provider.dart`
- `lib/providers/received_order_provider.dart`
- `lib/screens/change_password_screen.dart`
- `lib/screens/chat_to_order/chat_screen.dart`
- `lib/screens/driver/concert_ticket_scanner_screen.dart`
- `lib/screens/driver/driver_booking_confirm.dart`
- `lib/screens/driver/driver_home.dart`
- `lib/screens/driver/driver_profile.dart`
- `lib/screens/kyc/kyc_popup.dart`
- `lib/screens/register_route/register_route_popup.dart`
- `lib/screens/splash_screen.dart`
- `lib/services/api_service.dart`
- `lib/services/beludriver_signalr_http_client.dart`
- `lib/services/signalr_service.dart`
- `lib/services/token_storage.dart`
- `lib/services/v2/api_service.dart`
- `linux/flutter/generated_plugin_registrant.cc`
- `linux/flutter/generated_plugins.cmake`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `pubspec.lock`
- `pubspec.yaml`
- `test/token_storage_test.dart`
- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugins.cmake`
