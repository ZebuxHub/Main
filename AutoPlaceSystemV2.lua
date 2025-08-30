-- Enhanced Auto Place System V2
-- Optimized for performance and smart ocean egg handling

local Players = game:GetService("Players")
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
