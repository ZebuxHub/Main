-- ============================================
-- Auto Place System - Revamped & Optimized
-- ============================================
-- High-performance pet placement system with smart egg prioritization,
-- ocean egg skipping, focus-first placement, and minimal lag design.

local AutoPlaceSystem = {}

-- ============ Services & Dependencies ============
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- ============ External Dependencies ============
local WindUI, Tabs, Config
local selectedEggTypes = {}
local selectedMutations = {}
local fallbackToRegularWhenNoWater = true

-- ============ Remote Cache ============
-- Cache remotes once with timeouts to avoid infinite waits
local Remotes = ReplicatedStorage:WaitForChild("Remote", 5)
local CharacterRE = Remotes and Remotes:FindFirstChild("CharacterRE")

-- ============ Stats (moved early for visibility) ============
local placementStats = {
    totalPlacements = 0,
    mutationPlacements = 0,
    lastPlacement = nil,
    lastReason = nil
}

-- ============ Performance Cache System ============
local CACHE_DURATION = 8 -- Cache for 8 seconds to reduce lag
local tileCache = {
    lastUpdate = 0,
    regularTiles = {},
    waterTiles = {},
    regularAvailable = 0,
    waterAvailable = 0
}

local eggCache = {
    lastUpdate = 0,
    availableEggs = {},
    oceanEggs = {},
    regularEggs = {}
}

-- ============ Ocean Egg Detection ============
local OCEAN_EGGS = {
    ["SeaweedEgg"] = true,
    ["ClownfishEgg"] = true,
    ["LionfishEgg"] = true,
    ["SharkEgg"] = true,
    ["AnglerfishEgg"] = true,
    ["OctopusEgg"] = true,
    ["SeaDragonEgg"] = true
}

local function isOceanEgg(eggType)
    return OCEAN_EGGS[eggType] == true
end

-- ============ Utility Functions ============
local function getAssignedIslandName()
    if not LocalPlayer then return nil end
    return LocalPlayer:GetAttribute("AssignedIslandName")
end

local function getIslandNumberFromName(islandName)
    if not islandName then return nil end
    local match = string.match(islandName, "Island_(%d+)")
    if match then
        return tonumber(match)
    end
    match = string.match(islandName, "(%d+)")
    if match then
        return tonumber(match)
    end
    return nil
end

-- ============ Smart Egg Management ============
local function getEggContainer()
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = pg and pg:FindFirstChild("Data")
    return data and data:FindFirstChild("Egg") or nil
end

local function getEggMutation(eggUID)
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return nil end
    
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return nil end
    
    local eggContainer = data:FindFirstChild("Egg")
    if not eggContainer then return nil end
    
    local eggConfig = eggContainer:FindFirstChild(eggUID)
    if not eggConfig then return nil end
    
    local mutation = eggConfig:GetAttribute("M")
    if mutation == "Dino" then
        mutation = "Jurassic"
    end
    
    return mutation
end

-- Enhanced egg collection with smart filtering
local function updateAvailableEggs()
    local currentTime = time()
    if currentTime - eggCache.lastUpdate < CACHE_DURATION then
        return eggCache.availableEggs, eggCache.oceanEggs, eggCache.regularEggs
    end
    
    local eg = getEggContainer()
    local allEggs = {}
    local oceanEggs = {}
    local regularEggs = {}
    
    if not eg then 
        eggCache.availableEggs = {}
        eggCache.oceanEggs = {}
        eggCache.regularEggs = {}
        return {}, {}, {}
    end
    
    -- Create filter sets for faster lookup
    local selectedTypeSet = {}
    for _, type in ipairs(selectedEggTypes) do
        -- Clean ocean emoji prefixes
        local cleanType = type:gsub("🌊 ", "")
        selectedTypeSet[cleanType] = true
    end
    
    local selectedMutationSet = {}
    for _, mutation in ipairs(selectedMutations) do
        selectedMutationSet[mutation] = true
    end
    
    for _, child in ipairs(eg:GetChildren()) do
        if #child:GetChildren() == 0 then -- No subfolder = available
            local eggType = child:GetAttribute("T")
            if eggType then
                local mutation = getEggMutation(child.Name)
                
                -- Apply filters
                local passesTypeFilter = true
                local passesMutationFilter = true
                
                if #selectedEggTypes > 0 then
                    passesTypeFilter = selectedTypeSet[eggType] == true
                end
                
                if #selectedMutations > 0 then
                    if not mutation then
                        passesMutationFilter = false
                    else
                        passesMutationFilter = selectedMutationSet[mutation] == true
                    end
                end
                
                if passesTypeFilter and passesMutationFilter then
                    local eggInfo = { 
                        uid = child.Name, 
                        type = eggType,
                        mutation = mutation,
                        priority = mutation and 1000 or 100 -- Mutations get higher priority
                    }
                    
                    table.insert(allEggs, eggInfo)
                    
                    if isOceanEgg(eggType) then
                        table.insert(oceanEggs, eggInfo)
                    else
                        table.insert(regularEggs, eggInfo)
                    end
                end
            end
        end
    end
    
    -- Sort by priority (mutations first)
    table.sort(allEggs, function(a, b) 
        return a.priority > b.priority 
    end)
    table.sort(oceanEggs, function(a, b) 
        return a.priority > b.priority 
    end)
    table.sort(regularEggs, function(a, b) 
        return a.priority > b.priority 
    end)
    
    -- Update cache
    eggCache.lastUpdate = currentTime
    eggCache.availableEggs = allEggs
    eggCache.oceanEggs = oceanEggs
    eggCache.regularEggs = regularEggs
    
    return allEggs, oceanEggs, regularEggs
end

-- Find any regular (non-ocean) egg ignoring current selection filters
local function findAnyAvailableRegularEgg()
    local eg = getEggContainer()
    if not eg then return nil end
    local bestEgg = nil
    local bestPriority = -1
    for _, child in ipairs(eg:GetChildren()) do
        if #child:GetChildren() == 0 then
            local eggType = child:GetAttribute("T")
            if eggType and not isOceanEgg(eggType) then
                local mutation = getEggMutation(child.Name)
                local priority = mutation and 1000 or 100
                if priority > bestPriority then
                    bestPriority = priority
                    bestEgg = {
                        uid = child.Name,
                        type = eggType,
                        mutation = mutation,
                        priority = priority,
                    }
                end
            end
        end
    end
    return bestEgg
end

-- ============ Smart Farm Tile Management ============
local function getFarmParts(islandNumber, isWater)
    if not islandNumber then return {} end
    local art = workspace:FindFirstChild("Art")
    if not art then return {} end
    
    local islandName = "Island_" .. tostring(islandNumber)
    local island = art:FindFirstChild(islandName)
    if not island then 
        for _, child in ipairs(art:GetChildren()) do
            if child.Name:match("^Island[_-]?" .. tostring(islandNumber) .. "$") then
                island = child
                break
            end
        end
        if not island then return {} end
    end
    
    local farmParts = {}
    local pattern = isWater and "WaterFarm_split_0_0_0" or "^Farm_split_%d+_%d+_%d+$"
    
    local function scanForFarmParts(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("BasePart") then
                local matches = false
                if isWater then
                    matches = child.Name == pattern
                else
                    matches = child.Name:match(pattern)
                end
                
                -- Validate that it's a proper 8x8x8 farm tile
                if matches and child.Size == Vector3.new(8, 8, 8) and child.CanCollide then
                    -- Additional validation for water farm tiles
                    if isWater and child.Name == "WaterFarm_split_0_0_0" then
                        table.insert(farmParts, child)
                    elseif not isWater then
                        table.insert(farmParts, child)
                    end
                end
            end
            scanForFarmParts(child)
        end
    end
    
    scanForFarmParts(island)
    
    -- Filter out locked tiles
    local unlockedFarmParts = {}
    local env = island:FindFirstChild("ENV")
    local locksFolder = env and env:FindFirstChild("Locks")
    
    if locksFolder then
        local lockedAreas = {}
        for _, lockModel in ipairs(locksFolder:GetChildren()) do
            if lockModel:IsA("Model") then
                local farmPart = lockModel:FindFirstChild("Farm")
                if farmPart and farmPart:IsA("BasePart") and farmPart.Transparency == 0 then
                    table.insert(lockedAreas, {
                        position = farmPart.Position,
                        size = farmPart.Size
                    })
                end
            end
        end
        
        for _, farmPart in ipairs(farmParts) do
            local isLocked = false
            for _, lockArea in ipairs(lockedAreas) do
                local farmPartPos = farmPart.Position
                local lockCenter = lockArea.position
                local lockSize = lockArea.size
                
                local lockHalfSize = lockSize / 2
                local lockMinX = lockCenter.X - lockHalfSize.X
                local lockMaxX = lockCenter.X + lockHalfSize.X
                local lockMinZ = lockCenter.Z - lockHalfSize.Z
                local lockMaxZ = lockCenter.Z + lockHalfSize.Z
                
                if farmPartPos.X >= lockMinX and farmPartPos.X <= lockMaxX and
                   farmPartPos.Z >= lockMinZ and farmPartPos.Z <= lockMaxZ then
                    isLocked = true
                    break
                end
            end
            
            if not isLocked then
                table.insert(unlockedFarmParts, farmPart)
            end
        end
    else
        unlockedFarmParts = farmParts
    end
    
    return unlockedFarmParts
end

-- Optimized tile availability checking with 8x8 grid alignment
local function isTileOccupied(farmPart)
    local center = farmPart.Position
    -- Use grid-snapped position for consistent detection
    local surfacePosition = Vector3.new(
        math.floor(center.X / 8) * 8 + 4, -- Snap to 8x8 grid center (X)
        center.Y + 12, -- Standard height for pets/eggs
        math.floor(center.Z / 8) * 8 + 4  -- Snap to 8x8 grid center (Z)
    )
    
    -- Check PlayerBuiltBlocks
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    if playerBuiltBlocks then
        for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
            if model:IsA("Model") then
                local modelPos = model:GetPivot().Position
                local xzDistance = math.sqrt((modelPos.X - surfacePosition.X)^2 + (modelPos.Z - surfacePosition.Z)^2)
                local yDistance = math.abs(modelPos.Y - surfacePosition.Y)
                
                if xzDistance < 4.0 and yDistance < 12.0 then
                    return true
                end
            end
        end
    end
    
    -- Check workspace.Pets
    local workspacePets = workspace:FindFirstChild("Pets")
    if workspacePets then
        for _, pet in ipairs(workspacePets:GetChildren()) do
            if pet:IsA("Model") then
                local petPos = pet:GetPivot().Position
                local xzDistance = math.sqrt((petPos.X - surfacePosition.X)^2 + (petPos.Z - surfacePosition.Z)^2)
                local yDistance = math.abs(petPos.Y - surfacePosition.Y)
                
                if xzDistance < 4.0 and yDistance < 12.0 then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Enhanced tile cache system
local function updateTileCache()
    local currentTime = time()
    if currentTime - tileCache.lastUpdate < CACHE_DURATION then
        return tileCache.regularAvailable, tileCache.waterAvailable
    end
    
    local islandName = getAssignedIslandName()
    local islandNumber = getIslandNumberFromName(islandName)
    
    if not islandNumber then
        tileCache.regularAvailable = 0
        tileCache.waterAvailable = 0
        return 0, 0
    end
    
    -- Get farm parts
    local regularParts = getFarmParts(islandNumber, false)
    local waterParts = getFarmParts(islandNumber, true)
    
    -- Count available tiles
    local regularAvailable = 0
    local waterAvailable = 0
    local availableRegularTiles = {}
    local availableWaterTiles = {}
    
    for _, part in ipairs(regularParts) do
        if not isTileOccupied(part) then
            regularAvailable = regularAvailable + 1
            table.insert(availableRegularTiles, part)
        end
    end
    
    for _, part in ipairs(waterParts) do
        if not isTileOccupied(part) then
            waterAvailable = waterAvailable + 1
            table.insert(availableWaterTiles, part)
        end
    end
    
    -- Update cache
    tileCache.lastUpdate = currentTime
    tileCache.regularTiles = availableRegularTiles
    tileCache.waterTiles = availableWaterTiles
    tileCache.regularAvailable = regularAvailable
    tileCache.waterAvailable = waterAvailable
    
    return regularAvailable, waterAvailable
end

-- ============ Focus-First Placement System ============
local function waitJitter(baseSeconds)
    local jitter = math.random() * 0.2
    task.wait(baseSeconds + jitter)
end

local function getRandomFromList(list)
    local count = #list
    if count == 0 then return nil end
    return list[math.random(1, count)]
end
local function focusEgg(eggUID)
    if not CharacterRE then
        warn("CharacterRE remote missing; cannot focus egg " .. tostring(eggUID))
        return false
    end
    local success, err = pcall(function()
        CharacterRE:FireServer("Focus", eggUID)
    end)
    if not success then
        warn("Failed to focus egg " .. tostring(eggUID) .. ": " .. tostring(err))
    end
    return success
end

local function placePet(farmPart, eggUID)
    if not farmPart or not eggUID then return false end
    
    -- Enhanced surface position calculation for 8x8 tiles
    -- Ensure perfect centering on both water and regular farm tiles
    local tileCenter = farmPart.Position
    local surfacePosition = Vector3.new(
        math.floor(tileCenter.X / 8) * 8 + 4, -- Snap to 8x8 grid center (X)
        tileCenter.Y + (farmPart.Size.Y / 2), -- Surface height
        math.floor(tileCenter.Z / 8) * 8 + 4  -- Snap to 8x8 grid center (Z)
    )
    
    -- Equip egg to Deploy S2 using the exact UID we've collected
    local deploy = LocalPlayer.PlayerGui.Data:FindFirstChild("Deploy")
    if deploy then
        deploy:SetAttribute("S2", eggUID)
    end
    
    -- Hold egg (key 2)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
    waitJitter(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
    task.wait(0.1)
    
    -- Teleport to tile (use grid-snapped position for consistency)
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            -- Teleport to the exact center of the 8x8 tile
            local teleportPos = Vector3.new(surfacePosition.X, farmPart.Position.Y, surfacePosition.Z)
            hrp.CFrame = CFrame.new(teleportPos)
            waitJitter(0.1)
        end
    end
    
    -- Place pet (using proper vector.create format)
    local vector = { create = function(x, y, z) return Vector3.new(x, y, z) end }
    local args = {
        "Place",
        {
            DST = vector.create(surfacePosition.X, surfacePosition.Y, surfacePosition.Z),
            ID = eggUID
        }
    }

    if not CharacterRE then
        warn("CharacterRE remote missing; cannot place egg " .. tostring(eggUID))
        return false
    end

    local success, err = pcall(function()
        CharacterRE:FireServer(unpack(args))
    end)
    
    if not success then
        warn("Failed to place egg " .. tostring(eggUID) .. ": " .. tostring(err))
        return false
    end
    
    -- Verify placement
    waitJitter(0.25)
    -- Prefer re-checking occupancy at the intended tile center
    if isTileOccupied(farmPart) then
        return true
    end
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    if playerBuiltBlocks then
        for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
            if model:IsA("Model") and model.Name == eggUID then
                return true
            end
        end
    end
    
    return false
end

-- ============ Smart Egg Selection & Placement ============
local function getNextBestEgg()
    local allEggs, oceanEggs, regularEggs = updateAvailableEggs()
    local regularAvailable, waterAvailable = updateTileCache()
    
    -- Smart prioritization: choose egg type based on available space
    if regularAvailable > 0 and #regularEggs > 0 then
        -- Regular farms available, use regular eggs
        return regularEggs[1], getRandomFromList(tileCache.regularTiles), "regular"
    elseif waterAvailable > 0 and #oceanEggs > 0 then
        -- Water farms available, prioritize ocean eggs
        return oceanEggs[1], getRandomFromList(tileCache.waterTiles), "water"
    elseif regularAvailable > 0 and #oceanEggs > 0 then
        -- Only regular farms available but we have ocean eggs - optionally fallback
        if fallbackToRegularWhenNoWater then
            local anyRegular = findAnyAvailableRegularEgg()
            if anyRegular and tileCache.regularTiles and #tileCache.regularTiles > 0 then
                return anyRegular, getRandomFromList(tileCache.regularTiles), "fallback_regular"
            end
        end
        return nil, nil, "skip_ocean"
    end
    
    return nil, nil, "no_space"
end

local function attemptPlacement()
    local eggInfo, tileInfo, reason = getNextBestEgg()
    
    if not eggInfo or not tileInfo then
        if reason == "skip_ocean" then
            -- Ocean eggs skipped - this is normal behavior
            placementStats.lastReason = "Ocean eggs skipped (no water farms)"
            return false, placementStats.lastReason
        elseif reason == "no_space" then
            placementStats.lastReason = "No available tiles for any eggs"
            return false, placementStats.lastReason
        else
            placementStats.lastReason = "No suitable eggs found"
            return false, placementStats.lastReason
        end
    end
    
    -- Focus egg first (game requirement)
    if not focusEgg(eggInfo.uid) then
        placementStats.lastReason = "Failed to focus egg " .. eggInfo.uid
        return false, placementStats.lastReason
    end
    
    task.wait(0.2) -- Wait for focus to register
    
    -- Attempt placement
    local success = placePet(tileInfo, eggInfo.uid)
    
    if success then
        -- Invalidate cache after successful placement
        tileCache.lastUpdate = 0
        eggCache.lastUpdate = 0
        placementStats.lastReason = "Placed " .. (eggInfo.mutation and (eggInfo.mutation .. " ") or "") .. eggInfo.type
        if eggInfo.mutation then
            placementStats.mutationPlacements = placementStats.mutationPlacements + 1
        end
        
        if eggInfo.mutation then
            WindUI:Notify({ 
                Title = "🏠 Auto Place", 
                Content = "Placed " .. eggInfo.mutation .. " " .. eggInfo.type .. " on 8x8 tile!", 
                Duration = 3 
            })
        else
            WindUI:Notify({ 
                Title = "🏠 Auto Place", 
                Content = "Placed " .. eggInfo.type .. " on 8x8 tile!", 
                Duration = 2 
            })
        end
        
        return true, "Successfully placed " .. eggInfo.type
    else
        placementStats.lastReason = "Failed to place " .. eggInfo.type
        return false, placementStats.lastReason
    end
end

-- ============ Auto Place Main Logic ============
local autoPlaceEnabled = false
local autoPlaceThread = nil

local function runAutoPlace()
    local consecutiveFailures = 0
    local maxFailures = 5
    
    while autoPlaceEnabled do
        local success, message = attemptPlacement()
        
        if success then
            placementStats.totalPlacements = placementStats.totalPlacements + 1
            placementStats.lastPlacement = os.time()
            consecutiveFailures = 0
            
            -- Shorter wait after successful placement
            waitJitter(1.5)
        else
            consecutiveFailures = consecutiveFailures + 1
            
            -- Adaptive waiting based on failure reason
            if message:find("skip") or message:find("no water") then
                -- Ocean eggs skipped - wait longer
                waitJitter(5)
            elseif message:find("No available tiles") then
                -- No space - wait longer
                waitJitter(8)
            elseif consecutiveFailures >= maxFailures then
                -- Too many failures - longer wait
                waitJitter(10)
                consecutiveFailures = 0
            else
                -- Normal failure - short wait
                waitJitter(2)
            end
        end
    end
end

-- ============ Public API ============
function AutoPlaceSystem.Init(dependencies)
    WindUI = dependencies.WindUI
    Tabs = dependencies.Tabs
    Config = dependencies.Config
    
    -- Set up UI elements
    math.randomseed(os.time())
    AutoPlaceSystem.CreateUI()
    
    return AutoPlaceSystem
end

function AutoPlaceSystem.CreateUI()
    -- Egg selection dropdown
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
            selectedEggTypes = selection
            eggCache.lastUpdate = 0 -- Invalidate cache
        end
    })
    
    -- Mutation selection dropdown
    local placeMutationDropdown = Tabs.PlaceTab:Dropdown({
        Title = "🧬 Pick Mutations",
        Desc = "Choose which mutations to place (leave empty for all mutations)",
        Values = {"Golden", "Diamond", "Electric", "Fire", "Jurassic"},
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedMutations = selection
            eggCache.lastUpdate = 0 -- Invalidate cache
        end
    })
    
    -- Statistics display
    local statsLabel = Tabs.PlaceTab:Paragraph({
        Title = "📊 Placement Statistics",
        Desc = "Starting up...",
        Image = "activity",
        ImageSize = 16,
    })

    -- Behavior toggle: fallback to regular eggs when no water farms
    Tabs.PlaceTab:Toggle({
        Title = "Fallback to regular eggs when no water farms",
        Desc = "If only ocean eggs are selected but no water tiles, place any regular egg.",
        Value = true,
        Callback = function(state)
            fallbackToRegularWhenNoWater = state
        end
    })
    
    local function updateStats()
        if not statsLabel then return end
        
        local lastPlacementText = ""
        if placementStats.lastPlacement then
            local timeSince = os.time() - placementStats.lastPlacement
            local timeText = timeSince < 60 and (timeSince .. "s ago") or (math.floor(timeSince/60) .. "m ago")
            lastPlacementText = " | 🕒 Last: " .. timeText
        end
        local rAvail, wAvail = updateTileCache()
        local reasonText = placementStats.lastReason and (" | ℹ️ " .. placementStats.lastReason) or ""
        local statsText = string.format("✅ Placed: %d | 🦄 Mutations: %d | 🧱 Tiles R/W: %d/%d%s%s", 
            placementStats.totalPlacements, 
            placementStats.mutationPlacements,
            rAvail or 0,
            wAvail or 0,
            reasonText,
            lastPlacementText)
        
        if statsLabel.SetDesc then
            statsLabel:SetDesc(statsText)
        end
    end
    
    -- Main auto place toggle
    local autoPlaceToggle = Tabs.PlaceTab:Toggle({
        Title = "🏠 Auto Place Pets (Revamped)",
        Desc = "Smart placement with ocean egg skipping and focus-first logic!",
        Value = false,
        Callback = function(state)
            autoPlaceEnabled = state
            
            if state and not autoPlaceThread then
                autoPlaceThread = task.spawn(function()
                    runAutoPlace()
                    autoPlaceThread = nil
                end)
                
                -- Start stats update loop
                task.spawn(function()
                    while autoPlaceEnabled do
                        updateStats()
                        task.wait(3)
                    end
                end)
                
                WindUI:Notify({ Title = "🏠 Auto Place", Content = "Revamped system started! 🎉", Duration = 3 })
            elseif not state and autoPlaceThread then
                WindUI:Notify({ Title = "🏠 Auto Place", Content = "Stopped", Duration = 3 })
            end
        end
    })
    
    -- Store references for external access
    AutoPlaceSystem.Toggle = autoPlaceToggle
    AutoPlaceSystem.EggDropdown = placeEggDropdown
    AutoPlaceSystem.MutationDropdown = placeMutationDropdown
end

function AutoPlaceSystem.SetFilters(eggTypes, mutations)
    selectedEggTypes = eggTypes or {}
    selectedMutations = mutations or {}
    eggCache.lastUpdate = 0 -- Invalidate cache
end

function AutoPlaceSystem.GetStats()
    return placementStats
end

function AutoPlaceSystem.IsEnabled()
    return autoPlaceEnabled
end

function AutoPlaceSystem.SetEnabled(enabled)
    if AutoPlaceSystem.Toggle then
        -- Trigger the toggle to update UI and start/stop system
        AutoPlaceSystem.Toggle:SetValue(enabled)
    end
end

return AutoPlaceSystem
