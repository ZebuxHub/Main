-- Macro Recorder/Player for Roblox using WindUI
-- Records calls to ReplicatedStorage.RemoteFunctions.PlaceUnit / UpgradeUnit
-- Saves as JSON, loads and replays by absolute time or by wave (workspace attribute "Round")

-- Guard executor-only APIs
local env = (getfenv and getfenv()) or _G
local exec = {
    writefile = env and env.writefile or nil,
    readfile = env and env.readfile or nil,
    isfile = env and env.isfile or nil,
    isfolder = env and env.isfolder or nil,
    makefolder = env and env.makefolder or nil,
    listfiles = env and env.listfiles or nil,
    delfile = env and env.delfile or nil,
    getrawmetatable = env and env.getrawmetatable or nil,
    getnamecallmethod = env and env.getnamecallmethod or nil,
    isreadonly = env and env.isreadonly or nil,
    setreadonly = env and env.setreadonly or nil,
    vector = env and env.vector or nil,
}

local hasFS = type(exec.writefile) == "function" and type(exec.readfile) == "function"
local hasHook = type(exec.getrawmetatable) == "function" and type(exec.getnamecallmethod) == "function"

-- WindUI bootstrap (you can remove if you already load WindUI elsewhere)
local WindUI = nil
pcall(function()
    WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

-- Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remotes we care about
local RemoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local PlaceUnitRF = RemoteFunctions:FindFirstChild("PlaceUnit")
local UpgradeUnitRF = RemoteFunctions:FindFirstChild("UpgradeUnit")

-- Folder for macros
local ROOT_FOLDER = "WindUI"
local MACRO_DIR = ROOT_FOLDER .. "/Macros"
pcall(function()
    if hasFS and exec.isfolder and not exec.isfolder(ROOT_FOLDER) and exec.makefolder then exec.makefolder(ROOT_FOLDER) end
    if hasFS and exec.isfolder and not exec.isfolder(MACRO_DIR) and exec.makefolder then exec.makefolder(MACRO_DIR) end
end)

-- Utilities: serialization for userdata that JSON cannot encode
local function serializeValue(value)
    local t = typeof and typeof(value) or type(value)
    if t == "Vector3" then
        return { __type = "Vector3", x = value.X, y = value.Y, z = value.Z }
    elseif t == "CFrame" then
        local c = { value:GetComponents() }
        return { __type = "CFrame", components = c }
    elseif t == "Color3" then
        return { __type = "Color3", r = value.R, g = value.G, b = value.B }
    elseif t == "table" then
        local out = {}
        for k, v in pairs(value) do
            out[k] = serializeValue(v)
        end
        return out
    else
        return value
    end
end

local function attemptVectorCreate(x, y, z)
    local ok, vec = pcall(function()
        if exec.vector and typeof(exec.vector.create) == "function" then
            return exec.vector.create(x, y, z)
        end
        return Vector3.new(x, y, z)
    end)
    return ok and vec or Vector3.new(x, y, z)
end

local function deserializeValue(value)
    if type(value) ~= "table" then return value end
    local hint = rawget(value, "__type")
    if hint == "Vector3" then
        return attemptVectorCreate(value.x, value.y, value.z)
    elseif hint == "CFrame" then
        return CFrame.new(table.unpack(value.components or {}))
    elseif hint == "Color3" then
        return Color3.new(value.r, value.g, value.b)
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = deserializeValue(v)
    end
    return out
end

local function deepClone(v)
    local tv = type(v)
    if tv ~= "table" then return v end
    local n = {}
    for k, val in pairs(v) do n[deepClone(k)] = deepClone(val) end
    return n
end

-- Macro runtime state
local Macro = {
    meta = {
        version = 1,
        createdAt = DateTime.now():ToIsoDate(),
        placeId = game.PlaceId,
        gameId = game.GameId,
    },
    events = {},
}

local isRecording = false
local isPlaying = false
local playMode = "Time" -- "Time" | "Wave"
local stepDelay = 0.15
local recordStartClock = 0
local currentWave = tonumber(workspace:GetAttribute("Round")) or 0

-- Status exposure for UI
local statusText = {
    mode = "Idle",
    detail = "Ready",
    counters = { recorded = 0, played = 0 },
}

local function setStatus(mode, detail)
    statusText.mode = mode
    statusText.detail = detail or statusText.detail
end

-- Wave tracker
pcall(function()
    workspace:GetAttributeChangedSignal("Round"):Connect(function()
        currentWave = tonumber(workspace:GetAttribute("Round")) or currentWave
    end)
end)

-- File helpers
local function listMacros()
    local files = {}
    if not hasFS or not exec.listfiles then return files end
    for _, f in ipairs(exec.listfiles(MACRO_DIR)) do
        local name = f:match("([^/\\]+)%.json$")
        if name then table.insert(files, name) end
    end
    table.sort(files)
    return files
end

local function saveMacro(name)
    if not hasFS then return false, "Filesystem API not available" end
    if not name or name == "" then return false, "Empty file name" end
    local data = deepClone(Macro)
    local serialEvents = {}
    for i, ev in ipairs(data.events) do
        serialEvents[i] = {
            kind = ev.kind,
            wave = ev.wave,
            t = ev.t,
            args = serializeValue(ev.args),
        }
    end
    data.events = serialEvents
    if not exec.writefile then return false, "writefile not available" end
    exec.writefile(MACRO_DIR .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    return true
end

local function loadMacro(name)
    if not hasFS then return false, "Filesystem API not available" end
    local path = MACRO_DIR .. "/" .. name .. ".json"
    if not (exec.isfile and exec.isfile(path)) then return false, "File not found" end
    local ok, decoded = pcall(function()
        if not exec.readfile then error("readfile missing") end
        return HttpService:JSONDecode(exec.readfile(path))
    end)
    if not ok then return false, "Failed to decode JSON" end
    Macro = decoded
    for _, ev in ipairs(Macro.events or {}) do
        ev.args = deserializeValue(ev.args)
    end
    Macro.events = Macro.events or {}
    statusText.counters.recorded = #Macro.events
    return true
end

-- Recording
local function startRecording()
    Macro = {
        meta = {
            version = 1,
            createdAt = DateTime.now():ToIsoDate(),
            placeId = game.PlaceId,
            gameId = game.GameId,
        },
        events = {},
    }
    statusText.counters.recorded = 0
    recordStartClock = os.clock()
    isRecording = true
    setStatus("Recording", "Waiting for remote calls…")
end

local function stopRecording()
    isRecording = false
    setStatus("Idle", string.format("Recorded %d actions", statusText.counters.recorded))
end

local function recordEvent(kind, args)
    if not isRecording then return end
    local ev = {
        kind = kind,
        args = deepClone(args),
        wave = currentWave,
        t = os.clock() - recordStartClock,
    }
    table.insert(Macro.events, ev)
    statusText.counters.recorded += 1
    setStatus("Recording", string.format("%s captured (wave %d)", kind, ev.wave))
end

-- Hook remotes via __namecall
if hasHook then
    local gmt = exec.getrawmetatable(game)
    local oldNamecall = gmt.__namecall
    local oldReadOnly = exec.isreadonly and exec.isreadonly(gmt)
    if exec.setreadonly then exec.setreadonly(gmt, false) end
    gmt.__namecall = function(self, ...)
        local method = exec.getnamecallmethod and exec.getnamecallmethod() or ""
        local remoteName = rawget(self, "Name") or tostring(self)
        local result
        if isRecording and method == "InvokeServer" and (remoteName == "PlaceUnit" or remoteName == "UpgradeUnit") then
            local packed = { ... }
            -- The game examples use unpack(args), so we reconsolidate to a single args table
            -- Detect signature: some scripts pass a single table, some pass varargs
            local toRecord
            if #packed == 1 and type(packed[1]) == "table" then
                toRecord = packed[1]
            else
                toRecord = packed
            end
            recordEvent(remoteName, toRecord)
        end
        result = oldNamecall(self, ...)
        return result
    end
    if exec.setreadonly then exec.setreadonly(gmt, oldReadOnly ~= false) end
end

-- Playback
local function stopPlayback()
    isPlaying = false
    setStatus("Idle", "Playback stopped")
end

local function invoke(kind, args)
    local rf = (kind == "PlaceUnit") and PlaceUnitRF or (kind == "UpgradeUnit") and UpgradeUnitRF or nil
    if not rf then return end
    local packed
    if type(args) == "table" and (args[1] ~= nil or next(args) ~= nil) then
        packed = args
    else
        packed = { args }
    end
    pcall(function()
        rf:InvokeServer(table.unpack(packed))
    end)
end

local function playByTime()
    if isPlaying then return end
    if not Macro or not Macro.events or #Macro.events == 0 then return end
    isPlaying = true
    setStatus("Playing", "Time-based playback started")
    statusText.counters.played = 0
    -- Sort by time
    local events = {}
    for _, ev in ipairs(Macro.events) do table.insert(events, ev) end
    table.sort(events, function(a, b) return a.t < b.t end)
    local startClock = os.clock()
    for _, ev in ipairs(events) do
        if not isPlaying then break end
        local dueAt = startClock + ev.t
        while isPlaying and os.clock() < dueAt do task.wait() end
        setStatus("Playing", string.format("%s (wave %d, t=%.2fs)", ev.kind, ev.wave or -1, ev.t or 0))
        invoke(ev.kind, ev.args)
        statusText.counters.played += 1
        if stepDelay and stepDelay > 0 then task.wait(stepDelay) end
    end
    stopPlayback()
end

local function playByWave()
    if isPlaying then return end
    if not Macro or not Macro.events or #Macro.events == 0 then return end
    isPlaying = true
    setStatus("Playing", "Wave-based playback started")
    statusText.counters.played = 0
    local events = {}
    for _, ev in ipairs(Macro.events) do table.insert(events, ev) end
    table.sort(events, function(a, b)
        if (a.wave or 0) == (b.wave or 0) then return (a.t or 0) < (b.t or 0) end
        return (a.wave or 0) < (b.wave or 0)
    end)
    for _, ev in ipairs(events) do
        if not isPlaying then break end
        while isPlaying and currentWave < (ev.wave or 0) do
            task.wait(0.1)
        end
        setStatus("Playing", string.format("%s (wave %d)", ev.kind, ev.wave or -1))
        invoke(ev.kind, ev.args)
        statusText.counters.played += 1
        if stepDelay and stepDelay > 0 then task.wait(stepDelay) end
    end
    stopPlayback()
end

local function startPlayback()
    if playMode == "Wave" then
        task.spawn(playByWave)
    else
        task.spawn(playByTime)
    end
end

-- WindUI based UI (minimal)
if WindUI then
    local Window = WindUI:CreateWindow({
        Title = "Macro Recorder",
        Icon = "mouse-pointer-2",
        Folder = "RemoteRecorder",
        Size = UDim2.fromOffset(500, 380),
        Transparent = true,
        Theme = "Dark",
        User = { Enabled = false },
    })

    local Section = Window:Section({ Title = "Macro Stuff", Opened = true })
    local Tab = Section:Tab({ Title = "Recorder", Icon = "radio" })

    local StatusParagraph = Tab:Paragraph({
        Title = "Macro Status: Idle",
        Desc = "Mode: Idle\nDetails: Ready\nRecorded: 0\nPlayed: 0\nWave: 0",
        Color = "Grey",
    })

    local function refreshStatus()
        local title = "Macro Status: " .. statusText.mode
        local desc = string.format(
            "Mode: %s\nDetails: %s\nRecorded: %d\nPlayed: %d\nWave: %d",
            statusText.mode,
            statusText.detail,
            statusText.counters.recorded,
            statusText.counters.played,
            currentWave
        )
        StatusParagraph:SetTitle(title)
        StatusParagraph:SetDesc(desc)
    end
    task.spawn(function()
        while true do
            refreshStatus()
            task.wait(0.25)
        end
    end)

    Tab:Divider()

    local RecordToggle = Tab:Toggle({
        Title = "Record Macro",
        Value = false,
        Callback = function(v)
            if v then startRecording() else stopRecording() end
        end,
    })

    local PlayToggle = Tab:Toggle({
        Title = "Play Macro",
        Value = false,
        Callback = function(v)
            if v then startPlayback() else stopPlayback() end
        end,
    })

    Tab:Toggle({
        Title = "Play Mode: Wave",
        Type = "Checkbox",
        Value = false,
        Callback = function(checked)
            playMode = checked and "Wave" or "Time"
        end,
    })

    Tab:Slider({
        Title = "Step Delay",
        Value = { Min = 0, Max = 1, Default = stepDelay },
        Step = 0.05,
        Callback = function(v) stepDelay = v end,
    })

    Tab:Divider()

    local fileName = "macro"
    Tab:Input({
        Title = "File Name",
        Value = fileName,
        Placeholder = "name without .json",
        Callback = function(txt) fileName = txt end,
    })

    Tab:Button({
        Title = "Save Macro",
        Callback = function()
            local ok, err = saveMacro(fileName)
            WindUI:Notify({ Title = ok and "Saved" or "Save Failed", Content = ok and ("Saved as " .. fileName .. ".json") or err, Duration = 4 })
        end,
    })

    local filesDrop
    filesDrop = Tab:Dropdown({
        Title = "Available Macros",
        Values = listMacros(),
        AllowNone = true,
        Multi = false,
        Callback = function(v)
            if not v or v == "" then return end
            local ok, err = loadMacro(v)
            WindUI:Notify({ Title = ok and "Loaded" or "Load Failed", Content = ok and ("Loaded " .. v) or err, Duration = 4 })
        end,
    })

    Tab:Button({
        Title = "Refresh List",
        Callback = function() filesDrop:Refresh(listMacros()) end,
    })

    Tab:Button({
        Title = "Delete Selected",
        Callback = function()
            if not hasFS then return end
            local selected = filesDrop:GetValue()
            if type(selected) == "table" then selected = selected[1] end
            if not selected or selected == "" then return end
            local path = MACRO_DIR .. "/" .. selected .. ".json"
            if exec.isfile and exec.isfile(path) and exec.delfile then exec.delfile(path) end
            filesDrop:Refresh(listMacros())
            WindUI:Notify({ Title = "Deleted", Content = selected, Duration = 3 })
        end,
    })

    Window:OnClose(function()
        PlayToggle:SetValue(false)
        RecordToggle:SetValue(false)
        stopPlayback()
        stopRecording()
    end)
else
    warn("WindUI failed to load; running headless recorder only.")
end

-- Expose a minimal public API if required by other scripts
return {
    StartRecording = startRecording,
    StopRecording = stopRecording,
    StartPlayback = startPlayback,
    StopPlayback = stopPlayback,
    SetPlayMode = function(mode) playMode = (mode == "Wave") and "Wave" or "Time" end,
    Save = saveMacro,
    Load = loadMacro,
    List = listMacros,
}


