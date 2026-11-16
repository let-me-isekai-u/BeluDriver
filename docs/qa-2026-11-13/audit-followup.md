# BELUDRIVER — audit bổ sung và sửa code, 13/11/2026

Phạm vi: `/Users/nhatanhly/beludriver_app`, remote `let-me-isekai-u/BeluDriver`, baseline HEAD `7823938`. Working tree sạch trước lần sửa này. Chỉ đọc sheet **Tài xế Đông Dương**, vùng A1:I100 của `/Users/nhatanhly/Downloads/Test app belucar.xlsx`; không sửa Excel gốc hoặc repository Belucar_app.

Đã đọc đủ tình huống, điều kiện, bước test, dữ liệu, kỳ vọng, thực tế và trạng thái cho **98 test case**: 91 Pass, 5 Fail, 1 Blocked, 1 chưa có trạng thái. Có **21 dòng Pass khác kỳ vọng sau khi chuẩn hóa khoảng trắng**; bảng dưới xét cả các khác biệt chỉ về cách diễn đạt. Không lấy trạng thái Pass làm bằng chứng đã chạy đạt.

**FIXED IN CODE** chỉ mô tả thay đổi nguồn trong lần này. **NEEDS RETEST** là trạng thái QA của mọi thay đổi và các sửa có sẵn. Không chạy Flutter test, analyze, build, run hoặc điều khiển thiết bị/simulator. Các kết quả test/analyze trong `report.md`, `focused-tests.txt`, `analyze.txt` cùng thư mục thuộc đợt cũ, không chứng minh cho diff hiện tại.

## Các sửa mới

| Case / phạm vi | Phân loại | Nguyên nhân và sửa | Trạng thái |
|---|---|---|---|
| TC_Work_13, TC_Work_15 | Confirmed by code | Chi tiết chỉ xét `status < 4`, không phân biệt người tạo và người được phân công; trạng thái 0/1 còn có thể rơi vào nhánh hoàn thành. Đối chiếu `(rideId, rideSource, status)` với API chuyến của tài xế hiện tại; chỉ cho bắt đầu ở 2, hoàn thành ở 3. Áp dụng cả hiển thị và lớp gửi lệnh dùng chung cho API v1/v2, gồm đường gọi từ Hoạt động. Kiểm tra lại quyền trước mỗi lệnh, chặn thao tác đồng thời trên cùng chuyến. Không cấp quyền từ danh sách đơn đã đẩy. | FIXED IN CODE; NEEDS RETEST với A/B và cả hai nguồn đơn |
| TC_Authenlication_01 | Confirmed by code | HTTP thông thường không refresh; chat tự refresh riêng và khóa vĩnh viễn lần refresh sau lỗi; Splash từng xóa phiên khi refresh lỗi mạng/5xx. Thêm bộ điều phối chung, gộp refresh đồng thời, lưu cặp token bằng compare-and-rotate trong hàng đợi Secure Storage; chặn response cũ khôi phục/xóa phiên mới. Retry request đọc tối đa một lần; 401/403 của refresh hoặc 401 sau retry đọc kết thúc phiên và xóa stack về login. Lỗi mạng/5xx/phản hồi token sai cấu trúc giữ phiên và cho thử lại. | FIXED IN CODE; NEEDS RETEST; cần backend xác nhận các mã từ chối khác 401/403 |
| TC_Profile_05 | UI inconsistency | Popup vẫn dùng bảng xanh lá/vàng cũ, không có Close; nút xóa trắng trên nền sáng khi đổi concept. Dùng token Brand, thêm nút đóng có tooltip, footer tự xuống hàng khi hẹp; giữ số tỉnh, tuyến và payload hiện tại. | FIXED IN CODE; NEEDS RETEST |
| TC_Profile_02 và màn lịch sử rút tiền liên quan | UI inconsistency | Lịch sử tài chính hiện đã dùng concept navy/surface; chuẩn hóa màu thu/chi về Brand. Lịch sử rút tiền còn số tiền/thông tin trắng trên b50 và subtitle tối trên hero navy: đổi màu theo nền. | FIXED IN CODE; NEEDS RETEST |
| TC_Home_07, trạng thái rỗng/lỗi | UI inconsistency | Back đã có sẵn và tương phản đúng; tiêu đề empty/error còn trắng trên canvas sáng. Đổi các tiêu đề này về Brand.ink. | FIXED IN CODE; NEEDS RETEST |
| Tạo đơn — chặn gửi lặp | Confirmed by code | Hàm xác nhận chưa có guard khi đã gửi, chỉ dựa vào việc nút rebuild. Thêm guard `_isCreatingRide` ở đầu action. | FIXED IN CODE; NEEDS RETEST |
| Audit phiên QR xe độc lập | Confirmed by code | Refresh xe trả false cho mọi lỗi, khiến 5xx/mất mạng xóa phiên xe. Chỉ kết thúc phiên khi refresh bị 401/403; lỗi tạm thời giữ phiên, gộp refresh đồng thời và kiểm tra phiên trước khi retry. Giữ endpoint/payload/session token riêng, không đưa JWT tài xế vào luồng xe. | FIXED IN CODE; NEEDS RETEST |
| Audit log xác thực | Confirmed by code | API v1/v2 ghi trực tiếp mật khẩu cũ/mới; decoder/body/header log có thể lộ thông tin xác thực; FCM ghi device token. Bỏ các log này, giữ thông tin trạng thái phục vụ chẩn đoán. | FIXED IN CODE; NEEDS RETEST log trên bản QA |

### Quyền chuyến và giới hạn client

`RideDetailModel` hiện không ánh xạ `driverId`/người tạo/người nhận; `rideSource` phân biệt nguồn/phiên bản đơn, không phải role. Chat đã có hai trường riêng `createdDriverId` và `acceptedDriverId`, chứng minh cần tách hai vai trò, nhưng không có bằng chứng rằng response chi tiết dùng cùng schema. Không tự thêm key hoặc suy diễn `driverId` là người thực hiện.

Client dùng contract đang có trong `ActivityHistoryProvider`: `/api/driverapi/ride-confirmed` là đơn tài xế hiện tại đã nhận, `/api/driverapi/ride-process` là đơn đang thực hiện. Danh sách trả `success/data`, định danh `rideId` hoặc `id`, `rideSource` và `status`. Giữ fallback nguồn 1 như model hiện tại; nguồn không được hỗ trợ và dữ liệu thiếu/không xác minh được không được cấp quyền. Người tạo vẫn đọc chi tiết bình thường. Khi API phân quyền không tải được, nội dung chi tiết vẫn hiển thị nhưng nút thực hiện không được bật; tải lại để xác minh.

Kiểm tra client không thay thế phân quyền backend. Backend phải kiểm tra JWT của người thực hiện và trạng thái tại thời điểm cập nhật nguyên tử. TC_Work_14/16 ghi server đã trả “Bạn không phải tài xế”, nhưng chưa có kiểm thử lại cho cả hai endpoint, nguồn đơn và tình huống đổi người nhận giữa lúc xem và thao tác.

### Token, retry và tài chính

Giữ cấu hình Keychain/Keystore, migration plaintext cũ, tombstone và phiên xe độc lập. Bổ sung đọc cặp token nguyên tử, rotate/clear có so sánh cặp hiện tại, dùng chung hàng đợi với login/logout. TokenProvider của chat/SignalR dùng cùng bộ điều phối với HTTP. Các REST v1/v2, KYC, chat và soát vé đi qua transport xác thực chung; không thay contract endpoint/payload.

Refresh dùng contract hiện có: `POST /api/accountdriverapi/refresh-token`, JSON `refreshToken`, response cấp gốc gồm `accessToken` và `refreshToken`. Không giả định response bọc `data`. Request đọc GET/HEAD và POST lịch sử rút tiền được phát lại đúng một lần sau refresh thành công. Nếu request đọc retry vẫn 401 thì kết thúc phiên. HTTP 403 của request nghiệp vụ không tự logout.

**Không tự retry POST/PUT/PATCH/DELETE nghiệp vụ**, kể cả có Idempotency-Key, do chưa xác minh bảo đảm idempotency server. Sau 401 và refresh thành công, client trả lỗi có hướng dẫn kiểm tra trạng thái trước khi thử lại; không giả báo giao dịch thành công. Giữ key lệnh tài chính qua các lần token rotation để lần thử lại do người dùng chủ động không đổi key chỉ vì token mới. Không retry khi timeout/5xx. Cơ chế refresh/retry riêng của xe nhà xe giữ contract đang có, không dùng refresh token tài khoản tài xế.

## P1 đã có xử lý trong baseline — không ghi công sửa mới

| Case | Bằng chứng code hiện tại | Phân loại / trạng thái |
|---|---|---|
| TC_Register_15 | `RegisterProvider.validateField` xét mật khẩu rỗng trước strength regex. | Confirmed by code: logic hiện đã xử lý; NEEDS RETEST |
| TC_Register_17, TC_Register_19 | Có thông báo riêng khi trường nhập lại trống, trước so sánh không khớp. | Confirmed by code: logic hiện đã xử lý; NEEDS RETEST |
| TC_CreateOrder_05 | `OrderFormProvider.validate` chặn dữ liệu không gồm đúng 10 chữ số trước bước xác nhận. Không thay giới hạn này trong lần sửa. | Confirmed by code: logic hiện đã xử lý; NEEDS RETEST; contract backend về độ dài vẫn cần đối chiếu |
| TC_CreateOrder_11 | Controller ngày/giờ thuộc provider, setter cập nhật text; trường giờ dùng Brand.ink. | Confirmed by code: logic hiện đã xử lý; NEEDS RETEST |
| TC_CreateOrder_13 | Request giữ tên/SĐT/địa chỉ/loại/số lượng/ngày giờ/ghi chú/giá; xác nhận có các hàng chữ tối trên card sáng. | Confirmed by code: logic hiện đã xử lý; NEEDS RETEST |
| TC_Home_12, TC_Home_15 | Validator rút tiền phân biệt thiếu tiền/ngân hàng/STK/tên và vượt số dư; hiển thị inline, return trước API; giữ phản hồi server. | Confirmed by code: logic hiện đã xử lý; NEEDS RETEST trên môi trường QA |
| TC_Register_01 | Header đăng ký hiện dùng chữ tối và Back navy trên nền sáng, form cuộn theo bước. | UI inconsistency: sửa có sẵn; NEEDS RETEST |
| TC_Home_03, TC_Home_05 | Header có Back tương phản; màn camera có Close và đường quay về nhập mã; controller camera vẫn do plugin quản lý. | UI inconsistency: sửa có sẵn; NEEDS RETEST quyền/lifecycle native |
| TC_CreateOrder_06/07/08/10 | Menu surface/chữ ink, gợi ý địa chỉ chữ tối, panel bản đồ sáng, date picker header navy/chữ trắng. | UI inconsistency: sửa có sẵn; NEEDS RETEST trên thiết bị, bàn phím và cỡ chữ lớn |

## Toàn bộ 21 dòng PASS khác kỳ vọng

| Case | Kết luận audit |
|---|---|
| TC_Register_01 | UI inconsistency; sửa có sẵn, NEEDS RETEST. |
| TC_Register_16 | Confirmed by code: thiếu validation định dạng, mới kiểm tra không rỗng. Chưa sửa regex do thiếu quy tắc được backend chấp nhận; UNVERIFIED cho từng mẫu, cần phối hợp backend. |
| TC_Register_17 | Logic hiện xử lý trống trước mismatch; NEEDS RETEST. |
| TC_Register_19 | Logic hiện xử lý trống trước mismatch; NEEDS RETEST. |
| TC_Register_21 | Test expectation issue so với luồng hiện tại: đăng ký đã có bước yêu cầu challenge và nhập OTP trước gửi đăng ký, không còn chờ đăng ký xong mới xác minh. Chưa xác minh live API; NEEDS RETEST luồng hiện có. |
| TC_Home_03 | UI inconsistency; Back và màu đã sửa sẵn; NEEDS RETEST. |
| TC_Home_05 | UI inconsistency; Close camera có sẵn; NEEDS RETEST camera thật. |
| TC_Home_07 | Back có sẵn; lần này sửa thêm chữ trạng thái rỗng/lỗi; NEEDS RETEST. |
| TC_Home_12 | Validator và lỗi inline có sẵn; NEEDS RETEST. |
| TC_Home_15 | Chặn vượt số dư và thông báo server có sẵn; NEEDS RETEST. |
| TC_CreateOrder_05 | Validate đúng 10 chữ số có sẵn; NEEDS RETEST. |
| TC_CreateOrder_06 | UI inconsistency; menu sáng có sẵn; NEEDS RETEST. |
| TC_CreateOrder_07 | UI inconsistency; chữ gợi ý tối có sẵn; NEEDS RETEST. |
| TC_CreateOrder_08 | UI inconsistency; màu panel có sẵn; tải tile/resolve bản đồ UNVERIFIED. |
| TC_CreateOrder_09 | UNVERIFIED: “GPS có vẻ đúng” không xác nhận được độ chính xác. Không đổi logic GPS. |
| TC_CreateOrder_10 | UI inconsistency; màu DatePicker có sẵn; NEEDS RETEST. |
| TC_CreateOrder_11 | Binding/controller/màu giờ có sẵn; NEEDS RETEST. |
| TC_CreateOrder_13 | Thông tin xác nhận có sẵn; NEEDS RETEST. |
| TC_CreateOrder_17 | Khác cách diễn đạt, kết quả thực tế phù hợp kỳ vọng chặn nhận đơn đã hủy; không có bằng chứng lỗi client. Cần cập nhật mô tả test; chưa xác minh race trên server. |
| TC_Work_14 | Khác cách diễn đạt, server từ chối người không phải tài xế đúng kỳ vọng. Client nay chặn sớm nên nên cập nhật bước test: kiểm tra không gửi lệnh từ UI, kiểm tra server riêng trong môi trường QA. |
| TC_Work_17 | UNVERIFIED: thực tế không ghi rõ ví người tạo có được cộng hay không. Không thể kết luận thiếu tiền hay đúng logic từ dòng này; cần đối soát backend hai ví/lịch sử trên môi trường QA. |

TC_ForgetPassword_04 (row 12) chưa có kỳ vọng/thực tế/trạng thái; TC_CreateOrder_02 (row 53) đánh Pass nhưng thiếu kỳ vọng/thực tế: **UNVERIFIED**, không dùng để kết luận layout tốt. 70 dòng Pass còn lại không có chênh lệch nội dung sau chuẩn hóa khoảng trắng; chưa tái hiện trên thiết bị, không tự nâng thành PASS của lần audit này. TC_Work_16 phù hợp kỳ vọng server từ chối người tạo, nhưng vẫn cần hồi quy sau thay đổi guard.

### Biển số — TC_Register_16

Chưa có OpenAPI/rule validation biển số trong repository. Endpoint Swagger công khai thử đọc trả 404, không cung cấp thêm schema. Không dùng quy định pháp lý hoặc một regex suy đoán để giới hạn loại xe/tỉnh/series/biển cũ. Không coi mọi mẫu tester ghi là chắc chắn sai, cũng không bỏ bước xác minh email. Backend cần xác nhận chuẩn hóa dấu cách/dấu gạch/dấu chấm, biển 4/5 số, loại xe và series được hỗ trợ, cùng response validation. Sau đó đặt validator trước `requestRegistrationChallenge`/`register` (hai đường đã gọi `validateAllFields`), phân biệt trống/sai định dạng. **Case này chưa được sửa định dạng.**

## File đã sửa trong lần này

Nguồn:

- `lib/main.dart`
- `lib/providers/driver/ride_detail_provider.dart`
- `lib/screens/driver/ride_detail_screen.dart`
- `lib/screens/driver/driver_booking_confirm.dart`
- `lib/screens/driver/wallet_history_screen.dart`
- `lib/screens/driver/withdrawal_history_screen.dart`
- `lib/screens/register_route/register_route_popup.dart`
- `lib/screens/chat_to_order/chat_group_list_screen.dart`
- `lib/screens/splash_screen.dart`
- `lib/services/session_auth.dart` (mới)
- `lib/services/driver_auth_client.dart` (mới)
- `lib/services/token_storage.dart`
- `lib/services/api_service.dart`
- `lib/services/v2/api_service.dart`
- `lib/services/api_response.dart`
- `lib/services/api_chat_service.dart`
- `lib/services/chat_session.dart`
- `lib/services/concert_ticket_service.dart`
- `lib/services/kyc_service.dart`
- `lib/services/firebase_notification_service.dart`
- `lib/features/carrier_vehicle/carrier_vehicle_service.dart`

Test chuẩn bị, **chưa chạy**:

- `test/qa_session_and_permissions_test.dart` (mới): đồng thời 401, retry một lần, refresh từ chối/5xx/mất mạng, phiên mới không bị ghi đè, financial key qua rotation và không replay lệnh, quyền nguồn/trạng thái chuyến, phiên xe giữ khi 5xx.
- `test/support/driver_session_fixture.dart` (mới): Secure Storage giả trong bộ nhớ, không gọi máy chủ thật.
- `test/financial_command_test.dart`, `test/concert_ticket_service_test.dart`, `test/chat_realtime_test.dart`, `test/qa_validation_test.dart`: bổ sung session fixture do transport mới đọc credential thực qua TokenStorage.

Không thay Bundle ID/Application ID/signing/dependencies/backend; không pull/merge/rebase/reset/commit/push. Không tạo tài khoản, tạo đơn, quét check-in hay thực hiện giao dịch thật.

## Backend cần phối hợp

1. Xác nhận `ride-confirmed`/`ride-process` chỉ trả chuyến mà JWT hiện tại là người thực hiện; nguồn 1/2 và status 2/3 phải nhất quán. Nếu danh sách phân trang/thay schema, cần cung cấp contract. Danh sách lỗi/thiếu dữ liệu hiện giữ client ở trạng thái không cho thao tác.
2. Kiểm tra phân quyền nguyên tử ở cả start/complete cho cả hai nguồn: người tạo A không được cập nhật chuyến B nhận; từ chối dữ liệu cũ, trạng thái kết thúc và cạnh tranh đổi người nhận. Không tin role/driverId do client gửi.
3. Xác nhận status/code refresh hết hạn, bị thu hồi và token rotation. Hiện tự kết thúc phiên trên 401/403; 400/422 không tự coi là thu hồi khi chưa có contract. Cần mẫu response token để kiểm chứng contract cấp gốc đang được dùng.
4. Xác nhận phạm vi, TTL và hành vi `Idempotency-Key`, lưu kết quả lệnh tài chính cùng giao dịch; client hiện không tự phát lại mutation sau refresh. Cung cấp cơ chế tra cứu kết quả tạo đơn/giao dịch trước khi thử lại sau timeout.
5. Cung cấp quy tắc biển số cho TC_Register_16. Xác nhận độ dài SĐT khách theo API, không tự đổi giới hạn hiện tại. Đối soát TC_Work_17, gồm ví người nhận và người tạo, trên dữ liệu QA.

## Checklist kiểm thử thủ công trên thiết bị

1. **Quyền A/B:** A tạo, B nhận đơn nguồn 2. A xem đủ thông tin nhưng không có Start/Complete ở các trạng thái 0–5. B chỉ thấy Start ở 2, Complete ở 3; hoàn thành vào lịch sử đúng. Hồi quy nguồn 1, tab Hoạt động và mở chi tiết từ các đường điều hướng khác. Tải lại sau thay đổi trạng thái/đổi tài xế; mất mạng khi kiểm tra quyền không được gửi mutation. Thử thao tác lặp nhanh. Kiểm thử server trực tiếp chỉ ở môi trường QA được cấp quyền.
2. **Phiên tài xế:** access token hết hạn + refresh còn hạn, mở đồng thời hồ sơ/đơn/ví/chat: chỉ một refresh, nội dung tải lại, cặp token mới tồn tại sau mở lại app. Refresh bị thu hồi: về Login và Back không quay vào dữ liệu cũ. Refresh lỗi mạng/5xx/response thiếu token: giữ phiên, có đường thử lại. Request đọc retry vẫn 401: không lặp refresh. Logout/login tài khoản khác trong lúc refresh đang chờ: response cũ không khôi phục/xóa phiên mới.
3. **Mutation và tiền:** chỉ dùng sandbox/QA. Token hết hạn lúc tạo đơn/rút tiền/nhận/bắt đầu/hoàn thành: không tự gửi lại lệnh; thông báo hướng dẫn kiểm tra trạng thái. Timeout/5xx và thử lại có kiểm tra kết quả; key tài chính giữ qua token rotation. Hồi quy thiếu từng trường rút tiền, số tiền sai/0/bằng/vượt số dư, số dư server thay đổi, lỗi server rõ ràng; không dùng tiền thật.
4. **Đăng ký:** bỏ trống mật khẩu, nhập lại SĐT/mật khẩu; xác nhận phân biệt trống/yếu/không khớp. Hồi quy bước challenge/email OTP có sẵn, đổi email/SĐT sau nhận mã, lỗi backend. TC_Register_16 vẫn mở và cần contract; không tuyên bố đã chặn đầy đủ mẫu biển số.
5. **Đẩy đơn:** SĐT 9/10/11 chữ số, số lượng 0/1, chọn loại chuyến, địa chỉ gợi ý/bản đồ, đổi ngày giờ, quay lại màn trước; giờ đã chọn và toàn bộ thông tin xác nhận phải còn đúng. Nhấn tạo liên tiếp không sinh lệnh song song; chỉ kiểm tra tạo thật trong QA.
6. **UI:** lịch sử tài chính/rút tiền (loading/rỗng/lỗi/nội dung dài); popup tuyến mở/tìm/chọn/xóa/đóng khi barrier không dismiss, gửi xong/timeout, màn hẹp/cỡ chữ lớn/bàn phím. Soát vé, QR camera cấp/từ chối quyền, Close/system Back/background-resume/mở lại; chỉ báo camera tắt khi rời màn. Nhóm chat có dữ liệu/rỗng/lỗi và Back. Dropdown/date picker/gợi ý địa chỉ/panel bản đồ đọc được; kiểm tra overflow khi bàn phím mở.
7. **Phiên QR xe:** access token xe hết hạn với session token còn hạn, nhiều request đồng thời; refresh 401/403 yêu cầu quét lại, mất mạng/5xx giữ phiên. Logout hoặc đổi xe khi request cũ còn chờ không làm tác vụ cũ chạy dưới phiên xe mới. Không dùng token tài xế để refresh phiên xe.

Kiểm tra trong lần này: parser qua `dart format --output=none` thành công trên cả 27 file Dart thay đổi (exit 0); `git diff --check` thành công (exit 0). `git status --short` của `/Users/nhatanhly/Belucar_app` vẫn rỗng. Chưa có bằng chứng type-check, runtime, render native hay QA PASS cho diff mới.
