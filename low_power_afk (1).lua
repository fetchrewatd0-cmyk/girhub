-- Low Power / AFK Mode (executor, all-in-one)
-- Toggle: on-screen button (top right) or RightControl

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

-- ===== SETTINGS =====
local CFG = {
	FPS_CAP       = 10,                    -- cap while ON (raise to 15 if you get kicked/rubberband)
	NORMAL_FPS    = 60,                    -- cap when OFF
	SCREEN_COLOR  = Color3.new(0, 0, 0),   -- black; Color3.new(1,1,1) for white
	TOGGLE_KEY    = Enum.KeyCode.RightControl,
	DISABLE_3D    = true,
	MUTE_AUDIO    = true,
	STRIP_LIGHTING = true,
	LOW_MESH       = true,    -- lowest mesh detail + streaming off attempt
	CAMERA_TWEAK   = true,    -- classic touch camera + FOV 120 (from original)
	STRIP_MAP      = true,    -- remove textures/decals/particles/materials, hide parts
	STRIP_DELAY    = 30,      -- seconds to wait before stripping (like the original)
	START_ENABLED = true,
}
-- ====================

if not game:IsLoaded() then game.Loaded:Wait() end

-- Re-running replaces the old copy instead of silently exiting
if getgenv and getgenv().LowPowerCleanup then
	pcall(getgenv().LowPowerCleanup)
end
local running = true

pcall(function() if setthreadidentity then setthreadidentity(8) end end)

local enabled = false
local saved = {}
local lightingConn

-- Overlay
local gui = Instance.new("ScreenGui")
gui.Name = "LowPowerMode"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647
gui.Enabled = true

local parented = false
if typeof(gethui) == "function" then
	parented = pcall(function() gui.Parent = gethui() end)
end
if not parented then
	if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
	gui.Parent = CoreGui
end

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
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

-- On-screen toggle button (always visible, sits above the black overlay)
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
button.AutoButtonColor = true
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = button

-- Helpers
local function setFps(cap)
	-- same style as the original AFKTY script (no typeof check, some executors
	-- expose setfpscap as a callable that typeof() doesn't report as "function")
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

local Workspace = game:GetService("Workspace")
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
		if enabled then pcall(optimizeCharacter, char) end
	end))
	if plr.Character then pcall(optimizeCharacter, plr.Character) end
end

local function startStrip()
	stripToken += 1
	local token = stripToken
	task.spawn(function()
		task.wait(CFG.STRIP_DELAY)
		if not enabled or token ~= stripToken then return end

		pcall(function()
			local terrain = Workspace:FindFirstChildOfClass("Terrain")
			if terrain then
				terrain.WaterWaveSize = 0
				terrain.WaterWaveSpeed = 0
				terrain.WaterReflectance = 0
				terrain.WaterTransparency = 0.4
			end
		end)

		local n = 0
		for _, v in ipairs(Workspace:GetDescendants()) do
			if not enabled or token ~= stripToken then return end
			pcall(optimize, v)
			n += 1
			if n % 500 == 0 then task.wait() end -- avoid freezing
		end

		table.insert(stripConns, Workspace.DescendantAdded:Connect(function(v)
			if enabled then pcall(optimize, v) end
		end))
		for _, plr in ipairs(Players:GetPlayers()) do pcall(setupPlayer, plr) end
		table.insert(stripConns, Players.PlayerAdded:Connect(function(plr) pcall(setupPlayer, plr) end))
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

local function applyLow()
	if CFG.DISABLE_3D then
		pcall(function() RunService:Set3dRenderingEnabled(false) end)
	end

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

local function restore()
	stopStrip()
	if saved.mesh then
		pcall(function() settings().Rendering.MeshPartDetailLevel = saved.mesh end)
	end
	if saved.fov then
		pcall(function() Workspace.CurrentCamera.FieldOfView = saved.fov end)
	end
	pcall(function() RunService:Set3dRenderingEnabled(true) end)

	if lightingConn then
		lightingConn:Disconnect()
		lightingConn = nil
	end

	if saved.volume ~= nil then
		pcall(function() UserSettings():GetService("UserGameSettings").MasterVolume = saved.volume end)
	end
	if saved.shadows ~= nil then
		pcall(function() Lighting.GlobalShadows = saved.shadows end)
	end
	if saved.effects then
		for v, was in pairs(saved.effects) do
			if v and v.Parent then
				pcall(function() v.Enabled = was end)
			end
		end
	end
	saved = {}

	setFps(CFG.NORMAL_FPS)
end

local function setLowPower(state)
	if state == enabled then return end
	enabled = state
	frame.Visible = state
	button.Text = state and "Low Power: ON" or "Low Power: OFF"
	button.BackgroundColor3 = state and Color3.fromRGB(30, 120, 50) or Color3.fromRGB(40, 40, 40)
	if state then applyLow() else restore() end
end

-- Re-apply FPS cap periodically (games/Roblox can reset it)
task.spawn(function()
	while running do
		if enabled then setFps(CFG.FPS_CAP) end
		task.wait(5)
	end
end)

button.Activated:Connect(function()
	setLowPower(not enabled)
end)

local keyConn = UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == CFG.TOGGLE_KEY then
		setLowPower(not enabled)
	end
end)

if CFG.START_ENABLED then
	setLowPower(true)
end

if getgenv then
	getgenv().LowPowerCleanup = function()
		running = false
		if keyConn then keyConn:Disconnect() end
		if enabled then pcall(restore) end
		gui:Destroy()
	end
end
