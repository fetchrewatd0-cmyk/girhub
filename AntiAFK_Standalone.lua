-- Standalone Anti-AFK (Chilli Hub Edition)
-- Can toggle on/off, survives respawns

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- State management
local antiAFKState = {
    Alive = true,
    Silenced = {},      -- Disabled connections
    PatrolFunctions = {} -- Hijacked AntiAFK functions
}

-- Fake TeleportService (blocks game's AntiAFK)
local fakeService = setmetatable({}, {
    __index = function()
        return function() end
    end,
})

-- Get all connections to Idled event
local function getIdledConnections()
    if type(getconnections) ~= "function" then
        return {}
    end
    local ok, result = pcall(getconnections, localPlayer.Idled)
    ok = ok and type(result) == "table"
    return ok and result or {}
end

-- Disable all Idled connections
local function disableIdledConnections()
    for _, conn in ipairs(getIdledConnections()) do
        if pcall(function() conn:Disable() end) then
            table.insert(antiAFKState.Silenced, conn)
        end
    end
end

-- Re-enable Idled connections
local function enableIdledConnections()
    for _, conn in ipairs(antiAFKState.Silenced) do
        pcall(function() conn:Enable() end)
    end
    table.clear(antiAFKState.Silenced)
end

-- Find game's AntiAFK function and hijack it
local function findAndHijackAntiAFK()
    if type(getgc) ~= "function" or type(debug) ~= "table" or type(debug.getupvalues) ~= "function" then
        return
    end
    
    local ok, allClosures = pcall(getgc, false)
    if not ok or type(allClosures) ~= "table" then
        return
    end
    
    for _, func in ipairs(allClosures) do
        if type(func) == "function" and islclosure(func) then
            local ok2, source = pcall(debug.info, func, "s")
            ok2 = ok2 and type(source) == "string"
            ok2 = ok2 and string.find(source, "AntiAFK", 1, true)
            
            if ok2 then
                local ok3, upvals = pcall(debug.getupvalues, func)
                
                if ok3 and type(upvals) == "table" then
                    for k, upval in pairs(upvals) do
                        if typeof(upval) == "Instance" and upval.ClassName == "TeleportService" then
                            local ok4 = pcall(debug.setupvalue, func, k, fakeService)
                            if ok4 then
                                table.insert(antiAFKState.PatrolFunctions, { Fn = func, Index = k, Original = upval })
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Restore original TeleportService references
local function restoreAntiAFKFunctions()
    for _, entry in ipairs(antiAFKState.PatrolFunctions) do
        pcall(debug.setupvalue, entry.Fn, entry.Index, entry.Original)
    end
    table.clear(antiAFKState.PatrolFunctions)
end

-- Main activation
local function activateAntiAFK()
    disableIdledConnections()
    
    if #antiAFKState.PatrolFunctions == 0 then
        findAndHijackAntiAFK()
    end
end

-- Deactivate
local function deactivateAntiAFK()
    enableIdledConnections()
    restoreAntiAFKFunctions()
end

-- Reactivate on respawn
localPlayer.CharacterAdded:Connect(function()
    task.delay(1, function()
        if antiAFKState.Alive then
            table.clear(antiAFKState.Silenced)
            pcall(activateAntiAFK)
        end
    end)
end)

-- Periodic reactivation (every 10 minutes)
task.spawn(function()
    while antiAFKState.Alive do
        activateAntiAFK()
        task.wait(600)
    end
end)

-- Cleanup on exit
game:BindToClose(function()
    antiAFKState.Alive = false
    deactivateAntiAFK()
end)

-- Activate on startup
activateAntiAFK()
print("[Anti-AFK] Always ON")
