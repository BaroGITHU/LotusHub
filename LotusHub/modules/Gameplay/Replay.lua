--[[
    LOTUSHUB / modules/Gameplay/Replay.lua
    ======================================
    Module triển khai Gameplay -> Replay (v2: tích hợp raw Leave/Lobby).

    DỮ LIỆU ĐÃ CÓ TỪ NGƯỜI DÙNG:
      VERIFIED: PlayerGui.EndScreen.Holder.Buttons.Retry.Button là TextButton,
                từng quan sát hiển thị khi kết thúc trận.
      CANDIDATE: ReplicatedStorage.AV_GAME_ENDSCREEN_V1_BLINK_RELIABLE_REMOTE
                 với buffer 1 byte HEX 03, xuất hiện trong log lúc bấm Retry.
      CANDIDATE: Raw có EndScreen.Holder.Buttons.Leave (chưa có log Dex).
      UNTESTED:  Raw có AV_GAME_MATCH_FLOW... buffer 03 và Lobby PlaceId
                 16146832113. KHÔNG tự gọi hai lệnh này để tránh về sai nơi.
      UNTESTED:  Gửi 03 từ script có thực sự Retry và chuyển Stage hay không.

    CHỨC NĂNG:
      1) Auto Replay: khi Retry của EndScreen hiển thị, thử gửi 03.
         Không spam vô hạn; có giới hạn lần thử và chờ màn hình phản hồi.
      2) Teleport to lobby after N replays: đếm những lượt Retry do
         LotusHub gửi mà quan sát được EndScreen đóng + dấu hiệu Stage.
         Khi đạt N, ngừng Retry và đợi EndScreen tiếp theo để thử nút
         Leave của game hoặc Lobby handler riêng.
      3) Hiển thị bộ đếm trong Replay, cho phép Reset thủ công.

    KHÔNG dùng firesignal, KHÔNG giả vờ đã được server xác nhận.
    Đóng menu hay Execute lại: ctx.alive=false -> dừng vòng kiểm tra.
]]
local Replay = {}

function Replay.Init(ctx, ui)
    local state = ctx.state
    local playerGui = ctx.playerGui
    local rs = game:GetService("ReplicatedStorage")
    local vim -- Nạp VirtualInputManager bằng pcall khi thực sự cần click Leave.

    -- [R1] CẤU HÌNH: thay con số tại đây nếu muốn điều chỉnh.
    local CONFIG = {
        PollInterval = 0.35,          -- Kiểm tra UI khoảng 3 lần/giây.
        RetryCooldown = 6,           -- Đợi 6 giây trước khi thử lại nếu EndScreen còn hiện.
        MaxAttemptsPerEndScreen = 2,  -- Tối đa 2 FireServer cho một EndScreen.
        TransitionStable = 0.8,      -- EndScreen phải biến mất ổn định >= 0.8 giây.
        TransitionTimeout = 25,      -- Đợi tối đa 25 giây để quan sát chuyển sang Stage.
        StageChecksEnabled = true,  -- Không đếm chỉ vì Retry biến mất.
        -- Chỉ gửi 1 thao tác click. Không kích hoạt đồng thời nhiều signal.
        -- Raw cũng có firesignal, MATCH_FLOW remote, TeleportService:Teleport.
        -- Không gọi các phương thức dự phòng chưa xác minh ở bản này.
    }

    -- [R2] REMOTE ĐƯỢC CAPTURE; KHÔNG TỰ BỊA ĐƯỜNG DẪN.
    local RETRY_REMOTE = "AV_GAME_ENDSCREEN_V1_BLINK_RELIABLE_REMOTE"
    local NOTIFICATION_REMOTE = "AV_GAME_NOTIFICATIONS_POPUPS_V1_BLINK_RELIABLE_REMOTE"
    local MATCH_STARTED_TEXT = "Match Started!"

    local session = {
        wasVisible = false,      -- Retry có hiện ở lần kiểm tra trước?
        endScreenId = 0,        -- Tăng khi thấy một màn hình kết thúc mới.
        attempts = 0,           -- Số lượt thử trong EndScreen hiện tại.
        lastAttemptAt = nil,
        awaitingHide = false,   -- Đã gửi 03, đang đợi EndScreen ẩn.
        confirming = false,     -- EndScreen đã ẩn, chờ dấu hiệu Stage.
        hiddenSince = nil,
        confirmDeadline = nil,
        matchStartedAfterRetry = false,
        count = 0,              -- Số lượt Replay quan sát được trong phiên bật.
        lobbyRequested = false,
        lobbyHandler = nil,     -- Tùy chọn callback Lobby đã được xác minh sau này.
        lobbyPendingAt = nil,   -- Thời gian đã thử bấm Leave (chưa phải ACK).
        lastStatus = nil,
        tickRunning = false,
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

    -- [R3] KIỂM TRA GUI HIỂN THỊ (cả Visible của cha và ScreenGui.Enabled).
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

    -- GUI Retry thực tế: EndScreen.Retry.Button (VERIFIED từ log).
    -- Raw bổ sung HUD.EndFrame.Retry.Body (CANDIDATE). Cả hai đều
    -- phải đang hiển thị thật; không suy luận từ Name đơn thuần.
    local function getRetryButton()
        local endScreen = playerGui:FindFirstChild("EndScreen")
        local holder = endScreen and endScreen:FindFirstChild("Holder")
        local buttons = holder and holder:FindFirstChild("Buttons")
        local retry = buttons and buttons:FindFirstChild("Retry")
        local button = retry and retry:FindFirstChild("Button")
        if button and button:IsA("GuiObject") then
            -- Có Button nhưng đang ẩn thì KHÔNG dùng Frame cha để gửi Retry.
            return visible(button) and button or nil
        end
        -- Retry có thể là Frame chứa nút hoặc vùng bấm.
        if retry and visible(retry) then return retry end

        local hud = playerGui:FindFirstChild("HUD")
        local endFrame = hud and hud:FindFirstChild("EndFrame")
        local hudRetry = endFrame and endFrame:FindFirstChild("Retry")
        if endFrame and visible(endFrame) and hudRetry and visible(hudRetry) then
            local body = hudRetry:FindFirstChild("Body")
            if body and visible(body) then return body end
            return hudRetry
        end
        return nil
    end

    -- [R4] TÍN HIỆU CHUYỂN VỀ STAGE: chỉ là GUI CANDIDATE.
    -- Dùng để chống việc tính một lượt Replay chỉ vì EndScreen đóng.
    -- Không khẳng định đây là state server chính thức.
    local function stageHintVisible()
        local hud = playerGui:FindFirstChild("HUD")
        local stageFrame = hud and hud:FindFirstChild("StageFrame")
        if stageFrame and visible(stageFrame) then return true end

        local guides = playerGui:FindFirstChild("Guides")
        local list = guides and guides:FindFirstChild("List")
        local matchHud = list and list:FindFirstChild("MatchStatusHUD")
        local buttons = matchHud and matchHud:FindFirstChild("Buttons")
        local autoPlay = buttons and buttons:FindFirstChild("AutoPlay")
        if autoPlay and visible(autoPlay) then return true end

        return false
    end

    -- [R5] ĐỌC SLIDER N; nếu giá trị chưa hợp lệ thì dùng N=20 mặc định.
    local function replayLimit()
        return math.clamp(math.floor(tonumber(state.ReplayLimit) or 20), 1, 100)
    end

    local function limitReached()
        return state.ReplayLimitEnabled == true
            and session.count >= replayLimit()
    end

    -- [R6] DỮ LIỆU LOBBY TỪ RAW: chỉ có GUI Leave là đường tương tác ứng viên.
    -- KHÔNG gửi AV_GAME_MATCH_FLOW buffer 03 / TeleportService (chưa xác minh).
    local function getLeaveButton()
        -- CANDIDATE #1 từ raw: EndScreen.Holder.Buttons.Leave.
        local endScreen = playerGui:FindFirstChild("EndScreen")
        local holder = endScreen and endScreen:FindFirstChild("Holder")
        local buttons = holder and holder:FindFirstChild("Buttons")
        local leaveRoot = buttons and buttons:FindFirstChild("Leave")

        -- CANDIDATE #2 từ raw: HUD.EndFrame.Leave.Body.
        if not leaveRoot or not visible(leaveRoot) then
            local hud = playerGui:FindFirstChild("HUD")
            local endFrame = hud and hud:FindFirstChild("EndFrame")
            local hudLeave = endFrame and endFrame:FindFirstChild("Leave")
            if endFrame and visible(endFrame) and hudLeave and visible(hudLeave) then
                leaveRoot = hudLeave
            else
                return nil
            end
        end

        -- Ưu tiên GuiButton thực nếu có; fallback Frame đúng path từ raw.
        if leaveRoot:IsA("GuiButton") then return leaveRoot end
        local button = leaveRoot:FindFirstChild("Button")
        if button and button:IsA("GuiButton") then
            -- Button tồn tại nhưng không hiển thị => chưa được phép tương tác.
            return visible(button) and button or nil
        end
        button = leaveRoot:FindFirstChildWhichIsA("GuiButton", true)
        if button and visible(button) then return button end
        local body = leaveRoot:FindFirstChild("Body")
        if body and visible(body) then return body end
        return leaveRoot -- Frame ứng viên, click tại tâm như raw.
    end

    -- Bấm đúng GuiObject nằm dưới Leave của một EndScreen hiển thị.
    -- Chỉ một click (không gọi đồng thời firesignal + VIM để tránh double).
    local function clickLeave(button)
        if not ctx.alive or not button or not visible(button) then
            return false, "Nút Leave không còn hiển thị"
        end
        local okService, service = pcall(function()
            return game:GetService("VirtualInputManager")
        end)
        if not okService or not service then
            return false, "Executor không cho truy cập VirtualInputManager"
        end
        vim = service
        local center = button.AbsolutePosition + (button.AbsoluteSize / 2)
        local ok, err = pcall(function()
            vim:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
            task.wait(0.06)
            -- Luôn thả chuột kể cả khi ui/toggle đã tắt giữa thao tác.
            vim:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
        end)
        return ok, err
    end

    -- Đã đủ N: KHÔNG ngắt Stage đang chạy; chỉ thử Leave lúc EndScreen hiện.
    local function tryLobby(endVisible)
        if not ctx.alive or not limitReached() or not endVisible then return end
        if session.lobbyRequested then return end

        local fn = session.lobbyHandler
        if type(fn) == "function" then
            session.lobbyRequested = true
            session.lobbyPendingAt = os.clock()
            local ok, sent = pcall(fn, {
                count = session.count,
                limit = replayLimit(),
                reason = "ReplayLimit",
            })
            if not ok then
                warn("[LotusHub Replay] Lỗi Lobby handler: " .. tostring(sent))
            else
                log("Đã gọi Lobby handler (ACK kết quả: " .. tostring(sent)
                    .. "). Chưa xác nhận đã về Lobby.")
            end
            return
        end

        local leave = getLeaveButton()
        if not leave then
            logOnce("leaveMissing", "CANDIDATE Leave GUI chưa có/không hiển thị."
                .. " Đạt " .. session.count .. "/" .. replayLimit()
                .. "; đã dừng Retry, không tự gọi Remote/PlaceId chưa kiểm chứng.")
            return
        end

        -- Chặn thử lặp sau lần nhấn đầu tiên; không teleport liên tục.
        -- Nếu menu LotusHub đang che nút Leave trên màn hình, cần thu nhỏ
        -- menu để VirtualInputManager click tới đúng GUI của game.
        session.lobbyRequested = true
        session.lobbyPendingAt = os.clock()
        local ok, err = clickLeave(leave)
        if ok then
            log("Đã THỬ nhấn Leave qua VirtualInputManager; chờ xác minh Lobby."
                .. " (CANDIDATE GUI, chưa phải ACK server)")
        else
            warn("[LotusHub Replay] Không thể nhấn Leave: " .. tostring(err))
            -- Không đổi sang Remote hoặc PlaceId mù.
        end
    end

    -- [R6.1] ĐẨY SỐ ĐẾM VÀ TRẠNG THÁI VỀ UI GAMEPLAY, KHÔNG TẠO MENU RIÊNG.
    local function updateProgress()
        local status = string.format("%d/%d/%s/%s", session.count, replayLimit(),
            tostring(state.ReplayLimitEnabled), tostring(session.lobbyRequested))
        if session.lastStatus == status then return end
        session.lastStatus = status
        if type(ctx.replayProgressSink) == "function" then
            ctx.replayProgressSink(session.count, replayLimit(),
                limitReached() and "Chờ kết thúc để về Lobby" or nil)
        end
    end

    local function clearPending()
        session.awaitingHide = false
        session.confirming = false
        session.hiddenSince = nil
        session.confirmDeadline = nil
        session.matchStartedAfterRetry = false
    end

    -- [R7] THỬ GỬI REMOTE RETRY: có chống gửi trùng, không coi FireServer = thành công.
    local function sendRetry(now)
        if not ctx.alive or state.AutoReplay ~= true or limitReached() then return end
        local remote = rs:FindFirstChild(RETRY_REMOTE)
        if not remote or not remote:IsA("RemoteEvent") then
            logOnce("remoteMissing", "MISSING Remote Retry: " .. RETRY_REMOTE)
            return
        end

        -- Chốt số lần trước khi gửi để hạn chế burst nếu có lỗi.
        session.attempts += 1
        session.lastAttemptAt = now
        session.awaitingHide = true
        session.matchStartedAfterRetry = false

        local ok, err = pcall(function()
            remote:FireServer(buffer.fromstring("\003"))
        end)
        if ok then
            log("Đã gửi Retry 03 (EndScreen #" .. session.endScreenId
                .. ", thử " .. session.attempts .. "/"
                .. CONFIG.MaxAttemptsPerEndScreen .. "). Chờ chuyển trạng thái...")
        else
            session.awaitingHide = false
            warn("[LotusHub Replay] LỖI FireServer Retry: " .. tostring(err))
        end
    end

    local function onNewEndScreen()
        session.endScreenId += 1
        session.attempts = 0
        session.lastAttemptAt = nil
        clearPending()
        log("Đã thấy GUI Retry ở EndScreen #" .. session.endScreenId)
    end

    -- [R8] XÁC MINH: chỉ tăng số đếm khi chính LotusHub gửi Retry,
    -- EndScreen biến mất, và nhận được GUI Stage hoặc Match Started! sau đó.
    local function confirmReplay()
        session.count += 1
        log("Replay đã quan sát: " .. session.count .. "/" .. replayLimit()
            .. " (EndScreen ẩn + tín hiệu Stage; chưa phải ACK server Retry)")
        clearPending()
        if limitReached() then
            log("Đã đạt N Replay; chờ EndScreen kế tiếp để thử Leave, không ngắt trận giữa chừng.")
        end
        updateProgress()
    end

    -- [R9] 1 TICK: xử lý sự xuất hiện/biến mất của Retry.
    local function tick()
        if not ctx.alive or session.tickRunning then return end
        session.tickRunning = true
        local ok, err = pcall(function()
            local now = os.clock()
            local button = getRetryButton()
            local leave = getLeaveButton()
            local endVisible = (button ~= nil and visible(button))
                or (leave ~= nil and visible(leave))

            -- Phát hiện cửa sổ kết thúc mới.
            if endVisible and not session.wasVisible then
                if session.confirming then
                    log("EndScreen trở lại trước khi xác nhận Replay. Không cộng số đếm.")
                end
                onNewEndScreen()
            end

            -- Một lần Retry có vẻ đã được nhận: EndScreen đóng sau khi gửi.
            if not endVisible and session.wasVisible and session.awaitingHide then
                session.awaitingHide = false
                session.confirming = true
                session.hiddenSince = now
                session.confirmDeadline = now + CONFIG.TransitionTimeout
                log("EndScreen đã ẩn sau lệnh Retry; đang đợi dấu hiệu Stage...")
            end

            session.wasVisible = endVisible

            if session.confirming and not endVisible then
                local stable = session.hiddenSince
                    and (now - session.hiddenSince >= CONFIG.TransitionStable)
                local foundStage = session.matchStartedAfterRetry
                    or (CONFIG.StageChecksEnabled and stageHintVisible())
                if stable and foundStage then
                    confirmReplay()
                elseif now >= session.confirmDeadline then
                    log("Không xác minh được Stage mới sau Retry; KHÔNG cộng số đếm.")
                    clearPending()
                end
            end

            -- Slider/limit có thể đổi bất cứ lúc nào; kiểm tra mỗi tick.
            updateProgress()
            if limitReached() then
                -- Không về Lobby khi vẫn đang chơi Stage: chỉ ở EndScreen.
                tryLobby(endVisible)
                if session.lobbyRequested and session.lobbyPendingAt
                    and endVisible and now - session.lobbyPendingAt > 9 then
                    logOnce("leaveUnconfirmed", "Đã thử Leave nhưng EndScreen vẫn hiện sau 9 giây."
                        .. " Hãy kiểm tra lại GUI/VirtualInput; không gửi lần thứ hai.")
                end
                return
            end

            if not endVisible or not button or state.AutoReplay ~= true then return end

            -- Đang chờ Retry được xử lý: không gửi liên tiếp trong mỗi tick.
            if session.awaitingHide then
                if now - session.lastAttemptAt < CONFIG.RetryCooldown then
                    return
                end
                if session.attempts >= CONFIG.MaxAttemptsPerEndScreen then
                    logOnce("max:" .. session.endScreenId,
                        "Đã thử Retry tối đa " .. session.attempts
                            .. " lần ở EndScreen hiện tại; chờ người dùng kiểm tra.")
                    return
                end
            end

            if session.attempts == 0
                or (session.lastAttemptAt
                    and now - session.lastAttemptAt >= CONFIG.RetryCooldown
                    and session.attempts < CONFIG.MaxAttemptsPerEndScreen) then
                sendRetry(now)
            end
        end)
        session.tickRunning = false
        if not ok then
            warn("[LotusHub Replay] LỖI tick: " .. tostring(err))
        end
    end

    -- [R10] LẮNG NGHE THÔNG BÁO MATCH STARTED! SAU RETRY.
    -- Nhận thật qua OnClientEvent, không dùng firesignal mô phỏng.
    local notification = rs:FindFirstChild(NOTIFICATION_REMOTE)
    if notification and notification:IsA("RemoteEvent") then
        ctx:Connect(notification.OnClientEvent, function(payload)
            if not ctx.alive or typeof(payload) ~= "buffer" then return end
            if not (session.awaitingHide or session.confirming) then return end
            local ok, raw = pcall(buffer.tostring, payload)
            if ok and type(raw) == "string"
                and raw:find(MATCH_STARTED_TEXT, 1, true) then
                session.matchStartedAfterRetry = true
            end
        end)
    else
        logOnce("notification", "MISSING Notification Remote; chỉ dựa vào GUI Stage candidate")
    end

    -- [R11] HAI TOGGLE ĐỘC LẬP.
    -- AutoReplay OFF: dừng gửi và hủy lượt đang chờ.
    -- ReplayLimitEnabled OFF: ngừng giới hạn/teleport nhưng không tự tắt AutoReplay.
    ui:SetToggleHandler("AutoReplay", function(enabled)
        log("AutoReplay = " .. tostring(enabled))
        clearPending()
        if enabled then
            -- Không reset số đếm khi OFF/ON. Chỉ reset bằng nút Reset.
            session.attempts = 0
            session.lastAttemptAt = nil
            task.defer(tick)
        end
        updateProgress()
    end)

    ui:SetToggleHandler("ReplayLimitEnabled", function(enabled)
        log("ReplayLimitEnabled = " .. tostring(enabled)
            .. " | N=" .. replayLimit())
        if not enabled then
            -- OFF chỉ hủy phần giới hạn / yêu cầu về Lobby.
            session.lobbyRequested = false
            session.lobbyPendingAt = nil
            session.logs.leaveMissing = nil
            session.logs.leaveUnconfirmed = nil
        else
            task.defer(tick)
        end
        updateProgress()
    end)

    -- [R12] API để nối Lobby handler riêng nếu sau này có bằng chứng tốt hơn.
    function ui:SetReplayLobbyHandler(fn)
        assert(type(fn) == "function", "SetReplayLobbyHandler expects function")
        session.lobbyHandler = fn
        session.logs.leaveMissing = nil
        task.defer(tick)
    end

    function ui:GetReplayStatus()
        return {
            count = session.count,
            limit = replayLimit(),
            autoReplay = state.AutoReplay == true,
            returnToLobby = state.ReplayLimitEnabled == true,
            lobbyIntegrated = type(session.lobbyHandler) == "function" or getLeaveButton() ~= nil,
            pending = session.awaitingHide or session.confirming,
            waitingForLobby = limitReached(),
            lobbyRequested = session.lobbyRequested,
        }
    end

    function ui:ResetReplayCount()
        -- Khi Reset giữa lúc chuyển trận, không cộng lại từ phiên cũ.
        clearPending()
        session.count = 0
        session.lobbyRequested = false
        session.lobbyPendingAt = nil
        session.logs.leaveMissing = nil
        session.logs.leaveUnconfirmed = nil
        log("Đã reset số đếm Replay về 0 theo yêu cầu API")
        updateProgress()
    end

    -- [R13] CHỈ MỘT WORKER. Khi đóng UI, ctx.alive=false -> tự ngừng.
    task.spawn(function()
        while ctx.alive do
            tick()
            task.wait(CONFIG.PollInterval)
        end
    end)
end

return Replay
