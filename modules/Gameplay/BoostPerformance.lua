--[[
    LOTUSHUB / modules/Gameplay/BoostPerformance.lua
    ================================================
    Module tối ưu hóa hiệu năng và tốc độ khung hình (Boost FPS).
    
    CHỨC NĂNG A: FreeFire Graphics (Boost FPS)
      Khi ON:
        1) Tắt GlobalShadows trong Lighting.
        2) Vô hiệu hóa Bloom, Blur, DepthOfField, SunRays, ColorCorrection và các PostEffect.
        3) Tắt/giảm các hiệu ứng hạt ParticleEmitter, Trail, Beam, Fire, Smoke, Sparkles.
        4) Giảm chi tiết hiển thị: tắt CastShadow trên BasePart, chuyển Material sang SmoothPlastic,
           ẩn Decal/Texture nặng, tắt Terrain Decoration (cỏ 3D) và giảm sóng nước Terrain.
        5) Lắng nghe Workspace.DescendantAdded để tự động tối ưu quái vật và kỹ năng mới sinh ra trong trận.
      Khi OFF:
        Khôi phục toàn bộ các thuộc tính và trạng thái gốc đã lưu trước khi bật.
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
        lighting = {},
        terrain = {},
        postEffects = {},     -- [instance] = originalEnabled
        emitters = {},        -- [instance] = originalEnabled
        trails = {},          -- [instance] = originalEnabled
        beams = {},           -- [instance] = originalEnabled
        miscEffects = {},     -- [instance] = originalEnabled (Fire, Smoke, Sparkles)
        castShadows = {},     -- [part] = originalCastShadow
        materials = {},       -- [part] = originalMaterial
        decals = {},          -- [decal] = originalTransparency
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
                savedState.emitters[inst] = inst.Enabled
                inst.Enabled = false
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
        elseif inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
            if savedState.miscEffects[inst] == nil then
                savedState.miscEffects[inst] = inst.Enabled
                inst.Enabled = false
            end
        -- B. Giảm chi tiết hình học của vật thể
        elseif inst:IsA("BasePart") then
            if inst.CastShadow and savedState.castShadows[inst] == nil then
                savedState.castShadows[inst] = inst.CastShadow
                inst.CastShadow = false
            end
            if inst.Material ~= Enum.Material.SmoothPlastic and inst.Material ~= Enum.Material.Plastic then
                if savedState.materials[inst] == nil then
                    savedState.materials[inst] = inst.Material
                    inst.Material = Enum.Material.SmoothPlastic
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

        -- 1. Lighting: Tắt GlobalShadows
        pcall(function()
            if savedState.lighting.GlobalShadows == nil then
                savedState.lighting.GlobalShadows = Lighting.GlobalShadows
                Lighting.GlobalShadows = false
            end
        end)

        -- 2. Lighting & Camera: Tắt Post-processing
        for _, child in ipairs(Lighting:GetChildren()) do
            optimizePostEffect(child)
        end
        local camera = Workspace.CurrentCamera
        if camera then
            for _, child in ipairs(camera:GetChildren()) do
                optimizePostEffect(child)
            end
        end

        -- 3. Terrain: Tắt cỏ 3D và sóng nước
        pcall(function()
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                if savedState.terrain.Decoration == nil then
                    savedState.terrain.Decoration = terrain.Decoration
                    terrain.Decoration = false
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
            end
        end)

        -- 4. Quét toàn bộ Workspace hiện có theo từng đợt để không giật lag
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

        -- 5. Lắng nghe DescendantAdded để tự động xử lý kỹ năng/quái vật mới
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

        -- 2. Khôi phục Lighting
        pcall(function()
            if savedState.lighting.GlobalShadows ~= nil then
                Lighting.GlobalShadows = savedState.lighting.GlobalShadows
            end
        end)
        savedState.lighting = {}

        -- 3. Khôi phục PostEffects
        for obj, origEnabled in pairs(savedState.postEffects) do
            pcall(function()
                if obj and obj.Parent then
                    obj.Enabled = origEnabled
                end
            end)
        end
        savedState.postEffects = {}

        -- 4. Khôi phục Terrain
        pcall(function()
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                if savedState.terrain.Decoration ~= nil then
                    terrain.Decoration = savedState.terrain.Decoration
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
            end
        end)
        savedState.terrain = {}

        -- 5. Khôi phục ParticleEmitter, Trail, Beam, Fire, v.v.
        for obj, origEnabled in pairs(savedState.emitters) do
            pcall(function()
                if obj and obj.Parent then
                    obj.Enabled = origEnabled
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

        -- 6. Khôi phục BasePart (CastShadow & Material)
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

        -- 7. Khôi phục Decals / Textures
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
end

return BoostPerformance

