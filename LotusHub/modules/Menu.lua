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
