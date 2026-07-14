# Kế Hoạch Nâng Cấp Floating Window (V2.0 - Premium Edition)

Mục tiêu của kế hoạch này là biến Floating Window từ một tiện ích hiển thị đẹp mắt trở thành một trải nghiệm **thực sự cao cấp (premium)**, có tính tương tác cao và thẩm mỹ sánh ngang với các sản phẩm như Apple Music hay Spotify.

## 1. 🎨 Khai Thác Màu Sắc Thông Minh (Dominant Color Extraction)
- **Vấn đề hiện tại:** Nền kính mờ và các hiệu ứng phát sáng (shadow, particles) đang dùng màu trắng/đen hoặc màu ngẫu nhiên.
- **Nâng cấp:** Tự động phân tích ảnh bìa Album (Thumbnail) để trích xuất ra 2-3 màu chủ đạo.
- **Ứng dụng:** 
  - Đổ màu Gradient phát sáng (Glow) xung quanh dòng chữ lời bài hát dựa trên màu Album.
  - Các hạt nốt nhạc bay lên (`FloatingNotesView`) sẽ có màu tệp với Album art thay vì random.
  - Mang lại cảm giác "đắm chìm" (immersive) hệt như Apple Music.

## 2. 🎤 Trải Nghiệm Lời Bài Hát (Karaoke-style Lyrics)
- **Word-by-word Sync:** Chuyển từ việc highlight cả câu sang highlight **từng chữ** theo thời gian thực (nếu API `lrclib` hỗ trợ định dạng lrc nâng cao).
- **Blur Fade-out:** Hiển thị 3 câu hát nhưng câu trên cùng và dưới cùng sẽ bị làm mờ (blur) và mờ dần (opacity), tạo hiệu ứng cuộn 3D sâu hơn.

## 3. 🖱️ Tương Tác Trực Tiếp (On-Window Controls)
- **Hover to Control:** Hiện tại cửa sổ nổi chỉ để xem. Sẽ thêm hiệu ứng: khi rê chuột (hover) vào khu vực Hộp nhạc, nó sẽ mở rộng ra (expand) để hiện các nút `Play/Pause`, `Next`, `Prev`.
- **Interactive Seek Bar:** Biến thanh tiến trình trên cửa sổ nổi thành dạng có thể click/kéo để tua bài trực tiếp mà không cần mở Menu Bar.

## 4. 🕹️ Hiệu Ứng Vật Lý (Fluid Physics & Dynamic Island)
- **Drag Tilt Physics:** Khi cầm cửa sổ kéo đi, cửa sổ sẽ hơi nghiêng nhẹ (tilt) theo hướng kéo, tạo cảm giác có trọng lượng.
- **Chế Độ Dynamic Pill:** Thêm tính năng nháy đúp (double-click) để thu gọn toàn bộ lời hát và hộp nhạc thành một "Viên thuốc" nhỏ xíu (giống Dynamic Island của iPhone) chỉ hiện sóng nhạc và tên bài hát.

## 5. 🐱 Nâng Cấp "Hệ Sinh Thái" Mèo Oneko
- **Nhiều tương tác hơn:** Cho phép click vào con mèo để nó kêu "Meow" (hiện bong bóng chat) hoặc vung vẩy vuốt.
- **Đổi Skin:** Chuột phải vào cửa sổ để đổi mèo thành các con vật khác (Chó ciba, Chim cánh cụt...).

---

> [!TIP]
> **Thứ tự ưu tiên khuyến nghị:** Nên bắt đầu làm tính năng **(1) Khai Thác Màu Sắc** và **(3) Hover Controls** trước vì hai tính năng này mang lại hiệu ứng Wow thị giác lớn nhất với effort vừa phải!
