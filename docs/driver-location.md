# Chia sẻ vị trí khi làm việc

Triển khai 2026-11-12. Tài xế app tự bật/tắt ở Trang chủ, không tự bật tài khoản mới. Chỉ quản trị hệ thống role 4 xem được bản đồ tổng quan; giữ latest point, không route history. Backend migration 014 phải áp trước app mới. Contract đầy đủ ở repository backend: `docs/api/fleet-map.md`, ADR 0010.

- `lib/features/driver_location/driver_gps_tracker.dart`: singleton theo phiên đăng nhập, Geolocator stream, Android foreground notification/iOS background location. Giữ một điểm mới nhất trong RAM, gửi 10 giây, lấy mẫu mới khi đứng yên; không đổi timestamp cũ thành thời gian hiện tại.
- `driver_location_api.dart`: JWT qua ChatSession (có refresh), GET/PUT `/api/driver/location/sharing`, POST `/api/driver/location`; identity do server xác định. Bật lấy stream ID mới; tắt/đổi stamp vô hiệu upload trễ. Server không đồng ý chia sẻ thì không thu thập.
- Home restore chỉ khi server đang bật; tab khác không dừng GPS. Logout/delete dừng trước khi xóa token; unmount Home dừng local. Late enable sau logout được bù bằng OFF dùng token tài khoản cũ, tránh đổi tài khoản khác.
- GPS Nhà xe vẫn thuộc `features/carrier_vehicle`, dùng QR xe + Run như cũ, không JWT tài xế thường. QR định danh xe, không định danh người lái.

Kiểm thử: `flutter test test/driver_location_test.dart` (7 tests), analyze các file sửa; release APK build pass 12/11. Chưa test thực địa Android/iOS, background/force-kill hoặc publish store. OS có thể ngắt GPS: bản đồ phải chuyển stale thay vì giả heartbeat. iOS Info.plist có location background mode và mô tả quyền; Android manifest đã có foreground location + notification permissions. Không yêu cầu theo dõi khi đã OFF.
