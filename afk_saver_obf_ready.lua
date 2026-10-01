-- afk saver
-- button top right = black screen on/off, everything else stays on

local plrs = game:GetService("Players")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local lighting = game:GetService("Lighting")
local ws = game:GetService("Workspace")

local cfg = {
	fps = 10,
	color = Color3.new(0, 0, 0),
	topGap = 60,
	key = Enum.KeyCode.RightControl,
	startOn = true,
	toggle3d = true,
	mute = true,
	lightingOff = true,
	lowMesh = true,
	camera = true,
	strip = true,
	startDelay = 5,
	stripDelay = 10,
}

if not game:IsLoaded() then game.Loaded:Wait() end

if getgenv and getgenv().afkCleanup then
	pcall(getgenv().afkCleanup)
end

pcall(function() if setthreadidentity then setthreadidentity(8) end end)

local alive = true
local active = false
local screenOn = false
local old = {}
local lightConn

-- gui
local gui = Instance.new("ScreenGui")
gui.Name = "afk_saver"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647

local ok = false
if gethui then ok = pcall(function() gui.Parent = gethui() end) end
if not ok then
	if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
	gui.Parent = game:GetService("CoreGui")
end

local bg = Instance.new("Frame")
bg.Position = UDim2.fromOffset(0, cfg.topGap)
bg.Size = UDim2.new(1, 0, 1, -cfg.topGap)
bg.BackgroundColor3 = cfg.color
bg.BorderSizePixel = 0
bg.Active = true
bg.Visible = false
bg.Parent = gui

local txt = Instance.new("TextLabel")
txt.Size = UDim2.fromScale(1, 0.06)
txt.Position = UDim2.fromScale(0, 0.47)
txt.BackgroundTransparency = 1
txt.Text = "press the button top right (or RightCtrl) to turn it off"
txt.TextColor3 = Color3.fromRGB(90, 90, 90)
txt.TextScaled = true
txt.Font = Enum.Font.Gotham
txt.Parent = bg

local btn = Instance.new("TextButton")
btn.Size = UDim2.fromOffset(150, 34)
btn.Position = UDim2.new(1, -160, 0, 10)
btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
btn.BackgroundTransparency = 0.15
btn.BorderSizePixel = 0
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 14
btn.Text = "Low Power: OFF"
btn.ZIndex = 10
btn.Parent = gui
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

local function setCap(n)
	pcall(function() if setfpscap then setfpscap(n) end end)
	pcall(function() if getgenv and getgenv().setfpscap then getgenv().setfpscap(n) end end)
end

-- lighting
local function killEffect(v)
	if v:IsA("PostEffect") or v:IsA("Atmosphere") or v:IsA("Clouds") then
		if old.fx and old.fx[v] == nil then old.fx[v] = v.Enabled end
		pcall(function() v.Enabled = false end)
	end
end

-- map stripping
local hidden = setmetatable({}, {__mode = "k"})
local turnedOff = setmetatable({}, {__mode = "k"})
local conns = {}
local stripId = 0

local function isNpc(obj)
	local p = obj.Parent
	while p and p ~= ws do
		if p:IsA("Model") and p:FindFirstChildOfClass("Humanoid") then return true end
		p = p.Parent
	end
	return false
end

local function turnOff(o)
	if o.Enabled then
		turnedOff[o] = true
		o.Enabled = false
	end
end

local function hide(o)
	hidden[o] = true
	o.LocalTransparencyModifier = 1
end

local function strip(obj)
	if isNpc(obj) then return end
	if obj:IsA("Highlight") then
		turnOff(obj)
	elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
		or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
		turnOff(obj)
	elseif obj:IsA("Decal") then
		obj:Destroy()
	elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		obj.ImageTransparency = 1
	elseif obj:IsA("SurfaceAppearance") then
		obj.ColorMap = ""
		obj.MetalnessMap = ""
		obj.NormalMap = ""
		obj.RoughnessMap = ""
	elseif obj:IsA("MeshPart") then
		obj.TextureID = ""
		obj.Transparency = 1
		hide(obj)
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
		hide(obj)
	elseif obj:IsA("Sound") then
		obj.Volume = 0
	end
end

local function stripChar(char)
	for _, v in ipairs(char:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Material = Enum.Material.SmoothPlastic
			v.Reflectance = 0
			v.CastShadow = false
			hide(v)
		elseif v:IsA("Accessory") or v:IsA("Clothing") or v:IsA("ShirtGraphic") or v:IsA("Decal") then
			v:Destroy()
		elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
			or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
			turnOff(v)
		end
	end
end

local function watchPlayer(p)
	table.insert(conns, p.CharacterAdded:Connect(function(char)
		task.wait(1)
		if active then pcall(stripChar, char) end
	end))
	if p.Character then pcall(stripChar, p.Character) end
end

local function startStrip()
	stripId = stripId + 1
	local id = stripId
	task.spawn(function()
		task.wait(cfg.stripDelay)
		if not active or id ~= stripId then return end

		pcall(function()
			local t = ws:FindFirstChildOfClass("Terrain")
			if t then
				t.WaterWaveSize = 0
				t.WaterWaveSpeed = 0
				t.WaterReflectance = 0
				t.WaterTransparency = 0.4
			end
		end)

		local queue = {}
		table.insert(conns, ws.DescendantAdded:Connect(function(v)
			if active then queue[#queue + 1] = v end
		end))

		-- go through the map in small chunks so the game doesnt freeze
		local all = ws:GetDescendants()
		local i, last = 1, os.clock()
		while i <= #all do
			if not active or id ~= stripId then return end
			pcall(strip, all[i])
			i = i + 1
			if os.clock() - last > 0.004 then
				task.wait(0.15)
				last = os.clock()
			end
		end
		all = nil

		for _, p in ipairs(plrs:GetPlayers()) do pcall(watchPlayer, p) end
		table.insert(conns, plrs.PlayerAdded:Connect(function(p) pcall(watchPlayer, p) end))

		while active and id == stripId do
			local t0 = os.clock()
			while #queue > 0 and os.clock() - t0 < 0.004 do
				local v = table.remove(queue)
				if v and v.Parent then pcall(strip, v) end
			end
			task.wait(0.2)
		end
	end)
end

local function stopStrip()
	stripId = stripId + 1
	for _, c in ipairs(conns) do c:Disconnect() end
	conns = {}
	for o in pairs(hidden) do
		if o.Parent then pcall(function() o.LocalTransparencyModifier = 0 end) end
	end
	for o in pairs(turnedOff) do
		if o.Parent then pcall(function() o.Enabled = true end) end
	end
	hidden = setmetatable({}, {__mode = "k"})
	turnedOff = setmetatable({}, {__mode = "k"})
end

-- turn everything on
local function enable()
	if active then return end
	active = true

	if cfg.mute then
		pcall(function()
			local ugs = UserSettings():GetService("UserGameSettings")
			old.vol = ugs.MasterVolume
			ugs.MasterVolume = 0
		end)
	end

	if cfg.lightingOff then
		old.fx = {}
		pcall(function()
			old.shadows = lighting.GlobalShadows
			lighting.GlobalShadows = false
		end)
		for _, v in ipairs(lighting:GetChildren()) do killEffect(v) end
		lightConn = lighting.ChildAdded:Connect(killEffect)
	end

	if cfg.lowMesh then
		pcall(function()
			old.mesh = settings().Rendering.MeshPartDetailLevel
			settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level00
		end)
		pcall(function() ws.StreamingEnabled = false end)
	end

	if cfg.camera then
		pcall(function() plrs.LocalPlayer.DevTouchCameraMode = Enum.DevTouchCameraMovementMode.Classic end)
		pcall(function()
			local cam = ws.CurrentCamera
			if cam then
				old.fov = cam.FieldOfView
				cam.FieldOfView = 120
			end
		end)
	end

	if cfg.strip then startStrip() end
	setCap(cfg.fps)
end

local function disable()
	active = false
	stopStrip()
	if lightConn then lightConn:Disconnect() lightConn = nil end
	if old.vol ~= nil then
		pcall(function() UserSettings():GetService("UserGameSettings").MasterVolume = old.vol end)
	end
	if old.shadows ~= nil then
		pcall(function() lighting.GlobalShadows = old.shadows end)
	end
	if old.fx then
		for v, was in pairs(old.fx) do
			if v and v.Parent then pcall(function() v.Enabled = was end) end
		end
	end
	if old.mesh then
		pcall(function() settings().Rendering.MeshPartDetailLevel = old.mesh end)
	end
	if old.fov then
		pcall(function() ws.CurrentCamera.FieldOfView = old.fov end)
	end
	old = {}
	pcall(function() rs:Set3dRenderingEnabled(true) end)
	setCap(60)
end

-- black screen toggle
local function setScreen(on)
	screenOn = on
	bg.Visible = on
	btn.Text = on and "Low Power: ON" or "Low Power: OFF"
	btn.BackgroundColor3 = on and Color3.fromRGB(30, 120, 50) or Color3.fromRGB(40, 40, 40)
	if cfg.toggle3d then
		pcall(function() rs:Set3dRenderingEnabled(not on) end)
	end
end

btn.Activated:Connect(function() setScreen(not screenOn) end)

local keyConn = uis.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == cfg.key then setScreen(not screenOn) end
end)

-- some games reset the cap so keep setting it
task.spawn(function()
	while alive do
		if active then setCap(cfg.fps) end
		task.wait(5)
	end
end)

task.spawn(function()
	pcall(function()
		if not plrs.LocalPlayer.Character then plrs.LocalPlayer.CharacterAdded:Wait() end
	end)
	task.wait(cfg.startDelay)
	if not alive then return end
	enable()
	if cfg.startOn and not screenOn then setScreen(true) end
end)

if getgenv then
	getgenv().afkCleanup = function()
		alive = false
		keyConn:Disconnect()
		pcall(disable)
		gui:Destroy()
	end
end
