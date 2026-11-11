--[[
    LotusHub / modules/Modifiers/Restart/Restart.lua — Quản lý module Restart (con của Modifiers).
    Bao gồm 2 tính năng:
      1. Auto Restart After Waves (có thanh giá trị slider để chọn số Wave)
      2. Auto Restart If Don't Have Modifier (hiện bảng Modifier để chọn các Modifier mong muốn)
]]
local Restart = {}

function Restart.Init(ctx, ui)
    -- Nạp các module thành phần
    local ok1, m1 = pcall(function()
        return loadstring(readfile("LotusHub/modules/Modifiers/Restart/RestartAfterWaves.lua"))()
    end)
    if ok1 and type(m1) == "table" and type(m1.Init) == "function" then
        m1.Init(ctx, ui)
    end

    local ok2, m2 = pcall(function()
        return loadstring(readfile("LotusHub/modules/Modifiers/Restart/RestartIfMissingModifier.lua"))()
    end)
    if ok2 and type(m2) == "table" and type(m2.Init) == "function" then
        m2.Init(ctx, ui)
    end
end

return Restart
