# API GaviStore cho 3105

Ứng dụng được cấu hình gọi hai URL trên domain của bạn:

- Kiểm tra key: `POST https://gbao.infinityfreeapp.com/api/v1/check-key.php`
- Danh sách patch: `GET https://gbao.infinityfreeapp.com/repo.json`

## Cài API kiểm tra key

1. Sao lưu website hiện tại.
2. Tải toàn bộ nội dung trong `server/public/` lên thư mục gốc website (thường là `htdocs` hoặc `public_html`). Không ghi đè `dashboard.php`.
3. Trong thư mục `private/` vừa tải lên, sao chép `keys.json.example` thành `keys.json`.
4. Sửa `keys.json`: đặt `key` là key thật, `active` là `true`, `expires_at` là thời điểm hết hạn UTC theo ISO 8601. Đặt `device_limit` là `1` để chỉ cho một thiết bị; đặt `0` nếu không giới hạn. Không xóa `.htaccess`.
5. Nếu hosting không cho ghi `private/keys.json`, cấp quyền ghi cho PHP trên đúng file đó. Không cấp quyền ghi toàn bộ website.

API ghi mã thiết bị đầu tiên sử dụng key vào `devices`; lần kiểm tra sau từ cùng thiết bị tiếp tục hợp lệ. Thiết bị khác bị từ chối khi đã đạt `device_limit`. Khi người dùng đổi điện thoại, quản trị viên có thể xóa mã cũ khỏi `devices`.

**Lưu ý bảo mật:** thư mục `private/` phải bị chặn truy cập trực tiếp bằng `.htaccess`. Hãy thử mở URL `/private/keys.json` trên trình duyệt; máy chủ phải trả 403/404, tuyệt đối không được hiển thị JSON.

## Đưa patch từ dashboard lên ứng dụng

`dashboard.php` hiện tại không có trong source upload nên chưa thể xác nhận nó lưu patch ở đâu, hay đã có API xuất danh sách hay chưa. Bản app này đọc chuẩn kho 3105 v1 từ `/repo.json`; nó không scrape giao diện HTML của dashboard.

- Mỗi patch phải là file `.3105` hợp lệ do 3105 tạo.
- Thêm một object vào mảng `packages` trong `repo.json` cho mỗi patch.
- Dùng `name` làm tên nút trên app.
- Dùng `tags` để nhóm patch thành các thư mục trong menu chọn thư mục.
- `download` là đường dẫn tương đối hoặc URL HTTPS đến file `.3105`.
- `sha256` phải là SHA-256 thật của file patch.
- Khai báo `supportedOS` đúng với phiên bản iOS hỗ trợ.

Ví dụ một mục patch:

```json
{
  "identifier": "patch-demo",
  "kind": "patch",
  "name": "Patch Demo",
  "author": "Gbao",
  "version": "1.0.0",
  "summary": "Mô tả ngắn patch.",
  "tags": ["Thư mục 1"],
  "download": "patches/patch-demo.3105",
  "sha256": "THAY_BANG_SHA256_64_KY_TU_CUA_FILE",
  "supportedOS": [
    { "minimum": "17.0", "maximum": "18.7.1" },
    { "minimum": "26.0", "maximum": "26.6.1" }
  ]
}
```

Ứng dụng dùng trình xác minh manifest, checksum và luồng import có sẵn của 3105. Chạm một lần vào ô patch là chọn; chạm lần nữa là bỏ chọn. Sau khi chọn, bấm **Tải patch** để nhập vào kho 3105. Để áp dụng hoặc khôi phục, mở **Kho patch đã tải** và dùng các thao tác xác nhận sẵn có trong 3105.

## Phần cần nối với dashboard hiện tại

API trên là giao ước mẫu độc lập. Nó chưa tự đọc database hiện có của `dashboard.php`. Muốn quản lý key trực tiếp từ dashboard đang dùng và để dashboard tự xuất danh sách patch theo thư mục, cần có source của `dashboard.php` cùng file PHP/SQL mà nó đang dùng. Không nên tự thay thế dashboard hay đoán tên bảng dữ liệu.

Liên kết nhóm Telegram và Zalo cũng chưa có trong thông tin được cung cấp; hiện app hiển thị hai thẻ chờ cấu hình, chưa gắn URL giả.
