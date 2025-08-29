-- Auto Place System.lua
-- Build A Zoo: Auto Placement System
-- Author: Zebux
-- Version: 1.0

local AutoPlaceSystem = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

-- Module variables (will be initialized by main script)
local WindUI = nil
local Config = nil

-- Auto Place state variables
local autoPlaceEnabled = false
local availableEggs = {}
local availableTiles = {}
local placeConnections = {}
local placingInProgress = false

-- Ocean egg categories for water farm placement
local OCEAN_EGGS = {
    ["SeaweedEgg"] = true,
    ["ClownfishEgg"] = true,
    ["LionfishEgg"] = true,
    ["SharkEgg"] = true,
    ["AnglerfishEgg"] = true,
    ["OctopusEgg"] = true,
    ["SeaDragonEgg"] = true
}

-- Check if an egg type requires water farm placement
local function isOceanEgg(eggType)
    return OCEAN_EGGS[eggType] == true
end

-- Helper function to get assigned island name
local function getAssignedIslandName()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return nil end
    
    local island = data:FindFirstChild("Island")
    if not island then return nil end
    
    return island.Value
end

-- Helper function to extract island number from island name
local function getIslandNumberFromName(islandName)
    if not islandName or islandName == "" then return nil end
    
    -- Extract number from island name (e.g., "Island_1" -> 1)
    local number = string.match(islandName, "%d+")
    return tonumber(number)
end

-- Get locked tiles for auto unlock system
local function getLockedTiles(islandNumber)
    if not islandNumber then return {} end
    local art = workspace:FindFirstChild("Art")
    if not art then return {} end
    
    local islandName = "Island_" .. tostring(islandNumber)
    local island = art:FindFirstChild(islandName)
    if not island then return {} end
    
    local env = island:FindFirstChild("ENV")
    if not env then return {} end
    
    local locksFolder = env:FindFirstChild("Locks")
    if not locksFolder then return {} end
    
    local lockedTiles = {}
    
    -- Scan for locks that start with 'F' (like F20, F30, etc.)
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
    
    if not success then
        warn("❌ Failed to unlock tile " .. (lockInfo.modelName or "unknown") .. ": " .. tostring(errorMsg))
    end
    
    return success
end

-- Function to auto unlock tiles when needed
local function autoUnlockTilesIfNeeded(islandNumber, eggType)
    -- Input validation
    if not islandNumber then 
        warn("autoUnlockTilesIfNeeded: No island number provided")
        return false 
    end
    if not eggType then 
        warn("autoUnlockTilesIfNeeded: No egg type provided")
        return false 
    end
    
    -- Check if we have available tiles first
    local farmParts
    local isOceanEggType = false
    
    -- Safe check for ocean egg type
    local success, result = pcall(function()
        return isOceanEgg(eggType)
    end)
    
    if success then
        isOceanEggType = result
    else
        warn("autoUnlockTilesIfNeeded: Error checking ocean egg type: " .. tostring(result))
        isOceanEggType = false
    end
    
    -- Get farm parts safely
    local farmPartsSuccess, farmPartsResult = pcall(function()
        if isOceanEggType then
            return AutoPlaceSystem.getWaterFarmParts(islandNumber)
        else
            return AutoPlaceSystem.getFarmParts(islandNumber)
        end
    end)
    
    if farmPartsSuccess then
        farmParts = farmPartsResult or {}
    else
        warn("autoUnlockTilesIfNeeded: Error getting farm parts: " .. tostring(farmPartsResult))
        return false
    end
    
    -- Count available (unlocked and unoccupied) tiles
    local availableCount = 0
    for _, part in ipairs(farmParts) do
        local isOccupied = false
        local checkSuccess, checkResult = pcall(function()
            return AutoPlaceSystem.isFarmTileOccupied(part, 6)
        end)
        
        if checkSuccess then
            isOccupied = checkResult
        else
            warn("autoUnlockTilesIfNeeded: Error checking tile occupation: " .. tostring(checkResult))
            isOccupied = true -- Assume occupied if we can't check
        end
        
        if not isOccupied then
            availableCount = availableCount + 1
        end
    end
    
    -- If we have less than 3 available tiles, try to unlock more
    if availableCount < 3 then
        local lockedTiles = {}
        local lockedTilesSuccess, lockedTilesResult = pcall(function()
            return getLockedTiles(islandNumber)
        end)
        
        if lockedTilesSuccess then
            lockedTiles = lockedTilesResult or {}
        else
            warn("autoUnlockTilesIfNeeded: Error getting locked tiles: " .. tostring(lockedTilesResult))
            return false
        end
        
        if #lockedTiles > 0 then
            -- Sort by cost (cheapest first) with error handling
            local sortSuccess, sortError = pcall(function()
                table.sort(lockedTiles, function(a, b)
                    return (a.cost or 0) < (b.cost or 0)
                end)
            end)
            
            if not sortSuccess then
                warn("autoUnlockTilesIfNeeded: Error sorting locked tiles: " .. tostring(sortError))
            end
            
            -- Try to unlock the cheapest tiles
            local unlockedCount = 0
            for _, lockInfo in ipairs(lockedTiles) do
                if unlockedCount >= 2 then break end -- Don't unlock too many at once
                
                local unlockSuccess, unlockError = pcall(function()
                    return unlockTile(lockInfo)
                end)
                
                if unlockSuccess and unlockError then
                    unlockedCount = unlockedCount + 1
                    task.wait(0.5) -- Wait between unlocks
                elseif not unlockSuccess then
                    warn("autoUnlockTilesIfNeeded: Error unlocking tile: " .. tostring(unlockError))
                end
            end
            
            if unlockedCount > 0 then
                task.wait(1) -- Wait for server to process unlocks
                return true
            end
        end
    end
    
    return false
end

-- Get water farm parts for ocean eggs
function AutoPlaceSystem.getWaterFarmParts(islandNumber)
    if not islandNumber then return {} end
    local art = workspace:FindFirstChild("Art")
    if not art then return {} end
    
    local islandName = "Island_" .. tostring(islandNumber)
    local island = art:FindFirstChild(islandName)
    if not island then 
        -- Try alternative naming patterns
        for _, child in ipairs(art:GetChildren()) do
            if child.Name:match("^Island[_-]?" .. tostring(islandNumber) .. "$") then
                island = child
                break
            end
        end
        if not island then return {} end
    end
    
    local waterFarmParts = {}
    local function scanForWaterFarmParts(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("BasePart") and child.Name == "WaterFarm_split_0_0_0" then
                -- Additional validation: check if part is valid for placement
                if child.Size == Vector3.new(8, 8, 8) and child.CanCollide then
                    table.insert(waterFarmParts, child)
                end
            end
            scanForWaterFarmParts(child)
        end
    end
    
    scanForWaterFarmParts(island)
    
    print("🌊 Found", #waterFarmParts, "total water farm parts")
    
    -- Filter out locked water farm tiles by checking the Locks folder
    local unlockedWaterFarmParts = {}
    local env = island:FindFirstChild("ENV")
    local locksFolder = env and env:FindFirstChild("Locks")
    
    if locksFolder then
        print("🌊 Checking locks folder with", #locksFolder:GetChildren(), "lock models")
        -- Create a map of locked areas using position checking
        local lockedAreas = {}
        for _, lockModel in ipairs(locksFolder:GetChildren()) do
            if lockModel:IsA("Model") and lockModel.Name:match("^F%d+") then
                local farmPart = lockModel:FindFirstChild("Farm")
                if farmPart and farmPart:IsA("BasePart") then
                    -- Check if this lock is active (transparency = 0 means locked)
                    if farmPart.Transparency == 0 then
                        print("🌊 Active lock found:", lockModel.Name, "at", farmPart.Position)
                        -- Store the lock's position and size for area checking
                        table.insert(lockedAreas, {
                            position = farmPart.Position,
                            size = farmPart.Size
                        })
                    else
                        print("🌊 Inactive lock (unlocked):", lockModel.Name)
                    end
                end
            end
        end
        
        print("🌊 Found", #lockedAreas, "active locked areas")
        
        -- Check each water farm part against locked areas
        for i, waterFarmPart in ipairs(waterFarmParts) do
            local isLocked = false
            
            for _, lockArea in ipairs(lockedAreas) do
                -- Check if water farm part is within the lock area
                local waterFarmPos = waterFarmPart.Position
                local lockCenter = lockArea.position
                local lockSize = lockArea.size
                
                -- Calculate the bounds of the lock area
                local lockHalfSize = lockSize / 2
                local lockMinX = lockCenter.X - lockHalfSize.X
                local lockMaxX = lockCenter.X + lockHalfSize.X
                local lockMinZ = lockCenter.Z - lockHalfSize.Z
                local lockMaxZ = lockCenter.Z + lockHalfSize.Z
                
                -- Check if water farm part is within the lock bounds
                if waterFarmPos.X >= lockMinX and waterFarmPos.X <= lockMaxX and
                   waterFarmPos.Z >= lockMinZ and waterFarmPos.Z <= lockMaxZ then
                    isLocked = true
                    print("🌊 Water farm", i, "is locked by area at", lockCenter)
                    break
                end
            end
            
            if not isLocked then
                table.insert(unlockedWaterFarmParts, waterFarmPart)
                print("🌊 Water farm", i, "is unlocked and available")
            end
        end
        
        print("🌊 Final result:", #unlockedWaterFarmParts, "unlocked water farm parts out of", #waterFarmParts, "total")
    else
        -- If no locks folder found, assume all water farm tiles are unlocked
        unlockedWaterFarmParts = waterFarmParts
    end
    
    return unlockedWaterFarmParts
end

-- Get regular farm parts
function AutoPlaceSystem.getFarmParts(islandNumber)
    if not islandNumber then return {} end
    local art = workspace:FindFirstChild("Art")
    if not art then return {} end
    
    local islandName = "Island_" .. tostring(islandNumber)
    local island = art:FindFirstChild(islandName)
    if not island then 
        -- Try alternative naming patterns
        for _, child in ipairs(art:GetChildren()) do
            if child.Name:match("^Island[_-]?" .. tostring(islandNumber) .. "$") then
                island = child
                break
            end
        end
        if not island then return {} end
    end
    
    local farmParts = {}
    local function scanForFarmParts(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("BasePart") and child.Name:match("^Farm_split_%d+_%d+_%d+$") then
                -- Additional validation: check if part is valid for placement
                if child.Size == Vector3.new(8, 8, 8) and child.CanCollide then
                    table.insert(farmParts, child)
                end
            end
            scanForFarmParts(child)
        end
    end
    
    scanForFarmParts(island)
    
    -- Filter out locked tiles by checking the Locks folder
    local unlockedFarmParts = {}
    local env = island:FindFirstChild("ENV")
    local locksFolder = env and env:FindFirstChild("Locks")
    
    if locksFolder then
        -- Create a map of locked areas using CFrame and size
        local lockedAreas = {}
        for _, lockModel in ipairs(locksFolder:GetChildren()) do
            if lockModel:IsA("Model") then
                local farmPart = lockModel:FindFirstChild("Farm")
                if farmPart and farmPart:IsA("BasePart") then
                    -- Check if this lock is active (transparency = 0 means locked)
                    if farmPart.Transparency == 0 then
                        -- Store the lock's CFrame and size for area checking
                        table.insert(lockedAreas, {
                            cframe = farmPart.CFrame,
                            size = farmPart.Size,
                            position = farmPart.Position
                        })
                    end
                end
            end
        end
        
        -- Check each farm part against locked areas
        for _, farmPart in ipairs(farmParts) do
            local isLocked = false
            
            for _, lockArea in ipairs(lockedAreas) do
                -- Check if farm part is within the lock area
                local farmPartPos = farmPart.Position
                local lockCenter = lockArea.position
                local lockSize = lockArea.size
                
                -- Calculate the bounds of the lock area
                local lockHalfSize = lockSize / 2
                local lockMinX = lockCenter.X - lockHalfSize.X
                local lockMaxX = lockCenter.X + lockHalfSize.X
                local lockMinZ = lockCenter.Z - lockHalfSize.Z
                local lockMaxZ = lockCenter.Z + lockHalfSize.Z
                
                -- Check if farm part is within the lock bounds
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
        -- If no locks folder found, assume all tiles are unlocked
        unlockedFarmParts = farmParts
    end
    
    return unlockedFarmParts
end

-- Helper functions for tile management
local function getTileCenterPosition(farmPart)
    if not farmPart or not farmPart.IsA or not farmPart:IsA("BasePart") then return nil end
    -- Middle of the farm tile (parts are 8x8x8)
    return farmPart.Position
end

-- Check if a model looks like a pet
local function isPetLikeModel(model)
    if not model or not model:IsA("Model") then return false end
    -- Common signals that a model is a pet or a placed unit
    if model:FindFirstChildOfClass("Humanoid") then return true end
    if model:FindFirstChild("AnimationController") then return true end
    if model:GetAttribute("IsPet") or model:GetAttribute("PetType") or model:GetAttribute("T") then return true end
    local lowerName = string.lower(model.Name)
    if string.find(lowerName, "pet") or string.find(lowerName, "egg") then return true end
    if CollectionService and (CollectionService:HasTag(model, "Pet") or CollectionService:HasTag(model, "IdleBigPet")) then
        return true
    end
    return false
end

-- Get pet models overlapping a tile
local function getPetModelsOverlappingTile(farmPart)
    if not farmPart or not farmPart:IsA("BasePart") then return {} end
    local centerCF = farmPart.CFrame
    -- Slightly taller box to capture pets above the tile
    local regionSize = Vector3.new(8, 14, 8)
    local params = OverlapParams.new()
    params.RespectCanCollide = false
    -- Search within whole workspace, we will filter to models
    local parts = workspace:GetPartBoundsInBox(centerCF, regionSize, params)
    local modelMap = {}
    for _, part in ipairs(parts) do
        if part ~= farmPart then
            local model = part:FindFirstAncestorOfClass("Model")
            if model and not modelMap[model] and isPetLikeModel(model) then
                modelMap[model] = true
            end
        end
    end
    local models = {}
    for model in pairs(modelMap) do table.insert(models, model) end
    return models
end

-- Get all player's pets that exist in workspace
local function getPlayerPetsInWorkspace()
    local petsInWorkspace = {}
    local workspacePets = workspace:FindFirstChild("Pets")
    
    if not workspacePets then return petsInWorkspace end
    
    -- Get player's pet configurations
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return petsInWorkspace end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return petsInWorkspace end
    
    local petsFolder = data:FindFirstChild("Pets")
    if not petsFolder then return petsInWorkspace end
    
    -- Get all pet configurations
    for _, petConfig in ipairs(petsFolder:GetChildren()) do
        if petConfig:IsA("Configuration") then
            local petModel = workspacePets:FindFirstChild(petConfig.Name)
            if petModel and petModel:IsA("Model") then
                table.insert(petsInWorkspace, {
                    name = petConfig.Name,
                    model = petModel,
                    position = petModel:GetPivot().Position
                })
            end
        end
    end
    
    return petsInWorkspace
end

-- Check if a farm tile is occupied by pets or eggs
function AutoPlaceSystem.isFarmTileOccupied(farmPart, minDistance)
    minDistance = minDistance or 6
    local center = getTileCenterPosition(farmPart)
    if not center then return true end
    
    -- Calculate surface position (same as placement logic)
    local surfacePosition = Vector3.new(
        center.X,
        center.Y + 12, -- Eggs float 12 studs above tile surface
        center.Z
    )
    
    -- Debug for water farm tiles
    local isWaterFarm = farmPart.Name == "WaterFarm_split_0_0_0"
    if isWaterFarm then
        print("📍 Checking water farm tile at", surfacePosition, "with", minDistance, "stud radius")
    end
    
    -- Check for pets in PlayerBuiltBlocks (eggs/hatching pets)
    local models = getPetModelsOverlappingTile(farmPart)
    if #models > 0 then
        if isWaterFarm then
            print("📍 Found", #models, "overlapping models in PlayerBuiltBlocks")
        end
        for i, model in ipairs(models) do
            local pivotPos = model:GetPivot().Position
            local distance = (pivotPos - surfacePosition).Magnitude
            -- Check distance to surface position instead of center
            if distance <= minDistance then
                if isWaterFarm then
                    print("📍 Water farm occupied by PlayerBuiltBlocks model", i, "at distance", distance)
                end
                return true
            end
        end
    end
    
    -- Check for fully hatched pets in workspace.Pets
    local playerPets = getPlayerPetsInWorkspace()
    if isWaterFarm and #playerPets > 0 then
        print("📍 Checking against", #playerPets, "pets in workspace")
    end
    for i, petInfo in ipairs(playerPets) do
        local petPos = petInfo.position
        local distance = (petPos - surfacePosition).Magnitude
        -- Check distance to surface position instead of center
        if distance <= minDistance then
            if isWaterFarm then
                print("📍 Water farm occupied by workspace pet", petInfo.name, "at distance", distance)
            end
            return true
        end
    end
    
    if isWaterFarm then
        print("📍 Water farm tile is available!")
    end
    
    return false
end

-- Get egg container
local function getEggContainer()
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = pg and pg:FindFirstChild("Data")
    return data and data:FindFirstChild("Egg") or nil
end

-- Function to read mutation from egg configuration
local function getEggMutation(eggUID)
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return nil end
    
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return nil end
    
    local eggContainer = data:FindFirstChild("Egg")
    if not eggContainer then return nil end
    
    local eggFolder = eggContainer:FindFirstChild(eggUID)
    if not eggFolder then return nil end
    
    local mutationValue = eggFolder:FindFirstChild("Mutation")
    if mutationValue and mutationValue:IsA("StringValue") then
        return mutationValue.Value
    end
    
    return nil
end

-- List available egg UIDs for auto placement
local function listAvailableEggUIDs()
    local eggs = {}
    local eggContainer = getEggContainer()
    if not eggContainer then return eggs end
    
    for _, child in ipairs(eggContainer:GetChildren()) do
        if child:IsA("Folder") and #child:GetChildren() == 0 then -- No subfolder = available egg
            local eggType = child:GetAttribute("T") or "Unknown"
            local mutation = getEggMutation(child.Name)
            
            table.insert(eggs, {
                uid = child.Name,
                type = eggType,
                mutation = mutation
            })
        end
    end
    
    return eggs
end

-- Update available eggs list
function AutoPlaceSystem.updateAvailableEggs(selectedEggTypes, selectedMutations)
    local eggs = listAvailableEggUIDs()
    availableEggs = {}
    
    selectedEggTypes = selectedEggTypes or {}
    selectedMutations = selectedMutations or {}
    
    -- Smart egg prioritization and filtering logic
    local islandName = getAssignedIslandName()
    local islandNumber = getIslandNumberFromName(islandName)
    
    -- Check available space for different farm types
    local regularFarmParts = AutoPlaceSystem.getFarmParts(islandNumber)
    local waterFarmParts = AutoPlaceSystem.getWaterFarmParts(islandNumber)
    
    local availableRegularTiles = 0
    local availableWaterTiles = 0
    
    -- Count available tiles
    for _, part in ipairs(regularFarmParts) do
        if not AutoPlaceSystem.isFarmTileOccupied(part, 6) then
            availableRegularTiles = availableRegularTiles + 1
        end
    end
    
    for _, part in ipairs(waterFarmParts) do
        if not AutoPlaceSystem.isFarmTileOccupied(part, 3) then
            availableWaterTiles = availableWaterTiles + 1
        end
    end
    
    -- Prioritize eggs based on available space
    local prioritizedEggs = {}
    local oceanEggs = {}
    local regularEggs = {}
    
    -- Separate eggs by type
    for _, eggInfo in ipairs(eggs) do
        if isOceanEgg(eggInfo.type) then
            table.insert(oceanEggs, eggInfo)
        else
            table.insert(regularEggs, eggInfo)
        end
    end
    
    -- Add regular eggs first, then ocean eggs
    if availableRegularTiles > 0 then
        for _, egg in ipairs(regularEggs) do
            table.insert(prioritizedEggs, egg)
        end
    end
    
    if availableWaterTiles > 0 then
        for _, egg in ipairs(oceanEggs) do
            table.insert(prioritizedEggs, egg)
        end
    end
    
    availableEggs = prioritizedEggs
    return #prioritizedEggs
end

-- Main placement attempt function
function AutoPlaceSystem.attemptPlacement()
    if #availableEggs == 0 then 
        warn("Auto Place stopped: No eggs available")
        return 
    end
    
    -- Try to find a placeable egg (skip ocean eggs if no water farms available)
    local eggToPlace = nil
    local eggIndex = nil
    
    print("🥚 Checking", #availableEggs, "eggs for placement...")
    
    for i, egg in ipairs(availableEggs) do
        local canPlace = true
        print("🥚 Checking egg", i, ":", egg.type, "(Ocean:", isOceanEgg(egg.type), ")")
        
        -- Check if this is an ocean egg and if we have water farms available
        if isOceanEgg(egg.type) then
            local islandName = getAssignedIslandName()
            local islandNumber = getIslandNumberFromName(islandName)
            local waterFarmParts = AutoPlaceSystem.getWaterFarmParts(islandNumber)
            
            print("🌊 getWaterFarmParts returned", #waterFarmParts, "parts for", egg.type)
            
            -- Count available water farm tiles (use smaller radius for water farms)
            local availableWaterTiles = 0
            for j, part in ipairs(waterFarmParts) do
                local isOccupied = AutoPlaceSystem.isFarmTileOccupied(part, 3) -- Reduced from 6 to 3 studs
                if not isOccupied then
                    availableWaterTiles = availableWaterTiles + 1
                    print("🌊 Water farm", j, "is available for", egg.type)
                else
                    print("🌊 Water farm", j, "is occupied")
                end
            end
            
            print("🥚 Ocean egg", egg.type, "- Water tiles available:", availableWaterTiles)
            
            -- If no water farm tiles available, skip this ocean egg
            if availableWaterTiles == 0 then
                canPlace = false
                print("🥚 ❌ Skipping ocean egg", egg.type, "- no water farms available")
            else
                print("🥚 ✅ Ocean egg", egg.type, "can be placed on", availableWaterTiles, "water farms")
            end
        else
            print("🥚 Normal egg", egg.type, "- should be placeable")
        end
        
        if canPlace then
            eggToPlace = egg
            eggIndex = i
            print("🥚 Selected egg for placement:", egg.type)
            break
        end
    end
    
    -- If no eggs can be placed (all are ocean eggs with no water farms), give up
    if not eggToPlace then
        warn("Auto Place stopped: No placeable eggs (ocean eggs need water farms)")
        return
    end
    
    -- Move the selected egg to the front of the list for processing
    if eggIndex > 1 then
        table.remove(availableEggs, eggIndex)
        table.insert(availableEggs, 1, eggToPlace)
    end
    
    return eggToPlace
end

-- Get available eggs list
function AutoPlaceSystem.getAvailableEggs()
    return availableEggs
end

-- Get available tiles list
function AutoPlaceSystem.getAvailableTiles()
    return availableTiles
end

-- Set auto place enabled state
function AutoPlaceSystem.setEnabled(enabled)
    autoPlaceEnabled = enabled
end

-- Get auto place enabled state
function AutoPlaceSystem.isEnabled()
    return autoPlaceEnabled
end

-- Cleanup function
function AutoPlaceSystem.cleanup()
    autoPlaceEnabled = false
    availableEggs = {}
    availableTiles = {}
    
    -- Cleanup connections
    for _, conn in ipairs(placeConnections) do
        pcall(function() conn:Disconnect() end)
    end
    placeConnections = {}
    
    print("🧹 Auto Place System cleaned up successfully!")
end

-- Initialization function
function AutoPlaceSystem.Init(dependencies)
    if not dependencies then
        warn("AutoPlaceSystem.Init: No dependencies provided")
        return false
    end
    
    WindUI = dependencies.WindUI
    Config = dependencies.Config
    
    if not WindUI then
        warn("AutoPlaceSystem.Init: WindUI is required")
        return false
    end
    
    print("🎯 Auto Place System initialized successfully!")
    return true
end

return AutoPlaceSystem
