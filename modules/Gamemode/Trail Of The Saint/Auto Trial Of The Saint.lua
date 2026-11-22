--[[
    LotusHub / modules/Gamemode/Trail Of The Saint/Auto Trial Of The Saint.lua
    Chức năng: Auto Trial Of The Saint (Chế độ Thử thách Thánh nhân).
    Bao gồm bảng chọn giữa 2 ending:
      1. True ending
      2. Secret ending (Secret endinh)
    Hiện tại khởi tạo giao diện và state, sẵn sàng nạp logic khi có raw.
]]
local AutoTrialOfTheSaint = {}

function AutoTrialOfTheSaint.Init(ctx, ui)
    local state = ctx.state

    if state.AutoTrialOfTheSaint == nil then
        state.AutoTrialOfTheSaint = false
    end

    if type(state.TrialEndings) ~= "table" then
        state.TrialEndings = {
            ["True ending"] = false,
            ["Secret ending"] = false,
        }
    end

    local function log(message)
        print("[LotusHub TrialOfTheSaint] " .. message)
    end

    if type(ui.SetToggleHandler) == "function" then
        ui:SetToggleHandler("AutoTrialOfTheSaint", function(enabled)
            log("AutoTrialOfTheSaint = " .. tostring(enabled))
        end)
    end
end

return AutoTrialOfTheSaint