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
