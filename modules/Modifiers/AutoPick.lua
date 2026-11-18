--[[
    LotusHub / modules/Modifiers/AutoPick.lua — Tự động nhận diện và chọn Modifier (Thẻ bài).
    Tích hợp từ raw source Auto Pick Modifiers (hỗ trợ cả Starter Cards & Additive Cards,
    lọc số La Mã I, II, III... và số thường).
    
    Tuân thủ kiến trúc LotusHub:
    - Vòng lặp kiểm tra ctx.alive, ngắt tức thì khi UI bị hủy hoặc Execute lại.
    - Không tạo ScreenGui trôi nổi riêng biệt; giao diện tích hợp hoàn toàn trong LotusHub.
    - Không sử dụng Tween/Hover animation trên các nút thao tác.
]]
local AutoPick = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

function AutoPick.Init(ctx, ui)
    local player = Players.LocalPlayer
    local playerGui = ctx.playerGui or (player and player:WaitForChild("PlayerGui"))
    local state = ctx.state

    -- [1] NẠP BẢNG CẤU HÌNH MODIFIERS
    local ModifierConfig = ctx.ModifierConfig
    if not ModifierConfig then
        -- Fallback tìm trong package hoặc loadfile nếu chưa gắn vào ctx
        local ok, mod = pcall(function()
            return loadstring(readfile("LotusHub/modules/Modifiers/ModifierConfig.lua"))()
        end)
        if ok and type(mod) == "table" then
            ModifierConfig = mod
        else
            -- Tối thiểu cần có table cấu hình mặc định
            ModifierConfig = {
                GetDefaultPriorityMap = function() return {} end,
                NormalizeCardName = function(text, lookup)
                    local clean = text:gsub("<[^>]+>", ""):match("^%s*(.-)%s*$") or ""
                    local base = clean:gsub("%s+[IVXLCDM]+$", ""):gsub("%s+%d+$", ""):match("^%s*(.-)%s*$") or clean
                    local score = lookup and lookup[string.lower(base)]
                    return base, (score or -1)
                end,
                List = {}
            }
        end
        ctx.ModifierConfig = ModifierConfig
    end

    -- Khởi tạo state mặc định cho Modifiers
    if state.AutoPickModifiers == nil then
        state.AutoPickModifiers = false
    end
    if type(state.ModifierPriority) ~= "table" then
        state.ModifierPriority = {}
    end

    -- [2] TRẠNG THÁI NỘI BỘ CỦA WORKER
    local session = {
        hasVotedThisRound = false,
        lastVoteTime = 0,
        lastCardFound = "",
    }

    local function log(message)
        print("[LotusHub AutoPick] " .. message)
    end

    local function getActivePriorityMap()
        local baseMap = ModifierConfig.GetDefaultPriorityMap and ModifierConfig.GetDefaultPriorityMap() or {}
        local activeMap = {}
        for k, v in pairs(baseMap) do
            activeMap[k] = v
        end
        -- Áp dụng các mức ưu tiên người dùng tùy chỉnh
        for modName, customPrio in pairs(state.ModifierPriority) do
            local num = tonumber(customPrio)
            if num then
                activeMap[string.lower(modName)] = math.floor(num)
            end
        end
        return activeMap
    end

    -- Mô phỏng click chuột tại tọa độ màn hình
    local function simulateClickAt(x, y)
        if not VirtualInputManager then return end
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
            task.wait(0.04)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
    end

    -- [3] HÀM QUÉT VÀ BỎ PHIẾU CHỌN THẺ TỐT NHẤT
    local function attemptPickCard()
        if not ctx.alive or state.AutoPickModifiers ~= true then
            return false
        end

        local priorityLookup = getActivePriorityMap()
        local candidates = {}
        local isVotePending = false

        for _, gui in ipairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui ~= ctx.screen then
                -- Bỏ qua GUI LotusHub chính để không nhận diện nhầm chữ trên menu
                local guiName = gui.Name
                if not guiName:find("LotusHub") then
                    for _, label in ipairs(gui:GetDescendants()) do
                        if label:IsA("TextLabel") and label.Visible then
                            local text = label.Text
                            if text:find("(0/1)") then
                                isVotePending = true
                            end

                            if #text >= 3 then
                                local baseName, score = ModifierConfig.NormalizeCardName(text, priorityLookup)
                                if score >= 0 then
                                    local pos = label.AbsolutePosition
                                    local size = label.AbsoluteSize
                                    if pos.X > 10 and pos.Y > 10 and size.X > 0 and size.Y > 0 then
                                        local cardContainer = label:FindFirstAncestorWhichIsA("Frame") or label
                                        local cardCenter = cardContainer.AbsolutePosition + (cardContainer.AbsoluteSize / 2)

                                        table.insert(candidates, {
                                            Original = text,
                                            BaseName = baseName,
                                            Score = score,
                                            ClickX = cardCenter.X,
                                            ClickY = cardCenter.Y,
                                            Element = cardContainer
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if #candidates > 0 and (isVotePending or not session.hasVotedThisRound) then
            -- Khử trùng lặp thẻ
            local uniqueCandidates = {}
            local seen = {}
            for _, c in ipairs(candidates) do
                if not seen[c.Original] then
                    seen[c.Original] = true
                    table.insert(uniqueCandidates, c)
                end
            end

            -- Sắp xếp giảm dần theo điểm ưu tiên Score
            table.sort(uniqueCandidates, function(a, b)
                return a.Score > b.Score
            end)

            local chosen = uniqueCandidates[1]
            session.hasVotedThisRound = true
            session.lastVoteTime = tick()
            session.lastCardFound = chosen.BaseName

            log(string.format("Đã chọn thẻ tối ưu: '%s' (Gốc: '%s' | Ưu tiên: %d) tại (%d, %d)",
                chosen.BaseName, chosen.Original, chosen.Score, chosen.ClickX, chosen.ClickY))

            task.spawn(function()
                -- Bước 1: Thử gọi tín hiệu nút nếu có firesignal
                if type(firesignal) == "function" then
                    local btn = chosen.Element:FindFirstChildWhichIsA("GuiButton", true)
                    if btn then
                        pcall(function() firesignal(btn.MouseButton1Click) end)
                        pcall(function() firesignal(btn.Activated) end)
                    end
                end

                -- Bước 2: Mô phỏng click chuột vào tâm thẻ và nút Vote bên dưới
                simulateClickAt(chosen.ClickX, chosen.ClickY)
                task.wait(0.05)
                simulateClickAt(chosen.ClickX, chosen.ClickY + 110)
            end)

            return true
        end

        return false
    end

    -- [4] VÒNG LẶP POLLING TỰ ĐỘNG QUÉT THẺ MODIFIER
    task.spawn(function()
        while ctx.alive do
            task.wait(0.3)

            if state.AutoPickModifiers == true then
                local isCardWindowOpen = false

                for _, gui in ipairs(playerGui:GetChildren()) do
                    if gui:IsA("ScreenGui") and gui.Enabled and gui ~= ctx.screen then
                        local guiName = gui.Name
                        if not guiName:find("LotusHub") then
                            for _, label in ipairs(gui:GetDescendants()) do
                                if label:IsA("TextLabel") and label.Visible then
                                    local t = label.Text
                                    if t:find("Additive Cards")
                                        or t:find("Starter Cards")
                                        or t:find("Automatically ends")
                                        or t:find("Click to vote") then
                                        isCardWindowOpen = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                    if isCardWindowOpen then break end
                end

                if not isCardWindowOpen then
                    if session.hasVotedThisRound then
                        session.hasVotedThisRound = false
                    end
                else
                    if tick() - session.lastVoteTime > 2.2 then
                        attemptPickCard()
                    end
                end
            end
        end
        log("Worker AutoPick đã dừng an toàn do ctx.alive = false.")
    end)

    -- [5] ĐĂNG KÝ TOGGLE HANDLER VỚI UI
    if type(ui.SetToggleHandler) == "function" then
        ui:SetToggleHandler("AutoPickModifiers", function(enabled)
            log("AutoPickModifiers = " .. tostring(enabled))
            if enabled then
                session.hasVotedThisRound = false
                session.lastVoteTime = 0
                task.spawn(function()
                    task.wait(0.05)
                    attemptPickCard()
                end)
            end
        end)
    end
end

return AutoPick
