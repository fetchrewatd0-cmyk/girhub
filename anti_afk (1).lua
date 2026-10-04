local localPlayer = game:GetService("Players").LocalPlayer

local tbl30 = { Enabled = true, Alive = true, Silenced = {} }

local function fn35()
    if type(getconnections) ~= "function" then
        return {}
    end
    local ok, result = pcall(getconnections, localPlayer.Idled)
    ok = ok and type(result) == "table"
    local tbl31 = ok and result or {}
    return tbl31
end

local function fn36()
    for _, v35 in ipairs(fn35()) do
        if pcall(function()
            v35:Disable()
        end) then
            local n32 = #tbl30.Silenced + 1
            tbl30.Silenced[n32] = v35
        end
    end
end

local function fn37()
    local silenced = tbl30.Silenced

    if #silenced == 0 then
        silenced = fn35()
    end

    for _, v35 in ipairs(silenced) do
        pcall(function()
            v35:Enable()
        end)
    end

    table.clear(tbl30.Silenced)
end

local obj = setmetatable({}, {
    __index = function()
        return function() end
    end,
})

local tbl31 = {}

local function fn38()
    local tbl32 = {}
    if
        type(getgc) ~= "function"
        or type(debug) ~= "table"
        or type(debug.getupvalues) ~= "function"
    then
        return tbl32
    end
    local ok, result = pcall(getgc, false)
    local v35 = result
    if not ok or type(v35) ~= "table" then
        return tbl32
    end

    for _, v36 in ipairs(v35) do
        if type(v36) == "function" and islclosure(v36) then
            local ok2, result2 = pcall(debug.info, v36, "s")
            ok2 = ok2 and type(result2) == "string"
            ok2 = ok2 and string.find(result2, "AntiAFK", 1, true)

            if ok2 then
                local ok3, result3 = pcall(debug.getupvalues, v36)
                local v37 = result3

                if ok3 and type(v37) == "table" then
                    for k, v38 in pairs(v37) do
                        if
                            typeof(v38) == "Instance"
                            and v38.ClassName == "TeleportService"
                        then
                            local n32 = #tbl32 + 1
                            tbl32[n32] = { Fn = v36, Index = k, Original = v38 }
                        end
                    end
                end
            end
        end
    end

    return tbl32
end

local function fn39()
    for _, v35 in ipairs(fn38()) do
        local ok, result = pcall(debug.getupvalue, v35.Fn, v35.Index)
        ok = ok and typeof(result) == "Instance"

        if ok then
            if pcall(debug.setupvalue, v35.Fn, v35.Index, obj) then
                local n32 = #tbl31 + 1
                tbl31[n32] = v35
            end
        end
    end
end

local function fn40()
    for _, v35 in ipairs(tbl31) do
        pcall(debug.setupvalue, v35.Fn, v35.Index, v35.Original)
    end

    table.clear(tbl31)
end

local function fn41()
    fn36()

    if #tbl31 == 0 then
        fn39()
    end
end

local connection = localPlayer.CharacterAdded:Connect(function()
    task.delay(1, function()
        if tbl30.Alive and tbl30.Enabled then
            table.clear(tbl30.Silenced)
            pcall(fn41)
        end
    end)
end)

task.spawn(function()
    while tbl30.Alive do
        if tbl30.Enabled then
            fn41()
        end

        task.wait(600)
    end
end)
