--[[
    LOTUSHUB / run_all_standalone.lua — SCRIPT CHẠY ĐƠN FILE.
    TỰ ĐỘNG GỘP TỪ: run_all.lua + Menu + Gameplay + Modifiers + Match + Replay + Boost + AutoPick + Restart.
    Để chỉnh source: sửa file module trong modules/, sau đó chạy scripts/build_standalone.py.
    Không cần readfile, không tự tải bất kỳ dữ liệu mạng nào.
]]

local Modules = {}

-- BEGIN MODULE Menu
Modules.Menu = (function()
--[[
    LotusHub / modules/Menu.lua — REBUILD TOÀN BỘ GIAO DIỆN MENU.
    Kiến trúc UI được tái cấu trúc hoàn chỉnh từ đầu:
    1. KHU VỰC ĐIỀU KHIỂN GÓC PHẢI (TopControls):
       - Tách biệt hoàn toàn khỏi Header và các label tự co giãn.
       - Neo cố định tuyệt đối ở góc trên-phải của Main Frame (AnchorPoint 1, 0).
       - Hai nút Minimize (−) và Close (×) có kích thước 42x34, neo vĩnh viễn theo offset (-84 và -34).
       - Tuyệt đối KHÔNG có animation, KHÔNG tween, KHÔNG đổi màu, KHÔNG phóng to/thu nhỏ khi hover/click.
    2. CÔNG TẮC ON/OFF (toggleItem):
       - Hoạt động theo cơ chế toggle switch truyền thống nhưng không dùng TweenService.
       - OFF: Nền tối (C.track), núm trắng nằm bên TRÁI (3, 3), state = false.
       - ON: Nền sáng (C.on), núm trắng nằm bên PHẢI (41, 3), state = true.
       - Chuyển đổi vị trí và màu sắc tức thì khi click, gọi đúng handler, không có animation trung gian.
    3. HỆ THỐNG NÚT BẤM TOÀN DIỆN:
       - Tất cả TextButton đều có AutoButtonColor = false, loại bỏ hoàn toàn hiện tượng lún/nhún/dịch của Roblox.
       - Các section đóng/mở tức thì, slider kéo mượt mà, sidebar tab chuyển tức thì.
    4. BẢO TOÀN VÒNG ĐỜI & API:
       - Tương thích 100% với Gameplay.lua, Match.lua, Replay.lua, BoostPerformance.lua.
       - Hỗ trợ đầy đủ RegisterTab, ShowTab, SetToggleHandler, GetState, Destroy.
]]
local Menu = {}

function Menu.Create(ctx)
    local UserInputService = game:GetService("UserInputService")
    local ContextActionService = game:GetService("ContextActionService")
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local localPlayer = Players.LocalPlayer
    local playerGui = ctx.playerGui
    local env = ctx.env
    local state = ctx.state
    local expanded = ctx.expanded
    local controller

    -- Bọc Connect để run_all có thể ngắt toàn bộ khi đóng/Execute lại.
    local function connect(signal, callback)
        return ctx:Connect(signal, callback)
    end

    -- [C] BẢNG MÀU CHUẨN KIM LOẠI BẠC TỐI CỦA LOTUSHUB
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

    -- [G] CÁC HÀM TẠO GUI CƠ BẢN
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
    local screen = new("ScreenGui", playerGui, {
        Name = "LotusHub_Gameplay_UI_Demo",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        DisplayOrder = 600,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    -- Khung cửa sổ chính 940x590, vị trí trung tâm màn hình
    local main = corner(new("Frame", screen, {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(940, 590),
        BorderSizePixel = 0,
        BackgroundColor3 = C.panel,
        BackgroundTransparency = 0.17,
        ClipsDescendants = true,
        Active = true,
    }), 12)
    stroke(main, 0.48)

    -- UIScale phục vụ co giãn responsive trên nhiều độ phân giải
    local uiScale = new("UIScale", main, { Scale = 1 })

    -- [I] KHU VỰC ĐIỀU KHIỂN CỐ ĐỊNH Ở GÓC PHẢI (TOP CONTROLS)
    -- Tách biệt hoàn toàn khỏi Header để triệt tiêu 100% hiện tượng dịch chuyển do text hoặc responsive
    local topControls = new("Frame", main, {
        Name = "TopControls",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(130, 61),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 10,
        Active = false,
    })

    local BOX_SIZE = UDim2.fromOffset(42, 34)
    local TEXT_SIZE = 26

    -- Diagnostic kiểm tra tọa độ tâm (mặc định OFF, bật bằng getgenv().LotusHubDebugButtons = true)
    local DEBUG_BUTTON_COORDS = (ctx and ctx.debugButtonCoords)
        or (env and env.LotusHubDebugButtons)
        or false

    local function createTopBoxButton(name, text, xCenterOffset)
        -- TextButton dạng hộp phẳng cố định tuyệt đối trong TopControls
        -- AutoButtonColor = false chặn triệt để hiệu ứng nhún/lún mặc định của Roblox
        local button = corner(new("TextButton", topControls, {
            Name = name,
            Size = BOX_SIZE,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(1, xCenterOffset, 0.5, 0),
            BackgroundColor3 = Color3.fromRGB(38, 41, 46),
            BackgroundTransparency = 0.25,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Active = true,
            Selectable = false,
            Text = "",
            ClipsDescendants = false,
            ZIndex = 11,
        }), 6)

        -- Viền hộp kim loại bạc cố định
        stroke(button, 0.45)

        -- Ký tự − hoặc × căn chính giữa, font GothamBold, màu bạc tĩnh, không animation
        label(button, text, {
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(1, 1),
            Text = text,
            TextColor3 = C.silver,
            TextSize = TEXT_SIZE,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            Active = false,
            ZIndex = 12,
        })

        if DEBUG_BUTTON_COORDS then
            local function logButtonState(evt)
                task.defer(function()
                    if button and button.Parent then
                        local ap = button.AbsolutePosition
                        local as = button.AbsoluteSize
                        local center = ap + as / 2
                        print(string.format("[LotusHub Diagnostic] %s:%s | Pos=(%.1f, %.1f) | Size=(%.1f, %.1f) | Center=(%.1f, %.1f) | Scale=%.3f",
                            name, evt, ap.X, ap.Y, as.X, as.Y, center.X, center.Y, uiScale and uiScale.Scale or 1))
                    end
                end)
            end
            logButtonState("Init")
            button.MouseButton1Click:Connect(function()
                logButtonState("Click")
            end)
        end

        return button
    end

    -- Hai nút nằm cố định theo offset chính xác từ mép phải của cửa sổ:
    -- CloseButton: tâm cách mép phải 34px (xCenterOffset = -34)
    -- MinimizeButton: tâm cách mép phải 84px (xCenterOffset = -84)
    local minimizeButton = createTopBoxButton("MinimizeButton", "−", -84)
    local closeButton = createTopBoxButton("CloseButton", "×", -34)

    -- [I.1] THANH TIÊU ĐỀ (HEADER) VÀ LOGO
    -- Header chỉ trải dài đến mép vùng điều khiển (1, -130), không chạm vào hai nút
    local header = new("Frame", main, {
        Name = "TitleBar",
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, -130, 0, 61),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 5,
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
        Size = UDim2.fromOffset(290, 52),
        Font = Enum.Font.GothamSemibold,
        TextSize = 23,
    })

    label(header, "[Early Access]", {
        Position = UDim2.fromOffset(355, 6),
        Size = UDim2.fromOffset(120, 52),
        Font = Enum.Font.GothamSemibold,
        TextColor3 = C.muted,
        TextSize = 15,
    })

    -- Đường kẻ mảnh phân cách thanh tiêu đề và thân menu
    new("Frame", main, {
        Name = "Divider",
        Position = UDim2.fromOffset(20, 62),
        Size = UDim2.new(1, -40, 0, 1),
        BackgroundColor3 = C.silver,
        BackgroundTransparency = 0.68,
        BorderSizePixel = 0,
        ZIndex = 6,
    })

    -- [I.2] NÚT TRÒN KHI THU NHỎ MENU (RESTORE BUBBLE)
    local restoreBubble = new("TextButton", screen, {
        Name = "RestoreBubble",
        Size = UDim2.fromOffset(60, 60),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = C.panel,
        BackgroundTransparency = 0.1,
        Text = "✿",
        TextColor3 = C.silver,
        TextSize = 30,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Active = true,
        Selectable = false,
        Visible = false,
        ZIndex = 100,
    })
    new("UICorner", restoreBubble, { CornerRadius = UDim.new(1, 0) })
    stroke(restoreBubble, 0.48)

    -- [J] THÂN CỬA SỔ: SIDEBAR + VÙNG CUỘN NỘI DUNG
    local body = new("Frame", main, {
        Name = "Body",
        Position = UDim2.fromOffset(0, 66),
        Size = UDim2.new(1, 0, 1, -66),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 2,
    })

    local sidebar = new("Frame", body, {
        Name = "Sidebar",
        Position = UDim2.fromOffset(18, 23),
        Size = UDim2.fromOffset(224, 442),
        BackgroundTransparency = 1,
        Active = true,
    })
    vertical(sidebar, 11)

    -- Vạch dọc phân cách sidebar và nội dung
    new("Frame", body, {
        Name = "SidebarSeparator",
        Position = UDim2.fromOffset(255, 22),
        Size = UDim2.new(0, 1, 1, -70),
        BorderSizePixel = 0,
        BackgroundColor3 = C.muted,
        BackgroundTransparency = 0.68,
    })

    local sectionTitle = label(body, "Gameplay", {
        Name = "TabTitle",
        Position = UDim2.fromOffset(276, 13),
        Size = UDim2.new(1, -302, 0, 63),
        Font = Enum.Font.GothamBold,
        TextSize = 32,
    })

    local scroll = new("ScrollingFrame", body, {
        Name = "ContentScroll",
        Position = UDim2.fromOffset(276, 94),
        Size = UDim2.new(1, -297, 1, -146),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.muted,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        VerticalScrollBarInset = Enum.ScrollBarInset.None,
        Active = true,
        Selectable = false,
    })
    vertical(scroll, 11)
    new("UIPadding", scroll, {
        PaddingTop = UDim.new(0, 2),
        PaddingRight = UDim.new(0, 5),
        PaddingBottom = UDim.new(0, 10),
    })

    local footer = label(main, "LotusHub Modular · Match v3 tích hợp; mục khác chưa nối", {
        Position = UDim2.new(0, 20, 1, -25),
        Size = UDim2.new(1, -40, 0, 20),
        TextColor3 = C.muted,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    -- [K] HỆ THỐNG TAB VÀ SIDEBAR NÚT ĐIỀU HƯỚNG
    local currentTab = nil
    local tabs = {}
    local tabBuilders = {}
    local tabButtons = {}

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
            Active = true,
            Selectable = false,
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

    local function clearContent()
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        scroll.CanvasPosition = Vector2.zero
    end

    -- [L] CÁC THÀNH PHẦN GIAO DIỆN CHUẨN (UI COMPONENTS)
    local function itemFrame(parent, height)
        return corner(new("Frame", parent, {
            Size = UDim2.new(1, 0, 0, height or 49),
            BackgroundColor3 = C.row,
            BackgroundTransparency = 0.26,
            BorderSizePixel = 0,
            Active = true,
            ClipsDescendants = false,
        }), 8)
    end

    -- [M] CÔNG TẮC ON/OFF HOÀN TOÀN TĨNH (KHÔNG DÙNG TWEEN)
    -- OFF: nền C.track (tối), núm trắng nằm bên TRÁI tại (3, 3), state = false
    -- ON:  nền C.on (sáng), núm trắng nằm bên PHẢI tại (41, 3), state = true
    -- Vị trí và màu sắc cập nhật tức thời bằng gán thuộc tính trực tiếp khi click
    local function toggleItem(parent, text, readValue, saveValue)
        local row = itemFrame(parent, 49)
        label(row, text, {
            Position = UDim2.fromOffset(17, 0),
            Size = UDim2.new(1, -112, 1, 0),
            TextSize = 16,
        })

        local track = corner(new("TextButton", row, {
            Name = "ToggleTrack",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -18, 0.5, 0),
            Size = UDim2.fromOffset(67, 29),
            BackgroundColor3 = C.track,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            Active = true,
            Selectable = false,
        }), 9)
        stroke(track, 0.33)

        local knob = corner(new("Frame", track, {
            Name = "ToggleKnob",
            Size = UDim2.fromOffset(23, 23),
            Position = UDim2.fromOffset(3, 3),
            BackgroundColor3 = C.silver,
            BorderSizePixel = 0,
            Active = false,
        }), 7)

        local function redraw()
            local value = (readValue() == true)
            track.BackgroundColor3 = value and C.on or C.track
            knob.Position = value and UDim2.fromOffset(41, 3) or UDim2.fromOffset(3, 3)
            knob.BackgroundColor3 = value and C.white or C.silver
        end

        redraw()

        track.MouseButton1Click:Connect(function()
            local current = (readValue() == true)
            saveValue(not current)
            redraw()
        end)

        return row
    end

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

    -- [N] NHÓM CHỨC NĂNG CÓ THỂ ĐÓNG/MỞ (SECTION)
    local function section(parent, key, displayName, defaultOpen)
        if expanded[key] == nil then
            expanded[key] = defaultOpen
        end

        local wrapper = new("Frame", parent, {
            Name = "Section_" .. key,
            LayoutOrder = #parent:GetChildren(),
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        })
        vertical(wrapper, 6)

        local button = corner(new("TextButton", wrapper, {
            Name = "SectionHeader",
            LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 49),
            BackgroundColor3 = C.row,
            BackgroundTransparency = 0.21,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Active = true,
            Selectable = false,
        }), 9)

        label(button, displayName, {
            Position = UDim2.fromOffset(17, 0),
            Size = UDim2.new(1, -76, 1, 0),
            Font = Enum.Font.GothamSemibold,
            TextSize = 19,
        })

        local arrow = label(button, expanded[key] and "⌄" or "›", {
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
            Visible = expanded[key] == true,
        })
        local contentsLayout = vertical(contents, 6)
        contentsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        new("UIPadding", contents, { PaddingTop = UDim.new(0, 2) })

        button.MouseButton1Click:Connect(function()
            local isOpen = not (expanded[key] == true)
            expanded[key] = isOpen
            contents.Visible = isOpen
            arrow.Text = isOpen and "⌄" or "›"
        end)

        return contents
    end

    -- [O] THANH KÉO (SLIDER)
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
            Active = true,
            Selectable = false,
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

    -- [P] KHỐI THÔNG TIN / GHI CHÚ
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

    -- [Q] CHUYỂN TAB ĐỘNG
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
        build(controller)
    end

    -- [R] NÚT THU NHỎ / KHÔI PHỤC MENU
    local bubbleDragging = false
    local bubbleDragStartMouse = nil
    local bubbleDragStartPos = nil
    local bubbleMoved = false

    connect(restoreBubble.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            bubbleDragging = true
            bubbleMoved = false
            bubbleDragStartMouse = input.Position
            bubbleDragStartPos = restoreBubble.Position
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if not bubbleDragging or not bubbleDragStartMouse or not bubbleDragStartPos then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - bubbleDragStartMouse
            if not bubbleMoved and delta.Magnitude >= 5 then
                bubbleMoved = true
            end
            if bubbleMoved then
                local x = math.clamp(bubbleDragStartPos.X.Offset + delta.X, 30, (screen.AbsoluteSize.X or 940) - 30)
                local y = math.clamp(bubbleDragStartPos.Y.Offset + delta.Y, 30, (screen.AbsoluteSize.Y or 590) - 30)
                restoreBubble.Position = UDim2.fromOffset(x, y)
            end
        end
    end)

    local function stopBubbleDrag()
        bubbleDragging = false
        bubbleDragStartMouse = nil
        bubbleDragStartPos = nil
        bubbleMoved = false
    end

    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            stopBubbleDrag()
        end
    end)
    connect(UserInputService.WindowFocusReleased, stopBubbleDrag)

    connect(restoreBubble.MouseButton1Click, function()
        if bubbleMoved then return end
        restoreBubble.Visible = false
        main.Visible = true
    end)

    -- Bấm nút Minimize (−) thu nhỏ menu
    connect(minimizeButton.MouseButton1Click, function()
        main.Visible = false
        local ap = main.AbsolutePosition
        local as = main.AbsoluteSize
        local x = math.clamp(ap.X + 37, 30, (screen.AbsoluteSize.X or 940) - 30)
        local y = math.clamp(ap.Y + 30, 30, (screen.AbsoluteSize.Y or 590) - 30)
        restoreBubble.Position = UDim2.fromOffset(x, y)
        restoreBubble.Visible = true
    end)

    -- [S] BẢO VỆ CHỐNG CLICK-THROUGH (CLICK-TO-MOVE SINK)
    local SINK_ACTION = "LotusHub_InputSink"
    local isHoveringMenu = false
    local isHoveringBubble = false

    local function isPosInObject(pos, obj)
        if not (obj and obj.Visible) then return false end
        local absPos = obj.AbsolutePosition
        local absSize = obj.AbsoluteSize
        return pos.X >= absPos.X and pos.X <= (absPos.X + absSize.X)
            and pos.Y >= absPos.Y and pos.Y <= (absPos.Y + absSize.Y)
    end

    local function isInputOverUI(pos)
        if pos and (isPosInObject(pos, main) or isPosInObject(pos, restoreBubble)) then
            return true
        end
        local mouseLoc = UserInputService:GetMouseLocation()
        if mouseLoc and (isPosInObject(mouseLoc, main) or isPosInObject(mouseLoc, restoreBubble)) then
            return true
        end
        return false
    end

    local function updateSink()
        local shouldSink = (isHoveringMenu and main.Visible) or (isHoveringBubble and restoreBubble.Visible)
        if shouldSink then
            pcall(function()
                ContextActionService:BindActionAtPriority(
                    SINK_ACTION,
                    function()
                        return Enum.ContextActionResult.Sink
                    end,
                    false,
                    Enum.ContextActionPriority.High.Value + 3000,
                    Enum.UserInputType.MouseButton1,
                    Enum.UserInputType.MouseButton2,
                    Enum.UserInputType.Touch
                )
            end)
        else
            pcall(function()
                ContextActionService:UnbindAction(SINK_ACTION)
            end)
        end
    end

    connect(main.MouseEnter, function()
        isHoveringMenu = true
        updateSink()
    end)
    connect(main.MouseLeave, function()
        isHoveringMenu = false
        updateSink()
    end)
    connect(restoreBubble.MouseEnter, function()
        isHoveringBubble = true
        updateSink()
    end)
    connect(restoreBubble.MouseLeave, function()
        isHoveringBubble = false
        updateSink()
    end)

    connect(main:GetPropertyChangedSignal("Visible"), function()
        if not main.Visible then isHoveringMenu = false end
        updateSink()
    end)
    connect(restoreBubble:GetPropertyChangedSignal("Visible"), function()
        if not restoreBubble.Visible then isHoveringBubble = false end
        updateSink()
    end)

    local function cancelHumanoidMovement()
        local mouseLoc = UserInputService:GetMouseLocation()
        if isInputOverUI(mouseLoc) then
            pcall(function()
                local char = localPlayer and localPlayer.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hum and hrp then
                        hum:MoveTo(hrp.Position)
                    end
                end
            end)
        end
    end

    connect(UserInputService.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if isInputOverUI(input.Position) then
                cancelHumanoidMovement()
            end
        end
    end)

    -- Hook ClickToMove Controller của Roblox để chặn Click-to-Move xuyên thấu
    task.spawn(function()
        pcall(function()
            local ps = localPlayer and localPlayer:WaitForChild("PlayerScripts", 3)
            if not ps then return end
            local playerModule = require(ps:WaitForChild("PlayerModule", 3))
            local controls = nil
            pcall(function() controls = playerModule:GetControls() end)

            local ctm = nil
            pcall(function()
                if controls and type(controls.GetClickToMoveController) == "function" then
                    ctm = controls:GetClickToMoveController()
                elseif type(playerModule.GetClickToMoveController) == "function" then
                    ctm = playerModule:GetClickToMoveController()
                elseif controls and controls.clickToMoveController then
                    ctm = controls.clickToMoveController
                end
            end)

            if ctm and type(ctm.OnTap) == "function" and not ctm._lotusHooked then
                ctm._lotusHooked = true
                local originalOnTap = ctm.OnTap
                ctm.OnTap = function(self, tapPositions, goToPoint, wasTouchTap)
                    local mouseLoc = UserInputService:GetMouseLocation()
                    if isInputOverUI(mouseLoc) then
                        return
                    end
                    return originalOnTap(self, tapPositions, goToPoint, wasTouchTap)
                end
            end
        end)
    end)

    -- [T] KÉO CỬA SỔ BẰNG THANH TIÊU ĐỀ (HEADER DRAG)
    local dragging = false
    local dragTouch = nil
    local dragStartMousePos = nil
    local dragStartWindowPos = nil
    local dragMoved = false
    local DRAG_DEADZONE = 5

    local function isInsideButton(pos, btn, padding)
        if not (btn and btn.Visible) then return false end
        local pad = padding or 0
        local ap = btn.AbsolutePosition
        local as = btn.AbsoluteSize
        return pos.X >= (ap.X - pad) and pos.X <= (ap.X + as.X + pad)
            and pos.Y >= (ap.Y - pad) and pos.Y <= (ap.Y + as.Y + pad)
    end

    local function isInTopButtonZone(pos)
        if isInsideButton(pos, closeButton, 8) or isInsideButton(pos, minimizeButton, 8) then
            return true
        end
        if topControls and topControls.Visible then
            local tap = topControls.AbsolutePosition
            local tas = topControls.AbsoluteSize
            if pos.X >= (tap.X - 5) and pos.X <= (tap.X + tas.X + 5)
                and pos.Y >= (tap.Y - 5) and pos.Y <= (tap.Y + tas.Y + 5) then
                return true
            end
        end
        return false
    end

    connect(header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            if isInTopButtonZone(input.Position) then
                return
            end

            dragging = true
            dragMoved = false
            dragTouch = (input.UserInputType == Enum.UserInputType.Touch) and input or nil
            dragStartMousePos = input.Position
            dragStartWindowPos = main.Position
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if not dragging or not dragStartMousePos or not dragStartWindowPos then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or (input.UserInputType == Enum.UserInputType.Touch and input == dragTouch) then
            local currentPos = input.Position
            local deltaPix = currentPos - dragStartMousePos

            if not dragMoved then
                if deltaPix.Magnitude >= DRAG_DEADZONE then
                    dragMoved = true
                else
                    return
                end
            end

            local scale = uiScale and uiScale.Scale or 1
            if scale <= 0 then scale = 1 end
            local deltaScaled = deltaPix / scale

            main.Position = UDim2.new(
                dragStartWindowPos.X.Scale, dragStartWindowPos.X.Offset + deltaScaled.X,
                dragStartWindowPos.Y.Scale, dragStartWindowPos.Y.Offset + deltaScaled.Y
            )
        end
    end)

    local function stopDragging()
        dragging = false
        dragTouch = nil
        dragStartMousePos = nil
        dragStartWindowPos = nil
        dragMoved = false
    end

    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or (input.UserInputType == Enum.UserInputType.Touch and input == dragTouch) then
            stopDragging()
        end
    end)
    connect(UserInputService.WindowFocusReleased, stopDragging)

    -- [U] RESPONSIVE TỰ CO GIÃN THEO MÀN HÌNH (ỔN ĐỊNH LOBBY VÀ STAGE)
    local function updateScale()
        local cam = Workspace.CurrentCamera
        local size = (screen and screen.AbsoluteSize)
        if not size or size.X <= 0 or size.Y <= 0 then
            size = cam and cam.ViewportSize
        end
        if not size or size.X <= 0 or size.Y <= 0 then return end

        local fit = math.min((size.X - 20) / 940, (size.Y - 20) / 590, 1)
        uiScale.Scale = math.clamp(fit, 0.35, 1)
    end

    connect(screen:GetPropertyChangedSignal("AbsoluteSize"), updateScale)
    local cameraConn = nil
    local function watchCamera()
        if cameraConn then
            cameraConn:Disconnect()
            cameraConn = nil
        end
        if Workspace.CurrentCamera then
            cameraConn = connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale)
        end
        updateScale()
    end
    connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), watchCamera)
    watchCamera()

    -- [V] SAO CHÉP STATE NỘI BỘ
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

    -- [W] API CÔNG KHAI CHO CÁC MODULE KHÁC
    controller = {
        scroll = scroll,
        section = section,
        stateToggle = stateToggle,
        toggleItem = toggleItem,
        sliderItem = sliderItem,
        infoItem = infoItem,
    }

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
        pcall(function()
            ContextActionService:UnbindAction(SINK_ACTION)
        end)
        ctx:Destroy()
    end

    -- Đóng UI hoàn toàn bằng nút ×
    connect(closeButton.MouseButton1Click, function()
        controller:Destroy()
    end)

    ctx.screen = screen
    return controller
end

return Menu
end)()
-- END MODULE Menu

-- BEGIN MODULE ModifierConfig
Modules.ModifierConfig = (function()
--[[
    LotusHub / modules/Modifiers/ModifierConfig.lua
    Bảng dữ liệu danh sách Modifiers (Buff, Debuff, Mechanics) của Anime Vanguards.
    Nguồn: Trích xuất trực tiếp từ raw source Auto Pick Modifiers do người dùng cung cấp.
]]
local ModifierConfig = {}

-- [1] DANH SÁCH TOÀN BỘ 45 MODIFIERS ĐƯỢC PHÂN THEO BẬC ƯU TIÊN MẶC ĐỊNH
ModifierConfig.List = {
    -- Top Buff / Kinh tế (Điểm rất cao: 90 - 100)
    { Name = "Money Surge", Priority = 100, Desc = "+40% Yen from waves and Farms" },
    { Name = "High Class", Priority = 100, Desc = "Start with 10k Yen, +40% income" },
    { Name = "Harvest", Priority = 95, Desc = "+100% event currency" },
    { Name = "Gluttony", Priority = 95, Desc = "Farms pay out a second time" },
    { Name = "Monarch", Priority = 90, Desc = "Monarch trait for one unit" },
    { Name = "Damage", Priority = 85, Desc = "Boosts unit damage" },
    { Name = "Cooldown", Priority = 85, Desc = "Lowers unit SPA" },
    { Name = "Press It", Priority = 80, Desc = "-50% active ability cooldown" },
    { Name = "Uncommon Loot", Priority = 80, Desc = "2 random uncommon buffs" },
    { Name = "Common Loot", Priority = 75, Desc = "3 random common buffs" },
    { Name = "Range", Priority = 75, Desc = "Boosts unit range" },
    { Name = "Slayer", Priority = 75, Desc = "More damage to bosses" },
    { Name = "Lifeline", Priority = 70, Desc = "+1 Life Stock every 5 waves" },
    { Name = "Tyrant Destroyer", Priority = 70, Desc = "Friezo spawns at half health" },
    { Name = "Sphere Finder", Priority = 70, Desc = "Start with 2 Spheres" },
    { Name = "New Unit", Priority = 70, Desc = "Adds a unit to your hotbar" },
    { Name = "Sloth", Priority = 65, Desc = "Enemies move 30% slower" },

    -- Cơ chế đổi độ khó / Trung bình (Điểm vừa: 30 - 60)
    { Name = "Champions", Priority = 60, Desc = "Mini-bosses, +75% event currency" },
    { Name = "Fast", Priority = 60, Desc = "More Fast cards, more currency" },
    { Name = "Strong", Priority = 55, Desc = "More Strong cards, more currency" },
    { Name = "Dodge", Priority = 50, Desc = "More Dodge cards, more currency" },
    { Name = "Fisticuffs", Priority = 50, Desc = "-40% range, +200% damage" },
    { Name = "Precise Attack", Priority = 45, Desc = "+150% damage, +100% SPA" },
    { Name = "Planning Ahead", Priority = 40, Desc = "+150% range, -50% damage" },
    { Name = "Limit Break", Priority = 40, Desc = "2x placement cap, smaller discounts" },
    { Name = "No Trait No Problem", Priority = 40, Desc = "No traits, 2x placement cap" },
    { Name = "King's Burden", Priority = 35, Desc = "Monarch for all units, -40% Yen" },
    { Name = "Warding off Evil", Priority = 35, Desc = "Resist debuffs with Cursed Objects" },
    { Name = "Tyrant Arrives", Priority = 30, Desc = "First slot only, free placements" },
    { Name = "Greed", Priority = 30, Desc = "Upgraded unit becomes greedy" },
    { Name = "Lust", Priority = 30, Desc = "Selling upgraded unit refunds full" },
    { Name = "Wrath", Priority = 30, Desc = "Hits trigger wrath damage" },

    -- Debuff bất lợi / Né nhặt (Điểm thấp: 1 - 15)
    { Name = "Pride", Priority = 15, Desc = "Only 1 unit placed at a time" },
    { Name = "Envy", Priority = 10, Desc = "Strongest unit loses 30% stats" },
    { Name = "Nightmare Boss", Priority = 10, Desc = "Story boss mechanic" },
    { Name = "Nightmare Armor", Priority = 10, Desc = "-20% damage to enemies" },
    { Name = "Nightmare Health", Priority = 10, Desc = "+100% enemy HP" },
    { Name = "Nightmare Speed", Priority = 10, Desc = "+50% enemy speed" },
    { Name = "Nightmare Weakness", Priority = 10, Desc = "-20% unit damage" },
    { Name = "Regen", Priority = 5, Desc = "Enemies regenerate health" },
    { Name = "Revitalize", Priority = 5, Desc = "Enemies heal nearby on death" },
    { Name = "Shielded", Priority = 5, Desc = "Damage shield on enemies" },
    { Name = "Immunity", Priority = 3, Desc = "Immune to Slow & Stun" },
    { Name = "Thrice", Priority = 3, Desc = "Enemies split on death" },
    { Name = "Drowsy", Priority = 2, Desc = "Your units attack slower" },
    { Name = "Exploding", Priority = 2, Desc = "Explode on death, stunning units" },
    { Name = "Quake", Priority = 1, Desc = "Periodically stuns your units" },
}

-- [2] TẠO MAP TRA CỨU ĐIỂM ƯU TIÊN MẶC ĐỊNH (KEY VIẾT THƯỜNG)
function ModifierConfig.GetDefaultPriorityMap()
    local lookup = {}
    for _, item in ipairs(ModifierConfig.List) do
        lookup[string.lower(item.Name)] = item.Priority
    end
    return lookup
end

-- [3] HÀM CHUẨN HÓA TÊN THẺ (LỌC RICHTEXT/HTML, SỐ LA MÃ & SỐ THƯỜNG)
function ModifierConfig.NormalizeCardName(rawText, priorityLookup)
    if type(rawText) ~= "string" then return "", -1 end
    -- Bỏ thẻ HTML/RichText và khoảng trắng thừa
    local text = rawText:gsub("<[^>]+>", ""):match("^%s*(.-)%s*$") or ""

    -- Tách số La Mã (I, II, III, IV, V, VI, VII, VIII, IX, X...) hoặc số thường ở cuối tên thẻ
    local baseName = text:gsub("%s+[IVXLCDM]+$", ""):gsub("%s+%d+$", "")
    baseName = baseName:match("^%s*(.-)%s*$") or baseName

    local lowerBase = string.lower(baseName)
    local score = priorityLookup and priorityLookup[lowerBase]

    return baseName, (score or -1)
end

-- [4] LẤY DANH SÁCH MODIFIER ĐÃ SẮP XẾP THEO ĐIỂM ƯU TIÊN (HỖ TRỢ TÌM KIẾM)
function ModifierConfig.GetSortedList(priorityOverrides, query)
    local results = {}
    local q = (type(query) == "string" and string.lower(query):match("^%s*(.-)%s*$")) or ""

    for _, item in ipairs(ModifierConfig.List) do
        local nameLower = string.lower(item.Name)
        local descLower = string.lower(item.Desc)

        if q == "" or nameLower:find(q, 1, true) or descLower:find(q, 1, true) then
            local currentPriority = item.Priority
            if priorityOverrides and priorityOverrides[item.Name] ~= nil then
                currentPriority = tonumber(priorityOverrides[item.Name]) or item.Priority
            end

            table.insert(results, {
                Name = item.Name,
                Priority = currentPriority,
                Desc = item.Desc,
            })
        end
    end

    table.sort(results, function(a, b)
        if a.Priority == b.Priority then
            return a.Name < b.Name
        end
        return a.Priority > b.Priority
    end)

    return results
end

-- [5] HÀM KHỞI TẠO TƯƠNG THÍCH VỚI LOADMODULE CỦA LOTUSHUB
function ModifierConfig.Init(ctx, ui)
    if ctx then
        ctx.ModifierConfig = ModifierConfig
    end
end

return ModifierConfig
end)()
-- END MODULE ModifierConfig

-- BEGIN MODULE Gameplay
Modules.Gameplay = (function()
--[[
    LotusHub / modules/Gameplay.lua — Nội dung tab Gameplay.
    Nhóm chức năng: Match, Replay, Failsafe, Boost Performance.
    (Các mục Modifiers và Restart đã được chuyển sang tab Modifiers riêng).
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
        Failsafe = false,
        BoostPerformance = false,
    }
    for key, value in pairs(defaultExpanded) do
        if ctx.expanded[key] == nil then ctx.expanded[key] = value end
    end

    -- [3] Dùng các hàm vẽ của Menu, không lặp lại GUI code tại đây.
    local scroll = ui.scroll
    local section = ui.section
    local stateToggle = ui.stateToggle
    local sliderItem = ui.sliderItem
    local infoItem = ui.infoItem

    -- [4] Hàm dựng nội dung tab Gameplay.
    local function buildGameplay()
        -- Nhóm MATCH: Auto Startgame và Auto Active Auto Play là hai toggle riêng.
        local match = section(scroll, "Match", "Match", true)
        stateToggle(match, "Auto Startgame", "AutoStartgame")
        stateToggle(match, "Auto Active Auto Play", "AutoActiveAutoPlay")

        -- Nhóm REPLAY: giữ Auto Replay và tùy chọn về Lobby sau N lần.
        local replay = section(scroll, "Replay", "Replay", true)
        stateToggle(replay, "Auto Replay", "AutoReplay")
        stateToggle(replay, "Teleport to lobby after N replays", "ReplayLimitEnabled")
        sliderItem(replay, "Replay count (N)", state, "ReplayLimit", 1, 100, "")

        -- [REPLAY STATUS] Hiển thị đếm + nút Reset
        local progressRow = infoItem(replay, "Đã Replay: 0 / " .. tostring(state.ReplayLimit))
        local progressText = progressRow:FindFirstChildWhichIsA("TextLabel")
        if progressText then
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
        reset.AutoButtonColor = false -- Tắt hiệu ứng di chuyển/nhún khi nhấn
        reset.Active = true
        reset.Selectable = false
        reset.Parent = progressRow
        local resetCorner = Instance.new("UICorner")
        resetCorner.CornerRadius = UDim.new(0, 6)
        resetCorner.Parent = reset
        reset.Activated:Connect(function()
            if type(ui.ResetReplayCount) == "function" then
                ui:ResetReplayCount()
            end
        end)

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

        -- Nhóm FAILSAFE: số phút đặt ở slider chỉ được ghi vào state.FailsafeMinutes.
        local failsafe = section(scroll, "Failsafe", "Failsafe", false)
        stateToggle(failsafe, "Auto Teleport to Lobby After Minutes", "FailsafeTeleportEnabled")
        sliderItem(failsafe, "Minutes", state, "FailsafeMinutes", 1, 120, "m")

        -- Nhóm BOOST PERFORMANCE: tối ưu FPS và đồ họa.
        local boost = section(scroll, "BoostPerformance", "Boost Performance", false)
        stateToggle(boost, "FreeFire Graphics (Boost FPS)", "FreeFireGraphics")
        stateToggle(boost, "Delete Map", "DeleteMap")
        stateToggle(boost, "Delete Entities", "DeleteEntities")
        infoItem(boost, "FreeFire Graphics: Tối ưu FPS, tắt đổ bóng & hiệu ứng.")
    end

    -- [5] API tương thích ngược cho SetModifiers
    function ui:SetModifiers(names)
        -- No-op: tab Modifiers đã quản lý danh sách Modifiers
    end

    -- [6] Đăng ký tab Gameplay với Menu chính.
    ui:RegisterTab("Gameplay", function()
        buildGameplay()
    end)
end

return Gameplay
end)()
-- END MODULE Gameplay

-- BEGIN MODULE Modifiers
Modules.Modifiers = (function()
--[[
    LotusHub / modules/Modifiers.lua — Tab Modifiers (cùng cấp với Gameplay trên menu sidebar).
    Bao gồm các nhóm chức năng:
      1. Auto Pick Modifiers: Tự động nhặt thẻ theo độ ưu tiên (lọc số La Mã, hỗ trợ Starter & Additive).
      2. Restart (con của Modifiers):
         - Auto Restart After Waves: Slider chọn số wave để restart trận.
         - Auto Restart If Don't Have Modifier: Bảng chọn Modifier để chọn modifier cần có.
]]
local Modifiers = {}

function Modifiers.Init(ctx, ui)
    -- [1] State mặc định của tab Modifiers
    local defaults = {
        AutoPickModifiers = false,
        ModifierPriority = {},
        RestartAfterWavesEnabled = false,
        RestartAfterWaves = 10,
        RestartIfMissingModifier = false,
        SelectedModifiers = {},
    }
    local state = ctx.state
    for key, value in pairs(defaults) do
        if state[key] == nil then state[key] = value end
    end

    -- [2] Trạng thái nhóm gập/mở mặc định trong tab Modifiers
    local defaultExpanded = {
        AutoPick = true,
        Restart = true,
    }
    for key, value in pairs(defaultExpanded) do
        if ctx.expanded[key] == nil then ctx.expanded[key] = value end
    end

    -- [3] Nạp cấu hình ModifierConfig nếu chưa có
    local ModifierConfig = ctx.ModifierConfig
    if not ModifierConfig then
        pcall(function()
            local chunk = loadstring(readfile("LotusHub/modules/Modifiers/ModifierConfig.lua"))
            if chunk then ModifierConfig = chunk() end
        end)
        if ModifierConfig then ctx.ModifierConfig = ModifierConfig end
    end

    local C = {
        row = Color3.fromRGB(56, 58, 63),
        subRow = Color3.fromRGB(42, 44, 49),
        active = Color3.fromRGB(105, 111, 117),
        silver = Color3.fromRGB(225, 228, 232),
        muted = Color3.fromRGB(165, 171, 179),
        track = Color3.fromRGB(17, 19, 23),
        on = Color3.fromRGB(94, 116, 120),
        border = Color3.fromRGB(80, 85, 95),
        accent = Color3.fromRGB(55, 95, 150),
    }

    local scroll = ui.scroll
    local section = ui.section
    local stateToggle = ui.stateToggle
    local sliderItem = ui.sliderItem
    local infoItem = ui.infoItem

    -- [4] Hàm dựng nội dung tab Modifiers
    local function buildModifiers()
        -- ====================================================================
        -- 1. NHÓM AUTO PICK MODIFIERS
        -- ====================================================================
        local pickSection = section(scroll, "Auto Pick Modifiers", "AutoPick", true)
        stateToggle(pickSection, "Auto Pick Modifiers", "AutoPickModifiers")

        local modTableContainer = Instance.new("Frame")
        modTableContainer.Name = "ModifierTableContainer"
        modTableContainer.LayoutOrder = #pickSection:GetChildren()
        modTableContainer.Size = UDim2.new(1, 0, 0, 260)
        modTableContainer.BackgroundColor3 = C.row
        modTableContainer.BackgroundTransparency = 0.26
        modTableContainer.BorderSizePixel = 0
        modTableContainer.Active = true
        modTableContainer.Parent = pickSection
        local mtcCorner = Instance.new("UICorner")
        mtcCorner.CornerRadius = UDim.new(0, 8)
        mtcCorner.Parent = modTableContainer

        local modTableHeader = Instance.new("TextLabel")
        modTableHeader.Size = UDim2.new(1, -24, 0, 26)
        modTableHeader.Position = UDim2.fromOffset(12, 6)
        modTableHeader.BackgroundTransparency = 1
        modTableHeader.Text = "Độ ưu tiên chọn Modifier (Priority):"
        modTableHeader.Font = Enum.Font.GothamSemibold
        modTableHeader.TextSize = 14
        modTableHeader.TextColor3 = C.silver
        modTableHeader.TextXAlignment = Enum.TextXAlignment.Left
        modTableHeader.Parent = modTableContainer

        -- Ô tìm kiếm cho Modifiers
        local modSearchBox = Instance.new("TextBox")
        modSearchBox.Size = UDim2.new(1, -24, 0, 30)
        modSearchBox.Position = UDim2.fromOffset(12, 34)
        modSearchBox.BackgroundColor3 = C.track
        modSearchBox.BorderSizePixel = 0
        modSearchBox.PlaceholderText = "🔍 Tìm modifier..."
        modSearchBox.PlaceholderColor3 = C.muted
        modSearchBox.Text = ""
        modSearchBox.TextColor3 = C.silver
        modSearchBox.Font = Enum.Font.Gotham
        modSearchBox.TextSize = 13
        modSearchBox.ClearTextOnFocus = false
        modSearchBox.Parent = modTableContainer
        local msbCorner = Instance.new("UICorner")
        msbCorner.CornerRadius = UDim.new(0, 6)
        msbCorner.Parent = modSearchBox
        local msbPad = Instance.new("UIPadding")
        msbPad.PaddingLeft = UDim.new(0, 10)
        msbPad.Parent = modSearchBox

        local modScroll = Instance.new("ScrollingFrame")
        modScroll.Size = UDim2.new(1, -24, 1, -74)
        modScroll.Position = UDim2.fromOffset(12, 68)
        modScroll.BackgroundTransparency = 1
        modScroll.BorderSizePixel = 0
        modScroll.ScrollBarThickness = 4
        modScroll.ScrollBarImageColor3 = C.muted
        modScroll.ScrollingDirection = Enum.ScrollingDirection.Y
        modScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        modScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        modScroll.Parent = modTableContainer
        local mslLayout = Instance.new("UIListLayout")
        mslLayout.SortOrder = Enum.SortOrder.LayoutOrder
        mslLayout.Padding = UDim.new(0, 5)
        mslLayout.Parent = modScroll

        local modItems = {}
        local function renderModifierPriorityList()
            for _, child in ipairs(modItems) do
                child:Destroy()
            end
            table.clear(modItems)

            local sortedList = {}
            if ModifierConfig and type(ModifierConfig.GetSortedList) == "function" then
                sortedList = ModifierConfig.GetSortedList(state.ModifierPriority, modSearchBox.Text)
            else
                local baseList = (ModifierConfig and ModifierConfig.List) or {}
                for _, item in ipairs(baseList) do
                    local p = state.ModifierPriority[item.Name] or item.Priority
                    table.insert(sortedList, { Name = item.Name, Priority = p, Desc = item.Desc })
                end
            end

            for _, mod in ipairs(sortedList) do
                local itemFrame = Instance.new("Frame")
                itemFrame.Size = UDim2.new(1, -6, 0, 44)
                itemFrame.BackgroundColor3 = C.subRow
                itemFrame.BorderSizePixel = 0
                itemFrame.Parent = modScroll
                local ifCorner = Instance.new("UICorner")
                ifCorner.CornerRadius = UDim.new(0, 6)
                ifCorner.Parent = itemFrame

                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(1, -170, 0, 20)
                nameLabel.Position = UDim2.fromOffset(10, 3)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = mod.Name
                nameLabel.TextColor3 = C.silver
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.TextSize = 13
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.Parent = itemFrame

                local descLabel = Instance.new("TextLabel")
                descLabel.Size = UDim2.new(1, -170, 0, 16)
                descLabel.Position = UDim2.fromOffset(10, 23)
                descLabel.BackgroundTransparency = 1
                descLabel.Text = mod.Desc or ""
                descLabel.TextColor3 = C.muted
                descLabel.Font = Enum.Font.Gotham
                descLabel.TextSize = 10
                descLabel.TextTruncate = Enum.TextTruncate.AtEnd
                descLabel.TextXAlignment = Enum.TextXAlignment.Left
                descLabel.Parent = itemFrame

                -- Nút TOP: đưa lên ưu tiên cao nhất
                local topBtn = Instance.new("TextButton")
                topBtn.Size = UDim2.fromOffset(36, 26)
                topBtn.Position = UDim2.new(1, -156, 0.5, -13)
                topBtn.BackgroundColor3 = C.accent
                topBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                topBtn.Font = Enum.Font.GothamBold
                topBtn.TextSize = 10
                topBtn.Text = "TOP"
                topBtn.AutoButtonColor = false
                topBtn.Active = true
                topBtn.Parent = itemFrame
                local tbCorner = Instance.new("UICorner")
                tbCorner.CornerRadius = UDim.new(0, 4)
                tbCorner.Parent = topBtn

                topBtn.Activated:Connect(function()
                    local highest = 100
                    for _, m in ipairs(sortedList) do
                        if m.Priority > highest then highest = m.Priority end
                    end
                    state.ModifierPriority[mod.Name] = highest + 5
                    task.defer(renderModifierPriorityList)
                end)

                -- Hộp nhập Priority trực tiếp
                local prioBox = Instance.new("TextBox")
                prioBox.Size = UDim2.fromOffset(46, 26)
                prioBox.Position = UDim2.new(1, -114, 0.5, -13)
                prioBox.BackgroundColor3 = C.track
                prioBox.TextColor3 = Color3.fromRGB(255, 220, 100)
                prioBox.Font = Enum.Font.GothamBold
                prioBox.TextSize = 12
                prioBox.Text = tostring(mod.Priority)
                prioBox.ClearTextOnFocus = false
                prioBox.Parent = itemFrame
                local pbCorner = Instance.new("UICorner")
                pbCorner.CornerRadius = UDim.new(0, 4)
                pbCorner.Parent = prioBox

                prioBox.FocusLost:Connect(function()
                    local num = tonumber(prioBox.Text)
                    if num and num >= 0 and num <= 99999 then
                        state.ModifierPriority[mod.Name] = math.floor(num)
                        task.defer(renderModifierPriorityList)
                    else
                        prioBox.Text = tostring(mod.Priority)
                    end
                end)

                -- Nút tăng ưu tiên ▲ (+5)
                local upBtn = Instance.new("TextButton")
                upBtn.Size = UDim2.fromOffset(26, 12)
                upBtn.Position = UDim2.new(1, -62, 0.5, -13)
                upBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 60)
                upBtn.TextColor3 = C.silver
                upBtn.Font = Enum.Font.GothamBold
                upBtn.TextSize = 9
                upBtn.Text = "▲"
                upBtn.AutoButtonColor = false
                upBtn.Active = true
                upBtn.Parent = itemFrame
                local ubCorner = Instance.new("UICorner")
                ubCorner.CornerRadius = UDim.new(0, 3)
                ubCorner.Parent = upBtn

                upBtn.Activated:Connect(function()
                    state.ModifierPriority[mod.Name] = (mod.Priority or 50) + 5
                    task.defer(renderModifierPriorityList)
                end)

                -- Nút giảm ưu tiên ▼ (-5)
                local downBtn = Instance.new("TextButton")
                downBtn.Size = UDim2.fromOffset(26, 12)
                downBtn.Position = UDim2.new(1, -62, 0.5, 1)
                downBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 60)
                downBtn.TextColor3 = C.silver
                downBtn.Font = Enum.Font.GothamBold
                downBtn.TextSize = 9
                downBtn.Text = "▼"
                downBtn.AutoButtonColor = false
                downBtn.Active = true
                downBtn.Parent = itemFrame
                local dbCorner = Instance.new("UICorner")
                dbCorner.CornerRadius = UDim.new(0, 3)
                dbCorner.Parent = downBtn

                downBtn.Activated:Connect(function()
                    local current = mod.Priority or 50
                    state.ModifierPriority[mod.Name] = math.max(0, current - 5)
                    task.defer(renderModifierPriorityList)
                end)

                table.insert(modItems, itemFrame)
            end
        end

        modSearchBox:GetPropertyChangedSignal("Text"):Connect(renderModifierPriorityList)
        renderModifierPriorityList()

        -- ====================================================================
        -- 2. NHÓM RESTART (CON CỦA MODIFIERS)
        -- ====================================================================
        local restartSection = section(scroll, "Restart", "Restart", true)
        stateToggle(restartSection, "Auto Restart After Waves", "RestartAfterWavesEnabled")
        sliderItem(restartSection, "Restart at wave", state, "RestartAfterWaves", 1, 200, "")
        stateToggle(restartSection, "Auto Restart If Don't Have Modifier", "RestartIfMissingModifier")

        -- [BẢNG MODIFIER ĐỂ CHỌN MODIFIER YÊU CẦU]
        local restartTableContainer = Instance.new("Frame")
        restartTableContainer.Name = "RestartModifierTableContainer"
        restartTableContainer.LayoutOrder = #restartSection:GetChildren()
        restartTableContainer.Size = UDim2.new(1, 0, 0, 220)
        restartTableContainer.BackgroundColor3 = C.row
        restartTableContainer.BackgroundTransparency = 0.26
        restartTableContainer.BorderSizePixel = 0
        restartTableContainer.Active = true
        restartTableContainer.Parent = restartSection
        local rtcCorner = Instance.new("UICorner")
        rtcCorner.CornerRadius = UDim.new(0, 8)
        rtcCorner.Parent = restartTableContainer

        -- Tiêu đề bảng
        local restartTableHeader = Instance.new("TextLabel")
        restartTableHeader.Size = UDim2.new(1, -24, 0, 26)
        restartTableHeader.Position = UDim2.fromOffset(12, 6)
        restartTableHeader.BackgroundTransparency = 1
        restartTableHeader.Text = "Bảng chọn Modifier cần có (Required Modifiers):"
        restartTableHeader.Font = Enum.Font.GothamSemibold
        restartTableHeader.TextSize = 14
        restartTableHeader.TextColor3 = C.silver
        restartTableHeader.TextXAlignment = Enum.TextXAlignment.Left
        restartTableHeader.Parent = restartTableContainer

        -- Ô tìm kiếm trong bảng Restart
        local restartSearchBox = Instance.new("TextBox")
        restartSearchBox.Size = UDim2.new(1, -24, 0, 30)
        restartSearchBox.Position = UDim2.fromOffset(12, 34)
        restartSearchBox.BackgroundColor3 = C.track
        restartSearchBox.BorderSizePixel = 0
        restartSearchBox.PlaceholderText = "🔍 Tìm modifier..."
        restartSearchBox.PlaceholderColor3 = C.muted
        restartSearchBox.Text = ""
        restartSearchBox.TextColor3 = C.silver
        restartSearchBox.Font = Enum.Font.Gotham
        restartSearchBox.TextSize = 13
        restartSearchBox.ClearTextOnFocus = false
        restartSearchBox.Parent = restartTableContainer
        local rsbCorner = Instance.new("UICorner")
        rsbCorner.CornerRadius = UDim.new(0, 6)
        rsbCorner.Parent = restartSearchBox
        local rsbPad = Instance.new("UIPadding")
        rsbPad.PaddingLeft = UDim.new(0, 10)
        rsbPad.Parent = restartSearchBox

        -- Khung cuộn danh sách chọn Modifier
        local restartScroll = Instance.new("ScrollingFrame")
        restartScroll.Size = UDim2.new(1, -24, 1, -74)
        restartScroll.Position = UDim2.fromOffset(12, 68)
        restartScroll.BackgroundTransparency = 1
        restartScroll.BorderSizePixel = 0
        restartScroll.ScrollBarThickness = 4
        restartScroll.ScrollBarImageColor3 = C.muted
        restartScroll.ScrollingDirection = Enum.ScrollingDirection.Y
        restartScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        restartScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        restartScroll.Parent = restartTableContainer
        local rslLayout = Instance.new("UIListLayout")
        rslLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rslLayout.Padding = UDim.new(0, 4)
        rslLayout.Parent = restartScroll

        local restartItems = {}
        local function renderRestartModifierList()
            for _, child in ipairs(restartItems) do
                child:Destroy()
            end
            table.clear(restartItems)

            local list = (ModifierConfig and ModifierConfig.List) or {}
            local query = string.lower(restartSearchBox.Text):match("^%s*(.-)%s*$") or ""

            for _, mod in ipairs(list) do
                local nameLower = string.lower(mod.Name)
                local descLower = string.lower(mod.Desc or "")

                if query == "" or nameLower:find(query, 1, true) or descLower:find(query, 1, true) then
                    local itemRow = Instance.new("Frame")
                    itemRow.Size = UDim2.new(1, -6, 0, 36)
                    itemRow.BackgroundColor3 = C.subRow
                    itemRow.BorderSizePixel = 0
                    itemRow.Parent = restartScroll
                    local irCorner = Instance.new("UICorner")
                    irCorner.CornerRadius = UDim.new(0, 6)
                    irCorner.Parent = itemRow

                    local modNameLabel = Instance.new("TextLabel")
                    modNameLabel.Size = UDim2.new(1, -90, 1, 0)
                    modNameLabel.Position = UDim2.fromOffset(10, 0)
                    modNameLabel.BackgroundTransparency = 1
                    modNameLabel.Text = mod.Name
                    modNameLabel.TextColor3 = C.silver
                    modNameLabel.Font = Enum.Font.GothamSemibold
                    modNameLabel.TextSize = 13
                    modNameLabel.TextXAlignment = Enum.TextXAlignment.Left
                    modNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
                    modNameLabel.Parent = itemRow

                    local checkBtn = Instance.new("TextButton")
                    checkBtn.Size = UDim2.fromOffset(68, 24)
                    checkBtn.Position = UDim2.new(1, -76, 0.5, -12)
                    checkBtn.BorderSizePixel = 0
                    checkBtn.Font = Enum.Font.GothamBold
                    checkBtn.TextSize = 11
                    checkBtn.AutoButtonColor = false -- Không hover/click animation
                    checkBtn.Active = true
                    checkBtn.Parent = itemRow
                    local cbCorner = Instance.new("UICorner")
                    cbCorner.CornerRadius = UDim.new(0, 4)
                    cbCorner.Parent = checkBtn

                    local function updateCheckVisual()
                        local isSelected = (state.SelectedModifiers[mod.Name] == true)
                        checkBtn.BackgroundColor3 = isSelected and C.on or Color3.fromRGB(50, 52, 60)
                        checkBtn.TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or C.muted
                        checkBtn.Text = isSelected and "CHỌN ✓" or "BỎ QUA"
                    end
                    updateCheckVisual()

                    checkBtn.Activated:Connect(function()
                        state.SelectedModifiers[mod.Name] = not state.SelectedModifiers[mod.Name]
                        updateCheckVisual()
                    end)

                    table.insert(restartItems, itemRow)
                end
            end
        end

        restartSearchBox:GetPropertyChangedSignal("Text"):Connect(renderRestartModifierList)
        renderRestartModifierList()
    end

    -- [5] Đăng ký tab Modifiers với Menu chính
    ui:RegisterTab("Modifiers", function()
        buildModifiers()
    end)
end

return Modifiers
end)()
-- END MODULE Modifiers

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

-- BEGIN MODULE BoostPerformance
Modules.BoostPerformance = (function()
--[[
    LOTUSHUB / modules/Gameplay/BoostPerformance.lua
    ================================================
    Module tối ưu hóa hiệu năng và tốc độ khung hình (Boost FPS).
    
    CHỨC NĂNG A: FreeFire Graphics (Boost FPS)
      Khi ON:
        1) Tắt GlobalShadows trong Lighting.
        2) Vô hiệu hóa Bloom, Blur, DepthOfField, SunRays, ColorCorrection và các PostEffect.
        3) Tắt/giảm các hiệu ứng hạt ParticleEmitter, Trail, Beam, Fire, Smoke, Sparkles.
        4) Giảm chi tiết hiển thị: tắt CastShadow trên BasePart, chuyển Material sang SmoothPlastic,
           ẩn Decal/Texture nặng, tắt Terrain Decoration (cỏ 3D) và giảm sóng nước Terrain.
        5) Lắng nghe Workspace.DescendantAdded để tự động tối ưu quái vật và kỹ năng mới sinh ra trong trận.
      Khi OFF:
        Khôi phục toàn bộ các thuộc tính và trạng thái gốc đã lưu trước khi bật.
]]
local BoostPerformance = {}

function BoostPerformance.Init(ctx, ui)
    local state = ctx.state
    local playerGui = ctx.playerGui
    local Lighting = game:GetService("Lighting")
    local Workspace = game:GetService("Workspace")
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

    local session = {
        active = false,
        listenerConnection = nil,
    }

    -- Bảng lưu trữ trạng thái gốc để khôi phục khi OFF
    local savedState = {
        lighting = {},
        terrain = {},
        postEffects = {},     -- [instance] = originalEnabled
        emitters = {},        -- [instance] = originalEnabled
        trails = {},          -- [instance] = originalEnabled
        beams = {},           -- [instance] = originalEnabled
        miscEffects = {},     -- [instance] = originalEnabled (Fire, Smoke, Sparkles)
        castShadows = {},     -- [part] = originalCastShadow
        materials = {},       -- [part] = originalMaterial
        decals = {},          -- [decal] = originalTransparency
    }

    local function log(message)
        print("[LotusHub BoostPerformance] " .. message)
    end

    -- [1] TỐI ƯU HÓA POST-EFFECT TRONG LIGHTING VÀ CAMERA
    local function optimizePostEffect(obj)
        if not obj then return end
        if obj:IsA("PostEffect") or obj:IsA("BloomEffect") or obj:IsA("BlurEffect")
            or obj:IsA("DepthOfFieldEffect") or obj:IsA("SunRaysEffect")
            or obj:IsA("ColorCorrectionEffect") or obj:IsA("Atmosphere") then
            if savedState.postEffects[obj] == nil then
                pcall(function()
                    savedState.postEffects[obj] = obj.Enabled
                    obj.Enabled = false
                end)
            end
        end
    end

    -- [2] TỐI ƯU HÓA TỪNG INSTANCE ĐỐI TƯỢNG TRONG WORKSPACE
    local function optimizeInstance(inst)
        if not inst or not inst.Parent then return end

        -- Bỏ qua GUI hiển thị của người chơi
        if inst:IsDescendantOf(playerGui) then return end

        -- Bỏ qua nhân vật của chính người chơi để không làm hỏng avatar
        local char = player.Character
        if char and inst:IsDescendantOf(char) then return end

        -- A. Hiệu ứng hạt và ánh sáng động
        if inst:IsA("ParticleEmitter") then
            if savedState.emitters[inst] == nil then
                savedState.emitters[inst] = inst.Enabled
                inst.Enabled = false
            end
        elseif inst:IsA("Trail") then
            if savedState.trails[inst] == nil then
                savedState.trails[inst] = inst.Enabled
                inst.Enabled = false
            end
        elseif inst:IsA("Beam") then
            if savedState.beams[inst] == nil then
                savedState.beams[inst] = inst.Enabled
                inst.Enabled = false
            end
        elseif inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
            if savedState.miscEffects[inst] == nil then
                savedState.miscEffects[inst] = inst.Enabled
                inst.Enabled = false
            end
        -- B. Giảm chi tiết hình học của vật thể
        elseif inst:IsA("BasePart") then
            if inst.CastShadow and savedState.castShadows[inst] == nil then
                savedState.castShadows[inst] = inst.CastShadow
                inst.CastShadow = false
            end
            if inst.Material ~= Enum.Material.SmoothPlastic and inst.Material ~= Enum.Material.Plastic then
                if savedState.materials[inst] == nil then
                    savedState.materials[inst] = inst.Material
                    inst.Material = Enum.Material.SmoothPlastic
                end
            end
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            if inst.Transparency < 1 and savedState.decals[inst] == nil then
                savedState.decals[inst] = inst.Transparency
                inst.Transparency = 1
            end
        end
    end

    -- [3] HÀM KÍCH HOẠT FREEFIRE GRAPHICS
    local function enableFreeFire()
        if session.active then return end
        session.active = true
        log("Đang áp dụng FreeFire Graphics (Boost FPS)...")

        -- 1. Lighting: Tắt GlobalShadows
        pcall(function()
            if savedState.lighting.GlobalShadows == nil then
                savedState.lighting.GlobalShadows = Lighting.GlobalShadows
                Lighting.GlobalShadows = false
            end
        end)

        -- 2. Lighting & Camera: Tắt Post-processing
        for _, child in ipairs(Lighting:GetChildren()) do
            optimizePostEffect(child)
        end
        local camera = Workspace.CurrentCamera
        if camera then
            for _, child in ipairs(camera:GetChildren()) do
                optimizePostEffect(child)
            end
        end

        -- 3. Terrain: Tắt cỏ 3D và sóng nước
        pcall(function()
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                if savedState.terrain.Decoration == nil then
                    savedState.terrain.Decoration = terrain.Decoration
                    terrain.Decoration = false
                end
                if savedState.terrain.WaterWaveSize == nil then
                    savedState.terrain.WaterWaveSize = terrain.WaterWaveSize
                    terrain.WaterWaveSize = 0
                end
                if savedState.terrain.WaterWaveSpeed == nil then
                    savedState.terrain.WaterWaveSpeed = terrain.WaterWaveSpeed
                    terrain.WaterWaveSpeed = 0
                end
                if savedState.terrain.WaterReflectance == nil then
                    savedState.terrain.WaterReflectance = terrain.WaterReflectance
                    terrain.WaterReflectance = 0
                end
            end
        end)

        -- 4. Quét toàn bộ Workspace hiện có theo từng đợt để không giật lag
        task.spawn(function()
            local descendants = Workspace:GetDescendants()
            for i, inst in ipairs(descendants) do
                if not session.active or not ctx.alive then break end
                pcall(optimizeInstance, inst)
                if i % 1000 == 0 then
                    task.wait()
                end
            end
            log("Đã áp dụng tối ưu toàn bộ Workspace.")
        end)

        -- 5. Lắng nghe DescendantAdded để tự động xử lý kỹ năng/quái vật mới
        if not session.listenerConnection then
            session.listenerConnection = Workspace.DescendantAdded:Connect(function(inst)
                if not session.active or not ctx.alive then return end
                pcall(optimizeInstance, inst)
            end)
            table.insert(ctx.connections, session.listenerConnection)
        end

        log("FreeFire Graphics: ĐÃ BẬT.")
    end

    -- [4] HÀM KHÔI PHỤC ĐỒ HỌA GỐC
    local function disableFreeFire()
        if not session.active then return end
        session.active = false
        log("Đang khôi phục đồ họa và hiệu ứng gốc...")

        -- 1. Ngắt kết nối lắng nghe
        if session.listenerConnection then
            pcall(function() session.listenerConnection:Disconnect() end)
            session.listenerConnection = nil
        end

        -- 2. Khôi phục Lighting
        pcall(function()
            if savedState.lighting.GlobalShadows ~= nil then
                Lighting.GlobalShadows = savedState.lighting.GlobalShadows
            end
        end)
        savedState.lighting = {}

        -- 3. Khôi phục PostEffects
        for obj, origEnabled in pairs(savedState.postEffects) do
            pcall(function()
                if obj and obj.Parent then
                    obj.Enabled = origEnabled
                end
            end)
        end
        savedState.postEffects = {}

        -- 4. Khôi phục Terrain
        pcall(function()
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                if savedState.terrain.Decoration ~= nil then
                    terrain.Decoration = savedState.terrain.Decoration
                end
                if savedState.terrain.WaterWaveSize ~= nil then
                    terrain.WaterWaveSize = savedState.terrain.WaterWaveSize
                end
                if savedState.terrain.WaterWaveSpeed ~= nil then
                    terrain.WaterWaveSpeed = savedState.terrain.WaterWaveSpeed
                end
                if savedState.terrain.WaterReflectance ~= nil then
                    terrain.WaterReflectance = savedState.terrain.WaterReflectance
                end
            end
        end)
        savedState.terrain = {}

        -- 5. Khôi phục ParticleEmitter, Trail, Beam, Fire, v.v.
        for obj, origEnabled in pairs(savedState.emitters) do
            pcall(function()
                if obj and obj.Parent then
                    obj.Enabled = origEnabled
                end
            end)
        end
        savedState.emitters = {}

        for obj, origEnabled in pairs(savedState.trails) do
            pcall(function()
                if obj and obj.Parent then
                    obj.Enabled = origEnabled
                end
            end)
        end
        savedState.trails = {}

        for obj, origEnabled in pairs(savedState.beams) do
            pcall(function()
                if obj and obj.Parent then
                    obj.Enabled = origEnabled
                end
            end)
        end
        savedState.beams = {}

        for obj, origEnabled in pairs(savedState.miscEffects) do
            pcall(function()
                if obj and obj.Parent then
                    obj.Enabled = origEnabled
                end
            end)
        end
        savedState.miscEffects = {}

        -- 6. Khôi phục BasePart (CastShadow & Material)
        for part, origShadow in pairs(savedState.castShadows) do
            pcall(function()
                if part and part.Parent then
                    part.CastShadow = origShadow
                end
            end)
        end
        savedState.castShadows = {}

        for part, origMat in pairs(savedState.materials) do
            pcall(function()
                if part and part.Parent then
                    part.Material = origMat
                end
            end)
        end
        savedState.materials = {}

        -- 7. Khôi phục Decals / Textures
        for decal, origTrans in pairs(savedState.decals) do
            pcall(function()
                if decal and decal.Parent then
                    decal.Transparency = origTrans
                end
            end)
        end
        savedState.decals = {}

        log("FreeFire Graphics: ĐÃ TẮT và khôi phục cài đặt gốc.")
    end

    -- [5] ĐĂNG KÝ TOGGLE HANDLER VỚI MENU
    ui:SetToggleHandler("FreeFireGraphics", function(enabled)
        if enabled then
            enableFreeFire()
        else
            disableFreeFire()
        end
    end)

    -- Khởi động nếu toggle đã bật sẵn từ trước
    if state.FreeFireGraphics == true then
        task.defer(enableFreeFire)
    end
end

return BoostPerformance
end)()
-- END MODULE BoostPerformance

-- BEGIN MODULE AutoPick
Modules.AutoPick = (function()
--[[
    LotusHub / modules/Modifiers/AutoPick.lua — Tự động nhận diện và chọn Modifier (Thẻ bài).
    Tích hợp từ raw source Auto Pick Modifiers (hỗ trợ cả Starter Cards & Additive Cards,
    lọc số La Mã I, II, III... và số thường).
    
    Tuân thủ kiến trúc LotusHub:
    - Vòng lặp kiểm tra ctx.alive, ngắt tức thì khi UI bị hủy hoặc Execute lại.
    - Không tạo ScreenGui trôi nổi riêng biệt; giao diện tích hợp hoàn toàn trong LotusHub.
    - Không sử dụng Tween/Hover animation trên các nút thao tác.
]]
local AutoPick = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

function AutoPick.Init(ctx, ui)
    local player = Players.LocalPlayer
    local playerGui = ctx.playerGui or (player and player:WaitForChild("PlayerGui"))
    local state = ctx.state

    -- [1] NẠP BẢNG CẤU HÌNH MODIFIERS
    local ModifierConfig = ctx.ModifierConfig
    if not ModifierConfig then
        -- Fallback tìm trong package hoặc loadfile nếu chưa gắn vào ctx
        local ok, mod = pcall(function()
            return loadstring(readfile("LotusHub/modules/Modifiers/ModifierConfig.lua"))()
        end)
        if ok and type(mod) == "table" then
            ModifierConfig = mod
        else
            -- Tối thiểu cần có table cấu hình mặc định
            ModifierConfig = {
                GetDefaultPriorityMap = function() return {} end,
                NormalizeCardName = function(text, lookup)
                    local clean = text:gsub("<[^>]+>", ""):match("^%s*(.-)%s*$") or ""
                    local base = clean:gsub("%s+[IVXLCDM]+$", ""):gsub("%s+%d+$", ""):match("^%s*(.-)%s*$") or clean
                    local score = lookup and lookup[string.lower(base)]
                    return base, (score or -1)
                end,
                List = {}
            }
        end
        ctx.ModifierConfig = ModifierConfig
    end

    -- Khởi tạo state mặc định cho Modifiers
    if state.AutoPickModifiers == nil then
        state.AutoPickModifiers = false
    end
    if type(state.ModifierPriority) ~= "table" then
        state.ModifierPriority = {}
    end

    -- [2] TRẠNG THÁI NỘI BỘ CỦA WORKER
    local session = {
        hasVotedThisRound = false,
        lastVoteTime = 0,
        lastCardFound = "",
    }

    local function log(message)
        print("[LotusHub AutoPick] " .. message)
    end

    local function getActivePriorityMap()
        local baseMap = ModifierConfig.GetDefaultPriorityMap and ModifierConfig.GetDefaultPriorityMap() or {}
        local activeMap = {}
        for k, v in pairs(baseMap) do
            activeMap[k] = v
        end
        -- Áp dụng các mức ưu tiên người dùng tùy chỉnh
        for modName, customPrio in pairs(state.ModifierPriority) do
            local num = tonumber(customPrio)
            if num then
                activeMap[string.lower(modName)] = math.floor(num)
            end
        end
        return activeMap
    end

    -- Mô phỏng click chuột tại tọa độ màn hình
    local function simulateClickAt(x, y)
        if not VirtualInputManager then return end
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
            task.wait(0.04)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
    end

    -- [3] HÀM QUÉT VÀ BỎ PHIẾU CHỌN THẺ TỐT NHẤT
    local function attemptPickCard()
        if not ctx.alive or state.AutoPickModifiers ~= true then
            return false
        end

        local priorityLookup = getActivePriorityMap()
        local candidates = {}
        local isVotePending = false

        for _, gui in ipairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui ~= ctx.screen then
                -- Bỏ qua GUI LotusHub chính để không nhận diện nhầm chữ trên menu
                local guiName = gui.Name
                if not guiName:find("LotusHub") then
                    for _, label in ipairs(gui:GetDescendants()) do
                        if label:IsA("TextLabel") and label.Visible then
                            local text = label.Text
                            if text:find("(0/1)") then
                                isVotePending = true
                            end

                            if #text >= 3 then
                                local baseName, score = ModifierConfig.NormalizeCardName(text, priorityLookup)
                                if score >= 0 then
                                    local pos = label.AbsolutePosition
                                    local size = label.AbsoluteSize
                                    if pos.X > 10 and pos.Y > 10 and size.X > 0 and size.Y > 0 then
                                        local cardContainer = label:FindFirstAncestorWhichIsA("Frame") or label
                                        local cardCenter = cardContainer.AbsolutePosition + (cardContainer.AbsoluteSize / 2)

                                        table.insert(candidates, {
                                            Original = text,
                                            BaseName = baseName,
                                            Score = score,
                                            ClickX = cardCenter.X,
                                            ClickY = cardCenter.Y,
                                            Element = cardContainer
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if #candidates > 0 and (isVotePending or not session.hasVotedThisRound) then
            -- Khử trùng lặp thẻ
            local uniqueCandidates = {}
            local seen = {}
            for _, c in ipairs(candidates) do
                if not seen[c.Original] then
                    seen[c.Original] = true
                    table.insert(uniqueCandidates, c)
                end
            end

            -- Sắp xếp giảm dần theo điểm ưu tiên Score
            table.sort(uniqueCandidates, function(a, b)
                return a.Score > b.Score
            end)

            local chosen = uniqueCandidates[1]
            session.hasVotedThisRound = true
            session.lastVoteTime = tick()
            session.lastCardFound = chosen.BaseName

            log(string.format("Đã chọn thẻ tối ưu: '%s' (Gốc: '%s' | Ưu tiên: %d) tại (%d, %d)",
                chosen.BaseName, chosen.Original, chosen.Score, chosen.ClickX, chosen.ClickY))

            task.spawn(function()
                -- Bước 1: Thử gọi tín hiệu nút nếu có firesignal
                if type(firesignal) == "function" then
                    local btn = chosen.Element:FindFirstChildWhichIsA("GuiButton", true)
                    if btn then
                        pcall(function() firesignal(btn.MouseButton1Click) end)
                        pcall(function() firesignal(btn.Activated) end)
                    end
                end

                -- Bước 2: Mô phỏng click chuột vào tâm thẻ và nút Vote bên dưới
                simulateClickAt(chosen.ClickX, chosen.ClickY)
                task.wait(0.05)
                simulateClickAt(chosen.ClickX, chosen.ClickY + 110)
            end)

            return true
        end

        return false
    end

    -- [4] VÒNG LẶP POLLING TỰ ĐỘNG QUÉT THẺ MODIFIER
    task.spawn(function()
        while ctx.alive do
            task.wait(0.3)

            if state.AutoPickModifiers == true then
                local isCardWindowOpen = false

                for _, gui in ipairs(playerGui:GetChildren()) do
                    if gui:IsA("ScreenGui") and gui.Enabled and gui ~= ctx.screen then
                        local guiName = gui.Name
                        if not guiName:find("LotusHub") then
                            for _, label in ipairs(gui:GetDescendants()) do
                                if label:IsA("TextLabel") and label.Visible then
                                    local t = label.Text
                                    if t:find("Additive Cards")
                                        or t:find("Starter Cards")
                                        or t:find("Automatically ends")
                                        or t:find("Click to vote") then
                                        isCardWindowOpen = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                    if isCardWindowOpen then break end
                end

                if not isCardWindowOpen then
                    if session.hasVotedThisRound then
                        session.hasVotedThisRound = false
                    end
                else
                    if tick() - session.lastVoteTime > 2.2 then
                        attemptPickCard()
                    end
                end
            end
        end
        log("Worker AutoPick đã dừng an toàn do ctx.alive = false.")
    end)

    -- [5] ĐĂNG KÝ TOGGLE HANDLER VỚI UI
    if type(ui.SetToggleHandler) == "function" then
        ui:SetToggleHandler("AutoPickModifiers", function(enabled)
            log("AutoPickModifiers = " .. tostring(enabled))
            if enabled then
                session.hasVotedThisRound = false
                session.lastVoteTime = 0
                task.spawn(function()
                    task.wait(0.05)
                    attemptPickCard()
                end)
            end
        end)
    end
end

return AutoPick
end)()
-- END MODULE AutoPick

-- BEGIN MODULE RestartAfterWaves
Modules.RestartAfterWaves = (function()
--[[
    LotusHub / modules/Restart/RestartAfterWaves.lua
    Tính năng: Auto Restart After Waves (Tự động Restart trận khi đạt tới số Wave chỉ định).
    Có thanh giá trị (slider) để chọn số Wave mục tiêu (1..200).
]]
local RestartAfterWaves = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

function RestartAfterWaves.Init(ctx, ui)
    local player = Players.LocalPlayer
    local playerGui = ctx.playerGui or (player and player:WaitForChild("PlayerGui"))
    local state = ctx.state

    -- Cấu hình mặc định
    if state.RestartAfterWavesEnabled == nil then
        state.RestartAfterWavesEnabled = false
    end
    if state.RestartAfterWaves == nil then
        state.RestartAfterWaves = 10
    end

    local session = {
        lastTriggeredWave = -1,
        isRestarting = false,
        lastAttemptTime = 0,
    }

    local function log(message)
        print("[LotusHub RestartAfterWaves] " .. message)
    end

    -- Tìm hiển thị số Wave hiện tại trong trận đấu
    local function getCurrentWave()
        local hud = playerGui:FindFirstChild("HUD")
        if hud then
            local map = hud:FindFirstChild("Map")
            local waves = map and map:FindFirstChild("WavesAmount")
            if waves and waves:IsA("TextLabel") and waves.Visible then
                local num = tonumber(waves.Text:match("%d+"))
                if num then return num end
            end
        end

        -- Fallback quét tìm nhãn Wave bất kỳ trên màn hình
        for _, gui in ipairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui ~= ctx.screen then
                local guiName = gui.Name
                if not guiName:find("LotusHub") then
                    for _, label in ipairs(gui:GetDescendants()) do
                        if label:IsA("TextLabel") and label.Visible then
                            local t = label.Text
                            if t:find("Wave") or t:find("WAVE") then
                                local num = tonumber(t:match("%d+"))
                                if num then return num end
                            end
                        end
                    end
                end
            end
        end

        return nil
    end

    -- Kích hoạt hành động Restart / Chơi lại trận
    local function executeRestart()
        if session.isRestarting then return end
        session.isRestarting = true
        log("Đạt số Wave mục tiêu -> Đang thực hiện Restart...")

        task.spawn(function()
            -- Cách 1: Thử nhấn nút Retry trên giao diện kết trận nếu có
            local retryBtn = nil
            local hud = playerGui:FindFirstChild("HUD")
            local endFrame = hud and hud:FindFirstChild("EndFrame")
            if endFrame and endFrame.Visible then
                retryBtn = endFrame:FindFirstChild("Retry", true)
            end
            local endScreen = playerGui:FindFirstChild("EndScreen")
            if endScreen and endScreen.Enabled then
                local holder = endScreen:FindFirstChild("Holder")
                local buttons = holder and holder:FindFirstChild("Buttons")
                if buttons then
                    retryBtn = buttons:FindFirstChild("Retry", true) or retryBtn
                end
            end

            if retryBtn then
                local clickTarget = retryBtn:FindFirstChildWhichIsA("GuiButton", true) or (retryBtn:IsA("GuiButton") and retryBtn)
                if clickTarget then
                    if type(firesignal) == "function" then
                        pcall(function() firesignal(clickTarget.MouseButton1Click) end)
                        pcall(function() firesignal(clickTarget.Activated) end)
                    end
                    if VirtualInputManager and clickTarget.AbsoluteSize.X > 0 then
                        local center = clickTarget.AbsolutePosition + (clickTarget.AbsoluteSize / 2)
                        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
                        task.wait(0.04)
                        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
                    end
                    log("Đã click nút Retry trên GUI.")
                end
            end

            -- Cách 2: Gửi remote Retry nếu có
            local RETRY_REMOTE_NAME = "AV_GAME_ENDSCREEN_V1_BLINK_RELIABLE_REMOTE"
            local retryRemote = ReplicatedStorage:FindFirstChild(RETRY_REMOTE_NAME)
            if retryRemote and retryRemote:IsA("RemoteEvent") then
                pcall(function()
                    retryRemote:FireServer(buffer.fromstring("\003"))
                end)
                log("Đã gửi Remote Retry buffer 0x03")
            end

            -- Cách 3: Gửi remote MATCH_FLOW nếu trận chưa kết thúc để thoát về / restart
            local MATCH_FLOW_REMOTE = "AV_GAME_MATCH_FLOW_V1_BLINK_RELIABLE_REMOTE"
            local matchFlow = ReplicatedStorage:FindFirstChild(MATCH_FLOW_REMOTE)
            if matchFlow and matchFlow:IsA("RemoteEvent") then
                pcall(function()
                    matchFlow:FireServer(buffer.fromstring("\003"))
                end)
            end

            task.wait(3)
            session.isRestarting = false
        end)
    end

    -- [WORKER POLLING]
    task.spawn(function()
        while ctx.alive do
            task.wait(0.5)

            if state.RestartAfterWavesEnabled == true then
                local targetWave = math.clamp(math.floor(tonumber(state.RestartAfterWaves) or 10), 1, 200)
                local currentWave = getCurrentWave()

                if currentWave and currentWave >= targetWave then
                    if session.lastTriggeredWave ~= currentWave and (tick() - session.lastAttemptTime > 10) then
                        session.lastTriggeredWave = currentWave
                        session.lastAttemptTime = tick()
                        log(string.format("Wave hiện tại (%d) >= Mục tiêu (%d)!", currentWave, targetWave))
                        executeRestart()
                    end
                elseif currentWave and currentWave < targetWave then
                    -- Reset khi bắt đầu trận mới ở wave thấp hơn
                    session.lastTriggeredWave = -1
                end
            end
        end
        log("Worker RestartAfterWaves đã dừng an toàn.")
    end)

    if type(ui.SetToggleHandler) == "function" then
        ui:SetToggleHandler("RestartAfterWavesEnabled", function(enabled)
            log("RestartAfterWavesEnabled = " .. tostring(enabled))
        end)
    end
end

return RestartAfterWaves
end)()
-- END MODULE RestartAfterWaves

-- BEGIN MODULE RestartIfMissingModifier
Modules.RestartIfMissingModifier = (function()
--[[
    LotusHub / modules/Restart/RestartIfMissingModifier.lua
    Tính năng: Auto Restart If Don't Have Modifier.
    Hiện bảng Modifier để người dùng chọn các Modifier mong muốn (Required Modifiers).
    Nếu sau vòng chọn thẻ mà không sở hữu modifier mong muốn, tự động restart trận.
]]
local RestartIfMissingModifier = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

function RestartIfMissingModifier.Init(ctx, ui)
    local player = Players.LocalPlayer
    local playerGui = ctx.playerGui or (player and player:WaitForChild("PlayerGui"))
    local state = ctx.state

    if state.RestartIfMissingModifier == nil then
        state.RestartIfMissingModifier = false
    end
    if type(state.SelectedModifiers) ~= "table" then
        state.SelectedModifiers = {}
    end

    local session = {
        checkedThisRound = false,
        isRestarting = false,
        lastAttemptTime = 0,
        lastCardModalSeen = 0,
    }

    local function log(message)
        print("[LotusHub RestartIfMissingModifier] " .. message)
    end

    -- Đếm số modifier người dùng yêu cầu
    local function getRequiredCount()
        local count = 0
        for _, req in pairs(state.SelectedModifiers) do
            if req == true then count = count + 1 end
        end
        return count
    end

    -- Kiểm tra xem thẻ Modifier mong muốn có xuất hiện trong danh sách buff/thẻ hiện tại không
    local function hasAnyRequiredModifier()
        local requiredCount = getRequiredCount()
        if requiredCount == 0 then return true end -- Không chọn modifier nào thì xem như thỏa mãn

        -- 1. Quét PlayerGui (HUD / Buff list / Cards)
        for _, gui in ipairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui ~= ctx.screen then
                local guiName = gui.Name
                if not guiName:find("LotusHub") then
                    for _, label in ipairs(gui:GetDescendants()) do
                        if label:IsA("TextLabel") and label.Visible then
                            local t = label.Text
                            for modName, isRequired in pairs(state.SelectedModifiers) do
                                if isRequired == true and t:find(modName, 1, true) then
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end

        return false
    end

    -- Kích hoạt restart
    local function executeRestart()
        if session.isRestarting then return end
        session.isRestarting = true
        log("Không tìm thấy Modifier mong muốn -> Đang kích hoạt Restart...")

        task.spawn(function()
            -- Thử nút Retry
            local retryBtn = nil
            local hud = playerGui:FindFirstChild("HUD")
            local endFrame = hud and hud:FindFirstChild("EndFrame")
            if endFrame and endFrame.Visible then
                retryBtn = endFrame:FindFirstChild("Retry", true)
            end
            local endScreen = playerGui:FindFirstChild("EndScreen")
            if endScreen and endScreen.Enabled then
                local holder = endScreen:FindFirstChild("Holder")
                local buttons = holder and holder:FindFirstChild("Buttons")
                if buttons then
                    retryBtn = buttons:FindFirstChild("Retry", true) or retryBtn
                end
            end

            if retryBtn then
                local clickTarget = retryBtn:FindFirstChildWhichIsA("GuiButton", true) or (retryBtn:IsA("GuiButton") and retryBtn)
                if clickTarget then
                    if type(firesignal) == "function" then
                        pcall(function() firesignal(clickTarget.MouseButton1Click) end)
                        pcall(function() firesignal(clickTarget.Activated) end)
                    end
                    if VirtualInputManager and clickTarget.AbsoluteSize.X > 0 then
                        local center = clickTarget.AbsolutePosition + (clickTarget.AbsoluteSize / 2)
                        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
                        task.wait(0.04)
                        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
                    end
                end
            end

            -- Gửi remote Retry nếu có
            local RETRY_REMOTE_NAME = "AV_GAME_ENDSCREEN_V1_BLINK_RELIABLE_REMOTE"
            local retryRemote = ReplicatedStorage:FindFirstChild(RETRY_REMOTE_NAME)
            if retryRemote and retryRemote:IsA("RemoteEvent") then
                pcall(function()
                    retryRemote:FireServer(buffer.fromstring("\003"))
                end)
            end

            -- Gửi remote MATCH_FLOW nếu trong trận
            local MATCH_FLOW_REMOTE = "AV_GAME_MATCH_FLOW_V1_BLINK_RELIABLE_REMOTE"
            local matchFlow = ReplicatedStorage:FindFirstChild(MATCH_FLOW_REMOTE)
            if matchFlow and matchFlow:IsA("RemoteEvent") then
                pcall(function()
                    matchFlow:FireServer(buffer.fromstring("\003"))
                end)
            end

            task.wait(3)
            session.isRestarting = false
        end)
    end

    -- [WORKER POLLING]
    task.spawn(function()
        while ctx.alive do
            task.wait(0.5)

            if state.RestartIfMissingModifier == true and getRequiredCount() > 0 then
                -- Kiểm tra xem bảng chọn thẻ có đang mở không
                local isCardWindowOpen = false
                for _, gui in ipairs(playerGui:GetChildren()) do
                    if gui:IsA("ScreenGui") and gui.Enabled and gui ~= ctx.screen then
                        if not gui.Name:find("LotusHub") then
                            for _, label in ipairs(gui:GetDescendants()) do
                                if label:IsA("TextLabel") and label.Visible then
                                    local t = label.Text
                                    if t:find("Additive Cards") or t:find("Starter Cards") or t:find("Click to vote") then
                                        isCardWindowOpen = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                    if isCardWindowOpen then break end
                end

                if isCardWindowOpen then
                    session.lastCardModalSeen = tick()
                    session.checkedThisRound = false
                else
                    -- Sau khi bảng chọn thẻ vừa đóng được 3 giây, tiến hành kiểm tra
                    if session.lastCardModalSeen > 0 and (tick() - session.lastCardModalSeen > 3) and not session.checkedThisRound then
                        session.checkedThisRound = true
                        local hasMod = hasAnyRequiredModifier()
                        if not hasMod then
                            log("Kiểm tra sau vòng chọn thẻ: KHÔNG có Modifier mong muốn!")
                            executeRestart()
                        else
                            log("Kiểm tra sau vòng chọn thẻ: ĐÃ CÓ Modifier mong muốn.")
                        end
                    end
                end
            end
        end
        log("Worker RestartIfMissingModifier đã dừng an toàn.")
    end)

    if type(ui.SetToggleHandler) == "function" then
        ui:SetToggleHandler("RestartIfMissingModifier", function(enabled)
            log("RestartIfMissingModifier = " .. tostring(enabled))
        end)
    end
end

return RestartIfMissingModifier
end)()
-- END MODULE RestartIfMissingModifier

local env = ((type(getgenv) == "function") and getgenv()) or _G
local Players = game:GetService("Players")
local player = Players.LocalPlayer
if not player then error("[LotusHub] LocalPlayer chưa sẵn sàng") end

local Menu = Modules.Menu
local ModifierConfig = Modules.ModifierConfig
local Gameplay = Modules.Gameplay
local Modifiers = Modules.Modifiers
local Match = Modules.Match
local Replay = Modules.Replay
local BoostPerformance = Modules.BoostPerformance
local AutoPick = Modules.AutoPick
local RestartAfterWaves = Modules.RestartAfterWaves
local RestartIfMissingModifier = Modules.RestartIfMissingModifier

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
    knownModifiers = {},
    ModifierConfig = ModifierConfig,
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
    self.alive = false -- Ngăn worker Match/Replay/AutoPick thực hiện thao tác mới.
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

-- [GẮN MODULE] Lần lượt tạo UI, nạp config, đăng ký tab Gameplay & Modifiers, nối Match, Replay, Boost, AutoPick, Restart.
local ok, err = pcall(function()
    local ui = Menu.Create(ctx)
    ctx.ui = ui
    ModifierConfig.Init(ctx, ui)
    Gameplay.Init(ctx, ui)
    Modifiers.Init(ctx, ui)
    Match.Init(ctx, ui)
    Replay.Init(ctx, ui)
    BoostPerformance.Init(ctx, ui)
    AutoPick.Init(ctx, ui)
    RestartAfterWaves.Init(ctx, ui)
    RestartIfMissingModifier.Init(ctx, ui)
    env.LotusHubUI = ui -- API tương thích bản cũ.
    ui:ShowTab("Gameplay")
end)

if not ok then
    ctx:Destroy()
    error("[LotusHub] Khởi động thất bại: " .. tostring(err))
end

print("[LotusHub] Đã nạp Menu + Gameplay + Modifiers + Match V3 + Replay + Boost + AutoPick + Restart.")
