--== FPS cap (once) + 0x Optimiser (3D off / black screen) + FPS monitor ==--

if not game:IsLoaded() then game.Loaded:Wait() end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui    = game:GetService("CoreGui")
local UIS        = game:GetService("UserInputService")

local function safe(name, f)
    local ok, e = pcall(f)
    if not ok then warn("[0x] " .. name .. " failed: " .. tostring(e)) end
end

--==================== [CONFIG] ====================--
local CONFIG = {
    FPS_CAP      = 15,    -- applied once at start
    BLACK_SCREEN = true,  -- 3D rendering off + black screen (default ON)
    TOGGLE_KEY   = Enum.KeyCode.F5,
}

--==================== [1] FPS CAP (one time) ====================--
pcall(function() setfpscap(CONFIG.FPS_CAP) end)
print("[0x] FPS cap applied once:", CONFIG.FPS_CAP)

--==================== [2] UI ====================--
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
    Name = "Window", Size = UDim2.fromOffset(360, 100),
    Position = UDim2.new(0.5, -180, 0.5, -50),
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
    Text = "0x Optimiser",
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

--==================== [3] 0x OPTIMISER (black screen + 3D off) ====================--
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

oxSetToggle = makeToggle(0, "0x Optimiser (black screen)", CONFIG.BLACK_SCREEN, function(v)
    optimiserOn = v
    applyOptimiser()
end)

--==================== [4] FPS MONITOR ====================--
local fpsLbl = mk("TextLabel", {
    Name = "FpsCounter", BackgroundTransparency = 1,
    Size = UDim2.fromOffset(160, 28),
    Position = UDim2.new(1, -170, 0, 45),
    Font = Enum.Font.GothamBold, TextSize = 20,
    TextColor3 = Color3.fromRGB(0, 255, 120),
    TextXAlignment = Enum.TextXAlignment.Right,
    Text = "FPS: --", ZIndex = 3, Parent = gui,
}, gui)

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

--==================== [5] RUNTIME ====================--
local runtimeLbl = mk("TextLabel", {
    Name = "Runtime", BackgroundTransparency = 1,
    Size = UDim2.fromOffset(260, 24),
    Position = UDim2.new(1, -270, 0, 73),
    Font = Enum.Font.GothamMedium, TextSize = 16,
    TextColor3 = Color3.fromRGB(180, 220, 255),
    TextXAlignment = Enum.TextXAlignment.Right,
    Text = "Runtime: 0d 00h 00m 00s", ZIndex = 3, Parent = gui,
}, gui)

do
    local startTime = os.time()
    task.spawn(function()
        while true do
            local t = os.time() - startTime
            runtimeLbl.Text = string.format("Runtime: %dd %02dh %02dm %02ds",
                math.floor(t / 86400), math.floor((t % 86400) / 3600),
                math.floor((t % 3600) / 60), t % 60)
            task.wait(1)
        end
    end)
end

--==================== [6] TOGGLE WINDOW / KEYS ====================--
local function toggleWindow() win.Visible = not win.Visible end
iconBtn.MouseButton1Click:Connect(toggleWindow)
closeBtn.MouseButton1Click:Connect(function() win.Visible = false end)
UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightControl then toggleWindow() end
    if i.KeyCode == CONFIG.TOGGLE_KEY then toggleOptimiser() end
end)

--==================== [7] BOOT ====================--
safe("optimiser", applyOptimiser)

-- Re-assert the black screen / 3D state a few times at join (game can reset it)
task.spawn(function()
    for _ = 1, 10 do
        task.wait(1)
        safe("reassert", applyOptimiser)
    end
end)

print("[0x] Loaded. Tap ⚡ FPS top-left or press RightControl.")
