-- Dashboard Integration Module for Build A Zoo
-- Sends real-time stats and receives commands from web dashboard
-- Created by Zebux

local DashboardIntegration = {}

-- ============ CONFIGURATION ============
local DASHBOARD_URL = "http://localhost:3000" -- Change to your deployed URL later
local UPDATE_INTERVAL = 30 -- Send stats every 30 seconds
local RETRY_DELAY = 5 -- Retry failed requests after 5 seconds

-- ============ SERVICES ============
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Wait for RemoteEvent (created by server handler)
local DashboardRemote = ReplicatedStorage:WaitForChild("DashboardRemote", 10)
if not DashboardRemote then
    warn("[Dashboard] ❌ DashboardRemote not found!")
    warn("[Dashboard] ⚠️  Make sure DashboardIntegration_ServerHandler.lua is running on the server")
    warn("[Dashboard] 📖 See ROBLOX_SERVER_SETUP.md for instructions")
end

-- ============ STATE ============
local isRunning = false
local lastUpdateTime = 0
local updateThread = nil
local commandListenerThread = nil
local dashboardEnabled = false

-- ============ HELPER FUNCTIONS ============

-- Get player's net worth
local function getPlayerNetWorth()
    if not LocalPlayer then return 0 end
    local attrValue = LocalPlayer:GetAttribute("NetWorth")
    if type(attrValue) == "number" then return attrValue end
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local netWorthValue = leaderstats:FindFirstChild("NetWorth")
        if netWorthValue and type(netWorthValue.Value) == "number" then
            return netWorthValue.Value
        end
    end
    return 0
end

-- Get current island
local function getAssignedIslandName()
    if not LocalPlayer then return "Unknown" end
    local success, islandName = pcall(function()
        return LocalPlayer:GetAttribute("AssignedIslandName")
    end)
    return success and islandName or "Unknown"
end

-- Get total eggs in inventory
local function getTotalEggs()
    local count = 0
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = playerGui and playerGui:FindFirstChild("Data")
    local eggContainer = data and data:FindFirstChild("Egg")
    
    if eggContainer then
        for _, child in ipairs(eggContainer:GetChildren()) do
            if #child:GetChildren() == 0 then -- Available egg
                count = count + 1
            end
        end
    end
    
    return count
end

-- Get total pets owned
local function getTotalPets()
    local count = 0
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = playerGui and playerGui:FindFirstChild("Data")
    local petsFolder = data and data:FindFirstChild("Pets")
    
    if petsFolder then
        count = #petsFolder:GetChildren()
    end
    
    return count
end

-- Get total placed pets
local function getTotalPlacedPets()
    local count = 0
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    
    if playerBuiltBlocks then
        for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
            if model:IsA("Model") then
                local userId = model:GetAttribute("UserId")
                if userId and tonumber(userId) == LocalPlayer.UserId then
                    count = count + 1
                end
            end
        end
    end
    
    return count
end

-- Get automation status
local function getAutomationStatus()
    return {
        autoBuy = _G.ZebuxState and autoBuyEnabled or false,
        autoPlace = _G.ZebuxState and autoPlaceEnabled or false,
        autoHatch = _G.ZebuxState and autoHatchEnabled or false,
        autoClaim = _G.ZebuxState and autoClaimEnabled or false,
        autoFeed = _G.ZebuxState and autoFeedEnabled or false,
        autoUpgrade = _G.ZebuxState and autoUpgradeEnabled or false,
        autoBuyFruit = _G.ZebuxState and autoBuyFruitEnabled or false
    }
end

-- Get pet speed stats
local function getPetSpeedStats()
    local speeds = {}
    local totalSpeed = 0
    local fastestSpeed = 0
    local slowestSpeed = math.huge
    local avgSpeed = 0
    
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = playerGui and playerGui:FindFirstChild("Data")
    local petsFolder = data and data:FindFirstChild("Pets")
    
    if petsFolder then
        local petCount = 0
        for _, petConfig in ipairs(petsFolder:GetChildren()) do
            if petConfig:IsA("Configuration") then
                local speed = petConfig:GetAttribute("S") or petConfig:GetAttribute("Speed") or 0
                if type(speed) == "number" and speed > 0 then
                    table.insert(speeds, speed)
                    totalSpeed = totalSpeed + speed
                    fastestSpeed = math.max(fastestSpeed, speed)
                    slowestSpeed = math.min(slowestSpeed, speed)
                    petCount = petCount + 1
                end
            end
        end
        
        if petCount > 0 then
            avgSpeed = totalSpeed / petCount
        end
    end
    
    return {
        fastest = fastestSpeed,
        slowest = slowestSpeed == math.huge and 0 or slowestSpeed,
        average = avgSpeed,
        total = totalSpeed
    }
end

-- Get egg type breakdown
local function getEggStats()
    local eggTypes = {}
    local mutations = {}
    
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = playerGui and playerGui:FindFirstChild("Data")
    local eggContainer = data and data:FindFirstChild("Egg")
    
    if eggContainer then
        for _, child in ipairs(eggContainer:GetChildren()) do
            if #child:GetChildren() == 0 then -- Available egg
                local eggType = child:GetAttribute("T") or "Unknown"
                local mutation = child:GetAttribute("M")
                
                eggTypes[eggType] = (eggTypes[eggType] or 0) + 1
                
                if mutation and mutation ~= "" then
                    mutations[mutation] = (mutations[mutation] or 0) + 1
                end
            end
        end
    end
    
    return {
        types = eggTypes,
        mutations = mutations
    }
end

-- Get conveyor level
local function getConveyorLevel()
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = playerGui and playerGui:FindFirstChild("Data")
    local gameFlag = data and data:FindFirstChild("GameFlag")
    
    if gameFlag then
        return gameFlag:GetAttribute("Conveyor") or 0
    end
    
    return 0
end

-- Get performance metrics
local function getPerformanceMetrics()
    local fps = 0
    local ping = 0
    
    -- Calculate FPS
    pcall(function()
        fps = math.floor(1 / RunService.Heartbeat:Wait())
    end)
    
    -- Get ping
    pcall(function()
        ping = LocalPlayer:GetNetworkPing() * 1000 -- Convert to ms
    end)
    
    return {
        fps = fps,
        ping = math.floor(ping),
        memoryUsage = math.floor(gcinfo() / 1024) -- MB
    }
end

-- ============ DASHBOARD COMMUNICATION ============

-- Collect all stats
local function collectAccountStats()
    local petSpeedStats = getPetSpeedStats()
    local eggStats = getEggStats()
    local automation = getAutomationStatus()
    local performance = getPerformanceMetrics()
    
    return {
        -- Account Info
        accountId = tostring(LocalPlayer.UserId),
        username = LocalPlayer.Name,
        displayName = LocalPlayer.DisplayName,
        
        -- Economy
        money = getPlayerNetWorth(),
        
        -- Inventory
        totalEggs = getTotalEggs(),
        totalPets = getTotalPets(),
        placedPets = getTotalPlacedPets(),
        
        -- Progress
        currentIsland = getAssignedIslandName(),
        conveyorLevel = getConveyorLevel(),
        
        -- Pet Stats
        petSpeed = {
            fastest = petSpeedStats.fastest,
            slowest = petSpeedStats.slowest,
            average = petSpeedStats.average,
            total = petSpeedStats.total
        },
        
        -- Egg Breakdown
        eggStats = eggStats,
        
        -- Automation Status
        automation = automation,
        
        -- Performance
        performance = performance,
        
        -- Timestamp
        lastUpdate = os.time(),
        
        -- Game Info
        placeId = game.PlaceId,
        jobId = game.JobId
    }
end

-- Register account with dashboard
local function registerAccount()
    if not DashboardRemote then
        warn("[Dashboard] ❌ Cannot register: DashboardRemote not available")
        warn("[Dashboard] 📖 Follow setup instructions in ROBLOX_SERVER_SETUP.md")
        return false
    end
    
    local stats = collectAccountStats()
    
    -- Send registration request to server via RemoteEvent
    DashboardRemote:FireServer("REGISTER", {
        url = DASHBOARD_URL,
        stats = stats
    })
    
    print("[Dashboard] 📤 Registration request sent to server")
    return true
end

-- Send stats update to dashboard
local function sendStatsUpdate()
    if not dashboardEnabled then return false end
    if not DashboardRemote then return false end
    
    local stats = collectAccountStats()
    
    -- Send update request to server via RemoteEvent
    DashboardRemote:FireServer("UPDATE_STATS", {
        url = DASHBOARD_URL,
        stats = stats
    })
    
    print("[Dashboard] 📤 Stats update sent to server")
    lastUpdateTime = os.time()
    return true
end

-- Listen for commands from dashboard
local function checkForCommands()
    if not dashboardEnabled then return end
    if not DashboardRemote then return end
    
    -- Request commands from server via RemoteEvent
    DashboardRemote:FireServer("FETCH_COMMANDS", {
        url = DASHBOARD_URL
    })
end

-- Handle responses from server
if DashboardRemote then
    DashboardRemote.OnClientEvent:Connect(function(responseType, data)
        if responseType == "REGISTER_SUCCESS" then
            print("[Dashboard] ✅ Account registered successfully")
            
        elseif responseType == "REGISTER_FAILED" then
            warn("[Dashboard] ❌ Failed to register account:", data.error)
            
        elseif responseType == "UPDATE_SUCCESS" then
            print("[Dashboard] 📊 Stats updated successfully")
            
        elseif responseType == "UPDATE_FAILED" then
            warn("[Dashboard] ⚠️ Failed to send stats update:", data.error)
            
        elseif responseType == "COMMANDS_RECEIVED" then
            local commands = data.commands
            if commands and #commands > 0 then
                for _, command in ipairs(commands) do
                    executeCommand(command)
                end
            end
            
        elseif responseType == "FETCH_FAILED" then
            warn("[Dashboard] ⚠️ Failed to fetch commands:", data.error)
        end
    end)
end

-- Execute remote command
local function executeCommand(command)
    if not command or not command.type then return end
    
    print("[Dashboard] 🎮 Executing command:", command.type)
    
    -- Toggle automation commands
    if command.type == "TOGGLE_AUTO_BUY" then
        if autoBuyToggle and autoBuyToggle.SetValue then
            autoBuyToggle:SetValue(command.value)
        end
    elseif command.type == "TOGGLE_AUTO_PLACE" then
        if autoPlaceToggle and autoPlaceToggle.SetValue then
            autoPlaceToggle:SetValue(command.value)
        end
    elseif command.type == "TOGGLE_AUTO_HATCH" then
        if autoHatchToggle and autoHatchToggle.SetValue then
            autoHatchToggle:SetValue(command.value)
        end
    elseif command.type == "TOGGLE_AUTO_CLAIM" then
        if autoClaimToggle and autoClaimToggle.SetValue then
            autoClaimToggle:SetValue(command.value)
        end
    elseif command.type == "TOGGLE_AUTO_FEED" then
        if autoFeedToggle and autoFeedToggle.SetValue then
            autoFeedToggle:SetValue(command.value)
        end
    
    -- Data request commands
    elseif command.type == "REQUEST_FULL_STATS" then
        sendStatsUpdate()
    
    -- Notification command
    elseif command.type == "SEND_NOTIFICATION" then
        if WindUI then
            WindUI:Notify({
                Title = command.title or "Dashboard",
                Content = command.message or "Message from dashboard",
                Duration = command.duration or 5
            })
        end
    end
end

-- ============ MAIN LOOP ============

local function startStatsUpdater()
    if updateThread then return end
    
    updateThread = task.spawn(function()
        while dashboardEnabled do
            local currentTime = os.time()
            
            -- Send stats update if enough time has passed
            if currentTime - lastUpdateTime >= UPDATE_INTERVAL then
                local success = sendStatsUpdate()
                
                if not success then
                    -- Retry after delay on failure
                    task.wait(RETRY_DELAY)
                end
            end
            
            task.wait(5) -- Check every 5 seconds
        end
    end)
end

local function startCommandListener()
    if commandListenerThread then return end
    
    commandListenerThread = task.spawn(function()
        while dashboardEnabled do
            checkForCommands()
            task.wait(10) -- Check for commands every 10 seconds
        end
    end)
end

-- ============ PUBLIC API ============

function DashboardIntegration.Init(config)
    if isRunning then
        warn("[Dashboard] Already initialized")
        return false
    end
    
    -- Store dashboard URL if provided
    if config and config.dashboardUrl then
        DASHBOARD_URL = config.dashboardUrl
    end
    
    -- Enable dashboard
    dashboardEnabled = true
    isRunning = true
    
    print("[Dashboard] 🚀 Initializing Dashboard Integration...")
    print("[Dashboard] 📡 Dashboard URL:", DASHBOARD_URL)
    
    -- Register account
    task.spawn(function()
        task.wait(2) -- Wait for game to load
        
        local registered = registerAccount()
        
        if registered then
            -- Start stats updater
            startStatsUpdater()
            
            -- Start command listener
            startCommandListener()
            
            -- Notify user
            if WindUI then
                WindUI:Notify({
                    Title = "🌐 Dashboard Connected",
                    Content = "Account registered with dashboard successfully!",
                    Duration = 4
                })
            end
        else
            -- Retry registration
            task.wait(RETRY_DELAY)
            registerAccount()
        end
    end)
    
    return true
end

function DashboardIntegration.Stop()
    dashboardEnabled = false
    isRunning = false
    
    -- Cancel threads
    if updateThread then
        task.cancel(updateThread)
        updateThread = nil
    end
    
    if commandListenerThread then
        task.cancel(commandListenerThread)
        commandListenerThread = nil
    end
    
    print("[Dashboard] 🛑 Dashboard integration stopped")
end

function DashboardIntegration.SendManualUpdate()
    return sendStatsUpdate()
end

function DashboardIntegration.GetStatus()
    return {
        isRunning = isRunning,
        dashboardEnabled = dashboardEnabled,
        lastUpdateTime = lastUpdateTime,
        dashboardUrl = DASHBOARD_URL
    }
end

function DashboardIntegration.SetDashboardUrl(url)
    DASHBOARD_URL = url
    print("[Dashboard] 🔗 Dashboard URL updated:", url)
end

return DashboardIntegration

