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
local WindUI, Tabs, Config, AutoSystemsConfig, CustomUIConfig
local selectedEggTypes = {}
local selectedMutations = {}
local fallbackToRegularWhenNoWater = true
local placeEggsEnabled = true
local placePetsEnabled = false
local minPetRateFilter = 0
local petSortAscending = true

-- ============ Hologram Placement System ============
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local hologramEnabled = false
local hologramMode = "single" -- "single" or "area"
local selectedTiles = {} -- Array of selected tile positions
local hologramParts = {} -- Visual hologram parts
local hologramConnection = nil
local dragStartPosition = nil
local isDragging = false

-- ============ Auto Equip Best Pet System ============
local autoEquipEnabled = false

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
    -- Strict classification based on game config only (no name heuristics)
    local base = getPetBaseData(petType)
    if not base then return false end
    local category = base.Category
    if typeof(category) == "string" then
        local c = string.lower(category)
        if c == "ocean" then return true end
        -- Some configs may use phrases, keep contains("ocean") but avoid other terms
        if string.find(c, "ocean") then return true end
    end
    local limitedTag = base.LimitedTag
    if typeof(limitedTag) == "string" and string.lower(limitedTag) == "ocean" then
        return true
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
    -- Fetch pet value directly from PlayerGui ScreenStorage UI (Price.Value.Text: "$X,XXX")
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local screenStorage = pg and pg:FindFirstChild("ScreenStorage")
    local frame = screenStorage and screenStorage:FindFirstChild("Frame")
    local contentPet = frame and frame:FindFirstChild("ContentPet")
    local scrolling = contentPet and contentPet:FindFirstChild("ScrollingFrame")
    local node = scrolling and petNode and scrolling:FindFirstChild(petNode.Name)
    local btn = node and node:FindFirstChild("BTN")
    local stat = btn and btn:FindFirstChild("Stat")
    local price = stat and stat:FindFirstChild("Price")
    local valueLabel = price and price:FindFirstChild("Value")
    local txt = nil
    if valueLabel and valueLabel:IsA("TextLabel") then
        txt = valueLabel.Text
    elseif price and price:IsA("TextLabel") then
        txt = price.Text
    end
    if txt then
        local numeric = tonumber((txt:gsub("[^%d]", ""))) or 0
        return numeric
    end
    return 0
end

local function updateAvailablePets()
    local currentTime = time()
    if currentTime - petCache.lastUpdate < CACHE_DURATION then
        return petCache.candidates
    end
    local container = getPetContainer()
    local out = {}
    if container then
        for _, child in ipairs(container:GetChildren()) do
            local petType = child:GetAttribute("T")
            local mutation = child:GetAttribute("M")
            if mutation == "Dino" then
                mutation = "Jurassic"
            end
            -- Simplified: Only check if pet exists, has type, not placed, and not big pet
            if petType and not isPetAlreadyPlacedByUid(child.Name) and not isBigPet(petType) then
                local rate = computeEffectiveRate(petType, mutation, child)
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
    
    -- Sort pets for sequential placement (optimized)
    table.sort(out, function(a, b)
        if petSortAscending then
            return a.effectiveRate < b.effectiveRate
        else
            return a.effectiveRate > b.effectiveRate
        end
    end)
    
    petCache.lastUpdate = currentTime
    petCache.candidates = out
    petCache.currentIndex = 1 -- Reset index
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

-- ============ Optimized Tile Management ============
-- Simplified and faster tile occupation checking
local function isTileOccupied(farmPart)
    local center = farmPart.Position
    -- Optimized position calculation - no grid snapping needed for checking
    local checkPosition = Vector3.new(center.X, center.Y + 8, center.Z)
    
    -- Quick check for pets in workspace
    local workspacePets = workspace:FindFirstChild("Pets")
    if workspacePets then
        for _, pet in ipairs(workspacePets:GetChildren()) do
            if pet:IsA("Model") then
                local petPos = pet:GetPivot().Position
                local distance = (petPos - checkPosition).Magnitude
                if distance < 6.0 then -- Slightly larger radius for safety
                    return true
                end
            end
        end
    end
    
    -- Quick check for built blocks
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    if playerBuiltBlocks then
        for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
            if model:IsA("Model") then
                local modelPos = model:GetPivot().Position
                local distance = (modelPos - checkPosition).Magnitude
                if distance < 6.0 then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Optimized tile cache system with reduced processing
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
    
    -- Get farm parts (cached for performance)
    local regularParts = getFarmParts(islandNumber, false)
    local waterParts = getFarmParts(islandNumber, true)
    
    -- Fast counting with minimal processing
    local regularAvailable = 0
    local waterAvailable = 0
    local availableRegularTiles = {}
    local availableWaterTiles = {}
    
    -- Process regular tiles
    for _, part in ipairs(regularParts) do
        if not isTileOccupied(part) then
            regularAvailable = regularAvailable + 1
            table.insert(availableRegularTiles, part)
        end
    end
    
    -- Process water tiles
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

-- Optimized and reliable placement function
local function placePet(farmPart, eggUID)
    if not farmPart or not eggUID then return false end
    
    -- Simple and fast surface position calculation
    local surfacePosition = Vector3.new(
        farmPart.Position.X,
        farmPart.Position.Y + (farmPart.Size.Y / 2), -- Surface height
        farmPart.Position.Z
    )
    
    -- Equip egg to Deploy S2
    local deploy = LocalPlayer.PlayerGui.Data:FindFirstChild("Deploy")
    if deploy then
        deploy:SetAttribute("S2", eggUID)
    end
    
    -- Hold egg (key 2) - simplified timing
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
    task.wait(0.05)
    
    -- Place pet with simplified vector format
    local args = {
        "Place",
        {
            DST = Vector3.new(surfacePosition.X, surfacePosition.Y, surfacePosition.Z),
            ID = eggUID
        }
    }

    if not CharacterRE then return false end

    local success = pcall(function()
        CharacterRE:FireServer(unpack(args))
    end)
    
    if not success then return false end
    
    -- Quick verification - just check if tile becomes occupied
    task.wait(0.2)
    return isTileOccupied(farmPart)
end

-- Enhanced getNextBestEgg to use hologram tiles if available
local function getNextBestEgg()
    local allEggs, oceanEggs, regularEggs = updateAvailableEggs()
    local regularAvailable, waterAvailable = updateTileCache()
    
    -- If hologram tiles are selected, use those first
    if #selectedTiles > 0 then
        local islandName = getAssignedIslandName()
        local islandNumber = getIslandNumberFromName(islandName)
        
        if islandNumber then
            local allParts = getFarmParts(islandNumber, false) -- Regular tiles
            local waterParts = getFarmParts(islandNumber, true) -- Water tiles
            
            -- Combine all parts
            for _, part in ipairs(waterParts) do
                table.insert(allParts, part)
            end
            
            -- Find first available hologram tile
            for _, tilePos in ipairs(selectedTiles) do
                for _, part in ipairs(allParts) do
                    local distance = (part.Position - tilePos).Magnitude
                    if distance < 4 and not isTileOccupied(part) then
                        -- Determine if this is a water tile
                        local isWaterTile = false
                        for _, waterPart in ipairs(waterParts) do
                            if waterPart == part then
                                isWaterTile = true
                                break
                            end
                        end
                        
                        -- Return appropriate egg type for this tile
                        if isWaterTile and #oceanEggs > 0 then
                            return oceanEggs[1], part, "hologram_water"
                        elseif not isWaterTile and #regularEggs > 0 then
                            return regularEggs[1], part, "hologram_regular"
                        end
                    end
                end
            end
        end
    end
    
    -- Fallback to normal logic if no hologram tiles available
    if regularAvailable > 0 and #regularEggs > 0 then
        return regularEggs[1], getRandomFromList(tileCache.regularTiles), "regular"
    elseif waterAvailable > 0 and #oceanEggs > 0 then
        return oceanEggs[1], getRandomFromList(tileCache.waterTiles), "water"
    elseif regularAvailable > 0 and #oceanEggs > 0 then
        return nil, nil, "skip_ocean"
    end
    
    return nil, nil, "no_space"
end

-- Enhanced getNextBestPet to use hologram tiles if available
local function getNextBestPet()
    local candidates = updateAvailablePets()
    local regularAvailable, waterAvailable = updateTileCache()
    
    if #candidates == 0 then
        return nil, nil, "no_pets"
    end
    
    -- If hologram tiles are selected, use those first
    if #selectedTiles > 0 then
        local islandName = getAssignedIslandName()
        local islandNumber = getIslandNumberFromName(islandName)
        
        if islandNumber then
            local allParts = getFarmParts(islandNumber, false) -- Regular tiles
            local waterParts = getFarmParts(islandNumber, true) -- Water tiles
            
            -- Combine all parts
            for _, part in ipairs(waterParts) do
                table.insert(allParts, part)
            end
            
            -- Find first available hologram tile and matching pet
            for _, tilePos in ipairs(selectedTiles) do
                for _, part in ipairs(allParts) do
                    local distance = (part.Position - tilePos).Magnitude
                    if distance < 4 and not isTileOccupied(part) then
                        -- Determine if this is a water tile
                        local isWaterTile = false
                        for _, waterPart in ipairs(waterParts) do
                            if waterPart == part then
                                isWaterTile = true
                                break
                            end
                        end
                        
                        -- Find appropriate pet for this tile
                        for _, candidate in ipairs(candidates) do
                            if not isPetAlreadyPlacedByUid(candidate.uid) then
                                if (isWaterTile and candidate.isOcean) or (not isWaterTile and not candidate.isOcean) then
                                    return candidate, part, "hologram_match"
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Fallback to normal sequential logic
    if regularAvailable == 0 and waterAvailable == 0 then
        return nil, nil, "no_tiles_available"
    end
    
    -- Sequential placement: start from current index and find next valid pet
    local startIndex = petCache.currentIndex
    local found = false
    local selectedCandidate = nil
    local searchAttempts = 0
    
    while searchAttempts < #candidates do
        local currentCandidate = candidates[petCache.currentIndex]
        
        if currentCandidate then
            if not isPetAlreadyPlacedByUid(currentCandidate.uid) then
                if currentCandidate.isOcean then
                    if waterAvailable > 0 then
                        selectedCandidate = currentCandidate
                        found = true
                        break
                    end
                else
                    if regularAvailable > 0 then
                        selectedCandidate = currentCandidate
                        found = true
                        break
                    end
                end
            end
        end
        
        petCache.currentIndex = petCache.currentIndex + 1
        if petCache.currentIndex > #candidates then
            petCache.currentIndex = 1
        end
        
        searchAttempts = searchAttempts + 1
        
        if petCache.currentIndex == startIndex and searchAttempts > 1 then
            break
        end
    end
    
    if not found then
        return nil, nil, "no_suitable_pets"
    end
    
    petCache.currentIndex = petCache.currentIndex + 1
    if petCache.currentIndex > #candidates then
        petCache.currentIndex = 1
    end
    
    if selectedCandidate.isOcean then
        if waterAvailable > 0 then
            return selectedCandidate, getRandomFromList(tileCache.waterTiles), "water"
        else
            return nil, nil, "ocean_pet_no_tiles"
        end
    else
        if regularAvailable > 0 then
            return selectedCandidate, getRandomFromList(tileCache.regularTiles), "regular"
        else
            return nil, nil, "regular_pet_no_regular_tiles"
        end
    end
end

local function attemptPlacement()
    local willPlacePet = placePetsEnabled
    local willPlaceEgg = placeEggsEnabled
    -- Helper: egg placement flow (callable as fallback or primary)
    local function placeEggFlow()
        if not willPlaceEgg then
            return false, "Egg placement disabled"
        end
        local eggInfo, tileInfo, reason = getNextBestEgg()
        if not eggInfo or not tileInfo then
            if reason == "skip_ocean" then
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
        task.wait(0.2)
        local success = placePet(tileInfo, eggInfo.uid)
        if success then
            eggCache.lastUpdate = 0
            if tileInfo then
                tileCache.lastUpdate = time() - (CACHE_DURATION - 2)
            end
            placementStats.lastReason = "Placed " .. (eggInfo.mutation and (eggInfo.mutation .. " ") or "") .. eggInfo.type
            if eggInfo.mutation then
                placementStats.mutationPlacements = placementStats.mutationPlacements + 1
            end
            if eggInfo.mutation then
                WindUI:Notify({ Title = "🏠 Auto Place", Content = "Placed " .. eggInfo.mutation .. " " .. eggInfo.type .. " on 8x8 tile!", Duration = 3 })
            else
                WindUI:Notify({ Title = "🏠 Auto Place", Content = "Placed " .. eggInfo.type .. " on 8x8 tile!", Duration = 2 })
            end
            return true, "Successfully placed " .. eggInfo.type
        else
            placementStats.lastReason = "Failed to place " .. eggInfo.type
            return false, placementStats.lastReason
        end
    end

    -- If both selected, try pet first for variety; if blocked, fall back to eggs
    if willPlacePet then
        local petInfo, tileInfo, reason = getNextBestPet()
        if not petInfo or not tileInfo then
            if reason == "no_pets" then
                placementStats.lastReason = "No pets pass filters"
                if willPlaceEgg then return placeEggFlow() end
                return false, placementStats.lastReason
            elseif reason == "no_tiles_available" then
                placementStats.lastReason = "No tiles available"
                if willPlaceEgg then return placeEggFlow() end
                return false, placementStats.lastReason
            elseif reason == "ocean_pets_no_tiles" then
                placementStats.lastReason = "Ocean pets need water/regular tiles"
                if willPlaceEgg then return placeEggFlow() end
                return false, placementStats.lastReason
            elseif reason == "regular_pets_no_regular_tiles" then
                placementStats.lastReason = "Regular pets need regular tiles"
                if willPlaceEgg then return placeEggFlow() end
                return false, placementStats.lastReason
            elseif reason == "mixed_pets_insufficient_tiles" then
                placementStats.lastReason = "Not enough tiles for pet types"
                if willPlaceEgg then return placeEggFlow() end
                return false, placementStats.lastReason
            elseif reason == "ocean_pet_no_tiles" then
                placementStats.lastReason = "Ocean pet: no water/regular tiles"
                if willPlaceEgg then return placeEggFlow() end
                return false, placementStats.lastReason
            elseif reason == "regular_pet_no_regular_tiles" then
                placementStats.lastReason = "Regular pet: no regular tiles"
                if willPlaceEgg then return placeEggFlow() end
                return false, placementStats.lastReason
            else
                placementStats.lastReason = "No suitable pets found"
                if willPlaceEgg then return placeEggFlow() end
                return false, placementStats.lastReason
            end
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
            if willPlaceEgg then return placeEggFlow() end
            return false, placementStats.lastReason
        end
        waitJitter(0.2)
        local success = placePet(tileInfo, petInfo.uid)
        if success then
            -- Only invalidate pet cache since we placed a pet
            petCache.lastUpdate = 0
            -- Mark specific tile as occupied instead of full tile rescan
            if tileInfo then
                tileCache.lastUpdate = time() - (CACHE_DURATION - 2) -- Partial refresh in 2 seconds
            end
            
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
            placementStats.lastReason = "Failed to place pet " .. petInfo.type
            if willPlaceEgg then return placeEggFlow() end
            return false, placementStats.lastReason
        end
    end

    -- If we reached here without placing pets, try eggs
    return placeEggFlow()
end

-- ============ Auto Place Main Logic ============
local autoPlaceEnabled = false
local autoPlaceThread = nil

-- ============ Event-Driven Placement System ============
local placementState = {
    isDormant = false,
    lastAttemptTime = 0,
    connections = {},
    dormantReason = ""
}

local function enterDormantMode(reason)
    if placementState.isDormant then return end
    
    placementState.isDormant = true
    placementState.dormantReason = reason
    placementStats.lastReason = "Dormant: " .. reason
    
    print("[AutoPlace] Entering dormant mode:", reason)
end

local function exitDormantMode(trigger)
    if not placementState.isDormant then return end
    
    placementState.isDormant = false
    placementState.dormantReason = ""
    placementStats.lastReason = "Reactivated by: " .. trigger
    
    print("[AutoPlace] Exiting dormant mode, triggered by:", trigger)
    
    -- Only invalidate what might have changed based on trigger
    if trigger:find("eggs") then
        eggCache.lastUpdate = 0
    elseif trigger:find("pets") then
        petCache.lastUpdate = 0
    elseif trigger:find("tile") then
        tileCache.lastUpdate = 0
    else
        -- Unknown trigger, invalidate all (safe fallback)
        eggCache.lastUpdate = 0
        petCache.lastUpdate = 0
        tileCache.lastUpdate = 0
    end
    
    task.spawn(attemptPlacement)
end

local function setupEventMonitoring()
    -- Clear existing connections
    for _, connection in ipairs(placementState.connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
    placementState.connections = {}
    
    -- Monitor for new eggs (triggers reactivation)
    local eggContainer = getEggContainer()
    if eggContainer then
        local function onEggChanged()
            if not autoPlaceEnabled then return end
            task.wait(0.1) -- Brief wait for attributes
            exitDormantMode("new eggs available")
        end
        
        table.insert(placementState.connections, eggContainer.ChildAdded:Connect(onEggChanged))
        table.insert(placementState.connections, eggContainer.ChildRemoved:Connect(onEggChanged))
    end
    
    -- Monitor for new pets (triggers reactivation)
    local petContainer = getPetContainer()
    if petContainer then
        local function onPetChanged()
            if not autoPlaceEnabled then return end
            task.wait(0.1)
            exitDormantMode("new pets available")
        end
        
        table.insert(placementState.connections, petContainer.ChildAdded:Connect(onPetChanged))
        table.insert(placementState.connections, petContainer.ChildRemoved:Connect(onPetChanged))
    end
    
    -- Monitor workspace pets (tiles becoming available)
    local workspacePets = workspace:FindFirstChild("Pets")
    if workspacePets then
        local function onWorkspacePetChanged()
            if not autoPlaceEnabled then return end
            task.wait(0.2) -- Wait for tile to be properly freed
            exitDormantMode("tile freed")
        end
        
        table.insert(placementState.connections, workspacePets.ChildAdded:Connect(onWorkspacePetChanged))
        table.insert(placementState.connections, workspacePets.ChildRemoved:Connect(onWorkspacePetChanged))
    end
    
    -- Monitor PlayerBuiltBlocks (new tiles built)
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    if playerBuiltBlocks then
        local function onBlockChanged()
            if not autoPlaceEnabled then return end
            task.wait(0.2)
            exitDormantMode("new tiles built")
        end
        
        table.insert(placementState.connections, playerBuiltBlocks.ChildAdded:Connect(onBlockChanged))
        table.insert(placementState.connections, playerBuiltBlocks.ChildRemoved:Connect(onBlockChanged))
    end
end

-- Optimized main auto place loop
local function runAutoPlace()
    local consecutiveFailures = 0
    local maxFailures = 5
    
    -- Setup event monitoring
    setupEventMonitoring()
    
    while autoPlaceEnabled do
        -- Skip processing if dormant
        if not placementState.isDormant then
            local success, message = attemptPlacement()
            placementState.lastAttemptTime = time()
            
            if success then
                placementStats.totalPlacements = placementStats.totalPlacements + 1
                placementStats.lastPlacement = os.time()
                consecutiveFailures = 0
                
                -- Shorter wait for faster placement
                task.wait(1.0)
            else
                consecutiveFailures = consecutiveFailures + 1
                
                -- Simplified dormant mode logic
                local shouldGoDormant = false
                local dormantReason = ""
                
                if message:find("No tiles available") or message:find("no_tiles_available") then
                    shouldGoDormant = true
                    dormantReason = "No tiles available"
                elseif message:find("No pets") or message:find("no_pets") then
                    shouldGoDormant = true
                    dormantReason = "No pets available"
                elseif consecutiveFailures >= maxFailures then
                    shouldGoDormant = true
                    dormantReason = "Too many failures"
                    consecutiveFailures = 0
                end
                
                if shouldGoDormant then
                    enterDormantMode(dormantReason)
                else
                    -- Shorter retry delay
                    task.wait(1.0)
                end
            end
        else
            -- Dormant mode - check less frequently
            task.wait(3.0)
        end
    end
    
    -- Cleanup connections when stopping
    for _, connection in ipairs(placementState.connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
    placementState.connections = {}
end

-- ============ Auto Unlock Helper Functions ============
local autoUnlockEnabled = false
local autoUnlockThread = nil
local autoPickUpEnabled = false
local autoPickUpTileFilter = "Both"
local autoPickUpThread = nil
local pickUpSpeedThreshold = 100

-- ============ Hologram Placement System Functions ============

-- Create a hologram part for tile visualization
local function createHologramPart(position, tileType)
    local hologram = Instance.new("Part")
    hologram.Name = "PlacementHologram"
    hologram.Size = Vector3.new(8, 0.5, 8) -- 8x8 tile size, thin height
    hologram.Position = Vector3.new(position.X, position.Y + 4.5, position.Z) -- Slightly above tile
    hologram.Anchored = true
    hologram.CanCollide = false
    hologram.Material = Enum.Material.ForceField
    hologram.Transparency = 0.5
    
    -- Color based on tile type
    if tileType == "water" then
        hologram.Color = Color3.fromRGB(0, 162, 255) -- Blue for water
    elseif tileType == "occupied" then
        hologram.Color = Color3.fromRGB(255, 0, 0) -- Red for occupied
    else
        hologram.Color = Color3.fromRGB(0, 255, 0) -- Green for available
    end
    
    -- Add glowing effect
    local pointLight = Instance.new("PointLight")
    pointLight.Color = hologram.Color
    pointLight.Brightness = 2
    pointLight.Range = 10
    pointLight.Parent = hologram
    
    -- Add pulsing animation
    local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    local tween = TweenService:Create(hologram, tweenInfo, {Transparency = 0.2})
    tween:Play()
    
    hologram.Parent = workspace
    return hologram
end

-- Clear all hologram parts
local function clearHolograms()
    for _, hologram in ipairs(hologramParts) do
        if hologram and hologram.Parent then
            hologram:Destroy()
        end
    end
    hologramParts = {}
end

-- Get tile type at position (water, regular, occupied)
local function getTileTypeAtPosition(position)
    local islandName = getAssignedIslandName()
    local islandNumber = getIslandNumberFromName(islandName)
    
    if not islandNumber then return "invalid" end
    
    -- Check if position matches a water tile
    local waterParts = getFarmParts(islandNumber, true)
    for _, waterPart in ipairs(waterParts) do
        local distance = (waterPart.Position - position).Magnitude
        if distance < 4 then -- Within tile bounds
            return isTileOccupied(waterPart) and "occupied" or "water"
        end
    end
    
    -- Check if position matches a regular tile
    local regularParts = getFarmParts(islandNumber, false)
    for _, regularPart in ipairs(regularParts) do
        local distance = (regularPart.Position - position).Magnitude
        if distance < 4 then -- Within tile bounds
            return isTileOccupied(regularPart) and "occupied" or "regular"
        end
    end
    
    return "invalid"
end

-- Snap position to 8x8 grid
local function snapToGrid(position)
    return Vector3.new(
        math.floor(position.X / 8) * 8 + 4,
        position.Y,
        math.floor(position.Z / 8) * 8 + 4
    )
end

-- Update holograms based on selected tiles
local function updateHolograms()
    clearHolograms()
    
    for _, tilePos in ipairs(selectedTiles) do
        local tileType = getTileTypeAtPosition(tilePos)
        local hologram = createHologramPart(tilePos, tileType)
        table.insert(hologramParts, hologram)
    end
end

-- Handle mouse/touch input for tile selection
local function onInputBegan(input)
    if not hologramEnabled then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local camera = workspace.CurrentCamera
        local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
        
        -- Raycast to find tiles
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {workspace.Pets, workspace.PlayerBuiltBlocks}
        
        local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
        
        if raycastResult and raycastResult.Instance then
            local hitPart = raycastResult.Instance
            local hitPosition = raycastResult.Position
            
            -- Check if we hit a farm tile
            if hitPart.Name:match("Farm_split") or hitPart.Name == "WaterFarm_split_0_0_0" then
                local snappedPos = snapToGrid(hitPosition)
                
                if hologramMode == "single" then
                    -- Single tile selection
                    selectedTiles = {snappedPos}
                    updateHolograms()
                elseif hologramMode == "area" then
                    -- Area selection - start drag
                    isDragging = true
                    dragStartPosition = snappedPos
                    selectedTiles = {snappedPos}
                    updateHolograms()
                end
            end
        end
    end
end

local function onInputChanged(input)
    if not hologramEnabled or not isDragging then return end
    
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        local camera = workspace.CurrentCamera
        local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
        
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {workspace.Pets, workspace.PlayerBuiltBlocks}
        
        local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
        
        if raycastResult and raycastResult.Instance then
            local hitPart = raycastResult.Instance
            local hitPosition = raycastResult.Position
            
            if hitPart.Name:match("Farm_split") or hitPart.Name == "WaterFarm_split_0_0_0" then
                local snappedPos = snapToGrid(hitPosition)
                
                -- Create area selection from drag start to current position
                if dragStartPosition then
                    selectedTiles = {}
                    
                    local minX = math.min(dragStartPosition.X, snappedPos.X)
                    local maxX = math.max(dragStartPosition.X, snappedPos.X)
                    local minZ = math.min(dragStartPosition.Z, snappedPos.Z)
                    local maxZ = math.max(dragStartPosition.Z, snappedPos.Z)
                    
                    -- Add all tiles in the rectangular area
                    for x = minX, maxX, 8 do
                        for z = minZ, maxZ, 8 do
                            local tilePos = Vector3.new(x, dragStartPosition.Y, z)
                            table.insert(selectedTiles, tilePos)
                        end
                    end
                    
                    updateHolograms()
                end
            end
        end
    end
end

local function onInputEnded(input)
    if not hologramEnabled then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = false
        dragStartPosition = nil
    end
end

-- Enable/disable hologram system
local function setHologramEnabled(enabled)
    hologramEnabled = enabled
    
    if enabled then
        -- Connect input handlers
        UserInputService.InputBegan:Connect(onInputBegan)
        UserInputService.InputChanged:Connect(onInputChanged)
        UserInputService.InputEnded:Connect(onInputEnded)
        
        -- Start periodic hologram updates
        task.spawn(function()
            while hologramEnabled do
                if #selectedTiles > 0 then
                    updateHolograms()
                end
                task.wait(2) -- Update every 2 seconds
            end
        end)
        
        WindUI:Notify({
            Title = "🎯 Hologram Mode",
            Content = "Click tiles to select placement locations!",
            Duration = 3
        })
    else
        -- Clear holograms and disconnect handlers
        clearHolograms()
        selectedTiles = {}
        
        WindUI:Notify({
            Title = "🎯 Hologram Mode",
            Content = "Hologram placement disabled",
            Duration = 2
        })
    end
end

-- ============ Auto Equip Best Pet System ============

-- Get the best pet (highest value) from ALL pets in inventory
local function getBestPet()
    local container = getPetContainer()
    local allPets = {}
    
    if not container then
        return nil, "Pet container not found"
    end
    
    -- Get ALL pets regardless of filters
    for _, child in ipairs(container:GetChildren()) do
        local petType = child:GetAttribute("T")
        local mutation = child:GetAttribute("M")
        if mutation == "Dino" then
            mutation = "Jurassic"
        end
        
        if petType then
            local rate = computeEffectiveRate(petType, mutation, child)
            table.insert(allPets, {
                uid = child.Name,
                type = petType,
                mutation = mutation,
                effectiveRate = rate,
                isOcean = isOceanPet(petType)
            })
        end
    end
    
    if #allPets == 0 then
        return nil, "No pets available"
    end
    
    -- Sort by effectiveRate (highest first)
    table.sort(allPets, function(a, b)
        return a.effectiveRate > b.effectiveRate
    end)
    
    return allPets[1], "Best pet found"
end

-- Equip pet to Deploy S2 slot
local function equipPet(petUID)
    if not petUID then return false end
    
    local deploy = LocalPlayer.PlayerGui.Data:FindFirstChild("Deploy")
    if deploy then
        deploy:SetAttribute("S2", petUID)
        return true
    end
    
    return false
end

-- Auto equip best pet function
local function autoEquipBestPet()
    local bestPet, message = getBestPet()
    
    if not bestPet then
        WindUI:Notify({
            Title = "🔧 Auto Equip",
            Content = "❌ " .. message,
            Duration = 3
        })
        return false
    end
    
    local success = equipPet(bestPet.uid)
    
    if success then
        WindUI:Notify({
            Title = "🔧 Auto Equip",
            Content = "✅ Equipped " .. (bestPet.mutation and (bestPet.mutation .. " ") or "") .. bestPet.type .. " (Speed: " .. bestPet.effectiveRate .. ")",
            Duration = 4
        })
        return true
    else
        WindUI:Notify({
            Title = "🔧 Auto Equip",
            Content = "❌ Failed to equip pet",
            Duration = 3
        })
        return false
    end
end

-- Enhanced placement function using selected tiles
local function placeOnSelectedTiles()
    if #selectedTiles == 0 then
        WindUI:Notify({
            Title = "🎯 Hologram Place",
            Content = "❌ No tiles selected! Enable hologram mode and select tiles first.",
            Duration = 4
        })
        return false
    end
    
    local placedCount = 0
    local totalTiles = #selectedTiles
    
    WindUI:Notify({
        Title = "🎯 Hologram Place",
        Content = "🚀 Placing on " .. totalTiles .. " selected tiles...",
        Duration = 3
    })
    
    for i, tilePos in ipairs(selectedTiles) do
        -- Find the actual farm part at this position
        local islandName = getAssignedIslandName()
        local islandNumber = getIslandNumberFromName(islandName)
        
        if islandNumber then
            local allParts = getFarmParts(islandNumber, false) -- Regular tiles
            local waterParts = getFarmParts(islandNumber, true) -- Water tiles
            
            -- Combine all parts
            for _, part in ipairs(waterParts) do
                table.insert(allParts, part)
            end
            
            -- Find matching farm part
            local targetPart = nil
            for _, part in ipairs(allParts) do
                local distance = (part.Position - tilePos).Magnitude
                if distance < 4 and not isTileOccupied(part) then
                    targetPart = part
                    break
                end
            end
            
            if targetPart then
                -- Get best egg or pet to place
                local eggInfo, tileInfo, reason = getNextBestEgg()
                local petInfo, petTileInfo, petReason = getNextBestPet()
                
                local itemToPlace = nil
                local isEgg = false
                
                -- Choose what to place based on availability and settings
                if placeEggsEnabled and eggInfo then
                    itemToPlace = eggInfo
                    isEgg = true
                elseif placePetsEnabled and petInfo then
                    itemToPlace = petInfo
                    isEgg = false
                end
                
                if itemToPlace then
                    -- Focus the item first
                    if focusEgg(itemToPlace.uid) then
                        task.wait(0.1)
                        -- Place the item on the target tile
                        local success = placePet(targetPart, itemToPlace.uid)
                        if success then
                            placedCount = placedCount + 1
                            -- Update caches
                            if isEgg then
                                eggCache.lastUpdate = 0
                            else
                                petCache.lastUpdate = 0
                            end
                            tileCache.lastUpdate = 0
                            
                            -- Update holograms to show new occupied state
                            updateHolograms()
                        end
                    end
                end
                
                task.wait(0.3) -- Small delay between placements
            end
        end
        
        -- Update progress
        if i % 3 == 0 or i == totalTiles then
            WindUI:Notify({
                Title = "🎯 Hologram Place",
                Content = "Progress: " .. placedCount .. "/" .. i .. " tiles",
                Duration = 1
            })
        end
    end
    
    -- Final update of holograms
    updateHolograms()
    
    WindUI:Notify({
        Title = "🎯 Hologram Place",
        Content = "✅ Completed! Placed on " .. placedCount .. "/" .. totalTiles .. " tiles",
        Duration = 4
    })
    
    return placedCount > 0
end

local function getLockedTilesForCurrentIsland()
    local lockedTiles = {}
    local islandName = getAssignedIslandName()
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
        if lockModel:IsA("Model") then
            local farmPart = lockModel:FindFirstChild("Farm")
            if farmPart and farmPart:IsA("BasePart") and farmPart.Transparency == 0 then
                local lockCost = farmPart:GetAttribute("LockCost") or 0
                table.insert(lockedTiles, {
                    modelName = lockModel.Name,
                    farmPart = farmPart,
                    cost = lockCost,
                    model = lockModel
                })
            end
        end
    end
    
    return lockedTiles
end

local function unlockTile(lockInfo)
    if not lockInfo or not lockInfo.farmPart then return false end
    
    local args = { "Unlock", lockInfo.farmPart }
    local success = pcall(function()
        if CharacterRE then
            CharacterRE:FireServer(unpack(args))
        end
    end)
    
    return success
end

local function getPlayerNetWorth()
    if not LocalPlayer then return 0 end
    local attrValue = LocalPlayer:GetAttribute("NetWorth")
    if type(attrValue) == "number" then return attrValue end
    return 0
end

local function runAutoUnlock()
    while autoUnlockEnabled do
        local ok, err = pcall(function()
            local lockedTiles = getLockedTilesForCurrentIsland()
            if #lockedTiles == 0 then
                task.wait(2)
                return
            end
            
            table.sort(lockedTiles, function(a, b)
                return (a.cost or 0) < (b.cost or 0)
            end)
            
            for _, lockInfo in ipairs(lockedTiles) do
                if not autoUnlockEnabled then break end
                local netWorth = getPlayerNetWorth()
                if netWorth >= (lockInfo.cost or 0) then
                    if unlockTile(lockInfo) then
                        task.wait(0.5)
                    end
                end
            end
            
            task.wait(3)
        end)
        
        if not ok then
            warn("Auto Unlock error: " .. tostring(err))
            task.wait(1)
        end
    end
end

-- ============ Auto Pick Up Helper Functions ============
local function parseNumberWithSuffix(text)
    if not text or type(text) ~= "string" then return nil end
    
    local cleanText = text:gsub("[$€£¥₹/s,]", ""):gsub("^%s*(.-)%s*$", "%1")
    local number, suffix = cleanText:match("^([%d%.]+)([KkMmBbTt]?)$")
    
    if not number then
        number = cleanText:match("([%d%.]+)")
    end
    
    local numValue = tonumber(number)
    if not numValue then return nil end
    
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

local function runAutoPickUp()
    while autoPickUpEnabled do
        local ok, err = pcall(function()
            local petsFolder = workspace:FindFirstChild("Pets")
            if not petsFolder then
                task.wait(1)
                return
            end
            
            local playerUserId = LocalPlayer.UserId
            local petsToDelete = {}
            
            for _, pet in ipairs(petsFolder:GetChildren()) do
                if not autoPickUpEnabled then break end
                
                if pet:IsA("Model") then
                    local petUserId = pet:GetAttribute("UserId")
                    if petUserId and tonumber(petUserId) == playerUserId then
                        local rootPart = pet:FindFirstChild("RootPart")
                        if rootPart then
                            -- Classify by pet type (from Data.Pets) instead of world position
                            local petTypeForFilter = nil
                            do
                                local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
                                local data = pg and pg:FindFirstChild("Data")
                                local invPets = data and data:FindFirstChild("Pets")
                                local conf = invPets and invPets:FindFirstChild(pet.Name)
                                if conf and conf:IsA("Configuration") then
                                    petTypeForFilter = conf:GetAttribute("T")
                                end
                            end
                            local isOcean = false
                            if petTypeForFilter then
                                isOcean = isOceanPet(petTypeForFilter)
                            end
                            if autoPickUpTileFilter == "Regular" and isOcean then
                                -- Skip ocean pets when filtering for Normal tiles
                                -- (using type classification from ResPet)
                            else
                                if autoPickUpTileFilter == "Ocean" and not isOcean then
                                    -- Skip normal pets when filtering for Ocean
                                else
                                    local idleGUI = rootPart:FindFirstChild("GUI/IdleGUI", true)
                                    if idleGUI then
                                        local speedText = idleGUI:FindFirstChild("Speed")
                                        if speedText and speedText:IsA("TextLabel") then
                                            local speedValue = parseNumberWithSuffix(speedText.Text)
                                            if speedValue and speedValue < pickUpSpeedThreshold then
                                                table.insert(petsToDelete, { name = pet.Name })
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            for _, petInfo in ipairs(petsToDelete) do
                if not autoPickUpEnabled then break end
                
                local success = pcall(function()
                    if CharacterRE then
                        CharacterRE:FireServer("Del", petInfo.name)
                    end
                end)
                
                if success then
                    task.wait(0.5)
                else
                    task.wait(0.2)
                end
            end
            
            task.wait(3)
        end)
        
        if not ok then
            warn("Auto Pick Up error: " .. tostring(err))
            task.wait(1)
        end
    end
end

-- ============ Public API ============
function AutoPlaceSystem.Init(dependencies)
    WindUI = dependencies.WindUI
    Tabs = dependencies.Tabs
    Config = dependencies.Config
    AutoSystemsConfig = dependencies.AutoSystemsConfig or dependencies.Config
    CustomUIConfig = dependencies.CustomUIConfig or dependencies.Config
    
    -- Set up UI elements
    math.randomseed(os.time())
    AutoPlaceSystem.CreateUI()
    
    return AutoPlaceSystem
end

-- Function to sync loaded values to internal variables
function AutoPlaceSystem.SyncLoadedValues()
    -- Sync Min Speed value (now an Input field)
    if AutoPlaceSystem.MinSpeedSlider and AutoPlaceSystem.MinSpeedSlider.Value then
        local inputValue = AutoPlaceSystem.MinSpeedSlider.Value
        local parsedValue = parseNumberWithSuffix(inputValue)
        if parsedValue and parsedValue >= 0 then
            minPetRateFilter = parsedValue
        else
            minPetRateFilter = tonumber(inputValue) or 0
        end
        print("[AutoPlace] Synced Min Speed:", minPetRateFilter, "from input:", inputValue)
    end
    
    -- Sync Sort Order value
    if AutoPlaceSystem.SortOrderDropdown and AutoPlaceSystem.SortOrderDropdown.Value then
        local sortValue = AutoPlaceSystem.SortOrderDropdown.Value
        petSortAscending = (sortValue == "Low to High")
        print("[AutoPlace] Synced Sort Order:", sortValue, "Ascending:", petSortAscending)
    end
    
    -- Sync Sources value
    if AutoPlaceSystem.PlaceModeDropdown and AutoPlaceSystem.PlaceModeDropdown.Value then
        local sources = AutoPlaceSystem.PlaceModeDropdown.Value
        local set = {}
        if type(sources) == "table" then
            for _, v in ipairs(sources) do set[v] = true end
        end
        placeEggsEnabled = set["Eggs"] == true
        placePetsEnabled = set["Pets"] == true
        print("[AutoPlace] Synced Sources - Eggs:", placeEggsEnabled, "Pets:", placePetsEnabled)
    end
    
    -- Force cache invalidation to apply new settings
    petCache.lastUpdate = 0
    eggCache.lastUpdate = 0
end

function AutoPlaceSystem.CreateUI()
    -- Define config references at the start for use throughout the function
    local configForDropdowns = CustomUIConfig or Config
    local configForSettings = AutoSystemsConfig or Config
    
    -- Store references for GetConfigElements
    local minSpeedSliderRef, sortOrderDropdownRef, placeModeDropdownRef
    local autoUnlockToggleRef, autoPickUpToggleRef, autoPickUpTileDropdownRef, autoPickUpSpeedSliderRef
    
    -- Statistics first
    Tabs.PlaceTab:Section({
        Title = "Statistics",
        Icon = "activity"
    })

    local statsLabel = Tabs.PlaceTab:Paragraph({
        Title = "Stats",
        Desc = "Live placement stats"
    })

    -- Egg Settings
    Tabs.PlaceTab:Section({
        Title = "Egg Settings",
        Icon = "egg"
    })

    -- Egg selection dropdown
    local placeEggDropdown = Tabs.PlaceTab:Dropdown({
        Title = "Egg Types",
        Desc = "Choose eggs to place",
        Values = {
            "BasicEgg", "RareEgg", "SuperRareEgg", "EpicEgg", "LegendEgg", "PrismaticEgg", 
            "HyperEgg", "VoidEgg", "BowserEgg", "DemonEgg", "CornEgg", "BoneDragonEgg", 
            "UltraEgg", "DinoEgg", "FlyEgg", "UnicornEgg", "AncientEgg", "UnicornProEgg",
            "DarkGoatyEgg", "SnowbunnyEgg", "RhinoRockEgg", "SaberCubEgg", "GeneralKongEgg", "PegasusEgg",
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
    -- Register with CustomUIConfig for dropdowns
    if configForDropdowns then
        pcall(function()
            configForDropdowns:Register("autoPlaceEggTypes", placeEggDropdown)
        end)
    end
    
    -- Mutation selection dropdown
    local placeMutationDropdown = Tabs.PlaceTab:Dropdown({
        Title = "Mutations",
        Desc = "Choose mutations (optional)",
        Values = {"Golden", "Diamond", "Electirc", "Fire", "Jurassic", "Snow"},
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedMutations = selection
            eggCache.lastUpdate = 0
        end
    })
    if configForDropdowns then
        pcall(function()
            configForDropdowns:Register("autoPlaceMutations", placeMutationDropdown)
        end)
    end

    -- Pet Settings
    Tabs.PlaceTab:Section({
        Title = "Pet Settings",
        Icon = "heart"
    })

    minSpeedSliderRef = Tabs.PlaceTab:Input({
        Title = "Min Speed",
        Desc = "Min pet value (supports 1K, 1M, 1B, 1T)",
        Value = "0",
        Callback = function(value)
            local parsedValue = parseNumberWithSuffix(value)
            if parsedValue and parsedValue >= 0 then
                minPetRateFilter = parsedValue
            else
                minPetRateFilter = tonumber(value) or 0
            end
            petCache.lastUpdate = 0
        end
    })
    if configForSettings then
        pcall(function()
            configForSettings:Register("autoPlaceMinSpeed", minSpeedSliderRef)
        end)
    end

    sortOrderDropdownRef = Tabs.PlaceTab:Dropdown({
        Title = "Sort Order",
        Desc = "Sort by value",
        Values = {"Low to High","High to Low"},
        Value = "Low to High",
        Multi = false,
        AllowNone = false,
        Callback = function(v)
            petSortAscending = (v == "Low to High")
            petCache.lastUpdate = 0
        end
    })
    if configForSettings then
        pcall(function()
            configForSettings:Register("autoPlaceSortOrder", sortOrderDropdownRef)
        end)
    end

    -- Mode & behavior (Sources)
    Tabs.PlaceTab:Section({
        Title = "What to Place",
        Icon = "layers"
    })

    -- Replace toggle with multi-select dropdown for placement sources
    placeModeDropdownRef = Tabs.PlaceTab:Dropdown({
        Title = "Sources",
        Desc = "Pick sources",
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
    -- Register with AutoSystemsConfig for settings
    if configForSettings then
        pcall(function()
            configForSettings:Register("autoPlaceSources", placeModeDropdownRef)
        end)
    end

    -- ============ NEW: Hologram Placement System UI ============
    Tabs.PlaceTab:Section({
        Title = "🎯 Hologram Placement",
        Icon = "target"
    })

    -- Hologram mode dropdown
    local hologramModeDropdown = Tabs.PlaceTab:Dropdown({
        Title = "Selection Mode",
        Desc = "Choose how to select tiles",
        Values = {"Single Tile", "Area Drag"},
        Value = "Single Tile",
        Multi = false,
        AllowNone = false,
        Callback = function(value)
            if value == "Single Tile" then
                hologramMode = "single"
            elseif value == "Area Drag" then
                hologramMode = "area"
            end
        end
    })
    if configForSettings then
        pcall(function()
            configForSettings:Register("hologramMode", hologramModeDropdown)
        end)
    end

    -- Hologram toggle
    local hologramToggle = Tabs.PlaceTab:Toggle({
        Title = "Enable Hologram Mode",
        Desc = "Click/drag tiles to select placement locations",
        Value = false,
        Callback = function(state)
            setHologramEnabled(state)
        end
    })
    if configForSettings then
        pcall(function()
            configForSettings:Register("hologramEnabled", hologramToggle)
        end)
    end

    -- Clear selected tiles button
    Tabs.PlaceTab:Button({
        Title = "Clear Selected Tiles",
        Desc = "Remove all selected hologram tiles",
        Callback = function()
            selectedTiles = {}
            clearHolograms()
            WindUI:Notify({
                Title = "🎯 Hologram",
                Content = "✅ Cleared all selected tiles",
                Duration = 2
            })
        end
    })

    -- Refresh holograms button
    Tabs.PlaceTab:Button({
        Title = "Refresh Holograms",
        Desc = "Update hologram colors to show current tile status",
        Callback = function()
            if #selectedTiles > 0 then
                updateHolograms()
                WindUI:Notify({
                    Title = "🎯 Hologram",
                    Content = "✅ Refreshed hologram colors",
                    Duration = 2
                })
            else
                WindUI:Notify({
                    Title = "🎯 Hologram",
                    Content = "❌ No tiles selected to refresh",
                    Duration = 2
                })
            end
        end
    })

    -- Place on selected tiles button
    Tabs.PlaceTab:Button({
        Title = "Place on Selected Tiles",
        Desc = "Place pets/eggs on all selected hologram tiles",
        Callback = function()
            placeOnSelectedTiles()
        end
    })

    -- ============ NEW: Auto Equip Best Pet System UI ============
    Tabs.PlaceTab:Section({
        Title = "🔧 Auto Equip",
        Icon = "wrench"
    })

    -- Auto equip best pet button
    Tabs.PlaceTab:Button({
        Title = "Equip Best Pet",
        Desc = "Automatically equip your highest value pet",
        Callback = function()
            autoEquipBestPet()
        end
    })

    -- Show current equipped pet info
    local equippedPetLabel = Tabs.PlaceTab:Paragraph({
        Title = "Currently Equipped",
        Desc = "No pet equipped"
    })

    -- Function to update equipped pet display
    local function updateEquippedPetDisplay()
        local deploy = LocalPlayer.PlayerGui.Data:FindFirstChild("Deploy")
        if deploy then
            local equippedUID = deploy:GetAttribute("S2")
            if equippedUID then
                -- Try to get pet info
                local candidates = updateAvailablePets()
                local equippedPet = nil
                
                for _, pet in ipairs(candidates) do
                    if pet.uid == equippedUID then
                        equippedPet = pet
                        break
                    end
                end
                
                if equippedPet then
                    local displayText = (equippedPet.mutation and (equippedPet.mutation .. " ") or "") .. 
                                      equippedPet.type .. " (Speed: " .. equippedPet.effectiveRate .. ")"
                    equippedPetLabel:SetDesc(displayText)
                else
                    equippedPetLabel:SetDesc("Unknown pet: " .. tostring(equippedUID))
                end
            else
                equippedPetLabel:SetDesc("No pet equipped")
            end
        else
            equippedPetLabel:SetDesc("Deploy system not found")
        end
    end

    -- Update equipped pet display periodically
    task.spawn(function()
        while true do
            updateEquippedPetDisplay()
            task.wait(3)
        end
    end)

    -- Stats update function (defined before usage)
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
        local dormantText = placementState.isDormant and " 💤" or ""
        local statsText = string.format("Placed: %d | Mutations: %d | Tiles R/W: %d/%d%s%s%s", 
            placementStats.totalPlacements, 
            placementStats.mutationPlacements,
            rAvail or 0,
            wAvail or 0,
            reasonText,
            lastPlacementText,
            dormantText)
        
        if statsLabel.SetDesc then
            statsLabel:SetDesc(statsText)
        end
    end

    -- Auto Place toggle (moved here under Sort Order)
    local autoPlaceToggle = Tabs.PlaceTab:Toggle({
        Title = "Auto Place",
        Desc = "Automatically place pets/eggs",
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

    -- Store reference
    AutoPlaceSystem.Toggle = autoPlaceToggle
    -- Register with Config manager so the value is saved/loaded
    if configForSettings then
        pcall(function()
            configForSettings:Register("autoPlaceEnabled", autoPlaceToggle)
        end)
    end
    
    -- Tile Management section
    Tabs.PlaceTab:Section({
        Title = "Tile Management",
        Icon = "land-plot"
    })
    
    autoUnlockToggleRef = Tabs.PlaceTab:Toggle({
        Title = "Auto Unlock Tiles",
        Desc = "Unlock tiles automatically",
        Value = false,
        Callback = function(state)
            autoUnlockEnabled = state
            
            if state and not autoUnlockThread then
                autoUnlockThread = task.spawn(function()
                    runAutoUnlock()
                    autoUnlockThread = nil
                end)
                WindUI:Notify({ Title = "Auto Unlock", Content = "Started", Duration = 2 })
            elseif not state and autoUnlockThread then
                WindUI:Notify({ Title = "Auto Unlock", Content = "Stopped", Duration = 2 })
            end
        end
    })
    if configForSettings then
        pcall(function()
            configForSettings:Register("autoUnlockEnabled", autoUnlockToggleRef)
        end)
    end
    
    -- (Removed) Auto Pick Up tab controls are consolidated under PlaceTab
    
    -- Auto Pick Up controls under the same section as Tile Management
    
    autoPickUpTileDropdownRef = Tabs.PlaceTab:Dropdown({
        Title = "Tile Filter",
        Desc = "Pick up on: Normal or Ocean",
        Values = {"Both", "Normal", "Ocean"},
        Value = "Both",
        Callback = function(value)
            if value == "Normal" then
                autoPickUpTileFilter = "Regular"
            elseif value == "Ocean" then
                autoPickUpTileFilter = "Ocean"
            else
                autoPickUpTileFilter = "Both"
            end
        end
    })
    if configForSettings then
        pcall(function()
            configForSettings:Register("autoPickUpTileFilter", autoPickUpTileDropdownRef)
        end)
    end
    
    autoPickUpSpeedSliderRef = Tabs.PlaceTab:Input({
        Title = "Speed Threshold",
        Desc = "Pick up pets below this speed",
        Value = "100",
        Callback = function(value)
            local parsedValue = parseNumberWithSuffix(value)
            if parsedValue and parsedValue > 0 then
                pickUpSpeedThreshold = parsedValue
            else
                pickUpSpeedThreshold = tonumber(value) or 100
            end
        end
    })
    if configForSettings then
        pcall(function()
            configForSettings:Register("autoPickUpSpeedThreshold", autoPickUpSpeedSliderRef)
        end)
    end
    
    autoPickUpToggleRef = Tabs.PlaceTab:Toggle({
        Title = "Auto Pick Up",
        Desc = "Automatically pick up slow pets",
        Value = false,
        Callback = function(state)
            autoPickUpEnabled = state
            
            if state and not autoPickUpThread then
                autoPickUpThread = task.spawn(function()
                    runAutoPickUp()
                    autoPickUpThread = nil
                end)
                WindUI:Notify({ Title = "Auto Pick Up", Content = "Started picking up slow pets", Duration = 2 })
            elseif not state and autoPickUpThread then
                WindUI:Notify({ Title = "Auto Pick Up", Content = "Stopped", Duration = 2 })
            end
        end
    })
    if configForSettings then
        pcall(function()
            configForSettings:Register("autoPickUpEnabled", autoPickUpToggleRef)
        end)
    end

    -- Stats update function (moved earlier in CreateUI)

    -- Main auto place toggle (keep the new one only)
    local autoPlaceToggle = AutoPlaceSystem.Toggle -- will be set earlier
    if not autoPlaceToggle then
        autoPlaceToggle = Tabs.PlaceTab:Toggle({
            Title = "Auto Place",
            Desc = "Automatically place pets/eggs",
            Value = false,
            Callback = function(state)
                autoPlaceEnabled = state
                
                if state and not autoPlaceThread then
                    autoPlaceThread = task.spawn(function()
                        runAutoPlace()
                        autoPlaceThread = nil
                    end)
                    
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
        AutoPlaceSystem.Toggle = autoPlaceToggle
    end
    
    -- Store references for external access
    AutoPlaceSystem.EggDropdown = placeEggDropdown
    AutoPlaceSystem.MutationDropdown = placeMutationDropdown
    AutoPlaceSystem.MinSpeedSlider = minSpeedSliderRef
    AutoPlaceSystem.SortOrderDropdown = sortOrderDropdownRef
    AutoPlaceSystem.PlaceModeDropdown = placeModeDropdownRef
    AutoPlaceSystem.AutoUnlockToggle = autoUnlockToggleRef
    AutoPlaceSystem.AutoPickUpToggle = autoPickUpToggleRef
    AutoPlaceSystem.AutoPickUpTileDropdown = autoPickUpTileDropdownRef
    AutoPlaceSystem.AutoPickUpSpeedSlider = autoPickUpSpeedSliderRef
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

-- Get config elements for external registration
function AutoPlaceSystem.GetConfigElements()
    return {
        autoPlaceToggle = AutoPlaceSystem.Toggle,
        eggDropdown = AutoPlaceSystem.EggDropdown,
        mutationDropdown = AutoPlaceSystem.MutationDropdown,
        minSpeedSlider = AutoPlaceSystem.MinSpeedSlider,
        sortOrderDropdown = AutoPlaceSystem.SortOrderDropdown,
        placeModeDropdown = AutoPlaceSystem.PlaceModeDropdown,
        autoUnlockToggle = AutoPlaceSystem.AutoUnlockToggle,
        autoPickUpToggle = AutoPlaceSystem.AutoPickUpToggle,
        autoPickUpTileDropdown = AutoPlaceSystem.AutoPickUpTileDropdown,
        autoPickUpSpeedSlider = AutoPlaceSystem.AutoPickUpSpeedSlider,
    }
end

return AutoPlaceSystem
