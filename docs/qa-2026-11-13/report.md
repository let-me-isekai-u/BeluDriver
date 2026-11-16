# BELUDRIVER — báo cáo sửa QA ngày 13/11/2026

Đã audit 17/17 testcase Failed và sửa trực tiếp 15/17. Phân loại: 8 `FIXED_VERIFIED`, 7 `FIXED_NEEDS_DEVICE_TEST`, 1 `BLOCKED_BACKEND`, 1 `NOT_FIXED` theo yêu cầu bỏ qua biển số của chủ sản phẩm. TC_Register_15 được sửa và báo riêng, không cộng vào 17.

`FIXED_VERIFIED` trong báo cáo này chỉ xác nhận hành vi bằng unit/widget test trên máy phát triển, không thay thế kết quả QA trên Android/iOS hoặc API production. Không chạy giao dịch rút tiền thật, không tạo tài khoản thật, không tuyên bố 17 testcase đã Pass.

## Baseline và phạm vi

- Repository local: `/Users/nhatanhly/beludriver_app`, remote được yêu cầu: `https://github.com/let-me-isekai-u/BeluDriver.git`.
- Branch kiểm tra trước khi sửa: `main`. HEAD: `d269cbd` — `fix(app): point production API to datxedongduong.com`.
- Các commit trước đó: `71cd240` — giữ lỗi API và khóa lệnh tài chính; `3108d44` — sửa chat realtime và lỗi đăng nhập; `6a919dd` — cập nhật UI.
- Working tree có sẵn nhiều thay đổi chưa commit, gồm token storage và nhiều màn hình. Không reset, không commit gộp, không tạo branch, không push. File liệt kê bên dưới là các file đợt QA này thực sự chỉnh thêm; không phải toàn bộ `git diff` của working tree.
- Không chỉnh forgot password/gửi OTP/reset password; không tái sử dụng endpoint OTP cho đăng ký. Không chỉnh logic GPS/chia sẻ vị trí, realtime chat, nhận chuyến hay hoàn thành chuyến.
- Không thay đổi payload/endpoint tạo chuyến, đăng ký hoặc rút tiền. Cơ chế idempotency và kiểm tra server được giữ nguyên.

## Evidence

- **U**: [qa_validation_test.dart](../../test/qa_validation_test.dart) — 11 tests: thứ tự validate đăng ký, chặn form lỗi trước request, thiếu thông tin rút tiền, biên số dư, giữ thông báo server/financial key, SĐT khách, dữ liệu ngày giờ/request.
- **W**: [qa_screens_test.dart](../../test/qa_screens_test.dart) — 8 widget tests: header/back đăng ký, soát vé, đóng camera mô phỏng, back nhóm chat, lỗi rút tiền/không POST, chọn ngày giờ, đầy đủ thông tin xác nhận, dropdown/gợi ý/chọn địa chỉ.
- **R**: test sẵn có `driver_login_api_test.dart`, `financial_command_test.dart`, `concert_ticket_service_test.dart`, `chat_realtime_test.dart` — 7 tests.
- [Log tests](focused-tests.txt): **26/26 passed**. [Log analyze](analyze.txt): **No issues found**, 12 file Dart trong phạm vi thay đổi. `git diff --check` trên các file nguồn được sửa: không có lỗi.
- Camera trong W dùng fake `MobileScannerPlatform`; chứng minh vị trí nút đóng, pop route và lời gọi dừng camera. Không chứng minh quyền camera/native preview hay việc thu hồi tài nguyên trên thiết bị thật. Giữ controller nội bộ của `mobile_scanner` 7.5.0, có cơ chế start/stop/dispose và observer lifecycle trong plugin; không bổ sung cơ chế camera cạnh tranh với plugin.

## Kết luận từng testcase

| Testcase | Root cause | Thay đổi | Kết quả | Evidence |
|---|---|---|---|---|
| TC_Register_01 | Header tự dựng dùng chữ và Back trắng trên `Brand.canvas` sáng; không phải AppBar chuẩn | Chữ `Brand.ink`, Back navy trên nền `b50`, thêm tooltip | `FIXED_NEEDS_DEVICE_TEST` | W: header và thao tác Back; cần kiểm tra theme/status bar thiết bị |
| TC_Register_16 | Chỉ kiểm tra biển số không rỗng; chưa có quy tắc định dạng trong code | Để nguyên theo yêu cầu người dùng: sẽ tự bổ sung validation biển số sau | `NOT_FIXED` | Audit `RegisterProvider.validate`; yêu cầu cập nhật của người dùng |
| TC_Register_17 | So sánh xác nhận SĐT trước khi kiểm tra trống | Trả `Chưa nhập lại số điện thoại` trước lỗi không khớp | `FIXED_VERIFIED` | U: kiểm tra cả trống, không khớp và chặn gọi đăng ký |
| TC_Register_19 | So sánh xác nhận mật khẩu trước khi kiểm tra trống | Trả `Chưa nhập lại mật khẩu` trước lỗi không khớp | `FIXED_VERIFIED` | U: trống và không khớp |
| TC_Register_21 | Client gọi thẳng `driver-register-ver2`; không tìm thấy bước/endpoint xác minh đăng ký riêng. Lỗi email theo báo cáo QA chưa có trace backend để xác nhận nguyên nhân phía server | Không bypass; giữ nguyên luồng. Cần backend cung cấp thứ tự và contract xác minh đăng ký | `BLOCKED_BACKEND` | Audit `RegisterProvider.register`, `ApiService.driverRegister`, các màn hình và endpoint hiện có; chưa gọi production |
| TC_Home_03 | AppBar navy chữ navy; thẻ navy với chữ navy/đen | AppBar chữ/Back trắng rõ ràng; các thẻ nền sáng, nội dung tối; sửa màu thông báo, loading, kết quả | `FIXED_NEEDS_DEVICE_TEST` | W: màn soát vé và thông báo nhập trống; R: giữ check-in QR/response; cần QA kết quả thực tế |
| TC_Home_05 | Close cùng màu nền navy; Row chứa Close bị giãn theo chiều cao Stack nên không neo phía trên | Neo Close phía trên bằng Positioned/SafeArea, icon trắng, tooltip; overlay bỏ bắt pointer; bảo vệ mounted sau await | `FIXED_NEEDS_DEVICE_TEST` | W: camera mô phỏng start/đóng/stop, nút ở phía trên; R: QR payload; cần quyền/lifecycle native |
| TC_Home_07 | Back tự sinh thừa hưởng màu tối của theme trên header gradient navy | Thêm Back trắng rõ ràng, `maybePop` về route gọi | `FIXED_VERIFIED` | W: mở nhóm chat từ trang chủ rồi Back; R: realtime group/message/card |
| TC_Home_12 | `_confirmWithdraw` return im lặng khi thiếu số tiền/ngân hàng; chưa kiểm tra tài khoản/chủ tài khoản | Validator riêng theo thứ tự số tiền, số dư, ngân hàng, tài khoản, chủ tài khoản; lỗi inline/liveRegion; return trước submit; dispose controller | `FIXED_VERIFIED` | U: từng trường bắt buộc và dữ liệu sai; W: lỗi hiện trên màn hình và không gửi POST |
| TC_Home_15 | Vượt số dư return không thông báo; ngoại lệ submit không có phản hồi riêng | Báo `Số dư ví không đủ để rút tiền`; giữ kiểm tra server/idempotency; dùng `apiErrorMessage` cho lỗi API; catch kết quả chưa xác định | `FIXED_VERIFIED` | U: số dư bằng/vượt, server 409, message tiếng Việt và key; W: vượt số dư không POST; chưa giao dịch thật |
| TC_CreateOrder_05 | SĐT khách chỉ kiểm tra không rỗng | Chặn chuỗi không phải 10–11 chữ số trước bước tiếp theo; không thêm quy tắc nhà mạng/prefix | `FIXED_VERIFIED` | U: dưới 10, chữ, quá 11, số hợp lệ đi tới validate tiếp theo |
| TC_CreateOrder_06 | Menu dropdown nền primary navy, chữ `Brand.ink` tối | Menu nền `Brand.surface`, giữ màu chữ và logic loại chuyến | `FIXED_NEEDS_DEVICE_TEST` | W: mở menu/chọn bao xe 7 chỗ, giữ selected type; cần kiểm tra thị giác trên máy |
| TC_CreateOrder_07 | Primary text gợi ý trắng trên canvas sáng | Primary text `Brand.ink`, giữ dữ liệu/autocomplete/onSelected | `FIXED_NEEDS_DEVICE_TEST` | W: gợi ý đọc được, chọn đúng placeId và địa chỉ; cần test autocomplete API thật |
| TC_CreateOrder_08 | Nhãn hướng dẫn trắng trên trắng; panel địa chỉ nền ink và nhiều chữ tối | Nhãn tối; panel surface sáng; subtitle và loading tương phản. Giữ nguyên tile URL, controller bản đồ, tọa độ, resolve và GPS | `FIXED_NEEDS_DEVICE_TEST` | Audit diff phần màu; chưa có bằng chứng native map/tile render ổn định |
| TC_CreateOrder_10 | DatePicker override `onPrimary` đen trên primary navy; thiếu style header cục bộ phù hợp | `onPrimary` trắng, theme/header rõ ràng, font 28/height 1.2; dùng date controller do provider quản lý | `FIXED_NEEDS_DEVICE_TEST` | W: mở DatePicker ở 390×844 không overflow, xác nhận và giữ ngày; cần cỡ chữ/locale/thiết bị QA |
| TC_CreateOrder_11 | State đã cập nhật nhưng chữ giờ trắng trên nền sáng; controller tạo lại mỗi build; tiêu đề hộp giờ tràn trên màn hẹp | Chữ giờ tối, controller có vòng đời trong provider, cập nhật trong setter; Expanded cho tiêu đề hộp giờ | `FIXED_VERIFIED` | U: thời gian/ISO và snapshot request; W: mở/Xong, binding giữ `09:05`, không overflow ở 390 px |
| TC_CreateOrder_13 | Request đã mang đủ thông tin, UI đã có các hàng nhưng nhiều giá trị trắng trên card sáng; không phải mất dữ liệu khi truyền màn hình | Sửa chữ các hàng thông tin/giá thành ink, card surface; giữ nguyên request và submit | `FIXED_VERIFIED` | U: địa chỉ/tên/SĐT/giá/note/groupId/date-time trong request; W: hiển thị đầy đủ các trường và màu chữ |

TC_Register_15 (Blocked, báo riêng): `FIXED_VERIFIED`. Kiểm tra mật khẩu trống trước strength regex, trả `Chưa nhập mật khẩu`; mật khẩu yếu vẫn bị chặn. U đã kiểm chứng cả hai trường hợp.

## File thay đổi trong đợt QA

Nguồn:

1. `lib/providers/driver/register_provider.dart`
2. `lib/providers/broker/order_form_provider.dart`
3. `lib/validation/withdrawal_validation.dart` (mới)
4. `lib/screens/driver/driver_register_screen.dart`
5. `lib/screens/driver/driver_home.dart` (phần rút tiền)
6. `lib/screens/driver/concert_ticket_scanner_screen.dart`
7. `lib/screens/chat_to_order/chat_group_list_screen.dart`
8. `lib/screens/driver/driver_booking_screen.dart`
9. `lib/screens/driver/driver_booking_confirm.dart`
10. `lib/screens/driver/driver_address_map_picker_screen.dart` (màu UI)

Tests: `test/qa_validation_test.dart`, `test/qa_screens_test.dart` (mới).

Báo cáo/evidence: `docs/qa-2026-11-13/report.md`, `docs/qa-2026-11-13/analyze.txt`, `docs/qa-2026-11-13/focused-tests.txt` (mới).

## Lệnh xác minh

```sh
flutter analyze --no-pub lib/providers/driver/register_provider.dart lib/providers/broker/order_form_provider.dart lib/screens/driver/driver_register_screen.dart lib/screens/driver/driver_booking_screen.dart lib/screens/driver/driver_booking_confirm.dart lib/screens/driver/driver_home.dart lib/screens/driver/concert_ticket_scanner_screen.dart lib/screens/driver/driver_address_map_picker_screen.dart lib/screens/chat_to_order/chat_group_list_screen.dart lib/validation/withdrawal_validation.dart test/qa_validation_test.dart test/qa_screens_test.dart

flutter test --no-pub test/qa_validation_test.dart test/qa_screens_test.dart test/driver_login_api_test.dart test/financial_command_test.dart test/concert_ticket_service_test.dart test/chat_realtime_test.dart
```

Không chạy test toàn dự án. Các lần chạy ban đầu phát hiện vấn đề của test harness (finder tooltip, mock secure storage, scroll/pump khi mở picker) và overflow thực của header chọn giờ; đã chỉnh và chạy lại bộ tập trung. Log được lưu là lần chạy hoàn tất sau cùng.

## Tồn đọng và việc QA cần làm

1. TC_Register_16: chủ sản phẩm tự thêm validate sau. Không áp dụng regex biển số tạm thời.
2. TC_Register_21: backend cần cung cấp precondition của `driver-register-ver2`, API khởi tạo/xác nhận email hoặc điện thoại, mã trạng thái/mã lỗi, và response mẫu cho tài khoản chưa xác minh. Phải xác định tài khoản đã được tạo hay chưa trước khi thiết kế CTA tiếp tục; không suy diễn từ thông báo lỗi và không dùng OTP reset password.
3. Kiểm tra 7 mục `FIXED_NEEDS_DEVICE_TEST` trên Android/iOS: đăng ký/header/status bar, soát vé/kết quả, QR camera, dropdown, gợi ý địa chỉ, bản đồ, DatePicker. Camera: cấp/từ chối quyền, Close, system Back, nhập thủ công, quét thành công, background/resume và mở lại scanner; kiểm tra chỉ báo camera tắt khi rời màn hình.
4. Bản đồ: tile tải được qua mạng thực, kéo ghim, resolve địa chỉ, điểm gợi ý và điểm tọa độ, GPS có/từ chối quyền; kiểm tra lại chia sẻ vị trí đang triển khai mà không đổi cơ chế.
5. Rút tiền trên môi trường QA: từng trường thiếu, số tiền sai/0/vượt/bằng số dư, số dư vừa thay đổi trên server, server từ chối/401/mất mạng/kết quả chưa xác định; không tạo yêu cầu trùng khi thao tác lại. Số dư client chỉ là feedback, server vẫn phải quyết định.
6. Đẩy đơn: đổi loại chuyến/số khách, chọn lại ngày giờ, font lớn/màn hình hẹp, quay lại từ xác nhận để sửa, kiểm tra payload tạo đơn và dữ liệu đơn sau submit thật.
7. Smoke test thiết bị: đăng nhập, chat realtime, QR, ví, GPS, nhận chuyến và hoàn thành chuyến. Bộ automated hiện không bao phủ E2E nhận/hoàn thành chuyến, quyền OS, native camera hay dịch vụ bản đồ thật; chưa có cơ sở khẳng định các phần này không regression.

Rủi ro còn lại: kiểu/cỡ chữ và system UI trên máy QA; quyền/lifecycle native camera; tile và autocomplete phụ thuộc mạng; số dư ví có thể thay đổi giữa lúc mở form và submit; contract xác minh đăng ký chưa có. Giữ nguyên kiểm tra server và luồng bảo mật hiện tại.
