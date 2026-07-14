# Kế Hoạch Lên Đời Giao Diện (GUI) Cho Audio Player Trên macOS

Chơi chán với giao diện Terminal (CLI) rồi, giờ là lúc chúng ta biến nó thành một **ứng dụng Desktop thực thụ cho Mac** với giao diện siêu mượt, xịn xò không kém gì Apple Music hay Spotify!

Dựa trên yêu cầu "đặc biệt cho Mac", tôi đề xuất sử dụng framework **Wails** (https://wails.io). Nó kết hợp sức mạnh xử lý âm thanh Backend của **Go** và giao diện Frontend bằng **Web Technologies (HTML/CSS/JS)**. Ứng dụng sẽ chạy bằng nhân WebKit siêu nhẹ của Apple, tạo ra một file `.app` cực chuẩn chỉ.

Dưới đây là Roadmap gồm 4 giai đoạn để thực hiện:

---

## 🚀 Giai Đoạn 1: Khởi tạo và Dịch chuyển Core (Backend)
Thay vì đập đi xây lại, chúng ta sẽ **tái sử dụng 90% bộ engine âm thanh** mà chúng ta đã cất công gọt dũa (cơ chế tải nhạc `yt-dlp`, xử lý sample rate, limiter chống rè của `beep`).
* **Bước 1.1:** Cài đặt Wails CLI và khởi tạo project mới: `wails init -n audio-gui -t vanilla`.
* **Bước 1.2:** Nhúng toàn bộ thư mục `internal/player` cũ vào project mới.
* **Bước 1.3:** Viết cầu nối (Bindings) trong file `app.go`. Các hàm Go sẽ được xuất (export) ra để giao diện có thể gọi được như: `PlayTrack(url)`, `Pause()`, `SetVolume(vol)`, `SearchYouTube(query)`.

---

## 🎨 Giai Đoạn 2: Xây Dựng Giao Diện Kính Mờ (Glassmorphism)
Đây là lúc để "WOW" người dùng. Thiết kế sẽ đi theo ngôn ngữ **Apple MacOS Native Design**.
* **Bước 2.1:** Thiết kế **Frameless Window** (Cửa sổ không viền, loại bỏ thanh tiêu đề mặc định, hỗ trợ kéo thả toàn bộ cửa sổ).
* **Bước 2.2:** Sử dụng CSS **Vibrant/Glassmorphism** (hiệu ứng kính mờ xuyên thấu) làm nền cho ứng dụng, thay đổi màu sắc dựa trên ảnh bìa (Thumbnail) của video YouTube đang phát.
* **Bước 2.3:** Tạo các Component UI cốt lõi bằng Vanilla HTML/CSS/JS (để kiểm soát mượt mà nhất):
  - Thanh Search Bar tích hợp hiệu ứng gõ phím.
  - Vùng hiển thị Thumbnail đĩa nhạc có khả năng xoay chầm chậm.
  - Thanh Progress bar mượt mà.
  - Các nút điều khiển Play/Pause/Next với micro-animations (nhún nhẹ khi click).

---

## 🔗 Giai Đoạn 3: Tích hợp Frontend & Backend
* **Bước 3.1:** Viết Javascript gọi các hàm Wails Bindings để kết nối UI với bộ não âm thanh Go.
* **Bước 3.2:** Thay thế `Visualizer` dạng ASCII bằng một bộ **Spectrum Visualizer** (sóng nhạc nhảy múa) render bằng thẻ `<canvas>` trên Web, lấy data tần số thực trực tiếp từ `beep`.
* **Bước 3.3:** Xử lý việc fetch ảnh Thumbnail của video YouTube (lấy từ metadata của `yt-dlp`) để đập thẳng lên giao diện.

---

## 🍎 Giai Đoạn 4: Tích Hợp Sâu Vào Hệ Sinh Thái macOS (Mac Exclusive)
Để chứng minh đây là một app "chuẩn Mac", ta sẽ thêm các "đồ chơi" đặc thù:
* **Bước 4.1:** Media Keys: Hỗ trợ các phím cứng Play/Pause/Next trên bàn phím MacBook (sử dụng thư viện CGO của Mac).
* **Bước 4.2:** Mac Notification Center: Hiện thông báo góc phải màn hình kiểu Mac mỗi khi chuyển bài hát (kèm ảnh Thumbnail video).
* **Bước 4.3:** Giữ lại tính năng Systray Menu Bar (biểu tượng trên thanh trạng thái) mà ta vừa làm, nhưng cho phép điều khiển nhạc từ đó khi thu nhỏ app!
* **Bước 4.4:** Đóng gói (Build) thành file `AudioPlayer.app` hoàn chỉnh với biểu tượng icon đàng hoàng. Dễ dàng ném vào thư mục `/Applications`.

---

### Bạn Thấy Sao?
Nếu bạn duyệt kế hoạch này, tôi sẽ hướng dẫn bạn chạy lệnh khởi tạo **Wails project** ngay và chúng ta sẽ bắt đầu đắp code cho **Giai đoạn 1**!
