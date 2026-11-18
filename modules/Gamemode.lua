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
        GrandPrix = true,
        TrailOfTheSaint = true,
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
        local grandPrixSection = section(scroll, "GrandPrix", "Grand Prix", true)
        stateToggle(grandPrixSection, "Auto join Grand Prix", "AutoJoinGrandPrix")
        stateToggle(grandPrixSection, "Auto Horse Racing", "AutoHorseRacing")
        infoItem(grandPrixSection, "Grand Prix: Tự động xác nhận Mount Picker và đua ngựa autopilot 1000 spd.")

        -- ====================================================================
        -- 2. NHÓM TRAIL OF THE SAINT
        -- ====================================================================
        local saintSection = section(scroll, "TrailOfTheSaint", "Trail Of The Saint", true)
        stateToggle(saintSection, "Auto Trial Of The Saint", "AutoTrialOfTheSaint")

        -- [BẢNG CHỌN GIỮA CÁC ENDING (Tương tự bảng Modifier)]
        local endingContainer = Instance.new("Frame")
        endingContainer.Name = "TrialEndingContainer"
        endingContainer.LayoutOrder = #saintSection:GetChildren()
        endingContainer.Size = UDim2.new(1, 0, 0, 140)
        endingContainer.BackgroundColor3 = C.row
        endingContainer.BackgroundTransparency = 0.26
        endingContainer.BorderSizePixel = 0
        endingContainer.Active = true
        endingContainer.Parent = saintSection
        local ecCorner = Instance.new("UICorner")
        ecCorner.CornerRadius = UDim.new(0, 8)
        ecCorner.Parent = endingContainer

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
            end)
        end
    end

    -- [5] Đăng ký tab Gamemode với Menu chính
    ui:RegisterTab("Gamemode", function()
        buildGamemode()
    end)
end

return Gamemode