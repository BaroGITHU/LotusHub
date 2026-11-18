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
