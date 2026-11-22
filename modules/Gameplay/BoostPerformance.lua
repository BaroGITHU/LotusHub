--[[
    LOTUSHUB / modules/Gameplay/BoostPerformance.lua
    ================================================
    Module tối ưu hóa hiệu năng và tốc độ khung hình (Boost FPS).
    
    CHỨC NĂNG A: FreeFire Graphics (Boost FPS)
      Khi ON:
        1) Tối ưu engine kết xuất: settings().Rendering.QualityLevel = 1.
        2) Tắt GlobalShadows, sương mù FogEnd/FogStart = 9e9 trong Lighting.
        3) Vô hiệu hóa Bloom, Blur, DepthOfField, SunRays, ColorCorrection, Atmosphere và mọi PostEffect.
        4) Tắt hiệu ứng hạt ParticleEmitter (Lifetime = 0, Enabled = false), Trail, Beam, Fire, Smoke, Sparkles, Highlight.
        5) Loại bỏ texture của MeshPart (TextureID = "") và SpecialMesh (TextureId = ""), đưa toàn bộ vật thể về phong cách đồ họa phẳng mượt (Plastic) tối giản chuẩn Free Fire.
        6) Tắt CastShadow, Reflectance = 0 trên toàn bộ BasePart, ẩn Decal/Texture.
        7) Tắt Terrain Decoration (cỏ 3D) và làm phẳng sóng nước Terrain.
        8) Lắng nghe Workspace.DescendantAdded để tự động tối ưu quái vật và kỹ năng mới sinh ra trong trận.
      Khi OFF:
        Khôi phục 100% toàn bộ thuộc tính, texture, hiệu ứng và cài đặt gốc đã lưu.

    CHỨC NĂNG B: Delete Map
      Ẩn toàn bộ chi tiết hình học của map trong Workspace (giữ nguyên va chạm để không rơi xuống void).

    CHỨC NĂNG C: Delete Entities
      Ẩn toàn bộ quái/thực thể trong Workspace.
]]
local BoostPerformance = {}

function BoostPerformance.Init(ctx, ui)
    local state = ctx.state
    local playerGui = ctx.playerGui
    local Lighting = game:GetService("Lighting")
    local Workspace = game:GetService("Workspace")
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

    local session = {
        active = false,
        listenerConnection = nil,
    }

    -- Bảng lưu trữ trạng thái gốc để khôi phục khi OFF
    local savedState = {
        qualityLevel = nil,
        lighting = {},
        terrain = {},
        postEffects = {},         -- [instance] = originalEnabled
        emitters = {},            -- [instance] = { Enabled, Lifetime }
        trails = {},              -- [instance] = originalEnabled
        beams = {},               -- [instance] = originalEnabled
        miscEffects = {},         -- [instance] = originalEnabled (Fire, Smoke, Sparkles, Highlight)
        castShadows = {},         -- [part] = originalCastShadow
        materials = {},           -- [part] = originalMaterial
        reflectance = {},         -- [part] = originalReflectance
        decals = {},              -- [decal] = originalTransparency
        meshTextures = {},        -- [meshPart] = originalTextureID
        specialMeshTextures = {}, -- [specialMesh] = originalTextureId
    }

    local function log(message)
        print("[LotusHub BoostPerformance] " .. message)
    end

    -- [1] TỐI ƯU HÓA POST-EFFECT TRONG LIGHTING VÀ CAMERA
    local function optimizePostEffect(obj)
        if not obj then return end
        if obj:IsA("PostEffect") or obj:IsA("BloomEffect") or obj:IsA("BlurEffect")
            or obj:IsA("DepthOfFieldEffect") or obj:IsA("SunRaysEffect")
            or obj:IsA("ColorCorrectionEffect") or obj:IsA("Atmosphere") then
            if savedState.postEffects[obj] == nil then
                pcall(function()
                    savedState.postEffects[obj] = obj.Enabled
                    obj.Enabled = false
                end)
            end
        end
    end

    -- [2] TỐI ƯU HÓA TỪNG INSTANCE ĐỐI TƯỢNG TRONG WORKSPACE
    local function optimizeInstance(inst)
        if not inst or not inst.Parent then return end

        -- Bỏ qua GUI hiển thị của người chơi
        if inst:IsDescendantOf(playerGui) then return end

        -- Bỏ qua nhân vật của chính người chơi để không làm hỏng avatar
        local char = player.Character
        if char and inst:IsDescendantOf(char) then return end

        -- A. Hiệu ứng hạt và ánh sáng động
        if inst:IsA("ParticleEmitter") then
            if savedState.emitters[inst] == nil then
                savedState.emitters[inst] = {
                    Enabled = inst.Enabled,
                    Lifetime = inst.Lifetime,
                }
                inst.Enabled = false
                pcall(function() inst.Lifetime = NumberRange.new(0) end)
            end
        elseif inst:IsA("Trail") then
            if savedState.trails[inst] == nil then
                savedState.trails[inst] = inst.Enabled
                inst.Enabled = false
            end
        elseif inst:IsA("Beam") then
            if savedState.beams[inst] == nil then
                savedState.beams[inst] = inst.Enabled
                inst.Enabled = false
            end
        elseif inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") or inst:IsA("Highlight") then
            if savedState.miscEffects[inst] == nil then
                savedState.miscEffects[inst] = inst.Enabled
                inst.Enabled = false
            end
        -- B. Giảm chi tiết hình học của vật thể & loại bỏ texture chuẩn Free Fire
        elseif inst:IsA("MeshPart") then
            if inst.CastShadow and savedState.castShadows[inst] == nil then
                savedState.castShadows[inst] = inst.CastShadow
                inst.CastShadow = false
            end
            if inst.Material ~= Enum.Material.Plastic then
                if savedState.materials[inst] == nil then
                    savedState.materials[inst] = inst.Material
                    inst.Material = Enum.Material.Plastic
                end
            end
            if inst.Reflectance ~= 0 then
                if savedState.reflectance[inst] == nil then
                    savedState.reflectance[inst] = inst.Reflectance
                    inst.Reflectance = 0
                end
            end
            if inst.TextureID ~= "" then
                if savedState.meshTextures[inst] == nil then
                    savedState.meshTextures[inst] = inst.TextureID
                    inst.TextureID = ""
                end
            end
        elseif inst:IsA("SpecialMesh") then
            if inst.TextureId ~= "" then
                if savedState.specialMeshTextures[inst] == nil then
                    savedState.specialMeshTextures[inst] = inst.TextureId
                    inst.TextureId = ""
                end
            end
        elseif inst:IsA("BasePart") then
            if inst.CastShadow and savedState.castShadows[inst] == nil then
                savedState.castShadows[inst] = inst.CastShadow
                inst.CastShadow = false
            end
            if inst.Material ~= Enum.Material.Plastic then
                if savedState.materials[inst] == nil then
                    savedState.materials[inst] = inst.Material
                    inst.Material = Enum.Material.Plastic
                end
            end
            if inst.Reflectance ~= 0 then
                if savedState.reflectance[inst] == nil then
                    savedState.reflectance[inst] = inst.Reflectance
                    inst.Reflectance = 0
                end
            end
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            if inst.Transparency < 1 and savedState.decals[inst] == nil then
                savedState.decals[inst] = inst.Transparency
                inst.Transparency = 1
            end
        end
    end

    -- [3] HÀM KÍCH HOẠT FREEFIRE GRAPHICS
    local function enableFreeFire()
        if session.active then return end
        session.active = true
        log("Đang áp dụng FreeFire Graphics (Boost FPS)...")

        -- 1. Engine Quality: Hạ chất lượng kết xuất xuống mức tối thiểu (Boost FPS tối đa)
        pcall(function()
            if savedState.qualityLevel == nil then
                savedState.qualityLevel = settings().Rendering.QualityLevel
            end
            settings().Rendering.QualityLevel = 1
        end)

        -- 2. Lighting: Tắt bóng đổ, khử sương mù & chuyển Compatibility mode nếu có hỗ trợ
        pcall(function()
            if savedState.lighting.GlobalShadows == nil then
                savedState.lighting.GlobalShadows = Lighting.GlobalShadows
                Lighting.GlobalShadows = false
            end
            if savedState.lighting.FogEnd == nil then
                savedState.lighting.FogEnd = Lighting.FogEnd
                Lighting.FogEnd = 9e9
            end
            if savedState.lighting.FogStart == nil then
                savedState.lighting.FogStart = Lighting.FogStart
                Lighting.FogStart = 9e9
            end
            pcall(function()
                if type(sethiddenproperty) == "function" then
                    savedState.lighting.Technology = Lighting.Technology
                    sethiddenproperty(Lighting, "Technology", 2)
                end
            end)
        end)

        -- 3. Lighting & Camera: Tắt toàn bộ Post-processing
        for _, child in ipairs(Lighting:GetChildren()) do
            optimizePostEffect(child)
        end
        local camera = Workspace.CurrentCamera
        if camera then
            for _, child in ipairs(camera:GetChildren()) do
                optimizePostEffect(child)
            end
        end

        -- 4. Terrain: Tắt cỏ 3D, làm phẳng sóng nước
        pcall(function()
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                if savedState.terrain.Decoration == nil then
                    savedState.terrain.Decoration = terrain.Decoration
                    terrain.Decoration = false
                    pcall(function()
                        if type(sethiddenproperty) == "function" then
                            sethiddenproperty(terrain, "Decoration", false)
                        end
                    end)
                end
                if savedState.terrain.WaterWaveSize == nil then
                    savedState.terrain.WaterWaveSize = terrain.WaterWaveSize
                    terrain.WaterWaveSize = 0
                end
                if savedState.terrain.WaterWaveSpeed == nil then
                    savedState.terrain.WaterWaveSpeed = terrain.WaterWaveSpeed
                    terrain.WaterWaveSpeed = 0
                end
                if savedState.terrain.WaterReflectance == nil then
                    savedState.terrain.WaterReflectance = terrain.WaterReflectance
                    terrain.WaterReflectance = 0
                end
                if savedState.terrain.WaterTransparency == nil then
                    savedState.terrain.WaterTransparency = terrain.WaterTransparency
                    terrain.WaterTransparency = 1
                end
            end
        end)

        -- 5. Quét toàn bộ Workspace hiện có theo từng đợt để không giật lag
        task.spawn(function()
            local descendants = Workspace:GetDescendants()
            for i, inst in ipairs(descendants) do
                if not session.active or not ctx.alive then break end
                pcall(optimizeInstance, inst)
                if i % 1000 == 0 then
                    task.wait()
                end
            end
            log("Đã áp dụng tối ưu toàn bộ Workspace.")
        end)

        -- 6. Lắng nghe DescendantAdded để tự động xử lý kỹ năng/quái vật mới
        if not session.listenerConnection then
            session.listenerConnection = Workspace.DescendantAdded:Connect(function(inst)
                if not session.active or not ctx.alive then return end
                pcall(optimizeInstance, inst)
            end)
            table.insert(ctx.connections, session.listenerConnection)
        end

        log("FreeFire Graphics: ĐÃ BẬT.")
    end

    -- [4] HÀM KHÔI PHỤC ĐỒ HỌA GỐC
    local function disableFreeFire()
        if not session.active then return end
        session.active = false
        log("Đang khôi phục đồ họa và hiệu ứng gốc...")

        -- 1. Ngắt kết nối lắng nghe
        if session.listenerConnection then
            pcall(function() session.listenerConnection:Disconnect() end)
            session.listenerConnection = nil
        end

        -- 2. Khôi phục Engine Quality
        pcall(function()
            if savedState.qualityLevel ~= nil then
                settings().Rendering.QualityLevel = savedState.qualityLevel
            end
        end)
        savedState.qualityLevel = nil

        -- 3. Khôi phục Lighting
        pcall(function()
            if savedState.lighting.GlobalShadows ~= nil then
                Lighting.GlobalShadows = savedState.lighting.GlobalShadows
            end
            if savedState.lighting.FogEnd ~= nil then
                Lighting.FogEnd = savedState.lighting.FogEnd
            end
            if savedState.lighting.FogStart ~= nil then
                Lighting.FogStart = savedState.lighting.FogStart
            end
            if savedState.lighting.Technology ~= nil and type(sethiddenproperty) == "function" then
                pcall(sethiddenproperty, Lighting, "Technology", savedState.lighting.Technology)
            end
        end)
        savedState.lighting = {}

        -- 4. Khôi phục PostEffects
        for obj, origEnabled in pairs(savedState.postEffects) do
            pcall(function()
                if obj and obj.Parent then
                    obj.Enabled = origEnabled
                end
            end)
        end
        savedState.postEffects = {}

        -- 5. Khôi phục Terrain
        pcall(function()
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                if savedState.terrain.Decoration ~= nil then
                    terrain.Decoration = savedState.terrain.Decoration
                    pcall(function()
                        if type(sethiddenproperty) == "function" then
                            sethiddenproperty(terrain, "Decoration", savedState.terrain.Decoration)
                        end
                    end)
                end
                if savedState.terrain.WaterWaveSize ~= nil then
                    terrain.WaterWaveSize = savedState.terrain.WaterWaveSize
                end
                if savedState.terrain.WaterWaveSpeed ~= nil then
                    terrain.WaterWaveSpeed = savedState.terrain.WaterWaveSpeed
                end
                if savedState.terrain.WaterReflectance ~= nil then
                    terrain.WaterReflectance = savedState.terrain.WaterReflectance
                end
                if savedState.terrain.WaterTransparency ~= nil then
                    terrain.WaterTransparency = savedState.terrain.WaterTransparency
                end
            end
        end)
        savedState.terrain = {}

        -- 6. Khôi phục ParticleEmitter, Trail, Beam, Fire, v.v.
        for obj, origData in pairs(savedState.emitters) do
            pcall(function()
                if obj and obj.Parent then
                    obj.Enabled = origData.Enabled
                    obj.Lifetime = origData.Lifetime
                end
            end)
        end
        savedState.emitters = {}

        for obj, origEnabled in pairs(savedState.trails) do
            pcall(function()
                if obj and obj.Parent then
                    obj.Enabled = origEnabled
                end
            end)
        end
        savedState.trails = {}

        for obj, origEnabled in pairs(savedState.beams) do
            pcall(function()
                if obj and obj.Parent then
                    obj.Enabled = origEnabled
                end
            end)
        end
        savedState.beams = {}

        for obj, origEnabled in pairs(savedState.miscEffects) do
            pcall(function()
                if obj and obj.Parent then
                    obj.Enabled = origEnabled
                end
            end)
        end
        savedState.miscEffects = {}

        -- 7. Khôi phục Texture của MeshPart & SpecialMesh
        for mesh, origTexture in pairs(savedState.meshTextures) do
            pcall(function()
                if mesh and mesh.Parent then
                    mesh.TextureID = origTexture
                end
            end)
        end
        savedState.meshTextures = {}

        for smesh, origTexture in pairs(savedState.specialMeshTextures) do
            pcall(function()
                if smesh and smesh.Parent then
                    smesh.TextureId = origTexture
                end
            end)
        end
        savedState.specialMeshTextures = {}

        -- 8. Khôi phục BasePart (CastShadow, Material & Reflectance)
        for part, origShadow in pairs(savedState.castShadows) do
            pcall(function()
                if part and part.Parent then
                    part.CastShadow = origShadow
                end
            end)
        end
        savedState.castShadows = {}

        for part, origMat in pairs(savedState.materials) do
            pcall(function()
                if part and part.Parent then
                    part.Material = origMat
                end
            end)
        end
        savedState.materials = {}

        for part, origRef in pairs(savedState.reflectance) do
            pcall(function()
                if part and part.Parent then
                    part.Reflectance = origRef
                end
            end)
        end
        savedState.reflectance = {}

        -- 9. Khôi phục Decals / Textures
        for decal, origTrans in pairs(savedState.decals) do
            pcall(function()
                if decal and decal.Parent then
                    decal.Transparency = origTrans
                end
            end)
        end
        savedState.decals = {}

        log("FreeFire Graphics: ĐÃ TẮT và khôi phục cài đặt gốc.")
    end

    -- [5] ĐĂNG KÝ TOGGLE HANDLER VỚI MENU
    ui:SetToggleHandler("FreeFireGraphics", function(enabled)
        if enabled then
            enableFreeFire()
        else
            disableFreeFire()
        end
    end)

    -- Khởi động nếu toggle đã bật sẵn từ trước
    if state.FreeFireGraphics == true then
        task.defer(enableFreeFire)
    end

    -- [6] ĐĂNG KÝ TOGGLE HANDLER CHO DELETE MAP
    local mapSaved = {}
    local function setMapDeleted(delete)
        for _, name in ipairs({"Map", "World", "Stage", "Environment", "Level"}) do
            local folder = Workspace:FindFirstChild(name)
            if folder then
                for _, part in ipairs(folder:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if delete then
                            if mapSaved[part] == nil then
                                mapSaved[part] = part.Transparency
                                part.Transparency = 1
                            end
                        else
                            if mapSaved[part] ~= nil then
                                part.Transparency = mapSaved[part]
                            end
                        end
                    end
                end
            end
        end
        if not delete then mapSaved = {} end
        log(delete and "Delete Map: ĐÃ BẬT (ẩn bản đồ)" or "Delete Map: ĐÃ TẮT (khôi phục bản đồ)")
    end

    ui:SetToggleHandler("DeleteMap", function(enabled)
        setMapDeleted(enabled)
    end)
    if state.DeleteMap == true then task.defer(function() setMapDeleted(true) end) end

    -- [7] ĐĂNG KÝ TOGGLE HANDLER CHO DELETE ENTITIES
    local entitiesSaved = {}
    local function setEntitiesDeleted(delete)
        for _, name in ipairs({"Enemies", "Mobs", "Entities", "Units"}) do
            local folder = Workspace:FindFirstChild(name)
            if folder then
                for _, part in ipairs(folder:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if delete then
                            if entitiesSaved[part] == nil then
                                entitiesSaved[part] = part.Transparency
                                part.Transparency = 1
                            end
                        else
                            if entitiesSaved[part] ~= nil then
                                part.Transparency = entitiesSaved[part]
                            end
                        end
                    end
                end
            end
        end
        if not delete then entitiesSaved = {} end
        log(delete and "Delete Entities: ĐÃ BẬT (ẩn thực thể)" or "Delete Entities: ĐÃ TẮT (khôi phục thực thể)")
    end

    ui:SetToggleHandler("DeleteEntities", function(enabled)
        setEntitiesDeleted(enabled)
    end)
    if state.DeleteEntities == true then task.defer(function() setEntitiesDeleted(true) end) end
end

return BoostPerformance
