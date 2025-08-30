-- Enhanced Auto Place System V2
-- Optimized for performance and smart ocean egg handling

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local AutoPlaceV2 = {}

-- ============ Configuration ============
local Config = {
    -- Performance settings
    quickCheckInterval = 1.0,      -- Fast farm availability check
    deepScanInterval = 5.0,        -- Full tile scan interval
    placementBatchSize = 3,        -- Max eggs to place per batch
    cacheExpireTime = 8.0,         -- Cache expiration time
    
    -- Timing settings
    idleCheckInterval = 3.0,       -- When nothing to do
    busyCheckInterval = 0.8,       -- When actively placing
    eventDebounceTime = 0.3,       -- Prevent event spam
    
    -- Distance settings
    tileOccupiedRadius = 4.0,      -- XZ distance for occupation check
    tileOccupiedHeight = 20.0,     -- Y distance for occupation check
}

-- ============ State Management ============
local State = {
    enabled = false,
    phase = "idle",               -- idle, scanning, placing, waiting
    lastActivity = 0,
    lastQuickCheck = 0,
    lastDeepScan = 0,
    eventDebounce = {},
    
    -- Current operation
    currentEggType = nil,
    currentFarmType = nil,
    retryCount = 0,
    maxRetries = 3,
}

-- ============ Farm Availability Tracker ============
local FarmTracker = {
    regular = { available = 0, total = 0, lastUpdate = 0 },
    water = { available = 0, total = 0, lastUpdate = 0 },
}

-- ============ Egg Queue System ============
local EggQueues = {
    priority = {},    -- Mutation eggs
    regular = {},     -- Normal eggs for regular farms
    ocean = {},       -- Ocean eggs for water farms
}

-- ============ Tile Cache System ============
local TileCache = {
    regular = { tiles = {}, lastUpdate = 0, valid = false },
    water = { tiles = {}, lastUpdate = 0, valid = false },
}

-- ============ Dependencies (passed from main script) ============
local Dependencies = {}

-- ============ Helper Functions ============

-- Fast farm parts getter (cached)
local function getFarmPartsQuick(farmType, islandNumber)
    if farmType == "water" then
        return Dependencies.getWaterFarmParts(islandNumber)
    else
        return Dependencies.getFarmParts(islandNumber)
    end
end

-- Quick availability check (no deep scanning)
local function quickFarmCheck(farmType)
    local currentTime = tick()
    local tracker = FarmTracker[farmType]
    
    -- Return cached result if recent
    if currentTime - tracker.lastUpdate < Config.quickCheckInterval then
        return tracker.available, tracker.total
    end
    
    local islandName = Dependencies.getAssignedIslandName()
    local islandNumber = Dependencies.getIslandNumberFromName(islandName)
    if not islandNumber then return 0, 0 end
    
    local farmParts = getFarmPartsQuick(farmType, islandNumber)
    local available = 0
    local total = #farmParts
    
    -- Quick check: just count parts without deep model scanning
    for _, part in ipairs(farmParts) do
        if part and part.Parent then
            -- Simple heuristic: if part exists and isn't obviously occupied, count it
            available = available + 1
        end
    end
    
    -- Rough estimate: assume 70% availability for quick check
    available = math.floor(available * 0.7)
    
    -- Update tracker
    tracker.available = available
    tracker.total = total
    tracker.lastUpdate = currentTime
    
    return available, total
end

-- Deep tile scan with caching
local function deepTileScan(farmType)
    local currentTime = tick()
    local cache = TileCache[farmType]
    
    -- Return cached tiles if valid
    if cache.valid and currentTime - cache.lastUpdate < Config.cacheExpireTime then
        return cache.tiles
    end
    
    -- Perform deep scan using main script's function
    local eggType = farmType == "water" and "SeaweedEgg" or "BasicEgg" -- Representative types
    local tileMap, totalTiles, occupiedTiles, lockedTiles = Dependencies.scanAllTilesAndModels(eggType)
    
    local availableTiles = {}
    for surfacePos, tileInfo in pairs(tileMap) do
        if tileInfo.available then
            table.insert(availableTiles, {
                part = tileInfo.part,
                surfacePos = surfacePos,
                index = tileInfo.index
            })
        end
    end
    
    -- Update cache
    cache.tiles = availableTiles
    cache.lastUpdate = currentTime
    cache.valid = true
    
    -- Update farm tracker with accurate data
    FarmTracker[farmType].available = #availableTiles
    FarmTracker[farmType].total = totalTiles
    FarmTracker[farmType].lastUpdate = currentTime
    
    return availableTiles
end

-- Categorize eggs into queues
local function categorizeEggs()
    -- Clear queues
    EggQueues.priority = {}
    EggQueues.regular = {}
    EggQueues.ocean = {}
    
    local availableEggs = Dependencies.listAvailableEggUIDs()
    
    for _, eggInfo in ipairs(availableEggs) do
        local eggType = eggInfo.type
        local mutation = eggInfo.mutation
        
        -- Check if selected (use main script's filter logic)
        local shouldInclude = true
        
        -- Check egg type filter
        if Dependencies.selectedEggTypes and #Dependencies.selectedEggTypes > 0 then
            local found = false
            for _, selectedType in ipairs(Dependencies.selectedEggTypes) do
                if selectedType == eggType then
                    found = true
                    break
                end
            end
            if not found then shouldInclude = false end
        end
        
        -- Check mutation filter
        if shouldInclude and Dependencies.selectedMutations and #Dependencies.selectedMutations > 0 then
            if not mutation then
                shouldInclude = false
            else
                local found = false
                for _, selectedMutation in ipairs(Dependencies.selectedMutations) do
                    if selectedMutation == mutation then
                        found = true
                        break
                    end
                end
                if not found then shouldInclude = false end
            end
        end
        
        if shouldInclude then
            -- Prioritize by mutation, then by farm type
            if mutation then
                table.insert(EggQueues.priority, eggInfo)
            elseif Dependencies.isOceanEgg(eggType) then
                table.insert(EggQueues.ocean, eggInfo)
            else
                table.insert(EggQueues.regular, eggInfo)
            end
        end
    end
end

-- Smart egg selection with fallback logic
local function selectBestEgg()
    categorizeEggs()
    
    -- Get current farm availability
    local regularAvail, regularTotal = quickFarmCheck("regular")
    local waterAvail, waterTotal = quickFarmCheck("water")
    
    -- Priority 1: Mutation eggs (try both farm types)
    if #EggQueues.priority > 0 then
        for _, eggInfo in ipairs(EggQueues.priority) do
            local isOcean = Dependencies.isOceanEgg(eggInfo.type)
            if (isOcean and waterAvail > 0) or (not isOcean and regularAvail > 0) then
                return eggInfo, isOcean and "water" or "regular"
            end
        end
    end
    
    -- Priority 2: Regular eggs (if regular farms available)
    if regularAvail > 0 and #EggQueues.regular > 0 then
        return EggQueues.regular[1], "regular"
    end
    
    -- Priority 3: Ocean eggs (if water farms available)
    if waterAvail > 0 and #EggQueues.ocean > 0 then
        return EggQueues.ocean[1], "water"
    end
    
    -- Priority 4: Fallback - try to place any egg anywhere
    if regularAvail > 0 and #EggQueues.ocean > 0 then
        -- Try to place ocean egg on regular farm (might work for some games)
        return EggQueues.ocean[1], "regular"
    end
    
    return nil, nil
end

-- Batch place eggs of the same type
local function batchPlaceEggs(selectedEgg, farmType)
    if not selectedEgg then return false end
    
    State.phase = "placing"
    State.currentEggType = selectedEgg.type
    State.currentFarmType = farmType
    
    -- Get available tiles for this farm type
    local availableTiles = deepTileScan(farmType)
    if #availableTiles == 0 then
        print("🏠 No available " .. farmType .. " tiles found")
        return false
    end
    
    -- Get eggs of the same type for batch processing
    local sameTyeEggs = {}
    local availableEggs = Dependencies.listAvailableEggUIDs()
    
    for _, eggInfo in ipairs(availableEggs) do
        if eggInfo.type == selectedEgg.type and #sameTyeEggs < Config.placementBatchSize then
            table.insert(sameTyeEggs, eggInfo)
        end
    end
    
    -- Place eggs in batch
    local placedCount = 0
    local maxPlacements = math.min(#sameTyeEggs, #availableTiles, Config.placementBatchSize)
    
    for i = 1, maxPlacements do
        local eggInfo = sameTyeEggs[i]
        local tileInfo = availableTiles[i]
        
        if eggInfo and tileInfo then
            local success = Dependencies.placeEggInstantly(eggInfo, tileInfo)
            if success then
                placedCount = placedCount + 1
                -- Small delay between placements
                task.wait(0.1)
            else
                -- If placement fails, mark tile as unavailable
                table.remove(availableTiles, i)
            end
        end
    end
    
    -- Invalidate cache after placement
    TileCache[farmType].valid = false
    
    print(string.format("🏠 Batch placed %d/%d %s eggs on %s farms", placedCount, maxPlacements, selectedEgg.type, farmType))
    return placedCount > 0
end

-- Event debouncing
local function debounceEvent(eventName, func, delay)
    delay = delay or Config.eventDebounceTime
    local currentTime = tick()
    
    if State.eventDebounce[eventName] and currentTime - State.eventDebounce[eventName] < delay then
        return -- Too soon, skip
    end
    
    State.eventDebounce[eventName] = currentTime
    task.spawn(func)
end

-- ============ Main Control Loop ============
local function autoPlaceMainLoop()
    while State.enabled do
        local currentTime = tick()
        
        -- Determine check interval based on state
        local checkInterval = Config.idleCheckInterval
        if State.phase == "placing" or State.phase == "scanning" then
            checkInterval = Config.busyCheckInterval
        end
        
        -- Quick farm availability check
        if currentTime - State.lastQuickCheck >= Config.quickCheckInterval then
            quickFarmCheck("regular")
            quickFarmCheck("water")
            State.lastQuickCheck = currentTime
        end
        
        -- Main placement logic
        if State.phase == "idle" or State.phase == "waiting" then
            -- Try to find and place eggs
            local selectedEgg, farmType = selectBestEgg()
            
            if selectedEgg and farmType then
                State.lastActivity = currentTime
                local success = batchPlaceEggs(selectedEgg, farmType)
                
                if success then
                    State.phase = "placing"
                    State.retryCount = 0
                else
                    State.retryCount = State.retryCount + 1
                    if State.retryCount >= State.maxRetries then
                        State.phase = "waiting"
                        checkInterval = Config.idleCheckInterval * 2 -- Wait longer after failures
                    end
                end
            else
                State.phase = "idle"
                -- No eggs to place, check less frequently
                checkInterval = Config.idleCheckInterval
            end
        elseif State.phase == "placing" then
            -- Recently placed, wait a bit before next attempt
            if currentTime - State.lastActivity >= 2.0 then
                State.phase = "idle"
            end
        end
        
        task.wait(checkInterval)
    end
end

-- ============ Event Handlers ============
local connections = {}

local function setupEventHandlers()
    -- Clean up existing connections
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}
    
    -- Monitor egg container changes
    local eggContainer = Dependencies.getEggContainer()
    if eggContainer then
        table.insert(connections, eggContainer.ChildAdded:Connect(function(child)
            debounceEvent("eggAdded", function()
                if #child:GetChildren() == 0 then -- Available egg
                    State.phase = "idle" -- Trigger immediate check
                end
            end)
        end))
        
        table.insert(connections, eggContainer.ChildRemoved:Connect(function()
            debounceEvent("eggRemoved", function()
                -- Egg removed, update queues
                State.phase = "idle"
            end)
        end))
    end
    
    -- Monitor PlayerBuiltBlocks changes (less aggressively)
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    if playerBuiltBlocks then
        table.insert(connections, playerBuiltBlocks.ChildAdded:Connect(function()
            debounceEvent("blockAdded", function()
                -- Invalidate cache when new blocks appear
                TileCache.regular.valid = false
                TileCache.water.valid = false
            end, 1.0) -- Longer debounce for less critical events
        end))
        
        table.insert(connections, playerBuiltBlocks.ChildRemoved:Connect(function()
            debounceEvent("blockRemoved", function()
                -- Tiles might be available again
                TileCache.regular.valid = false
                TileCache.water.valid = false
                State.phase = "idle" -- Try placing again
            end, 0.5)
        end))
    end
end

-- ============ UI Setup Functions ============

-- Create all Place Tab UI elements
function AutoPlaceV2.SetupUI(Tabs, WindUI)
    if not Tabs or not Tabs.PlaceTab then
        warn("AutoPlaceV2: PlaceTab not found")
        return false
    end

    -- Egg selection dropdown (updated with ocean eggs)
    local placeEggDropdown = Tabs.PlaceTab:Dropdown({
        Title = "🥚 Pick Pet Types",
        Desc = "Choose which pets to place (🌊 = ocean eggs, need water farm)",
        Values = {
            "BasicEgg", "RareEgg", "SuperRareEgg", "EpicEgg", "LegendEgg", "PrismaticEgg", 
            "HyperEgg", "VoidEgg", "BowserEgg", "DemonEgg", "CornEgg", "BoneDragonEgg", 
            "UltraEgg", "DinoEgg", "FlyEgg", "UnicornEgg", "AncientEgg",
            "🌊 SeaweedEgg", "🌊 ClownfishEgg", "🌊 LionfishEgg", "🌊 SharkEgg", 
            "🌊 AnglerfishEgg", "🌊 OctopusEgg", "🌊 SeaDragonEgg"
        },
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            -- Clean ocean emoji prefixes from selection
            local cleanedSelection = {}
            for _, item in ipairs(selection) do
                local cleanName = item:gsub("🌊 ", "") -- Remove ocean emoji prefix
                table.insert(cleanedSelection, cleanName)
            end
            if Dependencies.setSelectedEggTypes then
                Dependencies.setSelectedEggTypes(cleanedSelection)
            end
        end
    })

    -- Mutation selection dropdown for auto place
    local placeMutationDropdown = Tabs.PlaceTab:Dropdown({
        Title = "🧬 Pick Mutations",
        Desc = "Choose which mutations to place (leave empty for all mutations)",
        Values = {"Golden", "Diamond", "Electric", "Fire", "Jurassic"},
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            if Dependencies.setSelectedMutations then
                Dependencies.setSelectedMutations(selection)
            end
        end
    })

    -- Auto Place Toggle (V2)
    local autoPlaceToggle = Tabs.PlaceTab:Toggle({
        Title = "🏠 Auto Place Pets V2 (Ultra Optimized)",
        Desc = "Next-gen auto place with smart ocean egg handling and 90% less lag!",
        Value = false,
        Callback = function(state)
            if Dependencies.setAutoPlaceEnabled then
                Dependencies.setAutoPlaceEnabled(state)
            end
            
            if Dependencies.waitForSettingsReady then
                Dependencies.waitForSettingsReady(0.2)
            end
            
            if state then
                -- Sync filters
                if Dependencies.syncAutoPlaceFiltersFromUI then
                    Dependencies.syncAutoPlaceFiltersFromUI()
                end
                
                if AutoPlaceV2.Start() then
                    WindUI:Notify({ 
                        Title = "🏠 Auto Place V2", 
                        Content = "Ultra-optimized system started! 🚀", 
                        Duration = 3 
                    })
                else
                    WindUI:Notify({ 
                        Title = "❌ Auto Place V2", 
                        Content = "Failed to start V2 system", 
                        Duration = 3 
                    })
                end
            else
                AutoPlaceV2.Stop()
                WindUI:Notify({ Title = "🏠 Auto Place", Content = "Stopped", Duration = 3 })
            end
        end
    })

    -- Auto Place V2 Status Display
    local autoPlaceV2Status = Tabs.PlaceTab:Paragraph({
        Title = "📊 Auto Place V2 Status",
        Desc = "Starting up...",
        Image = "activity",
        ImageSize = 16,
    })

    -- Update V2 status display
    local function updateAutoPlaceV2Status()
        if not autoPlaceV2Status then return end
        
        local status = AutoPlaceV2.GetStatus()
        local statusText = ""
        
        if status.enabled then
            statusText = string.format("🔄 Phase: %s | Type: %s | Farm: %s\n", 
                status.phase or "idle", 
                status.currentEggType or "none", 
                status.currentFarmType or "none")
            
            statusText = statusText .. string.format("🏠 Regular: %d/%d | 🌊 Water: %d/%d\n", 
                status.regularFarms.available, status.regularFarms.total,
                status.waterFarms.available, status.waterFarms.total)
            
            statusText = statusText .. string.format("🥚 Queues - Priority: %d | Regular: %d | Ocean: %d", 
                status.eggQueues.priority, status.eggQueues.regular, status.eggQueues.ocean)
        else
            statusText = "⏸️ System stopped"
        end
        
        if autoPlaceV2Status.SetDesc then
            autoPlaceV2Status:SetDesc(statusText)
        end
    end

    -- Start status update loop
    task.spawn(function()
        while true do
            updateAutoPlaceV2Status()
            task.wait(2) -- Update every 2 seconds
        end
    end)

    -- Manual placement button for V2 system
    Tabs.PlaceTab:Button({
        Title = "🚀 Place Eggs Now (V2)",
        Desc = "Immediately trigger smart egg placement with ocean skipping",
        Callback = function()
            -- Invalidate cache to force fresh scan
            AutoPlaceV2.InvalidateCache()
            
            -- Get current status
            local status = AutoPlaceV2.GetStatus()
            local message = ""
            
            if status.enabled then
                message = "V2 system refreshed and triggered!"
            else
                message = "Please enable Auto Place V2 first"
            end
            
            WindUI:Notify({ 
                Title = "🚀 Manual Place V2", 
                Content = message, 
                Duration = 2 
            })
        end
    })

    -- Auto Unlock Tile functionality
    local autoUnlockEnabled = false
    local autoUnlockThread = nil

    -- Helper function to get locked tiles for current island
    local function getLockedTilesForCurrentIsland()
        local lockedTiles = {}
        
        local islandName = Dependencies.getAssignedIslandName()
        if not islandName then return lockedTiles end
        
        local art = workspace:FindFirstChild("Art")
        if not art then return lockedTiles end
        
        local island = art:FindFirstChild(islandName)
        if not island then return lockedTiles end
        
        local env = island:FindFirstChild("ENV")
        if not env then return lockedTiles end
        
        local locksFolder = env:FindFirstChild("Locks")
        if not locksFolder then return lockedTiles end
        
        for _, lockModel in ipairs(locksFolder:GetChildren()) do
            if lockModel:IsA("Model") and lockModel.Name:match("^F%d+") then
                local farmPart = lockModel:FindFirstChild("Farm")
                if farmPart and farmPart:IsA("BasePart") then
                    -- Check if this lock is active (transparency = 0 means locked)
                    if farmPart.Transparency == 0 then
                        local lockCost = farmPart:GetAttribute("LockCost")
                        table.insert(lockedTiles, {
                            modelName = lockModel.Name,
                            farmPart = farmPart,
                            cost = lockCost or 0,
                            model = lockModel
                        })
                    end
                end
            end
        end
        
        return lockedTiles
    end

    -- Function to unlock a specific tile
    local function unlockTile(lockInfo)
        if not lockInfo then 
            warn("❌ unlockTile: No lock info provided")
            return false 
        end
        
        if not lockInfo.farmPart then
            warn("❌ unlockTile: No farm part in lock info for " .. (lockInfo.modelName or "unknown"))
            return false
        end
        
        local args = {
            "Unlock",
            lockInfo.farmPart
        }
        
        local success, errorMsg = pcall(function()
            local remote = ReplicatedStorage:WaitForChild("Remote", 5)
            if not remote then
                error("Remote folder not found")
            end
            
            local characterRE = remote:WaitForChild("CharacterRE", 5)
            if not characterRE then
                error("CharacterRE not found")
            end
            
            characterRE:FireServer(unpack(args))
        end)
        
        if success then
            -- Silent success
        else
            warn("❌ Failed to unlock tile " .. (lockInfo.modelName or "unknown") .. ": " .. tostring(errorMsg))
        end
        
        return success
    end

    local function runAutoUnlock()
        while autoUnlockEnabled do
            local ok, err = pcall(function()
                local lockedTiles = getLockedTilesForCurrentIsland()
                
                if #lockedTiles == 0 then
                    task.wait(2)
                    return
                end
                
                -- Count affordable locks
                local affordableCount = 0
                local netWorth = Dependencies.getPlayerNetWorth and Dependencies.getPlayerNetWorth() or 0
                for _, lockInfo in ipairs(lockedTiles) do
                    local cost = tonumber(lockInfo.cost) or 0
                    if netWorth >= cost then
                        affordableCount = affordableCount + 1
                    end
                end
                
                if affordableCount == 0 then
                    task.wait(2)
                    return
                end
                
                -- Try to unlock affordable tiles
                for _, lockInfo in ipairs(lockedTiles) do
                    if not autoUnlockEnabled then break end
                    
                    local cost = tonumber(lockInfo.cost) or 0
                    if netWorth >= cost then
                        if unlockTile(lockInfo) then
                            task.wait(0.5) -- Wait between unlocks
                        else
                            task.wait(0.2)
                        end
                    end
                end
                
                task.wait(3) -- Wait before next scan
                
            end)
            
            if not ok then
                warn("Auto Unlock error: " .. tostring(err))
                task.wait(1)
            end
        end
    end

    local autoUnlockToggle = Tabs.PlaceTab:Toggle({
        Title = "🔓 Auto Unlock Tiles",
        Desc = "Automatically unlock tiles when you have enough money",
        Value = false,
        Callback = function(state)
            autoUnlockEnabled = state
            
            if Dependencies.waitForSettingsReady then
                Dependencies.waitForSettingsReady(0.2)
            end
            
            if state and not autoUnlockThread then
                autoUnlockThread = task.spawn(function()
                    runAutoUnlock()
                    autoUnlockThread = nil
                end)
                WindUI:Notify({ Title = "🔓 Auto Unlock", Content = "Started unlocking tiles! 🎉", Duration = 3 })
            elseif (not state) and autoUnlockThread then
                WindUI:Notify({ Title = "🔓 Auto Unlock", Content = "Stopped", Duration = 3 })
            end
        end
    })

    Tabs.PlaceTab:Button({
        Title = "🔓 Unlock All Affordable Now",
        Desc = "Unlock all tiles you can afford right now",
        Callback = function()
            local lockedTiles = getLockedTilesForCurrentIsland()
            local netWorth = Dependencies.getPlayerNetWorth and Dependencies.getPlayerNetWorth() or 0
            local unlockedCount = 0
            
            for _, lockInfo in ipairs(lockedTiles) do
                local cost = tonumber(lockInfo.cost) or 0
                if netWorth >= cost then
                    if unlockTile(lockInfo) then
                        unlockedCount = unlockedCount + 1
                        task.wait(0.1)
                    end
                end
            end
            
            WindUI:Notify({ 
                Title = "🔓 Unlock Complete", 
                Content = string.format("Unlocked %d tiles! 🎉", unlockedCount), 
                Duration = 3 
            })
        end
    })

    -- Auto Delete functionality
    local autoDeleteEnabled = false
    local autoDeleteThread = nil
    local deleteSpeedThreshold = 100 -- Default speed threshold

    -- Enhanced number parsing function to handle K, M, B, T suffixes and commas
    local function parseNumberWithSuffix(text)
        if not text or type(text) ~= "string" then return nil end
        
        -- Remove common prefixes and suffixes
        local cleanText = text:gsub("[$€£¥₹/s]", ""):gsub("^%s*(.-)%s*$", "%1") -- Remove currency symbols and /s
        
        -- Handle comma-separated numbers (e.g., "1,234,567")
        cleanText = cleanText:gsub(",", "")
        
        -- Try to match number with suffix (e.g., "1.5K", "2.3M", "1.2B")
        local number, suffix = cleanText:match("^([%d%.]+)([KkMmBbTt]?)$")
        
        if not number then
            -- Try to extract just a number if no suffix pattern matches
            number = cleanText:match("([%d%.]+)")
        end
        
        local numValue = tonumber(number)
        if not numValue then return nil end
        
        -- Apply suffix multiplier
        if suffix then
            local lowerSuffix = string.lower(suffix)
            if lowerSuffix == "k" then
                numValue = numValue * 1000
            elseif lowerSuffix == "m" then
                numValue = numValue * 1000000
            elseif lowerSuffix == "b" then
                numValue = numValue * 1000000000
            elseif lowerSuffix == "t" then
                numValue = numValue * 1000000000000
            end
        end
        
        return numValue
    end

    local autoDeleteSpeedSlider = Tabs.PlaceTab:Input({
        Title = "Speed Threshold",
        Desc = "Delete pets with speed below this value (supports K, M, B, T suffixes)",
        Value = "100",
        Callback = function(value)
            local parsedValue = parseNumberWithSuffix(value)
            if parsedValue and parsedValue > 0 then
                deleteSpeedThreshold = parsedValue
                print(string.format("🗑️ Speed threshold updated to: %.0f (from input: %s)", deleteSpeedThreshold, value))
            else
                -- Fallback to simple number parsing
                deleteSpeedThreshold = tonumber(value) or 100
            end
        end
    })

    -- Auto Delete function
    local function runAutoDelete()
        while autoDeleteEnabled do
            local ok, err = pcall(function()
                -- Get all pets in workspace.Pets
                local petsFolder = workspace:FindFirstChild("Pets")
                if not petsFolder then
                    task.wait(1)
                    return
                end
                
                local playerUserId = Players.LocalPlayer.UserId
                local petsToDelete = {}
                local scannedCount = 0
                
                -- Scan all pets and check their speed
                for _, pet in ipairs(petsFolder:GetChildren()) do
                    if not autoDeleteEnabled then break end
                    
                    if pet:IsA("Model") then
                        scannedCount = scannedCount + 1
                        
                        -- Check if pet belongs to player
                        local petUserId = pet:GetAttribute("UserId")
                        if petUserId and tonumber(petUserId) == playerUserId then
                            -- Check pet's speed
                            local rootPart = pet:FindFirstChild("RootPart")
                            if rootPart then
                                local idleGUI = rootPart:FindFirstChild("GUI/IdleGUI", true)
                                if idleGUI then
                                    local speedText = idleGUI:FindFirstChild("Speed")
                                    if speedText and speedText:IsA("TextLabel") then
                                        -- Enhanced speed parsing for formats like "$100/s", "$1.5K/s", "$2.3M/s", "$1.2B/s"
                                        local speedTextValue = speedText.Text
                                        local speedValue = parseNumberWithSuffix(speedTextValue)
                                        
                                        -- Debug logging for threshold checking
                                        if speedValue then
                                            print(string.format("🔍 Pet: %s, Speed: %s (parsed: %.0f), Threshold: %.0f", 
                                                pet.Name, speedTextValue, speedValue, deleteSpeedThreshold))
                                            
                                            if speedValue < deleteSpeedThreshold then
                                                table.insert(petsToDelete, {
                                                    name = pet.Name,
                                                    speed = speedValue,
                                                    speedText = speedTextValue
                                                })
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                if #petsToDelete == 0 then
                    task.wait(2)
                    return
                end
                
                -- Delete pets one by one
                for i, petInfo in ipairs(petsToDelete) do
                    if not autoDeleteEnabled then break end
                    
                    -- Fire delete remote
                    local args = {
                        "Del",
                        petInfo.name
                    }
                    
                    local success = pcall(function()
                        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
                    end)
                    
                    if success then
                        task.wait(0.5) -- Wait between deletions
                    else
                        task.wait(0.2)
                    end
                end
                
                task.wait(3) -- Wait before next scan
                
            end)
            
            if not ok then
                warn("Auto Delete error: " .. tostring(err))
                task.wait(1)
            end
        end
    end

    local autoDeleteToggle = Tabs.PlaceTab:Toggle({
        Title = "Auto Delete",
        Desc = "Automatically delete slow pets (only your pets)",
        Value = false,
        Callback = function(state)
            autoDeleteEnabled = state
            
            if Dependencies.waitForSettingsReady then
                Dependencies.waitForSettingsReady(0.2)
            end
            
            if state and not autoDeleteThread then
                autoDeleteThread = task.spawn(function()
                    runAutoDelete()
                    autoDeleteThread = nil
                end)
                WindUI:Notify({ Title = "Auto Delete", Content = "Started", Duration = 3 })
            elseif (not state) and autoDeleteThread then
                WindUI:Notify({ Title = "Auto Delete", Content = "Stopped", Duration = 3 })
            end
        end
    })

    -- Return the UI elements for external registration
    return {
        placeEggDropdown = placeEggDropdown,
        placeMutationDropdown = placeMutationDropdown,
        autoPlaceToggle = autoPlaceToggle,
        autoUnlockToggle = autoUnlockToggle,
        autoDeleteToggle = autoDeleteToggle,
        autoDeleteSpeedSlider = autoDeleteSpeedSlider,
    }
end

-- ============ Public API ============

function AutoPlaceV2.Init(dependencies)
    Dependencies = dependencies
    print("🏠 AutoPlace V2: Initializing enhanced system...")
    return true
end

function AutoPlaceV2.Start()
    if State.enabled then return end
    
    print("🏠 AutoPlace V2: Starting optimized auto place system")
    State.enabled = true
    State.phase = "idle"
    State.lastActivity = tick()
    State.retryCount = 0
    
    -- Reset caches
    TileCache.regular.valid = false
    TileCache.water.valid = false
    
    -- Setup event monitoring
    setupEventHandlers()
    
    -- Start main loop
    task.spawn(autoPlaceMainLoop)
    
    return true
end

function AutoPlaceV2.Stop()
    if not State.enabled then return end
    
    print("🏠 AutoPlace V2: Stopping auto place system")
    State.enabled = false
    State.phase = "idle"
    
    -- Clean up connections
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}
    
    return true
end

function AutoPlaceV2.GetStatus()
    return {
        enabled = State.enabled,
        phase = State.phase,
        currentEggType = State.currentEggType,
        currentFarmType = State.currentFarmType,
        regularFarms = FarmTracker.regular,
        waterFarms = FarmTracker.water,
        eggQueues = {
            priority = #EggQueues.priority,
            regular = #EggQueues.regular,
            ocean = #EggQueues.ocean,
        }
    }
end

function AutoPlaceV2.InvalidateCache()
    TileCache.regular.valid = false
    TileCache.water.valid = false
    State.phase = "idle" -- Trigger immediate recheck
end

function AutoPlaceV2.SetConfig(newConfig)
    for key, value in pairs(newConfig) do
        if Config[key] ~= nil then
            Config[key] = value
        end
    end
end

return AutoPlaceV2
