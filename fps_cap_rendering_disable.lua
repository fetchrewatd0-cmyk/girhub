local duration = 60  -- 1 minute in seconds
local startTime = tick()

-- FPS Cap Loop
while tick() - startTime < duration do
    setfpscap(15)
    task.wait(0.1)
end

print("1 minute loop complete!")

-- RENDERING DISABLE (Proper Implementation)
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

-- Apply settings multiple times with delays
local function applyRenderingSettings()
    -- Set rendering settings
    pcall(function()
        local rendering = settings().Rendering
        rendering.QualityLevel = Enum.QualityLevel.Level01
        rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
        rendering.EditQualityLevel = Enum.QualityLevel.Level01
    end)
    
    -- Set UserSettings quality
    pcall(function()
        local userSettings = UserSettings()
        local gameSettings = userSettings:GetService("UserGameSettings")
        gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    end)
    
    -- Set Lighting settings
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.ShadowSoftness = 0
        Lighting.FogEnd = 9000000000
        Lighting.Technology = Enum.Technology.Legacy
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
    end)
    
    -- Set Terrain settings
    pcall(function()
        local terrain = workspace.Terrain
        terrain.Decoration = false
        terrain.WaterWaveSize = 0
        terrain.WaterWaveSpeed = 0
        terrain.WaterReflectance = 0
        terrain.WaterTransparency = 1
    end)
end

-- Disable visual effects on all parts
local function disableVisuals(obj)
    if not obj or not obj.Parent then return end
    
    pcall(function()
        if obj:IsA("ParticleEmitter") then
            obj.Enabled = false
            obj.Rate = 0
        elseif obj:IsA("Trail") or obj:IsA("Beam") then
            obj.Enabled = false
        elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
            obj.Enabled = false
            obj.Brightness = 0
        elseif obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            obj.Enabled = false
        elseif obj:IsA("Explosion") then
            obj.Visible = false
        elseif obj:IsA("SpecialMesh") then
            obj.TextureId = ""
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            if not (obj.Name == "face" and obj.Parent and obj.Parent.Name == "Head") then
                obj.Transparency = 1
            end
        elseif obj:IsA("MeshPart") then
            obj.RenderFidelity = Enum.RenderFidelity.Performance
            obj.TextureID = ""
            obj.CastShadow = false
            obj.Reflectance = 0
            obj.Material = Enum.Material.SmoothPlastic
        elseif obj:IsA("BasePart") then
            obj.CastShadow = false
            obj.Reflectance = 0
            obj.Material = Enum.Material.SmoothPlastic
        elseif obj:IsA("PostEffect") then
            obj.Enabled = false
        elseif obj:IsA("Clouds") then
            obj.Cover = 0
            obj.Density = 0
        elseif obj:IsA("Atmosphere") then
            obj.Density = 0
            obj.Haze = 0
            obj.Glare = 0
        end
    end)
end

-- Apply settings immediately
applyRenderingSettings()

-- Process existing descendants
task.spawn(function()
    task.wait(0.5)
    for _, descendant in pairs(workspace:GetDescendants()) do
        disableVisuals(descendant)
    end
    
    for _, descendant in pairs(Lighting:GetDescendants()) do
        disableVisuals(descendant)
    end
    
    -- Reapply rendering settings after processing descendants
    task.wait(0.5)
    applyRenderingSettings()
end)

-- Hook new descendants
workspace.DescendantAdded:Connect(function(descendant)
    disableVisuals(descendant)
end)

Lighting.DescendantAdded:Connect(function(descendant)
    disableVisuals(descendant)
end)

-- Reapply settings every 2 seconds to maintain them
task.spawn(function()
    while true do
        task.wait(2)
        applyRenderingSettings()
    end
end)

print("Rendering disabled + FPS capped to 15!")
