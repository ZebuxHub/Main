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
local placeEggsEnabled = true
local placePetsEnabled = false
local minPetRateFilter = 0
local petSortAscending = true

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

-- ============ Performance Profiler ============
local performanceStats = {
    enabled = false,
    timings = {},
    lagSpikes = {},
    maxLagThreshold = 0.05, -- 50ms threshold for lag spike detection (more sensitive)
}

local function startTimer(name)
    if not performanceStats.enabled then return end
    performanceStats.timings[name] = tick()
end

local function endTimer(name)
    if not performanceStats.enabled or not performanceStats.timings[name] then return end
    local elapsed = tick() - performanceStats.timings[name]
    performanceStats.timings[name] = nil
    
    -- Log if it's a lag spike
    if elapsed > performanceStats.maxLagThreshold then
        table.insert(performanceStats.lagSpikes, {
            function_name = name,
            duration = elapsed,
            timestamp = os.time()
        })
        
        -- Keep only last 10 lag spikes
        if #performanceStats.lagSpikes > 10 then
            table.remove(performanceStats.lagSpikes, 1)
        end
        
        print(string.format("⚠️ LAG SPIKE: %s took %.3fs", name, elapsed))
    end
    
    return elapsed
end

local function getPerformanceReport()
    local report = "=== AutoPlace Performance Report ===\n"
    report = report .. string.format("Profiling: %s\n", performanceStats.enabled and "ON" or "OFF")
    report = report .. string.format("Recent lag spikes (%d):\n", #performanceStats.lagSpikes)
    
    for i = #performanceStats.lagSpikes, math.max(1, #performanceStats.lagSpikes - 5), -1 do
        local spike = performanceStats.lagSpikes[i]
        report = report .. string.format("  %s: %.3fs\n", spike.function_name, spike.duration)
    end
    
    return report
end

-- ============ Pet Blacklist System ============
local petBlacklist = {} -- UIDs that failed speed verification and should never be placed again

-- ============ Config Cache (ResPet / ResMutate) ============
local resPetById = nil
local resMutateById = nil
local resBigPetScale = nil

-- Cache Util.Pet ModuleScript for global attributes (e.g., BenfitMax)
local UtilPetModuleScript = nil
local function getUtilPetModule()
	if UtilPetModuleScript ~= nil then return UtilPetModuleScript end
	local ok, util = pcall(function()
		return ReplicatedStorage:WaitForChild("Util", 5)
	end)
	if ok and util then
		UtilPetModuleScript = util:FindFirstChild("Pet")
	end
	return UtilPetModuleScript
end

local function getUtilPetAttribute(attrName, defaultValue)
	local mod = getUtilPetModule()
	if mod then
		local ok, val = pcall(function()
			return mod:GetAttribute(attrName)
		end)
		if ok and val ~= nil then return val end
	end
	return defaultValue
end

local function loadConfigModule(moduleScript)
    if not moduleScript then return nil end
    local ok, data = pcall(function()
        return require(moduleScript)
    end)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

local function ensureConfigCached()
    if resPetById and resMutateById and resBigPetScale then return end
    local cfg = ReplicatedStorage:FindFirstChild("Config")
    if not cfg then return end
    resPetById = resPetById or loadConfigModule(cfg:FindFirstChild("ResPet")) or {}
    resMutateById = resMutateById or loadConfigModule(cfg:FindFirstChild("ResMutate")) or {}
    resBigPetScale = resBigPetScale or loadConfigModule(cfg:FindFirstChild("ResBigPetScale")) or {}
end

local function getPetBaseData(petType)
    ensureConfigCached()
    return resPetById and resPetById[petType] or nil
end

local function getMutationData(mutation)
    ensureConfigCached()
    return resMutateById and resMutateById[mutation] or nil
end

local function getBigLevelDefFromExp(totalExp)
    ensureConfigCached()
    if type(resBigPetScale) ~= "table" then return nil end
    local entries = {}
    for key, def in pairs(resBigPetScale) do
        if type(def) == "table" and def.EXP ~= nil then
            table.insert(entries, { level = key, def = def })
        end
    end
    table.sort(entries, function(a, b)
        local ax = tonumber(a.def.EXP) or 0
        local bx = tonumber(b.def.EXP) or 0
        return ax < bx
    end)
    local best = nil
    for _, item in ipairs(entries) do
        local req = tonumber(item.def.EXP) or 0
        if req <= (tonumber(totalExp) or 0) then
            best = item.def
        else
            break
        end
    end
    return best
end

local function isOceanPet(petType)
    local base = getPetBaseData(petType)
    local category = base and base.Category
    if typeof(category) == "string" then
        local c = string.lower(category)
        if string.find(c, "ocean") or string.find(c, "water") or string.find(c, "sea") then
            return true
        end
    end
    -- Fallback heuristic on type name
    if typeof(petType) == "string" then
        local t = string.lower(petType)
        if string.find(t, "fish") or string.find(t, "shark") or string.find(t, "octopus") or string.find(t, "sea") or string.find(t, "angler") then
            return true
        end
    end
    return false
end

local function isBigPet(petType)
    local base = getPetBaseData(petType)
    if not base then return false end
    -- Heuristics from config to identify big pets
    if base.MaxSize and tonumber(base.MaxSize) and tonumber(base.MaxSize) >= 2 then
        return true
    end
    if base.BigRate and tonumber(base.BigRate) and tonumber(base.BigRate) > 0 then
        return true
    end
    if base.PetIndex and tostring(base.PetIndex) == "Big" then
        return true
    end
    if base.Category and tostring(base.Category):lower():find("big") then
        return true
    end
    return false
end

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

local function getPetContainer()
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = pg and pg:FindFirstChild("Data")
    return data and data:FindFirstChild("Pets") or nil
end

local function isPetAlreadyPlacedByUid(petUID)
    local container = getPetContainer()
    local node = container and container:FindFirstChild(petUID)
    if not node then return false end
    local dAttr = node:GetAttribute("D")
    return dAttr ~= nil and tostring(dAttr) ~= ""
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

-- Build a ranked pet candidate list from PlayerGui.Data.Pets
local petCache = {
    lastUpdate = 0,
    candidates = {},
    currentIndex = 1 -- Track which pet to place next for sequential placement
}

local function computeEffectiveRate(petType, mutation, petNode)
    local base = getPetBaseData(petType)
    if not base then return 0 end
    
    -- Use precise decimal arithmetic to avoid floating point errors
    local rate = tonumber(base.ProduceRate) or 0
    
    -- BPV path (big pet exp) overrides base with levelDef.Produce and BigRate
    local bpv = petNode and petNode:GetAttribute("BPV")
    if bpv then
        local levelDef = getBigLevelDefFromExp(bpv)
        if levelDef and levelDef.Produce then
            rate = tonumber(levelDef.Produce) or rate
            -- Scan dynamic MT_* attributes for BigRate max
            local maxBigRate = 1.0
            local ok, attrs = pcall(function()
                return petNode:GetAttributes()
            end)
            if ok and type(attrs) == "table" then
                for key, _ in pairs(attrs) do
                    if type(key) == "string" and key:sub(1,3) == "MT_" then
                        local mutName = key:sub(4)
                        local mdef = getMutationData(mutName)
                        if mdef and tonumber(mdef.BigRate) then
                            maxBigRate = math.max(maxBigRate, tonumber(mdef.BigRate))
                        end
                    end
                end
            end
            -- Use precise multiplication and round to avoid precision errors
            local finalRate = rate * maxBigRate
            return math.floor(finalRate + 0.5) -- Round to nearest integer
        end
    end
    
    -- Size/V scaling: V is an integer scaled by 1e-4, exponent 2.24, scaled by (BenfitMax - 1)
    local vAttr = petNode and petNode:GetAttribute("V")
    local benefitMax = getUtilPetAttribute("BenfitMax", 1)
    if vAttr and benefitMax then
        local vScaled = tonumber(vAttr) and (tonumber(vAttr) * 1.0e-4) or 0.0
        local vMultiplier = ((benefitMax - 1) * (vScaled ^ 2.24)) + 1
        rate = rate * vMultiplier
    end
    
    -- Base mutation multiplier (ProduceRate)
    if mutation then
        local m = getMutationData(mutation)
        if m and tonumber(m.ProduceRate) then
            local mutMultiplier = tonumber(m.ProduceRate)
            rate = rate * mutMultiplier
        end
    end
    
    -- Round to nearest integer to avoid precision issues
    return math.floor(rate + 0.5)
end

local function updateAvailablePets()
    startTimer("updateAvailablePets")
    local currentTime = time()
    if currentTime - petCache.lastUpdate < CACHE_DURATION then
        endTimer("updateAvailablePets")
        return petCache.candidates
    end
    
    startTimer("getPetContainer")
    local container = getPetContainer()
    endTimer("getPetContainer")
    
    local out = {}
    if container then
        startTimer("petLoop")
        local children = container:GetChildren()
        local processedCount = 0
        
        for _, child in ipairs(children) do
            -- Yield every 10 pets to prevent frame drops
            processedCount = processedCount + 1
            if processedCount % 10 == 0 then
                task.wait() -- Yield to prevent lag spikes
            end
            
            local petType = child:GetAttribute("T")
            local mutation = child:GetAttribute("M")
            if mutation == "Dino" then
                mutation = "Jurassic"
            end
            if petType and not isPetAlreadyPlacedByUid(child.Name) and not petBlacklist[child.Name] then
                if (not isBigPet(petType)) then
                    startTimer("computeEffectiveRate")
                    local rate = computeEffectiveRate(petType, mutation, child)
                    endTimer("computeEffectiveRate")
                    if rate >= (minPetRateFilter or 0) then
                        table.insert(out, {
                            uid = child.Name,
                            type = petType,
                            mutation = mutation,
                            effectiveRate = rate,
                            isOcean = isOceanPet(petType)
                        })
                    end
                end
            end
        end
        endTimer("petLoop")
    end
    
    -- Sort pets for sequential placement
    startTimer("petSort")
    table.sort(out, function(a, b)
        if petSortAscending then
            -- Sort by speed first, then by UID for consistent ordering
            if a.effectiveRate == b.effectiveRate then
                return a.uid < b.uid -- Stable sort by UID
            end
            return a.effectiveRate < b.effectiveRate
        else
            if a.effectiveRate == b.effectiveRate then
                return a.uid < b.uid -- Stable sort by UID
            end
            return a.effectiveRate > b.effectiveRate
        end
    end)
    endTimer("petSort")
    
    petCache.lastUpdate = currentTime
    petCache.candidates = out
    -- Reset index when pet list changes
    petCache.currentIndex = 1
    endTimer("updateAvailablePets")
    return out
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
    startTimer("isTileOccupied")
    local center = farmPart.Position
    -- Use grid-snapped position for consistent detection
    local surfacePosition = Vector3.new(
        math.floor(center.X / 8) * 8 + 4, -- Snap to 8x8 grid center (X)
        center.Y + 12, -- Standard height for pets/eggs
        math.floor(center.Z / 8) * 8 + 4  -- Snap to 8x8 grid center (Z)
    )
    
    -- Check PlayerBuiltBlocks (limit iterations to prevent lag)
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    if playerBuiltBlocks then
        local children = playerBuiltBlocks:GetChildren()
        local maxCheck = math.min(#children, 30) -- Reduced from 100 to 30
        for i = 1, maxCheck do
            local model = children[i]
            if model:IsA("Model") then
                local ok, modelPos = pcall(function() return model:GetPivot().Position end)
                if ok then
                    -- Use faster distance calculation (avoid sqrt)
                    local xDiff = modelPos.X - surfacePosition.X
                    local zDiff = modelPos.Z - surfacePosition.Z
                    local xzDistanceSquared = xDiff * xDiff + zDiff * zDiff
                    local yDistance = math.abs(modelPos.Y - surfacePosition.Y)
                    
                    if xzDistanceSquared < 16.0 and yDistance < 12.0 then -- 16.0 = 4.0^2
                        endTimer("isTileOccupied")
                        return true
                    end
                end
            end
        end
    end
    
    -- Check workspace.Pets (limit iterations to prevent lag)
    local workspacePets = workspace:FindFirstChild("Pets")
    if workspacePets then
        local children = workspacePets:GetChildren()
        local maxCheck = math.min(#children, 20) -- Reduced from 50 to 20
        for i = 1, maxCheck do
            local pet = children[i]
            if pet:IsA("Model") then
                local ok, petPos = pcall(function() return pet:GetPivot().Position end)
                if ok then
                    -- Use faster distance calculation (avoid sqrt)
                    local xDiff = petPos.X - surfacePosition.X
                    local zDiff = petPos.Z - surfacePosition.Z
                    local xzDistanceSquared = xDiff * xDiff + zDiff * zDiff
                    local yDistance = math.abs(petPos.Y - surfacePosition.Y)
                    
                    if xzDistanceSquared < 16.0 and yDistance < 12.0 then -- 16.0 = 4.0^2
                        endTimer("isTileOccupied")
                        return true
                    end
                end
            end
        end
    end
    
    endTimer("isTileOccupied")
    return false
end

-- Enhanced tile cache system
local function updateTileCache()
    startTimer("updateTileCache")
    local currentTime = time()
    if currentTime - tileCache.lastUpdate < CACHE_DURATION then
        endTimer("updateTileCache")
        return tileCache.regularAvailable, tileCache.waterAvailable
    end
    
    local islandName = getAssignedIslandName()
    local islandNumber = getIslandNumberFromName(islandName)
    
    if not islandNumber then
        tileCache.regularAvailable = 0
        tileCache.waterAvailable = 0
        endTimer("updateTileCache")
        return 0, 0
    end
    
    -- Get farm parts
    startTimer("getFarmParts")
    local regularParts = getFarmParts(islandNumber, false)
    local waterParts = getFarmParts(islandNumber, true)
    endTimer("getFarmParts")
    
    -- Count available tiles
    local regularAvailable = 0
    local waterAvailable = 0
    local availableRegularTiles = {}
    local availableWaterTiles = {}
    
    startTimer("tileOccupancyCheck")
    local checkedCount = 0
    
    for _, part in ipairs(regularParts) do
        -- Yield every 5 tiles to prevent frame drops
        checkedCount = checkedCount + 1
        if checkedCount % 5 == 0 then
            task.wait() -- Yield to prevent lag spikes
        end
        
        if not isTileOccupied(part) then
            regularAvailable = regularAvailable + 1
            table.insert(availableRegularTiles, part)
        end
    end
    
    for _, part in ipairs(waterParts) do
        -- Continue counting for yielding
        checkedCount = checkedCount + 1
        if checkedCount % 5 == 0 then
            task.wait() -- Yield to prevent lag spikes
        end
        
        if not isTileOccupied(part) then
            waterAvailable = waterAvailable + 1
            table.insert(availableWaterTiles, part)
        end
    end
    endTimer("tileOccupancyCheck")
    
    -- Update cache
    tileCache.lastUpdate = currentTime
    tileCache.regularTiles = availableRegularTiles
    tileCache.waterTiles = availableWaterTiles
    tileCache.regularAvailable = regularAvailable
    tileCache.waterAvailable = waterAvailable
    
    endTimer("updateTileCache")
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
        -- CharacterRE remote missing; cannot focus egg
        return false
    end
    local success, err = pcall(function()
        CharacterRE:FireServer("Focus", eggUID)
    end)
    if not success then
        -- Failed to focus egg
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
        -- CharacterRE remote missing; cannot place egg
        return false
    end

    local success, err = pcall(function()
        CharacterRE:FireServer(unpack(args))
    end)
    
    if not success then
        -- Failed to place egg
        return false
    end
    
    -- Verify placement: check that pet attributes now include D (placed marker)
    waitJitter(0.4)
    local petContainer = getPetContainer()
    local petNode = petContainer and petContainer:FindFirstChild(eggUID)
    if petNode then
        local dAttr = petNode:GetAttribute("D")
        if dAttr ~= nil and tostring(dAttr) ~= "" then
            return true
        end
    end
    -- Fallback: occupancy check
    if isTileOccupied(farmPart) then
        return true
    end
    return false
end

-- ============ Pet Speed Verification & Auto-Delete ============
local function getActualPetSpeedFromWorkspace(petUID)
    -- Look for the placed pet in workspace.Pets
    local workspacePets = workspace:FindFirstChild("Pets")
    if not workspacePets then return nil end
    
    for _, pet in ipairs(workspacePets:GetChildren()) do
        if pet:IsA("Model") and pet.Name == petUID then
            -- Look for speed display in the pet model
            local function findSpeedInModel(model)
                for _, child in ipairs(model:GetDescendants()) do
                    if child:IsA("TextLabel") or child:IsA("SurfaceGui") then
                        local text = child.Text or ""
                        -- Look for speed patterns like "Speed: 123" or "🏃 123"
                        local speedMatch = text:match("Speed:%s*(%d+)") or 
                                         text:match("🏃%s*(%d+)") or
                                         text:match("(%d+)%s*/s") or
                                         text:match("Production:%s*(%d+)")
                        if speedMatch then
                            return tonumber(speedMatch)
                        end
                    end
                end
                return nil
            end
            
            local actualSpeed = findSpeedInModel(pet)
            if actualSpeed then
                return actualSpeed
            end
        end
    end
    return nil
end

local function verifyAndDeletePetIfNeeded(petUID, expectedSpeed)
    -- Wait a moment for pet to fully appear in workspace
    task.wait(1.0)
    
    local actualSpeed = getActualPetSpeedFromWorkspace(petUID)
    if not actualSpeed then
        -- Could not find speed text, assume it's correct for now
        return true
    end
    
    -- Check if actual speed meets minimum requirement
    if actualSpeed < (minPetRateFilter or 0) then
        -- Speed too low! Auto-delete this pet
        WindUI:Notify({
            Title = "🗑️ Auto Delete",
            Content = "Pet speed " .. actualSpeed .. " < " .. (minPetRateFilter or 0) .. ". Deleting pet " .. petUID,
            Duration = 3
        })
        
        -- Add to blacklist first
        petBlacklist[petUID] = true
        
        -- Try to delete the pet using the same method as auto-delete system
        local success = pcall(function()
            if CharacterRE then
                CharacterRE:FireServer("DeletePet", petUID)
            end
        end)
        
        if success then
            -- Clear caches to update lists
            petCache.lastUpdate = 0
            tileCache.lastUpdate = 0
            
            WindUI:Notify({
                Title = "🗑️ Auto Delete", 
                Content = "✅ Deleted pet " .. petUID .. " (speed too low)", 
                Duration = 2
            })
            return false -- Pet was deleted
        else
            WindUI:Notify({
                Title = "🗑️ Auto Delete", 
                Content = "❌ Failed to delete pet " .. petUID, 
                Duration = 2
            })
        end
    end
    
    return true -- Pet is valid and kept
end

local function clearPetBlacklist()
    petBlacklist = {}
    petCache.lastUpdate = 0 -- Force refresh
    WindUI:Notify({
        Title = "🔄 Blacklist Cleared",
        Content = "All blacklisted pets can now be placed again",
        Duration = 2
    })
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

-- Select next pet candidate in sequential order and appropriate tile
local function getNextBestPet()
    local candidates = updateAvailablePets()
    local regularAvailable, waterAvailable = updateTileCache()
    
    if #candidates == 0 then
        return nil, nil, "no_pets"
    end
    
    -- Sequential placement: start from current index and find next valid pet
    local startIndex = petCache.currentIndex
    local found = false
    local selectedCandidate = nil
    local searchAttempts = 0
    
    -- Search through candidates starting from current index
    while searchAttempts < #candidates do
        local currentCandidate = candidates[petCache.currentIndex]
        
        if currentCandidate then
            -- Double-check pet is still not placed
            if not isPetAlreadyPlacedByUid(currentCandidate.uid) then
                -- Check if we have appropriate tiles for this pet
                if currentCandidate.isOcean and waterAvailable > 0 then
                    selectedCandidate = currentCandidate
                    found = true
                    break
                elseif not currentCandidate.isOcean and regularAvailable > 0 then
                    selectedCandidate = currentCandidate
                    found = true
                    break
                end
            end
        end
        
        -- Move to next pet in sequence
        petCache.currentIndex = petCache.currentIndex + 1
        if petCache.currentIndex > #candidates then
            petCache.currentIndex = 1 -- Wrap around
        end
        
        searchAttempts = searchAttempts + 1
        
        -- Prevent infinite loop
        if petCache.currentIndex == startIndex and searchAttempts > 1 then
            break
        end
    end
    
    if not found then
        -- No valid pets found, check why
        local hasOcean = false
        local hasRegular = false
        for _, cand in ipairs(candidates) do
            if not isPetAlreadyPlacedByUid(cand.uid) then
                if cand.isOcean then hasOcean = true end
                if not cand.isOcean then hasRegular = true end
            end
        end
        
        if hasOcean and not hasRegular and waterAvailable == 0 then
            return nil, nil, "skip_ocean"
        else
            return nil, nil, "no_space"
        end
    end
    
    -- Advance index for next placement
    petCache.currentIndex = petCache.currentIndex + 1
    if petCache.currentIndex > #candidates then
        petCache.currentIndex = 1 -- Wrap around
    end
    
    -- Return selected pet and appropriate tile
    if selectedCandidate.isOcean then
        return selectedCandidate, getRandomFromList(tileCache.waterTiles), "water"
    else
        return selectedCandidate, getRandomFromList(tileCache.regularTiles), "regular"
    end
end

local function attemptPlacement()
    startTimer("attemptPlacement")
    local willPlacePet = placePetsEnabled
    local willPlaceEgg = placeEggsEnabled
    -- If both selected, try pet first for variety; alternate could be added later
    if willPlacePet then
        local petInfo, tileInfo, reason = getNextBestPet()
        if not petInfo or not tileInfo then
            if reason == "skip_ocean" then
                placementStats.lastReason = "Ocean pets skipped (no water farms)"
                return false, placementStats.lastReason
            elseif reason == "no_space" then
                placementStats.lastReason = "No available tiles for pets"
                return false, placementStats.lastReason
            elseif reason == "no_pets" then
                placementStats.lastReason = "No pets pass filters"
                return false, placementStats.lastReason
            else
                placementStats.lastReason = "No suitable pets found"
                return false, placementStats.lastReason
            end
        end

        if petInfo.isOcean and tileInfo and tileInfo.Name ~= "WaterFarm_split_0_0_0" then
            placementStats.lastReason = "Blocked ocean pet on regular tile"
            return false, placementStats.lastReason
        end

        -- Skip if already placed (D attribute present)
        local petContainer = getPetContainer()
        local petNode = petContainer and petContainer:FindFirstChild(petInfo.uid)
        if petNode then
            local dAttr = petNode:GetAttribute("D")
            if dAttr ~= nil and tostring(dAttr) ~= "" then
                placementStats.lastReason = "Pet already placed"
                -- Invalidate pet cache so next iteration picks a different pet
                petCache.lastUpdate = 0
                return false, placementStats.lastReason
            end
        end

        if not focusEgg(petInfo.uid) then
            placementStats.lastReason = "Failed to focus pet " .. petInfo.uid
            return false, placementStats.lastReason
        end
        waitJitter(0.2)
        local success = placePet(tileInfo, petInfo.uid)
        if success then
            tileCache.lastUpdate = 0
            petCache.lastUpdate = 0
            
            -- Verify pet speed and auto-delete if needed
            local isValidPet = verifyAndDeletePetIfNeeded(petInfo.uid, petInfo.effectiveRate)
            
            if isValidPet then
                placementStats.lastReason = "Placed pet " .. (petInfo.mutation and (petInfo.mutation .. " ") or "") .. petInfo.type .. " (Speed: " .. petInfo.effectiveRate .. ")"
                if petInfo.mutation then
                    placementStats.mutationPlacements = placementStats.mutationPlacements + 1
                end
                WindUI:Notify({
                    Title = "🏠 Auto Place",
                    Content = "Placed pet " .. (petInfo.mutation and (petInfo.mutation .. " ") or "") .. petInfo.type .. " (Speed: " .. petInfo.effectiveRate .. ")!",
                    Duration = 2
                })
                return true, "Successfully placed pet"
            else
                placementStats.lastReason = "Pet " .. petInfo.type .. " deleted (speed verification failed)"
                return false, placementStats.lastReason
            end
        else
            placementStats.lastReason = "Failed to place pet " .. petInfo.type
            return false, placementStats.lastReason
        end
    end

    if not willPlaceEgg then
        return false, "Egg placement disabled"
    end

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
        
        endTimer("attemptPlacement")
        return true, "Successfully placed " .. eggInfo.type
    else
        placementStats.lastReason = "Failed to place " .. eggInfo.type
        endTimer("attemptPlacement")
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
            if message:find("skip") or message:find("no water") or message:find("Ocean") then
                -- Ocean eggs/pets skipped - wait much longer to reduce CPU
                waitJitter(15)
            elseif message:find("No available tiles") or message:find("no_space") then
                -- No space - wait longer
                waitJitter(12)
            elseif message:find("already placed") then
                -- Candidate was already placed; rescan quickly
                waitJitter(0.5)
            elseif message:find("disabled") then
                -- Placement mode disabled - wait longer
                waitJitter(8)
            elseif consecutiveFailures >= maxFailures then
                -- Too many failures - much longer wait
                waitJitter(20)
                consecutiveFailures = 0
            else
                -- Normal failure - moderate wait
                waitJitter(4)
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
    -- Egg filters section
    Tabs.PlaceTab:Section({
        Title = "Egg Filters",
        Icon = "egg"
    })

    -- Egg selection dropdown
    local placeEggDropdown = Tabs.PlaceTab:Dropdown({
        Title = "Egg Types",
        Desc = "Pick eggs to place (🌊 needs water)",
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
            eggCache.lastUpdate = 0
        end
    })
    
    -- Mutation selection dropdown
    local placeMutationDropdown = Tabs.PlaceTab:Dropdown({
        Title = "Mutations",
        Desc = "Pick mutations (empty = any)",
        Values = {"Golden", "Diamond", "Electric", "Fire", "Jurassic"},
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedMutations = selection
            eggCache.lastUpdate = 0
        end
    })
    
    -- Statistics section with live stats
    Tabs.PlaceTab:Section({
        Title = "Statistics",
        Icon = "activity"
    })
    
    local statsLabel = Tabs.PlaceTab:Paragraph({
        Title = "Stats",
        Desc = "Waiting for placement data..."
    })

    -- Mode & behavior section
    Tabs.PlaceTab:Section({
        Title = "What to Place",
        Icon = "layers"
    })

    -- Replace toggle with multi-select dropdown for placement sources
    local placeModeDropdown = Tabs.PlaceTab:Dropdown({
        Title = "Sources",
        Desc = "Choose what to place",
        Values = {"Eggs","Pets"},
        Value = {"Eggs"},
        Multi = true,
        AllowNone = false,
        Callback = function(selection)
            local set = {}
            for _, v in ipairs(selection or {}) do set[v] = true end
            placeEggsEnabled = set["Eggs"] == true
            placePetsEnabled = set["Pets"] == true
            petCache.lastUpdate = 0
        end
    })

    -- Pet settings section
    Tabs.PlaceTab:Section({
        Title = "Pet Settings",
        Icon = "heart"
    })

    Tabs.PlaceTab:Slider({
        Title = "Min Speed",
        Desc = "Only place pets ≥ this rate",
        Value = {
            Min = 0,
            Max = 50000,
            Default = 0,
        },
        Step = 1,
        Callback = function(val)
            minPetRateFilter = tonumber(val) or 0
            petCache.lastUpdate = 0
        end
    })
    
    -- Replace toggle with dropdown sort order
    Tabs.PlaceTab:Dropdown({
        Title = "Sort Order",
        Desc = "Order by rate",
        Values = {"Low → High","High → Low"},
        Value = "Low → High",
        Multi = false,
        AllowNone = false,
        Callback = function(v)
            petSortAscending = (v == "Low → High")
            petCache.lastUpdate = 0
        end
    })
    
    -- Debug section
    Tabs.PlaceTab:Section({
        Title = "Debug Tools",
        Icon = "bug"
    })
    
    Tabs.PlaceTab:Toggle({
        Title = "Performance Profiler",
        Desc = "Track lag spikes and performance",
        Value = false,
        Callback = function(enabled)
            performanceStats.enabled = enabled
            if enabled then
                performanceStats.lagSpikes = {}
                WindUI:Notify({Title = "Profiler", Content = "Performance tracking enabled", Duration = 2})
            else
                WindUI:Notify({Title = "Profiler", Content = "Performance tracking disabled", Duration = 2})
            end
        end
    })
    
    Tabs.PlaceTab:Button({
        Title = "Performance Report",
        Desc = "Show lag spike analysis",
        Callback = function()
            local report = getPerformanceReport()
            print(report)
            WindUI:Notify({Title = "Performance Report", Content = "Check console for detailed report", Duration = 3})
        end
    })
    
    local performanceMode = "Balanced"
    Tabs.PlaceTab:Dropdown({
        Title = "Performance Mode",
        Desc = "Adjust speed vs smoothness",
        Values = {"Fast", "Balanced", "Smooth"},
        Value = "Balanced",
        Multi = false,
        AllowNone = false,
        Callback = function(mode)
            performanceMode = mode
            -- Adjust cache duration based on mode
            if mode == "Fast" then
                CACHE_DURATION = 3 -- Faster updates, more work
            elseif mode == "Balanced" then
                CACHE_DURATION = 5 -- Default
            else -- Smooth
                CACHE_DURATION = 8 -- Longer cache, less frequent updates
            end
            
            -- Clear caches to apply new settings
            petCache.lastUpdate = 0
            tileCache.lastUpdate = 0
            
            WindUI:Notify({Title = "Performance", Content = "Mode set to " .. mode, Duration = 2})
        end
    })

    -- Run section
    Tabs.PlaceTab:Section({
        Title = "Run",
        Icon = "play"
    })
    
    -- Stats update function
    local function updateStats()
        if not statsLabel then return end
        
        local lastPlacementText = ""
        if placementStats.lastPlacement then
            local timeSince = os.time() - placementStats.lastPlacement
            local timeText = timeSince < 60 and (timeSince .. "s ago") or (math.floor(timeSince/60) .. "m ago")
            lastPlacementText = " | Last: " .. timeText
        end
        local rAvail, wAvail = updateTileCache()
        local reasonText = placementStats.lastReason and (" | " .. placementStats.lastReason) or ""
        local statsText = string.format("Placed: %d | Mutations: %d | Tiles R/W: %d/%d%s%s", 
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
        Title = "Auto Place",
        Desc = "Smart placement system",
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
                
                WindUI:Notify({ Title = "Auto Place", Content = "Started", Duration = 2 })
            elseif not state and autoPlaceThread then
                WindUI:Notify({ Title = "Auto Place", Content = "Stopped", Duration = 2 })
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
