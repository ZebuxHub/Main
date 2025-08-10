-- RemoteRecorder.lua
-- Records and replays specific RemoteFunction calls (PlaceUnit, UpgradeUnit)
-- with timing and wave (workspace Attribute "Round") metadata.

-- Dependencies: WindUI (fetched via HTTP), exploit env with: hookmetamethod, getnamecallmethod, checkcaller,
-- makefolder, writefile, readfile, isfile, listfiles.
-- luacheck: globals makefolder writefile readfile isfile listfiles hookmetamethod getnamecallmethod checkcaller

-- Access through _G to avoid undefined-global lints
local makefolder = rawget(_G, "makefolder") or function(_) end
local writefile = rawget(_G, "writefile") or function(_, _) end
local readfile = rawget(_G, "readfile") or function(_) return nil end
local isfile = rawget(_G, "isfile") or function(_) return false end
local listfiles = rawget(_G, "listfiles") or function(_) return {} end
local hookmetamethod = rawget(_G, "hookmetamethod") or function(_, _, fn) return fn end
local getnamecallmethod = rawget(_G, "getnamecallmethod") or function() return nil end
local checkcaller = rawget(_G, "checkcaller") or function() return false end

-- Configuration
local RECORDINGS_FOLDER = "RemoteRecorder"
local DEFAULT_WINDOW_SIZE = UDim2.fromOffset(560, 430)

-- Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ensure folder exists
pcall(function()
    makefolder(RECORDINGS_FOLDER)
end)

-- State
local currentRoundNumber = tonumber(workspace:GetAttribute("Round")) or 0
local recordingActive = false
local replayActive = false
local recordingStartClock = nil
local recordedEvents = {}
local lastEventId = 0
local recentSummaries = {}
local maxRecentVisible = 40
local macroStatusText = "None"
local waitingForText = "-"

-- UI State
local selectedFileName = ""
local gateReplayByWave = true
local timeScale = 1.0

-- Utility: Deep copy (for args capture safety)
local function deepCopy(value, seen)
    seen = seen or {}
    local ty = typeof(value)
    if ty == "table" then
        if seen[value] then return seen[value] end
        local t = {}
        seen[value] = t
        for k, v in pairs(value) do
            t[deepCopy(k, seen)] = deepCopy(v, seen)
        end
        return t
    end
    return value
end

-- Serialization for JSON-safe persistence
local function serializeValue(value)
    local ty = typeof(value)
    if ty == "CFrame" then
        local components = { value:GetComponents() }
        return { __type = "CFrame", components = components }
    elseif ty == "Vector3" then
        return { __type = "Vector3", x = value.X, y = value.Y, z = value.Z }
    elseif ty == "Vector2" then
        return { __type = "Vector2", x = value.X, y = value.Y }
    elseif ty == "Color3" then
        return { __type = "Color3", r = value.R, g = value.G, b = value.B }
    elseif ty == "EnumItem" then
        return { __type = "EnumItem", enumType = tostring(value.EnumType), name = value.Name }
    elseif ty == "Instance" then
        return { __type = "Instance", path = value:GetFullName() }
    elseif ty == "table" then
        local out = {}
        for k,v in pairs(value) do
            local key = typeof(k) == "string" and k or tostring(k)
            out[key] = serializeValue(v)
        end
        return out
    elseif ty == "function" or ty == "userdata" or ty == "thread" then
        return { __type = ty }
    else
        -- number, string, boolean, nil
        return value
    end
end

local function deserializeValue(value)
    if typeof(value) ~= "table" or value.__type == nil then
        return value
    end
    local t = value.__type
    if t == "CFrame" then
        return CFrame.new(table.unpack(value.components or {}))
    elseif t == "Vector3" then
        return Vector3.new(value.x or 0, value.y or 0, value.z or 0)
    elseif t == "Vector2" then
        return Vector2.new(value.x or 0, value.y or 0)
    elseif t == "Color3" then
        return Color3.new(value.r or 0, value.g or 0, value.b or 0)
    elseif t == "EnumItem" then
        local enumTypeStr, name = value.enumType, value.name
        local enumTypeName = enumTypeStr and enumTypeStr:match("Enum%.(.+)$")
        if enumTypeName and Enum[enumTypeName] and Enum[enumTypeName][name] then
            return Enum[enumTypeName][name]
        end
        return nil
    elseif t == "Instance" then
        -- Try to resolve path; best-effort.
        local ok, inst = pcall(function()
            return game:GetService(value.path:split(".")[1])
        end)
        if ok and inst then return inst end
        return nil
    else
        -- Recurse generic table
        local out = {}
        for k,v in pairs(value) do
            if k ~= "__type" then
                out[k] = deserializeValue(v)
            end
        end
        return out
    end
end

-- Current wave tracking
workspace:GetAttributeChangedSignal("Round"):Connect(function()
    local newVal = tonumber(workspace:GetAttribute("Round")) or 0
    currentRoundNumber = newVal
end)

local function getCurrentRound()
    return currentRoundNumber
end

-- Recording controls
local function startRecording()
    recordedEvents = {}
    lastEventId = 0
    recordingStartClock = os.clock()
    recordingActive = true
end

local function stopRecording()
    recordingActive = false
end

local function nextEventId()
    lastEventId += 1
    return lastEventId
end

-- Safe remote path builder (for readability)
local function remotePath(remote)
    local ok, path = pcall(function()
        return remote:GetFullName()
    end)
    if ok then return path end
    -- fallback
    local s = {}
    local inst = remote
    while inst and inst ~= game do
        table.insert(s, 1, inst.Name)
        inst = inst.Parent
    end
    return table.concat(s, "/")
end

-- Capture whitelist
local TARGETS = {
    RemoteFunction = {
        InvokeServer = {
            ["PlaceUnit"] = true,
            ["UpgradeUnit"] = true,
        }
    }
}

-- Hook once
if not _G.__RemoteRecorder_Hooked then
    _G.__RemoteRecorder_Hooked = true
    local originalNamecall
    originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod and getnamecallmethod() or nil
        local args = { ... }

        -- Avoid capturing our own calls
        if checkcaller and checkcaller() then
            return originalNamecall(self, ...)
        end

        -- Capture only if recording and target matches
        if recordingActive and typeof(self) == "Instance" then
            local classMatch = self.ClassName
            if classMatch == "RemoteFunction" and method == "InvokeServer" then
                if TARGETS.RemoteFunction.InvokeServer[self.Name] then
                    -- Do heavy work off the critical path
                    task.spawn(function()
                        local now = os.clock()
                        local event = {
                            id = nextEventId(),
                            t = now - (recordingStartClock or now),
                            wave = getCurrentRound(),
                            remoteClass = classMatch,
                            remoteName = self.Name,
                            remotePath = remotePath(self),
                            method = method,
                            args = {},
                        }
                        -- Serialize arguments
                        for i = 1, #args do
                            event.args[i] = serializeValue(deepCopy(args[i]))
                        end
                        table.insert(recordedEvents, event)

                        -- Update recent summaries and macro/status
                        local summary
                        if self.Name == "PlaceUnit" then
                            local unitName = typeof(args[1]) == "string" and args[1] or "?"
                            summary = string.format("[#%d] t=%.2fs wave=%s PlaceUnit(%s)", event.id, event.t or 0, tostring(event.wave), unitName)
                        elseif self.Name == "UpgradeUnit" then
                            local unitId = args[1] ~= nil and tostring(args[1]) or "?"
                            summary = string.format("[#%d] t=%.2fs wave=%s UpgradeUnit(%s)", event.id, event.t or 0, tostring(event.wave), unitId)
                        else
                            summary = string.format("[#%d] t=%.2fs wave=%s %s", event.id, event.t or 0, tostring(event.wave), tostring(self.Name))
                        end
                        table.insert(recentSummaries, summary)
                        if #recentSummaries > maxRecentVisible then table.remove(recentSummaries, 1) end
                        macroStatusText = "Recording"
                        if _G.__RR_updateRecordUI then _G.__RR_updateRecordUI() end
                    end)
                end
            end
        end

        return originalNamecall(self, ...)
    end)
end

-- File operations
local function listRecordingFiles()
    local files = {}
    for _, file in ipairs(listfiles(RECORDINGS_FOLDER)) do
        local name = file:match("([^/\\]+)%.json$")
        if name then table.insert(files, name) end
    end
    table.sort(files)
    return files
end

local function saveRecording(fileName)
    if not fileName or fileName == "" then return false, "Missing file name" end
    local payload = {
        version = 1,
        createdAt = os.time(),
        meta = {
            totalEvents = #recordedEvents,
        },
        events = recordedEvents,
    }
    local json = HttpService:JSONEncode(payload)
    writefile(RECORDINGS_FOLDER .. "/" .. fileName .. ".json", json)
    return true
end

local function loadRecording(fileName)
    local path = RECORDINGS_FOLDER .. "/" .. fileName .. ".json"
    if not isfile(path) then return nil, "File not found" end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok then return nil, "Invalid JSON" end
    return data
end

-- Replay
local function resolveRemote(event)
    -- Prefer strict path by navigating known tree for performance
    -- For our targets, we know they live in ReplicatedStorage/RemoteFunctions
    local ok, rf = pcall(function()
        return ReplicatedStorage:WaitForChild("RemoteFunctions", 1):WaitForChild(event.remoteName, 1)
    end)
    if ok and rf then return rf end
    -- Fallback: try generic lookup by name under ReplicatedStorage
    local candidate = ReplicatedStorage:FindFirstChild(event.remoteName, true)
    return candidate
end

local activeReplayTokens = {}

local function stopReplay()
    replayActive = false
    -- invalidate tokens
    for token in pairs(activeReplayTokens) do
        activeReplayTokens[token] = nil
    end
end

local function startReplay(data)
    if not data or typeof(data) ~= "table" or typeof(data.events) ~= "table" then return false, "Invalid data" end
    stopReplay()
    replayActive = true
    local startClock = os.clock()

    -- Sort by time for predictable scheduling
    table.sort(data.events, function(a,b)
        return (a.t or 0) < (b.t or 0)
    end)

    for idx, event in ipairs(data.events) do
        local token = newproxy(true)
        activeReplayTokens[token] = true
        task.spawn(function()
            -- Time gate + step delay (sequential-style extra spacing)
            local delaySeconds = math.max(0, (event.t or 0)) / (timeScale > 0 and timeScale or 1)
            if _G.__RR_stepDelaySec and _G.__RR_stepDelaySec > 0 then
                delaySeconds = delaySeconds + (_G.__RR_stepDelaySec * (idx - 1))
            end
            local elapsed = os.clock() - startClock
            if delaySeconds > elapsed then
                waitingForText = string.format("time: %.2fs", delaySeconds - elapsed)
                if _G.__RR_updateRecordUI then _G.__RR_updateRecordUI() end
                task.wait(delaySeconds - elapsed)
            end

            if not replayActive or not activeReplayTokens[token] then return end

            -- Wave gate
            if gateReplayByWave then
                local targetWave = tonumber(event.wave) or 0
                while replayActive and activeReplayTokens[token] and (getCurrentRound() < targetWave) do
                    waitingForText = string.format("wave >= %d", targetWave)
                    if _G.__RR_updateRecordUI then _G.__RR_updateRecordUI() end
                    task.wait(0.1)
                end
                if not replayActive or not activeReplayTokens[token] then return end
            end

            -- Resolve remote and args, then invoke
            local remote = resolveRemote(event)
            if remote and event.method == "InvokeServer" and remote.ClassName == "RemoteFunction" then
                macroStatusText = "Executing: " .. tostring(event.remoteName)
                if _G.__RR_updateRecordUI then _G.__RR_updateRecordUI() end
                local args = {}
                if typeof(event.args) == "table" then
                    for i = 1, #event.args do
                        args[i] = deserializeValue(event.args[i])
                    end
                end
                pcall(function()
                    remote:InvokeServer(table.unpack(args))
                end)
            end
            activeReplayTokens[token] = nil
            if idx == #data.events then
                macroStatusText = "Completed"
                waitingForText = "-"
                if _G.__RR_updateRecordUI then _G.__RR_updateRecordUI() end
            end
        end)
    end

    return true
end

-- WindUI setup
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local window = WindUI:CreateWindow({
    Title = "Remote Recorder",
    Icon = "database",
    Author = "Recorder",
    Folder = "RemoteRecorder",
    Size = DEFAULT_WINDOW_SIZE,
    Transparent = true,
    Theme = "Dark",
    User = { Enabled = false },
    KeySystem = nil,
})

local sectionMain = window:Section({ Title = "Recorder", Opened = true })
local sectionReplay = window:Section({ Title = "Replay", Opened = true })
local sectionFiles = window:Section({ Title = "Files", Opened = true })
local sectionStatus = window:Section({ Title = "Status", Opened = true })

local tabRecord = sectionMain:Tab({ Title = "Record", Icon = "radio" })
local tabReplay = sectionReplay:Tab({ Title = "Replay", Icon = "play" })
local tabFiles = sectionFiles:Tab({ Title = "Files", Icon = "file-cog" })
local tabStatus = sectionStatus:Tab({ Title = "Status", Icon = "list" })

-- Status elements
local statusParagraph = tabStatus:Paragraph({
    Title = "Recorder Status",
    Desc = "Idle",
    Image = "info",
    Color = "Grey",
})

local function updateStatus()
    local desc = string.format(
        "Recording: %s\nReplaying: %s\nEvents captured: %d\nCurrent wave: %d",
        tostring(recordingActive), tostring(replayActive), #recordedEvents, getCurrentRound()
    )
    statusParagraph:SetDesc(desc)
end

-- Record controls
local toggleRecord = tabRecord:Toggle({
    Title = "Record Macro",
    Desc = "Capture PlaceUnit and UpgradeUnit",
    Value = false,
    Callback = function(on)
        if on then
            startRecording()
            WindUI:Notify({ Title = "Recording started", Content = "Capturing remotes", Duration = 3 })
        else
            stopRecording()
            WindUI:Notify({ Title = "Recording stopped", Content = ("%d events"):format(#recordedEvents), Duration = 3 })
        end
        updateStatus()
    end
})

tabRecord:Button({
    Title = "Clear Recording",
    Callback = function()
        recordedEvents = {}
        lastEventId = 0
        recentSummaries = {}
        updateStatus()
        WindUI:Notify({ Title = "Cleared", Content = "Recording buffer emptied", Duration = 2 })
    end
})

-- Macro status & details
local macroStatusPara = tabRecord:Paragraph({ Title = "Macro Status", Desc = macroStatusText })
local actionPara = tabRecord:Paragraph({ Title = "Action", Desc = "-" })
local typePara = tabRecord:Paragraph({ Title = "Type", Desc = "-" })
local unitPara = tabRecord:Paragraph({ Title = "Unit", Desc = "-" })
local waitingPara = tabRecord:Paragraph({ Title = "Waiting for", Desc = waitingForText })

-- Live counters and recent actions
local recordCountParagraph = tabRecord:Paragraph({ Title = "Captured Steps", Desc = "0", Image = "hash", Color = "Grey" })
local recentParagraph = tabRecord:Paragraph({ Title = "Recent Actions", Desc = "(none)", Image = "list", Color = "Blue" })

-- Updater callable from hook/replay
_G.__RR_stepDelaySec = 0.2
_G.__RR_updateRecordUI = function()
    pcall(function()
        macroStatusPara:SetDesc(macroStatusText)
        waitingPara:SetDesc(waitingForText)
        recordCountParagraph:SetDesc(tostring(#recordedEvents))
        if #recordedEvents > 0 then
            local last = recordedEvents[#recordedEvents]
            actionPara:SetDesc(tostring(last.remoteName))
            typePara:SetDesc(tostring(last.method))
            if last.remoteName == "PlaceUnit" then
                local a1 = last.args and last.args[1]
                if typeof(a1) == "table" and a1.__type == nil then
                    unitPara:SetDesc(tostring(a1))
                else
                    unitPara:SetDesc(tostring(a1 and (a1.__type and "[serialized]" or a1) or "-"))
                end
            elseif last.remoteName == "UpgradeUnit" then
                unitPara:SetDesc(tostring(last.args and last.args[1] or "-"))
            else
                unitPara:SetDesc("-")
            end
        else
            actionPara:SetDesc("-")
            typePara:SetDesc("-")
            unitPara:SetDesc("-")
        end
        if #recentSummaries > 0 then
            recentParagraph:SetDesc(table.concat(recentSummaries, "\n"))
        else
            recentParagraph:SetDesc("(none)")
        end
    end)
end

tabRecord:Toggle({
    Title = "Play Macro",
    Value = false,
    Callback = function(on)
        if on then
            local ok, err = startReplay({ events = recordedEvents })
            if ok then
                WindUI:Notify({ Title = "Replay", Content = "Started", Duration = 2 })
            else
                WindUI:Notify({ Title = "Replay error", Content = tostring(err), Duration = 4 })
            end
        else
            stopReplay()
            WindUI:Notify({ Title = "Replay", Content = "Stopped", Duration = 2 })
        end
        updateStatus()
    end
})

tabRecord:Toggle({
    Title = "Auto Equip Macro Units",
    Value = false,
    Callback = function(on)
        -- Placeholder: Implement per-game equip logic if needed
        if on then
            WindUI:Notify({ Title = "Auto Equip", Content = "Not configured for this game", Duration = 3 })
        end
    end
})

tabRecord:Slider({
    Title = "Step Delay",
    Value = { Min = 0, Max = 2, Default = 0.2 },
    Step = 0.05,
    Callback = function(v)
        _G.__RR_stepDelaySec = tonumber(v) or 0
    end
})

tabRecord:Paragraph({
    Title = "What is recorded?",
    Desc = "RemoteFunction:InvokeServer calls on ReplicatedStorage/RemoteFunctions for PlaceUnit and UpgradeUnit. Each event stores time offset and wave (workspace Attribute 'Round').",
    Image = "help-circle",
    Color = "Blue",
})

-- Replay controls
local toggleWaveGate = tabReplay:Toggle({
    Title = "Gate by Wave (Round)",
    Value = gateReplayByWave,
    Callback = function(v)
        gateReplayByWave = v
    end
})

local timeScaleInput = tabReplay:Input({
    Title = "Time Scale",
    Value = tostring(timeScale),
    Placeholder = "1.0",
    Callback = function(txt)
        local val = tonumber(txt)
        if val and val > 0 then timeScale = val end
    end
})

tabReplay:Button({
    Title = "Start Replay (from memory)",
    Callback = function()
        local ok, err = startReplay({ events = recordedEvents })
        if ok then
            WindUI:Notify({ Title = "Replay", Content = "Started", Duration = 2 })
        else
            WindUI:Notify({ Title = "Replay error", Content = tostring(err), Duration = 4 })
        end
        updateStatus()
    end
})

tabReplay:Button({
    Title = "Stop Replay",
    Callback = function()
        stopReplay()
        WindUI:Notify({ Title = "Replay", Content = "Stopped", Duration = 2 })
        updateStatus()
    end
})

-- Files
local filesDropdown
filesDropdown = tabFiles:Dropdown({
    Title = "Saved Recordings",
    Values = listRecordingFiles(),
    Multi = false,
    AllowNone = true,
    Callback = function(name)
        selectedFileName = name or ""
    end
})

tabFiles:Button({
    Title = "Refresh List",
    Callback = function()
        filesDropdown:Refresh(listRecordingFiles())
    end
})

local fileNameText = ""
tabFiles:Input({
    Title = "File Name",
    Placeholder = "my_run",
    Callback = function(text)
        fileNameText = text
        selectedFileName = text
    end
})

tabFiles:Button({
    Title = "Save Recording to JSON",
    Callback = function()
        if #recordedEvents == 0 then
            WindUI:Notify({ Title = "Save", Content = "No events to save", Duration = 3 })
            return
        end
        local name = (fileNameText ~= "" and fileNameText) or selectedFileName
        if not name or name == "" then
            WindUI:Notify({ Title = "Save", Content = "Enter a file name", Duration = 3 })
            return
        end
        local ok, err = saveRecording(name)
        if ok then
            WindUI:Notify({ Title = "Saved", Content = name .. ".json", Duration = 3 })
            filesDropdown:Refresh(listRecordingFiles())
        else
            WindUI:Notify({ Title = "Save error", Content = tostring(err), Duration = 4 })
        end
    end
})

tabFiles:Button({
    Title = "Load And Replay From File",
    Callback = function()
        local name = selectedFileName
        if not name or name == "" then
            WindUI:Notify({ Title = "Load", Content = "Select a file first", Duration = 3 })
            return
        end
        local data, err = loadRecording(name)
        if not data then
            WindUI:Notify({ Title = "Load error", Content = tostring(err), Duration = 4 })
            return
        end
        local ok2, err2 = startReplay(data)
        if ok2 then
            WindUI:Notify({ Title = "Replay", Content = "Started from file", Duration = 3 })
        else
            WindUI:Notify({ Title = "Replay error", Content = tostring(err2), Duration = 4 })
        end
        updateStatus()
    end
})

-- Live status refresh
task.spawn(function()
    while true do
        updateStatus()
        task.wait(0.5)
    end
end)

window:OnClose(function()
    stopReplay()
    stopRecording()
end)


