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
            if petType and not isPetAlreadyPlacedByUid(child.Name) and not petBlacklist[child.Name] then
                if (not isBigPet(petType)) then
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
    end
    
    -- Sort pets for sequential placement
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
    
    petCache.lastUpdate = currentTime
    petCache.candidates = out
    -- Reset index when pet list changes
    petCache.currentIndex = 1
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
    
    -- Process tiles in smaller batches with yields to prevent lag
    local batchSize = 15
    local processed = 0
    
    for _, part in ipairs(regularParts) do
        if not isTileOccupied(part) then
            regularAvailable = regularAvailable + 1
            table.insert(availableRegularTiles, part)
        end
        processed = processed + 1
        if processed >= batchSize then
            processed = 0
            task.wait() -- Yield to prevent lag
        end
    end
    
    processed = 0
    for _, part in ipairs(waterParts) do
        if not isTileOccupied(part) then
            waterAvailable = waterAvailable + 1
            table.insert(availableWaterTiles, part)
        end
        processed = processed + 1
        if processed >= batchSize then
            processed = 0
            task.wait() -- Yield to prevent lag
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
    
    -- Verify placement robustly:
    -- Success if egg UID disappears from Data.Egg OR tile becomes occupied.
    local dataRoot = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Data")
    local eggFolder = dataRoot and dataRoot:FindFirstChild("Egg")
    local deadline = os.clock() + 2.0
    repeat
        -- Egg removed from inventory → placed
        if eggFolder and not eggFolder:FindFirstChild(eggUID) then
            return true
        end
        -- Tile occupied
        if isTileOccupied(farmPart) then
            return true
        end
        task.wait(0.05)
    until os.clock() > deadline
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
        -- Speed too low! Auto-pick up this pet
        WindUI:Notify({
            Title = "🔄 Auto Pick Up",
            Content = "Pet speed " .. actualSpeed .. " < " .. (minPetRateFilter or 0) .. ". Picking up pet " .. petUID,
            Duration = 3
        })
        
        -- Add to blacklist first
        petBlacklist[petUID] = true
        
        -- Try to delete the pet using the same method as auto-pick up system
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
                Title = "🔄 Auto Pick Up", 
                Content = "✅ Picked up pet " .. petUID .. " (speed too low)", 
                Duration = 2
            })
            return false -- Pet was picked up
        else
            WindUI:Notify({
                Title = "🔄 Auto Pick Up", 
                Content = "❌ Failed to pick up pet " .. petUID, 
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
        -- Water farms available, use ocean eggs
        return oceanEggs[1], getRandomFromList(tileCache.waterTiles), "water"
    elseif regularAvailable > 0 and #oceanEggs > 0 then
        -- Do NOT fallback ocean eggs to regular tiles
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
    
    -- Early exit if no tiles available at all
    if regularAvailable == 0 and waterAvailable == 0 then
        return nil, nil, "no_tiles_available"
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
                -- Pick only if there are tiles AVAILABLE for this type
                if currentCandidate.isOcean then
                    -- Ocean pets: water tiles only
                    if waterAvailable > 0 then
                        selectedCandidate = currentCandidate
                        found = true
                        break
                    end
                else
                    -- Regular pets: regular tiles only
                    if regularAvailable > 0 then
                        selectedCandidate = currentCandidate
                        found = true
                        break
                    end
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
        -- New behavior: if top candidates are ocean but no water, try best regular instead (and vice versa)
        if waterAvailable == 0 and regularAvailable > 0 then
            -- Scan for highest-priority regular candidate
            local best = nil
            for _, cand in ipairs(candidates) do
                if not cand.isOcean and not isPetAlreadyPlacedByUid(cand.uid) then
                    best = cand
                    break
                end
            end
            if best then
                return best, getRandomFromList(tileCache.regularTiles), "regular"
            end
        elseif regularAvailable == 0 and waterAvailable > 0 then
            -- Scan for highest-priority ocean candidate
            local best = nil
            for _, cand in ipairs(candidates) do
                if cand.isOcean and not isPetAlreadyPlacedByUid(cand.uid) then
                    best = cand
                    break
                end
            end
            if best then
                return best, getRandomFromList(tileCache.waterTiles), "water"
            end
        end

        -- If still none, return detailed reason
        local hasOcean = false
        local hasRegular = false
        for _, cand in ipairs(candidates) do
            if not isPetAlreadyPlacedByUid(cand.uid) then
                if cand.isOcean then hasOcean = true end
                if not cand.isOcean then hasRegular = true end
            end
        end
        if hasOcean and not hasRegular and waterAvailable == 0 then
            return nil, nil, "ocean_pets_no_tiles"
        elseif hasRegular and not hasOcean and regularAvailable == 0 then
            return nil, nil, "regular_pets_no_regular_tiles"
        elseif (hasOcean and waterAvailable == 0) and (hasRegular and regularAvailable == 0) then
            return nil, nil, "no_tiles_available"
        else
            return nil, nil, "no_suitable_pets"
        end
    end
    
    -- Advance index for next placement
    petCache.currentIndex = petCache.currentIndex + 1
    if petCache.currentIndex > #candidates then
        petCache.currentIndex = 1 -- Wrap around
    end
    
    -- Return selected pet and appropriate tile with smart tile selection
    if selectedCandidate.isOcean then
        -- Ocean pets: place on water only; if water full, DO NOT place
        if waterAvailable > 0 then
            return selectedCandidate, getRandomFromList(tileCache.waterTiles), "water"
        else
            return nil, nil, "ocean_pet_no_tiles"
        end
    else
        -- Regular pets: place on regular only; if full, DO NOT place
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

local function runAutoPlace()
    local consecutiveFailures = 0
    local maxFailures = 3
    
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
                
                -- Longer wait after success to reduce lag
                waitJitter(2.0)
            else
                consecutiveFailures = consecutiveFailures + 1
                
                -- Determine if we should enter dormant mode
                local shouldGoDormant = false
                local dormantReason = ""
                
                if message:find("no_tiles_available") or message:find("No tiles available") then
                    shouldGoDormant = true
                    dormantReason = "No tiles available"
                elseif message:find("ocean_pets_no_tiles") or message:find("Ocean pets need") then
                    shouldGoDormant = true
                    dormantReason = "Ocean pets need water/regular tiles"
                elseif message:find("regular_pets_no_regular_tiles") or message:find("Regular pets need") then
                    shouldGoDormant = true
                    dormantReason = "Regular pets need regular tiles"
                elseif message:find("mixed_pets_insufficient_tiles") or message:find("Not enough tiles") then
                    shouldGoDormant = true
                    dormantReason = "Insufficient tiles for pet mix"
                elseif message:find("ocean_pet_no_tiles") or message:find("Ocean pet: no") then
                    shouldGoDormant = true
                    dormantReason = "No tiles for ocean pets"
                elseif message:find("regular_pet_no_regular_tiles") or message:find("Regular pet: no") then
                    shouldGoDormant = true
                    dormantReason = "No regular tiles for regular pets"
                elseif message:find("no_pets") or message:find("No pets pass filters") then
                    shouldGoDormant = true
                    dormantReason = "No pets pass filters"
                elseif consecutiveFailures >= maxFailures then
                    shouldGoDormant = true
                    dormantReason = "Too many consecutive failures"
                    consecutiveFailures = 0
                end
                
                if shouldGoDormant then
                    enterDormantMode(dormantReason)
                else
                    -- Normal retry delays for temporary issues
                    if message:find("already placed") then
                        waitJitter(0.3)
                    elseif message:find("disabled") then
                        waitJitter(5)
                    else
                        waitJitter(2)
                    end
                end
            end
        else
            -- Dormant mode - just wait and check periodically
            waitJitter(5)
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
    -- Sync Min Speed value
    if AutoPlaceSystem.MinSpeedSlider and AutoPlaceSystem.MinSpeedSlider.Value then
        local sliderValue = AutoPlaceSystem.MinSpeedSlider.Value
        if type(sliderValue) == "table" and sliderValue.Default then
            minPetRateFilter = tonumber(sliderValue.Default) or 0
        else
            minPetRateFilter = tonumber(sliderValue) or 0
        end
        print("[AutoPlace] Synced Min Speed:", minPetRateFilter)
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

    minSpeedSliderRef = Tabs.PlaceTab:Slider({
        Title = "Min Speed",
        Desc = "Min pet value",
        Value = {
            Min = 0,
            Max = 50000,
            Default = 0,
        },
        Callback = function(val)
            minPetRateFilter = tonumber(val) or 0
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
