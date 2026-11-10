--[[
    LotusHub / modules/Gameplay.lua — Chỉ chứa nội dung tab Gameplay.
    Nhóm chức năng hiện có: Match, Replay, Failsafe, Boost Performance.
    (Đã loại bỏ nhóm Restart và Modifiers theo yêu cầu người dùng).
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
    local toggleItem = ui.toggleItem
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

    -- [5] API tương thích ngược cho SetModifiers (tránh lỗi nếu module khác gọi).
    function ui:SetModifiers(names)
        -- No-op: tính năng Modifiers đã được gỡ bỏ khỏi giao diện.
    end

    -- [6] Đăng ký tab Gameplay với Menu chính.
    ui:RegisterTab("Gameplay", function()
        buildGameplay()
    end)
end

return Gameplay
