--[[
    LotusHub / modules/Gamemode/Grand Prix/Auto join Grand Prix.lua
    Chức năng: Tự động nhận diện và xác nhận tham gia Grand Prix (Auto Confirm Mount Picker).
    Nguồn: Trích xuất từ raw Grand Prix Engine do người dùng cung cấp.
]]
local AutoJoinGrandPrix = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

function AutoJoinGrandPrix.Init(ctx, ui)
    local player = Players.LocalPlayer
    local playerGui = ctx.playerGui or (player and player:WaitForChild("PlayerGui"))
    local state = ctx.state

    if state.AutoJoinGrandPrix == nil then
        state.AutoJoinGrandPrix = false
    end

    local lastConfirmed = 0

    local function log(message)
        print("[LotusHub GrandPrix] " .. message)
    end

    -- Kiểm tra và tự động bấm nút Confirm trong GrandPrixMountPicker
    local function checkMountPicker()
        if not ctx.alive or state.AutoJoinGrandPrix ~= true then return end

        local grandPrixGui = playerGui:FindFirstChild("GrandPrix")
        if not grandPrixGui then return end

        local mountPicker = grandPrixGui:FindFirstChild("GrandPrixMountPicker", true)
        if not mountPicker then return end

        local confirmGroup = mountPicker:FindFirstChild("Confirm", true)
        local confirmBtn = nil

        if confirmGroup then
            local clickable = confirmGroup:FindFirstChild("Clickable", true)
            if clickable and clickable:IsA("TextButton") then
                confirmBtn = clickable
            end
        end

        if not confirmBtn then
            local buyGroup = mountPicker:FindFirstChild("Buy", true)
            if buyGroup then
                local clickable = buyGroup:FindFirstChild("Clickable", true)
                if clickable and clickable:IsA("TextButton") then
                    confirmBtn = clickable
                end
            end
        end

        -- Nhận diện và click khi nút xuất hiện trên màn hình
        if confirmBtn and confirmBtn.AbsoluteSize.X > 10 and confirmBtn.AbsoluteSize.Y > 10 then
            if tick() - lastConfirmed > 1.2 then
                lastConfirmed = tick()

                if type(firesignal) == "function" then
                    pcall(function() firesignal(confirmBtn.MouseButton1Down) end)
                    pcall(function() firesignal(confirmBtn.MouseButton1Click) end)
                    pcall(function() firesignal(confirmBtn.MouseButton1Up) end)
                    pcall(function() firesignal(confirmBtn.Activated) end)
                end

                if VirtualInputManager then
                    local center = confirmBtn.AbsolutePosition + (confirmBtn.AbsoluteSize / 2)
                    pcall(function()
                        VirtualInputManager:SendMouseButtonEvent(math.floor(center.X), math.floor(center.Y), 0, true, game, 0)
                        task.wait(0.04)
                        VirtualInputManager:SendMouseButtonEvent(math.floor(center.X), math.floor(center.Y), 0, false, game, 0)
                    end)
                end

                log("Đã bấm Confirm Mount Picker -> Tham gia Grand Prix thành công!")
            end
        end
    end

    -- Worker chạy ngầm kiểm tra định kỳ (chu kỳ 0.5s, ngắt sạch khi ctx.alive = false)
    task.spawn(function()
        while ctx.alive do
            task.wait(0.5)
            if state.AutoJoinGrandPrix == true then
                checkMountPicker()
            end
        end
        log("Worker AutoJoinGrandPrix đã dừng an toàn do ctx.alive = false.")
    end)

    if type(ui.SetToggleHandler) == "function" then
        ui:SetToggleHandler("AutoJoinGrandPrix", function(enabled)
            log("AutoJoinGrandPrix = " .. tostring(enabled))
            if enabled then
                lastConfirmed = 0
                task.spawn(checkMountPicker)
            end
        end)
    end
end

return AutoJoinGrandPrix