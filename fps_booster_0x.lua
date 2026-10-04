--== FPS Booster :: cap 15 for 60s then hold + rendering disable + prop strip ==--

if not game:IsLoaded() then game.Loaded:Wait() end

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Lighting          = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local CoreGui           = game:GetService("CoreGui")
local function safe(name, f) local ok, e = pcall(f) if not ok then warn("[FPS Booster] "..name.." failed: "..tostring(e)) end end
local UIS               = game:GetService("UserInputService")

--==================== [CONFIG] ====================--
local CONFIG = {
    FPS_CAP         = 15,     -- cap value
    MUTE_AUDIO      = true,   -- mute all sound
    REAPPLY_EVERY   = 2,      -- rendering re-apply interval
    STRIP_PROPS     = true,   -- destructive prop removal
    START_ON        = true,
    BLACK_SCREEN    = true,   -- 0x Optimiser: 3D rendering off + black screen (default ON)
    TOGGLE_KEY      = Enum.KeyCode.F5,
}

local RUNNING = CONFIG.START_ON

--==================== [1] FPS CAP — 60s then HOLD at 15] ====================--
local function capOnce()
    if CONFIG.FPS_CAP == nil then return end
    pcall(function() setfpscap(CONFIG.FPS_CAP) end)
end

-- Apply the cap a single time
capOnce()
print("[FPS Booster] FPS cap applied once:", CONFIG.FPS_CAP)

--==================== [1b] MUTE ALL AUDIO] ====================--
local SoundService = game:GetService("SoundService")
local savedVolume = SoundService.Volume
local savedMaster = 1
pcall(function() savedMaster = UserSettings():GetService("UserGameSettings").MasterVolume end)

local function muteSound(o)
    if o:IsA("Sound") then
        pcall(function() o.Volume = 0; o:Stop() end)
    end
end

local function muteAll()
    if not CONFIG.MUTE_AUDIO then return end
    pcall(function() SoundService.Volume = 0 end)
    pcall(function() UserSettings():GetService("UserGameSettings").MasterVolume = 0 end)
    for _, d in ipairs(game:GetDescendants()) do muteSound(d) end
end

local function unmuteAll()
    pcall(function() SoundService.Volume = savedVolume end)
    pcall(function() UserSettings():GetService("UserGameSettings").MasterVolume = savedMaster end)
end

game.DescendantAdded:Connect(function(d)
    if RUNNING and CONFIG.MUTE_AUDIO then muteSound(d) end
end)

--==================== [2] RENDERING SETTINGS] ====================--
local function applyRenderingSettings()
    pcall(function()
        local r = settings().Rendering
        r.QualityLevel = Enum.QualityLevel.Level01
        r.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
        r.EditQualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        local us = UserSettings()
        local gs = us:GetService("UserGameSettings")
        gs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    end)
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.ShadowSoftness = 0
        Lighting.FogEnd = 9000000000
        Lighting.Technology = Enum.Technology.Legacy
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
    end)
    pcall(function()
        local t = workspace.Terrain
        t.Decoration = false
        t.WaterWaveSize = 0
        t.WaterWaveSpeed = 0
        t.WaterReflectance = 0
        t.WaterTransparency = 1
    end)
end

--==================== [3] VISUAL DISABLE] ====================--
local function disableVisuals(obj)
    if not obj or not obj.Parent then return end
    pcall(function()
        if obj:IsA("ParticleEmitter") then
            obj.Enabled = false; obj.Rate = 0
        elseif obj:IsA("Trail") or obj:IsA("Beam") then
            obj.Enabled = false
        elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
            obj.Enabled = false; obj.Brightness = 0
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
            obj.Cover = 0; obj.Density = 0
        elseif obj:IsA("Atmosphere") then
            obj.Density = 0; obj.Haze = 0; obj.Glare = 0
        end
    end)
end

--==================== [4] PROP STRIP] ====================--
local function mapRoot()
    return workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
end

local KEEP = {
    __OBJECTS = true, World = true, AreaEggSlotsClient = true,
    Terrain = true, Camera = true, BossArena = true,
}

local function stripProps()
    if not CONFIG.STRIP_PROPS then return end

    local collisions = {}
    pcall(function()
        for _, c in ipairs(CollectionService:GetTagged("CollisionPart")) do
            collisions[c] = true
        end
    end)

    local function isProtected(inst)
        for c in pairs(collisions) do
            if c == inst or c:IsDescendantOf(inst) then return true end
        end
        return false
    end

    local function stripCount(inst)
        if inst == nil then return 0 end
        if not isProtected(inst) then
            local n = 0
            pcall(function() n = #inst:GetDescendants() + 1 end)
            pcall(function() inst:Destroy() end)
            return n
        end
        local n = 0
        for _, c in ipairs(inst:GetChildren()) do n += stripCount(c) end
        return n
    end

    local node = mapRoot()
    node = node and node:FindFirstChild("Build")
    node = node and node:FindFirstChild("Props")
    if node ~= nil then
        local n = stripCount(node)
        print(("[FPS] Removed Build.Props (%d instances)."):format(n))
    end

    task.spawn(function()
        local scanned = 0
        for _, child in ipairs(workspace:GetChildren()) do
            if KEEP[child.Name] or Players:GetPlayerFromCharacter(child) ~= nil then
                local ok, descs = pcall(function() return child:GetDescendants() end)
                for _, d in ipairs(ok and descs or {}) do
                    if not collisions[d] then disableVisuals(d) end
                end
            end
            scanned += 1
            if scanned % 500 == 0 then RunService.Heartbeat:Wait() end
        end
        print(("[FPS] Swept %d workspace roots."):format(scanned))
    end)
end

--==================== [5] INITIAL SWEEP] ====================--
local function fullSweep()
    muteAll()
    applyRenderingSettings()
    task.spawn(function()
        task.wait(0.5)
        for _, d in ipairs(workspace:GetDescendants()) do disableVisuals(d) end
        for _, d in ipairs(Lighting:GetDescendants()) do disableVisuals(d) end
        task.wait(0.5)
        applyRenderingSettings()
    end)
    stripProps()
end

--==================== [6] HOOKS] ====================--
workspace.DescendantAdded:Connect(function(d)
    if RUNNING then disableVisuals(d) end
end)
Lighting.DescendantAdded:Connect(function(d)
    if RUNNING then disableVisuals(d) end
end)

--==================== [7] RENDERING RE-APPLY LOOP — no fps cap in here] ====================--
task.spawn(function()
    while true do
        task.wait(CONFIG.REAPPLY_EVERY)
        if RUNNING then
            applyRenderingSettings()
        end
    end
end)

--==================== [8] UI] ====================--
local function mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end

local gui = mk("ScreenGui", {
    Name = "FpsBoosterUI", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true, DisplayOrder = 9999,
}, nil)
do
    local ok = pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
    if not ok or not gui.Parent then
        gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
end

local iconBtn = mk("TextButton", {
    Name = "Icon", Size = UDim2.fromOffset(100, 44),
    Position = UDim2.new(0, 8, 0, 45),
    BackgroundColor3 = Color3.fromRGB(30, 35, 45),
    Text = "⚡ FPS", TextSize = 14,
    Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(180, 240, 255),
    AutoButtonColor = true, ZIndex = 9999, Parent = gui,
}, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, iconBtn)
mk("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(100, 160, 220) }, iconBtn)

local win = mk("Frame", {
    Name = "Window", Size = UDim2.fromOffset(360, 260),
    Position = UDim2.new(0.5, -180, 0.5, -130),
    BackgroundColor3 = Color3.fromRGB(20, 20, 26),
    BorderSizePixel = 0, Visible = false, Active = true,
    Draggable = true, ZIndex = 9998, Parent = gui,
}, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 10) }, win)
mk("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(80, 100, 140) }, win)

local titleBar = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = Color3.fromRGB(30, 34, 44),
    BorderSizePixel = 0, Parent = win,
}, win)
mk("UICorner", { CornerRadius = UDim.new(0, 10) }, titleBar)
mk("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.new(1, -60, 1, 0),
    Position = UDim2.fromOffset(12, 0),
    Font = Enum.Font.GothamBold, TextSize = 15,
    TextColor3 = Color3.fromRGB(200, 230, 255),
    Text = "FPS Booster",
    TextXAlignment = Enum.TextXAlignment.Left, Parent = titleBar,
}, titleBar)
local closeBtn = mk("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -34, 0, 3),
    BackgroundColor3 = Color3.fromRGB(60, 30, 30),
    Text = "X", Font = Enum.Font.GothamBold,
    TextSize = 14, TextColor3 = Color3.fromRGB(255, 180, 180), Parent = titleBar,
}, titleBar)
mk("UICorner", { CornerRadius = UDim.new(0, 6) }, closeBtn)

local content = mk("Frame", {
    Size = UDim2.new(1, -20, 1, -50),
    Position = UDim2.fromOffset(10, 42),
    BackgroundTransparency = 1, Parent = win,
}, win)

local statusLbl = mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = Color3.fromRGB(26, 26, 32),
    BorderSizePixel = 0,
    Font = Enum.Font.Gotham, TextSize = 12,
    TextColor3 = Color3.fromRGB(200, 220, 240),
    Text = CONFIG.START_ON and ("Cap %d, audio muted."):format(CONFIG.FPS_CAP)
        or "Ready. Toggle below.",
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, Parent = content,
}, content)
mk("UICorner", { CornerRadius = UDim.new(0, 6) }, statusLbl)
mk("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) }, statusLbl)

local function makeToggle(y, label, default, onChange)
    local row = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.fromOffset(0, y),
        BackgroundColor3 = Color3.fromRGB(28, 28, 34),
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = content,
    }, content)
    mk("UICorner", { CornerRadius = UDim.new(0, 5) }, row)
    mk("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -70, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = Color3.fromRGB(230, 230, 240),
        Text = label, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    }, row)
    local box = mk("Frame", {
        Size = UDim2.fromOffset(38, 18),
        Position = UDim2.new(1, -48, 0.5, -9),
        BackgroundColor3 = default and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(60, 60, 70),
        BorderSizePixel = 0, Parent = row,
    }, row)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, box)
    local dot = mk("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0, Parent = box,
    }, box)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
    local state = default
    row.MouseButton1Click:Connect(function()
        state = not state
        box.BackgroundColor3 = state and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(60, 60, 70)
        dot.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.fromOffset(2, 2)
        onChange(state)
    end)
    return function(v)
        state = v
        box.BackgroundColor3 = v and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(60, 60, 70)
        dot.Position = v and UDim2.new(1, -16, 0.5, -7) or UDim2.fromOffset(2, 2)
    end
end

makeToggle(52, "FPS Booster", CONFIG.START_ON, function(v)
    RUNNING = v
    if v then
        fullSweep()
        capOnce()
        statusLbl.Text = ("Cap set to %d. Audio muted. Rendering disabled."):format(CONFIG.FPS_CAP)
    else
        unmuteAll()
        statusLbl.Text = "Paused (destroyed props stay gone until reload)."
    end
end)

makeToggle(88, "Strip Props (destructive)", CONFIG.STRIP_PROPS, function(v)
    CONFIG.STRIP_PROPS = v
    if v and RUNNING then
        statusLbl.Text = "Stripping props..."
        stripProps()
    else
        statusLbl.Text = "Safe mode: visuals disabled, props kept."
    end
end)

--==================== [8b] 0x OPTIMISER (black screen + live FPS)] ====================--
local optimiserOn = CONFIG.BLACK_SCREEN
local oxSetToggle

local black = mk("Frame", {
    Name = "Black", Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BorderSizePixel = 0, ZIndex = 1, Parent = gui,
}, gui)
local oxTitle = mk("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50),
    Position = UDim2.new(0, 0, 0.4, 0),
    Font = Enum.Font.GothamBold, TextSize = 40,
    TextColor3 = Color3.new(1, 1, 1), Text = "0x Optimiser",
    ZIndex = 2, Parent = gui,
}, gui)
local oxHint = mk("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
    Position = UDim2.new(0, 0, 0.4, 100),
    Font = Enum.Font.Gotham, TextSize = 16,
    TextColor3 = Color3.fromRGB(150, 150, 150),
    Text = "Press " .. CONFIG.TOGGLE_KEY.Name .. " or use the ⚡ FPS menu to toggle",
    ZIndex = 2, Parent = gui,
}, gui)
local fpsLbl = mk("TextLabel", {
    Name = "FpsCounter", BackgroundTransparency = 1,
    Size = UDim2.fromOffset(160, 28),
    Position = UDim2.new(1, -170, 0, 45),
    Font = Enum.Font.GothamBold, TextSize = 20,
    TextColor3 = Color3.fromRGB(0, 255, 120),
    TextXAlignment = Enum.TextXAlignment.Right,
    Text = "FPS: --", ZIndex = 3, Parent = gui,
}, gui)

local function applyOptimiser()
    pcall(function() RunService:Set3dRenderingEnabled(not optimiserOn) end)
    black.Visible = optimiserOn
    oxTitle.Visible = optimiserOn
    oxHint.Visible = optimiserOn
    if oxSetToggle then oxSetToggle(optimiserOn) end
end

local function toggleOptimiser()
    optimiserOn = not optimiserOn
    applyOptimiser()
end

-- Live FPS
do
    local frames, last = 0, os.clock()
    RunService.Heartbeat:Connect(function()
        frames += 1
        local now = os.clock()
        if now - last >= 0.5 then
            fpsLbl.Text = "FPS: " .. math.floor(frames / (now - last) + 0.5)
            frames, last = 0, now
        end
    end)
end

oxSetToggle = makeToggle(124, "0x Optimiser (black screen)", CONFIG.BLACK_SCREEN, function(v)
    optimiserOn = v
    applyOptimiser()
end)

--==================== [9] TOGGLE WINDOW] ====================--
local function toggleWindow() win.Visible = not win.Visible end
iconBtn.MouseButton1Click:Connect(toggleWindow)
closeBtn.MouseButton1Click:Connect(function() win.Visible = false end)
if UIS and UIS.InputBegan then
    UIS.InputBegan:Connect(function(i, gp)
        if gp then return end
        if i.KeyCode == Enum.KeyCode.RightControl then toggleWindow() end
        if i.KeyCode == CONFIG.TOGGLE_KEY then toggleOptimiser() end
    end)
end

--==================== [10] BOOT] ====================--
-- Optimiser first, so the black screen + 3D off + mute happen right at join
safe("optimiser", applyOptimiser)
safe("mute", function() if RUNNING then muteAll() end end)
safe("cap", capOnce)
if RUNNING then safe("sweep", fullSweep) end

-- Re-assert the state a few times in the first seconds (engine/game can reset it)
task.spawn(function()
    for _ = 1, 10 do
        task.wait(1)
        safe("reassert", function()
            applyOptimiser()
            if RUNNING then muteAll() end
        end)
    end
end)

print("[FPS Booster] Loaded. Tap ⚡ FPS top-left or press RightControl.")
