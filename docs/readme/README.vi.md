<h1 align="center">HotkeyDetective</h1>

<p align="center">
  <strong>Tìm ra ứng dụng nào đã chiếm phím tắt của bạn.</strong><br>
  macOS không cho cách nào để hỏi. Công cụ này thì có.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-000?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="MIT">
</p>

<p align="center">
  <strong>Ngôn ngữ:</strong>
  <a href="../../README.md">English</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.it.md">Italiano</a> ·
  <a href="README.pt-BR.md">Português</a> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.ar.md">العربية</a> ·
  <a href="README.th.md">ไทย</a> ·
  <a href="README.tr.md">Türkçe</a> ·
  <strong>Tiếng Việt</strong>
</p>

---

Bạn nhấn ⇧⌘4 và không có gì xảy ra. Một ứng dụng nào đó đã chiếm nó — nhưng là ứng dụng nào? macOS không có API nào trả lời điều này, và Cài đặt Hệ thống cũng không cho biết.

HotkeyDetective thu thập bằng chứng, đưa ra kết luận và trình bày luôn lập luận:

<p align="center">
  <img src="../images/verdict.png" alt="HotkeyDetective" width="420">
</p>

## Cách hoạt động

Không có nguồn duy nhất nào cho biết «ai sở hữu phím tắt này», nên ứng dụng thu thập nhiều tín hiệu độc lập và cân nhắc chúng:

| Nguồn | Chứng minh điều gì | Độ mạnh |
| --- | --- | --- |
| **Phím tắt hệ thống** | Bảng của chính macOS gán tổ hợp này | Chắc chắn |
| **Cấu hình ứng dụng** | Tệp cài đặt của một ứng dụng đã biết gán tổ hợp này | Cao (thấp nếu ứng dụng chưa chạy) |
| **Quét cấu hình** | Cài đặt của ứng dụng khớp với một định dạng lưu trữ đã biết | Trung bình |
| **Phản hồi** | Ngay sau khi nhấn phím, một ứng dụng mở cửa sổ hoặc chuyển lên trước | Cao |
| **Dò phím nóng** | Một tiến trình đang giữ đăng ký phím nóng Carbon | Chỉ là quan sát |

Kết luận là `xác nhận`, `có thể`, `xung đột`, `bị chiếm nhưng không xác định được` hoặc `trống`. Mọi khẳng định đều kèm bằng chứng, nên bạn tự đánh giá thay vì tin vào một hộp đen.

Có một phân biệt quan trọng: **phản hồi** chứng minh ứng dụng đã *nhận* phím, chứ không phải đã *đăng ký* phím. Phản hồi có thể củng cố cho chủ sở hữu nhưng không bao giờ phản bác được. Thiếu quy tắc này, ⌘Space sẽ bị hiểu là «hệ thống và Spotlight đang tranh nhau» dù chẳng có gì sai.

## Cài đặt

Yêu cầu macOS 14 trở lên.

```bash
git clone https://github.com/goodbug89/hotkey-detective.git
cd hotkey-detective
Scripts/bundle.sh
open build/HotkeyDetective.app
```

Bản dựng sẽ ký bằng chứng chỉ Developer ID nếu keychain có, nếu không thì ký ad-hoc. Bản ad-hoc mất quyền sau mỗi lần dựng lại — xem [BUILDING.md](../../BUILDING.md).

## Quyền

Việc dò cần cả **Trợ năng** lẫn **Giám sát nhập liệu**. macOS yêu cầu cả hai cho một event tap bàn phím chỉ-nghe.

Thao tác phím chỉ được quan sát, không bao giờ bị chặn, ghi log hay lưu lại. Tap được tạo với `.listenOnly` nên chủ sở hữu thật vẫn nhận được phím — đó chính là cách phát hiện phản hồi hoạt động. Sau khi dò, dữ liệu phím còn lại chỉ là đúng tổ hợp bạn đã tra. Kho mã này không có mã mạng nào.

Không có quyền, ứng dụng vẫn chạy ở **chế độ giới hạn**: chọn tổ hợp thủ công và câu trả lời chỉ dựa trên tệp cài đặt.

## Giới hạn đã biết

- **Dò phím nóng Carbon không thấy tiến trình khác.** `RegisterEventHotKey` chỉ báo xung đột trong chính tiến trình của bạn, nên kết luận «bị chiếm nhưng không xác định được» gần như không thể xảy ra. Ứng dụng đăng ký phím nóng, không hiện cửa sổ và lưu cấu hình ở định dạng lạ sẽ vẫn vô hình.
- **Tên chức năng hệ thống là tiếng Anh, trừ tiếng Hàn.** macOS giữ bản dịch riêng ở nơi chúng tôi không đọc được, và tự dịch sẽ lệch với những gì bạn thấy trong Cài đặt Hệ thống.
- **Quét cấu hình chỉ nhận hai định dạng lưu trữ** (thư viện `KeyboardShortcuts` và từ điển kiểu `MASShortcut`). Ứng dụng dùng định dạng riêng cần bộ phân tích riêng — [rất hoan nghênh đóng góp](../../CONTRIBUTING.md).

## Ai phát triển

HotkeyDetective được xây dựng bởi nhóm phát triển **[Unifyl](https://unifyl.app)**, trình quản lý tệp hai khung cho macOS.

## Giấy phép

MIT — [LICENSE](../../LICENSE)

