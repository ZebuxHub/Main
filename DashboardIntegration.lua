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

-- ============ STATE ============
local isRunning = false
local lastUpdateTime = 0
local updateThread = nil
local commandListenerThread = nil
local dashboardEnabled = false

-- ============ NERD STATS TRACKING ============
local nerdStats = {
    moneyProduced = 0, -- Total money produced
    moneySpent = 0, -- Total money spent
    sessionStartMoney = 0, -- Money when script started
    sessionStartTime = 0, -- Timestamp when tracking started
    lastMoney = 0, -- Last recorded money value
    eggsCollected = 0, -- Total eggs collected this session
    petsHatched = 0 -- Total pets hatched this session
}

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

-- Get pet speed stats with best/worst pet info
local function getPetSpeedStats()
    local speeds = {}
    local totalSpeed = 0
    local fastestSpeed = 0
    local slowestSpeed = math.huge
    local avgSpeed = 0
    local bestPet = nil
    local worstPet = nil
    local totalPlaced = 0
    
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = playerGui and playerGui:FindFirstChild("Data")
    local petsFolder = data and data:FindFirstChild("Pets")
    
    if petsFolder then
        local petCount = 0
        for _, petConfig in ipairs(petsFolder:GetChildren()) do
            if petConfig:IsA("Configuration") then
                local speed = petConfig:GetAttribute("S") or petConfig:GetAttribute("Speed") or 0
                local petType = petConfig:GetAttribute("T") or "Unknown"
                local mutation = petConfig:GetAttribute("M")
                local isPlaced = petConfig:GetAttribute("D") ~= nil
                
                if isPlaced then
                    totalPlaced = totalPlaced + 1
                end
                
                if type(speed) == "number" and speed > 0 then
                    table.insert(speeds, speed)
                    totalSpeed = totalSpeed + speed
                    
                    -- Track best pet
                    if speed > fastestSpeed then
                        fastestSpeed = speed
                        bestPet = {
                            name = petType,
                            speed = speed,
                            mutation = mutation
                        }
                    end
                    
                    -- Track worst pet
                    if speed < slowestSpeed then
                        slowestSpeed = speed
                        worstPet = {
                            name = petType,
                            speed = speed,
                            mutation = mutation
                        }
                    end
                    
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
        total = totalSpeed,
        totalPlaced = totalPlaced
    }, bestPet, worstPet
end

-- Track money changes
local function trackMoneyChanges()
    local currentMoney = getPlayerNetWorth()
    
    -- Initialize tracking on first run
    if nerdStats.sessionStartTime == 0 then
        nerdStats.sessionStartMoney = currentMoney
        nerdStats.lastMoney = currentMoney
        nerdStats.sessionStartTime = os.time()
        return
    end
    
    -- Check if money increased (produced)
    if currentMoney > nerdStats.lastMoney then
        nerdStats.moneyProduced = nerdStats.moneyProduced + (currentMoney - nerdStats.lastMoney)
    -- Check if money decreased (spent)
    elseif currentMoney < nerdStats.lastMoney then
        nerdStats.moneySpent = nerdStats.moneySpent + (nerdStats.lastMoney - currentMoney)
    end
    
    nerdStats.lastMoney = currentMoney
end

-- Calculate efficiency metrics
local function calculateEfficiencyMetrics()
    local uptimeSeconds = os.time() - nerdStats.sessionStartTime
    local uptimeHours = uptimeSeconds / 3600
    
    if uptimeHours == 0 then uptimeHours = 0.01 end -- Avoid division by zero
    
    return {
        eggsPerHour = nerdStats.eggsCollected / uptimeHours,
        petsPerHour = nerdStats.petsHatched / uptimeHours,
        moneyPerHour = nerdStats.moneyProduced / uptimeHours,
        uptimeHours = uptimeHours
    }
end

-- Get detailed egg inventory (like AutoPlaceGridUI)
local function getEggInventory()
    local eggs = {}
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
                local uid = child.Name
                
                -- Add to detailed list
                table.insert(eggs, {
                    uid = uid,
                    type = eggType,
                    mutation = mutation
                })
                
                -- Count by type
                eggTypes[eggType] = (eggTypes[eggType] or 0) + 1
                
                -- Count by mutation
                if mutation and mutation ~= "" then
                    mutations[mutation] = (mutations[mutation] or 0) + 1
                end
            end
        end
    end
    
    return {
        list = eggs, -- Detailed list for inventory view
        types = eggTypes,
        mutations = mutations
    }
end

-- Get detailed pet inventory (like AutoPlaceGridUI)
local function getPetInventory()
    local pets = {}
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = playerGui and playerGui:FindFirstChild("Data")
    local petsFolder = data and data:FindFirstChild("Pets")
    
    if petsFolder then
        for _, petConfig in ipairs(petsFolder:GetChildren()) do
            if petConfig:IsA("Configuration") then
                local uid = petConfig.Name
                local petType = petConfig:GetAttribute("T") or "Unknown"
                local mutation = petConfig:GetAttribute("M")
                local level = petConfig:GetAttribute("V") or 0
                local speed = petConfig:GetAttribute("S") or 0
                local isPlaced = petConfig:GetAttribute("D") ~= nil
                local isBigPet = petConfig:GetAttribute("IsBigpet") == true
                
                -- Skip big pets
                if not isBigPet then
                    table.insert(pets, {
                        uid = uid,
                        type = petType,
                        mutation = mutation,
                        level = level,
                        speed = speed,
                        isPlaced = isPlaced
                    })
                end
            end
        end
    end
    
    return pets
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
    -- Track money changes before collecting stats
    trackMoneyChanges()
    
    local petSpeedStats, bestPet, worstPet = getPetSpeedStats()
    local eggStats = getEggInventory() -- New: detailed inventory
    local petInventory = getPetInventory() -- New: detailed inventory
    local automation = getAutomationStatus()
    local performance = getPerformanceMetrics()
    local efficiency = calculateEfficiencyMetrics()
    
    return {
        -- Game Identifier (for multi-game support)
        gameId = "build-a-zoo",
        gameName = "Build A Zoo",
        
        -- Account Info
        accountId = tostring(LocalPlayer.UserId),
        username = LocalPlayer.Name,
        displayName = LocalPlayer.DisplayName,
        userId = tostring(LocalPlayer.UserId),
        
        -- Economy
        money = getPlayerNetWorth(),
        
        -- Nerd Stats - Money Tracking
        moneyProduced = nerdStats.moneyProduced,
        moneySpent = nerdStats.moneySpent,
        
        -- Nerd Stats - Best/Worst Pets
        bestPet = bestPet,
        worstPet = worstPet,
        
        -- Nerd Stats - Efficiency
        eggsPerHour = efficiency.eggsPerHour,
        petsPerHour = efficiency.petsPerHour,
        moneyPerHour = efficiency.moneyPerHour,
        uptimeHours = efficiency.uptimeHours,
        
        -- Inventory Counts
        totalEggs = getTotalEggs(),
        totalPets = getTotalPets(),
        placedPets = getTotalPlacedPets(),
        
        -- Detailed Inventory (for sidebar view)
        inventory = {
            eggs = eggStats.list, -- Detailed egg list
            pets = petInventory -- Detailed pet list
        },
        
        -- Progress
        currentIsland = getAssignedIslandName(),
        conveyorLevel = getConveyorLevel(),
        
        -- Pet Stats
        petSpeed = {
            fastest = petSpeedStats.fastest,
            slowest = petSpeedStats.slowest,
            average = petSpeedStats.average,
            total = petSpeedStats.total,
            totalPlaced = petSpeedStats.totalPlaced
        },
        
        -- Egg/Mutation Breakdown (for charts)
        eggBreakdown = eggStats.types,
        mutationBreakdown = eggStats.mutations,
        
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
    local stats = collectAccountStats()
    local jsonData = HttpService:JSONEncode(stats)
    
    local success, result = false, "No method available"
    
    -- Method 1: Try request function (common in executors)
    if not success and _G.request then
        success, result = pcall(function()
            return _G.request({
                Url = DASHBOARD_URL .. "/api/accounts/register",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
        end)
    end
    
    -- Method 2: Try syn.request (Synapse X)
    if not success and syn and syn.request then
        success, result = pcall(function()
            return syn.request({
                Url = DASHBOARD_URL .. "/api/accounts/register",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
        end)
    end
    
    -- Method 3: Try http_request (common executor function)
    if not success and http_request then
        success, result = pcall(function()
            return http_request({
                Url = DASHBOARD_URL .. "/api/accounts/register",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
        end)
    end
    
    -- Method 4: Fallback to GET with URL params (if all else fails)
    if not success then
        local encodedData = HttpService:UrlEncode(jsonData)
        success, result = pcall(function()
            return HttpService:GetAsync(
                DASHBOARD_URL .. "/api/accounts/register?data=" .. encodedData,
                false
            )
        end)
    end
    
    if success then
        print("[Dashboard] ✅ Account registered successfully")
        return true
    else
        warn("[Dashboard] ❌ Failed to register account:", tostring(result))
        return false
    end
end

-- Send stats update to dashboard
local function sendStatsUpdate()
    if not dashboardEnabled then return false end
    
    local stats = collectAccountStats()
    local jsonData = HttpService:JSONEncode(stats)
    
    local success, result = false, "No method available"
    
    -- Method 1: Try request function (common in executors)
    if not success and _G.request then
        success, result = pcall(function()
            return _G.request({
                Url = DASHBOARD_URL .. "/api/accounts/update-stats",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
        end)
    end
    
    -- Method 2: Try syn.request (Synapse X)
    if not success and syn and syn.request then
        success, result = pcall(function()
            return syn.request({
                Url = DASHBOARD_URL .. "/api/accounts/update-stats",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
        end)
    end
    
    -- Method 3: Try http_request (common executor function)
    if not success and http_request then
        success, result = pcall(function()
            return http_request({
                Url = DASHBOARD_URL .. "/api/accounts/update-stats",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
        end)
    end
    
    -- Method 4: Fallback to GET with URL params (if all else fails)
    if not success then
        local encodedData = HttpService:UrlEncode(jsonData)
        success, result = pcall(function()
            return HttpService:GetAsync(
                DASHBOARD_URL .. "/api/accounts/update-stats?data=" .. encodedData,
                false
            )
        end)
    end
    
    if success then
        print("[Dashboard] 📊 Stats updated successfully")
        lastUpdateTime = os.time()
        return true
    else
        warn("[Dashboard] ⚠️ Failed to send stats update:", tostring(result))
        return false
    end
end

-- Listen for commands from dashboard
local function checkForCommands()
    if not dashboardEnabled then return end
    
    local success, response = pcall(function()
        return HttpService:GetAsync(
            DASHBOARD_URL .. "/api/commands/fetch?accountId=" .. tostring(LocalPlayer.UserId),
            false
        )
    end)
    
    if success and response then
        local commands = HttpService:JSONDecode(response)
        
        if commands and #commands > 0 then
            for _, command in ipairs(commands) do
                executeCommand(command)
            end
        end
    end
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

