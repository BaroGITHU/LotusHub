# LotusHub Modular — Tách từ `Menu.lua`

Bản tách source ngày **2026-11-09**. Phần giao diện, nội dung Gameplay và logic Match v3 lấy từ file `Menu.lua` do bạn cung cấp; **không thêm tính năng Gameplay mới**.

## Cấu trúc

```text
LotusHub/
├── run_all.lua                       # Entry point: import các module trong ZIP
├── run_all_standalone.lua            # Tùy chọn: một file, không cần readfile
├── modules/
│   ├── Menu.lua                      # Cửa sổ, sidebar, toggle, slider, nút tròn
│   ├── Gameplay.lua                  # Tab Gameplay + các state + SetModifiers
│   └── Gameplay/
│       └── Match.lua                # Startgame + Auto Active Auto Play (v3)
└── README.md
```

## Cách chạy

**Cách A — tách module (phù hợp lúc phát triển):** giải nén giữ nguyên thư mục `LotusHub` vào thư mục mà executor có thể đọc bằng `readfile`. Execute:

```lua
loadstring(readfile("LotusHub/run_all.lua"))()
```

Nếu thư mục khác, đặt biến đường dẫn trước khi Execute:

```lua
getgenv().LotusHubRoot = "TênThưMụcCủaBạn"
loadstring(readfile("TênThưMụcCủaBạn/run_all.lua"))()
```

Điều kiện: executor **phải có `readfile` và `loadstring`**, thư mục/module phải thực sự nằm trong vùng file mà executor truy cập được. Trên LDPlayer, không thể tự giả định đường dẫn file PC/Android sẽ đọc được.

**Cách B — nếu không hỗ trợ `readfile`:** Execute toàn bộ `run_all_standalone.lua` (hoặc upload file này vào executor). Kết quả hành vi như bản module, nhưng muốn sửa module phải tạo lại standalone từ bản mới. Script này là bản *đóng gói của cùng source*, không phải phiên bản tính năng khác.

## Module nào chỉnh ở đâu?

| File | Chỉnh sửa |
|---|---|
| `run_all.lua` | Danh sách module cần import + thứ tự khởi động |
| `modules/Menu.lua` | Kích thước, màu, sidebar, kéo/thu nhỏ UI, nút bấm chung |
| `modules/Gameplay.lua` | Nhóm Match, Replay, Restart, Modifiers, Failsafe, Boost Performance; state và slider |
| `modules/Gameplay/Match.lua` | `MATCH_CONFIG`, gửi Start 0x02 / Auto Play 0x00, đọc GUI và notification |

### Cách thêm tab mới sau này

Ví dụ file `modules/Gamemode.lua` chứa:

```lua
local Gamemode = {}
function Gamemode.Init(ctx, ui)
    ui:RegisterTab("Gamemode", function()
        ui.infoItem(ui.scroll, "Chưa tích hợp chức năng Gamemode.")
    end)
end
return Gamemode
```

Trong `run_all.lua`:

```lua
-- Thêm vào MODULE_PATHS:
Gamemode = "modules/Gamemode.lua",

-- Sau dòng loadModule(MODULE_PATHS.Match):
local Gamemode = loadModule(MODULE_PATHS.Gamemode)

-- Sau Gameplay.Init(ctx, ui):
Gamemode.Init(ctx, ui)
```

Chỉ sau khi đăng ký, tab mới xuất hiện ở menu trái. Không cần chỉnh `Menu.lua` để thêm tab.

## Trạng thái chức năng hiện tại

- **Match v3:** đã chuyển logic từ source gốc, **UNTESTED** trên Roblox/LDPlayer. Capture Start/AutoPlay có sẵn, chưa xác minh end-to-end.
- **Nhận diện Stage:** vẫn `CANDIDATE`, hiện phụ thuộc GUI AutoPlay + chữ `Match Start` và notification `Match Started!`; chưa phải server state chắc chắn.
- **Các mục Replay/Restart/Modifiers/Failsafe/Boost Performance:** vẫn chỉ lưu trạng thái UI, **chưa gửi Remote**. Không tự bịa logic.
- **Tab trái:** hiện chỉ có **Gameplay**. Sau này dùng `RegisterTab` để thêm.
- **Nút tròn thu nhỏ:** giữ logic kéo thả như file nguồn. Khi đóng `×` sẽ dừng worker Match và ngắt các listener đã đăng ký trong phiên.
- **`SetModifiers`** giữ API cũ (truy cập `getgenv().LotusHubUI:SetModifiers({...})`). Tên Modifier phải là dữ liệu thực thu thập.

## Chú thích code

Mỗi module có ghi chú tiếng Việt. Những điểm mới khi tách module được chú thích `[IMPORT]`, `[START]`, `[GẮN MODULE]`; phần còn lại giữ cấu trúc của source gốc để bạn đối chiếu.

## Kiểm thử đề xuất

1. Execute một lần: xem có 1 cửa sổ và duy nhất tab Gameplay.
2. Thu nhỏ: thấy nút tròn, kéo rồi mở lại; `×` đóng hẳn UI.
3. Bật/tắt 2 toggle Match, quan sát Output tiền tố `[LotusHub Match V3]`.
4. Execute lại: không bị đè hai UI hay có hai worker Match đồng thời.
5. Chạy ở Lobby/Stage khác nhau và kiểm tra log trước khi tin logic tự động hoạt động.

**Lưu ý:** Chưa có xác nhận chạy thành công trên executor cụ thể; nếu `readfile` không truy cập được đường dẫn thư mục thì dùng `run_all_standalone.lua`.
