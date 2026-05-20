README - Tiếng Việt

Thư mục `assets` chứa tài nguyên giao diện đang được app sử dụng.

Thành phần:
- `animations/`: file animation JSON.
- `icons/`: icon, logo, hình nhỏ dùng trong UI.
- `sample_car.png`: ảnh mẫu xe.
- `summer_splash.png`: ảnh splash đang được dùng.
- `tet_splash.png`: ảnh splash theo mùa hoặc chủ đề khác.

Lưu ý:
- Thư mục này đang đặt trong `lib/assets`, không phải `assets/` ở root project.
- Khi đổi tên hoặc di chuyển file cần cập nhật lại `pubspec.yaml` và các chỗ `Image.asset`.

README - English

The `assets` folder contains UI resources used by the app.

Contents:
- `animations/`: JSON animation files.
- `icons/`: icons, logos, and small UI images.
- `sample_car.png`: sample car image.
- `summer_splash.png`: currently used splash image.
- `tet_splash.png`: alternate seasonal splash image.

Notes:
- This folder is inside `lib/assets`, not the root-level `assets/` folder.
- If a file is renamed or moved, update both `pubspec.yaml` and all `Image.asset` references.
