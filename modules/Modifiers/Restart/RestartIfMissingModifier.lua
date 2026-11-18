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
