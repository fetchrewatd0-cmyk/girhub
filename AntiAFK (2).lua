-- Standalone Anti-AFK (Steal an Egg)
-- Turns on automatically 60 seconds after you run it.
-- Re-running won't stack duplicate connections.

local DELAY_SECONDS = 60

task.delay(DELAY_SECONDS, function()
    local Players = game:GetService("Players")
    local VirtualUser = game:GetService("VirtualUser")
    local player = Players.LocalPlayer

    -- Clean up a previous run
    if getgenv then
        local env = getgenv()
        if env.__AntiAFK_Conn then
            pcall(function() env.__AntiAFK_Conn:Disconnect() end)
            env.__AntiAFK_Conn = nil
        end
    end

    -- Steal an Egg: kill the game's own AntiAFK script (PlayerScripts.Game.AntiAFK)
    local scripts = player:FindFirstChild("PlayerScripts")
    local gameFolder = scripts and scripts:FindFirstChild("Game")
    local afk = gameFolder and gameFolder:FindFirstChild("AntiAFK")
    if afk then
        pcall(function() afk.Disabled = true end)
        pcall(function() afk:Destroy() end)
    end

    -- Disable any existing Idled connections, if executor supports it
    if type(getconnections) == "function" then
        pcall(function()
            for _, c in ipairs(getconnections(player.Idled)) do
                pcall(function() c:Disable() end)
            end
        end)
    end

    -- Our own anti-idle: fake input whenever Roblox thinks you're idle
    local conn = player.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)

    if getgenv then
        getgenv().__AntiAFK_Conn = conn
    end

    print("[AntiAFK] Enabled")
end)

print("[AntiAFK] Will enable in " .. DELAY_SECONDS .. "s")
