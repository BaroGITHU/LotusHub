--[[
    LOTUSHUB / run_all_standalone.lua — SCRIPT CHẠY ĐƠN FILE (FIX BOUNCE/JITTER).
    - Đã triệt tiêu hoàn toàn hiện tượng co giật / nảy (bounce) UIScale khi di chuột.
    - Ổn định Input Sink, loại bỏ giật camera/nhân vật khi click menu.
    - Cố định giao diện tĩnh tuyệt đối khi tương tác.
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
        ElasticBehavior = Enum.ElasticBehavior.Never,
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
        if not build then return end
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
    local DRAG_DEADZONE = 6

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
    updateScale()

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
        toggleHandlers[key] = fn
    end

    function controller:GetState()
        local copy = {}
        for k, v in pairs(state) do copy[k] = v end
        return copy
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

-- BEGIN MODULE Gameplay
Modules.Gameplay = (function()
local Gameplay = {}

function Gameplay.Init(ctx, ui)
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

    local defaultExpanded = {
        Match = true,
        Replay = true,
        Failsafe = false,
        BoostPerformance = false,
    }
    for key, value in pairs(defaultExpanded) do
        if ctx.expanded[key] == nil then ctx.expanded[key] = value end
    end

    local scroll = ui.scroll
    local section = ui.section
    local stateToggle = ui.stateToggle
    local sliderItem = ui.sliderItem
    local infoItem = ui.infoItem

    local function buildGameplay()
        local match = section(scroll, "Match", "Match", true)
        stateToggle(match, "Auto Startgame", "AutoStartgame")
        stateToggle(match, "Auto Active Auto Play", "AutoActiveAutoPlay")

        local replay = section(scroll, "Replay", "Replay", true)
        stateToggle(replay, "Auto Replay", "AutoReplay")
        stateToggle(replay, "Teleport to lobby after N replays", "ReplayLimitEnabled")
        sliderItem(replay, "Replay count (N)", state, "ReplayLimit", 1, 100, "")

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
        reset.AutoButtonColor = false
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

        local failsafe = section(scroll, "Failsafe", "Failsafe", false)
        stateToggle(failsafe, "Auto Teleport to Lobby After Minutes", "FailsafeTeleportEnabled")
        sliderItem(failsafe, "Minutes", state, "FailsafeMinutes", 1, 120, "m")

        local boost = section(scroll, "BoostPerformance", "Boost Performance", false)
        stateToggle(boost, "FreeFire Graphics (Boost FPS)", "FreeFireGraphics")
        stateToggle(boost, "Delete Map", "DeleteMap")
        stateToggle(boost, "Delete Entities", "DeleteEntities")
        infoItem(boost, "FreeFire Graphics: Tối ưu FPS, tắt đổ bóng & hiệu ứng.")
    end

    function ui:SetModifiers(names) end

    ui:RegisterTab("Gameplay", function()
        buildGameplay()
    end)
end

return Gameplay
end)()
-- END MODULE Gameplay

-- BEGIN MODULE Match
Modules.Match = (function()
local Match = {}

function Match.Init(ctx, ui)
    local playerGui = ctx.playerGui
    local state = ctx.state
    local screen = ctx.screen

    local function connect(signal, callback)
        return ctx:Connect(signal, callback)
    end

    local MATCH_CONFIG = {
        CheckInterval = 0.25,
        StartDelay = 0,
        StartRetry = 1,
        AutoPlayRetry = 1,
        AutoPlayVerify = 3,
        StageAbsentChecks = 8,
        MaxStartAttempts = 0,
    }

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

    local function matchLogOnce(key, message)
        if matchSession.lastMessages[key] ~= message then
            matchSession.lastMessages[key] = message
            matchLog(message)
        end
    end

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

    local function matchFindPlayRoot()
        local node = playerGui
        for _, name in ipairs({ "Guides", "List", "MatchStatusHUD", "Buttons", "AutoPlay" }) do
            node = node:FindFirstChild(name)
            if not node then return nil end
        end
        return matchVisible(node) and node or nil
    end

    local function matchEndScreenShowing()
        local endScreen = playerGui:FindFirstChild("EndScreen")
        if not endScreen then return false end
        local holder = endScreen:FindFirstChild("Holder")
        return (holder and matchVisible(holder)) or false
    end

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

    local function matchNewStage(root, now)
        matchSession.nextId += 1
        local stage = {
            id = matchSession.nextId,
            root = root,
            detectedAt = now,
            started = false,
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
                end
            elseif raw:find(MSG_PLAY_ON, 1, true) then
                matchLog("Nhận thông báo Successfully enabled auto play!")
            end
        end)
    end

    local function matchTick()
        if not ctx.alive or matchSession.checking then return end
        matchSession.checking = true

        local ok, err = pcall(function()
            local now = os.clock()
            local root = matchFindPlayRoot()
            local endShowing = matchEndScreenShowing()
            local stage = matchSession.stage

            if endShowing then
                if stage then matchEndStage("EndScreen đang hiển thị") end
                return
            end

            if not root then
                if stage then
                    matchSession.absentTicks += 1
                    if matchSession.absentTicks >= MATCH_CONFIG.StageAbsentChecks then
                        matchEndStage("GUI AutoPlay biến mất")
                    end
                end
                return
            end

            if not stage or stage.root ~= root then
                stage = matchNewStage(root, now)
            end
            matchSession.absentTicks = 0

            local hasTitle = matchHasStartTitle()

            if stage.started and not hasTitle then
                stage.titleGoneAfterSeen = true
            elseif stage.started and hasTitle and stage.titleGoneAfterSeen then
                stage = matchNewStage(root, now)
            end

            if hasTitle then
                stage.titleSeen = true
            end

            if state.AutoStartgame and not stage.started then
                if hasTitle and (not stage.startLastAt or now - stage.startLastAt >= MATCH_CONFIG.StartRetry) then
                    stage.startLastAt = now
                    stage.startAttempts += 1
                    matchSend(START_REMOTE_NAME, "\002")
                end
            end

            if state.AutoActiveAutoPlay and stage.started then
                local playState, _ = matchReadPlayState(root)
                if playState == "OFF" then
                    local pending = stage.playWaitingUntil and now < stage.playWaitingUntil
                    local cooldown = not stage.playLastAt or now - stage.playLastAt >= MATCH_CONFIG.AutoPlayRetry
                    if not pending and cooldown then
                        stage.playLastAt = now
                        stage.playWaitingUntil = now + MATCH_CONFIG.AutoPlayVerify
                        if not matchSend(PLAY_REMOTE_NAME, "\000") then
                            stage.playWaitingUntil = nil
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

    local function onMatchToggleChanged(key, enabled)
        local stage = matchSession.stage
        if stage then
            if key == "AutoStartgame" and enabled then
                stage.startLastAt = nil
                stage.startAttempts = 0
            elseif key == "AutoActiveAutoPlay" then
                stage.playLastAt = nil
                stage.playWaitingUntil = nil
            end
        end
        if enabled then task.defer(matchTick) end
    end

    ui:SetToggleHandler("AutoStartgame", function(value)
        onMatchToggleChanged("AutoStartgame", value)
    end)
    ui:SetToggleHandler("AutoActiveAutoPlay", function(value)
        onMatchToggleChanged("AutoActiveAutoPlay", value)
    end)

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
local Replay = {}

function Replay.Init(ctx, ui)
    local state = ctx.state
    local playerGui = ctx.playerGui
    local rs = game:GetService("ReplicatedStorage")
    local players = game:GetService("Players")
    local player = players.LocalPlayer or players.PlayerAdded:Wait()

    local LOBBY_ID = 16146832113
    local RETRY_REMOTE_NAME = "AV_GAME_ENDSCREEN_V1_BLINK_RELIABLE_REMOTE"
    local MATCH_FLOW_REMOTE_NAME = "AV_GAME_MATCH_FLOW_V1_BLINK_RELIABLE_REMOTE"

    local CONFIG = {
        PollInterval = 0.35,
        LobbyWaitAfterClick = 0.8,
        LobbyWaitAfterRemote = 1.5,
        RetryCooldown = 6.0,
        MaxRetryAttempts = 2,
    }

    local session = {
        count = 0,
        endScreenActive = false,
        handledThisEndScreen = false,
        retryAttempts = 0,
        lastRetryAt = nil,
        lobbyTriggered = false,
        lobbyRunning = false,
        tickRunning = false,
        lastStatus = nil,
        lobbyHandler = nil,
        logs = {},
    }

    local function log(message)
        print("[LotusHub Replay] " .. message)
    end

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

    local function findButtonInContainer(container, name)
        if not container then return nil end
        local item = container:FindFirstChild(name)
        if not item then return nil end
        if item:IsA("GuiButton") and visible(item) then return item end
        local btn = item:FindFirstChild("Button")
        if btn and btn:IsA("GuiButton") and visible(btn) then return btn end
        local body = item:FindFirstChild("Body")
        if body and visible(body) then return body end
        local anyBtn = item:FindFirstChildWhichIsA("GuiButton", true)
        if anyBtn and visible(anyBtn) then return anyBtn end
        if visible(item) then return item end
        return nil
    end

    local function getEndButtons()
        local hud = playerGui:FindFirstChild("HUD")
        local endFrame = hud and hud:FindFirstChild("EndFrame")
        if endFrame and visible(endFrame) then
            local retry = findButtonInContainer(endFrame, "Retry")
            local leave = findButtonInContainer(endFrame, "Leave")
            if retry or leave then return retry, leave, "HUD.EndFrame" end
        end

        local endScreen = playerGui:FindFirstChild("EndScreen")
        local holder = endScreen and endScreen:FindFirstChild("Holder")
        local buttons = holder and holder:FindFirstChild("Buttons")
        if buttons and visible(buttons) then
            local retry = findButtonInContainer(buttons, "Retry")
            local leave = findButtonInContainer(buttons, "Leave")
            if retry or leave then return retry, leave, "EndScreen.Holder.Buttons" end
        end

        if endScreen and visible(endScreen) then
            local retry = findButtonInContainer(holder or endScreen, "Retry")
            local leave = findButtonInContainer(holder or endScreen, "Leave")
            if retry or leave then return retry, leave, "EndScreen" end
        end

        return nil, nil, nil
    end

    local function click(btn)
        if not btn or not ctx.alive then return false end
        local clicked = false

        if type(firesignal) == "function" and btn:IsA("GuiButton") then
            pcall(function() firesignal(btn.Activated) end)
            pcall(function() firesignal(btn.MouseButton1Click) end)
            clicked = true
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

    local function exitToLobby(leaveBtn)
        if session.lobbyRunning then return end
        session.lobbyRunning = true

        if leaveBtn then
            click(leaveBtn)
            task.wait(CONFIG.LobbyWaitAfterClick)
        end

        if not ctx.alive or state.ReplayLimitEnabled ~= true then
            session.lobbyRunning = false
            return
        end

        local matchFlowRemote = rs:FindFirstChild(MATCH_FLOW_REMOTE_NAME)
        if matchFlowRemote and matchFlowRemote:IsA("RemoteEvent") then
            pcall(function() matchFlowRemote:FireServer(buffer.fromstring("\003")) end)
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

        local tsOk, ts = pcall(function() return game:GetService("TeleportService") end)
        if tsOk and ts then
            pcall(function() ts:Teleport(LOBBY_ID, player) end)
        end
        session.lobbyRunning = false
    end

    local function doRetry(retryBtn)
        if retryBtn then click(retryBtn) end
        task.wait(0.2)
        local retryRemote = rs:FindFirstChild(RETRY_REMOTE_NAME)
        if retryRemote and retryRemote:IsA("RemoteEvent") then
            pcall(function() retryRemote:FireServer(buffer.fromstring("\003")) end)
        end
    end

    local function replayLimit()
        return math.clamp(math.floor(tonumber(state.ReplayLimit) or 20), 1, 100)
    end

    local function limitReached()
        return state.ReplayLimitEnabled == true and session.count >= replayLimit()
    end

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

    local function tick()
        if not ctx.alive or session.tickRunning then return end
        session.tickRunning = true

        local ok, err = pcall(function()
            local now = os.clock()
            local retryBtn, leaveBtn, _ = getEndButtons()
            local isEndVisible = (retryBtn ~= nil) or (leaveBtn ~= nil)

            if not isEndVisible then
                if session.endScreenActive then
                    session.endScreenActive = false
                    session.handledThisEndScreen = false
                    session.retryAttempts = 0
                    session.lastRetryAt = nil
                    session.lobbyTriggered = false
                end
                updateProgress()
                return
            end

            if not session.endScreenActive then
                session.endScreenActive = true
                session.handledThisEndScreen = false
                session.retryAttempts = 0
                session.lastRetryAt = nil
                session.lobbyTriggered = false
            end

            if not session.handledThisEndScreen then
                local returnAtN = (state.ReplayLimitEnabled == true)
                local autoReplay = (state.AutoReplay == true)

                if not returnAtN and not autoReplay then
                    updateProgress()
                    return
                end

                session.count += 1
                session.handledThisEndScreen = true
                updateProgress()

                local targetN = replayLimit()
                if returnAtN and session.count >= targetN then
                    session.lobbyTriggered = true
                    if type(session.lobbyHandler) == "function" then
                        pcall(session.lobbyHandler, { count = session.count, limit = targetN, reason = "ReplayLimit" })
                    else
                        task.spawn(function() exitToLobby(leaveBtn) end)
                    end
                elseif autoReplay then
                    session.retryAttempts += 1
                    session.lastRetryAt = now
                    task.spawn(function() doRetry(retryBtn) end)
                end
                return
            end

            if state.AutoReplay == true and not limitReached() then
                if session.retryAttempts < CONFIG.MaxRetryAttempts then
                    if session.lastRetryAt and (now - session.lastRetryAt >= CONFIG.RetryCooldown) then
                        session.retryAttempts += 1
                        session.lastRetryAt = now
                        task.spawn(function() doRetry(retryBtn) end)
                    end
                end
            end

            updateProgress()
        end)

        session.tickRunning = false
        if not ok then
            warn("[LotusHub Replay] LỖI tick: " .. tostring(err))
        end
    end

    ui:SetToggleHandler("AutoReplay", function(enabled)
        if enabled then task.defer(tick) end
        updateProgress()
    end)

    ui:SetToggleHandler("ReplayLimitEnabled", function(enabled)
        if enabled then task.defer(tick) end
        updateProgress()
    end)

    function ui:SetReplayLobbyHandler(fn)
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
        updateProgress()
    end

    task.spawn(function()
        while ctx.alive do
            tick()
            task.wait(CONFIG.PollInterval)
        end
    end)
end

return Replay
end)()
-- END MODULE Replay

-- BEGIN MODULE BoostPerformance
Modules.BoostPerformance = (function()
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

    local savedState = {
        lighting = {},
        terrain = {},
        postEffects = {},
        emitters = {},
        trails = {},
        beams = {},
        miscEffects = {},
        castShadows = {},
        materials = {},
        decals = {},
    }

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

    local function optimizeInstance(inst)
        if not inst or not inst.Parent then return end
        if inst:IsDescendantOf(playerGui) then return end
        local char = player.Character
        if char and inst:IsDescendantOf(char) then return end

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

    local function enableFreeFire()
        if session.active then return end
        session.active = true

        pcall(function()
            if savedState.lighting.GlobalShadows == nil then
                savedState.lighting.GlobalShadows = Lighting.GlobalShadows
                Lighting.GlobalShadows = false
            end
        end)

        for _, child in ipairs(Lighting:GetChildren()) do
            optimizePostEffect(child)
        end
        local camera = Workspace.CurrentCamera
        if camera then
            for _, child in ipairs(camera:GetChildren()) do
                optimizePostEffect(child)
            end
        end

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

        task.spawn(function()
            local descendants = Workspace:GetDescendants()
            for i, inst in ipairs(descendants) do
                if not session.active or not ctx.alive then break end
                pcall(optimizeInstance, inst)
                if i % 1000 == 0 then task.wait() end
            end
        end)

        if not session.listenerConnection then
            session.listenerConnection = Workspace.DescendantAdded:Connect(function(inst)
                if not session.active or not ctx.alive then return end
                pcall(optimizeInstance, inst)
            end)
            table.insert(ctx.connections, session.listenerConnection)
        end
    end

    local function disableFreeFire()
        if not session.active then return end
        session.active = false

        if session.listenerConnection then
            pcall(function() session.listenerConnection:Disconnect() end)
            session.listenerConnection = nil
        end

        pcall(function()
            if savedState.lighting.GlobalShadows ~= nil then
                Lighting.GlobalShadows = savedState.lighting.GlobalShadows
            end
        end)
        savedState.lighting = {}

        for obj, origEnabled in pairs(savedState.postEffects) do
            pcall(function()
                if obj and obj.Parent then obj.Enabled = origEnabled end
            end)
        end
        savedState.postEffects = {}

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

        for obj, origEnabled in pairs(savedState.emitters) do
            pcall(function() if obj and obj.Parent then obj.Enabled = origEnabled end end)
        end
        savedState.emitters = {}

        for obj, origEnabled in pairs(savedState.trails) do
            pcall(function() if obj and obj.Parent then obj.Enabled = origEnabled end end)
        end
        savedState.trails = {}

        for obj, origEnabled in pairs(savedState.beams) do
            pcall(function() if obj and obj.Parent then obj.Enabled = origEnabled end end)
        end
        savedState.beams = {}

        for obj, origEnabled in pairs(savedState.miscEffects) do
            pcall(function() if obj and obj.Parent then obj.Enabled = origEnabled end end)
        end
        savedState.miscEffects = {}

        for part, origShadow in pairs(savedState.castShadows) do
            pcall(function() if part and part.Parent then part.CastShadow = origShadow end end)
        end
        savedState.castShadows = {}

        for part, origMat in pairs(savedState.materials) do
            pcall(function() if part and part.Parent then part.Material = origMat end end)
        end
        savedState.materials = {}

        for decal, origTrans in pairs(savedState.decals) do
            pcall(function() if decal and decal.Parent then decal.Transparency = origTrans end end)
        end
        savedState.decals = {}
    end

    ui:SetToggleHandler("FreeFireGraphics", function(enabled)
        if enabled then enableFreeFire() else disableFreeFire() end
    end)

    if state.FreeFireGraphics == true then
        task.defer(enableFreeFire)
    end
end

return BoostPerformance
end)()
-- END MODULE BoostPerformance

local env = ((type(getgenv) == "function") and getgenv()) or _G
local Players = game:GetService("Players")
local player = Players.LocalPlayer
if not player then error("[LotusHub] LocalPlayer chưa sẵn sàng") end
local Menu, Gameplay, Match, Replay, BoostPerformance = Modules.Menu, Modules.Gameplay, Modules.Match, Modules.Replay, Modules.BoostPerformance

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
    connections = {},
    alive = true,
    screen = nil,
}

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

local ok, err = pcall(function()
    local ui = Menu.Create(ctx)
    ctx.ui = ui
    Gameplay.Init(ctx, ui)
    Match.Init(ctx, ui)
    Replay.Init(ctx, ui)
    BoostPerformance.Init(ctx, ui)
    env.LotusHubUI = ui
    ui:ShowTab("Gameplay")
end)

if not ok then
    ctx:Destroy()
    error("[LotusHub] Khởi động thất bại: " .. tostring(err))
end

print("[LotusHub] Đã nạp sexgay + Gameplay + Match V3 + Replay + BoostPerformance (Đã fix hoàn toàn lỗi bounce).")
