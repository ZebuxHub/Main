-- ============================================
-- Auto Place System - Clean & Integrated
-- ============================================
-- Clean placement system with mode selection, place type selection, and filters

local AutoPlaceSystem = {}

-- ============ Services & Dependencies ============
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- ============ External Dependencies ============
local WindUI, Tabs, Config
local selectedModes = {} -- pet, egg (multi-select)
local selectedPlaceTypes = {} -- normal, water (multi-select)
local selectedEggTypes = {}
local selectedEggMutations = {}
local selectedPetTypes = {}
local selectedPetMutations = {}
local minProduce = 0
local autoPlaceEnabled = false

-- ============ Remote Cache ============
local Remotes = ReplicatedStorage:WaitForChild("Remote", 5)
local CharacterRE = Remotes and Remotes:FindFirstChild("CharacterRE")

-- ============ Stats ============
local placementStats = {
    totalPlacements = 0,
    mutationPlacements = 0,
    lastPlacement = nil,
    lastReason = nil
}

-- ============ Config Cache ============
local resPetById = nil
local resMutateById = nil
local resBigPetScale = nil

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

-- ============ Pet Data Functions ============
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
    if typeof(petType) == "string" then
        local t = string.lower(petType)
        if string.find(t, "fish") or string.find(t, "shark") or string.find(t, "octopus") or string.find(t, "sea") or string.find(t, "angler") then
            return true
        end
    end
    return false
end

local function isOceanEgg(eggType)
    local oceanEggs = {
        ["SeaweedEgg"] = true,
        ["ClownfishEgg"] = true,
        ["LionfishEgg"] = true,
        ["SharkEgg"] = true,
        ["AnglerfishEgg"] = true,
        ["OctopusEgg"] = true,
        ["SeaDragonEgg"] = true
    }
    return oceanEggs[eggType] == true
end

-- ============ Data Collection ============
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

local function isPetAlreadyPlacedByUid(petUID)
    local container = getPetContainer()
    local node = container and container:FindFirstChild(petUID)
    if not node then return false end
    local dAttr = node:GetAttribute("D")
    return dAttr ~= nil and tostring(dAttr) ~= ""
end

-- ============ Available Items ============
local function getAvailableEggs()
    local eg = getEggContainer()
    local eggs = {}
    
    if not eg then return eggs end
    
    for _, child in ipairs(eg:GetChildren()) do
        if #child:GetChildren() == 0 then -- No subfolder = available
            local eggType = child:GetAttribute("T")
            if eggType then
                local mutation = getEggMutation(child.Name)
                
                -- Check if egg type is selected
                local typeSelected = #selectedEggTypes == 0 or table.find(selectedEggTypes, eggType) ~= nil
                
                -- Check if mutation is selected
                local mutationSelected = #selectedEggMutations == 0 or (mutation and table.find(selectedEggMutations, mutation) ~= nil)
                
                if typeSelected and mutationSelected then
                    table.insert(eggs, {
                        uid = child.Name,
                        type = eggType,
                        mutation = mutation,
                        isOcean = isOceanEgg(eggType)
                    })
                end
            end
        end
    end
    
    return eggs
end

local function getAvailablePets()
    local container = getPetContainer()
    local pets = {}
    
    if not container then return pets end
    
    for _, child in ipairs(container:GetChildren()) do
        local petType = child:GetAttribute("T")
        local mutation = child:GetAttribute("M")
        if mutation == "Dino" then
            mutation = "Jurassic"
        end
        
        if petType and not isPetAlreadyPlacedByUid(child.Name) then
            -- Check if pet type is selected
            local typeSelected = #selectedPetTypes == 0 or table.find(selectedPetTypes, petType) ~= nil
            
            -- Check if mutation is selected
            local mutationSelected = #selectedPetMutations == 0 or (mutation and table.find(selectedPetMutations, mutation) ~= nil)
            
            if typeSelected and mutationSelected then
                -- Calculate effective rate (simplified)
                local base = getPetBaseData(petType)
                local rate = base and (tonumber(base.ProduceRate) or 0) or 0
                
                -- Apply mutation multiplier
                if mutation then
                    local m = getMutationData(mutation)
                    if m and tonumber(m.ProduceRate) then
                        rate = rate * tonumber(m.ProduceRate)
                    end
                end
                
                -- Check min produce filter
                if rate >= minProduce then
                    table.insert(pets, {
                        uid = child.Name,
                        type = petType,
                        mutation = mutation,
                        rate = rate,
                        isOcean = isOceanPet(petType)
                    })
                end
            end
        end
    end
    
    -- Sort by rate (highest first)
    table.sort(pets, function(a, b) return a.rate > b.rate end)
    
    return pets
end

-- ============ Tile Management ============
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
                
                if matches and child.Size == Vector3.new(8, 8, 8) and child.CanCollide then
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
    return farmParts
end

local function isTileOccupied(farmPart)
    local center = farmPart.Position
    local surfacePosition = Vector3.new(
        math.floor(center.X / 8) * 8 + 4,
        center.Y + 12,
        math.floor(center.Z / 8) * 8 + 4
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

local function getAvailableTiles()
    local islandName = getAssignedIslandName()
    local islandNumber = getIslandNumberFromName(islandName)
    
    if not islandNumber then return {}, {} end
    
    local regularParts = getFarmParts(islandNumber, false)
    local waterParts = getFarmParts(islandNumber, true)
    
    local regularTiles = {}
    local waterTiles = {}
    
    for _, part in ipairs(regularParts) do
        if not isTileOccupied(part) then
            table.insert(regularTiles, part)
        end
    end
    
    for _, part in ipairs(waterParts) do
        if not isTileOccupied(part) then
            table.insert(waterTiles, part)
        end
    end
    
    return regularTiles, waterTiles
end

-- ============ Placement Functions ============
local function focusEgg(eggUID)
    if not CharacterRE then return false end
    local success, err = pcall(function()
        CharacterRE:FireServer("Focus", eggUID)
    end)
    return success
end

local function placePet(farmPart, eggUID)
    if not farmPart or not eggUID then return false end
    
    local tileCenter = farmPart.Position
    local surfacePosition = Vector3.new(
        math.floor(tileCenter.X / 8) * 8 + 4,
        tileCenter.Y + (farmPart.Size.Y / 2),
        math.floor(tileCenter.Z / 8) * 8 + 4
    )
    
    -- Equip egg to Deploy S2
    local deploy = LocalPlayer.PlayerGui.Data:FindFirstChild("Deploy")
    if deploy then
        deploy:SetAttribute("S2", eggUID)
    end
    
    -- Hold egg (key 2)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
    task.wait(0.1)
    
    -- Place pet
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
    
    -- Verify placement
    task.wait(0.4)
    local petContainer = getPetContainer()
    local petNode = petContainer and petContainer:FindFirstChild(eggUID)
    if petNode then
        local dAttr = petNode:GetAttribute("D")
        if dAttr ~= nil and tostring(dAttr) ~= "" then
            return true
        end
    end
    
    return isTileOccupied(farmPart)
end

-- ============ Main Placement Logic ============
local function attemptPlacement()
    local regularTiles, waterTiles = getAvailableTiles()
    
    -- Check if we have any place types selected
    local canUseRegular = table.find(selectedPlaceTypes, "normal") ~= nil
    local canUseWater = table.find(selectedPlaceTypes, "water") ~= nil
    
    if not canUseRegular and not canUseWater then
        placementStats.lastReason = "No place types selected"
        return false, placementStats.lastReason
    end
    
    -- Try eggs first if selected
    if table.find(selectedModes, "egg") ~= nil then
        local eggs = getAvailableEggs()
        
        for _, egg in ipairs(eggs) do
            local tile = nil
            
            if egg.isOcean and canUseWater and #waterTiles > 0 then
                tile = waterTiles[math.random(1, #waterTiles)]
            elseif not egg.isOcean and canUseRegular and #regularTiles > 0 then
                tile = regularTiles[math.random(1, #regularTiles)]
            end
            
            if tile then
                if not focusEgg(egg.uid) then
                    placementStats.lastReason = "Failed to focus egg " .. egg.uid
                    return false, placementStats.lastReason
                end
                
                task.wait(0.2)
                local success = placePet(tile, egg.uid)
                
                if success then
                    placementStats.lastReason = "Placed " .. (egg.mutation and (egg.mutation .. " ") or "") .. egg.type
                    if egg.mutation then
                        placementStats.mutationPlacements = placementStats.mutationPlacements + 1
                    end
                    return true, "Successfully placed " .. egg.type
                end
            end
        end
    end
    
    -- Try pets if selected
    if table.find(selectedModes, "pet") ~= nil then
        local pets = getAvailablePets()
        
        for _, pet in ipairs(pets) do
            local tile = nil
            
            if pet.isOcean and canUseWater and #waterTiles > 0 then
                tile = waterTiles[math.random(1, #waterTiles)]
            elseif not pet.isOcean and canUseRegular and #regularTiles > 0 then
                tile = regularTiles[math.random(1, #regularTiles)]
            end
            
            if tile then
                if not focusEgg(pet.uid) then
                    placementStats.lastReason = "Failed to focus pet " .. pet.uid
                    return false, placementStats.lastReason
                end
                
                task.wait(0.2)
                local success = placePet(tile, pet.uid)
                
                if success then
                    placementStats.lastReason = "Placed " .. (pet.mutation and (pet.mutation .. " ") or "") .. pet.type .. " (Rate: " .. pet.rate .. ")"
                    if pet.mutation then
                        placementStats.mutationPlacements = placementStats.mutationPlacements + 1
                    end
                    return true, "Successfully placed pet"
                end
            end
        end
    end
    
    placementStats.lastReason = "No suitable items found"
    return false, placementStats.lastReason
end

-- ============ Main Loop ============
local autoPlaceThread = nil

local function runAutoPlace()
    while autoPlaceEnabled do
        local success, message = attemptPlacement()
        
        if success then
            placementStats.totalPlacements = placementStats.totalPlacements + 1
            placementStats.lastPlacement = os.time()
            task.wait(1.5)
        else
            task.wait(3)
        end
    end
end

-- ============ UI Creation ============
function AutoPlaceSystem.CreateUI()
    -- Mode section
    Tabs.PlaceTab:Section({ Title = "Mode", Icon = "list" })
    local modeDropdown = Tabs.PlaceTab:Dropdown({
        Title = "Mode",
        Desc = "Select what to place",
        Values = {"pet", "egg"},
        Value = {},
        Multi = true,
        Callback = function(selection)
            selectedModes = selection
        end
    })
    
    -- Place type section
    Tabs.PlaceTab:Section({ Title = "Place", Icon = "map-pin" })
    local placeTypeDropdown = Tabs.PlaceTab:Dropdown({
        Title = "Place Type",
        Desc = "Select where to place",
        Values = {"normal", "water"},
        Value = {},
        Multi = true,
        Callback = function(selection)
            selectedPlaceTypes = selection
        end
    })
    
    -- Egg filters section
    Tabs.PlaceTab:Section({ Title = "Egg Filters", Icon = "egg" })
    local eggDropdown = Tabs.PlaceTab:Dropdown({
        Title = "Egg Types",
        Desc = "Select egg types to place",
        Values = {
            "BasicEgg", "RareEgg", "SuperRareEgg", "EpicEgg", "LegendEgg", "PrismaticEgg", 
            "HyperEgg", "VoidEgg", "BowserEgg", "DemonEgg", "CornEgg", "BoneDragonEgg", 
            "UltraEgg", "DinoEgg", "FlyEgg", "UnicornEgg", "AncientEgg",
            "SeaweedEgg", "ClownfishEgg", "LionfishEgg", "SharkEgg", 
            "AnglerfishEgg", "OctopusEgg", "SeaDragonEgg"
        },
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedEggTypes = selection
        end
    })
    
    local eggMutationDropdown = Tabs.PlaceTab:Dropdown({
        Title = "Egg Mutations",
        Desc = "Select egg mutations to place",
        Values = {"Golden", "Diamond", "Electric", "Fire", "Jurassic"},
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedEggMutations = selection
        end
    })
    
    -- Pet filters section
    Tabs.PlaceTab:Section({ Title = "Pet Filters", Icon = "paw-print" })
    local petDropdown = Tabs.PlaceTab:Dropdown({
        Title = "Pet Types",
        Desc = "Select pet types to place",
        Values = {}, -- Will be populated from game data
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedPetTypes = selection
        end
    })
    
    local petMutationDropdown = Tabs.PlaceTab:Dropdown({
        Title = "Pet Mutations",
        Desc = "Select pet mutations to place",
        Values = {"Golden", "Diamond", "Electric", "Fire", "Jurassic"},
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedPetMutations = selection
        end
    })
    
    -- Min produce section
    Tabs.PlaceTab:Section({ Title = "Settings", Icon = "settings" })
    local minProduceInput = Tabs.PlaceTab:Input({
        Title = "Min Produce",
        Desc = "Minimum production rate for pets",
        Value = "0",
        Placeholder = "e.g. 100",
        Callback = function(value)
            minProduce = tonumber(value) or 0
        end
    })
    
    -- Auto place toggle
    Tabs.PlaceTab:Section({ Title = "Control", Icon = "play" })
    local autoPlaceToggle = Tabs.PlaceTab:Toggle({
        Title = "Auto Place",
        Desc = "Start/stop automatic placement",
        Value = false,
        Callback = function(state)
            autoPlaceEnabled = state
            
            if state and not autoPlaceThread then
                autoPlaceThread = task.spawn(runAutoPlace)
                WindUI:Notify({ Title = "Auto Place", Content = "Started!", Duration = 2 })
            elseif not state and autoPlaceThread then
                WindUI:Notify({ Title = "Auto Place", Content = "Stopped", Duration = 2 })
            end
        end
    })
    
    -- Store references for external access
    AutoPlaceSystem.ModeDropdown = modeDropdown
    AutoPlaceSystem.PlaceTypeDropdown = placeTypeDropdown
    AutoPlaceSystem.EggDropdown = eggDropdown
    AutoPlaceSystem.EggMutationDropdown = eggMutationDropdown
    AutoPlaceSystem.PetDropdown = petDropdown
    AutoPlaceSystem.PetMutationDropdown = petMutationDropdown
    AutoPlaceSystem.MinProduceInput = minProduceInput
    AutoPlaceSystem.AutoPlaceToggle = autoPlaceToggle
end

-- ============ Public API ============
function AutoPlaceSystem.Init(dependencies)
    WindUI = dependencies.WindUI
    Tabs = dependencies.Tabs
    Config = dependencies.Config
    
    AutoPlaceSystem.CreateUI()
    return AutoPlaceSystem
end

function AutoPlaceSystem.GetUIElements()
    return {
        modeDropdown = AutoPlaceSystem.ModeDropdown,
        placeTypeDropdown = AutoPlaceSystem.PlaceTypeDropdown,
        eggDropdown = AutoPlaceSystem.EggDropdown,
        eggMutationDropdown = AutoPlaceSystem.EggMutationDropdown,
        petDropdown = AutoPlaceSystem.PetDropdown,
        petMutationDropdown = AutoPlaceSystem.PetMutationDropdown,
        minProduceInput = AutoPlaceSystem.MinProduceInput,
        autoPlaceToggle = AutoPlaceSystem.AutoPlaceToggle
    }
end

function AutoPlaceSystem.SetEnabled(enabled)
    if AutoPlaceSystem.AutoPlaceToggle then
        AutoPlaceSystem.AutoPlaceToggle:SetValue(enabled)
    end
end

function AutoPlaceSystem.IsEnabled()
    return autoPlaceEnabled
end

function AutoPlaceSystem.GetStats()
    return placementStats
end

return AutoPlaceSystem
