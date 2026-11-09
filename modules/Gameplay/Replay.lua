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
