--loadstring(readfile("LotusHub/run_all.lua"))()
--[[
    LOTUSHUB MODULAR / run_all.lua — FILE KHỞI ĐỘNG DUY NHẤT.

    Import lần lượt:
      - Menu
      - ModifierConfig
      - Gameplay
      - Modifiers
      - Gamemode (Grand Prix & Trail Of The Saint)
      - Workers: Match, Replay, BoostPerformance, AutoPick, Restart, GrandPrix, TrailOfTheSaint

    GIỮ CẤU TRÚC:
      LotusHub/run_all.lua
      LotusHub/modules/Menu.lua
      LotusHub/modules/Gameplay.lua
      LotusHub/modules/Modifiers.lua
      LotusHub/modules/Gamemode.lua
      LotusHub/modules/Gameplay/Match.lua
      LotusHub/modules/Gameplay/Replay.lua
      LotusHub/modules/Gameplay/BoostPerformance.lua
      LotusHub/modules/Modifiers/ModifierConfig.lua
      LotusHub/modules/Modifiers/AutoPick.lua
      LotusHub/modules/Modifiers/Restart/Restart.lua
      LotusHub/modules/Modifiers/Restart/RestartAfterWaves.lua
      LotusHub/modules/Modifiers/Restart/RestartIfMissingModifier.lua
      LotusHub/modules/Gamemode/Grand Prix/Auto join Grand Prix.lua
      LotusHub/modules/Gamemode/Grand Prix/Auto Horse Racing.lua
      LotusHub/modules/Gamemode/Trail Of The Saint/Auto Trial Of The Saint.lua
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local env = ((type(getgenv) == "function") and getgenv()) or _G
local Players = game:GetService("Players")
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
if not player then error("[LotusHub] LocalPlayer chưa sẵn sàng") end

-- Chỉ nạp các module trong danh sách, không tải mã bên ngoài.
local MODULE_PATHS = {
    Menu = "modules/Menu.lua",
    ModifierConfig = "modules/Modifiers/ModifierConfig.lua",
    Gameplay = "modules/Gameplay.lua",
    Match = "modules/Gameplay/Match.lua",
    Replay = "modules/Gameplay/Replay.lua",
    BoostPerformance = "modules/Gameplay/BoostPerformance.lua",
    Modifiers = "modules/Modifiers.lua",
    AutoPick = "modules/Modifiers/AutoPick.lua",
    RestartAfterWaves = "modules/Modifiers/Restart/RestartAfterWaves.lua",
    RestartIfMissingModifier = "modules/Modifiers/Restart/RestartIfMissingModifier.lua",
    Gamemode = "modules/Gamemode.lua",
    AutoJoinGrandPrix = "modules/Gamemode/Grand Prix/Auto join Grand Prix.lua",
    AutoHorseRacing = "modules/Gamemode/Grand Prix/Auto Horse Racing.lua",
    AutoTrialOfTheSaint = "modules/Gamemode/Trail Of The Saint/Auto Trial Of The Saint.lua",
}

-- [IMPORT] Nếu executor lưu file trong thư mục workspace/LotusHub,
-- giữ Root mặc định. Có thể đặt getgenv().LotusHubRoot = "...".
local ROOTS = {}
if type(env.LotusHubRoot) == "string" and env.LotusHubRoot ~= "" then
    table.insert(ROOTS, env.LotusHubRoot)
end
table.insert(ROOTS, "LotusHub")
table.insert(ROOTS, ".")

local function loadModule(relativePath)
    assert(type(readfile) == "function", "Executor không hỗ trợ readfile; dùng run_all_standalone.lua")
    assert(type(loadstring) == "function", "Executor không hỗ trợ loadstring")
    local contents, foundAt
    for _, root in ipairs(ROOTS) do
        local path = root == "." and relativePath or (root .. "/" .. relativePath)
        local ok, value = pcall(readfile, path)
        if ok and type(value) == "string" then
            contents, foundAt = value, path
            break
        end
    end
    if not contents then error("[LotusHub] Không đọc được module: " .. relativePath) end
    local chunk, compileErr = loadstring(contents, "@" .. foundAt)
    if not chunk then error("[LotusHub] Lỗi cú pháp tại " .. foundAt .. ": " .. tostring(compileErr)) end
    local result = chunk()
    assert(type(result) == "table" and type(result.Init or result.Create) == "function", "Module sai giao diện: " .. foundAt)
    return result
end

-- Import TRƯỚC KHI đóng UI cũ: nếu thiếu file, UI đang dùng không mất.
local Menu = loadModule(MODULE_PATHS.Menu)
local ModifierConfig = loadModule(MODULE_PATHS.ModifierConfig)
local Gameplay = loadModule(MODULE_PATHS.Gameplay)
local Modifiers = loadModule(MODULE_PATHS.Modifiers)
local Gamemode = loadModule(MODULE_PATHS.Gamemode)
local Match = loadModule(MODULE_PATHS.Match)
local Replay = loadModule(MODULE_PATHS.Replay)
local BoostPerformance = loadModule(MODULE_PATHS.BoostPerformance)
local AutoPick = loadModule(MODULE_PATHS.AutoPick)
local RestartAfterWaves = loadModule(MODULE_PATHS.RestartAfterWaves)
local RestartIfMissingModifier = loadModule(MODULE_PATHS.RestartIfMissingModifier)
local AutoJoinGrandPrix = loadModule(MODULE_PATHS.AutoJoinGrandPrix)
local AutoHorseRacing = loadModule(MODULE_PATHS.AutoHorseRacing)
local AutoTrialOfTheSaint = loadModule(MODULE_PATHS.AutoTrialOfTheSaint)

-- [START] Chỉ khi import xong mới dọn phiên cũ, tránh trùng worker/GUI.
if type(env.LotusHubUI) == "table" and type(env.LotusHubUI.Destroy) == "function" then
    pcall(function() env.LotusHubUI:Destroy() end)
end
local playerGui = player:WaitForChild("PlayerGui")
local leftoverGui = playerGui:FindFirstChild("LotusHub_Gameplay_UI_Demo")
if leftoverGui then leftoverGui:Destroy() end

pcall(function()
    local cg = game:GetService("CoreGui")
    local cgGui = cg and cg:FindFirstChild("LotusHub_Gameplay_UI_Demo")
    if cgGui then cgGui:Destroy() end
end)

pcall(function()
    if type(gethui) == "function" then
        local h = gethui()
        local hGui = h and h:FindFirstChild("LotusHub_Gameplay_UI_Demo")
        if hGui then hGui:Destroy() end
    end
end)

-- Xóa sạch hoàn toàn các file config và autoload cũ để chống tự động bật cheat
if type(delfile) == "function" and type(isfile) == "function" then
    pcall(function()
        if isfile("LotusHub_Config.json") then delfile("LotusHub_Config.json") end
        if isfile("LotusHub_Autoload.lua") then delfile("LotusHub_Autoload.lua") end
    end)
elseif type(writefile) == "function" then
    pcall(writefile, "LotusHub_Config.json", "{}")
end

local function setupAutoReloadOnTeleport(ctx, player)
    local queueteleport = (type(queue_on_teleport) == "function" and queue_on_teleport)
        or (syn and type(syn.queue_on_teleport) == "function" and syn.queue_on_teleport)
        or (fluxus and type(fluxus.queue_on_teleport) == "function" and fluxus.queue_on_teleport)

    if not queueteleport then return end

    local reloadPayload = [[
        task.spawn(function()
            if not game:IsLoaded() then
                game.Loaded:Wait()
            end
            local Players = game:GetService("Players")
            local lp = Players.LocalPlayer or Players.PlayerAdded:Wait()
            lp:WaitForChild("PlayerGui", 30)
            task.wait(0.5)

            local loaded = false

            -- 1. Ưu tiên đọc file cục bộ trong thư mục workspace của Executor
            if type(readfile) == "function" and type(loadstring) == "function" then
                local candidatePaths = {
                    "LotusHub_Autoload.lua",
                    "LotusHub/run_all_standalone.lua",
                    "run_all_standalone.lua",
                    "LotusHub/run_all.lua",
                    "run_all.lua",
                }
                for _, path in ipairs(candidatePaths) do
                    local ok, content = pcall(readfile, path)
                    if ok and type(content) == "string" and #content > 500 then
                        local fn, err = loadstring(content, "@" .. path)
                        if fn then
                            local runOk = pcall(fn)
                            if runOk then
                                loaded = true
                                break
                            end
                        end
                    end
                end
            end

            -- 2. Dự phòng: Nếu dán script trực tiếp không lưu file, nạp qua GitHub raw (chuẩn Infinite Yield)
            if not loaded and type(game.HttpGet) == "function" and type(loadstring) == "function" then
                local githubUrls = {
                    "https://raw.githubusercontent.com/BaroGITHU/LotusHub/Bao/run_all_standalone.lua",
                    "https://raw.githubusercontent.com/BaroGITHU/LotusHub/main/run_all_standalone.lua",
                }
                for _, url in ipairs(githubUrls) do
                    local ok, content = pcall(function() return game:HttpGet(url) end)
                    if ok and type(content) == "string" and #content > 500 then
                        local fn = loadstring(content, "@GitHub_LotusHub")
                        if fn then
                            local runOk = pcall(fn)
                            if runOk then
                                loaded = true
                                break
                            end
                        end
                    end
                end
            end
        end)
    ]]

    if type(writefile) == "function" and type(readfile) == "function" then
        pcall(function()
            for _, p in ipairs({"LotusHub/run_all_standalone.lua", "run_all_standalone.lua", "LotusHub/run_all.lua", "run_all.lua"}) do
                local ok, code = pcall(readfile, p)
                if ok and type(code) == "string" and #code > 500 then
                    writefile("LotusHub_Autoload.lua", code)
                    break
                end
            end
        end)
    end

    -- Đăng ký queueteleport ngay lập tức (phòng trường hợp OnTeleport bị bỏ lỡ)
    pcall(queueteleport, reloadPayload)

    -- Đăng ký lắng nghe sự kiện OnTeleport chuẩn Infinite Yield (kết nối trực tiếp, không phụ thuộc ctx)
    local teleportCheck = false
    Players.LocalPlayer.OnTeleport:Connect(function(state)
        if not teleportCheck and queueteleport then
            teleportCheck = true
            pcall(queueteleport, reloadPayload)
        end
    end)
end

local ctx = {
    env = env,
    playerGui = playerGui,
    state = {
        AutoStartgame = false,
        AutoActiveAutoPlay = false,
    },
    expanded = {},
    knownModifiers = {},
    ModifierConfig = ModifierConfig,
    connections = {},
    alive = true,
    screen = nil,
    SaveConfig = function() end,
}

-- Đăng ký listener để dọn sạch khi đóng UI hoặc Execute lại.
function ctx:Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(self.connections, connection)
    return connection
end

function ctx:Destroy()
    if not self.alive then return end
    self.alive = false -- Ngăn worker Match thực hiện thao tác mới.
    for _, connection in ipairs(self.connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(self.connections)
    if self.screen then
        pcall(function() self.screen:Destroy() end)
        self.screen = nil
    end
    if self.env.LotusHubUI == self.ui then self.env.LotusHubUI = nil end
end

-- [GẮN MODULE] Lần lượt tạo UI, đăng ký Gameplay, Modifiers & Gamemode, nối Match, Replay, Boost, AutoPick, Restart, GrandPrix.
local ok, err = pcall(function()
    local ui = Menu.Create(ctx)
    ctx.ui = ui
    ModifierConfig.Init(ctx, ui)
    Gameplay.Init(ctx, ui)
    Modifiers.Init(ctx, ui)
    Gamemode.Init(ctx, ui)
    Match.Init(ctx, ui)
    Replay.Init(ctx, ui)
    BoostPerformance.Init(ctx, ui)
    AutoPick.Init(ctx, ui)
    RestartAfterWaves.Init(ctx, ui)
    RestartIfMissingModifier.Init(ctx, ui)
    AutoJoinGrandPrix.Init(ctx, ui)
    AutoHorseRacing.Init(ctx, ui)
    AutoTrialOfTheSaint.Init(ctx, ui)
    env.LotusHubUI = ui -- API tương thích bản cũ.
    ui:ShowTab("Gameplay")
    setupAutoReloadOnTeleport(ctx, player)
end)

if not ok then
    ctx:Destroy()
    error("[LotusHub] Khởi động thất bại: " .. tostring(err))
end

print("[LotusHub Modular] Đã nạp thành công: Menu + Gameplay + Modifiers + Gamemode (Grand Prix & Trail Of The Saint).")
