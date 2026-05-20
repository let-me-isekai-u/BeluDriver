README - Tiếng Việt

Thư mục `features` là lớp tổ chức mới theo từng nhóm chức năng.

Mục đích:
- Giữ import gọn hơn bằng cách tạo các file `barrel` để `export` lại screen / provider / model.
- Giúp người mới vào dự án đọc code theo nghiệp vụ thay vì phải lần từng thư mục `screens`, `providers`, `models`.

Thư mục con:
- `auth/`: nhóm đăng nhập, đăng ký, quên mật khẩu, splash.
- `chat/`: nhóm chat.
- `driver/`: nhóm màn hình và provider của driver.
- `kyc/`: nhóm KYC.
- `routes/`: nhóm đăng ký tuyến.

Lưu ý:
- Hiện tại đây chủ yếu là lớp `export`, chưa thay thế hoàn toàn cấu trúc cũ.

README - English

The `features` folder is a newer feature-based organization layer.

Purpose:
- Keep imports cleaner by using barrel files that re-export screens, providers, and models.
- Help new developers read the codebase by business domain instead of browsing separate `screens`, `providers`, and `models` folders.

Subfolders:
- `auth/`: login, registration, forgot password, splash.
- `chat/`: chat-related functionality.
- `driver/`: driver screens and providers.
- `kyc/`: KYC-related functionality.
- `routes/`: route registration.

Note:
- This is currently mostly an export layer and does not fully replace the older structure yet.
