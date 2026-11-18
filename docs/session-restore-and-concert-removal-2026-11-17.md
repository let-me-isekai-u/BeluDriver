# Khôi phục phiên nhà xe và gỡ concert BIGBANG — 17/11/2026

**Trạng thái: đã sửa trực tiếp; runtime iOS/Android UNVERIFIED.** Không chạy Flutter build/run/test, không điều khiển thiết bị, không gọi API production, không sửa backend, không commit/push.

## Trạng thái local trước khi sửa

| Repository | Branch | HEAD | Staged | Local có sẵn |
|---|---|---|---|---|
| BeluDriver | `main` | `baf7e71c7af0e7cf85ff36b06f7dd1f6c9cc5b0b` | Không | 15 file modified và 5 mục untracked từ sửa iOS/map/QR/session trước đó |
| Belucar | `main` | `9d72813a7b2e3f23ae9b0780aa50452e3a6739da` | Không | `ios/Runner.xcodeproj/project.pbxproj` modified |

Dùng working tree local làm cơ sở. Không thay branch/HEAD/stash/index; không pull/merge/rebase/reset/clean. Các chỉnh sửa QR được phát triển tiếp, không hoàn tác. Hash xác nhận signing iOS ở cả hai repo, map attribution/test, ProfileProvider, TokenStorage test, QR cooldown và parser từ lần trước được giữ byte-for-byte; chỉ các phần concert bị xóa theo yêu cầu mới.

## BeluDriver — phiên QR

**Nguyên nhân phải quét lại:** chưa tái hiện trên thiết bị nên nguyên nhân runtime chính xác vẫn UNVERIFIED. HEAD trước các sửa local chỉ phục hồi tài xế thường; tuy nhiên working tree đầu task đã có `CarrierVehicleService.load()` trong Splash từ lần sửa trước. Không kết luận local hiện tại bỏ qua load. Những điểm xác minh được: chưa lưu lựa chọn chế độ cuối cùng; startup chuyển Login rồi push màn xe thay vì một quyết định điều hướng; main import `Screens/splash_screen.dart` sai casing so với đường dẫn Git `screens/splash_screen.dart`.

Session nhà xe đã lưu cả Access Token/Session Token/expiry/metadata trong Secure Storage `auth_vehicle_session_v1`, tách `auth_tokens_v1` của tài xế. Không đổi khóa, contract, thời hạn hoặc migration. Backend vẫn quyết định phiên còn quyền hay không; metadata trong máy không đủ để cho vào Home.

Cơ chế mới:

1. Đọc `lastActiveMode` không nhạy cảm; không có metadata thì thử xe trước để tương thích phiên cũ. Lựa chọn được ghi khi người dùng chọn đăng nhập tài xế/chế độ xe, exchange thành công, Back khỏi mode xe hoặc logout xe. Ghi preference có hàng đợi để lựa chọn mới nhất thắng khi async chồng nhau.
2. Thử phiên ưu tiên: xe → `load()` rồi GET `/api/carrier-vehicle/runs/today`; tài xế → đọc token rồi GET profile qua DriverAuthClient. Chỉ mở Home sau response thành công. Dữ liệu chuyến đã lấy được chuyển vào Home, tránh GET trùng ngay sau startup.
3. 401 xe → refresh bằng Session Token xe, tối đa một lần; gom refresh đồng thời, giữ bảo vệ response/generation từ lần trước. Refresh bị từ chối hoặc request vẫn 401 → kết thúc riêng phiên xe. Phiên tài xế dùng coordinator/token riêng.
4. Phiên ưu tiên không tồn tại/hết hạn/bị thu hồi → thử phiên còn lại. Không có phiên hợp lệ → Login; lý do hết phiên xe được chuyển vào Login, QR entry vẫn cho quét lại. Không tự mở camera khi startup.
5. Mạng/timeout/429/5xx/storage lỗi → giữ credential, hiển thị lỗi + Thử lại; không âm thầm chuyển sang mode khác hoặc vào Home như đã xác thực. Cooldown Retry-After của xe vẫn được giữ. Có nút Đăng nhập tài xế để người dùng chủ động rời bước khôi phục.
6. Startup gom thành một future, Splash khóa navigation; callback hết hạn Driver nhường quyết định fallback cho `/splash` và không đóng route nhà xe. Callback login cũ từ màn bị che không tự đẩy Driver Home lên trên QR mode.
7. Home/scanner khi là route gốc có đường Back về Login. Back chọn mode tài xế nhưng giữ phiên xe; logout xe mới xóa credential xe/tombstone và dừng GPS như bản sửa trước. Không khôi phục lại token đã logout.

| Tình huống | Cách xử lý / giới hạn |
|---|---|
| Hot Reload | Giữ state Dart hiện hữu; thường không chạy lại startup. Không dùng làm bằng chứng restore từ disk. |
| Hot Restart | State/static Dart được tạo lại; đọc phiên Secure Storage và kiểm tra server. Cần test trên debug build. |
| Cold Restart Android/iOS | Cùng logic restore từ Secure Storage, theo mode gần nhất còn hợp lệ. Cần test thiết bị. |
| Xóa data/cài lại | Không cam kết giữ phiên; đặc biệt Keychain iOS có hành vi khác với Android. Không kiểm thử bằng cách xóa dữ liệu người dùng. |
| Access Token xe hết 15 phút | Refresh bằng Session Token còn hiệu lực, không exchange QR mới. |
| Logout/thu hồi/hết hạn thực | Không dùng lại credential đã xóa/bị backend từ chối; không xóa nhầm JWT Driver. |

Giữ CarrierQrScanScreen, CarrierVehicleService/Home/Run/GpsTracker, chống quét lặp, scanner lifecycle, rate limit, manifest, board/no-show, vận hành chuyến và GPS theo runId. Lớp CarrierGpsTracker không bị chỉnh trong task này. Không thêm nút QR nhà xe trên Driver Home.

## BeluDriver — concert đã gỡ

Xóa đúng năm file chỉ thuộc concert:

- `lib/screens/driver/concert_ticket_scanner_screen.dart`
- `lib/services/concert_ticket_service.dart`
- `lib/models/concert_ticket_verification_model.dart`
- `test/concert_ticket_service_test.dart`
- `test/widget_test.dart` (toàn bộ file chỉ test concert scanner)

Sửa:

- `lib/screens/driver/driver_home.dart`: xóa nút Soát vé/import/navigation concert; giữ chat/nạp/rút ví.
- `lib/services/driver_auth_client.dart`: bỏ ngoại lệ replay endpoint concert đã xóa; giữ refresh tài xế và quy tắc replay của API còn hoạt động.
- `test/qa_screens_test.dart`: chỉ bỏ hai test concert TC_Home_03/05 và camera fake/import phục vụ chúng; giữ các test QA khác.
- `test/qr_session_lifecycle_test.dart`: chỉ bỏ hai test concert và import; giữ toàn bộ test xe/429/navigation.

Không tìm thấy asset/config riêng BIGBANG trong app đang dùng. Không giữ dead code dưới comment. Tài liệu QA cũ được giữ; báo cáo QR cũ được đánh dấu lịch sử, phần concert không còn áp dụng.

## Các file startup/session sửa hoặc thêm

- Sửa: `lib/main.dart`, `lib/screens/splash_screen.dart`, `lib/screens/driver/driver_login_screen.dart`, `lib/features/carrier_vehicle/carrier_vehicle_screens.dart`, `lib/features/carrier_vehicle/carrier_vehicle_service.dart`, `lib/services/driver_session_navigation.dart`, `lib/services/token_storage.dart`.
- Thêm: `lib/services/active_session_mode.dart`, `lib/services/startup_session_restore.dart`, `test/startup_session_restore_test.dart`.
- Tài liệu: báo cáo này, `docs/auth-token-storage.md`, ghi chú lịch sử trong `docs/qr-audit/2026-11-17.md`.

Test code mới chuẩn bị các trường hợp restore từ storage không exchange, mode ưu tiên, refresh/restore đồng thời, revoked/fallback hai chiều, lỗi mạng/5xx/429 giữ phiên, logout không khôi phục lại và Back từ root Home. **Không chạy test.**

## Belucar

Không tìm thấy module concert/UI/API/model BIGBANG trong source đang dùng, test hoặc các thư mục source lưu trong repository. Chỉ còn hai lệnh ghi `showEventBanner` tại Login và Splash; toàn repo không có nơi đọc. Đã bỏ hai dòng ghi trong:

- `lib/screens/login_screen.dart`
- `lib/screens/splash_screen.dart`

Không xóa dữ liệu preference hiện có để thử nghiệm. Không sửa CustomerSession/global refresh, đặt xe ghép, carrier booking, Vé của tôi, thanh toán/VietQR/ví, chat/map/tracking hoặc video `assets/videos/intro_splash.mp4`. Đã xem ba carousel: nội dung Tết, không phải concert; giữ nguyên. Các từ `ticket` của carrier và `event` của UI/callback không bị xem là BIGBANG. Chi tiết ở báo cáo trong repo Belucar.

## Dependency / kiểm tra / việc còn lại

- **Không gỡ dependency, không đổi pubspec/lockfile.** Không có package độc quyền concert được xác minh: mobile_scanner còn dùng cho QR nhà xe; UI concert dùng Flutter, HTTP và các package dùng chung. Không xóa package công cụ hay package dư có sẵn chưa chứng minh thuộc concert.
- Static analysis toàn bộ `lib` và `test` cả hai app: **0 error**; BeluDriver có warning/lint có sẵn (face detection/KYC/Splash…), Belucar còn lint info. Không coi đây là runtime PASS. `git diff --check` đạt.
- Tìm lại trong `lib`/`test`: không còn concert/BIGBANG/showEventBanner/tham chiếu các lớp đã xóa. Kiểm tra import/route không trỏ vào file đã xóa.
- Giữ signing/Bundle ID/Team ID và các thay đổi local không liên quan. Không gọi server hoặc đọc/xóa token thật trên thiết bị.

Owner cần test iOS/Android: QR một lần → xe; hot restart/cold restart khi chỉ có xe/chỉ Driver/cả hai mode; token xe hết 15 phút; revoke/expiry; offline/429/5xx rồi retry; Back/root Logout; logout rồi restart; mở chuyến, manifest/board/start/arrive/depart/complete/GPS; Driver Home không còn Soát vé. Belucar cần hồi quy video intro, refresh token, đặt xe ghép, đặt limousine/xe khách, Vé của tôi, thanh toán và tracking. Toàn bộ các kiểm chứng thiết bị/backend này hiện **UNVERIFIED**.

## Git status sau sửa

Branch/HEAD của cả hai repo không đổi; không có staged changes. Các mục iOS/map/ProfileProvider/TokenStorage test trong status BeluDriver bao gồm thay đổi có sẵn từ trước. Snapshot đầy đủ bên dưới:

/Users/nhatanhly/beludriver_app

```text
 M docs/auth-token-storage.md
 M ios/Runner.xcodeproj/project.pbxproj
 M lib/features/carrier_vehicle/carrier_vehicle_screens.dart
 M lib/features/carrier_vehicle/carrier_vehicle_service.dart
 M lib/main.dart
 D lib/models/concert_ticket_verification_model.dart
 M lib/providers/driver/profile_provider.dart
 D lib/screens/driver/concert_ticket_scanner_screen.dart
 M lib/screens/driver/driver_home.dart
 M lib/screens/driver/driver_login_screen.dart
 M lib/screens/splash_screen.dart
 D lib/services/concert_ticket_service.dart
 M lib/services/driver_auth_client.dart
 M lib/services/token_storage.dart
 M lib/widgets/driver_map_layer.dart
 D test/concert_ticket_service_test.dart
 M test/driver_map_layer_test.dart
 M test/qa_screens_test.dart
 M test/token_storage_test.dart
 D test/widget_test.dart
?? docs/qr-audit/
?? docs/session-restore-and-concert-removal-2026-11-17.md
?? lib/services/active_session_mode.dart
?? lib/services/driver_session_navigation.dart
?? lib/services/qr_cooldown.dart
?? lib/services/startup_session_restore.dart
?? lib/services/vehicle_qr_payload.dart
?? test/qr_session_lifecycle_test.dart
?? test/startup_session_restore_test.dart
```

/Users/nhatanhly/Belucar_app

```text
 M ios/Runner.xcodeproj/project.pbxproj
 M lib/screens/login_screen.dart
 M lib/screens/splash_screen.dart
?? docs/
```
