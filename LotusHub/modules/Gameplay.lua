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
