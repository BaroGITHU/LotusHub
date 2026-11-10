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
