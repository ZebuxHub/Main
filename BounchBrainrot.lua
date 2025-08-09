-- Bouch Brainrot automation using WindUI
-- Universal-ish: attempts to auto-detect your plot; allows manual override

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local Communication = ReplicatedStorage:WaitForChild("Communication")
local Remote_Sync = Communication:WaitForChild("Sync")
local Remote_Merge = Communication:WaitForChild("Merge")
local Remote_PurchaseBall = Communication:WaitForChild("PurchaseBall")
local Remote_UpgradeConveyor = Communication:WaitForChild("UpgradeConveyor")
local Remote_Rebirth = Communication:WaitForChild("Rebirth")
local TeleportService = game:GetService("TeleportService")

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- helpers
local function parseMoney(text)
    if typeof(text) ~= "string" then return 0 end
    local s = text:gsub(",", ""):gsub("%$", ""):gsub("%s+", ""):lower()
    if s == "" then return 0 end
    local num, suffix = s:match("^([%d%.]+)%s*([kmbt]?)$")
    num = tonumber(num or s) or 0
    local mult = 1
    if suffix == "k" then mult = 1e3 elseif suffix == "m" then mult = 1e6 elseif suffix == "b" then mult = 1e9 elseif suffix == "t" then mult = 1e12 end
    return num * mult
end

local function getLocalCash()
    local display
    pcall(function()
        display = LocalPlayer.PlayerGui.Main.Left.Currencies.Cash.Display
    end)
    if display and display:IsA("TextLabel") then
        return parseMoney(display.Text)
    end
    return 0
end

local function safeFind(instance, pathArray)
    local obj = instance
    for _, name in ipairs(pathArray) do
        if not obj then return nil end
        obj = obj:FindFirstChild(name)
    end
    return obj
end

local function autoDetectPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    -- Prefer plot that seems associated with the player via attribute/value
    local fallback
    for _, plot in ipairs(plots:GetChildren()) do
        local cur = plot:FindFirstChild("Cur")
        if cur then
            if not fallback then fallback = plot end
            local ownerAttr = plot:GetAttribute("Owner")
            if ownerAttr == LocalPlayer or ownerAttr == LocalPlayer.UserId or ownerAttr == LocalPlayer.Name then
                return plot
            end
            local owner = plot:FindFirstChild("Owner")
            if owner then
                local ok, val = pcall(function()
                    return owner.Value
                end)
                if ok and (val == LocalPlayer or val == LocalPlayer.Name) then
                    return plot
                end
            end
        end
    end
    return fallback
end

local selectedPlotName = nil
local cachedPlot
local lastPlotCheck = 0
local function getSelectedPlot()
    -- Reuse cached plot if still valid
    if cachedPlot and cachedPlot.Parent ~= nil then
        return cachedPlot
    end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    if selectedPlotName and plots:FindFirstChild(selectedPlotName) then
        cachedPlot = plots[selectedPlotName]
        return cachedPlot
    end
    -- Throttle auto-detect a bit to reduce overhead
    local now = os.clock()
    if now - lastPlotCheck > 1.0 then
        lastPlotCheck = now
        local detected = autoDetectPlot()
        if detected then
            selectedPlotName = detected.Name
            cachedPlot = detected
            return cachedPlot
        end
    end
    return nil
end

-- UI setup
local Window = WindUI:CreateWindow({
    Title = "Zebux",
    Icon = "brain",
    Author = "🧠 Bouch Brainrot",
    Folder = "BouchBrainrot",
    Size = UDim2.fromOffset(560, 420),
    Transparent = true,
    Theme = "Dark",
    HideSearchBar = false,
    ScrollBarEnabled = true,
})

local Tabs = {}
Tabs.MainSection = Window:Section({ Title = "⚙️ | Automation"})
Tabs.Main = Tabs.MainSection:Tab({ Title = "🎛️ | Main"})
Tabs.Settings = Tabs.MainSection:Tab({ Title = "🛠️ | Settings"})
Tabs.Info = Tabs.MainSection:Tab({ Title = "ℹ️ | Info"})


Tabs.Main:Divider()

-- (status indicators removed per user request)

-- Toggle states
local state = {
    AutoMoney = false,
    AutoMerge = false,
    AutoBuyPad = false,
    AutoBuyBrainrot = false,
    AutoUpgradeLuck = false,
    AutoRebirth = false,
    AutoRejoin = false,
}

-- Runners
local function startAutoMoney()
        task.spawn(function()
        while state.AutoMoney do
            -- Burst a few times per tick for speed, then tiny cooldown to reduce lag
            for _ = 1, 10 do
                local ok = pcall(function()
                    Remote_Sync:FireServer("1")
                end)
                if not ok then break end
            end
            task.wait(0.02)
        end
    end)
end

local function readMergeCost(plot)
    local label = safeFind(plot, {"Cur", "Merge", "Top", "Collect", "Cost", "Text"})
    if label and label:IsA("TextLabel") then
        return label.Text or ""
    end
    -- Sometimes last node could be a TextLabel named differently; try direct property on Cost
    local costNode = safeFind(plot, {"Cur", "Merge", "Top", "Collect", "Cost"})
    if costNode and costNode:IsA("TextLabel") then
        return costNode.Text or ""
    end
    return ""
end

local function readBuyPadCost(plot)
    local label = safeFind(plot, {"Cur", "BuyPad", "Top", "Collect", "Cost", "Text"})
    if label and label:IsA("TextLabel") then
        return label.Text or ""
    end
    local costNode = safeFind(plot, {"Cur", "BuyPad", "Top", "Collect", "Cost"})
    if costNode and costNode:IsA("TextLabel") then
        return costNode.Text or ""
    end
    return ""
end

local function readUpgradeConveyorCost(plot)
    local label = safeFind(plot, {"Cur", "UpgradeConveyor", "Top", "Collect", "Cost", "Text"})
    if label and label:IsA("TextLabel") then
        return label.Text or ""
    end
    local costNode = safeFind(plot, {"Cur", "UpgradeConveyor", "Top", "Collect", "Cost"})
    if costNode and costNode:IsA("TextLabel") then
        return costNode.Text or ""
    end
    return ""
end

local function readRebirthProgressText(plot)
    -- Prefer explicit Title TextLabel if present
    local titleNode = safeFind(plot, {"Cur", "Rebirth", "Top", "Collect", "Bar", "Title"})
    if titleNode and titleNode:IsA("TextLabel") then
        return titleNode.Text or ""
    end
    -- Fallback: scan for any TextLabel under Bar that contains a slash pattern
    local bar = safeFind(plot, {"Cur", "Rebirth", "Top", "Collect", "Bar"})
    if bar then
        for _, d in ipairs(bar:GetDescendants()) do
            if d:IsA("TextLabel") then
                local t = d.Text or ""
                if t:find("/") then
                    return t
                end
            end
        end
    end
    return ""
end

local function startAutoMerge(toggleRef)
    task.spawn(function()
        while state.AutoMerge do
            local plot = getSelectedPlot()
            if not plot then
                task.wait(0.25)
            else
                local costText = readMergeCost(plot)
                if costText == nil or costText == "" then
                    -- stop as requested when text is empty
                    state.AutoMerge = false
                    if toggleRef then toggleRef:SetValue(false) end
                    WindUI:Notify({ Title = "Merge", Content = "No merge cost available. Stopping.", Duration = 4 })
                    break
                end
                local have = getLocalCash()
                local need = parseMoney(costText)
                if have >= need and need > 0 then
                    pcall(function()
                        Remote_Merge:FireServer()
                    end)
                    task.wait(0.08)
                else
                    task.wait(0.12)
                end
            end
        end
        end)
    end

local function startAutoBuyPad()
    task.spawn(function()
        while state.AutoBuyPad do
            local plot = getSelectedPlot()
            if not plot then
                task.wait(0.25)
            else
                local costText = readBuyPadCost(plot)
                if costText ~= nil and costText ~= "" then
                    local have = getLocalCash()
                    local need = parseMoney(costText)
                    if have >= need and need > 0 then
                        pcall(function()
                            -- As per user instruction, uses Merge remote for BuyPad as well
                            Remote_Merge:FireServer()
                        end)
                        task.wait(0.08)
                    else
                        task.wait(0.12)
                    end
                else
                    task.wait(0.2)
                end
            end
        end
    end)
end

local function startAutoBuyBrainrot()
    task.spawn(function()
        while state.AutoBuyBrainrot do
            -- Fire 1..30 in a tight burst to minimize scheduler overhead
            for i = 1, 30 do
                pcall(function()
                    Remote_PurchaseBall:FireServer(tostring(i))
                end)
            end
            task.wait(0.03)
        end
    end)
end

local function startAutoUpgradeLuck(toggleRef)
    task.spawn(function()
        while state.AutoUpgradeLuck do
            local plot = getSelectedPlot()
            if not plot then
                task.wait(0.25)
            else
                local costText = readUpgradeConveyorCost(plot)
                if costText ~= nil and costText ~= "" then
                    local have = getLocalCash()
                    local need = parseMoney(costText)
                    if have >= need and need > 0 then
                        pcall(function()
                            Remote_UpgradeConveyor:FireServer()
                        end)
                        task.wait(0.08)
                    else
                        task.wait(0.12)
                    end
                else
                    -- If text is empty, stop automatically as requested
                    state.AutoUpgradeLuck = false
                    if toggleRef then toggleRef:SetValue(false) end
                    WindUI:Notify({ Title = "Upgrade Luck", Content = "No upgrade cost available. Stopping.", Duration = 4 })
                    break
                end
            end
        end
    end)
end

local function startAutoRebirth()
    task.spawn(function()
        while state.AutoRebirth do
            local plot = getSelectedPlot()
            if not plot then
                task.wait(0.25)
            else
                local text = readRebirthProgressText(plot)
                if text and text ~= "" then
                    -- Normalize string (remove commas/spaces)
                    text = text:gsub(",", ""):gsub("%s+", "")
                    -- Handle cases like $622M/$18M, 622M/18M, 622,000,000/18,000,000
                    local left, right = text:match("^([^/]+)/(.+)$")
                    if left and right then
                        local cur = parseMoney(left)
                        local req = parseMoney(right)
                        if req > 0 and cur >= req then
                            pcall(function()
                                Remote_Rebirth:FireServer()
                            end)
                            task.wait(0.2)
                        else
                            task.wait(0.1)
                        end
                    else
                        task.wait(0.2)
                    end
                else
                    task.wait(0.2)
                end
    end
end
    end)
end

-- UI elements
local autoMoneyToggle, autoMergeToggle, autoBuyPadToggle, autoBuyBrainrotToggle, autoUpgradeLuckToggle, autoRebirthToggle

autoMoneyToggle = Tabs.Main:Toggle({
    Title = "💵 Auto Money",
    Desc = "Make money super fast!",
    Value = false,
    Callback = function(v)
        state.AutoMoney = v
        if v then startAutoMoney() end
    end
})
Tabs.Main:Divider()

autoMergeToggle = Tabs.Main:Toggle({
    Title = "🧩 Auto Merge",
    Desc = "Merge when you can.",
    Value = false,
    Callback = function(v)
        state.AutoMerge = v
        if v then startAutoMerge(autoMergeToggle) end
    end
})
Tabs.Main:Divider()

autoBuyPadToggle = Tabs.Main:Toggle({
    Title = "🛒 Auto Buy Pad",
    Desc = "Buy pad when you have enough.",
    Value = false,
    Callback = function(v)
        state.AutoBuyPad = v
        if v then startAutoBuyPad() end
    end
})
Tabs.Main:Divider()

autoBuyBrainrotToggle = Tabs.Main:Toggle({
    Title = "🧠 Auto Buy Brainrot",
    Desc = "Buy super fast!",
    Value = false,
    Callback = function(v)
        state.AutoBuyBrainrot = v
        if v then startAutoBuyBrainrot() end
    end
})
Tabs.Main:Divider()

autoUpgradeLuckToggle = Tabs.Main:Toggle({
    Title = "🍀 Auto Upgrade Luck",
    Desc = "Upgrade when you have enough.",
    Value = false,
    Callback = function(v)
        state.AutoUpgradeLuck = v
        if v then startAutoUpgradeLuck(autoUpgradeLuckToggle) end
    end
})
Tabs.Main:Divider()

autoRebirthToggle = Tabs.Main:Toggle({
    Title = "🔁 Auto Rebirth",
    Desc = "Rebirth when bar is full.",
    Value = false,
    Callback = function(v)
        state.AutoRebirth = v
        if v then startAutoRebirth() end
    end
})
Tabs.Main:Divider()

Window:SelectTab(1)

WindUI:Notify({ Title = "Bouch Brainrot", Content = "Loaded.", Duration = 4 })



-- Settings: Save/Load Config
do
    local function ensureFolders()
        if typeof(_G.makefolder) == "function" then
            pcall(function() _G.makefolder("BouchBrainrot") end)
            pcall(function() _G.makefolder("BouchBrainrot/config") end)
        end
    end
    ensureFolders()

    local function listConfigs()
        local files = {}
        local ok, list = pcall(function()
            if typeof(_G.listfiles) == "function" then
                return _G.listfiles("BouchBrainrot/config")
            end
            return {}
        end)
        if ok and list then
            for _, f in ipairs(list) do
                local name = f:match("([^/\\]+)%.json$")
                if name then table.insert(files, name) end
            end
        end
        table.sort(files)
        return files
    end

    local currentConfigName = "default"
    Tabs.Settings:Section({ Title = "💾 Config" })

    Tabs.Settings:Input({
        Title = "Config Name",
        Placeholder = "default",
        Callback = function(text)
            currentConfigName = (text ~= "" and text) or "default"
        end
    })

    local function buildState()
        return {
            AutoMoney = state.AutoMoney,
            AutoMerge = state.AutoMerge,
            AutoBuyPad = state.AutoBuyPad,
            AutoBuyBrainrot = state.AutoBuyBrainrot,
            AutoUpgradeLuck = state.AutoUpgradeLuck,
            AutoRebirth = state.AutoRebirth,
        }
    end

    Tabs.Settings:Button({
        Title = "💾 Save Config",
        Callback = function()
            ensureFolders()
            local path = string.format("BouchBrainrot/config/%s.json", currentConfigName)
            local data = buildState()
            local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
            if not ok then
                WindUI:Notify({ Title = "Save Failed", Content = "JSON encode error", Duration = 4 })
                return
            end
            if typeof(_G.writefile) ~= "function" then
                WindUI:Notify({ Title = "Save Failed", Content = "Executor does not support writefile", Duration = 4 })
                return
            end
            pcall(function() _G.writefile(path, json) end)
            WindUI:Notify({ Title = "Saved", Content = "Saved to " .. currentConfigName .. ".json", Duration = 4 })
        end
    })

    Tabs.Settings:Button({
        Title = "📂 Load Config",
        Callback = function()
            local path = string.format("BouchBrainrot/config/%s.json", currentConfigName)
            if typeof(_G.isfile) ~= "function" or typeof(_G.readfile) ~= "function" then
                WindUI:Notify({ Title = "Load Failed", Content = "Executor does not support file ops", Duration = 4 })
                return
            end
            local ok, exists = pcall(function() return _G.isfile(path) end)
            if ok and exists then
                local ok2, json = pcall(function() return _G.readfile(path) end)
                if ok2 and json then
                    local ok3, data = pcall(function() return HttpService:JSONDecode(json) end)
                    if ok3 and type(data) == "table" then
                        if type(data.AutoMoney) == "boolean" then autoMoneyToggle:SetValue(data.AutoMoney) end
                        if type(data.AutoMerge) == "boolean" then autoMergeToggle:SetValue(data.AutoMerge) end
                        if type(data.AutoBuyPad) == "boolean" then autoBuyPadToggle:SetValue(data.AutoBuyPad) end
                        if type(data.AutoBuyBrainrot) == "boolean" then autoBuyBrainrotToggle:SetValue(data.AutoBuyBrainrot) end
                        if type(data.AutoUpgradeLuck) == "boolean" then autoUpgradeLuckToggle:SetValue(data.AutoUpgradeLuck) end
                        if type(data.AutoRebirth) == "boolean" then autoRebirthToggle:SetValue(data.AutoRebirth) end
                        WindUI:Notify({ Title = "Loaded", Content = currentConfigName, Duration = 4 })
                    else
                        WindUI:Notify({ Title = "Load Failed", Content = "Bad JSON format", Duration = 4 })
                    end
                end
            else
                WindUI:Notify({ Title = "Load Failed", Content = "File not found", Duration = 4 })
            end
        end
    })

    Tabs.Settings:Section({ Title = "🗂️ Files" })

    local configsDropdown
    configsDropdown = Tabs.Settings:Dropdown({
        Title = "Choose Config",
        Values = listConfigs(),
        AllowNone = true,
        Multi = false,
        Callback = function(name)
            if name and name ~= "" then currentConfigName = name end
        end
    })

    Tabs.Settings:Button({
        Title = "🔄 Refresh List",
        Callback = function()
            configsDropdown:Refresh(listConfigs())
        end
    })

    Tabs.Settings:Section({ Title = "⏰ Rejoin" })

    local rejoinMinutes = 0
    Tabs.Settings:Slider({
        Title = "Rejoin after (minutes)",
        Value = { Min = 0, Max = 120, Default = 0 },
        Callback = function(val)
            rejoinMinutes = tonumber(val) or 0
        end
    })

    Tabs.Settings:Toggle({
        Title = "🔁 Auto Rejoin",
        Desc = "Rejoin server after X minutes",
        Value = false,
        Callback = function(v)
            state.AutoRejoin = v
            if v and rejoinMinutes > 0 then
                task.spawn(function()
                    local start = os.clock()
                    while state.AutoRejoin do
                        local elapsedMin = (os.clock() - start) / 60
                        if elapsedMin >= rejoinMinutes then
                            -- Try rejoining
                            pcall(function()
                                local placeId = game.PlaceId
                                local jobId = game.JobId
                                if jobId and jobId ~= "" then
                                    TeleportService:TeleportToPlaceInstance(placeId, jobId, Players.LocalPlayer)
                                else
                                    TeleportService:Teleport(placeId, Players.LocalPlayer)
                                end
                            end)
                            break
                        end
                        task.wait(1)
                    end
                end)
            end
        end
    })
end


-- Info tab: Discord copy button
do
    local invite = "https://discord.gg/ceAb3N7j5n"
    Tabs.Info:Paragraph({ Title = "Discord", Desc = "Join our server!" })
    Tabs.Info:Button({
        Title = "📋 Copy Discord Link",
        Callback = function()
            if typeof(_G.setclipboard) == "function" then
                pcall(function() _G.setclipboard(invite) end)
                WindUI:Notify({ Title = "Copied!", Content = "Link copied: discord.gg/ceAb3N7j5n", Duration = 4 })
            else
                WindUI:Notify({ Title = "Clipboard", Content = invite, Duration = 6 })
            end
        end
    })
end

