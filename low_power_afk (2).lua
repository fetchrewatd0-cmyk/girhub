-- Low Power / AFK Mode (executor, all-in-one)
-- Everything below is ALWAYS ON by default (FPS cap, stripping, lighting, mute, etc).
-- The on-screen button (top right) / RightControl ONLY toggles the black screen
-- (and 3D rendering with it, so you can see the game when the screen is off).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

-- ===== SETTINGS =====
local CFG = {
	FPS_CAP        = 10,
	SCREEN_COLOR   = Color3.new(0, 0, 0),   -- black; Color3.new(1,1,1) for white
	TOP_GAP        = 60,      -- pixels left uncovered at the top so the FPS monitor stays visible
	TOGGLE_KEY     = Enum.KeyCode.RightControl,
	SCREEN_START_ON = true,   -- black screen on at start
	TOGGLE_3D      = true,    -- black screen ON = 3D rendering off, OFF = 3D back on
	MUTE_AUDIO     = true,
	STRIP_LIGHTING = true,
	LOW_MESH       = true,
	CAMERA_TWEAK   = true,
	STRIP_MAP      = true,
	START_DELAY    = 5,       -- seconds after your character spawns before features turn on
	STRIP_DELAY    = 10,      -- extra seconds before map stripping starts
}
-- ====================

if not game:IsLoaded() then game.Loaded:Wait() end

-- Re-running replaces the old copy instead of silently exiting
if getgenv and getgenv().LowPowerCleanup then
	pcall(getgenv().LowPowerCleanup)
end
local running = true

pcall(function() if setthreadidentity then setthreadidentity(8) end end)

local featuresOn = false
local screenOn = false
local saved = {}
local lightingConn

-- ===== Overlay + button =====
local gui = Instance.new("ScreenGui")
gui.Name = "LowPowerMode"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647

local parented = false
if typeof(gethui) == "function" then
	parented = pcall(function() gui.Parent = gethui() end)
end
if not parented then
	if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
	gui.Parent = CoreGui
end

local frame = Instance.new("Frame")
frame.Position = UDim2.fromOffset(0, CFG.TOP_GAP)
frame.Size = UDim2.new(1, 0, 1, -CFG.TOP_GAP)
frame.BackgroundColor3 = CFG.SCREEN_COLOR
frame.BorderSizePixel = 0
frame.Active = true
frame.Visible = false
frame.ZIndex = 1
frame.Parent = gui

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 0.06)
label.Position = UDim2.fromScale(0, 0.47)
label.BackgroundTransparency = 1
label.Text = "Low Power Mode - use the button (top right) or RightCtrl to exit"
label.TextColor3 = Color3.fromRGB(90, 90, 90)
label.TextScaled = true
label.Font = Enum.Font.Gotham
label.Parent = frame

local button = Instance.new("TextButton")
button.Name = "LowPowerToggle"
button.Size = UDim2.fromOffset(150, 34)
button.Position = UDim2.new(1, -160, 0, 10)
button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
button.BackgroundTransparency = 0.15
button.BorderSizePixel = 0
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamBold
button.TextSize = 14
button.Text = "Low Power: OFF"
button.ZIndex = 10
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = button

-- ===== Helpers =====
local function setFps(cap)
	pcall(function() if setfpscap then setfpscap(cap) end end)
	pcall(function() if getgenv and getgenv().setfpscap then getgenv().setfpscap(cap) end end)
end

local function disableEffect(v)
	if v:IsA("PostEffect") or v:IsA("Atmosphere") or v:IsA("Clouds") then
		if saved.effects and saved.effects[v] == nil then
			saved.effects[v] = v.Enabled
		end
		pcall(function() v.Enabled = false end)
	end
end

-- ===== Map / character stripping =====
local touchedLTM = setmetatable({}, {__mode = "k"})
local disabledObjs = setmetatable({}, {__mode = "k"})
local stripConns = {}
local stripToken = 0

local function inCreature(obj)
	local p = obj.Parent
	while p and p ~= Workspace do
		if p:IsA("Model") and p:FindFirstChildOfClass("Humanoid") then return true end
		p = p.Parent
	end
	return false
end

local function disableObj(o)
	if o.Enabled then
		disabledObjs[o] = true
		o.Enabled = false
	end
end

local function hidePart(o)
	touchedLTM[o] = true
	o.LocalTransparencyModifier = 1
end

local function optimize(obj)
	if inCreature(obj) then return end
	if obj:IsA("Highlight") then
		disableObj(obj)
	elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
		or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
		disableObj(obj)
	elseif obj:IsA("Decal") then
		obj:Destroy()
	elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		obj.ImageTransparency = 1
	elseif obj:IsA("SurfaceAppearance") then
		obj.ColorMap = ""; obj.MetalnessMap = ""; obj.NormalMap = ""; obj.RoughnessMap = ""
	elseif obj:IsA("MeshPart") then
		obj.TextureID = ""
		obj.Transparency = 1
		hidePart(obj)
	elseif obj:IsA("SpecialMesh") then
		obj.TextureId = ""
	elseif obj:IsA("BasePart") then
		local c = obj.Color
		obj.Material = Enum.Material.SmoothPlastic
		obj.Reflectance = 0
		obj.CastShadow = false
		obj.Color = Color3.fromRGB(
			math.floor(c.R * 255 / 32) * 32,
			math.floor(c.G * 255 / 32) * 32,
			math.floor(c.B * 255 / 32) * 32)
		hidePart(obj)
	elseif obj:IsA("Sound") then
		obj.Volume = 0
	end
end

local function optimizeCharacter(char)
	for _, v in ipairs(char:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Material = Enum.Material.SmoothPlastic
			v.Reflectance = 0
			v.CastShadow = false
			hidePart(v)
		elseif v:IsA("Accessory") or v:IsA("Clothing") or v:IsA("ShirtGraphic") or v:IsA("Decal") then
			v:Destroy()
		elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
			or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
			disableObj(v)
		end
	end
end

local function setupPlayer(plr)
	table.insert(stripConns, plr.CharacterAdded:Connect(function(char)
		task.wait(1)
		if featuresOn then pcall(optimizeCharacter, char) end
	end))
	if plr.Character then pcall(optimizeCharacter, plr.Character) end
end

local function startStrip()
	stripToken += 1
	local token = stripToken
	task.spawn(function()
		task.wait(CFG.STRIP_DELAY)
		if not featuresOn or token ~= stripToken then return end

		pcall(function()
			local terrain = Workspace:FindFirstChildOfClass("Terrain")
			if terrain then
				terrain.WaterWaveSize = 0
				terrain.WaterWaveSpeed = 0
				terrain.WaterReflectance = 0
				terrain.WaterTransparency = 0.4
			end
		end)

		local queue = {}
		table.insert(stripConns, Workspace.DescendantAdded:Connect(function(v)
			if featuresOn then queue[#queue + 1] = v end
		end))

		-- initial pass, time-budgeted so it never freezes the client
		local all = Workspace:GetDescendants()
		local i, t = 1, os.clock()
		while i <= #all do
			if not featuresOn or token ~= stripToken then return end
			pcall(optimize, all[i])
			i += 1
			if os.clock() - t > 0.004 then
				task.wait(0.15)
				t = os.clock()
			end
		end
		all = nil

		for _, plr in ipairs(Players:GetPlayers()) do pcall(setupPlayer, plr) end
		table.insert(stripConns, Players.PlayerAdded:Connect(function(plr) pcall(setupPlayer, plr) end))

		-- newly added instances, processed in small batches
		while featuresOn and token == stripToken do
			local t0 = os.clock()
			while #queue > 0 and os.clock() - t0 < 0.004 do
				local v = table.remove(queue)
				if v and v.Parent then pcall(optimize, v) end
			end
			task.wait(0.2)
		end
	end)
end

local function stopStrip()
	stripToken += 1
	for _, c in ipairs(stripConns) do c:Disconnect() end
	stripConns = {}
	for o in pairs(touchedLTM) do
		if o.Parent then pcall(function() o.LocalTransparencyModifier = 0 end) end
	end
	for o in pairs(disabledObjs) do
		if o.Parent then pcall(function() o.Enabled = true end) end
	end
	touchedLTM = setmetatable({}, {__mode = "k"})
	disabledObjs = setmetatable({}, {__mode = "k"})
end

-- ===== Always-on features =====
local function applyFeatures()
	if featuresOn then return end
	featuresOn = true

	if CFG.MUTE_AUDIO then
		pcall(function()
			local ugs = UserSettings():GetService("UserGameSettings")
			saved.volume = ugs.MasterVolume
			ugs.MasterVolume = 0
		end)
	end

	if CFG.STRIP_LIGHTING then
		saved.effects = {}
		pcall(function()
			saved.shadows = Lighting.GlobalShadows
			Lighting.GlobalShadows = false
		end)
		for _, v in ipairs(Lighting:GetChildren()) do disableEffect(v) end
		lightingConn = Lighting.ChildAdded:Connect(disableEffect)
	end

	if CFG.LOW_MESH then
		pcall(function()
			saved.mesh = settings().Rendering.MeshPartDetailLevel
			settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level00
		end)
		pcall(function() Workspace.StreamingEnabled = false end)
	end

	if CFG.CAMERA_TWEAK then
		pcall(function() Players.LocalPlayer.DevTouchCameraMode = Enum.DevTouchCameraMovementMode.Classic end)
		pcall(function()
			local cam = Workspace.CurrentCamera
			if cam then
				saved.fov = cam.FieldOfView
				cam.FieldOfView = 120
			end
		end)
	end

	if CFG.STRIP_MAP then startStrip() end

	setFps(CFG.FPS_CAP)
end

local function restoreFeatures()
	featuresOn = false
	stopStrip()
	if lightingConn then lightingConn:Disconnect(); lightingConn = nil end
	if saved.volume ~= nil then
		pcall(function() UserSettings():GetService("UserGameSettings").MasterVolume = saved.volume end)
	end
	if saved.shadows ~= nil then
		pcall(function() Lighting.GlobalShadows = saved.shadows end)
	end
	if saved.effects then
		for v, was in pairs(saved.effects) do
			if v and v.Parent then pcall(function() v.Enabled = was end) end
		end
	end
	if saved.mesh then
		pcall(function() settings().Rendering.MeshPartDetailLevel = saved.mesh end)
	end
	if saved.fov then
		pcall(function() Workspace.CurrentCamera.FieldOfView = saved.fov end)
	end
	saved = {}
	pcall(function() RunService:Set3dRenderingEnabled(true) end)
	setFps(60)
end

-- ===== Black screen toggle (the only thing the button controls) =====
local function setScreen(state)
	screenOn = state
	frame.Visible = state
	button.Text = state and "Low Power: ON" or "Low Power: OFF"
	button.BackgroundColor3 = state and Color3.fromRGB(30, 120, 50) or Color3.fromRGB(40, 40, 40)
	if CFG.TOGGLE_3D then
		pcall(function() RunService:Set3dRenderingEnabled(not state) end)
	end
end

button.Activated:Connect(function()
	setScreen(not screenOn)
end)

local keyConn = UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == CFG.TOGGLE_KEY then
		setScreen(not screenOn)
	end
end)

-- Keep the FPS cap applied (games/Roblox can reset it)
task.spawn(function()
	while running do
		if featuresOn then setFps(CFG.FPS_CAP) end
		task.wait(5)
	end
end)

-- Start: wait for character + short delay, then turn everything on
task.spawn(function()
	pcall(function()
		local plr = Players.LocalPlayer
		if not plr.Character then plr.CharacterAdded:Wait() end
	end)
	task.wait(CFG.START_DELAY)
	if not running then return end
	applyFeatures()
	if CFG.SCREEN_START_ON and not screenOn then setScreen(true) end
end)

if getgenv then
	getgenv().LowPowerCleanup = function()
		running = false
		if keyConn then keyConn:Disconnect() end
		pcall(restoreFeatures)
		gui:Destroy()
	end
end
