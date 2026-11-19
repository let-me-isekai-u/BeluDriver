# Chia sẻ vị trí khi làm việc

Triển khai 2026-11-12. Tài xế app tự bật/tắt ở Trang chủ, không tự bật tài khoản mới. Chỉ quản trị hệ thống role 4 xem được bản đồ tổng quan; giữ latest point, không route history. Backend migration 014 phải áp trước app mới. Contract đầy đủ ở repository backend: `docs/api/fleet-map.md`, ADR 0010.

- `lib/features/driver_location/driver_gps_tracker.dart`: singleton theo phiên đăng nhập, Geolocator stream, Android foreground notification/iOS background location. Giữ một điểm mới nhất trong RAM, gửi 10 giây, lấy mẫu mới khi đứng yên; không đổi timestamp cũ thành thời gian hiện tại.
- `driver_location_api.dart`: JWT qua ChatSession (có refresh), GET/PUT `/api/driver/location/sharing`, POST `/api/driver/location`; identity do server xác định. Bật lấy stream ID mới; tắt/đổi stamp vô hiệu upload trễ. Server không đồng ý chia sẻ thì không thu thập.
- Home restore chỉ khi server đang bật; tab khác không dừng GPS. Logout/delete dừng trước khi xóa token; unmount Home dừng local. Late enable sau logout được bù bằng OFF dùng token tài khoản cũ, tránh đổi tài khoản khác.
- GPS Nhà xe vẫn thuộc `features/carrier_vehicle`, dùng QR xe + Run như cũ, không JWT tài xế thường. QR định danh xe, không định danh người lái.

## Xin quyền và bật GPS từ công tắc (19/11/2026)

Công tắc ở Trang chủ chỉ có nhãn “Chia sẻ vị trí khi làm việc”, không kèm mô tả trạng thái khi bật/tắt. Chỉ hiện thông báo lỗi khi có lỗi cần xử lý.

Khi tài xế chủ động bật công tắc, app kiểm tra quyền và yêu cầu quyền vị trí qua hộp thoại hệ điều hành nếu chưa được cấp. Nếu quyền đã bị từ chối vĩnh viễn, app hỏi mở Cài đặt ứng dụng để cấp lại quyền. Khi đã có quyền nhưng dịch vụ vị trí đang tắt, app hỏi mở Cài đặt vị trí để bật GPS; không chỉ hiện dòng báo lỗi.

Sau khi quay lại từ Cài đặt, app kiểm tra lại cả quyền và GPS rồi tiếp tục yêu cầu bật chia sẻ. Hủy hộp thoại hoặc quay lại mà chưa cấp quyền/bật GPS giữ công tắc tắt; không mở hộp thoại lặp vô hạn. Rời màn hình hoặc dừng phiên khi đang mở Cài đặt hủy ý định bật còn chờ. Khôi phục tự động khi mở Trang chủ không tự xin quyền hoặc mở Cài đặt. Chỉ thu thập/gửi GPS sau khi đủ điều kiện thiết bị và máy chủ trả stream chia sẻ.

Kiểm thử hồi quy: `flutter test test/driver_location_test.dart test/driver_location_setup_test.dart`; ca mới kiểm quyền chưa cấp, từ chối, từ chối vĩnh viễn, GPS tắt, hủy, quay lại từ Cài đặt, thoát màn hình/dừng phiên và lỗi mở Cài đặt. Các ca nền/force-kill và iOS vẫn cần kiểm thực địa như giới hạn bên dưới.

Ngày 19/11/2026, 18/18 kiểm thử đạt và phân tích mã không báo lỗi. Bản release 1.2.7 trên Android 15 hiển thị hộp hỏi khi GPS tắt và tự bật chia sẻ sau khi bật GPS rồi quay lại. Hủy hoặc quay lại khi GPS vẫn tắt giữ công tắc tắt. Khi thu hồi quyền, Android hiện hộp xin quyền. Từ chối giữ công tắc tắt. Sau khi chọn không hỏi lại, app mở Cài đặt ứng dụng theo xác nhận của tài xế, rồi tự bật chia sẻ khi quyền được cấp và tài xế quay lại. Ngày 20/11/2026, bộ kiểm thử vẫn đạt 18/18 sau khi bỏ hai dòng mô tả và đã xác nhận giao diện mới trên điện thoại.

Kiểm thử: `flutter test test/driver_location_test.dart` (7 tests), analyze các file sửa; release APK build pass 12/11. Chưa test thực địa Android/iOS, background/force-kill hoặc publish store. OS có thể ngắt GPS: bản đồ phải chuyển stale thay vì giả heartbeat. iOS Info.plist có location background mode và mô tả quyền; Android manifest đã có foreground location + notification permissions. Không yêu cầu theo dõi khi đã OFF.
