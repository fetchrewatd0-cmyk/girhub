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
	START_ENABLED = true,
}
-- ====================

if not game:IsLoaded() then game.Loaded:Wait() end

if getgenv then
	if getgenv().LowPowerLoaded then
		warn("Low Power script already running")
		return
	end
	getgenv().LowPowerLoaded = true
end

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
	if typeof(setfpscap) == "function" then
		pcall(setfpscap, cap)
	end
end

local function disableEffect(v)
	if v:IsA("PostEffect") or v:IsA("Atmosphere") or v:IsA("Clouds") then
		if saved.effects and saved.effects[v] == nil then
			saved.effects[v] = v.Enabled
		end
		pcall(function() v.Enabled = false end)
	end
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

	setFps(CFG.FPS_CAP)
end

local function restore()
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
	while true do
		if enabled then setFps(CFG.FPS_CAP) end
		task.wait(10)
	end
end)

button.Activated:Connect(function()
	setLowPower(not enabled)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == CFG.TOGGLE_KEY then
		setLowPower(not enabled)
	end
end)

if CFG.START_ENABLED then
	setLowPower(true)
end
