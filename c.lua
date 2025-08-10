-- Remote Recorder using WindUI
-- Records specific RemoteFunction calls (PlaceUnit, UpgradeUnit), captures time and wave, saves/loads JSON, and replays by time and/or wave.

-- Load WindUI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Configurable targets
local TARGET_REMOTES = {
    ["PlaceUnit"] = true,
    ["UpgradeUnit"] = true,
}

local REC_FOLDER = "WindUI/Recordings"
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Ensure folders
pcall(function()
    makefolder("WindUI")
end)
pcall(function()
    makefolder(REC_FOLDER)
end)

-- Utility: safe attribute read
local function getCurrentWave()
    local success, value = pcall(function()
        return Workspace:GetAttribute("Round")
    end)
    if success and typeof(value) == "number" then
        return value
    end
    return nil
end

-- Serialization helpers
local function serializeValue(value, visited)
    visited = visited or {}

    local vtype = typeof(value)
    if vtype == "nil" or vtype == "boolean" or vtype == "number" or vtype == "string" then
        return value
    elseif vtype == "Vector3" then
        return { __type = "Vector3", x = value.X, y = value.Y, z = value.Z }
    elseif vtype == "CFrame" then
        local c = { value:GetComponents() }
        return { __type = "CFrame", components = c }
    elseif vtype == "Color3" then
        return { __type = "Color3", r = value.R, g = value.G, b = value.B }
    elseif vtype == "table" then
        if visited[value] then
            return { __type = "[Circular]" }
        end
        visited[value] = true
        local out = {}
        for k, v in pairs(value) do
            local sk = serializeValue(k, visited)
            local sv = serializeValue(v, visited)
            out[sk] = sv
        end
        return out
    else
        -- Attempt to detect vector-like tables (e.g., custom vector.create)
        local ok, x = pcall(function() return value.X end)
        if ok and typeof(x) == "number" then
            local y = value.Y; local z = value.Z
            if typeof(y) == "number" and typeof(z) == "number" then
                return { __type = "Vector3", x = x, y = y, z = z }
            end
        end
        -- Fallback to string
        return tostring(value)
    end
end

local function deserializeValue(value)
    if typeof(value) ~= "table" then
        return value
    end
    if value.__type == "Vector3" then
        local ctor
        local ok = pcall(function()
            ctor = (getfenv and getfenv().vector and getfenv().vector.create) or nil
        end)
        if ok and ctor then
            return ctor(value.x, value.y, value.z)
        end
        return Vector3.new(value.x, value.y, value.z)
    elseif value.__type == "CFrame" then
        return CFrame.new(table.unpack(value.components))
    elseif value.__type == "Color3" then
        return Color3.new(value.r, value.g, value.b)
    elseif value.__type == "[Circular]" then
        return nil
    end
    -- Generic table map
    local out = {}
    for k, v in pairs(value) do
        out[deserializeValue(k)] = deserializeValue(v)
    end
    return out
end

-- Recording state
local isRecording = false
local isReplaying = false
local recordStartTime = 0
local events = {}
local statusLog = {}

local function now()
    return tick()
end

local function logStatus(msg)
    table.insert(statusLog, os.date("!%H:%M:%S") .. " | " .. msg)
    if #statusLog > 200 then
        table.remove(statusLog, 1)
    end
end

-- UI Setup
local Window = WindUI:CreateWindow({
    Title = "Remote Recorder",
    Icon = "record",
    Author = "Recorder",
    Folder = "WindUI",
    Size = UDim2.fromOffset(620, 480),
    Transparent = true,
    Theme = "Dark",
})

local Section = Window:Section({ Title = "Recorder", Opened = true })
local RecordTab = Section:Tab({ Title = "Record", Icon = "circle" })
local ReplayTab = Section:Tab({ Title = "Replay", Icon = "play" })
local FilesTab  = Section:Tab({ Title = "Files", Icon = "file-cog" })
local StatusTab = Section:Tab({ Title = "Status", Icon = "align-left", ShowTabTitle = true })

-- Status UI
local statusParagraph = StatusTab:Paragraph({
    Title = "Status",
    Desc = "Idle",
    Image = "info",
    ImageSize = 22,
})

local function refreshStatus()
    local wave = getCurrentWave()
    local lines = {
        "Recording: " .. tostring(isRecording),
        "Replaying: " .. tostring(isReplaying),
        "Events: " .. tostring(#events),
        "Current Wave: " .. tostring(wave or "N/A"),
    }
    -- Append last ~6 log lines
    local startIdx = math.max(1, #statusLog - 6)
    for i = startIdx, #statusLog do
        table.insert(lines, statusLog[i])
    end
    statusParagraph:SetDesc(table.concat(lines, "\n"))
end

-- Periodic status updater
task.spawn(function()
    while true do
        refreshStatus()
        task.wait(0.5)
    end
end)

-- Recorder controls
RecordTab:Button({
    Title = "Start Recording",
    Variant = "Primary",
    Callback = function()
        if isRecording then return end
        events = {}
        recordStartTime = now()
        isRecording = true
        logStatus("Recording started")
        refreshStatus()
    end
})

RecordTab:Button({
    Title = "Stop Recording",
    Variant = "Secondary",
    Callback = function()
        if not isRecording then return end
        isRecording = false
        logStatus("Recording stopped (" .. tostring(#events) .. " events)")
        refreshStatus()
    end
})

RecordTab:Button({
    Title = "Clear Events",
    Variant = "Tertiary",
    Callback = function()
        events = {}
        logStatus("Events cleared")
        refreshStatus()
    end
})

local lastEventCode = RecordTab:Code({
    Title = "Last Captured Event (JSON)",
    Code = "{}",
})

-- Replay settings
local replayMode = "Time" -- Time | Wave | Both
local speedMultiplier = 1.0

ReplayTab:Dropdown({
    Title = "Replay Mode",
    Values = { "Time", "Wave", "Both" },
    Value = "Time",
    Callback = function(v)
        replayMode = v
        logStatus("Replay mode set to " .. v)
    end
})

ReplayTab:Slider({
    Title = "Speed Multiplier (Time mode)",
    Value = { Min = 0.1, Max = 5.0, Default = 1.0 },
    Step = 0.1,
    Callback = function(v)
        speedMultiplier = v
        logStatus("Speed multiplier set to " .. tostring(v))
    end
})

-- File helpers
local function listRecordingFiles()
    local files = {}
    for _, path in ipairs(listfiles(REC_FOLDER)) do
        if path:match("%.json$") then
            table.insert(files, path:match("([^/\\]+)$"))
        end
    end
    table.sort(files)
    return files
end

local function saveToFile(fileName)
    local payload = {
        meta = {
            createdAt = os.time(),
            gameId = game.GameId,
            placeId = game.PlaceId,
            version = 1,
        },
        events = events,
    }
    local json = HttpService:JSONEncode(payload)
    writefile(REC_FOLDER .. "/" .. fileName .. ".json", json)
end

local function loadFromFile(fileName)
    local path = REC_FOLDER .. "/" .. fileName .. ".json"
    if not isfile(path) then return false, "File not found" end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or typeof(data) ~= "table" then
        return false, "Invalid JSON"
    end
    if typeof(data.events) ~= "table" then
        return false, "Missing events"
    end
    events = data.events
    return true
end

-- Files UI
local fileNameInput = "session_" .. os.date("!%Y%m%d_%H%M%S")
FilesTab:Input({
    Title = "Recording Name",
    Value = fileNameInput,
    Placeholder = "file name",
    Callback = function(v) fileNameInput = v end,
})

FilesTab:Button({
    Title = "Save JSON",
    Variant = "Primary",
    Callback = function()
        if fileNameInput == "" then return end
        local ok, err = pcall(function()
            saveToFile(fileNameInput)
        end)
        if ok then
            logStatus("Saved to " .. fileNameInput .. ".json")
        else
            logStatus("Save failed: " .. tostring(err))
        end
        refreshStatus()
    end
})

local filesDropdown = FilesTab:Dropdown({
    Title = "Available Recordings",
    Values = listRecordingFiles(),
    AllowNone = true,
    Callback = function() end
})

FilesTab:Button({
    Title = "Refresh List",
    Callback = function()
        filesDropdown:Refresh(listRecordingFiles())
    end
})

FilesTab:Button({
    Title = "Load Selected",
    Variant = "Secondary",
    Callback = function()
        local selected = filesDropdown:GetValue()
        if not selected or selected == "" then return end
        selected = selected:gsub("%.json$", "")
        local ok, err = loadFromFile(selected)
        if ok then
            logStatus("Loaded " .. selected .. ".json (" .. tostring(#events) .. " events)")
        else
            logStatus("Load failed: " .. tostring(err))
        end
        refreshStatus()
    end
})

-- Hook remote calls
local originalNamecall
originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if method == "InvokeServer" and isRecording and not isReplaying then
        local remoteName = tostring(self.Name)
        local parentName = self.Parent and self.Parent.Name or ""
        local grandName = self.Parent and self.Parent.Parent and self.Parent.Parent.Name or ""

        local shouldCapture = TARGET_REMOTES[remoteName] and parentName == "RemoteFunctions" and grandName == "ReplicatedStorage"
        if shouldCapture then
            local capturedArgs = { ... }

            -- Serialize args
            local serialArgs = {}
            for i = 1, #capturedArgs do
                serialArgs[i] = serializeValue(capturedArgs[i])
            end

            local event = {
                t = now() - recordStartTime,
                wave = getCurrentWave(),
                remote = remoteName,
                path = "ReplicatedStorage/RemoteFunctions/" .. remoteName,
                method = method,
                args = serialArgs,
            }
            table.insert(events, event)
            local preview = HttpService:JSONEncode(event)
            lastEventCode:SetCode(preview)
            logStatus("Captured " .. remoteName)
        end
    end
    return originalNamecall(self, ...)
end)

-- Replay helpers
local function resolveRemote(path)
    -- path format: ReplicatedStorage/RemoteFunctions/Name
    local parts = string.split(path, "/")
    local node = game
    for _, p in ipairs(parts) do
        if p ~= "" and p ~= "game" then
            node = node:FindFirstChild(p)
            if not node then return nil end
        end
    end
    return node
end

local function invokeEvent(ev)
    local remote = resolveRemote(ev.path)
    if not remote then
        logStatus("Remote not found: " .. tostring(ev.path))
        return
    end
    local args = {}
    for i = 1, #ev.args do
        args[i] = deserializeValue(ev.args[i])
    end
    local ok, err = pcall(function()
        if ev.method == "InvokeServer" then
            remote:InvokeServer(table.unpack(args))
        else
            -- extend if needed
        end
    end)
    if not ok then
        logStatus("Invoke failed: " .. tostring(err))
    end
end

local function replayByTime()
    if #events == 0 then
        logStatus("No events to replay")
        return
    end
    isReplaying = true
    logStatus("Replay (Time) started")

    -- Sort by time
    local ordered = table.clone(events)
    table.sort(ordered, function(a, b) return (a.t or 0) < (b.t or 0) end)

    local t0 = now()
    for idx, ev in ipairs(ordered) do
        local delaySec = math.max(0, (ev.t or 0) / math.max(0.001, speedMultiplier))
        task.delay(delaySec, function()
            if isReplaying then
                invokeEvent(ev)
                if idx == #ordered then
                    isReplaying = false
                    logStatus("Replay (Time) finished in " .. string.format("%.2f", now() - t0) .. "s")
                end
            end
        end)
    end
end

local function replayByWave(matchAlsoTime)
    if #events == 0 then
        logStatus("No events to replay")
        return
    end
    isReplaying = true
    logStatus("Replay (Wave" .. (matchAlsoTime and "+Time" or "") .. ") armed")

    -- Group events by wave
    local byWave = {}
    for _, ev in ipairs(events) do
        local w = ev.wave or -1
        byWave[w] = byWave[w] or {}
        table.insert(byWave[w], ev)
    end
    for _, list in pairs(byWave) do
        table.sort(list, function(a, b)
            return (a.t or 0) < (b.t or 0)
        end)
    end

    local connection
    connection = Workspace:GetAttributeChangedSignal("Round"):Connect(function()
        if not isReplaying then
            if connection then connection:Disconnect() end
            return
        end
        local cur = getCurrentWave()
        if cur == nil then return end
        local bucket = byWave[cur]
        if bucket and #bucket > 0 then
            logStatus("Wave " .. tostring(cur) .. " matched; replaying " .. tostring(#bucket) .. " events")
            local startTime = now()
            for idx, ev in ipairs(bucket) do
                if matchAlsoTime then
                    local delaySec = math.max(0, (ev.t or 0))
                    task.delay(delaySec, function()
                        if isReplaying then
                            invokeEvent(ev)
                        end
                    end)
                else
                    task.spawn(function()
                        if isReplaying then
                            invokeEvent(ev)
                        end
                    end)
                end
            end
            byWave[cur] = nil
            -- If all buckets consumed, finish
            local remaining = 0
            for _, list in pairs(byWave) do
                if list and #list > 0 then remaining += 1 end
            end
            if remaining == 0 then
                isReplaying = false
                if connection then connection:Disconnect() end
                logStatus("Replay (Wave) finished")
            end
        end
    end)
end

ReplayTab:Button({
    Title = "Start Replay",
    Variant = "Primary",
    Callback = function()
        if isReplaying then return end
        if replayMode == "Time" then
            replayByTime()
        elseif replayMode == "Wave" then
            replayByWave(false)
        else -- Both
            replayByWave(true)
        end
        refreshStatus()
    end
})

ReplayTab:Button({
    Title = "Stop Replay",
    Variant = "Secondary",
    Callback = function()
        if isReplaying then
            isReplaying = false
            logStatus("Replay stopped")
            refreshStatus()
        end
    end
})

-- Initial status
logStatus("Ready. Targeting: PlaceUnit, UpgradeUnit")
refreshStatus()


