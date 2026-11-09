--loadstring(readfile("LotusHub/run_all.lua"))()
--[[
    LOTUSHUB MODULAR / run_all.lua — FILE KHỞI ĐỘNG DUY NHẤT.

    Import lần lượt: Menu.lua => Gameplay.lua => Gameplay/Match.lua.
    Các module không phải Script/ModuleScript Roblox; đây là file .lua
    trên ổ lưu trữ executor, nạp bằng loadstring(readfile(...)).
    Nếu executor KHÔNG hỗ trợ readfile, dùng run_all_standalone.lua.

    GIỮ CẤU TRÚC ZIP:
      LotusHub/run_all.lua
      LotusHub/modules/Menu.lua
      LotusHub/modules/Gameplay.lua
      LotusHub/modules/Gameplay/Match.lua
]]

local env = ((type(getgenv) == "function") and getgenv()) or _G
local Players = game:GetService("Players")
local player = Players.LocalPlayer
if not player then error("[LotusHub] LocalPlayer chưa sẵn sàng") end

-- Chỉ nạp các module trong danh sách, không tải mã bên ngoài.
local MODULE_PATHS = {
    Menu = "modules/Menu.lua",
    Gameplay = "modules/Gameplay.lua",
    Match = "modules/Gameplay/Match.lua",
    Replay = "modules/Gameplay/Replay.lua",
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
local Gameplay = loadModule(MODULE_PATHS.Gameplay)
local Match = loadModule(MODULE_PATHS.Match)
local Replay = loadModule(MODULE_PATHS.Replay)

-- [START] Chỉ khi import xong mới dọn phiên cũ, tránh trùng worker/GUI.
if type(env.LotusHubUI) == "table" and type(env.LotusHubUI.Destroy) == "function" then
    pcall(function() env.LotusHubUI:Destroy() end)
end
local playerGui = player:WaitForChild("PlayerGui")
local leftoverGui = playerGui:FindFirstChild("LotusHub_Gameplay_UI_Demo")
if leftoverGui then leftoverGui:Destroy() end

local ctx = {
    env = env,
    playerGui = playerGui,
    state = {},
    expanded = {},
    knownModifiers = {}, -- MISSING: không tự bịa modifier.
    connections = {},
    alive = true,
    screen = nil,
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

-- [GẮN MODULE] Lần lượt tạo UI, đăng ký Gameplay, nối Match vào toggle.
local ok, err = pcall(function()
    local ui = Menu.Create(ctx)
    ctx.ui = ui
    Gameplay.Init(ctx, ui)
    Match.Init(ctx, ui)
    Replay.Init(ctx, ui)
    env.LotusHubUI = ui -- API tương thích bản cũ.
    ui:ShowTab("Gameplay")
end)

if not ok then
    ctx:Destroy()
    error("[LotusHub] Khởi động thất bại: " .. tostring(err))
end

print("[LotusHub Modular] Đã nạp Menu + Gameplay + Match V3 + Replay. Các tính năng khác chỉ là UI.")
