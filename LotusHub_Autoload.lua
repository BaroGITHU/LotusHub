if not game:IsLoaded() then
    game.Loaded:Wait()
end

--[[
    LOTUSHUB / run_all_standalone.lua — SCRIPT CHẠY ĐƠN FILE.
    TỰ ĐỘNG GỘP TỪ:
      - Menu (Zero-animation, static buttons)
      - Gameplay (Match, Replay, BoostPerformance)
      - Modifiers (ModifierConfig, AutoPick, RestartAfterWaves, RestartIfMissingModifier)
      - Gamemode (Grand Prix, AutoHorseRacing, AutoTrialOfTheSaint)
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
        subRow = Color3.fromRGB(40, 42, 47),
        subRowBorder = Color3.fromRGB(70, 75, 84),
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

    -- [H] CỬA SỔ CHÍNH (Áp dụng kỹ thuật Infinite Yield: DisplayOrder tối đa, syn_protect_gui & gethui)
    local targetGui = nil
    local useSynProtect = false
    if type(gethui) == "function" then
        pcall(function()
            local h = gethui()
            if h then targetGui = h end
        end)
    end
    if not targetGui then
        pcall(function()
            local cg = game:GetService("CoreGui")
            if cg then
                targetGui = cg
                if type(syn_protect_gui) == "function" or (syn and type(syn.protect_gui) == "function") then
                    useSynProtect = true
                end
            end
        end)
    end
    if not targetGui then
        targetGui = playerGui
    end

    local screen = new("ScreenGui", nil, {
        Name = "LotusHub_Gameplay_UI_Demo",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        DisplayOrder = 2147483647,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    if useSynProtect then
        local protect = (type(syn_protect_gui) == "function" and syn_protect_gui)
            or (syn and syn.protect_gui)
        pcall(protect, screen)
    end
    screen.Parent = targetGui

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
        local frame = corner(new("Frame", parent, {
            LayoutOrder = #parent:GetChildren(),
            Size = UDim2.new(1, 0, 0, height or 44),
            BackgroundColor3 = C.subRow,
            BackgroundTransparency = 0.32,
            BorderSizePixel = 0,
            Active = true,
            ClipsDescendants = false,
        }), 6)
        stroke(frame, 0.45)
        return frame
    end

    -- [M] CÔNG TẮC ON/OFF HOÀN TOÀN TĨNH (KHÔNG DÙNG TWEEN)
    -- OFF: nền C.track (tối), núm trắng nằm bên TRÁI tại (3, 3), state = false
    -- ON:  nền C.on (sáng), núm trắng nằm bên PHẢI tại (39, 3), state = true
    -- Vị trí và màu sắc cập nhật tức thời bằng gán thuộc tính trực tiếp khi click
    local function toggleItem(parent, text, readValue, saveValue)
        local row = itemFrame(parent, 44)

        local rowButton = new("TextButton", row, {
            Name = "RowClickArea",
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.fromOffset(0, 0),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Active = true,
            Selectable = false,
            ZIndex = 1,
        })

        label(row, text, {
            Position = UDim2.fromOffset(14, 0),
            Size = UDim2.new(1, -96, 1, 0),
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            TextColor3 = C.silver,
            ZIndex = 2,
        })

        local track = corner(new("TextButton", row, {
            Name = "ToggleTrack",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -14, 0.5, 0),
            Size = UDim2.fromOffset(62, 26),
            BackgroundColor3 = C.track,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            Active = true,
            Selectable = false,
            ZIndex = 3,
        }), 8)
        stroke(track, 0.33)

        local knob = corner(new("Frame", track, {
            Name = "ToggleKnob",
            Size = UDim2.fromOffset(20, 20),
            Position = UDim2.fromOffset(3, 3),
            BackgroundColor3 = C.silver,
            BorderSizePixel = 0,
            Active = false,
            ZIndex = 4,
        }), 6)

        local function redraw()
            local value = (readValue() == true)
            track.BackgroundColor3 = value and C.on or C.track
            knob.Position = value and UDim2.fromOffset(39, 3) or UDim2.fromOffset(3, 3)
            knob.BackgroundColor3 = value and C.white or C.silver
        end

        redraw()

        local function triggerToggle()
            local current = (readValue() == true)
            saveValue(not current)
            redraw()
        end

        rowButton.MouseButton1Click:Connect(triggerToggle)
        track.MouseButton1Click:Connect(triggerToggle)

        return row
    end

    local toggleHandlers = {}

    local function stateToggle(parent, text, key, onChange)
        return toggleItem(parent, text, function()
            return state[key]
        end, function(value)
            state[key] = value
            if type(onChange) == "function" then
                pcall(onChange, value)
            end
            local handler = toggleHandlers[key]
            if type(handler) == "table" then
                for _, h in ipairs(handler) do pcall(h, value) end
            elseif type(handler) == "function" then
                handler(value)
            else
                print("[LotusHub UI] " .. key .. " = " .. tostring(value) .. " (chỉ UI)")
            end
            if type(ctx.SaveConfig) == "function" then
                pcall(ctx.SaveConfig)
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

        local arrow = label(button, expanded[key] and "v" or "›", {
            Position = UDim2.new(1, -48, 0, 0),
            Size = UDim2.fromOffset(35, 48),
            TextSize = 18,
            Font = Enum.Font.GothamBold,
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
        contentsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        new("UIPadding", contents, {
            PaddingTop = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 4),
            PaddingLeft = UDim.new(0, 18),
            PaddingRight = UDim.new(0, 2),
        })

        button.MouseButton1Click:Connect(function()
            local isOpen = not (expanded[key] == true)
            expanded[key] = isOpen
            contents.Visible = isOpen
            arrow.Text = isOpen and "v" or "›"
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
                if type(ctx.SaveConfig) == "function" then
                    pcall(ctx.SaveConfig)
                end
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
        if not toggleHandlers[key] then
            toggleHandlers[key] = fn
        elseif type(toggleHandlers[key]) == "function" then
            toggleHandlers[key] = { toggleHandlers[key], fn }
        elseif type(toggleHandlers[key]) == "table" then
            table.insert(toggleHandlers[key], fn)
        end
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
        Match = false,
        Replay = false,
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
        local match = section(scroll, "Match", "Match", false)
        stateToggle(match, "Auto Startgame", "AutoStartgame")
        stateToggle(match, "Auto Active Auto Play", "AutoActiveAutoPlay")

        -- Nhóm REPLAY: giữ Auto Replay và tùy chọn về Lobby sau N lần.
        local replay = section(scroll, "Replay", "Replay", false)
        local autoRepToggle = stateToggle(replay, "Auto Replay", "AutoReplay")
        autoRepToggle.LayoutOrder = 1

        local replaySub
        local teleToggle = stateToggle(replay, "Teleport to lobby after N replays", "ReplayLimitEnabled", function(enabled)
            if replaySub then replaySub.Visible = (enabled == true) end
        end)
        teleToggle.LayoutOrder = 2

        -- Khung chứa con thụt lề cho Teleport to lobby after N replays (nằm NGAY DƯỚI Teleport to lobby)
        replaySub = Instance.new("Frame")
        replaySub.Name = "ReplayLimitSubGroup"
        replaySub.LayoutOrder = 3
        replaySub.Size = UDim2.new(1, 0, 0, 0)
        replaySub.AutomaticSize = Enum.AutomaticSize.Y
        replaySub.BackgroundTransparency = 1
        replaySub.Visible = (state.ReplayLimitEnabled == true)
        replaySub.Parent = replay
        local subLayout = Instance.new("UIListLayout")
        subLayout.SortOrder = Enum.SortOrder.LayoutOrder
        subLayout.Padding = UDim.new(0, 6)
        subLayout.Parent = replaySub
        local subPadding = Instance.new("UIPadding")
        subPadding.PaddingLeft = UDim.new(0, 18)
        subPadding.PaddingRight = UDim.new(0, 2)
        subPadding.Parent = replaySub

        sliderItem(replaySub, "Replay count (N)", state, "ReplayLimit", 1, 100, "")

        -- [REPLAY STATUS] Hiển thị đếm + nút Reset
        local progressRow = infoItem(replaySub, "Đã Replay: 0 / " .. tostring(state.ReplayLimit))
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
        AutoPick = false,
        Restart = false,
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
        local pickSection = section(scroll, "AutoPick", "AutoPick", false)

        local pickSub
        local pickToggle = stateToggle(pickSection, "Auto Pick Modifiers", "AutoPickModifiers", function(enabled)
            if pickSub then pickSub.Visible = (enabled == true) end
        end)
        pickToggle.LayoutOrder = 1

        -- Khung chứa con thụt lề cho bảng danh sách AutoPick (nằm NGAY DƯỚI Auto Pick Modifiers)
        pickSub = Instance.new("Frame")
        pickSub.Name = "AutoPickSubGroup"
        pickSub.LayoutOrder = 2
        pickSub.Size = UDim2.new(1, 0, 0, 0)
        pickSub.AutomaticSize = Enum.AutomaticSize.Y
        pickSub.BackgroundTransparency = 1
        pickSub.Visible = (state.AutoPickModifiers == true)
        pickSub.Parent = pickSection
        local psPadding = Instance.new("UIPadding")
        psPadding.PaddingLeft = UDim.new(0, 18)
        psPadding.PaddingRight = UDim.new(0, 2)
        psPadding.Parent = pickSub

        local modTableContainer = Instance.new("Frame")
        modTableContainer.Name = "ModifierTableContainer"
        modTableContainer.LayoutOrder = 1
        modTableContainer.Size = UDim2.new(1, 0, 0, 260)
        modTableContainer.BackgroundColor3 = C.subRow or Color3.fromRGB(40, 42, 47)
        modTableContainer.BackgroundTransparency = 0.32
        modTableContainer.BorderSizePixel = 0
        modTableContainer.Active = true
        modTableContainer.Parent = pickSub
        local mtcCorner = Instance.new("UICorner")
        mtcCorner.CornerRadius = UDim.new(0, 8)
        mtcCorner.Parent = modTableContainer
        local mtcStroke = Instance.new("UIStroke")
        mtcStroke.Color = Color3.fromRGB(70, 75, 84)
        mtcStroke.Transparency = 0.45
        mtcStroke.Parent = modTableContainer

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
                    if type(ctx.SaveConfig) == "function" then pcall(ctx.SaveConfig) end
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
                        if type(ctx.SaveConfig) == "function" then pcall(ctx.SaveConfig) end
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
                    if type(ctx.SaveConfig) == "function" then pcall(ctx.SaveConfig) end
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
                    if type(ctx.SaveConfig) == "function" then pcall(ctx.SaveConfig) end
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
        local restartSection = section(scroll, "Restart", "Restart", false)

        -- 1. Mục cha: Auto Restart After Waves
        local wavesSub
        local wavesToggle = stateToggle(restartSection, "Auto Restart After Waves", "RestartAfterWavesEnabled", function(enabled)
            if wavesSub then wavesSub.Visible = (enabled == true) end
        end)
        wavesToggle.LayoutOrder = 1

        -- 1.1 Khung con thụt lề nằm NGAY DƯỚI Auto Restart After Waves
        wavesSub = Instance.new("Frame")
        wavesSub.Name = "RestartWavesSubGroup"
        wavesSub.LayoutOrder = 2
        wavesSub.Size = UDim2.new(1, 0, 0, 0)
        wavesSub.AutomaticSize = Enum.AutomaticSize.Y
        wavesSub.BackgroundTransparency = 1
        wavesSub.Visible = (state.RestartAfterWavesEnabled == true)
        wavesSub.Parent = restartSection
        local wsPadding = Instance.new("UIPadding")
        wsPadding.PaddingLeft = UDim.new(0, 18)
        wsPadding.PaddingRight = UDim.new(0, 2)
        wsPadding.Parent = wavesSub

        sliderItem(wavesSub, "Restart at wave", state, "RestartAfterWaves", 1, 200, "")

        -- 2. Mục cha: Auto Restart If Don't Have Modifier
        local missingModSub
        local missingModToggle = stateToggle(restartSection, "Auto Restart If Don't Have Modifier", "RestartIfMissingModifier", function(enabled)
            if missingModSub then missingModSub.Visible = (enabled == true) end
        end)
        missingModToggle.LayoutOrder = 3

        -- 2.1 Khung con thụt lề nằm NGAY DƯỚI Auto Restart If Don't Have Modifier
        missingModSub = Instance.new("Frame")
        missingModSub.Name = "RestartMissingModSubGroup"
        missingModSub.LayoutOrder = 4
        missingModSub.Size = UDim2.new(1, 0, 0, 0)
        missingModSub.AutomaticSize = Enum.AutomaticSize.Y
        missingModSub.BackgroundTransparency = 1
        missingModSub.Visible = (state.RestartIfMissingModifier == true)
        missingModSub.Parent = restartSection
        local mmPadding = Instance.new("UIPadding")
        mmPadding.PaddingLeft = UDim.new(0, 18)
        mmPadding.PaddingRight = UDim.new(0, 2)
        mmPadding.Parent = missingModSub

        -- [BẢNG MODIFIER ĐỂ CHỌN MODIFIER YÊU CẦU]
        local restartTableContainer = Instance.new("Frame")
        restartTableContainer.Name = "RestartModifierTableContainer"
        restartTableContainer.LayoutOrder = 1
        restartTableContainer.Size = UDim2.new(1, 0, 0, 220)
        restartTableContainer.BackgroundColor3 = C.subRow or Color3.fromRGB(40, 42, 47)
        restartTableContainer.BackgroundTransparency = 0.32
        restartTableContainer.BorderSizePixel = 0
        restartTableContainer.Active = true
        restartTableContainer.Parent = missingModSub
        local rtcCorner = Instance.new("UICorner")
        rtcCorner.CornerRadius = UDim.new(0, 8)
        rtcCorner.Parent = restartTableContainer
        local rtcStroke = Instance.new("UIStroke")
        rtcStroke.Color = Color3.fromRGB(70, 75, 84)
        rtcStroke.Transparency = 0.45
        rtcStroke.Parent = restartTableContainer

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
                        if type(ctx.SaveConfig) == "function" then
                            pcall(ctx.SaveConfig)
                        end
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

-- BEGIN MODULE Gamemode
Modules.Gamemode = (function()
--[[
    LotusHub / modules/Gamemode.lua — Tab Gamemode (Các chế độ chơi đặc biệt).
    Cây thư mục tương ứng:
      modules/Gamemode/
        |-- Grand Prix/
            |-- Auto join Grand Prix
            |-- Auto Horse Racing
        |-- Trail Of The Saint/
            |-- Auto Trial Of The Saint
]]
local Gamemode = {}

function Gamemode.Init(ctx, ui)
    -- [1] State mặc định cho Gamemode
    local defaults = {
        AutoJoinGrandPrix = false,
        AutoHorseRacing = false,
        AutoTrialOfTheSaint = false,
        TrialEndings = {
            ["True ending"] = true,
            ["Secret ending"] = false,
        },
    }
    local state = ctx.state
    for key, value in pairs(defaults) do
        if state[key] == nil then state[key] = value end
    end

    -- [2] Trạng thái mở rộng nhóm mặc định
    local defaultExpanded = {
        GrandPrix = false,
        TrailOfTheSaint = false,
    }
    for key, value in pairs(defaultExpanded) do
        if ctx.expanded[key] == nil then ctx.expanded[key] = value end
    end

    -- [3] Bảng màu chuẩn LotusHub
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
    local infoItem = ui.infoItem

    -- [4] Hàm dựng nội dung tab Gamemode
    local function buildGamemode()
        -- ====================================================================
        -- 1. NHÓM GRAND PRIX
        -- ====================================================================
        local grandPrixSection = section(scroll, "GrandPrix", "Grand Prix", false)
        stateToggle(grandPrixSection, "Auto join Grand Prix", "AutoJoinGrandPrix")
        stateToggle(grandPrixSection, "Auto Horse Racing", "AutoHorseRacing")
        infoItem(grandPrixSection, "Grand Prix: Tự động xác nhận Mount Picker và đua ngựa autopilot 1000 spd.")

        -- ====================================================================
        -- 2. NHÓM TRAIL OF THE SAINT
        -- ====================================================================
        local saintSection = section(scroll, "TrailOfTheSaint", "Trail Of The Saint", false)

        local saintSub
        local saintToggle = stateToggle(saintSection, "Auto Trial Of The Saint", "AutoTrialOfTheSaint", function(enabled)
            if saintSub then saintSub.Visible = (enabled == true) end
        end)
        saintToggle.LayoutOrder = 1

        -- Khung chứa con thụt lề cho bảng chọn Ending của Trail Of The Saint (nằm NGAY DƯỚI Auto Trial Of The Saint)
        saintSub = Instance.new("Frame")
        saintSub.Name = "TrailSaintSubGroup"
        saintSub.LayoutOrder = 2
        saintSub.Size = UDim2.new(1, 0, 0, 0)
        saintSub.AutomaticSize = Enum.AutomaticSize.Y
        saintSub.BackgroundTransparency = 1
        saintSub.Visible = (state.AutoTrialOfTheSaint == true)
        saintSub.Parent = saintSection
        local ssPadding = Instance.new("UIPadding")
        ssPadding.PaddingLeft = UDim.new(0, 18)
        ssPadding.PaddingRight = UDim.new(0, 2)
        ssPadding.Parent = saintSub

        -- [BẢNG CHỌN GIỮA CÁC ENDING (Tương tự bảng Modifier)]
        local endingContainer = Instance.new("Frame")
        endingContainer.Name = "TrialEndingContainer"
        endingContainer.LayoutOrder = 1
        endingContainer.Size = UDim2.new(1, 0, 0, 140)
        endingContainer.BackgroundColor3 = C.subRow or Color3.fromRGB(40, 42, 47)
        endingContainer.BackgroundTransparency = 0.32
        endingContainer.BorderSizePixel = 0
        endingContainer.Active = true
        endingContainer.Parent = saintSub
        local ecCorner = Instance.new("UICorner")
        ecCorner.CornerRadius = UDim.new(0, 8)
        ecCorner.Parent = endingContainer
        local ecStroke = Instance.new("UIStroke")
        ecStroke.Color = Color3.fromRGB(70, 75, 84)
        ecStroke.Transparency = 0.45
        ecStroke.Parent = endingContainer

        local ecHeader = Instance.new("TextLabel")
        ecHeader.Size = UDim2.new(1, -24, 0, 26)
        ecHeader.Position = UDim2.fromOffset(12, 6)
        ecHeader.BackgroundTransparency = 1
        ecHeader.Text = "Bảng chọn Ending (Trial Of The Saint):"
        ecHeader.Font = Enum.Font.GothamSemibold
        ecHeader.TextSize = 14
        ecHeader.TextColor3 = C.silver
        ecHeader.TextXAlignment = Enum.TextXAlignment.Left
        ecHeader.Parent = endingContainer

        -- Danh sách các Ending
        local endingList = {
            { Name = "True ending", Desc = "Hoàn thành cốt truyện với True Ending" },
            { Name = "Secret ending", Desc = "Hoàn thành cốt truyện với Secret Ending" },
        }

        local endingRows = Instance.new("Frame")
        endingRows.Size = UDim2.new(1, -24, 0, 96)
        endingRows.Position = UDim2.fromOffset(12, 36)
        endingRows.BackgroundTransparency = 1
        endingRows.Parent = endingContainer
        local elLayout = Instance.new("UIListLayout")
        elLayout.SortOrder = Enum.SortOrder.LayoutOrder
        elLayout.Padding = UDim.new(0, 6)
        elLayout.Parent = endingRows

        for index, item in ipairs(endingList) do
            local itemRow = Instance.new("Frame")
            itemRow.Size = UDim2.new(1, 0, 0, 42)
            itemRow.BackgroundColor3 = C.subRow
            itemRow.BorderSizePixel = 0
            itemRow.LayoutOrder = index
            itemRow.Parent = endingRows
            local irCorner = Instance.new("UICorner")
            irCorner.CornerRadius = UDim.new(0, 6)
            irCorner.Parent = itemRow

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -95, 0, 20)
            nameLabel.Position = UDim2.fromOffset(10, 3)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = item.Name
            nameLabel.TextColor3 = C.silver
            nameLabel.Font = Enum.Font.GothamSemibold
            nameLabel.TextSize = 13
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Parent = itemRow

            local descLabel = Instance.new("TextLabel")
            descLabel.Size = UDim2.new(1, -95, 0, 16)
            descLabel.Position = UDim2.fromOffset(10, 22)
            descLabel.BackgroundTransparency = 1
            descLabel.Text = item.Desc
            descLabel.TextColor3 = C.muted
            descLabel.Font = Enum.Font.Gotham
            descLabel.TextSize = 10
            descLabel.TextXAlignment = Enum.TextXAlignment.Left
            descLabel.Parent = itemRow

            local selectBtn = Instance.new("TextButton")
            selectBtn.Size = UDim2.fromOffset(72, 26)
            selectBtn.Position = UDim2.new(1, -80, 0.5, -13)
            selectBtn.BorderSizePixel = 0
            selectBtn.Font = Enum.Font.GothamBold
            selectBtn.TextSize = 11
            selectBtn.AutoButtonColor = false -- Tắt animation giật
            selectBtn.Active = true
            selectBtn.Parent = itemRow
            local sbCorner = Instance.new("UICorner")
            sbCorner.CornerRadius = UDim.new(0, 4)
            sbCorner.Parent = selectBtn

            local function updateBtnVisual()
                local isSelected = (state.TrialEndings[item.Name] == true)
                selectBtn.BackgroundColor3 = isSelected and C.on or Color3.fromRGB(50, 52, 60)
                selectBtn.TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or C.muted
                selectBtn.Text = isSelected and "CHỌN ✓" or "BỎ QUA"
            end
            updateBtnVisual()

            selectBtn.Activated:Connect(function()
                state.TrialEndings[item.Name] = not state.TrialEndings[item.Name]
                updateBtnVisual()
                if type(ctx.SaveConfig) == "function" then
                    pcall(ctx.SaveConfig)
                end
            end)
        end
    end

    -- [5] Đăng ký tab Gamemode với Menu chính
    ui:RegisterTab("Gamemode", function()
        buildGamemode()
    end)
end

return Gamemode
end)()
-- END MODULE Gamemode

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

    -- BẢO VỆ TUYỆT ĐỐI: Mặc định luôn là false khi vào bất kỳ Stage hay Lobby nào (chống tự động bắt đầu game)
    state.AutoStartgame = false
    state.AutoActiveAutoPlay = false

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

            -- AUTO STARTGAME: CHỈ KHI NGƯỜI DÙNG THỰC SỰ BẬT (== true), KHÔNG TỰ ĐỘNG BẬT
            if state.AutoStartgame == true and not stage.started then
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

-- BEGIN MODULE AutoJoinGrandPrix
Modules.AutoJoinGrandPrix = (function()
--[[
    LotusHub / modules/Gamemode/Grand Prix/Auto join Grand Prix.lua
    Chức năng: Tự động nhận diện và xác nhận tham gia Grand Prix (Auto Confirm Mount Picker).
    Nguồn: Trích xuất từ raw Grand Prix Engine do người dùng cung cấp.
]]
local AutoJoinGrandPrix = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

function AutoJoinGrandPrix.Init(ctx, ui)
    local player = Players.LocalPlayer
    local playerGui = ctx.playerGui or (player and player:WaitForChild("PlayerGui"))
    local state = ctx.state

    if state.AutoJoinGrandPrix == nil then
        state.AutoJoinGrandPrix = false
    end

    local lastConfirmed = 0

    local function log(message)
        print("[LotusHub GrandPrix] " .. message)
    end

    -- Kiểm tra và tự động bấm nút Confirm trong GrandPrixMountPicker
    local function checkMountPicker()
        if not ctx.alive or state.AutoJoinGrandPrix ~= true then return end

        local grandPrixGui = playerGui:FindFirstChild("GrandPrix")
        if not grandPrixGui then return end

        local mountPicker = grandPrixGui:FindFirstChild("GrandPrixMountPicker", true)
        if not mountPicker then return end

        local confirmGroup = mountPicker:FindFirstChild("Confirm", true)
        local confirmBtn = nil

        if confirmGroup then
            local clickable = confirmGroup:FindFirstChild("Clickable", true)
            if clickable and clickable:IsA("TextButton") then
                confirmBtn = clickable
            end
        end

        if not confirmBtn then
            local buyGroup = mountPicker:FindFirstChild("Buy", true)
            if buyGroup then
                local clickable = buyGroup:FindFirstChild("Clickable", true)
                if clickable and clickable:IsA("TextButton") then
                    confirmBtn = clickable
                end
            end
        end

        -- Nhận diện và click khi nút xuất hiện trên màn hình
        if confirmBtn and confirmBtn.AbsoluteSize.X > 10 and confirmBtn.AbsoluteSize.Y > 10 then
            if tick() - lastConfirmed > 1.2 then
                lastConfirmed = tick()

                if type(firesignal) == "function" then
                    pcall(function() firesignal(confirmBtn.MouseButton1Down) end)
                    pcall(function() firesignal(confirmBtn.MouseButton1Click) end)
                    pcall(function() firesignal(confirmBtn.MouseButton1Up) end)
                    pcall(function() firesignal(confirmBtn.Activated) end)
                end

                if VirtualInputManager then
                    local center = confirmBtn.AbsolutePosition + (confirmBtn.AbsoluteSize / 2)
                    pcall(function()
                        VirtualInputManager:SendMouseButtonEvent(math.floor(center.X), math.floor(center.Y), 0, true, game, 0)
                        task.wait(0.04)
                        VirtualInputManager:SendMouseButtonEvent(math.floor(center.X), math.floor(center.Y), 0, false, game, 0)
                    end)
                end

                log("Đã bấm Confirm Mount Picker -> Tham gia Grand Prix thành công!")
            end
        end
    end

    -- Worker chạy ngầm kiểm tra định kỳ (chu kỳ 0.5s, ngắt sạch khi ctx.alive = false)
    task.spawn(function()
        while ctx.alive do
            task.wait(0.5)
            if state.AutoJoinGrandPrix == true then
                checkMountPicker()
            end
        end
        log("Worker AutoJoinGrandPrix đã dừng an toàn do ctx.alive = false.")
    end)

    if type(ui.SetToggleHandler) == "function" then
        ui:SetToggleHandler("AutoJoinGrandPrix", function(enabled)
            log("AutoJoinGrandPrix = " .. tostring(enabled))
            if enabled then
                lastConfirmed = 0
                task.spawn(checkMountPicker)
            end
        end)
    end
end

return AutoJoinGrandPrix
end)()
-- END MODULE AutoJoinGrandPrix

-- BEGIN MODULE AutoHorseRacing
Modules.AutoHorseRacing = (function()
--[[
    LotusHub / modules/Gamemode/Grand Prix/Auto Horse Racing.lua
    Chức năng: Tự động đua ngựa trong Grand Prix (Autopilot đa Map, NoClip, 1000 spd, Watchdog 8s).
    Nguồn: Trích xuất từ raw Grand Prix Autonomous Full-Auto Engine.
]]
local AutoHorseRacing = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

function AutoHorseRacing.Init(ctx, ui)
    local player = Players.LocalPlayer
    local state = ctx.state

    if state.AutoHorseRacing == nil then
        state.AutoHorseRacing = false
    end

    local function log(message)
        print("[LotusHub HorseRacing] " .. message)
    end

    -- ==========================================================
    -- 1. TỌA ĐỘ 3 MAP (RECORDED TRACKS)
    -- ==========================================================
    local RecordedTracks = {
        [1] = {
            Vector3.new(167.53, 702.14, -249.38), Vector3.new(168.15, 701.66, -241.69),
            Vector3.new(169.17, 701.00, -227.81), Vector3.new(169.08, 700.79, -218.50),
            Vector3.new(167.98, 700.43, -200.76), Vector3.new(165.70, 699.37, -186.41),
            Vector3.new(161.35, 697.58, -163.07), Vector3.new(158.32, 697.00, -145.84),
            Vector3.new(157.28, 697.16, -131.90), Vector3.new(157.14, 698.35, -108.45),
            Vector3.new(156.98, 700.91, -76.27),  Vector3.new(156.93, 702.58, -48.01),
            Vector3.new(156.88, 703.01, -29.68),  Vector3.new(157.78, 702.59, -15.49),
            Vector3.new(158.87, 701.78, -3.57),   Vector3.new(158.33, 700.99, 5.41),
            Vector3.new(156.44, 699.65, 19.52),   Vector3.new(152.52, 698.56, 33.11),
            Vector3.new(146.36, 697.36, 49.54),   Vector3.new(139.14, 696.07, 67.02),
            Vector3.new(132.97, 695.32, 78.35),   Vector3.new(125.29, 694.55, 89.39),
            Vector3.new(117.40, 693.73, 98.61),   Vector3.new(109.15, 692.68, 106.38),
            Vector3.new(98.73, 691.16, 112.58),   Vector3.new(86.92, 689.69, 116.51),
            Vector3.new(75.51, 689.88, 119.28),   Vector3.new(63.06, 690.54, 121.78),
            Vector3.new(51.28, 690.39, 123.89),   Vector3.new(38.05, 690.01, 124.67),
            Vector3.new(25.39, 689.23, 124.44),   Vector3.new(13.10, 687.90, 123.91),
            Vector3.new(0.55, 685.67, 123.08),    Vector3.new(-11.55, 684.21, 123.09),
            Vector3.new(-23.84, 682.94, 123.35),  Vector3.new(-36.35, 682.18, 123.84),
            Vector3.new(-49.10, 680.39, 124.31),  Vector3.new(-61.22, 678.49, 124.44),
            Vector3.new(-73.42, 677.61, 123.20),  Vector3.new(-85.33, 676.84, 121.05),
            Vector3.new(-97.55, 676.31, 117.65),  Vector3.new(-110.65, 675.79, 113.16),
            Vector3.new(-122.48, 675.43, 108.99), Vector3.new(-134.48, 675.08, 105.78),
            Vector3.new(-147.21, 673.97, 105.16), Vector3.new(-160.56, 672.66, 106.58),
            Vector3.new(-174.15, 672.35, 106.99), Vector3.new(-186.91, 673.57, 106.73),
            Vector3.new(-198.44, 675.43, 106.34), Vector3.new(-210.79, 677.54, 104.67),
            Vector3.new(-222.14, 679.46, 100.63), Vector3.new(-234.18, 681.70, 94.93),
            Vector3.new(-244.23, 683.68, 88.31),  Vector3.new(-256.47, 686.43, 79.10),
            Vector3.new(-268.81, 689.48, 66.81),  Vector3.new(-278.99, 692.32, 52.33),
            Vector3.new(-287.62, 695.07, 38.56),  Vector3.new(-293.49, 697.36, 21.27),
            Vector3.new(-294.81, 698.61, 3.77),   Vector3.new(-295.22, 699.85, -14.70),
            Vector3.new(-295.60, 701.06, -33.93), Vector3.new(-295.48, 701.90, -48.08),
            Vector3.new(-294.19, 702.46, -60.98), Vector3.new(-292.80, 700.69, -74.13),
            Vector3.new(-291.46, 696.54, -88.58), Vector3.new(-290.33, 692.11, -100.23),
            Vector3.new(-289.01, 687.36, -113.62), Vector3.new(-287.49, 687.64, -127.83),
            Vector3.new(-285.74, 690.57, -143.06), Vector3.new(-283.88, 689.85, -157.05),
            Vector3.new(-281.86, 685.87, -170.71), Vector3.new(-279.76, 678.57, -183.97),
            Vector3.new(-276.81, 674.93, -196.78), Vector3.new(-271.96, 673.68, -209.52),
            Vector3.new(-265.00, 672.35, -225.96), Vector3.new(-258.55, 671.47, -241.07),
            Vector3.new(-251.92, 671.02, -259.52), Vector3.new(-247.01, 671.01, -282.88),
            Vector3.new(-243.63, 671.01, -300.22), Vector3.new(-239.08, 671.01, -317.10),
            Vector3.new(-233.69, 671.01, -334.98), Vector3.new(-227.92, 671.12, -354.35),
            Vector3.new(-223.59, 671.23, -375.62), Vector3.new(-219.38, 671.72, -391.17),
            Vector3.new(-216.38, 673.73, -408.12), Vector3.new(-213.19, 677.31, -427.79),
            Vector3.new(-209.85, 680.90, -448.49), Vector3.new(-206.59, 682.50, -468.67),
            Vector3.new(-198.85, 682.50, -469.97), Vector3.new(-200.28, 682.49, -480.88),
            Vector3.new(-199.73, 682.08, -496.70), Vector3.new(-198.32, 681.29, -512.14),
            Vector3.new(-195.24, 680.10, -529.21), Vector3.new(-191.67, 678.51, -548.34),
            Vector3.new(-188.36, 678.30, -567.84), Vector3.new(-186.46, 676.94, -584.90),
            Vector3.new(-185.89, 675.51, -603.78), Vector3.new(-184.57, 674.43, -621.55),
            Vector3.new(-183.72, 674.00, -639.43), Vector3.new(-182.88, 673.96, -656.88),
            Vector3.new(-181.77, 673.04, -676.45), Vector3.new(-178.68, 672.09, -694.78),
            Vector3.new(-173.55, 670.58, -718.38), Vector3.new(-168.06, 669.27, -744.24),
            Vector3.new(-162.57, 669.00, -773.13), Vector3.new(-158.44, 670.21, -789.67),
            Vector3.new(-155.47, 672.36, -811.72), Vector3.new(-157.12, 672.00, -829.57),
            Vector3.new(-168.05, 671.18, -844.50), Vector3.new(-185.04, 670.52, -858.94),
            Vector3.new(-202.75, 671.72, -873.37), Vector3.new(-218.46, 673.97, -886.09),
            Vector3.new(-234.56, 674.04, -902.06), Vector3.new(-243.05, 673.61, -918.71),
            Vector3.new(-245.04, 673.53, -935.89), Vector3.new(-241.24, 673.75, -951.16),
            Vector3.new(-231.10, 674.15, -963.80), Vector3.new(-216.84, 674.71, -968.86),
            Vector3.new(-200.66, 675.42, -968.17), Vector3.new(-182.69, 676.12, -966.91),
            Vector3.new(-166.31, 676.46, -967.39), Vector3.new(-148.41, 676.86, -971.22),
            Vector3.new(-132.56, 676.93, -977.30), Vector3.new(-118.66, 676.78, -987.82),
            Vector3.new(-105.18, 677.89, -1000.11), Vector3.new(-90.64, 680.28, -1011.42),
            Vector3.new(-76.31, 682.05, -1027.79), Vector3.new(-61.49, 681.98, -1046.30),
            Vector3.new(-47.50, 684.07, -1063.33), Vector3.new(-32.90, 686.00, -1074.09),
            Vector3.new(-17.53, 687.59, -1078.57), Vector3.new(-0.72, 688.77, -1076.49),
            Vector3.new(13.55, 689.13, -1064.21),  Vector3.new(23.43, 689.39, -1044.21),
            Vector3.new(33.00, 690.92, -1023.98),  Vector3.new(44.31, 691.14, -1006.29),
            Vector3.new(59.45, 691.80, -993.20),   Vector3.new(76.25, 694.09, -981.45),
            Vector3.new(96.68, 697.10, -974.30),   Vector3.new(116.51, 698.60, -968.21),
            Vector3.new(137.10, 698.98, -961.67),  Vector3.new(156.29, 697.23, -951.29),
            Vector3.new(173.32, 695.05, -938.33),  Vector3.new(183.95, 692.23, -921.77),
            Vector3.new(192.97, 689.53, -903.52),  Vector3.new(200.06, 688.21, -879.53),
            Vector3.new(203.04, 686.34, -859.15),  Vector3.new(200.94, 683.58, -840.85),
            Vector3.new(197.48, 681.28, -820.58),  Vector3.new(194.06, 681.02, -800.62),
            Vector3.new(190.71, 681.74, -780.99),  Vector3.new(186.87, 684.93, -760.33),
            Vector3.new(180.77, 691.18, -742.64),  Vector3.new(174.56, 702.01, -727.44),
            Vector3.new(172.87, 713.89, -714.62),  Vector3.new(175.04, 724.01, -703.54),
            Vector3.new(180.30, 732.44, -689.90),  Vector3.new(187.55, 738.63, -677.59),
            Vector3.new(201.96, 742.96, -663.97),  Vector3.new(218.13, 738.72, -650.07),
            Vector3.new(229.16, 726.99, -637.15),  Vector3.new(232.71, 711.29, -624.60),
            Vector3.new(227.26, 695.29, -607.90),  Vector3.new(217.18, 685.64, -592.72),
            Vector3.new(205.49, 681.23, -571.62),  Vector3.new(198.88, 680.89, -549.15),
            Vector3.new(197.44, 680.99, -533.10),  Vector3.new(197.65, 680.98, -512.25),
            Vector3.new(197.14, 682.17, -492.58),  Vector3.new(194.64, 685.42, -472.25),
            Vector3.new(191.54, 688.62, -450.67),  Vector3.new(186.21, 690.50, -430.74),
            Vector3.new(180.52, 692.76, -411.41),  Vector3.new(177.31, 695.38, -390.86),
            Vector3.new(176.55, 696.49, -367.12),  Vector3.new(175.83, 698.31, -345.81),
            Vector3.new(173.35, 700.81, -324.39),  Vector3.new(169.76, 702.28, -302.98),
            Vector3.new(166.22, 703.01, -281.58),  Vector3.new(162.77, 702.73, -260.78),
            Vector3.new(159.70, 702.06, -241.29),  Vector3.new(157.52, 701.37, -221.11),
            Vector3.new(155.25, 699.89, -199.27)
        },
        [2] = {
            Vector3.new(150.20, 702.99, -297.33), Vector3.new(156.25, 702.87, -280.83),
            Vector3.new(161.96, 703.34, -265.27), Vector3.new(166.07, 704.21, -249.41),
            Vector3.new(169.19, 705.19, -233.33), Vector3.new(174.99, 706.52, -216.19),
            Vector3.new(181.25, 707.99, -200.43), Vector3.new(187.32, 709.26, -185.21),
            Vector3.new(193.99, 709.98, -168.22), Vector3.new(199.80, 709.58, -151.18),
            Vector3.new(203.61, 708.60, -134.76), Vector3.new(206.88, 707.20, -118.46),
            Vector3.new(210.21, 706.40, -102.35), Vector3.new(213.52, 706.09, -86.17),
            Vector3.new(214.61, 705.78, -73.63),  Vector3.new(213.17, 705.10, -56.81),
            Vector3.new(211.23, 704.68, -40.74),  Vector3.new(207.94, 703.85, -19.76),
            Vector3.new(201.18, 701.82, -5.13),   Vector3.new(191.35, 700.50, 9.79),
            Vector3.new(178.33, 699.54, 25.61),   Vector3.new(164.34, 698.34, 33.95),
            Vector3.new(148.88, 697.11, 39.24),   Vector3.new(133.22, 696.62, 44.28),
            Vector3.new(116.78, 696.16, 51.19),   Vector3.new(101.84, 695.17, 59.11),
            Vector3.new(85.80, 693.52, 67.81),    Vector3.new(67.42, 691.23, 76.57),
            Vector3.new(49.83, 691.42, 78.30),    Vector3.new(32.63, 690.01, 75.49),
            Vector3.new(16.16, 686.51, 70.37),    Vector3.new(0.14, 681.99, 70.53),
            Vector3.new(-15.62, 681.65, 74.92),   Vector3.new(-31.68, 683.71, 80.31),
            Vector3.new(-47.83, 687.66, 84.39),   Vector3.new(-65.05, 686.78, 86.92),
            Vector3.new(-82.65, 685.45, 87.79),   Vector3.new(-99.35, 684.37, 87.45),
            Vector3.new(-116.34, 684.68, 83.01),  Vector3.new(-133.22, 683.05, 74.69),
            Vector3.new(-146.11, 683.01, 64.32),  Vector3.new(-155.69, 683.01, 50.98),
            Vector3.new(-161.77, 683.02, 33.99),  Vector3.new(-163.25, 683.01, 16.93),
            Vector3.new(-160.17, 683.01, -1.18),  Vector3.new(-155.03, 683.06, -16.43),
            Vector3.new(-150.15, 683.24, -36.10), Vector3.new(-149.86, 683.53, -48.86),
            Vector3.new(-150.80, 683.97, -67.37), Vector3.new(-144.25, 685.25, -86.69),
            Vector3.new(-137.47, 685.81, -104.97), Vector3.new(-133.88, 686.13, -124.11),
            Vector3.new(-133.45, 686.30, -139.14), Vector3.new(-142.47, 686.47, -153.07),
            Vector3.new(-150.88, 686.64, -166.64), Vector3.new(-152.15, 686.80, -178.45),
            Vector3.new(-151.87, 686.95, -191.47), Vector3.new(-154.73, 687.17, -206.49),
            Vector3.new(-159.03, 691.88, -222.63), Vector3.new(-162.19, 702.09, -233.66),
            Vector3.new(-163.86, 712.25, -238.67), Vector3.new(-164.83, 723.64, -240.38),
            Vector3.new(-164.84, 731.92, -240.38), Vector3.new(-163.90, 746.29, -242.39),
            Vector3.new(-163.52, 757.05, -247.52), Vector3.new(-163.68, 766.26, -255.52),
            Vector3.new(-164.30, 772.95, -265.76), Vector3.new(-165.38, 776.67, -279.00),
            Vector3.new(-166.45, 776.98, -292.20), Vector3.new(-167.38, 776.99, -304.37),
            Vector3.new(-168.37, 776.99, -317.25), Vector3.new(-169.29, 776.99, -329.21),
            Vector3.new(-170.40, 777.01, -343.84), Vector3.new(-171.19, 776.97, -355.57),
            Vector3.new(-172.01, 777.01, -368.62), Vector3.new(-172.47, 776.88, -381.43),
            Vector3.new(-170.89, 782.35, -400.01), Vector3.new(-168.98, 785.77, -418.31),
            Vector3.new(-167.50, 787.06, -434.62), Vector3.new(-166.62, 786.03, -450.13),
            Vector3.new(-166.44, 783.02, -463.48), Vector3.new(-166.92, 778.22, -476.41),
            Vector3.new(-168.01, 772.23, -488.16), Vector3.new(-171.33, 770.99, -500.38),
            Vector3.new(-180.91, 771.05, -514.66), Vector3.new(-194.71, 771.02, -525.79),
            Vector3.new(-206.69, 771.01, -537.34), Vector3.new(-217.69, 773.89, -550.17),
            Vector3.new(-225.52, 778.90, -559.41), Vector3.new(-232.70, 780.99, -567.91),
            Vector3.new(-240.35, 780.40, -577.31), Vector3.new(-247.91, 776.08, -587.47),
            Vector3.new(-254.25, 768.94, -596.77), Vector3.new(-260.43, 764.96, -607.47),
            Vector3.new(-266.73, 765.05, -622.61), Vector3.new(-271.41, 765.01, -643.10),
            Vector3.new(-275.59, 764.95, -659.36), Vector3.new(-281.98, 764.99, -674.81),
            Vector3.new(-287.98, 771.18, -689.08), Vector3.new(-293.46, 775.30, -704.40),
            Vector3.new(-297.23, 774.56, -715.66), Vector3.new(-300.70, 770.50, -726.26),
            Vector3.new(-303.86, 763.23, -735.84), Vector3.new(-306.67, 752.88, -744.16),
            Vector3.new(-309.73, 748.09, -754.08), Vector3.new(-313.06, 744.22, -765.12),
            Vector3.new(-316.12, 740.73, -775.60), Vector3.new(-318.31, 737.24, -787.80),
            Vector3.new(-318.35, 734.88, -799.33), Vector3.new(-317.13, 733.29, -812.13),
            Vector3.new(-313.61, 733.00, -829.37), Vector3.new(-306.86, 733.02, -845.21),
            Vector3.new(-298.17, 734.09, -858.25), Vector3.new(-286.96, 733.01, -868.49),
            Vector3.new(-270.90, 732.99, -873.67), Vector3.new(-255.31, 733.01, -867.45),
            Vector3.new(-245.24, 732.99, -852.00), Vector3.new(-236.67, 732.94, -835.87),
            Vector3.new(-226.88, 730.77, -818.53), Vector3.new(-217.50, 730.13, -803.03),
            Vector3.new(-208.56, 731.31, -788.82), Vector3.new(-196.89, 733.12, -772.90),
            Vector3.new(-182.94, 734.36, -762.90), Vector3.new(-167.45, 734.94, -758.75),
            Vector3.new(-149.18, 734.59, -758.48), Vector3.new(-132.71, 733.41, -758.59),
            Vector3.new(-115.33, 733.35, -758.93), Vector3.new(-100.69, 738.02, -761.76),
            Vector3.new(-89.01, 747.67, -765.08),  Vector3.new(-81.46, 760.83, -767.60),
            Vector3.new(-78.94, 773.63, -768.90),  Vector3.new(-81.22, 789.82, -769.63),
            Vector3.new(-87.56, 801.36, -771.61),  Vector3.new(-98.79, 811.69, -774.67),
            Vector3.new(-112.17, 817.43, -780.53), Vector3.new(-126.42, 819.25, -787.48),
            Vector3.new(-141.05, 817.26, -793.71), Vector3.new(-154.84, 811.16, -799.39),
            Vector3.new(-166.49, 800.89, -805.16), Vector3.new(-173.91, 788.31, -810.76),
            Vector3.new(-176.92, 772.25, -817.15), Vector3.new(-173.20, 756.26, -821.78),
            Vector3.new(-163.75, 743.28, -826.80), Vector3.new(-150.25, 735.14, -832.70),
            Vector3.new(-134.05, 733.00, -839.33), Vector3.new(-116.90, 732.44, -846.14),
            Vector3.new(-96.50, 730.74, -854.61),  Vector3.new(-78.69, 729.07, -865.48),
            Vector3.new(-65.85, 727.72, -879.60),  Vector3.new(-56.08, 726.92, -894.24),
            Vector3.new(-48.22, 723.82, -913.78),  Vector3.new(-40.40, 720.87, -930.67),
            Vector3.new(-29.68, 718.39, -944.33),  Vector3.new(-16.75, 714.28, -954.95),
            Vector3.new(-1.58, 710.68, -965.37),   Vector3.new(13.33, 710.77, -975.69),
            Vector3.new(30.51, 710.35, -982.66),   Vector3.new(49.02, 712.31, -984.72),
            Vector3.new(67.12, 714.72, -980.76),   Vector3.new(82.08, 715.39, -970.12),
            Vector3.new(89.19, 713.70, -954.44),   Vector3.new(86.90, 709.01, -937.73),
            Vector3.new(77.58, 708.56, -919.84),   Vector3.new(70.54, 710.12, -902.37),
            Vector3.new(63.67, 709.03, -884.34),   Vector3.new(57.22, 708.39, -863.31),
            Vector3.new(54.02, 708.25, -843.12),   Vector3.new(49.72, 708.97, -826.11),
            Vector3.new(48.47, 709.76, -809.57),   Vector3.new(51.00, 710.46, -793.28),
            Vector3.new(55.96, 711.41, -773.03),   Vector3.new(61.38, 712.90, -752.39),
            Vector3.new(67.35, 710.72, -736.82),   Vector3.new(71.13, 708.04, -720.90),
            Vector3.new(72.78, 705.41, -704.92),   Vector3.new(74.23, 704.22, -691.30),
            Vector3.new(75.48, 704.29, -675.17),   Vector3.new(74.90, 705.19, -658.42),
            Vector3.new(72.83, 706.56, -637.81),   Vector3.new(68.19, 708.36, -620.63),
            Vector3.new(60.83, 708.16, -599.91),   Vector3.new(56.65, 706.67, -582.42),
            Vector3.new(58.65, 705.32, -565.72),   Vector3.new(63.39, 703.79, -546.12),
            Vector3.new(67.69, 704.49, -529.36),   Vector3.new(72.08, 705.99, -511.70),
            Vector3.new(76.51, 707.75, -493.59),   Vector3.new(80.50, 707.93, -475.78),
            Vector3.new(84.71, 707.47, -457.18),   Vector3.new(89.94, 708.06, -437.96),
            Vector3.new(97.06, 708.37, -423.98),   Vector3.new(106.47, 708.47, -410.88),
            Vector3.new(118.17, 707.55, -394.77),  Vector3.new(128.96, 705.27, -379.29),
            Vector3.new(137.37, 703.76, -358.33),  Vector3.new(144.83, 703.00, -336.27),
            Vector3.new(153.63, 703.01, -311.93),  Vector3.new(162.98, 702.98, -286.08),
            Vector3.new(168.63, 703.18, -270.51)
        },
        [3] = {
            Vector3.new(154.43, 703.03, -272.66), Vector3.new(151.63, 703.31, -287.45),
            Vector3.new(150.93, 704.72, -303.07), Vector3.new(150.29, 706.59, -322.22),
            Vector3.new(152.04, 706.03, -342.44), Vector3.new(157.70, 703.75, -358.92),
            Vector3.new(163.90, 701.75, -375.79), Vector3.new(170.96, 700.11, -392.67),
            Vector3.new(182.28, 698.21, -410.40), Vector3.new(196.19, 696.26, -423.04),
            Vector3.new(213.98, 694.89, -433.94), Vector3.new(233.00, 692.66, -441.40),
            Vector3.new(253.89, 687.94, -449.33), Vector3.new(274.08, 682.23, -456.48),
            Vector3.new(295.76, 675.50, -461.73), Vector3.new(317.69, 668.52, -464.87),
            Vector3.new(337.95, 662.28, -467.64), Vector3.new(358.18, 656.43, -472.69),
            Vector3.new(377.75, 651.97, -475.43), Vector3.new(397.40, 648.60, -482.30),
            Vector3.new(415.21, 647.09, -492.66), Vector3.new(431.19, 647.22, -500.10),
            Vector3.new(447.09, 647.64, -506.18), Vector3.new(464.26, 647.44, -512.85),
            Vector3.new(481.80, 648.18, -519.62), Vector3.new(498.27, 649.14, -525.91),
            Vector3.new(517.85, 650.36, -533.17), Vector3.new(537.45, 650.55, -539.31),
            Vector3.new(555.52, 650.52, -543.87), Vector3.new(570.22, 650.68, -550.35),
            Vector3.new(580.34, 650.78, -553.71), Vector3.new(596.29, 650.37, -551.53),
            Vector3.new(618.17, 650.39, -552.51), Vector3.new(637.65, 650.06, -551.63),
            Vector3.new(659.17, 649.55, -549.96), Vector3.new(680.79, 649.45, -550.74),
            Vector3.new(700.70, 649.30, -553.04), Vector3.new(719.62, 649.94, -559.37),
            Vector3.new(732.94, 647.94, -567.81), Vector3.new(745.06, 648.27, -581.94),
            Vector3.new(754.28, 647.38, -595.57), Vector3.new(761.34, 647.68, -610.21),
            Vector3.new(767.42, 649.91, -626.53), Vector3.new(770.74, 650.42, -643.17),
            Vector3.new(771.22, 652.63, -661.46), Vector3.new(768.30, 656.59, -681.29),
            Vector3.new(763.57, 658.04, -697.78), Vector3.new(759.80, 657.22, -721.16),
            Vector3.new(764.06, 656.29, -736.17), Vector3.new(758.88, 655.56, -750.90),
            Vector3.new(753.07, 655.15, -765.69), Vector3.new(749.39, 655.06, -781.39),
            Vector3.new(743.51, 655.54, -796.75), Vector3.new(736.63, 656.47, -815.39),
            Vector3.new(729.80, 656.26, -829.42), Vector3.new(721.83, 656.36, -844.58),
            Vector3.new(709.28, 656.95, -859.62), Vector3.new(692.29, 656.98, -868.55),
            Vector3.new(673.38, 657.20, -873.74), Vector3.new(654.83, 657.60, -875.14),
            Vector3.new(634.71, 658.77, -874.95), Vector3.new(617.27, 660.02, -869.53),
            Vector3.new(602.31, 661.50, -861.57), Vector3.new(589.62, 663.02, -851.10),
            Vector3.new(579.92, 663.98, -836.22), Vector3.new(573.78, 664.04, -818.54),
            Vector3.new(565.85, 664.77, -801.88), Vector3.new(553.26, 666.88, -788.48),
            Vector3.new(539.53, 666.13, -778.43), Vector3.new(523.50, 666.52, -772.99),
            Vector3.new(504.82, 666.99, -775.45), Vector3.new(489.06, 665.55, -781.58),
            Vector3.new(475.17, 664.53, -794.92), Vector3.new(464.96, 663.74, -809.66),
            Vector3.new(454.71, 663.99, -829.70), Vector3.new(445.01, 666.37, -845.77),
            Vector3.new(435.52, 667.45, -862.23), Vector3.new(425.95, 668.13, -883.58),
            Vector3.new(420.05, 668.88, -905.53), Vector3.new(414.53, 669.56, -927.13),
            Vector3.new(406.98, 669.92, -943.10), Vector3.new(396.50, 669.90, -956.66),
            Vector3.new(383.30, 669.67, -966.47), Vector3.new(368.98, 671.43, -972.00),
            Vector3.new(359.16, 671.42, -981.47), Vector3.new(352.98, 673.29, -990.22),
            Vector3.new(342.56, 672.71, -985.88), Vector3.new(332.30, 672.15, -974.10),
            Vector3.new(322.06, 672.15, -960.78), Vector3.new(310.51, 672.97, -942.19),
            Vector3.new(306.23, 672.87, -924.52), Vector3.new(303.11, 671.86, -904.24),
            Vector3.new(298.72, 674.01, -887.59), Vector3.new(290.57, 678.25, -872.05),
            Vector3.new(279.95, 682.81, -860.13), Vector3.new(266.88, 688.04, -849.90),
            Vector3.new(251.59, 693.10, -843.24), Vector3.new(237.86, 696.85, -842.16),
            Vector3.new(222.42, 700.65, -844.49), Vector3.new(206.95, 704.26, -849.62),
            Vector3.new(190.89, 707.62, -859.35), Vector3.new(179.71, 709.61, -873.42),
            Vector3.new(175.87, 710.07, -885.84), Vector3.new(174.50, 710.11, -899.02),
            Vector3.new(173.92, 711.34, -911.55), Vector3.new(175.42, 714.91, -929.21),
            Vector3.new(182.97, 718.02, -942.91), Vector3.new(196.80, 720.92, -953.24),
            Vector3.new(210.50, 724.35, -959.34), Vector3.new(225.89, 728.59, -962.83),
            Vector3.new(241.18, 733.27, -963.77), Vector3.new(255.53, 737.23, -959.73),
            Vector3.new(268.01, 740.42, -949.72), Vector3.new(278.83, 743.72, -936.94),
            Vector3.new(288.03, 746.65, -922.59), Vector3.new(298.70, 748.34, -902.47),
            Vector3.new(309.40, 749.73, -888.47), Vector3.new(322.04, 750.87, -878.85),
            Vector3.new(335.45, 752.23, -870.86), Vector3.new(348.49, 753.42, -861.21),
            Vector3.new(359.05, 752.97, -848.29), Vector3.new(368.49, 752.08, -834.88),
            Vector3.new(378.54, 751.77, -820.50), Vector3.new(387.25, 752.08, -807.89),
            Vector3.new(398.25, 753.06, -787.99), Vector3.new(402.27, 753.70, -775.03),
            Vector3.new(401.50, 754.06, -758.03), Vector3.new(392.90, 753.41, -744.43),
            Vector3.new(378.48, 752.34, -734.28), Vector3.new(364.72, 752.75, -726.63),
            Vector3.new(352.92, 753.77, -712.58), Vector3.new(348.71, 753.40, -693.13),
            Vector3.new(349.42, 752.68, -669.06), Vector3.new(348.57, 752.68, -652.37),
            Vector3.new(349.31, 753.00, -636.34), Vector3.new(352.95, 753.01, -619.48),
            Vector3.new(357.04, 753.01, -603.52), Vector3.new(361.60, 753.04, -585.48),
            Vector3.new(364.70, 753.30, -565.56), Vector3.new(363.52, 753.34, -548.19),
            Vector3.new(358.25, 751.12, -529.98), Vector3.new(350.81, 744.05, -516.20),
            Vector3.new(346.08, 734.51, -507.05), Vector3.new(344.74, 724.46, -499.01),
            Vector3.new(346.44, 714.87, -491.51), Vector3.new(351.43, 704.39, -484.42),
            Vector3.new(359.39, 695.71, -479.79), Vector3.new(372.01, 688.57, -476.11),
            Vector3.new(385.28, 686.92, -474.03), Vector3.new(398.52, 689.99, -472.51),
            Vector3.new(413.48, 701.86, -470.63), Vector3.new(419.17, 713.59, -468.86),
            Vector3.new(420.79, 725.79, -465.03), Vector3.new(418.83, 737.15, -457.73),
            Vector3.new(415.28, 744.04, -448.14), Vector3.new(411.58, 748.74, -434.86),
            Vector3.new(408.66, 751.08, -424.33), Vector3.new(405.28, 752.76, -411.70),
            Vector3.new(401.94, 753.55, -399.48), Vector3.new(400.02, 753.60, -387.73),
            Vector3.new(399.63, 753.30, -375.74), Vector3.new(401.47, 753.07, -363.84),
            Vector3.new(404.63, 753.01, -352.13), Vector3.new(407.94, 753.01, -340.48),
            Vector3.new(411.27, 753.01, -328.79), Vector3.new(414.59, 753.01, -317.12),
            Vector3.new(417.88, 753.01, -305.50), Vector3.new(420.62, 752.93, -293.25),
            Vector3.new(422.67, 753.01, -281.03), Vector3.new(425.02, 752.97, -266.38),
            Vector3.new(427.00, 753.01, -254.42), Vector3.new(429.74, 753.01, -242.91),
            Vector3.new(432.90, 753.01, -231.61), Vector3.new(436.24, 755.82, -219.92),
            Vector3.new(439.70, 761.04, -207.72), Vector3.new(443.16, 763.43, -195.42),
            Vector3.new(446.54, 762.59, -183.52), Vector3.new(449.78, 758.45, -172.34),
            Vector3.new(452.88, 750.70, -161.96), Vector3.new(455.27, 740.66, -153.54),
            Vector3.new(457.37, 734.25, -143.50), Vector3.new(457.96, 730.91, -130.16),
            Vector3.new(456.69, 727.22, -117.82), Vector3.new(453.45, 722.64, -104.27),
            Vector3.new(449.77, 719.25, -93.74),  Vector3.new(444.09, 715.38, -82.18),
            Vector3.new(437.69, 712.20, -71.87),  Vector3.new(429.61, 709.34, -61.89),
            Vector3.new(420.08, 707.00, -54.17),  Vector3.new(408.32, 704.98, -48.49),
            Vector3.new(395.44, 703.76, -44.05),  Vector3.new(383.92, 703.21, -40.78),
            Vector3.new(371.26, 703.17, -37.76),  Vector3.new(359.33, 703.08, -37.20),
            Vector3.new(345.68, 702.63, -40.01),  Vector3.new(333.62, 702.41, -44.06),
            Vector3.new(322.30, 702.34, -49.27),  Vector3.new(312.03, 702.22, -58.18),
            Vector3.new(302.11, 702.44, -66.50),  Vector3.new(292.38, 702.20, -75.61),
            Vector3.new(283.49, 701.62, -84.35),  Vector3.new(274.00, 700.95, -93.75),
            Vector3.new(264.43, 700.17, -103.24), Vector3.new(256.03, 699.62, -111.99),
            Vector3.new(245.95, 698.90, -123.08), Vector3.new(235.31, 698.44, -133.73),
            Vector3.new(225.84, 698.13, -143.64), Vector3.new(217.81, 697.99, -152.63),
            Vector3.new(209.25, 698.84, -162.43), Vector3.new(200.35, 701.25, -172.68),
            Vector3.new(191.07, 702.79, -184.77), Vector3.new(184.45, 702.51, -196.56),
            Vector3.new(180.33, 702.46, -207.84), Vector3.new(176.87, 702.77, -219.56),
            Vector3.new(173.03, 702.99, -234.40), Vector3.new(171.21, 703.01, -245.91),
            Vector3.new(169.48, 703.01, -259.01), Vector3.new(167.71, 702.97, -272.98),
            Vector3.new(165.91, 703.16, -287.35), Vector3.new(164.31, 704.06, -300.16),
            Vector3.new(163.18, 705.09, -309.17)
        }
    }

    local session = {
        currentMap = 1,
        currentIndex = 1,
        lapCount = 1,
        speed = 1000,
        mapCooldownUntil = 0,
        lastProgressIndex = 1,
        lastProgressTime = tick(),
    }

    local function getActiveEntity()
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

        if humanoid and humanoid.SeatPart then
            local seat = humanoid.SeatPart
            local vehicleModel = seat:FindFirstAncestorWhichIsA("Model")
            if vehicleModel then
                return vehicleModel, (vehicleModel.PrimaryPart or seat)
            end
            return seat, seat
        end
        return character, rootPart
    end

    local function applyNoClip(model)
        if not model then return end
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end

    -- ==========================================================
    -- 2. DÒ MAP VÀ CHUYỂN MAP LIÊN TỤC
    -- ==========================================================
    task.spawn(function()
        local lastWorldCheck = 0
        local lastRoadInstance = nil
        local lastChildCount = -1

        local function triggerNextMap(targetMap)
            if tick() - lastWorldCheck < 4.0 then return end
            lastWorldCheck = tick()

            if targetMap then
                session.currentMap = targetMap
            else
                session.currentMap = (session.currentMap % 3) + 1
            end

            session.currentIndex = 1
            session.lapCount = 1
            session.mapCooldownUntil = tick() + 10
            session.lastProgressIndex = 1
            session.lastProgressTime = tick()
            log(string.format("Chuyển sang MAP %d -> Chờ 10s nạp asset!", session.currentMap))
        end

        while ctx.alive do
            task.wait(0.3)
            if state.AutoHorseRacing == true then
                local gpWorld = Workspace:FindFirstChild("GrandPrixWorld")
                if gpWorld then
                    local road = gpWorld:FindFirstChild("Road")
                    local scenery = gpWorld:FindFirstChild("Scenery")

                    if road and road ~= lastRoadInstance then
                        if lastRoadInstance ~= nil then
                            triggerNextMap()
                        end
                        lastRoadInstance = road
                    end

                    if road then
                        local currentCount = #road:GetChildren() + (scenery and #scenery:GetChildren() or 0)
                        if lastChildCount ~= -1 and math.abs(currentCount - lastChildCount) >= 8 then
                            triggerNextMap()
                        end
                        lastChildCount = currentCount
                    end
                else
                    lastRoadInstance = nil
                    lastChildCount = -1
                end
            end
        end
    end)

    -- ==========================================================
    -- 3. VÒNG LẶP AUTOPILOT (ĐUA NGỰA VƯỢT ĐỊA HÌNH)
    -- ==========================================================
    task.spawn(function()
        log("Lõi Auto Horse Racing sẵn sàng...")

        while ctx.alive do
            if state.AutoHorseRacing == true then
                -- 1. Chờ nạp map nếu vừa đổi
                if tick() < session.mapCooldownUntil then
                    local entity, root = getActiveEntity()
                    if root and root.Parent then
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                    end
                    RunService.Heartbeat:Wait()
                    continue
                end

                local track = RecordedTracks[session.currentMap]
                if track and #track > 2 then
                    local entity, root = getActiveEntity()
                    if root and root.Parent then
                        applyNoClip(entity)
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero

                        -- 2. Watchdog: Nếu kẹt 8s tại 1 waypoint thì reset về Waypoint 1
                        if session.currentIndex == session.lastProgressIndex then
                            if tick() - session.lastProgressTime >= 8.0 then
                                log(string.format("Kẹt tại Waypoint %d quá 8s! Reset về điểm 1...", session.currentIndex))
                                session.currentIndex = 1
                                session.lastProgressIndex = 1
                                session.lastProgressTime = tick()

                                local p1 = track[1]
                                local p2 = track[2] or (p1 + Vector3.new(0, 0, 1))
                                local resetCF = CFrame.lookAt(p1, p2)
                                if entity:IsA("Model") then
                                    entity:PivotTo(resetCF)
                                else
                                    root.CFrame = resetCF
                                end
                                task.wait(0.1)
                            end
                        else
                            session.lastProgressIndex = session.currentIndex
                            session.lastProgressTime = tick()
                        end

                        -- 3. Di chuyển CFrame mượt mà
                        local dt = RunService.Heartbeat:Wait()
                        local remainingDist = session.speed * dt
                        local currentPos = root.Position
                        local forwardDir = root.CFrame.LookVector

                        while remainingDist > 0 and state.AutoHorseRacing == true and (tick() >= session.mapCooldownUntil) do
                            local targetPt = track[session.currentIndex]
                            local delta = targetPt - currentPos
                            local dist = delta.Magnitude

                            if dist > 0.01 then
                                forwardDir = delta.Unit
                            end

                            if dist <= remainingDist then
                                remainingDist = remainingDist - dist
                                currentPos = targetPt
                                session.currentIndex = session.currentIndex + 1

                                if session.currentIndex > #track then
                                    session.currentIndex = 1
                                    session.lapCount = session.lapCount + 1
                                    log(string.format("Hoàn thành Map %d Vòng %d!", session.currentMap, session.lapCount - 1))
                                end
                            else
                                currentPos = currentPos + (delta.Unit * remainingDist)
                                remainingDist = 0
                            end
                        end

                        local finalCF = CFrame.lookAt(currentPos, currentPos + forwardDir)
                        if entity:IsA("Model") then
                            entity:PivotTo(finalCF)
                        else
                            root.CFrame = finalCF
                        end
                    else
                        task.wait(0.2)
                    end
                else
                    task.wait(0.5)
                end
            else
                task.wait(0.3)
            end
        end
        log("Worker AutoHorseRacing đã dừng an toàn do ctx.alive = false.")
    end)

    if type(ui.SetToggleHandler) == "function" then
        ui:SetToggleHandler("AutoHorseRacing", function(enabled)
            log("AutoHorseRacing = " .. tostring(enabled))
            if enabled then
                session.currentIndex = 1
                session.lastProgressTime = tick()
                session.mapCooldownUntil = tick() + 2
            end
        end)
    end
end

return AutoHorseRacing
end)()
-- END MODULE AutoHorseRacing

-- BEGIN MODULE AutoTrialOfTheSaint
Modules.AutoTrialOfTheSaint = (function()
--[[
    LotusHub / modules/Gamemode/Trail Of The Saint/Auto Trial Of The Saint.lua
    Chức năng: Auto Trial Of The Saint (Chế độ Thử thách Thánh nhân).
    Bao gồm bảng chọn giữa 2 ending:
      1. True ending
      2. Secret ending (Secret endinh)
    Hiện tại khởi tạo giao diện và state, sẵn sàng nạp logic khi có raw.
]]
local AutoTrialOfTheSaint = {}

function AutoTrialOfTheSaint.Init(ctx, ui)
    local state = ctx.state

    if state.AutoTrialOfTheSaint == nil then
        state.AutoTrialOfTheSaint = false
    end

    if type(state.TrialEndings) ~= "table" then
        state.TrialEndings = {
            ["True ending"] = true,
            ["Secret ending"] = false,
        }
    end

    local function log(message)
        print("[LotusHub TrialOfTheSaint] " .. message)
    end

    if type(ui.SetToggleHandler) == "function" then
        ui:SetToggleHandler("AutoTrialOfTheSaint", function(enabled)
            log("AutoTrialOfTheSaint = " .. tostring(enabled))
        end)
    end
end

return AutoTrialOfTheSaint
end)()
-- END MODULE AutoTrialOfTheSaint

local env = ((type(getgenv) == "function") and getgenv()) or _G
local Players = game:GetService("Players")
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
if not player then error("[LotusHub] LocalPlayer chưa sẵn sàng") end

local Menu = Modules.Menu
local ModifierConfig = Modules.ModifierConfig
local Gameplay = Modules.Gameplay
local Modifiers = Modules.Modifiers
local Gamemode = Modules.Gamemode
local Match = Modules.Match
local Replay = Modules.Replay
local BoostPerformance = Modules.BoostPerformance
local AutoPick = Modules.AutoPick
local RestartAfterWaves = Modules.RestartAfterWaves
local RestartIfMissingModifier = Modules.RestartIfMissingModifier
local AutoJoinGrandPrix = Modules.AutoJoinGrandPrix
local AutoHorseRacing = Modules.AutoHorseRacing
local AutoTrialOfTheSaint = Modules.AutoTrialOfTheSaint

-- [START] Chỉ khi import xong mới dọn phiên cũ, tránh trùng worker/GUI.
if type(env.LotusHubUI) == "table" and type(env.LotusHubUI.Destroy) == "function" then
    pcall(function() env.LotusHubUI:Destroy() end)
end
local playerGui = player:WaitForChild("PlayerGui")
local leftoverGui = playerGui:FindFirstChild("LotusHub_Gameplay_UI_Demo")
if leftoverGui then leftoverGui:Destroy() end

pcall(function()
    local cg = game:GetService("CoreGui")
    local cgGui = cg and cg:FindFirstChild("LotusHub_Gameplay_UI_Demo")
    if cgGui then cgGui:Destroy() end
end)

pcall(function()
    if type(gethui) == "function" then
        local h = gethui()
        local hGui = h and h:FindFirstChild("LotusHub_Gameplay_UI_Demo")
        if hGui then hGui:Destroy() end
    end
end)

-- Xóa sạch hoàn toàn các file config cũ để chống tự động bật cheat từ phiên trước
if type(delfile) == "function" and type(isfile) == "function" then
    pcall(function()
        if isfile("LotusHub_Config.json") then delfile("LotusHub_Config.json") end
    end)
elseif type(writefile) == "function" then
    pcall(writefile, "LotusHub_Config.json", "{}")
end

local function setupAutoReloadOnTeleport(ctx, player)
    local queueteleport = (type(queue_on_teleport) == "function" and queue_on_teleport)
        or (syn and type(syn.queue_on_teleport) == "function" and syn.queue_on_teleport)
        or (fluxus and type(fluxus.queue_on_teleport) == "function" and fluxus.queue_on_teleport)

    if not queueteleport then return end

    local reloadPayload = [[
        task.spawn(function()
            if not game:IsLoaded() then
                game.Loaded:Wait()
            end
            local Players = game:GetService("Players")
            local lp = Players.LocalPlayer or Players.PlayerAdded:Wait()
            lp:WaitForChild("PlayerGui", 30)
            task.wait(0.5)

            local loaded = false

            -- 1. Ưu tiên đọc file cục bộ trong thư mục workspace của Executor
            if type(readfile) == "function" and type(loadstring) == "function" then
                local candidatePaths = {
                    "LotusHub_Autoload.lua",
                    "LotusHub/run_all_standalone.lua",
                    "run_all_standalone.lua",
                    "LotusHub/run_all.lua",
                    "run_all.lua",
                }
                for _, path in ipairs(candidatePaths) do
                    local ok, content = pcall(readfile, path)
                    if ok and type(content) == "string" and #content > 500 then
                        local fn, err = loadstring(content, "@" .. path)
                        if fn then
                            local runOk = pcall(fn)
                            if runOk then
                                loaded = true
                                break
                            end
                        end
                    end
                end
            end

            -- 2. Dự phòng: Nếu dán script trực tiếp không lưu file, nạp qua GitHub raw (chuẩn Infinite Yield)
            if not loaded and type(game.HttpGet) == "function" and type(loadstring) == "function" then
                local githubUrls = {
                    "https://raw.githubusercontent.com/BaroGITHU/LotusHub/Bao/run_all_standalone.lua",
                    "https://raw.githubusercontent.com/BaroGITHU/LotusHub/main/run_all_standalone.lua",
                }
                for _, url in ipairs(githubUrls) do
                    local ok, content = pcall(function() return game:HttpGet(url) end)
                    if ok and type(content) == "string" and #content > 500 then
                        local fn = loadstring(content, "@GitHub_LotusHub")
                        if fn then
                            local runOk = pcall(fn)
                            if runOk then
                                loaded = true
                                break
                            end
                        end
                    end
                end
            end
        end)
    ]]

    if type(writefile) == "function" and type(readfile) == "function" then
        pcall(function()
            for _, p in ipairs({"LotusHub/run_all_standalone.lua", "run_all_standalone.lua", "LotusHub/run_all.lua", "run_all.lua"}) do
                local ok, code = pcall(readfile, p)
                if ok and type(code) == "string" and #code > 500 then
                    writefile("LotusHub_Autoload.lua", code)
                    break
                end
            end
        end)
    end

    -- Đăng ký queueteleport ngay lập tức (phòng trường hợp OnTeleport bị bỏ lỡ)
    pcall(queueteleport, reloadPayload)

    -- Đăng ký lắng nghe sự kiện OnTeleport chuẩn Infinite Yield (kết nối trực tiếp, không phụ thuộc ctx)
    local teleportCheck = false
    Players.LocalPlayer.OnTeleport:Connect(function(state)
        if not teleportCheck and queueteleport then
            teleportCheck = true
            pcall(queueteleport, reloadPayload)
        end
    end)
end

local ctx = {
    env = env,
    playerGui = playerGui,
    state = {
        AutoStartgame = false,
        AutoActiveAutoPlay = false,
    },
    expanded = {},
    knownModifiers = {},
    ModifierConfig = ModifierConfig,
    connections = {},
    alive = true,
    screen = nil,
    SaveConfig = function() end,
}

-- Đăng ký listener để dọn sạch khi đóng UI hoặc Execute lại.
function ctx:Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.connections, connection)
    return connection
end

function ctx:Destroy()
    if not self.alive then return end
    self.alive = false
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

-- [GẮN MODULE] Lần lượt tạo UI, đăng ký Gameplay, Modifiers & Gamemode, nối tất cả worker.
local ok, err = pcall(function()
    local ui = Menu.Create(ctx)
    ctx.ui = ui
    ModifierConfig.Init(ctx, ui)
    Gameplay.Init(ctx, ui)
    Modifiers.Init(ctx, ui)
    Gamemode.Init(ctx, ui)
    Match.Init(ctx, ui)
    Replay.Init(ctx, ui)
    BoostPerformance.Init(ctx, ui)
    AutoPick.Init(ctx, ui)
    RestartAfterWaves.Init(ctx, ui)
    RestartIfMissingModifier.Init(ctx, ui)
    AutoJoinGrandPrix.Init(ctx, ui)
    AutoHorseRacing.Init(ctx, ui)
    AutoTrialOfTheSaint.Init(ctx, ui)
    env.LotusHubUI = ui
    ui:ShowTab("Gameplay")
    setupAutoReloadOnTeleport(ctx, player)
end)

if not ok then
    ctx:Destroy()
    error("[LotusHub] Khởi động thất bại: " .. tostring(err))
end

print("[LotusHub Standalone] Đã nạp thành công: Menu + Gameplay + Modifiers + Gamemode (Grand Prix & Trail Of The Saint).")
