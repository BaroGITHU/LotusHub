--[[
    LOTUSHUB / run_all_standalone.lua — SCRIPT CHẠY ĐƠN FILE.
    TỰ ĐỘNG GỘP TỪ: run_all.lua + Menu + Gameplay + Match + Replay.
    Để chỉnh source: sửa file module trong modules/, sau đó chạy scripts/build_standalone.py.
    Không cần readfile, không tự tải bất kỳ dữ liệu mạng nào.
]]

local Modules = {}

-- BEGIN MODULE Menu
Modules.Menu = (function()
--[[
    LotusHub / modules/Menu.lua — UI dùng chung cho mọi tab.
    LẤY TỪ FILE Menu.lua NGƯỜI DÙNG CUNG CẤP (09/11/2026).
    Chỉ chịu trách nhiệm VẼ GIAO DIỆN, nhận click và chuyển callback.
    KHÔNG trực tiếp FireServer hoặc chứa logic riêng của Gameplay.

    CÁCH THÊM TAB: gọi ui:RegisterTab("Tên", function(ui) ... end)
    CÁCH BẮT TOGGLE: ui:SetToggleHandler("StateKey", function(enabled) ... end)
    Không thực thi file này độc lập; run_all.lua sẽ nạp module.
]]
local Menu = {}

function Menu.Create(ctx)
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local playerGui = ctx.playerGui
    local env = ctx.env
    local state = ctx.state
    local expanded = ctx.expanded
    local controller -- được gán ở cuối module, xử lý tab và Destroy.

    -- Bọc Connect để run_all có thể ngắt toàn bộ khi đóng/Execute lại.
    local function connect(signal, callback)
        return ctx:Connect(signal, callback)
    end

    -- [C] BẢNG MÀU -- NƠI DỄ CHỈNH GIAO DIỆN NHẤT
    -- Ví dụ muốn nền sáng hơn: đổi `panel = Color3.fromRGB(11, 13, 17)`.
    -- `row` là nền các mục, `active` là màu mục sidebar được chọn,
    -- `silver`/`white` là chữ sáng, `muted` là chữ phụ, `on` là toggle ON.
    local C = {
        panel = Color3.fromRGB(11, 13, 17),
        panelBorder = Color3.fromRGB(100, 105, 111),
        row = Color3.fromRGB(56, 58, 63),
        rowHover = Color3.fromRGB(76, 79, 85),
        active = Color3.fromRGB(105, 111, 117),
        silver = Color3.fromRGB(225, 228, 232),
        muted = Color3.fromRGB(165, 171, 179),
        track = Color3.fromRGB(17, 19, 23),
        on = Color3.fromRGB(94, 116, 120),
        white = Color3.fromRGB(255, 255, 255),
    }

    -- [G] CÁC HÀM TẠO GUI DÙNG LẠI NHIỀU LẦN
    -- new(...): tạo Instance, gán thuộc tính trong props, rồi gắn vào parent.
    -- corner(...): tạo bo góc; stroke(...): tạo viền; vertical(...): xếp dọc.
    -- label(...): tạo chữ với bộ kiểu mặc định để đỡ lặp code.
    local function new(className, parent, props)
        local obj = Instance.new(className)
        for key, value in pairs(props or {}) do
            obj[key] = value
        end
        obj.Parent = parent
        return obj
    end

    local function corner(obj, pixels)
        new("UICorner", obj, { CornerRadius = UDim.new(0, pixels or 8) })
        return obj
    end

    local function stroke(obj, transparency)
        new("UIStroke", obj, {
            Color = C.panelBorder,
            Thickness = 1,
            Transparency = transparency or 0.7,
        })
        return obj
    end

    local function vertical(parent, gap)
        return new("UIListLayout", parent, {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, gap or 8),
        })
    end

    local function label(parent, text, props)
        local base = {
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = C.white,
            Font = Enum.Font.Gotham,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            BorderSizePixel = 0,
        }
        for k, v in pairs(props or {}) do
            base[k] = v
        end
        return new("TextLabel", parent, base)
    end

    -- [H] CỬA SỔ CHÍNH
    -- ScreenGui là lớp hiển thị UI bên trong PlayerGui.
    -- ResetOnSpawn=false: UI không tự mất mỗi lần nhân vật respawn.
    -- DisplayOrder càng lớn thì UI thường càng được vẽ ở lớp phía trước.
    local screen = new("ScreenGui", playerGui, {
        Name = "LotusHub_Gameplay_UI_Demo",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        DisplayOrder = 600,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    -- Frame `main` là toàn bộ bảng LotusHub.
    -- Position (0.5,0.5) kết hợp AnchorPoint (0.5,0.5) đặt giữa màn hình.
    -- Size 940x590 là kích thước CƠ SỞ (pixel), còn UIScale sẽ co cho mobile.
    -- BackgroundTransparency 0.17: nền hơi trong suốt; 0 = không trong suốt.
    local main = corner(new("Frame", screen, {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(940, 590),
        BorderSizePixel = 0,
        BackgroundColor3 = C.panel,
        BackgroundTransparency = 0.17,
        ClipsDescendants = true,
    }), 12)
    stroke(main, 0.48)

    -- UIScale giúp co toàn cửa sổ theo kích thước màn hình, không phải zoom game.
    local uiScale = new("UIScale", main, { Scale = 1 })

    -- [I] THANH TIÊU ĐỀ, LOGO, NÚT THU NHỎ/ĐÓNG
    -- Đổi chuỗi trong label(header, "LotusHub - Anime Vanguards", ...) để đổi tên.
    -- `TextSize` tăng/giảm cỡ chữ; các `Position`/`Size` chỉnh bố cục.
    local header = new("Frame", main, {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 61),
        BackgroundTransparency = 1,
        Active = true,
    })

    label(header, "✿", {
        Position = UDim2.fromOffset(21, 4),
        Size = UDim2.fromOffset(32, 52),
        TextColor3 = C.muted,
        TextSize = 28,
        Font = Enum.Font.GothamBold,
    })
    label(header, "LotusHub - Anime Vanguards", {
        Position = UDim2.fromOffset(59, 5),
        Size = UDim2.new(1, -170, 0, 52),
        Font = Enum.Font.GothamSemibold,
        TextSize = 23,
    })

    label(header, "[Early Access]", {
        Position = UDim2.fromOffset(350, 6),
        Size = UDim2.new(1, -170, 0, 52),
        Font = Enum.Font.GothamSemibold,
        TextSize = 15,
    })

    local rule = new("Frame", main, {
        Position = UDim2.fromOffset(20, 62),
        Size = UDim2.new(1, -40, 0, 1),
        BackgroundColor3 = C.silver,
        BackgroundTransparency = 0.68,
        BorderSizePixel = 0,
    })

    local function topButton(text, x)
        return new("TextButton", header, {
            Size = UDim2.fromOffset(38, 38),
            Position = UDim2.new(1, x, 0, 10),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = C.silver,
            TextSize = 26,
            Font = Enum.Font.Gotham,
            AutoButtonColor = false,
        })
    end

    -- Hai nút ở góc phải: dấu trừ thu nhỏ và dấu nhân đóng cửa sổ.
    local minimizeButton = topButton("−", -86)
    local closeButton = topButton("×", -46)


    -- [I.1] NÚT TRÒN KHI THU NHỎ MENU
    -- Nút này nằm riêng trong ScreenGui.
    -- Khi menu mở: nút bị ẩn.
    -- Khi menu thu nhỏ: nút xuất hiện.

    local restoreBubble = new("TextButton", screen, {
        Name = "RestoreBubble",

        -- Kích thước nút tròn (pixel)
        Size = UDim2.fromOffset(60, 60),

        -- Lấy tâm nút làm điểm định vị
        AnchorPoint = Vector2.new(0.5, 0.5),

        -- Màu nền nút
        BackgroundColor3 = C.panel,
        BackgroundTransparency = 0.1,

        -- Biểu tượng giống logo trên header
        Text = "✿",
        TextColor3 = C.silver,
        TextSize = 30,
        Font = Enum.Font.GothamBold,

        BorderSizePixel = 0,
        AutoButtonColor = true,

        -- Ban đầu ẩn vì menu đang mở
        Visible = false,
        ZIndex = 10,
    })

    -- Bo tròn hoàn toàn nút 60x60
    new("UICorner", restoreBubble, {
        CornerRadius = UDim.new(1, 0),
    })

    -- Tạo viền bạc giống giao diện chính
    stroke(restoreBubble, 0.48)


    -- [J] THÂN CỬA SỔ: MENU TRÁI + KHUNG NỘI DUNG PHẢI
    -- body nằm dưới title bar. sidebar là menu trái.
    -- sectionTitle là tiêu đề tab hiện tại, scroll là vùng cuộn nội dung.
    local body = new("Frame", main, {
        Name = "Body",
        Position = UDim2.fromOffset(0, 66),
        Size = UDim2.new(1, 0, 1, -66),
        BackgroundTransparency = 1,
    })

    local sidebar = new("Frame", body, {
        Position = UDim2.fromOffset(18, 23),
        Size = UDim2.fromOffset(224, 442),
        BackgroundTransparency = 1,
    })
    vertical(sidebar, 11)

    new("Frame", body, {
        Position = UDim2.fromOffset(255, 22),
        Size = UDim2.new(0, 1, 1, -70),
        BorderSizePixel = 0,
        BackgroundColor3 = C.muted,
        BackgroundTransparency = 0.68,
    })

    local sectionTitle = label(body, "Gameplay", {
        Position = UDim2.fromOffset(276, 13),
        Size = UDim2.new(1, -302, 0, 63),
        Font = Enum.Font.GothamBold,
        TextSize = 32,
    })

    -- ScrollingFrame cho phép kéo xuống khi danh sách nhiều hơn chiều cao.
    -- AutomaticCanvasSize.Y tự nới phần nội dung theo các phần tử con.
    local scroll = new("ScrollingFrame", body, {
        Name = "ContentScroll",
        Position = UDim2.fromOffset(276, 94),
        Size = UDim2.new(1, -297, 1, -146),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.muted,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.Y,
    })
    vertical(scroll, 11)
    new("UIPadding", scroll, {
        PaddingTop = UDim.new(0, 2),
        PaddingRight = UDim.new(0, 5),
        PaddingBottom = UDim.new(0, 14),
    })

    -- Dòng chân trang nhắc người dùng rằng tất cả nút hiện tại chỉ là demo.
    local footer = label(body, "LotusHub Modular  •  Match v3 tích hợp; mục khác chưa nối", {
        Position = UDim2.new(0, 276, 1, -37),
        Size = UDim2.new(1, -304, 0, 24),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = C.muted,
    })

    -- [K] DANH SÁCH TAB BÊN TRÁI
    -- Đổi tên/thứ tự tab tại `tabs`. Để có nội dung mới, thêm xử lý ở showTab().
    -- Các tab khác ngoài Gameplay hiện chỉ có dòng thông báo (chưa tích hợp).
    local currentTab = nil
    local tabs = {} -- Được tạo động khi từng module đăng ký với RegisterTab.
    local tabBuilders = {}
    local tabButtons = {}

    -- Tạo 1 nút sidebar; stripe là vạch bạc báo tab đang được chọn.
    local function addNavButton(name, order)
        local button = corner(new("TextButton", sidebar, {
            Name = "Tab_" .. name,
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 47),
            BackgroundColor3 = C.active,
            BackgroundTransparency = 1,
            Text = "  " .. name,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = C.silver,
            TextSize = 19,
            Font = Enum.Font.GothamSemibold,
            AutoButtonColor = false,
            BorderSizePixel = 0,
        }), 7)
        local stripe = new("Frame", button, {
            Name = "Stripe",
            Position = UDim2.fromOffset(0, 4),
            Size = UDim2.new(0, 4, 1, -8),
            BackgroundColor3 = C.silver,
            BorderSizePixel = 0,
            Visible = false,
        })
        tabButtons[name] = { button = button, stripe = stripe }
        return button
    end


    -- [L] KHỐI HIỂN THỊ NỘI DUNG
    -- Khi chuyển tab, xóa các hàng cũ trong vùng scroll để dựng tab mới.
    -- UIListLayout và UIPadding không bị xóa vì không phải GuiObject.
    local function clearContent()
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        scroll.CanvasPosition = Vector2.zero
    end

    -- section(...): dựng một nhóm gập/mở như Match, Replay, Restart...
    -- key = khóa trong expanded; displayName = chữ hiện trên giao diện.
    -- Bấm vào thanh nhóm sẽ đổi expanded[key] giữa true/false.
    local function section(parent, key, displayName, defaultOpen)
        if expanded[key] == nil then
            expanded[key] = defaultOpen
        end

        local wrapper = new("Frame", parent, {
            Name = "Section_" .. key,
            LayoutOrder = #parent:GetChildren(),
            Size = UDim2.new(1, -1, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        })
        vertical(wrapper, 6)

        local button = corner(new("TextButton", wrapper, {
            LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 49),
            BackgroundColor3 = C.row,
            BackgroundTransparency = 0.21,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
        }), 9)
        label(button, displayName, {
            Position = UDim2.fromOffset(17, 0),
            Size = UDim2.new(1, -76, 1, 0),
            Font = Enum.Font.GothamSemibold,
            TextSize = 19,
        })
        local arrow = label(button, "⌄", {
            Position = UDim2.new(1, -48, 0, 0),
            Size = UDim2.fromOffset(35, 48),
            TextSize = 28,
            TextXAlignment = Enum.TextXAlignment.Center,
        })

        local contents = new("Frame", wrapper, {
            Name = "Items",
            LayoutOrder = 2,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        })
        vertical(contents, 6)
        new("UIPadding", contents, {
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 8),
        })

        local function update()
            contents.Visible = expanded[key]
            arrow.Text = expanded[key] and "⌄" or "›"
        end
        update()
        button.MouseButton1Click:Connect(function()
            expanded[key] = not expanded[key]
            update()
        end)
        return contents
    end

    -- [M] CÁC KIỂU HÀNG DÙNG CHUNG
    -- itemFrame: nền 1 hàng; toggleItem: công tắc bất kỳ;
    -- stateToggle: công tắc liên kết trực tiếp vào state[key].
    -- sliderItem: thanh kéo cập nhật một giá trị số vào tableRef[key].
    local function itemFrame(parent, height)
        return corner(new("Frame", parent, {
            LayoutOrder = #parent:GetChildren(),
            Size = UDim2.new(1, 0, 0, height or 49),
            BackgroundColor3 = C.row,
            BackgroundTransparency = 0.26,
            BorderSizePixel = 0,
        }), 8)
    end

    -- toggleItem không tự biết tính năng: chỉ đọc boolean qua readValue()
    -- và gọi saveValue(newBoolean) khi bấm. Phần `redraw` vẽ màu + núm bật/tắt.
    -- Do đó có thể dùng toggleItem cho modifier hoặc các trạng thái khác.
    local function toggleItem(parent, text, readValue, saveValue)
        local row = itemFrame(parent, 49)
        label(row, text, {
            Position = UDim2.fromOffset(17, 0),
            Size = UDim2.new(1, -112, 1, 0),
            TextSize = 16,
        })
        local track = corner(new("TextButton", row, {
            Name = "Toggle",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -18, 0.5, 0),
            Size = UDim2.fromOffset(67, 29),
            BackgroundColor3 = C.track,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        }), 9)
        stroke(track, 0.33)
        local knob = corner(new("Frame", track, {
            Size = UDim2.fromOffset(23, 23),
            Position = UDim2.fromOffset(3, 3),
            BackgroundColor3 = C.silver,
            BorderSizePixel = 0,
        }), 7)
        local function redraw()
            local value = readValue() == true
            track.BackgroundColor3 = value and C.on or C.track
            knob.Position = value and UDim2.fromOffset(41, 3) or UDim2.fromOffset(3, 3)
        end
        redraw()
        track.MouseButton1Click:Connect(function()
            saveValue(not readValue())
            redraw()
        end)
        return row
    end

    -- Mỗi toggle có handler riêng. Không ràng buộc Menu với Gameplay/Match.
    local toggleHandlers = {}

    local function stateToggle(parent, text, key)
        return toggleItem(parent, text, function()
            return state[key]
        end, function(value)
            state[key] = value
            if type(toggleHandlers[key]) == "function" then
                toggleHandlers[key](value)
            else
                print("[LotusHub UI] " .. key .. " = " .. tostring(value) .. " (chỉ UI)")
            end
        end)
    end

    -- [N] THANH KÉO (SLIDER)
    -- minimum/maximum là phạm vi số nguyên; ví dụ 1..100.
    -- tableRef[key] là nơi lưu giá trị (thường là `state`).
    -- suffix là chữ ở sau số, ví dụ "m" (phút).
    -- LƯU Ý: maximum phải lớn hơn minimum vì có phép chia (maximum-minimum).
    -- `applyPosition` đổi tọa độ chuột/chạm thành giá trị nằm trong phạm vi này.
    local function sliderItem(parent, text, tableRef, key, minimum, maximum, suffix)
        local row = itemFrame(parent, 79)
        label(row, text, {
            Position = UDim2.fromOffset(17, 6),
            Size = UDim2.new(1, -34, 0, 26),
            TextSize = 16,
        })
        local track = corner(new("Frame", row, {
            Position = UDim2.new(0, 26, 0, 53),
            Size = UDim2.new(1, -126, 0, 5),
            BackgroundColor3 = C.track,
            BorderSizePixel = 0,
        }), 3)
        local fill = corner(new("Frame", track, {
            Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = C.silver,
            BorderSizePixel = 0,
        }), 3)
        local knob = corner(new("Frame", track, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.fromOffset(20, 20),
            BackgroundColor3 = C.silver,
            BorderSizePixel = 0,
        }), 10)
        local amount = corner(new("Frame", row, {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -13, 0, 40),
            Size = UDim2.fromOffset(67, 31),
            BackgroundColor3 = C.active,
            BackgroundTransparency = 0.53,
            BorderSizePixel = 0,
        }), 6)
        local amountLabel = label(amount, "", {
            Size = UDim2.fromScale(1, 1),
            TextSize = 15,
            Font = Enum.Font.GothamSemibold,
            TextXAlignment = Enum.TextXAlignment.Center,
        })

        local draggingSlider = false
        local touchInput = nil
        local function redraw()
            local value = math.clamp(tonumber(tableRef[key]) or minimum, minimum, maximum)
            local fraction = (value - minimum) / (maximum - minimum)
            fill.Size = UDim2.fromScale(fraction, 1)
            knob.Position = UDim2.fromScale(fraction, 0.5)
            amountLabel.Text = tostring(value) .. (suffix or "")
        end
        local function applyPosition(pos)
            local width = track.AbsoluteSize.X
            if width <= 0 then return end
            local fraction = math.clamp((pos.X - track.AbsolutePosition.X) / width, 0, 1)
            tableRef[key] = math.floor(minimum + fraction * (maximum - minimum) + 0.5)
            redraw()
        end
        redraw()

        local hitbox = new("TextButton", row, {
            Position = UDim2.new(0, 13, 0, 37),
            Size = UDim2.new(1, -108, 0, 37),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 4,
        })
        hitbox.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                draggingSlider = true
                touchInput = (input.UserInputType == Enum.UserInputType.Touch) and input or nil
                applyPosition(input.Position)
            end
        end)

        local changing = UserInputService.InputChanged:Connect(function(input)
            if not draggingSlider then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or (input.UserInputType == Enum.UserInputType.Touch and input == touchInput) then
                applyPosition(input.Position)
            end
        end)
        local ending = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or (input.UserInputType == Enum.UserInputType.Touch and input == touchInput) then
                draggingSlider = false
                touchInput = nil
            end
        end)
        row.Destroying:Connect(function()
            changing:Disconnect()
            ending:Disconnect()
        end)
        return row
    end

    -- infoItem: hiển thị lời chú thích/hướng dẫn, không bấm được.
    local function infoItem(parent, text)
        local row = itemFrame(parent, 54)
        label(row, text, {
            Position = UDim2.fromOffset(17, 3),
            Size = UDim2.new(1, -34, 1, -6),
            TextColor3 = C.muted,
            TextSize = 13,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
        })
        return row
    end

    -- [P] HỆ THỐNG TAB ĐỘNG: Gameplay/Gamemode,... đều là module riêng.
    local function showTab(name)
        local build = tabBuilders[name]
        if not build then
            warn("[LotusHub Menu] Chưa đăng ký tab: " .. tostring(name))
            return
        end
        currentTab = name
        sectionTitle.Text = name
        clearContent()
        for tabName, objects in pairs(tabButtons) do
            local isCurrent = (tabName == name)
            objects.button.BackgroundTransparency = isCurrent and 0.52 or 1
            objects.button.TextColor3 = isCurrent and C.white or C.silver
            objects.stripe.Visible = isCurrent
        end
        build(controller) -- Tất cả nội dung tab được dựng ở module tương ứng.
    end

    -- [Q] THU NHỎ MENU THÀNH NÚT TRÒN CÓ THỂ KÉO THẢ

    local minimized = false

    -- [Q.1] CẤU HÌNH KÉO THẢ
    -- Kéo ít nhất 8 pixel mới tính là di chuyển.
    -- Giúp phân biệt thao tác bấm và kéo.
    local DRAG_THRESHOLD = 8

    local bubbleDragging = false
    local bubbleMoved = false
    local bubbleTouchInput = nil
    local bubbleStartInput = nil
    local bubbleStartPosition = nil

    -- [Q.2] GIỚI HẠN VỊ TRÍ NÚT TRÒN
    -- Ngăn nút bị kéo ra ngoài màn hình.
    local function setBubblePosition(x, y)
        local camera = Workspace.CurrentCamera
        if not camera then
            restoreBubble.Position = UDim2.fromOffset(x, y)
            return
        end

        local viewport = camera.ViewportSize

        -- Bán kính nút tròn 60x60
        local radiusX = restoreBubble.Size.X.Offset / 2
        local radiusY = restoreBubble.Size.Y.Offset / 2

        -- Giữ toàn bộ nút trong màn hình
        x = math.clamp(
            x,
            radiusX,
            math.max(radiusX, viewport.X - radiusX)
        )

        y = math.clamp(
            y,
            radiusY,
            math.max(radiusY, viewport.Y - radiusY)
        )

        restoreBubble.Position = UDim2.fromOffset(x, y)
    end

    -- [Q.3] BẤM NÚT THU NHỎ TRÊN HEADER
    minimizeButton.MouseButton1Click:Connect(function()
        if minimized then return end

        minimized = true

        -- Đưa nút tròn đến vị trí logo trên header
        setBubblePosition(
            main.AbsolutePosition.X + 37 * uiScale.Scale,
            main.AbsolutePosition.Y + 30 * uiScale.Scale
        )

        -- Ẩn menu, hiện nút tròn
        main.Visible = false
        restoreBubble.Visible = true
    end)

    -- [Q.4] PHÁT HIỆN KHI BẮT ĐẦU KÉO
    connect(restoreBubble.InputBegan, function(input)
        local inputType = input.UserInputType

        -- Hỗ trợ chuột PC và cảm ứng điện thoại
        if inputType ~= Enum.UserInputType.MouseButton1
            and inputType ~= Enum.UserInputType.Touch then
            return
        end

        bubbleDragging = true
        bubbleMoved = false

        -- Lưu ngón tay đang chạm (nếu dùng mobile)
        bubbleTouchInput =
            inputType == Enum.UserInputType.Touch
            and input or nil

        -- Lưu vị trí khi bắt đầu nhấn
        bubbleStartInput = Vector2.new(
            input.Position.X,
            input.Position.Y
        )

        -- Lưu vị trí ban đầu của nút tròn
        bubbleStartPosition = Vector2.new(
            restoreBubble.Position.X.Offset,
            restoreBubble.Position.Y.Offset
        )
    end)

    -- [Q.5] DI CHUYỂN NÚT TRÒN
    connect(UserInputService.InputChanged, function(input)
        if not bubbleDragging then return end
        if not bubbleStartInput then return end

        local isMouse =
            input.UserInputType == Enum.UserInputType.MouseMovement
            and bubbleTouchInput == nil

        local isTouch =
            input.UserInputType == Enum.UserInputType.Touch
            and input == bubbleTouchInput

        if not isMouse and not isTouch then
            return
        end

        -- Tọa độ hiện tại của chuột / ngón tay
        local currentPosition = Vector2.new(
            input.Position.X,
            input.Position.Y
        )

        -- Tính khoảng cách đã kéo
        local delta = currentPosition - bubbleStartInput

        -- Chỉ xác nhận kéo khi vượt ngưỡng
        if delta.Magnitude >= DRAG_THRESHOLD then
            bubbleMoved = true
        end

        if not bubbleMoved then return end

        -- Di chuyển nút theo hướng kéo
        setBubblePosition(
            bubbleStartPosition.X + delta.X,
            bubbleStartPosition.Y + delta.Y
        )
    end)

    -- [Q.6] KẾT THÚC KÉO
    connect(UserInputService.InputEnded, function(input)
        local isMouse =
            input.UserInputType == Enum.UserInputType.MouseButton1
            and bubbleTouchInput == nil

        local isTouch =
            input.UserInputType == Enum.UserInputType.Touch
            and input == bubbleTouchInput

        if isMouse or isTouch then
            bubbleDragging = false
            bubbleTouchInput = nil
        end
    end)

    -- [Q.7] BẤM NÚT TRÒN ĐỂ MỞ LẠI MENU
    -- Activated hỗ trợ cả chuột và cảm ứng.
    connect(restoreBubble.Activated, function()
        if not minimized then return end

        -- Nếu vừa kéo nút thì KHÔNG mở menu
        if bubbleMoved then
            return
        end

        minimized = false

        -- Ẩn nút tròn
        restoreBubble.Visible = false

        -- Mở lại menu tại vị trí ban đầu
        main.Visible = true
    end)



    -- [S] KÉO CỬA SỔ: ghi lại vị trí ban đầu khi nhấn, cập nhật theo độ dịch.
    -- `uiScale.Scale` được tính đến để kéo đúng dù UI đã thu nhỏ trên điện thoại.
    -- Keo cua so bang thanh tieu de (chuot / mobile touch).
    local dragging = false
    local dragTouch = nil
    local initialInputPos
    local initialWindowPos
    connect(header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragTouch = (input.UserInputType == Enum.UserInputType.Touch) and input or nil
            initialInputPos = input.Position
            initialWindowPos = main.Position
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if not dragging or not initialInputPos then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or (input.UserInputType == Enum.UserInputType.Touch and input == dragTouch) then
            local delta = (input.Position - initialInputPos) / uiScale.Scale
            main.Position = UDim2.new(
                initialWindowPos.X.Scale, initialWindowPos.X.Offset + delta.X,
                initialWindowPos.Y.Scale, initialWindowPos.Y.Offset + delta.Y
            )
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or (input.UserInputType == Enum.UserInputType.Touch and input == dragTouch) then
            dragging = false
            dragTouch = nil
        end
    end)

    -- [T] TỰ ĐIỀU CHỈNH KÍCH THƯỚC THEO MÀN HÌNH
    -- fit là hệ số co sao cho cửa sổ 940x590 vừa viewport (trừ viền 20px).
    -- math.clamp(..., 0.35, 1): co tối đa tới 35%, không phóng lớn hơn 100%.
    local function updateScale()
        local camera = Workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        local fit = math.min((viewport.X - 20) / 940, (viewport.Y - 20) / 590, 1)
        uiScale.Scale = math.clamp(fit, 0.35, 1)
    end

    local cameraConnection
    local function watchCamera()
        if cameraConnection then
            cameraConnection:Disconnect()
            cameraConnection = nil
        end
        if Workspace.CurrentCamera then
            cameraConnection = connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale)
        end
        updateScale()
    end
    connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), watchCamera)
    watchCamera()

    -- [U] API ĐỂ ĐỌC/SỬA DỮ LIỆU CỦA UI TỪ BÊN NGOÀI
    -- copyState sao chép cả bảng con để GetState() trả bản sao, tránh người dùng
    -- sửa trực tiếp vào bảng state nội bộ rồi nghĩ giao diện đã tự cập nhật.
    local function copyState(source)
        local copy = {}
        for k, v in pairs(source) do
            if type(v) == "table" then
                copy[k] = copyState(v)
            else
                copy[k] = v
            end
        end
        return copy
    end

    -- [U] API CÔNG KHAI CHO CÁC MODULE KHÁC
    controller = {
        scroll = scroll,
        section = section,
        stateToggle = stateToggle,
        toggleItem = toggleItem,
        sliderItem = sliderItem,
        infoItem = infoItem,
    }

    -- Đăng ký thêm tab và tạo nút bên trái (không hardcode Gamemode...).
    function controller:RegisterTab(name, buildFn)
        assert(type(name) == "string" and name ~= "", "Tên tab không hợp lệ")
        assert(type(buildFn) == "function", "Cần hàm dựng nội dung tab")
        if tabBuilders[name] then error("Tab đã tồn tại: " .. name) end
        tabBuilders[name] = buildFn
        table.insert(tabs, name)
        local button = addNavButton(name, #tabs)
        connect(button.MouseButton1Click, function()
            showTab(name)
        end)
    end

    function controller:ShowTab(name)
        showTab(name)
    end

    function controller:Refresh()
        if currentTab then showTab(currentTab) end
    end

    function controller:SetToggleHandler(key, fn)
        assert(type(key) == "string" and type(fn) == "function")
        toggleHandlers[key] = fn
    end

    function controller:GetState()
        return copyState(state)
    end

    function controller:Destroy()
        ctx:Destroy() -- Ngắt sự kiện, dừng worker và xóa cả menu + nút tròn.
    end

    -- SetModifiers sẽ được module Gameplay gắn riêng sau khi được import.
    -- Đóng UI qua dấu X (không tắt Auto Play đang bật bên trong game).
    connect(closeButton.MouseButton1Click, function()
        controller:Destroy()
    end)

    ctx.screen = screen -- Match cần để bỏ qua chính GUI LotusHub khi quét GUI game.
    return controller
end

return Menu
end)()
-- END MODULE Menu

-- BEGIN MODULE Gameplay
Modules.Gameplay = (function()
--[[
    LotusHub / modules/Gameplay.lua — Chỉ chứa nội dung tab Gameplay.
    Giữ nguyên các nhóm Match, Replay, Restart, Modifiers, Failsafe,
    Boost Performance từ Menu.lua của người dùng.
    Match + Replay đã được nối logic. Lobby có GUI Leave CANDIDATE;
    remote / PlaceId trong raw chưa xác minh nên không tự gọi.
    Muốn thêm tính năng Gameplay, sửa hàm buildGameplay() ở file này.
]]
local Gameplay = {}

function Gameplay.Init(ctx, ui)
    -- [1] State của Gameplay: được giữ riêng, không trộn với code menu.
    local defaults = {
        AutoStartgame = false,
        AutoActiveAutoPlay = false,
        AutoReplay = false,
        ReplayLimitEnabled = false,
        ReplayLimit = 20,
        RestartAfterWavesEnabled = false,
        RestartAfterWaves = 10,
        RestartIfMissingModifier = false,
        AutoPickModifiers = false,
        SelectedModifiers = {},
        ModifierPriority = {},
        FailsafeTeleportEnabled = false,
        FailsafeMinutes = 15,
        FreeFireGraphics = false,
        DeleteMap = false,
        DeleteEntities = false,
    }
    local state = ctx.state
    for key, value in pairs(defaults) do
        if state[key] == nil then state[key] = value end
    end

    -- [2] Trạng thái nhóm gập/mở (không tự thay đổi khi chuyển tab).
    local defaultExpanded = {
        Match = true,
        Replay = true,
        Restart = false,
        Modifiers = false,
        Failsafe = false,
        BoostPerformance = false,
    }
    for key, value in pairs(defaultExpanded) do
        if ctx.expanded[key] == nil then ctx.expanded[key] = value end
    end
    local knownModifiers = ctx.knownModifiers

    -- [3] Dùng các hàm vẽ của Menu, không lặp lại GUI code tại đây.
    local scroll = ui.scroll
    local section = ui.section
    local stateToggle = ui.stateToggle
    local toggleItem = ui.toggleItem
    local sliderItem = ui.sliderItem
    local infoItem = ui.infoItem

    -- [4] Hàm dưới được chuyển nguyên từ buildGameplay() trong source gốc.
    local function buildGameplay()
        -- Nhóm MATCH: Auto Startgame và Auto Active Auto Play là hai toggle riêng.
        local match = section(scroll, "Match", "Match", true)
        stateToggle(match, "Auto Startgame", "AutoStartgame")
        stateToggle(match, "Auto Active Auto Play", "AutoActiveAutoPlay")

        -- Nhóm REPLAY: giữ Auto Replay và tùy chọn về Lobby sau N lần.
        -- ReplayLimit và AutoReplay đã nối module Gameplay/Replay.lua.
        -- [REPLAY] Các chức năng còn giữ lại
        local replay = section(scroll, "Replay", "Replay", true)

        -- Tự động chơi lại trận
        stateToggle(replay, "Auto Replay", "AutoReplay")

        -- Tùy chọn về Lobby sau N lần Replay
        stateToggle(replay, "Teleport to lobby after N replays", "ReplayLimitEnabled")

        -- Chọn số lần Replay trước khi về Lobby
        sliderItem(replay, "Replay count (N)", state, "ReplayLimit", 1, 100, "")

        -- [REPLAY STATUS] Lấy chức năng hiển thị đếm + Reset từ raw.
        -- Không tạo ScreenGui phụ; dùng một hàng trong menu LotusHub.
        local progressRow = infoItem(replay, "Đã Replay: 0 / " .. tostring(state.ReplayLimit))
        local progressText = progressRow:FindFirstChildWhichIsA("TextLabel")
        if progressText then
            -- Chừa vùng bên phải cho nút Reset.
            progressText.Size = UDim2.new(1, -140, 1, -6)
            progressText.TextSize = 14
        end
        local reset = Instance.new("TextButton")
        reset.Name = "ReplayResetButton"
        reset.AnchorPoint = Vector2.new(1, 0.5)
        reset.Position = UDim2.new(1, -12, 0.5, 0)
        reset.Size = UDim2.fromOffset(101, 32)
        reset.BackgroundColor3 = Color3.fromRGB(65, 69, 76)
        reset.BorderSizePixel = 0
        reset.Font = Enum.Font.GothamSemibold
        reset.TextSize = 14
        reset.TextColor3 = Color3.fromRGB(225, 228, 232)
        reset.Text = "Reset (0)"
        reset.AutoButtonColor = false -- Không hiệu ứng nhấp nháy/đổi màu.
        reset.Parent = progressRow
        local resetCorner = Instance.new("UICorner")
        resetCorner.CornerRadius = UDim.new(0, 6)
        resetCorner.Parent = reset
        reset.Activated:Connect(function()
            if type(ui.ResetReplayCount) == "function" then
                ui:ResetReplayCount()
            end
        end)

        -- Replay.Init sẽ gọi sink mỗi khi bộ đếm hoặc N thay đổi.
        -- Kiểm tra Parent vì Gameplay có thể được dựng lại khi đổi tab.
        ctx.replayProgressSink = function(count, limit, status)
            if not progressRow.Parent then return end
            if progressText then
                progressText.Text = "Đã Replay: " .. tostring(count) .. " / " .. tostring(limit)
                if status then progressText.Text = progressText.Text .. " (đạt N)" end
            end
            reset.Text = "Reset (" .. tostring(count) .. ")"
        end
        if type(ui.GetReplayStatus) == "function" then
            local current = ui:GetReplayStatus()
            ctx.replayProgressSink(current.count, current.limit,
                current.waitingForLobby and "Chờ kết thúc" or nil)
        end

        -- Nhóm RESTART: con số wave chỉ lưu trong state.RestartAfterWaves.
        -- Danh sách yêu cầu Modifier chỉ xuất hiện sau SetModifiers(names).
        local restart = section(scroll, "Restart", "Restart", false)
        stateToggle(restart, "Auto Restart After Waves", "RestartAfterWavesEnabled")
        sliderItem(restart, "Restart at wave", state, "RestartAfterWaves", 1, 200, "")
        stateToggle(restart, "Auto Restart If Don't Have Modifier", "RestartIfMissingModifier")
        if #knownModifiers == 0 then
            infoItem(restart, "Chưa có danh sách Modifier thật để chọn điều kiện Restart.")
        else
            for _, modifier in ipairs(knownModifiers) do
                local name = modifier
                toggleItem(restart, "Require: " .. name, function()
                    return state.SelectedModifiers[name] == true
                end, function(value)
                    state.SelectedModifiers[name] = value
                end)
            end
        end

        -- Nhóm MODIFIERS: Priority 0..100 là mức ưu tiên HIỂN THỊ để tự chỉnh,
        -- không phải cơ chế ưu tiên hay giá trị modifier của game.
        local modifiers = section(scroll, "Modifiers", "Modifiers", false)
        stateToggle(modifiers, "Auto Pick Modifiers", "AutoPickModifiers")
        if #knownModifiers == 0 then
            infoItem(modifiers, "Modifier Priority: MISSING — chua co ten Modifier thu thap tu game.")
        else
            for _, modifier in ipairs(knownModifiers) do
                sliderItem(modifiers, "Priority: " .. modifier, state.ModifierPriority, modifier, 0, 100, "")
            end
        end

        -- Nhóm FAILSAFE: số phút đặt ở slider chỉ được ghi vào state.FailsafeMinutes.
        local failsafe = section(scroll, "Failsafe", "Failsafe", false)
        stateToggle(failsafe, "Auto Teleport to Lobby After Minutes", "FailsafeTeleportEnabled")
        sliderItem(failsafe, "Minutes", state, "FailsafeMinutes", 1, 120, "m")

        -- Nhóm BOOST: các nút không thay đổi đồ họa và không xóa entity/map thật.
        local boost = section(scroll, "BoostPerformance", "Boost Performance", false)
        stateToggle(boost, "FreeFire Graphics (Boost FPS)", "FreeFireGraphics")
        stateToggle(boost, "Delete Map", "DeleteMap")
        stateToggle(boost, "Delete Entities", "DeleteEntities")
        infoItem(boost, "Chi la toggle UI. KHONG xoa map/entities hoac thay doi do hoa that.")
    end

    -- [5] API nạp Modifier từ dữ liệu ĐÃ XÁC MINH. Không tự đặt tên giả.
    function ui:SetModifiers(names)
        assert(type(names) == "table", "SetModifiers expects an array of names")
        local result, seen = {}, {}
        for _, candidate in ipairs(names) do
            if type(candidate) == "string" then
                local name = candidate:match("^%s*(.-)%s*$")
                if name ~= "" and not seen[name] and #result < 30 then
                    table.insert(result, name)
                    seen[name] = true
                    if state.ModifierPriority[name] == nil then
                        state.ModifierPriority[name] = 50 -- Giá trị UI mặc định.
                    end
                end
            end
        end
        knownModifiers = result
        ctx.knownModifiers = result
        ui:Refresh()
    end

    -- [6] Khi bấm Gameplay, Menu gọi buildGameplay() để vẽ các hàng.
    ui:RegisterTab("Gameplay", function()
        buildGameplay()
    end)
end

return Gameplay
end)()
-- END MODULE Gameplay

-- BEGIN MODULE Match
Modules.Match = (function()
--[[
    LotusHub / modules/Gameplay/Match.lua — logic Match v3 tách khỏi GUI.
    Nguồn: Match v3 trong Menu.lua người dùng cung cấp (09/11/2026).
    Hai toggle ĐỘC LẬP: AutoStartgame và AutoActiveAutoPlay.
    Start 0x02 sau khi thấy "Match Start", mỗi 1 giây; nhận
    "Match Started!" mới cho phép thử Auto Play 0x00 khi GUI báo OFF.

    BẰNG CHỨNG: Remote là capture người dùng; stage/title/DisplayText
    vẫn CANDIDATE. Không tuyên bố đã test in-game.
    Đóng UI/Execute lại => ctx.alive=false, listener bị ngắt.
]]
local Match = {}

function Match.Init(ctx, ui)
    local playerGui = ctx.playerGui
    local state = ctx.state
    local screen = ctx.screen

    local function connect(signal, callback)
        return ctx:Connect(signal, callback)
    end

    -- [MATCH V3.1] CẤU HÌNH ĐƯỢC PHÉP CHỈNH
    local MATCH_CONFIG = {
        CheckInterval = 0.25,       -- Kiểm tra GUI 4 lần/giây; KHÔNG gửi Start 4 lần/giây.
        StartDelay = 0,            -- 0 = thử Start ngay khi xác định màn hình tiền trận.
        StartRetry = 1,            -- Tối thiểu 1 giây giữa các lệnh Start (giảm spam mạng).
        AutoPlayRetry = 1,         -- Thử lại Auto Play khi GUI còn OFF, tối thiểu 1 giây.
        AutoPlayVerify = 3,        -- Sau khi gửi Auto Play, chờ GUI xác nhận trong 3 giây.
        StageAbsentChecks = 8,     -- 8 x 0.25 = 2 giây mất GUI mới xem là rời Stage.
        MaxStartAttempts = 0,      -- 0 = không giới hạn; có thể đặt 120 để tự dừng sau 120 lần.
    }

    -- [MATCH V3.2] TÊN REMOTE/PAYLOAD ĐỀU TỪ CAPTURE NGƯỜI DÙNG CUNG CẤP
    local matchRS = game:GetService("ReplicatedStorage")
    local START_REMOTE_NAME = "AV_GAME_WAVES_V1_BLINK_RELIABLE_REMOTE"
    local PLAY_REMOTE_NAME = "AV_GAME_AUTOPLAY_V1_BLINK_RELIABLE_REMOTE"
    local NOTIFY_REMOTE_NAME = "AV_GAME_NOTIFICATIONS_POPUPS_V1_BLINK_RELIABLE_REMOTE"

    local MSG_STARTED = "Match Started!"
    local MSG_PLAY_ON = "Successfully enabled auto play!"
    local MSG_PLAY_FAIL = "Start the match to enable Auto Play."

    local matchSession = {
        stage = nil,
        nextId = 0,
        absentTicks = 0,
        checking = false,
        lastMessages = {},
    }

    local function matchLog(message)
        print("[LotusHub Match V3] " .. message)
    end

    -- In trạng thái mới khi thay đổi, tránh Output bị đầy khi polling liên tục.
    local function matchLogOnce(key, message)
        if matchSession.lastMessages[key] ~= message then
            matchSession.lastMessages[key] = message
            matchLog(message)
        end
    end

    -- [MATCH V3.3] KIỂM TRA HIỂN THỊ THẬT (CẢ GUI CHA VÀ ScreenGui)
    local function matchVisible(obj)
        if not obj or not obj:IsA("GuiObject") then return false end
        if obj.AbsoluteSize.X <= 0 or obj.AbsoluteSize.Y <= 0 then return false end
        local node = obj
        while node and node ~= playerGui do
            if node:IsA("GuiObject") and not node.Visible then return false end
            if node:IsA("ScreenGui") and not node.Enabled then return false end
            node = node.Parent
        end
        return node == playerGui
    end

    local function matchTrim(value)
        if type(value) ~= "string" then return "" end
        return (value:gsub("%s+", " "):match("^%s*(.-)%s*$"))
    end

    -- [MATCH V3.4] GUI STAGE ỨNG VIÊN TỪ DEX, KHÔNG PHẢI SERVER STATE
    local function matchFindPlayRoot()
        local node = playerGui
        for _, name in ipairs({ "Guides", "List", "MatchStatusHUD", "Buttons", "AutoPlay" }) do
            node = node:FindFirstChild(name)
            if not node then return nil end
        end
        return matchVisible(node) and node or nil
    end

    -- Ghi nhận màn hình kết thúc để ngăn vòng Start tiếp tục lúc đã hết trận.
    local function matchEndScreenShowing()
        local endScreen = playerGui:FindFirstChild("EndScreen")
        if not endScreen then return false end
        local holder = endScreen:FindFirstChild("Holder")
        return (holder and matchVisible(holder)) or false
    end

    -- [MATCH V3.5] "Match Start" LÀ DẤU HIỆU TIỀN TRẬN (CANDIDATE)
    -- Không tìm được nút Start thật, nên không giả định GUI button cụ thể.
    -- Chỉ tìm chữ đang hiển thị bên trong game, bỏ qua UI LotusHub.
    local function matchHasStartTitle()
        for _, obj in ipairs(playerGui:GetDescendants()) do
            if (obj:IsA("TextLabel") or obj:IsA("TextButton"))
                and not obj:IsDescendantOf(screen)
                and matchVisible(obj)
                and matchTrim(obj.Text) == "Match Start" then
                return true
            end
        end
        return false
    end

    -- [MATCH V3.6] AUTO PLAY: CHỈ BẬT KHI ĐỌC ĐƯỢC OFF CHÍNH XÁC
    local function matchReadPlayState(root)
        if not root then return "UNKNOWN", "Không thấy GUI AutoPlay" end
        local label = root:FindFirstChild("DisplayText", true)
        if not label or not matchVisible(label) then
            return "UNKNOWN", "DisplayText không hiển thị/không tồn tại"
        end
        if not (label:IsA("TextLabel") or label:IsA("TextButton")) then
            return "UNKNOWN", "DisplayText không phải TextLabel/TextButton"
        end
        local value = matchTrim(label.Text)
        if value == "Auto Play" then return "OFF", value end
        if value == "Auto Playing" then return "ON", value end
        return "UNKNOWN", "Text: " .. value
    end

    -- [MATCH V3.7] GỬI REMOTE (THÀNH CÔNG GỌI HÀM != SERVER CHẤP NHẬN)
    local function matchSend(remoteName, payload)
        if not ctx.alive then return false end
        local remote = matchRS:FindFirstChild(remoteName)
        if not remote or not remote:IsA("RemoteEvent") then
            matchLogOnce("remote:" .. remoteName, "MISSING RemoteEvent: " .. remoteName)
            return false
        end
        local ok, err = pcall(function()
            remote:FireServer(buffer.fromstring(payload))
        end)
        if not ok then
            matchLogOnce("err:" .. remoteName, "LỖI FireServer: " .. tostring(err))
            return false
        end
        return true
    end

    -- [MATCH V3.8] TÁCH TỪNG PHIÊN STAGE, KHÔNG ĐỂ VÒNG CŨ HOẠT ĐỘNG
    local function matchNewStage(root, now)
        matchSession.nextId += 1
        local stage = {
            id = matchSession.nextId,
            root = root,
            detectedAt = now,
            started = false,                -- Chỉ true khi nghe notification Match Started!
            startAttempts = 0,
            startLastAt = nil,
            titleSeen = false,
            titleGoneAfterSeen = false,
            playLastAt = nil,
            playWaitingUntil = nil,
        }
        matchSession.stage = stage
        matchSession.absentTicks = 0
        matchSession.lastMessages = {}
        matchLog("Stage ứng viên #" .. stage.id .. " đã xuất hiện")
        return stage
    end

    local function matchEndStage(reason)
        if matchSession.stage then
            matchLog("Kết thúc Stage #" .. matchSession.stage.id .. ": " .. reason)
        end
        matchSession.stage = nil
        matchSession.absentTicks = 0
        matchSession.lastMessages = {}
    end

    -- [MATCH V3.9] NGHE THÔNG BÁO THẬT TRONG PHIÊN, KHÔNG firesignal GIẢ LẬP
    local notification = matchRS:FindFirstChild(NOTIFY_REMOTE_NAME)
    if notification and notification:IsA("RemoteEvent") then
        connect(notification.OnClientEvent, function(payload)
            if not ctx.alive or typeof(payload) ~= "buffer" then return end
            local stage = matchSession.stage
            if not stage then return end
            local ok, raw = pcall(buffer.tostring, payload)
            if not ok or type(raw) ~= "string" then return end

            if raw:find(MSG_STARTED, 1, true) then
                if not stage.started then
                    stage.started = true
                    stage.playLastAt = nil
                    stage.playWaitingUntil = nil
                    matchLog("Nhận Match Started! → NGỪNG gửi Start (Stage #" .. stage.id .. ")")
                    if state.AutoActiveAutoPlay then
                        matchLog("Auto Active Auto Play ON → kiểm tra GUI để bật")
                    end
                end
            elseif raw:find(MSG_PLAY_ON, 1, true) then
                matchLog("Nhận thông báo Successfully enabled auto play! (sẽ xác minh GUI)")
            elseif raw:find(MSG_PLAY_FAIL, 1, true) then
                -- Chỉ để log; không làm điều kiện gửi Start trong logic mới.
                matchLog("Nhận Failure Auto Play; V3 KHÔNG dùng Failure để gửi Start")
            end
        end)
    else
        matchLog("MISSING notification Remote; không thể xác nhận Start từ notification")
    end

    -- [MATCH V3.10] MỘT VÒNG KIỂM TRA CHO CẢ HAI TOGGLE
    local function matchTick()
        if not ctx.alive or matchSession.checking then return end
        matchSession.checking = true

        local ok, err = pcall(function()
            local now = os.clock()
            local root = matchFindPlayRoot()
            local endShowing = matchEndScreenShowing()
            local stage = matchSession.stage

            -- EndScreen hiển thị = không thể tiếp tục Start/AutoPlay.
            if endShowing then
                if stage then matchEndStage("EndScreen đang hiển thị") end
                return
            end

            -- Khi GUI Stage mất, hủy session sau nhiều lần liên tiếp.
            if not root then
                if stage then
                    matchSession.absentTicks += 1
                    if matchSession.absentTicks >= MATCH_CONFIG.StageAbsentChecks then
                        matchEndStage("GUI AutoPlay biến mất")
                    end
                end
                if state.AutoStartgame or state.AutoActiveAutoPlay then
                    matchLogOnce("stage", "WAIT: chưa thấy GUI Stage, không gửi Remote")
                end
                return
            end

            if not stage or stage.root ~= root then
                stage = matchNewStage(root, now)
            end
            matchSession.absentTicks = 0

            local hasTitle = matchHasStartTitle()

            -- Khi cùng một Instance GUI được tái sử dụng ở Stage mới:
            -- sau khi đã Start, title biến mất rồi xuất hiện lại => tạo phiên mới.
            if stage.started and not hasTitle then
                stage.titleGoneAfterSeen = true
            elseif stage.started and hasTitle and stage.titleGoneAfterSeen then
                stage = matchNewStage(root, now)
            end

            if hasTitle then
                stage.titleSeen = true
            end

            -- AUTO STARTGAME: CHỈ DÙNG START REMOTE, KHÔNG PROBE AUTO PLAY.
            if state.AutoStartgame and not stage.started then
                if not hasTitle then
                    if stage.titleSeen then
                        matchLogOnce("start", "TẠM DỪNG Start: Match Start đã biến mất; chưa xem là xác nhận bắt đầu")
                    else
                        matchLogOnce("start", "WAIT: chưa thấy chữ Match Start (CANDIDATE)")
                    end
                elseif now - stage.detectedAt < MATCH_CONFIG.StartDelay then
                    matchLogOnce("start", "Đang chờ StartDelay " .. MATCH_CONFIG.StartDelay .. " giây")
                elseif MATCH_CONFIG.MaxStartAttempts > 0
                    and stage.startAttempts >= MATCH_CONFIG.MaxStartAttempts then
                    matchLogOnce("start", "PAUSED: đã đạt MaxStartAttempts; cần kiểm tra game")
                elseif not stage.startLastAt or now - stage.startLastAt >= MATCH_CONFIG.StartRetry then
                    stage.startLastAt = now
                    stage.startAttempts += 1
                    if matchSend(START_REMOTE_NAME, "\002") then
                        -- Log lượt 1, rồi mỗi 10 lượt để tránh làm lag Output.
                        if stage.startAttempts == 1 or stage.startAttempts % 10 == 0 then
                            matchLog("Đã gửi Start 0x02 lần " .. stage.startAttempts
                                .. " (chờ Match Started!)")
                        end
                    end
                end
            end

            -- AUTO ACTIVE AUTO PLAY: CHỈ THỬ SAU KHI NHẬN Match Started!.
            if state.AutoActiveAutoPlay then
                if not stage.started then
                    matchLogOnce("play", "WAIT: chưa có Match Started!, chưa gửi Auto Play")
                else
                    local playState, detail = matchReadPlayState(root)
                    if playState == "ON" then
                        stage.playWaitingUntil = nil
                        matchLogOnce("play", "VERIFIED GUI: Auto Playing (đang ON)")
                    elseif playState == "UNKNOWN" then
                        matchLogOnce("play", "UNKNOWN AutoPlay: " .. detail .. "; không gửi mù")
                    else
                        local pending = stage.playWaitingUntil and now < stage.playWaitingUntil
                        local cooldown = not stage.playLastAt
                            or now - stage.playLastAt >= MATCH_CONFIG.AutoPlayRetry
                        if not pending and cooldown then
                            stage.playLastAt = now
                            stage.playWaitingUntil = now + MATCH_CONFIG.AutoPlayVerify
                            if matchSend(PLAY_REMOTE_NAME, "\000") then
                                matchLog("Đã gửi Auto Play 0x00; chờ GUI đổi Auto Playing")
                            else
                                stage.playWaitingUntil = nil
                            end
                        end
                    end
                end
            end
        end)

        matchSession.checking = false
        if not ok then
            warn("[LotusHub Match V3] Lỗi tick: " .. tostring(err))
        end
    end

    -- [MATCH V3.11] GẮN TOGGLE; OFF CHỈ DỪNG RIÊNG, KHÔNG ĐỔI TOGGLE KHÁC
    local function onMatchToggleChanged(key, enabled)
        local stage = matchSession.stage
        if stage then
            if key == "AutoStartgame" then
                if enabled then
                    -- ON lại trong cùng Stage cho phép tiếp tục khi chưa started.
                    stage.startLastAt = nil
                    stage.startAttempts = 0
                end
            elseif key == "AutoActiveAutoPlay" then
                -- Reset thời điểm thử khi bật lại, không gửi lệnh tắt trong game.
                stage.playLastAt = nil
                stage.playWaitingUntil = nil
            end
        end
        matchLog(key .. " = " .. tostring(enabled))
        if enabled then task.defer(matchTick) end
    end

    -- [MATCH] GẮN RIÊNG TỪNG HANDLER: không phụ thuộc Menu.lua.
    ui:SetToggleHandler("AutoStartgame", function(value)
        onMatchToggleChanged("AutoStartgame", value)
    end)
    ui:SetToggleHandler("AutoActiveAutoPlay", function(value)
        onMatchToggleChanged("AutoActiveAutoPlay", value)
    end)

    -- [MATCH V3.12] CHỈ MỘT WORKER; ĐÓNG UI => alive=false, ngừng tự động
    -- Không tạo worker mới mỗi lần người dùng bật/tắt toggle.
    task.spawn(function()
        while ctx.alive do
            matchTick()
            task.wait(MATCH_CONFIG.CheckInterval)
        end
    end)
end

return Match
end)()
-- END MODULE Match

-- BEGIN MODULE Replay
Modules.Replay = (function()
--[[
    LOTUSHUB / modules/Gameplay/Replay.lua
    ======================================
    Module triển khai Gameplay -> Replay & Auto Lobby.
    Khôi phục hoàn toàn workflow đã kiểm thử thành công từ raw:
    "Auto Replay = Lobby when replay N.lua".

    BẢNG ĐÁNH GIÁ TRẠNG THÁI (STATUS AUDIT):
      [VERIFIED]
        - Chuỗi về Lobby từ raw end-to-end theo người dùng:
            1) click(leaveBtn)
            2) task.wait(0.8)
            3) AV_GAME_MATCH_FLOW_V1_BLINK_RELIABLE_REMOTE "\003"
            4) task.wait(1.5)
            5) TeleportService:Teleport(16146832113, LocalPlayer)
        - Quy ước tăng bộ đếm Config.Current += 1 ngay khi thấy màn hình kết thúc.
        - Quyết định tại EndScreen lần N: nếu ReturnAtN và Current >= TargetN -> exitToLobby ngay tại EndScreen đó;
          ngược lại nếu AutoReplay -> click(retryBtn).
        - Button thực tế: PlayerGui.EndScreen.Holder.Buttons.Retry.Button là TextButton.
        - Tương tác click: firesignal(Activated) / firesignal(MouseButton1Click) + VirtualInputManager ở tâm nút.
      [CANDIDATE]
        - Đường dẫn GUI HUD.EndFrame (Retry/Leave) và EndScreen.Holder.Buttons (Retry/Leave).
        - Remote Retry: AV_GAME_ENDSCREEN_V1_BLINK_RELIABLE_REMOTE "\003" (capture từ network log).
        - Kiểm tra inMatch: HUD.Map.WavesAmount ~= nil.
      [UNTESTED]
        - Bản tích hợp mới sau khi ghép vào kiến trúc LotusHub và standalone Bealloween.
      [MISSING]
        - Không có thành phần nào bị thiếu; toàn bộ Remote, GUI path và PlaceId đều lấy từ raw và capture thực tế.

    QUY TẮC BẢO VỆ:
      1) Mỗi EndScreen chỉ xử lý tăng đếm và kích hoạt nhánh MỘT LẦN (chống lặp vô hạn khi GUI đứng yên).
      2) Độc lập 2 toggle: AutoReplay và ReplayLimitEnabled; hủy tác vụ cũ khi ctx.alive = false.
      3) Không tạo ScreenGui phụ; đồng bộ trực tiếp với UI trong Gameplay.lua qua ctx.replayProgressSink.
]]
local Replay = {}

function Replay.Init(ctx, ui)
    local state = ctx.state
    local playerGui = ctx.playerGui
    local rs = game:GetService("ReplicatedStorage")
    local players = game:GetService("Players")
    local player = players.LocalPlayer or players.PlayerAdded:Wait()

    -- [CẤU HÌNH & HẰNG SỐ RAW]
    local LOBBY_ID = 16146832113
    local RETRY_REMOTE_NAME = "AV_GAME_ENDSCREEN_V1_BLINK_RELIABLE_REMOTE"
    local MATCH_FLOW_REMOTE_NAME = "AV_GAME_MATCH_FLOW_V1_BLINK_RELIABLE_REMOTE"

    local CONFIG = {
        PollInterval = 0.35,            -- Quét GUI khoảng 3 lần/giây theo raw
        LobbyWaitAfterClick = 0.8,     -- task.wait(0.8) từ raw sau khi click Leave
        LobbyWaitAfterRemote = 1.5,    -- task.wait(1.5) từ raw sau khi gửi MATCH_FLOW
        RetryCooldown = 6.0,           -- Chờ 6s trước khi thử lại nếu EndScreen chưa tắt
        MaxRetryAttempts = 2,          -- Tối đa 2 lần thử Retry cho cùng 1 EndScreen
    }

    local session = {
        count = 0,                     -- Bộ đếm lượt EndScreen (quy ước của raw)
        endScreenActive = false,       -- Trạng thái EndScreen đang hiển thị
        handledThisEndScreen = false,  -- Đã xử lý EndScreen hiện tại (chống đếm trùng / spam)
        retryAttempts = 0,             -- Số lần đã thử Retry trong EndScreen này
        lastRetryAt = nil,             -- Thời điểm thử Retry gần nhất
        lobbyTriggered = false,        -- Đã gọi exitToLobby trong EndScreen này (chống loop teleport)
        lobbyRunning = false,          -- Đang trong tiến trình chạy chuỗi exitToLobby
        tickRunning = false,           -- Chống re-entrancy trong tick
        lastStatus = nil,
        lobbyHandler = nil,            -- Hook tùy chọn nếu cần mở rộng
        logs = {},
    }

    local function log(message)
        print("[LotusHub Replay] " .. message)
    end

    local function logOnce(key, message)
        if session.logs[key] ~= message then
            session.logs[key] = message
            log(message)
        end
    end

    -- [KIỂM TRA GUI HIỂN THỊ THẬT]
    local function visible(obj)
        if not obj or not obj:IsA("GuiObject") then return false end
        if obj.AbsoluteSize.X <= 0 or obj.AbsoluteSize.Y <= 0 then return false end

        local node = obj
        while node and node ~= playerGui do
            if node:IsA("GuiObject") and not node.Visible then return false end
            if node:IsA("ScreenGui") and not node.Enabled then return false end
            node = node.Parent
        end
        return node == playerGui
    end

    -- [RAW inMatch: HUD.Map.WavesAmount ~= nil]
    local function isInMatch()
        local hud = playerGui:FindFirstChild("HUD")
        local map = hud and hud:FindFirstChild("Map")
        local waves = map and map:FindFirstChild("WavesAmount")
        return waves ~= nil and visible(waves)
    end

    -- [RAW getEndButtons: Ưu tiên HUD.EndFrame, fallback EndScreen.Holder.Buttons]
    local function findButtonInContainer(container, name)
        if not container then return nil end
        local item = container:FindFirstChild(name)
        if not item then return nil end

        -- 1. Nếu chính nó là GuiButton đang hiển thị
        if item:IsA("GuiButton") and visible(item) then
            return item
        end
        -- 2. Button con (VERIFIED: EndScreen.Holder.Buttons.Retry.Button là TextButton)
        local btn = item:FindFirstChild("Button")
        if btn and btn:IsA("GuiButton") and visible(btn) then
            return btn
        end
        -- 3. Body con (CANDIDATE: HUD.EndFrame.Retry.Body / Leave.Body)
        local body = item:FindFirstChild("Body")
        if body and visible(body) then
            return body
        end
        -- 4. Bất kỳ GuiButton con nào
        local anyBtn = item:FindFirstChildWhichIsA("GuiButton", true)
        if anyBtn and visible(anyBtn) then
            return anyBtn
        end
        -- 5. Fallback GuiObject nếu container visible
        if visible(item) then
            return item
        end
        return nil
    end

    local function getEndButtons()
        -- Nhánh 1: HUD.EndFrame (ưu tiên raw)
        local hud = playerGui:FindFirstChild("HUD")
        local endFrame = hud and hud:FindFirstChild("EndFrame")
        if endFrame and visible(endFrame) then
            local retry = findButtonInContainer(endFrame, "Retry")
            local leave = findButtonInContainer(endFrame, "Leave")
            if retry or leave then
                return retry, leave, "HUD.EndFrame"
            end
        end

        -- Nhánh 2: EndScreen.Holder.Buttons (fallback raw / verified log)
        local endScreen = playerGui:FindFirstChild("EndScreen")
        local holder = endScreen and endScreen:FindFirstChild("Holder")
        local buttons = holder and holder:FindFirstChild("Buttons")
        if buttons and visible(buttons) then
            local retry = findButtonInContainer(buttons, "Retry")
            local leave = findButtonInContainer(buttons, "Leave")
            if retry or leave then
                return retry, leave, "EndScreen.Holder.Buttons"
            end
        end

        -- Nhánh 3: Fallback tìm trực tiếp trong EndScreen / Holder
        if endScreen and visible(endScreen) then
            local retry = findButtonInContainer(holder or endScreen, "Retry")
            local leave = findButtonInContainer(holder or endScreen, "Leave")
            if retry or leave then
                return retry, leave, "EndScreen"
            end
        end

        return nil, nil, nil
    end

    -- [RAW click: firesignal + VirtualInputManager ở tâm nút]
    local function isCoveredByMenu(btn)
        if not btn or not ctx.screen or not ctx.screen.Enabled then return false end
        local main = ctx.screen:FindFirstChild("Main") or ctx.screen:FindFirstChildWhichIsA("Frame")
        if not main or not main.Visible then return false end

        local btnPos = btn.AbsolutePosition
        local btnSize = btn.AbsoluteSize
        local cx = btnPos.X + (btnSize.X / 2)
        local cy = btnPos.Y + (btnSize.Y / 2)

        local mPos = main.AbsolutePosition
        local mSize = main.AbsoluteSize
        return (cx >= mPos.X and cx <= mPos.X + mSize.X and cy >= mPos.Y and cy <= mPos.Y + mSize.Y)
    end

    local function click(btn)
        if not btn or not ctx.alive then return false end
        local clicked = false

        -- 1. firesignal (Activated & MouseButton1Click) theo raw
        if type(firesignal) == "function" and btn:IsA("GuiButton") then
            pcall(function() firesignal(btn.Activated) end)
            pcall(function() firesignal(btn.MouseButton1Click) end)
            clicked = true
        end

        -- 2. VirtualInputManager ở tâm nút theo raw
        if isCoveredByMenu(btn) then
            logOnce("covered", "Tọa độ nút bị menu LotusHub che; ưu tiên firesignal và gửi click VIM.")
        end

        local vimOk, vim = pcall(function() return game:GetService("VirtualInputManager") end)
        if vimOk and vim then
            pcall(function()
                local pos = btn.AbsolutePosition
                local size = btn.AbsoluteSize
                local x = pos.X + (size.X / 2)
                local y = pos.Y + (size.Y / 2)
                vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
                task.wait(0.05)
                vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
                clicked = true
            end)
        end

        return clicked
    end

    -- [RAW exitToLobby: KHÔI PHỤC TOÀN BỘ CHUỖI ĐÃ ĐƯỢC TEST THÀNH CÔNG]
    -- Thứ tự: click Leave -> wait 0.8s -> Remote MATCH_FLOW 03 -> wait 1.5s -> Teleport LOBBY_ID
    local function exitToLobby(leaveBtn)
        if session.lobbyRunning then return end
        session.lobbyRunning = true

        log("Bắt đầu chuỗi về Lobby đã xác minh (VERIFIED raw workflow)...")

        -- Bước 1: Click Leave button nếu có
        if leaveBtn then
            log("Bước 1: Click Leave button (" .. tostring(leaveBtn:GetFullName()) .. ")")
            click(leaveBtn)
            task.wait(CONFIG.LobbyWaitAfterClick)
        else
            log("Bước 1: Không có GUI Leave hiển thị, chuyển thẳng sang bước Remote.")
        end

        if not ctx.alive or state.ReplayLimitEnabled ~= true then
            session.lobbyRunning = false
            return
        end

        -- Bước 2: AV_GAME_MATCH_FLOW_V1_BLINK_RELIABLE_REMOTE "\003"
        local matchFlowRemote = rs:FindFirstChild(MATCH_FLOW_REMOTE_NAME)
        if matchFlowRemote and matchFlowRemote:IsA("RemoteEvent") then
            log("Bước 2: Gửi Remote " .. MATCH_FLOW_REMOTE_NAME .. " buffer 0x03")
            pcall(function()
                matchFlowRemote:FireServer(buffer.fromstring("\003"))
            end)
        else
            log("Bước 2: Không tìm thấy Remote " .. MATCH_FLOW_REMOTE_NAME .. ", tiếp tục fallback Teleport.")
        end

        if not ctx.alive or state.ReplayLimitEnabled ~= true then
            session.lobbyRunning = false
            return
        end

        task.wait(CONFIG.LobbyWaitAfterRemote)

        if not ctx.alive or state.ReplayLimitEnabled ~= true then
            session.lobbyRunning = false
            return
        end

        -- Bước 3: TeleportService:Teleport(16146832113, LocalPlayer)
        local tsOk, ts = pcall(function() return game:GetService("TeleportService") end)
        if tsOk and ts then
            log("Bước 3: Gọi TeleportService:Teleport về Lobby (PlaceId: " .. tostring(LOBBY_ID) .. ")")
            pcall(function()
                ts:Teleport(LOBBY_ID, player)
            end)
        else
            warn("[LotusHub Replay] Không thể khởi tạo TeleportService")
        end

        session.lobbyRunning = false
    end

    -- [RAW doRetry: Click retryBtn + gửi Remote Retry "\003"]
    local function doRetry(retryBtn)
        log("Thực hiện thao tác Retry (EndScreen #" .. session.count .. ", lần thử " .. session.retryAttempts .. ")...")

        if retryBtn then
            log("Click Retry button: " .. tostring(retryBtn:GetFullName()))
            click(retryBtn)
        else
            log("Không có nút Retry GUI trực tiếp, chuyển sang gửi Remote Retry.")
        end

        -- Remote Retry đã capture: AV_GAME_ENDSCREEN_V1_BLINK_RELIABLE_REMOTE "\003"
        task.wait(0.2)
        local retryRemote = rs:FindFirstChild(RETRY_REMOTE_NAME)
        if retryRemote and retryRemote:IsA("RemoteEvent") then
            pcall(function()
                retryRemote:FireServer(buffer.fromstring("\003"))
                log("Đã gửi Remote Retry " .. RETRY_REMOTE_NAME .. " buffer 0x03")
            end)
        end
    end

    -- [ĐỌC SLIDER N]
    local function replayLimit()
        return math.clamp(math.floor(tonumber(state.ReplayLimit) or 20), 1, 100)
    end

    local function limitReached()
        return state.ReplayLimitEnabled == true and session.count >= replayLimit()
    end

    -- [CẬP NHẬT TIẾN ĐỘ VỀ UI GAMEPLAY]
    local function updateProgress()
        local status = string.format("%d/%d/%s/%s", session.count, replayLimit(),
            tostring(state.ReplayLimitEnabled), tostring(session.lobbyTriggered))
        if session.lastStatus == status then return end
        session.lastStatus = status

        if type(ctx.replayProgressSink) == "function" then
            ctx.replayProgressSink(session.count, replayLimit(),
                limitReached() and "Chờ kết thúc để về Lobby" or nil)
        end
    end

    -- [VÒNG LẶP XỬ LÝ TICK THEO ĐÚNG NGUYÊN BẢN RAW]
    local function tick()
        if not ctx.alive or session.tickRunning then return end
        session.tickRunning = true

        local ok, err = pcall(function()
            local now = os.clock()
            local retryBtn, leaveBtn, source = getEndButtons()
            local isEndVisible = (retryBtn ~= nil) or (leaveBtn ~= nil)

            -- 1. Xử lý khi EndScreen biến mất (đã chuyển Stage hoặc chuyển Place)
            if not isEndVisible then
                if session.endScreenActive then
                    session.endScreenActive = false
                    session.handledThisEndScreen = false
                    session.retryAttempts = 0
                    session.lastRetryAt = nil
                    session.lobbyTriggered = false
                    log("EndScreen đã biến mất; đặt lại trạng thái sẵn sàng cho trận tiếp theo.")
                end
                updateProgress()
                return
            end

            -- 2. Xử lý khi phát hiện EndScreen mới
            if not session.endScreenActive then
                session.endScreenActive = true
                session.handledThisEndScreen = false
                session.retryAttempts = 0
                session.lastRetryAt = nil
                session.lobbyTriggered = false
                log("Phát hiện màn hình kết thúc trận tại: " .. tostring(source))
            end

            -- 3. XỬ LÝ MỘT LẦN CHO MỖI ENDSCREEN (BẢO VỆ CHỐNG ĐẾM TRÙNG & SPAM)
            if not session.handledThisEndScreen then
                local returnAtN = (state.ReplayLimitEnabled == true)
                local autoReplay = (state.AutoReplay == true)

                -- Nếu cả 2 toggle đều tắt, không đếm và không thao tác
                if not returnAtN and not autoReplay then
                    logOnce("bothOff", "EndScreen hiển thị nhưng AutoReplay và ReplayLimit đều OFF. Chờ người dùng.")
                    updateProgress()
                    return
                end

                -- Tăng bộ đếm theo đúng ngữ nghĩa raw (Config.Current += 1)
                session.count += 1
                session.handledThisEndScreen = true
                updateProgress()

                local targetN = replayLimit()
                log("EndScreen #" .. session.count .. " (Mốc N=" .. targetN .. ", ReturnAtN=" .. tostring(returnAtN) .. ", AutoReplay=" .. tostring(autoReplay) .. ")")

                -- Nhánh quyết định của raw:
                -- if ReturnAtN and Current >= TargetN then exitToLobby(...) elseif AutoReplay then click(retryBtn)
                if returnAtN and session.count >= targetN then
                    log("ĐÃ ĐẠT MỐC N (" .. session.count .. " >= " .. targetN .. "). Kích hoạt chuỗi về Lobby ngay tại EndScreen này!")
                    session.lobbyTriggered = true

                    -- Nếu có Custom Lobby Handler do user đăng ký, ưu tiên gọi
                    if type(session.lobbyHandler) == "function" then
                        log("Gọi Custom Lobby Handler...")
                        pcall(session.lobbyHandler, {
                            count = session.count,
                            limit = targetN,
                            reason = "ReplayLimit",
                        })
                    else
                        task.spawn(function()
                            exitToLobby(leaveBtn)
                        end)
                    end
                elseif autoReplay then
                    log("Chưa đạt mốc N hoặc ReplayLimit OFF. Kích hoạt Retry...")
                    session.retryAttempts += 1
                    session.lastRetryAt = now
                    task.spawn(function()
                        doRetry(retryBtn)
                    end)
                else
                    -- Case D: ReplayLimitEnabled=ON, AutoReplay=OFF, nhưng count < targetN
                    log("ReplayLimitEnabled=ON nhưng AutoReplay=OFF và chưa đạt mốc N (" .. session.count .. " < " .. targetN .. "). Giữ nguyên trạng thái, không Retry.")
                end
                return
            end

            -- 4. EndScreen vẫn đang hiển thị sau khi đã xử lý (Case E: đứng yên >10s)
            -- Không bao giờ đếm lại hay gọi Teleport lại!
            if state.AutoReplay == true and not limitReached() then
                -- Nếu Retry chưa làm ẩn EndScreen, cho phép thử lại tối đa MaxRetryAttempts lần sau cooldown
                if session.retryAttempts < CONFIG.MaxRetryAttempts then
                    if session.lastRetryAt and (now - session.lastRetryAt >= CONFIG.RetryCooldown) then
                        session.retryAttempts += 1
                        session.lastRetryAt = now
                        log("EndScreen vẫn hiện sau " .. CONFIG.RetryCooldown .. "s. Thử lại Retry lần " .. session.retryAttempts .. "/" .. CONFIG.MaxRetryAttempts .. "...")
                        task.spawn(function()
                            doRetry(retryBtn)
                        end)
                    end
                else
                    logOnce("retryMaxed", "Đã thử Retry tối đa " .. session.retryAttempts .. " lần ở EndScreen này. Dừng retry để tránh spam.")
                end
            elseif limitReached() then
                logOnce("lobbyWaiting", "Đã gửi lệnh về Lobby cho EndScreen hiện tại; không gửi lặp lại.")
            end

            updateProgress()
        end)

        session.tickRunning = false
        if not ok then
            warn("[LotusHub Replay] LỖI tick: " .. tostring(err))
        end
    end

    -- [XỬ LÝ SỰ KIỆN TOGGLE]
    ui:SetToggleHandler("AutoReplay", function(enabled)
        log("AutoReplay = " .. tostring(enabled))
        if enabled then
            task.defer(tick)
        end
        updateProgress()
    end)

    ui:SetToggleHandler("ReplayLimitEnabled", function(enabled)
        log("ReplayLimitEnabled = " .. tostring(enabled) .. " | N=" .. replayLimit())
        if enabled then
            task.defer(tick)
        end
        updateProgress()
    end)

    -- [API BỘ ĐẾM & TRẠNG THÁI]
    function ui:SetReplayLobbyHandler(fn)
        assert(type(fn) == "function", "SetReplayLobbyHandler yêu cầu function")
        session.lobbyHandler = fn
        task.defer(tick)
    end

    function ui:GetReplayStatus()
        return {
            count = session.count,
            limit = replayLimit(),
            autoReplay = state.AutoReplay == true,
            returnToLobby = state.ReplayLimitEnabled == true,
            lobbyIntegrated = true,
            pending = session.endScreenActive,
            waitingForLobby = limitReached(),
            lobbyRequested = session.lobbyTriggered,
        }
    end

    function ui:ResetReplayCount()
        session.count = 0
        session.endScreenActive = false
        session.handledThisEndScreen = false
        session.retryAttempts = 0
        session.lastRetryAt = nil
        session.lobbyTriggered = false
        session.logs = {}
        log("Đã reset số đếm Replay về 0 theo yêu cầu")
        updateProgress()
    end

    -- [KHỞI TẠO DUY NHẤT 1 WORKER]
    task.spawn(function()
        while ctx.alive do
            tick()
            task.wait(CONFIG.PollInterval)
        end
        log("Worker Replay đã dừng do ctx.alive = false.")
    end)
end

return Replay
end)()
-- END MODULE Replay

local env = ((type(getgenv) == "function") and getgenv()) or _G
local Players = game:GetService("Players")
local player = Players.LocalPlayer
if not player then error("[LotusHub] LocalPlayer chưa sẵn sàng") end
local Menu, Gameplay, Match, Replay = Modules.Menu, Modules.Gameplay, Modules.Match, Modules.Replay

-- [START] Chỉ khi import xong mới dọn phiên cũ, tránh trùng worker/GUI.
if type(env.LotusHubUI) == "table" and type(env.LotusHubUI.Destroy) == "function" then
    pcall(function() env.LotusHubUI:Destroy() end)
end
local playerGui = player:WaitForChild("PlayerGui")
local leftoverGui = playerGui:FindFirstChild("LotusHub_Gameplay_UI_Demo")
if leftoverGui then leftoverGui:Destroy() end

local ctx = {
    env = env,
    playerGui = playerGui,
    state = {},
    expanded = {},
    knownModifiers = {}, -- MISSING: không tự bịa modifier.
    connections = {},
    alive = true,
    screen = nil,
}

-- Đăng ký listener để dọn sạch khi đóng UI hoặc Execute lại.
function ctx:Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.connections, connection)
    return connection
end

function ctx:Destroy()
    if not self.alive then return end
    self.alive = false -- Ngăn worker Match thực hiện thao tác mới.
    for _, connection in ipairs(self.connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(self.connections)
    if self.screen then
        pcall(function() self.screen:Destroy() end)
        self.screen = nil
    end
    if self.env.LotusHubUI == self.ui then self.env.LotusHubUI = nil end
end

-- [GẮN MODULE] Lần lượt tạo UI, đăng ký Gameplay, nối Match vào toggle.
local ok, err = pcall(function()
    local ui = Menu.Create(ctx)
    ctx.ui = ui
    Gameplay.Init(ctx, ui)
    Match.Init(ctx, ui)
    Replay.Init(ctx, ui)
    env.LotusHubUI = ui -- API tương thích bản cũ.
    ui:ShowTab("Gameplay")
end)

if not ok then
    ctx:Destroy()
    error("[LotusHub] Khởi động thất bại: " .. tostring(err))
end

print("[LotusHub] Đã nạp Menu + Gameplay + Match V3 + Replay (Khôi phục Auto Replay -> Lobby Raw).")
