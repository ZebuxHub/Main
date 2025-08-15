-- PetPlacementFunctions.lua - Pet Placement Helper Functions
-- Author: Zebux
-- Version: 1.0

local PetPlacementFunctions = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local vector = { create = function(x, y, z) return Vector3.new(x, y, z) end }

-- Helper function to get assigned island name
local function getAssignedIslandName()
    if not LocalPlayer then return nil end
    return LocalPlayer:GetAttribute("AssignedIslandName")
end

-- Helper function to get island number from name
function PetPlacementFunctions.getIslandNumberFromName(islandName)
    if not islandName then return nil end
    -- Extract number from island name (e.g., "Island_3" -> 3)
    local match = string.match(islandName, "Island_(%d+)")
    if match then
        return tonumber(match)
    end
    -- Try other patterns
    match = string.match(islandName, "(%d+)")
    if match then
        return tonumber(match)
    end
    return nil
end

-- Get all conveyor belts for an island
function PetPlacementFunctions.getIslandBelts(islandName)
    if type(islandName) ~= "string" or islandName == "" then return {} end
    local art = workspace:FindFirstChild("Art")
    if not art then return {} end
    local island = art:FindFirstChild(islandName)
    if not island then return {} end
    local env = island:FindFirstChild("ENV")
    if not env then return {} end
    local conveyorRoot = env:FindFirstChild("Conveyor")
    if not conveyorRoot then return {} end
    local belts = {}
    -- Strictly look for Conveyor1..Conveyor9 in order
    for i = 1, 9 do
        local c = conveyorRoot:FindFirstChild("Conveyor" .. i)
        if c then
            local b = c:FindFirstChild("Belt")
            if b then table.insert(belts, b) end
        end
    end
    return belts
end

-- Pick one "active" belt (with most eggs; tie -> nearest to player)
function PetPlacementFunctions.getActiveBelt(islandName)
    local belts = PetPlacementFunctions.getIslandBelts(islandName)
    if #belts == 0 then return nil end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local hrpPos = hrp and hrp.Position or Vector3.new()
    local bestBelt, bestScore, bestDist
    for _, belt in ipairs(belts) do
        local children = belt:GetChildren()
        local eggs = 0
        local samplePos
        for _, ch in ipairs(children) do
            if ch:IsA("Model") then
                eggs += 1
                if not samplePos then
                    local ok, cf = pcall(function() return ch:GetPivot() end)
                    if ok and cf then samplePos = cf.Position end
                end
            end
        end
        if not samplePos then
            local p = belt.Parent and belt.Parent:FindFirstChildWhichIsA("BasePart", true)
            samplePos = p and p.Position or hrpPos
        end
        local dist = (samplePos - hrpPos).Magnitude
        -- Higher eggs preferred; for tie, closer belt preferred
        local score = eggs * 100000 - dist
        if not bestScore or score > bestScore then
            bestScore, bestDist, bestBelt = score, dist, belt
        end
    end
    return bestBelt
end

-- Get all farm parts for an island
function PetPlacementFunctions.getFarmParts(islandNumber)
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
    local locksFolder = island:FindFirstChild("ENV"):FindFirstChild("Locks")
    
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
                -- Use CFrame and size to determine if the farm part is covered by the lock
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

-- Occupancy helpers (uses Model:GetPivot to detect nearby placed pets)
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

local function getTileCenterPosition(farmPart)
    if not farmPart or not farmPart.IsA or not farmPart:IsA("BasePart") then return nil end
    -- Middle of the farm tile (parts are 8x8x8)
    return farmPart.Position
end

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

-- Get all pet configurations that the player owns
function PetPlacementFunctions.getPlayerPetConfigurations()
    local petConfigs = {}
    
    if not LocalPlayer then return petConfigs end
    
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return petConfigs end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return petConfigs end
    
    local petsFolder = data:FindFirstChild("Pets")
    if not petsFolder then return petConfigs end
    
    -- Get all pet configurations
    for _, petConfig in ipairs(petsFolder:GetChildren()) do
        if petConfig:IsA("Configuration") then
            table.insert(petConfigs, {
                name = petConfig.Name,
                config = petConfig
            })
        end
    end
    
    return petConfigs
end

-- Check if a pet exists in workspace.Pets by configuration name
function PetPlacementFunctions.findPetInWorkspace(petConfigName)
    local workspacePets = workspace:FindFirstChild("Pets")
    if not workspacePets then return nil end
    
    local petModel = workspacePets:FindFirstChild(petConfigName)
    if petModel and petModel:IsA("Model") then
        return petModel
    end
    
    return nil
end

-- Get all player's pets that exist in workspace
function PetPlacementFunctions.getPlayerPetsInWorkspace()
    local petsInWorkspace = {}
    local playerPets = PetPlacementFunctions.getPlayerPetConfigurations()
    local workspacePets = workspace:FindFirstChild("Pets")
    
    if not workspacePets then return petsInWorkspace end
    
    for _, petConfig in ipairs(playerPets) do
        local petModel = workspacePets:FindFirstChild(petConfig.name)
        if petModel and petModel:IsA("Model") then
            table.insert(petsInWorkspace, {
                name = petConfig.name,
                model = petModel,
                position = petModel:GetPivot().Position
            })
        end
    end
    
    return petsInWorkspace
end

-- Check if a farm tile is occupied
function PetPlacementFunctions.isFarmTileOccupied(farmPart, minDistance)
    minDistance = minDistance or 6
    local center = getTileCenterPosition(farmPart)
    if not center then return true end
    
    -- Calculate surface position (same as placement logic)
    local surfacePosition = Vector3.new(
        center.X,
        center.Y + 12, -- Eggs float 12 studs above tile surface
        center.Z
    )
    
    -- Check for pets in PlayerBuiltBlocks (eggs/hatching pets)
    local models = getPetModelsOverlappingTile(farmPart)
    if #models > 0 then
        for _, model in ipairs(models) do
            local pivotPos = model:GetPivot().Position
            -- Check distance to surface position instead of center
            if (pivotPos - surfacePosition).Magnitude <= minDistance then
                return true
            end
        end
    end
    
    -- Check for fully hatched pets in workspace.Pets
    local playerPets = PetPlacementFunctions.getPlayerPetsInWorkspace()
    for _, petInfo in ipairs(playerPets) do
        local petPos = petInfo.position
        -- Check distance to surface position instead of center
        if (petPos - surfacePosition).Magnitude <= minDistance then
            return true
        end
    end
    
    return false
end

-- Find an available farm part
function PetPlacementFunctions.findAvailableFarmPart(farmParts, minDistance)
    if not farmParts or #farmParts == 0 then return nil end
    
    -- First, collect all available parts
    local availableParts = {}
    for _, part in ipairs(farmParts) do
        if not PetPlacementFunctions.isFarmTileOccupied(part, minDistance) then
            table.insert(availableParts, part)
        end
    end
    
    -- If no available parts, return nil
    if #availableParts == 0 then return nil end
    
    -- Shuffle available parts to distribute placement
    for i = #availableParts, 2, -1 do
        local j = math.random(1, i)
        availableParts[i], availableParts[j] = availableParts[j], availableParts[i]
    end
    
    return availableParts[1]
end

-- Player helpers for proximity-based placement
function PetPlacementFunctions.getPlayerRootPosition()
    local character = LocalPlayer and LocalPlayer.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    return hrp.Position
end

function PetPlacementFunctions.findAvailableFarmPartNearPosition(farmParts, minDistance, targetPosition)
    if not targetPosition then return PetPlacementFunctions.findAvailableFarmPart(farmParts, minDistance) end
    if not farmParts or #farmParts == 0 then return nil end
    -- Sort farm parts by distance to targetPosition and pick first unoccupied
    local sorted = table.clone(farmParts)
    table.sort(sorted, function(a, b)
        return (a.Position - targetPosition).Magnitude < (b.Position - targetPosition).Magnitude
    end)
    for _, part in ipairs(sorted) do
        if not PetPlacementFunctions.isFarmTileOccupied(part, minDistance) then
            return part
        end
    end
    return nil
end

-- Enhanced pet validation based on the Pet module
function PetPlacementFunctions.validatePetUID(petUID)
    if not petUID or type(petUID) ~= "string" or petUID == "" then
        return false, "Invalid PET UID"
    end
    
    -- Check if pet exists in ReplicatedStorage.Pets (based on Pet module patterns)
    local petsFolder = ReplicatedStorage:FindFirstChild("Pets")
    if petsFolder then
        -- The Pet module shows pets are stored by their type (T attribute)
        -- We might need to validate the pet type exists
        return true, "Valid PET UID"
    end
    
    return true, "PET UID found (pets folder not accessible)"
end

-- Get pet information for better status display
function PetPlacementFunctions.getPetInfo(petUID)
    if not petUID then return nil end
    
    -- Try to get pet data from various sources
    local petData = {
        UID = petUID,
        Type = nil,
        Rarity = nil,
        Level = nil,
        Mutations = nil
    }
    
    -- Check if we can get pet type from the UID
    -- This might be stored in the player's data or we might need to parse it
    if type(petUID) == "string" then
        -- Some games store pet type in the UID itself
        petData.Type = petUID
    end
    
    return petData
end

-- Main pet placement function
function PetPlacementFunctions.placePetAtPart(farmPart, petUID)
    if not farmPart or not petUID then return false end
    
    -- Enhanced validation based on Pet module insights
    if not farmPart:IsA("BasePart") then return false end
    
    local isValid, validationMsg = PetPlacementFunctions.validatePetUID(petUID)
    if not isValid then
        warn("Pet validation failed: " .. validationMsg)
        return false
    end
    
    -- Place pet on surface (top of the farm split tile)
    local surfacePosition = Vector3.new(
        farmPart.Position.X,
        farmPart.Position.Y + (farmPart.Size.Y / 2), -- Top surface
        farmPart.Position.Z
    )
    
    local args = {
        "Place",
        {
            DST = vector.create(surfacePosition.X, surfacePosition.Y, surfacePosition.Z),
            ID = petUID
        }
    }
    
    local ok, err = pcall(function()
        local remote = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE")
        if remote then
            remote:FireServer(unpack(args))
        else
            error("CharacterRE remote not found")
        end
    end)
    
    if not ok then
        warn("Failed to fire Place for PET UID " .. tostring(petUID) .. " at " .. tostring(surfacePosition) .. ": " .. tostring(err))
        return false
    end
    
    return true
end

-- Helper function to check if a specific tile position is unlocked
function PetPlacementFunctions.isTileUnlocked(islandName, tilePosition)
    if not islandName or not tilePosition then return false end
    
    local art = workspace:FindFirstChild("Art")
    if not art then return true end -- Assume unlocked if no Art folder
    
    local island = art:FindFirstChild(islandName)
    if not island then return true end -- Assume unlocked if island not found
    
    local locksFolder = island:FindFirstChild("ENV"):FindFirstChild("Locks")
    if not locksFolder then return true end -- Assume unlocked if no locks folder
    
    -- Check if there's a lock covering this position
    for _, lockModel in ipairs(locksFolder:GetChildren()) do
        if lockModel:IsA("Model") then
            local farmPart = lockModel:FindFirstChild("Farm")
            if farmPart and farmPart:IsA("BasePart") and farmPart.Transparency == 0 then
                -- Check if tile position is within the lock area
                local lockCenter = farmPart.Position
                local lockSize = farmPart.Size
                
                -- Calculate the bounds of the lock area
                local lockHalfSize = lockSize / 2
                local lockMinX = lockCenter.X - lockHalfSize.X
                local lockMaxX = lockCenter.X + lockHalfSize.X
                local lockMinZ = lockCenter.Z - lockHalfSize.Z
                local lockMaxZ = lockCenter.Z + lockHalfSize.Z
                
                -- Check if tile position is within the lock bounds
                if tilePosition.X >= lockMinX and tilePosition.X <= lockMaxX and
                   tilePosition.Z >= lockMinZ and tilePosition.Z <= lockMaxZ then
                    return false -- This tile is locked
                end
            end
        end
    end
    
    return true -- Tile is unlocked
end

return PetPlacementFunctions
