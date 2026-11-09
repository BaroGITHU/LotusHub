--[[
    LotusHub / modules/Gameplay/Match.lua — logic Match v3 tách khỏi GUI.
    Nguồn: Match v3 trong Menu.lua người dùng cung cấp (09/11/2026).
    Hai toggle ĐỘC LẬP: AutoStartgame và AutoActiveAutoPlay.
    Start 0x02 sau khi thấy "Match Start", mỗi 1 giây; nhận
    "Match Started!" mới cho phép thử Auto Play 0x00 khi GUI báo OFF.

    BẰNG CHỨNG: Remote là capture người dùng; stage/title/DisplayText
    vẫn CANDIDATE. Không tuyên bố đã test in-game.
    Đóng UI/Execute lại => ctx.alive=false, listener bị ngắt.
]]
local Match = {}

function Match.Init(ctx, ui)
    local playerGui = ctx.playerGui
    local state = ctx.state
    local screen = ctx.screen

    local function connect(signal, callback)
        return ctx:Connect(signal, callback)
    end

    -- [MATCH V3.1] CẤU HÌNH ĐƯỢC PHÉP CHỈNH
    local MATCH_CONFIG = {
        CheckInterval = 0.25,       -- Kiểm tra GUI 4 lần/giây; KHÔNG gửi Start 4 lần/giây.
        StartDelay = 0,            -- 0 = thử Start ngay khi xác định màn hình tiền trận.
        StartRetry = 1,            -- Tối thiểu 1 giây giữa các lệnh Start (giảm spam mạng).
        AutoPlayRetry = 1,         -- Thử lại Auto Play khi GUI còn OFF, tối thiểu 1 giây.
        AutoPlayVerify = 3,        -- Sau khi gửi Auto Play, chờ GUI xác nhận trong 3 giây.
        StageAbsentChecks = 8,     -- 8 x 0.25 = 2 giây mất GUI mới xem là rời Stage.
        MaxStartAttempts = 0,      -- 0 = không giới hạn; có thể đặt 120 để tự dừng sau 120 lần.
    }

    -- [MATCH V3.2] TÊN REMOTE/PAYLOAD ĐỀU TỪ CAPTURE NGƯỜI DÙNG CUNG CẤP
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

    -- In trạng thái mới khi thay đổi, tránh Output bị đầy khi polling liên tục.
    local function matchLogOnce(key, message)
        if matchSession.lastMessages[key] ~= message then
            matchSession.lastMessages[key] = message
            matchLog(message)
        end
    end

    -- [MATCH V3.3] KIỂM TRA HIỂN THỊ THẬT (CẢ GUI CHA VÀ ScreenGui)
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

    -- [MATCH V3.4] GUI STAGE ỨNG VIÊN TỪ DEX, KHÔNG PHẢI SERVER STATE
    local function matchFindPlayRoot()
        local node = playerGui
        for _, name in ipairs({ "Guides", "List", "MatchStatusHUD", "Buttons", "AutoPlay" }) do
            node = node:FindFirstChild(name)
            if not node then return nil end
        end
        return matchVisible(node) and node or nil
    end

    -- Ghi nhận màn hình kết thúc để ngăn vòng Start tiếp tục lúc đã hết trận.
    local function matchEndScreenShowing()
        local endScreen = playerGui:FindFirstChild("EndScreen")
        if not endScreen then return false end
        local holder = endScreen:FindFirstChild("Holder")
        return (holder and matchVisible(holder)) or false
    end

    -- [MATCH V3.5] "Match Start" LÀ DẤU HIỆU TIỀN TRẬN (CANDIDATE)
    -- Không tìm được nút Start thật, nên không giả định GUI button cụ thể.
    -- Chỉ tìm chữ đang hiển thị bên trong game, bỏ qua UI LotusHub.
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

    -- [MATCH V3.6] AUTO PLAY: CHỈ BẬT KHI ĐỌC ĐƯỢC OFF CHÍNH XÁC
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

    -- [MATCH V3.7] GỬI REMOTE (THÀNH CÔNG GỌI HÀM != SERVER CHẤP NHẬN)
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

    -- [MATCH V3.8] TÁCH TỪNG PHIÊN STAGE, KHÔNG ĐỂ VÒNG CŨ HOẠT ĐỘNG
    local function matchNewStage(root, now)
        matchSession.nextId += 1
        local stage = {
            id = matchSession.nextId,
            root = root,
            detectedAt = now,
            started = false,                -- Chỉ true khi nghe notification Match Started!
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

    -- [MATCH V3.9] NGHE THÔNG BÁO THẬT TRONG PHIÊN, KHÔNG firesignal GIẢ LẬP
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
                    if state.AutoActiveAutoPlay then
                        matchLog("Auto Active Auto Play ON → kiểm tra GUI để bật")
                    end
                end
            elseif raw:find(MSG_PLAY_ON, 1, true) then
                matchLog("Nhận thông báo Successfully enabled auto play! (sẽ xác minh GUI)")
            elseif raw:find(MSG_PLAY_FAIL, 1, true) then
                -- Chỉ để log; không làm điều kiện gửi Start trong logic mới.
                matchLog("Nhận Failure Auto Play; V3 KHÔNG dùng Failure để gửi Start")
            end
        end)
    else
        matchLog("MISSING notification Remote; không thể xác nhận Start từ notification")
    end

    -- [MATCH V3.10] MỘT VÒNG KIỂM TRA CHO CẢ HAI TOGGLE
    local function matchTick()
        if not ctx.alive or matchSession.checking then return end
        matchSession.checking = true

        local ok, err = pcall(function()
            local now = os.clock()
            local root = matchFindPlayRoot()
            local endShowing = matchEndScreenShowing()
            local stage = matchSession.stage

            -- EndScreen hiển thị = không thể tiếp tục Start/AutoPlay.
            if endShowing then
                if stage then matchEndStage("EndScreen đang hiển thị") end
                return
            end

            -- Khi GUI Stage mất, hủy session sau nhiều lần liên tiếp.
            if not root then
                if stage then
                    matchSession.absentTicks += 1
                    if matchSession.absentTicks >= MATCH_CONFIG.StageAbsentChecks then
                        matchEndStage("GUI AutoPlay biến mất")
                    end
                end
                if state.AutoStartgame or state.AutoActiveAutoPlay then
                    matchLogOnce("stage", "WAIT: chưa thấy GUI Stage, không gửi Remote")
                end
                return
            end

            if not stage or stage.root ~= root then
                stage = matchNewStage(root, now)
            end
            matchSession.absentTicks = 0

            local hasTitle = matchHasStartTitle()

            -- Khi cùng một Instance GUI được tái sử dụng ở Stage mới:
            -- sau khi đã Start, title biến mất rồi xuất hiện lại => tạo phiên mới.
            if stage.started and not hasTitle then
                stage.titleGoneAfterSeen = true
            elseif stage.started and hasTitle and stage.titleGoneAfterSeen then
                stage = matchNewStage(root, now)
            end

            if hasTitle then
                stage.titleSeen = true
            end

            -- AUTO STARTGAME: CHỈ DÙNG START REMOTE, KHÔNG PROBE AUTO PLAY.
            if state.AutoStartgame and not stage.started then
                if not hasTitle then
                    if stage.titleSeen then
                        matchLogOnce("start", "TẠM DỪNG Start: Match Start đã biến mất; chưa xem là xác nhận bắt đầu")
                    else
                        matchLogOnce("start", "WAIT: chưa thấy chữ Match Start (CANDIDATE)")
                    end
                elseif now - stage.detectedAt < MATCH_CONFIG.StartDelay then
                    matchLogOnce("start", "Đang chờ StartDelay " .. MATCH_CONFIG.StartDelay .. " giây")
                elseif MATCH_CONFIG.MaxStartAttempts > 0
                    and stage.startAttempts >= MATCH_CONFIG.MaxStartAttempts then
                    matchLogOnce("start", "PAUSED: đã đạt MaxStartAttempts; cần kiểm tra game")
                elseif not stage.startLastAt or now - stage.startLastAt >= MATCH_CONFIG.StartRetry then
                    stage.startLastAt = now
                    stage.startAttempts += 1
                    if matchSend(START_REMOTE_NAME, "\002") then
                        -- Log lượt 1, rồi mỗi 10 lượt để tránh làm lag Output.
                        if stage.startAttempts == 1 or stage.startAttempts % 10 == 0 then
                            matchLog("Đã gửi Start 0x02 lần " .. stage.startAttempts
                                .. " (chờ Match Started!)")
                        end
                    end
                end
            end

            -- AUTO ACTIVE AUTO PLAY: CHỈ THỬ SAU KHI NHẬN Match Started!.
            if state.AutoActiveAutoPlay then
                if not stage.started then
                    matchLogOnce("play", "WAIT: chưa có Match Started!, chưa gửi Auto Play")
                else
                    local playState, detail = matchReadPlayState(root)
                    if playState == "ON" then
                        stage.playWaitingUntil = nil
                        matchLogOnce("play", "VERIFIED GUI: Auto Playing (đang ON)")
                    elseif playState == "UNKNOWN" then
                        matchLogOnce("play", "UNKNOWN AutoPlay: " .. detail .. "; không gửi mù")
                    else
                        local pending = stage.playWaitingUntil and now < stage.playWaitingUntil
                        local cooldown = not stage.playLastAt
                            or now - stage.playLastAt >= MATCH_CONFIG.AutoPlayRetry
                        if not pending and cooldown then
                            stage.playLastAt = now
                            stage.playWaitingUntil = now + MATCH_CONFIG.AutoPlayVerify
                            if matchSend(PLAY_REMOTE_NAME, "\000") then
                                matchLog("Đã gửi Auto Play 0x00; chờ GUI đổi Auto Playing")
                            else
                                stage.playWaitingUntil = nil
                            end
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

    -- [MATCH V3.11] GẮN TOGGLE; OFF CHỈ DỪNG RIÊNG, KHÔNG ĐỔI TOGGLE KHÁC
    local function onMatchToggleChanged(key, enabled)
        local stage = matchSession.stage
        if stage then
            if key == "AutoStartgame" then
                if enabled then
                    -- ON lại trong cùng Stage cho phép tiếp tục khi chưa started.
                    stage.startLastAt = nil
                    stage.startAttempts = 0
                end
            elseif key == "AutoActiveAutoPlay" then
                -- Reset thời điểm thử khi bật lại, không gửi lệnh tắt trong game.
                stage.playLastAt = nil
                stage.playWaitingUntil = nil
            end
        end
        matchLog(key .. " = " .. tostring(enabled))
        if enabled then task.defer(matchTick) end
    end

    -- [MATCH] GẮN RIÊNG TỪNG HANDLER: không phụ thuộc Menu.lua.
    ui:SetToggleHandler("AutoStartgame", function(value)
        onMatchToggleChanged("AutoStartgame", value)
    end)
    ui:SetToggleHandler("AutoActiveAutoPlay", function(value)
        onMatchToggleChanged("AutoActiveAutoPlay", value)
    end)

    -- [MATCH V3.12] CHỈ MỘT WORKER; ĐÓNG UI => alive=false, ngừng tự động
    -- Không tạo worker mới mỗi lần người dùng bật/tắt toggle.
    task.spawn(function()
        while ctx.alive do
            matchTick()
            task.wait(MATCH_CONFIG.CheckInterval)
        end
    end)
end

return Match
