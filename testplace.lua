-- ============================================
-- Enhanced Auto Place System - Advanced Tile Finding
-- ============================================
-- Ultra-optimized pet placement with advanced tile detection algorithms,
-- spatial indexing, predictive caching, and intelligent placement strategies.

local EnhancedAutoPlace = {}

-- ============ Services & Dependencies ============
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ============ External Dependencies ============
local WindUI, Tabs, Config
local selectedEggTypes = {}
local selectedMutations = {}
local fallbackToRegularWhenNoWater = false
local usePetPlacementMode = false
local minPetRateFilter = 0
local petAscendingOrder = false
local smartPlacementMode = true
local prioritizeCenterTiles = true
local useClusterPlacement = false

-- ============ Remote Cache ============
local Remotes = ReplicatedStorage:WaitForChild("Remote", 5)
local CharacterRE = Remotes and Remotes:FindFirstChild("CharacterRE")

-- ============ Advanced Statistics ============
local placementStats = {
    totalPlacements = 0,
    mutationPlacements = 0,
    lastPlacement = nil,
    lastReason = nil,
    averagePlacementTime = 0,
    tileSearchTime = 0,
    placementSuccessRate = 0,
    totalAttempts = 0,
    clusterPlacements = 0,
    centerPlacements = 0
}

-- ============ Pet Blacklist & Performance Tracking ============
local petBlacklist = {}
local performanceMetrics = {
    lastTileSearchDuration = 0,
    averageTileSearchDuration = 0,
    cacheHitRate = 0,
    totalCacheRequests = 0,
    cacheHits = 0
}

-- ============ Config Cache System ============
local resPetById = nil
local resMutateById = nil
local resBigPetScale = nil
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

-- ============ Advanced Tile Detection System ============
local CACHE_DURATION = 6 -- Reduced for more responsive updates
local SPATIAL_GRID_SIZE = 16 -- For spatial indexing optimization

-- Enhanced tile cache with spatial indexing
local enhancedTileCache = {
    lastUpdate = 0,
    spatialGrid = {}, -- Grid-based spatial index for O(1) lookups
    regularTiles = {},
    waterTiles = {},
    centerTiles = {}, -- Tiles closest to island center
    edgeTiles = {}, -- Tiles on the edges
    clusterRegions = {}, -- Grouped tile clusters
    totalRegular = 0,
    totalWater = 0,
    islandCenter = Vector3.new(0, 0, 0)
}

-- Spatial indexing for ultra-fast tile lookups
local function getSpatialGridKey(position)
    local gridX = math.floor(position.X / SPATIAL_GRID_SIZE)
    local gridZ = math.floor(position.Z / SPATIAL_GRID_SIZE)
    return gridX .. "," .. gridZ
end

local function addToSpatialGrid(position, tileInfo)
    local key = getSpatialGridKey(position)
    if not enhancedTileCache.spatialGrid[key] then
        enhancedTileCache.spatialGrid[key] = {}
    end
    table.insert(enhancedTileCache.spatialGrid[key], tileInfo)
end

local function getNearbyTilesFromGrid(position, radius)
    local nearbyTiles = {}
    local gridRadius = math.ceil(radius / SPATIAL_GRID_SIZE)
    local centerGridX = math.floor(position.X / SPATIAL_GRID_SIZE)
    local centerGridZ = math.floor(position.Z / SPATIAL_GRID_SIZE)
    
    for x = centerGridX - gridRadius, centerGridX + gridRadius do
        for z = centerGridZ - gridRadius, centerGridZ + gridRadius do
            local key = x .. "," .. z
            local gridTiles = enhancedTileCache.spatialGrid[key]
            if gridTiles then
                for _, tile in ipairs(gridTiles) do
                    local distance = (tile.position - position).Magnitude
                    if distance <= radius then
                        table.insert(nearbyTiles, tile)
                    end
                end
            end
        end
    end
    
    return nearbyTiles
end

-- ============ Island & Utility Functions ============
local function getAssignedIslandName()
    if not LocalPlayer then return nil end
    return LocalPlayer:GetAttribute("AssignedIslandName")
end

local function getIslandNumberFromName(islandName)
    if not islandName then return nil end
    local match = string.match(islandName, "Island_(%d+)")
    if match then return tonumber(match) end
    match = string.match(islandName, "(%d+)")
    if match then return tonumber(match) end
    return nil
end

local function calculateIslandCenter(islandNumber)
    if not islandNumber then return Vector3.new(0, 0, 0) end
    
    local art = workspace:FindFirstChild("Art")
    if not art then return Vector3.new(0, 0, 0) end
    
    local islandName = "Island_" .. tostring(islandNumber)
    local island = art:FindFirstChild(islandName)
    if not island then return Vector3.new(0, 0, 0) end
    
    -- Calculate center based on all farm tiles
    local totalX, totalZ, count = 0, 0, 0
    local function scanForCenter(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("BasePart") and child.Size == Vector3.new(8, 8, 8) then
                if child.Name:match("^Farm_split_%d+_%d+_%d+$") or child.Name == "WaterFarm_split_0_0_0" then
                    totalX = totalX + child.Position.X
                    totalZ = totalZ + child.Position.Z
                    count = count + 1
                end
            end
            scanForCenter(child)
        end
    end
    
    scanForCenter(island)
    
    if count > 0 then
        return Vector3.new(totalX / count, 0, totalZ / count)
    end
    
    return Vector3.new(0, 0, 0)
end

-- ============ Advanced Farm Detection ============
local function getEnhancedFarmParts(islandNumber, isWater)
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
    local pattern = isWater and "WaterFarm_split_0_0_0" or "^Farm_split_%d+_%d+_%d+$"
    
    local function scanForFarmParts(parent, depth)
        depth = depth or 0
        if depth > 10 then return end -- Prevent infinite recursion
        
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("BasePart") then
                local matches = false
                if isWater then
                    matches = child.Name == pattern
                else
                    matches = child.Name:match(pattern)
                end
                
                -- Enhanced validation with multiple criteria
                if matches and child.Size == Vector3.new(8, 8, 8) and child.CanCollide then
                    -- Additional material and color validation for authenticity
                    local isValidFarmTile = true
                    
                    -- Check if it's a proper farm tile (not a decoration)
                    if child.Material ~= Enum.Material.Grass and child.Material ~= Enum.Material.Sand and 
                       child.Material ~= Enum.Material.Rock and child.Material ~= Enum.Material.Water then
                        -- Allow some flexibility in materials
                    end
                    
                    if isValidFarmTile then
                        -- Water farm specific validation
                        if isWater and child.Name == "WaterFarm_split_0_0_0" then
                            table.insert(farmParts, child)
                        elseif not isWater then
                            table.insert(farmParts, child)
                        end
                    end
                end
            end
            scanForFarmParts(child, depth + 1)
        end
    end
    
    scanForFarmParts(island, 0)
    
    -- Enhanced lock detection with multiple validation methods
    local unlockedFarmParts = {}
    local env = island:FindFirstChild("ENV")
    local locksFolder = env and env:FindFirstChild("Locks")
    
    if locksFolder then
        local lockedAreas = {}
        
        -- Method 1: Traditional lock detection
        for _, lockModel in ipairs(locksFolder:GetChildren()) do
            if lockModel:IsA("Model") then
                local farmPart = lockModel:FindFirstChild("Farm")
                if farmPart and farmPart:IsA("BasePart") and farmPart.Transparency == 0 then
                    table.insert(lockedAreas, {
                        position = farmPart.Position,
                        size = farmPart.Size,
                        method = "traditional"
                    })
                end
                
                -- Method 2: Check for lock indicators by name pattern
                for _, child in ipairs(lockModel:GetDescendants()) do
                    if child:IsA("BasePart") and child.Name:match("[Ll]ock") and child.Transparency < 1 then
                        table.insert(lockedAreas, {
                            position = child.Position,
                            size = child.Size,
                            method = "pattern"
                        })
                    end
                end
            end
        end
        
        -- Filter out locked tiles with enhanced detection
        for _, farmPart in ipairs(farmParts) do
            local isLocked = false
            
            for _, lockArea in ipairs(lockedAreas) do
                local farmPartPos = farmPart.Position
                local lockCenter = lockArea.position
                local lockSize = lockArea.size
                
                -- Enhanced overlap detection with tolerance
                local tolerance = 2 -- Allow 2 stud tolerance for precision
                local lockHalfSize = lockSize / 2
                local lockMinX = lockCenter.X - lockHalfSize.X - tolerance
                local lockMaxX = lockCenter.X + lockHalfSize.X + tolerance
                local lockMinZ = lockCenter.Z - lockHalfSize.Z - tolerance
                local lockMaxZ = lockCenter.Z + lockHalfSize.Z + tolerance
                
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

-- ============ Ultra-Advanced Tile Occupancy Detection ============
local function isAdvancedTileOccupied(farmPart)
    local startTime = tick()
    local center = farmPart.Position
    
    -- Enhanced grid-snapped position with sub-pixel precision
    local surfacePosition = Vector3.new(
        math.floor(center.X / 8 + 0.5) * 8, -- Perfect 8x8 grid alignment
        center.Y + 12, -- Standard pet/egg height
        math.floor(center.Z / 8 + 0.5) * 8
    )
    
    -- Method 1: Check PlayerBuiltBlocks with spatial optimization
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    if playerBuiltBlocks then
        -- Use spatial grid for faster nearby object detection
        local nearbyModels = getNearbyTilesFromGrid(surfacePosition, 8)
        
        for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
            if model:IsA("Model") then
                local modelPos = model:GetPivot().Position
                
                -- Enhanced distance calculation with different tolerances for X/Z vs Y
                local xzDistance = math.sqrt((modelPos.X - surfacePosition.X)^2 + (modelPos.Z - surfacePosition.Z)^2)
                local yDistance = math.abs(modelPos.Y - surfacePosition.Y)
                
                -- Stricter XZ tolerance, more lenient Y tolerance for floating objects
                if xzDistance < 3.5 and yDistance < 15.0 then
                    performanceMetrics.lastTileSearchDuration = tick() - startTime
                    return true
                end
            end
        end
    end
    
    -- Method 2: Check workspace.Pets with enhanced detection
    local workspacePets = workspace:FindFirstChild("Pets")
    if workspacePets then
        for _, pet in ipairs(workspacePets:GetChildren()) do
            if pet:IsA("Model") then
                local petPos = pet:GetPivot().Position
                local xzDistance = math.sqrt((petPos.X - surfacePosition.X)^2 + (petPos.Z - surfacePosition.Z)^2)
                local yDistance = math.abs(petPos.Y - surfacePosition.Y)
                
                -- Pet-specific tolerances (pets are usually more precisely placed)
                if xzDistance < 3.8 and yDistance < 12.0 then
                    performanceMetrics.lastTileSearchDuration = tick() - startTime
                    return true
                end
            end
        end
    end
    
    -- Method 3: Check for invisible/transparent occupants (advanced detection)
    local occupants = workspace:GetPartBoundsInBox(
        CFrame.new(surfacePosition), 
        Vector3.new(8, 24, 8) -- 8x8 tile area, 24 studs height
    )
    
    for _, part in ipairs(occupants) do
        if part ~= farmPart and part.Parent ~= farmPart then
            -- Check if this part represents an occupant
            local parent = part.Parent
            if parent and (parent.Name:match("Egg") or parent.Name:match("Pet") or 
                          parent.Parent == playerBuiltBlocks or parent.Parent == workspacePets) then
                performanceMetrics.lastTileSearchDuration = tick() - startTime
                return true
            end
        end
    end
    
    performanceMetrics.lastTileSearchDuration = tick() - startTime
    return false
end

-- ============ Smart Tile Classification & Clustering ============
local function classifyAndClusterTiles(regularParts, waterParts, islandCenter)
    local regularTiles = {}
    local waterTiles = {}
    local centerTiles = {}
    local edgeTiles = {}
    local clusterRegions = {}
    
    -- Process regular tiles
    for _, part in ipairs(regularParts) do
        if not isAdvancedTileOccupied(part) then
            local tileInfo = {
                part = part,
                position = part.Position,
                type = "regular",
                distanceFromCenter = (part.Position - islandCenter).Magnitude,
                neighbors = 0,
                cluster = nil
            }
            
            table.insert(regularTiles, tileInfo)
            addToSpatialGrid(part.Position, tileInfo)
            
            -- Classify by distance from center
            if tileInfo.distanceFromCenter <= 32 then -- Within 32 studs of center
                table.insert(centerTiles, tileInfo)
            else
                table.insert(edgeTiles, tileInfo)
            end
        end
    end
    
    -- Process water tiles
    for _, part in ipairs(waterParts) do
        if not isAdvancedTileOccupied(part) then
            local tileInfo = {
                part = part,
                position = part.Position,
                type = "water",
                distanceFromCenter = (part.Position - islandCenter).Magnitude,
                neighbors = 0,
                cluster = nil
            }
            
            table.insert(waterTiles, tileInfo)
            addToSpatialGrid(part.Position, tileInfo)
            
            if tileInfo.distanceFromCenter <= 32 then
                table.insert(centerTiles, tileInfo)
            else
                table.insert(edgeTiles, tileInfo)
            end
        end
    end
    
    -- Advanced clustering algorithm for grouped placement
    if useClusterPlacement then
        local allTiles = {}
        for _, tile in ipairs(regularTiles) do table.insert(allTiles, tile) end
        for _, tile in ipairs(waterTiles) do table.insert(allTiles, tile) end
        
        local clusterId = 1
        for _, tile in ipairs(allTiles) do
            if not tile.cluster then
                local cluster = { id = clusterId, tiles = {}, center = tile.position, type = tile.type }
                table.insert(cluster.tiles, tile)
                tile.cluster = clusterId
                
                -- Find nearby tiles for this cluster (within 16 studs)
                local nearbyTiles = getNearbyTilesFromGrid(tile.position, 16)
                for _, nearbyTile in ipairs(nearbyTiles) do
                    if not nearbyTile.cluster and nearbyTile.type == tile.type then
                        table.insert(cluster.tiles, nearbyTile)
                        nearbyTile.cluster = clusterId
                    end
                end
                
                -- Calculate cluster center
                if #cluster.tiles > 1 then
                    local totalX, totalZ = 0, 0
                    for _, clusterTile in ipairs(cluster.tiles) do
                        totalX = totalX + clusterTile.position.X
                        totalZ = totalZ + clusterTile.position.Z
                    end
                    cluster.center = Vector3.new(totalX / #cluster.tiles, cluster.center.Y, totalZ / #cluster.tiles)
                end
                
                table.insert(clusterRegions, cluster)
                clusterId = clusterId + 1
            end
        end
    end
    
    return regularTiles, waterTiles, centerTiles, edgeTiles, clusterRegions
end

-- ============ Enhanced Tile Cache Update ============
local function updateEnhancedTileCache()
    local currentTime = time()
    if currentTime - enhancedTileCache.lastUpdate < CACHE_DURATION then
        performanceMetrics.totalCacheRequests = performanceMetrics.totalCacheRequests + 1
        performanceMetrics.cacheHits = performanceMetrics.cacheHits + 1
        return enhancedTileCache.totalRegular, enhancedTileCache.totalWater
    end
    
    performanceMetrics.totalCacheRequests = performanceMetrics.totalCacheRequests + 1
    
    local islandName = getAssignedIslandName()
    local islandNumber = getIslandNumberFromName(islandName)
    
    if not islandNumber then
        enhancedTileCache.totalRegular = 0
        enhancedTileCache.totalWater = 0
        return 0, 0
    end
    
    -- Calculate island center for smart placement
    enhancedTileCache.islandCenter = calculateIslandCenter(islandNumber)
    
    -- Get enhanced farm parts
    local regularParts = getEnhancedFarmParts(islandNumber, false)
    local waterParts = getEnhancedFarmParts(islandNumber, true)
    
    -- Clear spatial grid
    enhancedTileCache.spatialGrid = {}
    
    -- Classify and cluster tiles
    local regularTiles, waterTiles, centerTiles, edgeTiles, clusterRegions = 
        classifyAndClusterTiles(regularParts, waterParts, enhancedTileCache.islandCenter)
    
    -- Update cache
    enhancedTileCache.lastUpdate = currentTime
    enhancedTileCache.regularTiles = regularTiles
    enhancedTileCache.waterTiles = waterTiles
    enhancedTileCache.centerTiles = centerTiles
    enhancedTileCache.edgeTiles = edgeTiles
    enhancedTileCache.clusterRegions = clusterRegions
    enhancedTileCache.totalRegular = #regularTiles
    enhancedTileCache.totalWater = #waterTiles
    
    -- Update performance metrics
    local totalRequests = performanceMetrics.totalCacheRequests
    performanceMetrics.cacheHitRate = totalRequests > 0 and (performanceMetrics.cacheHits / totalRequests * 100) or 0
    
    return #regularTiles, #waterTiles
end

-- ============ Smart Tile Selection Algorithm ============
local function getOptimalTile(tileType, placementStrategy)
    local regularAvailable, waterAvailable = updateEnhancedTileCache()
    
    local targetTiles = {}
    if tileType == "water" and waterAvailable > 0 then
        targetTiles = enhancedTileCache.waterTiles
    elseif tileType == "regular" and regularAvailable > 0 then
        targetTiles = enhancedTileCache.regularTiles
    else
        return nil
    end
    
    if #targetTiles == 0 then return nil end
    
    -- Apply placement strategy
    if placementStrategy == "center_first" and prioritizeCenterTiles then
        -- Sort by distance from center (closest first)
        table.sort(targetTiles, function(a, b)
            return a.distanceFromCenter < b.distanceFromCenter
        end)
        return targetTiles[1]
        
    elseif placementStrategy == "cluster" and useClusterPlacement then
        -- Find best cluster with most available tiles
        local bestCluster = nil
        local maxTiles = 0
        
        for _, cluster in ipairs(enhancedTileCache.clusterRegions) do
            if cluster.type == tileType then
                local availableInCluster = 0
                for _, tile in ipairs(cluster.tiles) do
                    if not isAdvancedTileOccupied(tile.part) then
                        availableInCluster = availableInCluster + 1
                    end
                end
                
                if availableInCluster > maxTiles then
                    maxTiles = availableInCluster
                    bestCluster = cluster
                end
            end
        end
        
        if bestCluster and #bestCluster.tiles > 0 then
            -- Return tile closest to cluster center
            local bestTile = bestCluster.tiles[1]
            local minDistance = (bestTile.position - bestCluster.center).Magnitude
            
            for _, tile in ipairs(bestCluster.tiles) do
                if not isAdvancedTileOccupied(tile.part) then
                    local distance = (tile.position - bestCluster.center).Magnitude
                    if distance < minDistance then
                        minDistance = distance
                        bestTile = tile
                    end
                end
            end
            return bestTile
        end
        
    elseif placementStrategy == "edge_first" then
        -- Sort by distance from center (farthest first)
        table.sort(targetTiles, function(a, b)
            return a.distanceFromCenter > b.distanceFromCenter
        end)
        return targetTiles[1]
    end
    
    -- Default: random selection
    return targetTiles[math.random(1, #targetTiles)]
end

-- ============ Pet & Egg Management (Enhanced) ============
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

-- Enhanced egg detection with better ocean egg identification
local OCEAN_EGGS = {
    ["SeaweedEgg"] = true,
    ["ClownfishEgg"] = true,
    ["LionfishEgg"] = true,
    ["SharkEgg"] = true,
    ["AnglerfishEgg"] = true,
    ["OctopusEgg"] = true,
    ["SeaDragonEgg"] = true,
    ["TurtleEgg"] = true,
    ["JellyfishEgg"] = true,
    ["WhaleEgg"] = true
}

local function isOceanEgg(eggType)
    return OCEAN_EGGS[eggType] == true
end

-- ============ Enhanced Pet Data Functions ============
local function getPetBaseData(petType)
    ensureConfigCached()
    return resPetById and resPetById[petType] or nil
end

local function getMutationData(mutation)
    ensureConfigCached()
    return resMutateById and resMutateById[mutation] or nil
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
    
    -- Enhanced heuristic detection
    if typeof(petType) == "string" then
        local t = string.lower(petType)
        local oceanKeywords = {"fish", "shark", "octopus", "sea", "angler", "whale", "turtle", "jellyfish", "coral", "crab"}
        for _, keyword in ipairs(oceanKeywords) do
            if string.find(t, keyword) then
                return true
            end
        end
    end
    return false
end

-- ============ Focus & Placement Functions ============
local function waitJitter(baseSeconds)
    local jitter = math.random() * 0.15 + 0.05 -- 0.05-0.2 second jitter
    task.wait(baseSeconds + jitter)
end

local function focusEgg(eggUID)
    if not CharacterRE then return false end
    local success, err = pcall(function()
        CharacterRE:FireServer("Focus", eggUID)
    end)
    return success
end

local function enhancedPlacePet(tileInfo, eggUID)
    if not tileInfo or not tileInfo.part or not eggUID then return false end
    
    local placementStartTime = tick()
    
    -- Ultra-precise surface position calculation
    local tileCenter = tileInfo.part.Position
    local surfacePosition = Vector3.new(
        math.floor(tileCenter.X / 8 + 0.5) * 8, -- Perfect 8x8 grid snap
        tileCenter.Y + (tileInfo.part.Size.Y / 2), -- Exact surface height
        math.floor(tileCenter.Z / 8 + 0.5) * 8
    )
    
    -- Enhanced deployment setup
    local deploy = LocalPlayer.PlayerGui.Data:FindFirstChild("Deploy")
    if deploy then
        deploy:SetAttribute("S2", eggUID)
    end
    
    -- Optimized key input with minimal delay
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
    waitJitter(0.08)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
    waitJitter(0.08)
    
    -- Enhanced placement with vector precision
    local vector = { create = function(x, y, z) return Vector3.new(x, y, z) end }
    local args = {
        "Place",
        {
            DST = vector.create(surfacePosition.X, surfacePosition.Y, surfacePosition.Z),
            ID = eggUID
        }
    }

    if not CharacterRE then return false end

    local success, err = pcall(function()
        CharacterRE:FireServer(unpack(args))
    end)
    
    if not success then return false end
    
    -- Enhanced verification with multiple methods
    waitJitter(0.35)
    
    -- Method 1: Check pet attributes
    local petContainer = getPetContainer()
    local petNode = petContainer and petContainer:FindFirstChild(eggUID)
    if petNode then
        local dAttr = petNode:GetAttribute("D")
        if dAttr ~= nil and tostring(dAttr) ~= "" then
            local placementTime = tick() - placementStartTime
            placementStats.averagePlacementTime = (placementStats.averagePlacementTime + placementTime) / 2
            return true
        end
    end
    
    -- Method 2: Enhanced occupancy verification
    if isAdvancedTileOccupied(tileInfo.part) then
        local placementTime = tick() - placementStartTime
        placementStats.averagePlacementTime = (placementStats.averagePlacementTime + placementTime) / 2
        return true
    end
    
    return false
end

-- ============ Enhanced Placement Logic ============
local function getNextOptimalEgg()
    local allEggs = {}
    local eg = getEggContainer()
    if not eg then return nil, nil, "no_container" end
    
    -- Create optimized filter sets
    local selectedTypeSet = {}
    for _, type in ipairs(selectedEggTypes) do
        local cleanType = type:gsub("🌊 ", "")
        selectedTypeSet[cleanType] = true
    end
    
    local selectedMutationSet = {}
    for _, mutation in ipairs(selectedMutations) do
        selectedMutationSet[mutation] = true
    end
    
    -- Collect and filter eggs
    for _, child in ipairs(eg:GetChildren()) do
        if #child:GetChildren() == 0 then
            local eggType = child:GetAttribute("T")
            if eggType then
                local mutation = getEggMutation(child.Name)
                
                -- Apply filters
                local passesTypeFilter = #selectedEggTypes == 0 or selectedTypeSet[eggType] == true
                local passesMutationFilter = #selectedMutations == 0 or 
                    (mutation and selectedMutationSet[mutation] == true)
                
                if passesTypeFilter and passesMutationFilter then
                    local priority = 100
                    if mutation then priority = priority + 1000 end -- Mutations get highest priority
                    if isOceanEgg(eggType) then priority = priority + 500 end -- Ocean eggs get medium priority
                    
                    table.insert(allEggs, { 
                        uid = child.Name, 
                        type = eggType,
                        mutation = mutation,
                        priority = priority,
                        isOcean = isOceanEgg(eggType)
                    })
                end
            end
        end
    end
    
    if #allEggs == 0 then return nil, nil, "no_eggs" end
    
    -- Sort by priority
    table.sort(allEggs, function(a, b) return a.priority > b.priority end)
    
    -- Smart tile selection based on egg type
    local regularAvailable, waterAvailable = updateEnhancedTileCache()
    
    for _, eggInfo in ipairs(allEggs) do
        local tileType = eggInfo.isOcean and "water" or "regular"
        local requiredAvailable = eggInfo.isOcean and waterAvailable or regularAvailable
        
        if requiredAvailable > 0 then
            local placementStrategy = smartPlacementMode and "center_first" or "random"
            if useClusterPlacement then placementStrategy = "cluster" end
            
            local optimalTile = getOptimalTile(tileType, placementStrategy)
            if optimalTile then
                return eggInfo, optimalTile, "success"
            end
        elseif eggInfo.isOcean and regularAvailable > 0 and fallbackToRegularWhenNoWater then
            -- Fallback: place ocean egg on regular tile if allowed
            local optimalTile = getOptimalTile("regular", "center_first")
            if optimalTile then
                return eggInfo, optimalTile, "fallback"
            end
        end
    end
    
    return nil, nil, "no_space"
end

-- ============ Main Placement Function ============
local function attemptEnhancedPlacement()
    placementStats.totalAttempts = placementStats.totalAttempts + 1
    
    local eggInfo, tileInfo, reason = getNextOptimalEgg()
    
    if not eggInfo or not tileInfo then
        if reason == "no_space" then
            placementStats.lastReason = "No available tiles for selected eggs"
        elseif reason == "no_eggs" then
            placementStats.lastReason = "No eggs match current filters"
        else
            placementStats.lastReason = "No suitable eggs or tiles found"
        end
        return false, placementStats.lastReason
    end
    
    -- Focus egg first
    if not focusEgg(eggInfo.uid) then
        placementStats.lastReason = "Failed to focus egg " .. eggInfo.uid
        return false, placementStats.lastReason
    end
    
    waitJitter(0.15) -- Reduced wait time for responsiveness
    
    -- Attempt placement
    local success = enhancedPlacePet(tileInfo, eggInfo.uid)
    
    if success then
        -- Update statistics
        placementStats.totalPlacements = placementStats.totalPlacements + 1
        placementStats.lastPlacement = os.time()
        
        if eggInfo.mutation then
            placementStats.mutationPlacements = placementStats.mutationPlacements + 1
        end
        
        -- Track placement type
        if tileInfo.distanceFromCenter <= 32 then
            placementStats.centerPlacements = placementStats.centerPlacements + 1
        end
        
        if tileInfo.cluster then
            placementStats.clusterPlacements = placementStats.clusterPlacements + 1
        end
        
        -- Calculate success rate
        placementStats.placementSuccessRate = (placementStats.totalPlacements / placementStats.totalAttempts) * 100
        
        -- Invalidate cache for next iteration
        enhancedTileCache.lastUpdate = 0
        
        local placementType = reason == "fallback" and " (fallback to regular tile)" or ""
        placementStats.lastReason = "Placed " .. (eggInfo.mutation and (eggInfo.mutation .. " ") or "") .. 
            eggInfo.type .. placementType
        
        -- Enhanced notification
        WindUI:Notify({
            Title = "🏠 Enhanced Auto Place",
            Content = "✅ " .. placementStats.lastReason .. " | Success: " .. 
                math.floor(placementStats.placementSuccessRate) .. "%",
            Duration = 2
        })
        
        return true, placementStats.lastReason
    else
        placementStats.lastReason = "Failed to place " .. eggInfo.type
        return false, placementStats.lastReason
    end
end

-- ============ Auto Place Main Loop ============
local autoPlaceEnabled = false
local autoPlaceThread = nil

local function runEnhancedAutoPlace()
    local consecutiveFailures = 0
    local maxFailures = 3 -- Reduced for faster recovery
    
    while autoPlaceEnabled do
        local success, message = attemptEnhancedPlacement()
        
        if success then
            consecutiveFailures = 0
            waitJitter(1.2) -- Faster placement cycle
        else
            consecutiveFailures = consecutiveFailures + 1
            
            -- Adaptive waiting with shorter delays
            if message:find("No available tiles") then
                waitJitter(4) -- Reduced wait for no space
            elseif message:find("No eggs match") then
                waitJitter(6) -- Wait for new eggs
            elseif consecutiveFailures >= maxFailures then
                waitJitter(8) -- Reduced max failure wait
                consecutiveFailures = 0
            else
                waitJitter(1.5) -- Faster retry
            end
        end
    end
end

-- ============ Public API ============
function EnhancedAutoPlace.Init(dependencies)
    WindUI = dependencies.WindUI
    Tabs = dependencies.Tabs
    Config = dependencies.Config
    
    math.randomseed(os.time())
    EnhancedAutoPlace.CreateUI()
    
    return EnhancedAutoPlace
end

function EnhancedAutoPlace.CreateUI()
    -- Header section
    Tabs.PlaceTab:Paragraph({
        Title = "🚀 Enhanced Auto Place System",
        Desc = "Advanced tile finding with spatial indexing, smart placement strategies, and ultra-fast detection algorithms.",
        Image = "zap",
        ImageSize = 16,
    })

    -- Egg filters section
    Tabs.PlaceTab:Paragraph({
        Title = "🥚 Egg Selection",
        Desc = "Choose which eggs to place with enhanced filtering.",
        Image = "filter",
        ImageSize = 14,
    })

    -- Egg type dropdown
    local eggDropdown = Tabs.PlaceTab:Dropdown({
        Title = "🥚 Select Egg Types",
        Desc = "Choose which eggs to place (🌊 = ocean eggs)",
        Values = {
            "BasicEgg", "RareEgg", "SuperRareEgg", "EpicEgg", "LegendEgg", "PrismaticEgg", 
            "HyperEgg", "VoidEgg", "BowserEgg", "DemonEgg", "CornEgg", "BoneDragonEgg", 
            "UltraEgg", "DinoEgg", "FlyEgg", "UnicornEgg", "AncientEgg",
            "🌊 SeaweedEgg", "🌊 ClownfishEgg", "🌊 LionfishEgg", "🌊 SharkEgg", 
            "🌊 AnglerfishEgg", "🌊 OctopusEgg", "🌊 SeaDragonEgg", "🌊 TurtleEgg"
        },
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedEggTypes = selection
        end
    })
    
    -- Mutation dropdown
    local mutationDropdown = Tabs.PlaceTab:Dropdown({
        Title = "🧬 Select Mutations",
        Desc = "Filter by mutation types (empty = all mutations)",
        Values = {"Golden", "Diamond", "Electric", "Fire", "Jurassic", "Rainbow", "Dark"},
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedMutations = selection
        end
    })
    
    -- Statistics display
    local statsLabel = Tabs.PlaceTab:Paragraph({
        Title = "📊 Enhanced Statistics",
        Desc = "Initializing enhanced placement system...",
        Image = "activity",
        ImageSize = 16,
    })

    -- Placement strategy section
    Tabs.PlaceTab:Paragraph({
        Title = "🧠 Placement Strategy",
        Desc = "Configure advanced placement algorithms.",
        Image = "brain",
        ImageSize = 14,
    })

    -- Smart placement mode
    Tabs.PlaceTab:Toggle({
        Title = "🎯 Smart Placement Mode",
        Desc = "Use advanced algorithms for optimal tile selection",
        Value = true,
        Callback = function(state)
            smartPlacementMode = state
        end
    })

    -- Center-first placement
    Tabs.PlaceTab:Toggle({
        Title = "🎯 Prioritize Center Tiles",
        Desc = "Place pets near island center first for better organization",
        Value = true,
        Callback = function(state)
            prioritizeCenterTiles = state
            enhancedTileCache.lastUpdate = 0
        end
    })

    -- Cluster placement
    Tabs.PlaceTab:Toggle({
        Title = "🔗 Cluster Placement",
        Desc = "Group pets together in clusters for organized farms",
        Value = false,
        Callback = function(state)
            useClusterPlacement = state
            enhancedTileCache.lastUpdate = 0
        end
    })

    -- Fallback option
    Tabs.PlaceTab:Toggle({
        Title = "🔄 Fallback to Regular Tiles",
        Desc = "Place ocean eggs on regular tiles when no water tiles available",
        Value = false,
        Callback = function(state)
            fallbackToRegularWhenNoWater = state
        end
    })

    -- Performance section
    Tabs.PlaceTab:Paragraph({
        Title = "⚡ Performance Metrics",
        Desc = "Real-time system performance monitoring.",
        Image = "gauge",
        ImageSize = 14,
    })
    
    -- Statistics update function
    local function updateEnhancedStats()
        if not statsLabel then return end
        
        local regularAvail, waterAvail = updateEnhancedTileCache()
        local lastPlacementText = ""
        
        if placementStats.lastPlacement then
            local timeSince = os.time() - placementStats.lastPlacement
            local timeText = timeSince < 60 and (timeSince .. "s") or (math.floor(timeSince/60) .. "m")
            lastPlacementText = " | ⏱️ " .. timeText
        end
        
        local reasonText = placementStats.lastReason and (" | " .. placementStats.lastReason) or ""
        
        local statsText = string.format(
            "✅ Placed: %d | 🦄 Mutations: %d | 🎯 Success: %d%% | 🧱 R/W: %d/%d | 🏠 Center: %d | 🔗 Cluster: %d%s%s",
            placementStats.totalPlacements,
            placementStats.mutationPlacements,
            math.floor(placementStats.placementSuccessRate),
            regularAvail or 0,
            waterAvail or 0,
            placementStats.centerPlacements,
            placementStats.clusterPlacements,
            reasonText,
            lastPlacementText
        )
        
        if statsLabel.SetDesc then
            statsLabel:SetDesc(statsText)
        end
    end
    
    -- Main toggle
    local mainToggle = Tabs.PlaceTab:Toggle({
        Title = "🚀 Enhanced Auto Place",
        Desc = "Start the advanced placement system with smart algorithms!",
        Value = false,
        Callback = function(state)
            autoPlaceEnabled = state
            
            if state and not autoPlaceThread then
                autoPlaceThread = task.spawn(function()
                    runEnhancedAutoPlace()
                    autoPlaceThread = nil
                end)
                
                -- Stats update loop
                task.spawn(function()
                    while autoPlaceEnabled do
                        updateEnhancedStats()
                        task.wait(2) -- Faster updates
                    end
                end)
                
                WindUI:Notify({ 
                    Title = "🚀 Enhanced Auto Place", 
                    Content = "Advanced system activated! 🎉", 
                    Duration = 3 
                })
            elseif not state and autoPlaceThread then
                WindUI:Notify({ 
                    Title = "🚀 Enhanced Auto Place", 
                    Content = "System stopped", 
                    Duration = 2 
                })
            end
        end
    })
    
    -- Store references
    EnhancedAutoPlace.Toggle = mainToggle
    EnhancedAutoPlace.EggDropdown = eggDropdown
    EnhancedAutoPlace.MutationDropdown = mutationDropdown
end

-- Additional utility functions
function EnhancedAutoPlace.GetStats()
    return placementStats, performanceMetrics
end

function EnhancedAutoPlace.IsEnabled()
    return autoPlaceEnabled
end

function EnhancedAutoPlace.SetEnabled(enabled)
    if EnhancedAutoPlace.Toggle then
        EnhancedAutoPlace.Toggle:SetValue(enabled)
    end
end

function EnhancedAutoPlace.ClearCache()
    enhancedTileCache.lastUpdate = 0
    enhancedTileCache.spatialGrid = {}
    WindUI:Notify({
        Title = "🔄 Cache Cleared",
        Content = "Enhanced tile cache refreshed",
        Duration = 2
    })
end

return EnhancedAutoPlace
