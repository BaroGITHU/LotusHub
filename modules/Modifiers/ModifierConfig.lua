--[[
    LotusHub / modules/Modifiers/ModifierConfig.lua
    Bảng dữ liệu danh sách Modifiers (Buff, Debuff, Mechanics) của Anime Vanguards.
    Nguồn: Trích xuất trực tiếp từ raw source Auto Pick Modifiers do người dùng cung cấp.
]]
local ModifierConfig = {}

-- [1] DANH SÁCH TOÀN BỘ 45 MODIFIERS ĐƯỢC PHÂN THEO BẬC ƯU TIÊN MẶC ĐỊNH
ModifierConfig.List = {
    -- Top Buff / Kinh tế (Điểm rất cao: 90 - 100)
    { Name = "Money Surge", Priority = 100, Desc = "+40% Yen from waves and Farms" },
    { Name = "High Class", Priority = 100, Desc = "Start with 10k Yen, +40% income" },
    { Name = "Harvest", Priority = 95, Desc = "+100% event currency" },
    { Name = "Gluttony", Priority = 95, Desc = "Farms pay out a second time" },
    { Name = "Monarch", Priority = 90, Desc = "Monarch trait for one unit" },
    { Name = "Damage", Priority = 85, Desc = "Boosts unit damage" },
    { Name = "Cooldown", Priority = 85, Desc = "Lowers unit SPA" },
    { Name = "Press It", Priority = 80, Desc = "-50% active ability cooldown" },
    { Name = "Uncommon Loot", Priority = 80, Desc = "2 random uncommon buffs" },
    { Name = "Common Loot", Priority = 75, Desc = "3 random common buffs" },
    { Name = "Range", Priority = 75, Desc = "Boosts unit range" },
    { Name = "Slayer", Priority = 75, Desc = "More damage to bosses" },
    { Name = "Lifeline", Priority = 70, Desc = "+1 Life Stock every 5 waves" },
    { Name = "Tyrant Destroyer", Priority = 70, Desc = "Friezo spawns at half health" },
    { Name = "Sphere Finder", Priority = 70, Desc = "Start with 2 Spheres" },
    { Name = "New Unit", Priority = 70, Desc = "Adds a unit to your hotbar" },
    { Name = "Sloth", Priority = 65, Desc = "Enemies move 30% slower" },

    -- Cơ chế đổi độ khó / Trung bình (Điểm vừa: 30 - 60)
    { Name = "Champions", Priority = 60, Desc = "Mini-bosses, +75% event currency" },
    { Name = "Fast", Priority = 60, Desc = "More Fast cards, more currency" },
    { Name = "Strong", Priority = 55, Desc = "More Strong cards, more currency" },
    { Name = "Dodge", Priority = 50, Desc = "More Dodge cards, more currency" },
    { Name = "Fisticuffs", Priority = 50, Desc = "-40% range, +200% damage" },
    { Name = "Precise Attack", Priority = 45, Desc = "+150% damage, +100% SPA" },
    { Name = "Planning Ahead", Priority = 40, Desc = "+150% range, -50% damage" },
    { Name = "Limit Break", Priority = 40, Desc = "2x placement cap, smaller discounts" },
    { Name = "No Trait No Problem", Priority = 40, Desc = "No traits, 2x placement cap" },
    { Name = "King's Burden", Priority = 35, Desc = "Monarch for all units, -40% Yen" },
    { Name = "Warding off Evil", Priority = 35, Desc = "Resist debuffs with Cursed Objects" },
    { Name = "Tyrant Arrives", Priority = 30, Desc = "First slot only, free placements" },
    { Name = "Greed", Priority = 30, Desc = "Upgraded unit becomes greedy" },
    { Name = "Lust", Priority = 30, Desc = "Selling upgraded unit refunds full" },
    { Name = "Wrath", Priority = 30, Desc = "Hits trigger wrath damage" },

    -- Debuff bất lợi / Né nhặt (Điểm thấp: 1 - 15)
    { Name = "Pride", Priority = 15, Desc = "Only 1 unit placed at a time" },
    { Name = "Envy", Priority = 10, Desc = "Strongest unit loses 30% stats" },
    { Name = "Nightmare Boss", Priority = 10, Desc = "Story boss mechanic" },
    { Name = "Nightmare Armor", Priority = 10, Desc = "-20% damage to enemies" },
    { Name = "Nightmare Health", Priority = 10, Desc = "+100% enemy HP" },
    { Name = "Nightmare Speed", Priority = 10, Desc = "+50% enemy speed" },
    { Name = "Nightmare Weakness", Priority = 10, Desc = "-20% unit damage" },
    { Name = "Regen", Priority = 5, Desc = "Enemies regenerate health" },
    { Name = "Revitalize", Priority = 5, Desc = "Enemies heal nearby on death" },
    { Name = "Shielded", Priority = 5, Desc = "Damage shield on enemies" },
    { Name = "Immunity", Priority = 3, Desc = "Immune to Slow & Stun" },
    { Name = "Thrice", Priority = 3, Desc = "Enemies split on death" },
    { Name = "Drowsy", Priority = 2, Desc = "Your units attack slower" },
    { Name = "Exploding", Priority = 2, Desc = "Explode on death, stunning units" },
    { Name = "Quake", Priority = 1, Desc = "Periodically stuns your units" },
}

-- [2] TẠO MAP TRA CỨU ĐIỂM ƯU TIÊN MẶC ĐỊNH (KEY VIẾT THƯỜNG)
function ModifierConfig.GetDefaultPriorityMap()
    local lookup = {}
    for _, item in ipairs(ModifierConfig.List) do
        lookup[string.lower(item.Name)] = item.Priority
    end
    return lookup
end

-- [3] HÀM CHUẨN HÓA TÊN THẺ (LỌC RICHTEXT/HTML, SỐ LA MÃ & SỐ THƯỜNG)
function ModifierConfig.NormalizeCardName(rawText, priorityLookup)
    if type(rawText) ~= "string" then return "", -1 end
    -- Bỏ thẻ HTML/RichText và khoảng trắng thừa
    local text = rawText:gsub("<[^>]+>", ""):match("^%s*(.-)%s*$") or ""

    -- Tách số La Mã (I, II, III, IV, V, VI, VII, VIII, IX, X...) hoặc số thường ở cuối tên thẻ
    local baseName = text:gsub("%s+[IVXLCDM]+$", ""):gsub("%s+%d+$", "")
    baseName = baseName:match("^%s*(.-)%s*$") or baseName

    local lowerBase = string.lower(baseName)
    local score = priorityLookup and priorityLookup[lowerBase]

    return baseName, (score or -1)
end

-- [4] LẤY DANH SÁCH MODIFIER ĐÃ SẮP XẾP THEO ĐIỂM ƯU TIÊN (HỖ TRỢ TÌM KIẾM)
function ModifierConfig.GetSortedList(priorityOverrides, query)
    local results = {}
    local q = (type(query) == "string" and string.lower(query):match("^%s*(.-)%s*$")) or ""

    for _, item in ipairs(ModifierConfig.List) do
        local nameLower = string.lower(item.Name)
        local descLower = string.lower(item.Desc)

        if q == "" or nameLower:find(q, 1, true) or descLower:find(q, 1, true) then
            local currentPriority = item.Priority
            if priorityOverrides and priorityOverrides[item.Name] ~= nil then
                currentPriority = tonumber(priorityOverrides[item.Name]) or item.Priority
            end

            table.insert(results, {
                Name = item.Name,
                Priority = currentPriority,
                Desc = item.Desc,
            })
        end
    end

    table.sort(results, function(a, b)
        if a.Priority == b.Priority then
            return a.Name < b.Name
        end
        return a.Priority > b.Priority
    end)

    return results
end

-- [5] HÀM KHỞI TẠO TƯƠNG THÍCH VỚI LOADMODULE CỦA LOTUSHUB
function ModifierConfig.Init(ctx, ui)
    if ctx then
        ctx.ModifierConfig = ModifierConfig
    end
end

return ModifierConfig