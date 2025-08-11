-- Build A Zoo: Auto Buy Egg using WindUI

-- Load WindUI library (same as in Windui.lua)
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Window
local Window = WindUI:CreateWindow({
    Title = "Build A Zoo",
    Icon = "app-window-mac",
    IconThemed = true,
    Author = "Zebux",
    Folder = "Zebux",
    Size = UDim2.fromOffset(520, 360),
    Transparent = true,
    Theme = "Dark",
    -- No keysystem
})

local Tabs = {}
Tabs.MainSection = Window:Section({ Title = "Automation", Opened = true })
Tabs.AutoTab = Tabs.MainSection:Tab({ Title = "Auto Eggs", Icon = "egg" })
Tabs.PlaceTab = Tabs.MainSection:Tab({ Title = "Auto Place", Icon = "map-pin" })

-- Egg config loader
local eggConfig = {}

local function loadEggConfig()
    local ok, cfg = pcall(function()
        local cfgFolder = ReplicatedStorage:WaitForChild("Config")
        local module = cfgFolder:WaitForChild("ResEgg")
        return require(module)
    end)
    if ok and type(cfg) == "table" then
        eggConfig = cfg
    else
        eggConfig = {}
    end
end

local idToTypeMap = {}
local function getTypeFromConfig(key, val)
    if type(val) == "table" then
        local t = val.Type or val.Name or val.type or val.name
        if t ~= nil then return tostring(t) end
    end
    return tostring(key)
end

local function buildEggIdList()
    idToTypeMap = {}
    local ids = {}
    for id, val in pairs(eggConfig) do
        local idStr = tostring(id)
        table.insert(ids, idStr)
        idToTypeMap[idStr] = getTypeFromConfig(id, val)
    end
    table.sort(ids)
    return ids
end

local function getEggPriceById(eggId)
    local entry = eggConfig[eggId] or eggConfig[tonumber(eggId)]
    if entry == nil then
        for key, value in pairs(eggConfig) do
            if tostring(key) == tostring(eggId) then
                entry = value
                break
            end
            if type(value) == "table" then
                if value.Id == eggId or tostring(value.Id) == tostring(eggId) or value.Name == eggId then
                    entry = value
                    break
                end
            end
        end
    end
    if type(entry) == "table" then
        local price = entry.Price or entry.price or entry.Cost or entry.cost
        if type(price) == "number" then return price end
        if type(entry.Base) == "table" and type(entry.Base.Price) == "number" then return entry.Base.Price end
    end
    return nil
end

local function getEggPriceByType(eggType)
    local target = tostring(eggType)
    for key, value in pairs(eggConfig) do
        if type(value) == "table" then
            local t = value.Type or value.Name or value.type or value.name or tostring(key)
            if tostring(t) == target then
                local price = value.Price or value.price or value.Cost or value.cost
                if type(price) == "number" then return price end
                if type(value.Base) == "table" and type(value.Base.Price) == "number" then return value.Base.Price end
            end
        else
            if tostring(key) == target then
                -- primitive mapping, try id-based
                local price = getEggPriceById(key)
                if type(price) == "number" then return price end
            end
        end
    end
    return nil
end

-- Player helpers
local function getAssignedIslandName()
    if not LocalPlayer then return nil end
    return LocalPlayer:GetAttribute("AssignedIslandName")
end

local function getPlayerNetWorth()
    if not LocalPlayer then return 0 end
    local attrValue = LocalPlayer:GetAttribute("NetWorth")
    if type(attrValue) == "number" then return attrValue end
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local netWorthValue = leaderstats:FindFirstChild("NetWorth")
        if netWorthValue and type(netWorthValue.Value) == "number" then
            return netWorthValue.Value
        end
    end
    return 0
end

-- World helpers
local function getIslandBeltFolder(islandName)
    if type(islandName) ~= "string" or islandName == "" then return nil end
    local art = workspace:FindFirstChild("Art")
    if not art then return nil end
    local island = art:FindFirstChild(islandName)
    if not island then return nil end
    local env = island:FindFirstChild("ENV")
    if not env then return nil end
    local conveyor = env:FindFirstChild("Conveyor")
    if not conveyor then return nil end
    local conveyor1 = conveyor:FindFirstChild("Conveyor1")
    if not conveyor1 then return nil end
    local belt = conveyor1:FindFirstChild("Belt")
    return belt
end

-- Auto Place helpers
local function getIslandNumberFromName(islandName)
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

local function getFarmParts(islandNumber)
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
    return farmParts
end

local function getPetUID()
    if not LocalPlayer then return nil end
    
    -- Wait for PlayerGui to exist
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        -- Try to wait for it briefly
        playerGui = LocalPlayer:WaitForChild("PlayerGui", 2)
        if not playerGui then return nil end
    end
    
    -- Wait for Data folder to exist
    local data = playerGui:FindFirstChild("Data")
    if not data then
        data = playerGui:WaitForChild("Data", 2)
        if not data then return nil end
    end
    
    -- Wait for Egg object to exist
    local egg = data:FindFirstChild("Egg")
    if not egg then
        egg = data:WaitForChild("Egg", 2)
        if not egg then return nil end
    end
    
    -- The PET UID is the NAME of the egg object, not its Value
    local eggName = egg.Name
    if not eggName or eggName == "" then
        return nil
    end
    
    return eggName
end

-- Enhanced pet validation based on the Pet module
local function validatePetUID(petUID)
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
local function getPetInfo(petUID)
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

local function placePetAtPart(farmPart, petUID)
    if not farmPart or not petUID then return false end
    
    -- Enhanced validation based on Pet module insights
    if not farmPart:IsA("BasePart") then return false end
    
    local isValid, validationMsg = validatePetUID(petUID)
    if not isValid then
        warn("Pet validation failed: " .. validationMsg)
        return false
    end
    
    local position = farmPart.Position
    local args = {
        "Place",
        {
            DST = vector.create(position.X, position.Y, position.Z),
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
        warn("Failed to fire Place for PET UID " .. tostring(petUID) .. " at " .. tostring(position) .. ": " .. tostring(err))
        return false
    end
    
    return true
end

-- UI state
loadEggConfig()
local eggIdList = buildEggIdList()
local selectedTypeSet = {}

local eggDropdown
eggDropdown = Tabs.AutoTab:Dropdown({
    Title = "Egg IDs",
    Desc = "Select IDs; compared by Type attribute on belt models",
    Values = eggIdList,
    Value = {},
    Multi = true,
    AllowNone = true,
            Callback = function(selection)
            selectedTypeSet = {}
            local function addTypeFor(idStr)
                -- Always include the ID itself (many games set Type directly to the config ID, e.g., "BasicEgg")
                selectedTypeSet[idStr] = true
                -- Also include the mapped Type from config (if available and different)
                local mappedType = idToTypeMap[idStr]
                if mappedType and tostring(mappedType) ~= idStr then
                    selectedTypeSet[tostring(mappedType)] = true
                end
            end
            if type(selection) == "table" then
                for _, id in ipairs(selection) do
                    addTypeFor(tostring(id))
                end
            elseif type(selection) == "string" then
                addTypeFor(tostring(selection))
            end
            -- update selected types display
            local keys = {}
            for k in pairs(selectedTypeSet) do table.insert(keys, k) end
            table.sort(keys)
            statusData.selectedTypes = table.concat(keys, ", ")
            updateStatusParagraph()
        end
})

Tabs.AutoTab:Button({
    Title = "Refresh Egg List",
    Callback = function()
        loadEggConfig()
        eggIdList = buildEggIdList()
        if eggDropdown and eggDropdown.Refresh then
            eggDropdown:Refresh(eggIdList)
        end
    end
})

local autoBuyEnabled = false
local autoBuyThread = nil

-- Status tracking
local statusData = {
    eggsFound = 0,
    matchingFound = 0,
    affordableFound = 0,
    lastAction = "Idle",
    lastUID = nil,
    totalBuys = 0,
    netWorth = 0,
    islandName = nil,
}

Tabs.AutoTab:Section({ Title = "Status", Icon = "info" })
local statusParagraph = Tabs.AutoTab:Paragraph({
    Title = "Auto Buy Status",
    Desc = "Waiting...",
    Image = "activity",
    ImageSize = 22,
})

local function formatStatusDesc()
    local lines = {}
    table.insert(lines, "Island: " .. tostring(statusData.islandName or "?"))
    table.insert(lines, "NetWorth: " .. tostring(statusData.netWorth))
    table.insert(lines, "Eggs on belt: " .. tostring(statusData.eggsFound))
    table.insert(lines, "Matching: " .. tostring(statusData.matchingFound) .. ", Affordable: " .. tostring(statusData.affordableFound))
    table.insert(lines, "Buys: " .. tostring(statusData.totalBuys))
    if statusData.selectedTypes then
        table.insert(lines, "Selected: " .. statusData.selectedTypes)
    end
    if statusData.seenTypes then
        table.insert(lines, "Seen: " .. statusData.seenTypes)
    end
    if statusData.lastUID then
        table.insert(lines, "Last UID: " .. tostring(statusData.lastUID))
    end
    table.insert(lines, "Last: " .. tostring(statusData.lastAction))
    return table.concat(lines, "\n")
end

local function updateStatusParagraph()
    if statusParagraph and statusParagraph.SetDesc then
        statusParagraph:SetDesc(formatStatusDesc())
    end
end

local function shouldBuyEggInstance(eggInstance, playerMoney)
    if not eggInstance or not eggInstance:IsA("Model") then return false, nil, nil end
    -- Read Type primarily; some games may store as EggType or Name
    local eggType = eggInstance:GetAttribute("Type")
        or eggInstance:GetAttribute("EggType")
        or eggInstance:GetAttribute("Name")
    if not eggType then return false, nil, nil end
    eggType = tostring(eggType)
    if not selectedTypeSet[eggType] then return false, nil, nil end

    local price = eggInstance:GetAttribute("Price") or getEggPriceByType(eggType)
    if type(price) ~= "number" then return false, nil, nil end
    if playerMoney < price then return false, nil, nil end
    return true, eggInstance.Name, price
end

local function buyEggByUID(eggUID)
    local args = {
        "BuyEgg",
        eggUID
    }
    local ok, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    if not ok then
        warn("Failed to fire BuyEgg for UID " .. tostring(eggUID) .. ": " .. tostring(err))
    end
end

local function focusEggByUID(eggUID)
    local args = {
        "Focus",
        eggUID
    }
    local ok, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    if not ok then
        warn("Failed to fire Focus for UID " .. tostring(eggUID) .. ": " .. tostring(err))
    end
end

local function runAutoBuy()
    while autoBuyEnabled do
        local islandName = getAssignedIslandName()
        statusData.islandName = islandName

        if not islandName or islandName == "" then
            statusData.lastAction = "Waiting for island assignment (AssignedIslandName)"
            updateStatusParagraph()
            task.wait(0.6)
            continue
        end

        local beltFolder = getIslandBeltFolder(islandName)
        if not beltFolder then
            statusData.eggsFound = 0
            statusData.matchingFound = 0
            statusData.affordableFound = 0
            statusData.lastAction = "Waiting for belt on island"
            updateStatusParagraph()
            task.wait(0.6)
            continue
        end

        local allChildren = beltFolder:GetChildren()
        local children = {}
        for _, inst in ipairs(allChildren) do
            if inst:IsA("Model") then table.insert(children, inst) end
        end
        statusData.eggsFound = #children
        statusData.netWorth = getPlayerNetWorth()

        if statusData.eggsFound == 0 then
            statusData.matchingFound = 0
            statusData.affordableFound = 0
            statusData.lastAction = "Waiting for eggs to spawn"
            updateStatusParagraph()
            task.wait(0.5)
            continue
        end

        local matching = {}
        local seen = {}
        for _, child in ipairs(children) do
            local ok, uid, price = shouldBuyEggInstance(child, statusData.netWorth)
            local t = child:GetAttribute("Type") or child:GetAttribute("EggType") or child:GetAttribute("Name")
            if t ~= nil then seen[tostring(t)] = true end
            if ok then
                table.insert(matching, { uid = uid, price = price })
            end
        end
        do
            local list = {}
            for k in pairs(seen) do table.insert(list, k) end
            table.sort(list)
            statusData.seenTypes = (#list > 0) and table.concat(list, ", ") or nil
        end
        statusData.matchingFound = #matching

        if statusData.matchingFound == 0 then
            statusData.affordableFound = 0
            statusData.lastAction = "No matching eggs on belt (adjust dropdown)"
            updateStatusParagraph()
            task.wait(0.5)
            continue
        end

        table.sort(matching, function(a, b)
            return (a.price or math.huge) < (b.price or math.huge)
        end)

        local affordable = {}
        for _, item in ipairs(matching) do
            if statusData.netWorth >= (item.price or math.huge) then
                table.insert(affordable, item)
            end
        end
        statusData.affordableFound = #affordable

        if statusData.affordableFound == 0 then
            local cheapest = matching[1]
            statusData.lastAction = "Waiting for money (cheapest " .. tostring(cheapest and cheapest.price or "?") .. ", NetWorth " .. tostring(statusData.netWorth) .. ")"
            updateStatusParagraph()
            task.wait(0.4)
            continue
        end

        local chosen = affordable[1]
        statusData.lastUID = chosen.uid
        statusData.lastAction = "Buying UID " .. tostring(chosen.uid) .. " for " .. tostring(chosen.price)
        updateStatusParagraph()
        buyEggByUID(chosen.uid)
        focusEggByUID(chosen.uid)
        statusData.totalBuys = (statusData.totalBuys or 0) + 1
        statusData.lastAction = "Bought + Focused UID " .. tostring(chosen.uid)
        updateStatusParagraph()
        task.wait(0.25)
    end
end

Tabs.AutoTab:Toggle({
    Title = "Auto Buy Egg",
    Desc = "Buys eggs from your island conveyor that match the selected egg IDs",
    Value = false,
    Callback = function(state)
        autoBuyEnabled = state
        if state and not autoBuyThread then
            autoBuyThread = task.spawn(function()
                runAutoBuy()
                autoBuyThread = nil
            end)
            WindUI:Notify({ Title = "Auto Buy", Content = "Started", Duration = 3 })
            statusData.lastAction = "Started"
            updateStatusParagraph()
        elseif (not state) and autoBuyThread then
            WindUI:Notify({ Title = "Auto Buy", Content = "Stopped", Duration = 3 })
            statusData.lastAction = "Stopped"
            updateStatusParagraph()
        end
    end
})

-- Auto Place functionality
local autoPlaceEnabled = false
local autoPlaceThread = nil

-- Auto Place status tracking
local placeStatusData = {
    islandName = nil,
    islandNumber = nil,
    farmPartsFound = 0,
    petUID = nil,
    petInfo = nil,
    totalPlaces = 0,
    lastAction = "Idle",
    lastPosition = nil,
    validationStatus = nil,
}

Tabs.PlaceTab:Section({ Title = "Status", Icon = "info" })
local placeStatusParagraph = Tabs.PlaceTab:Paragraph({
    Title = "Auto Place Status",
    Desc = "Waiting...",
    Image = "activity",
    ImageSize = 22,
})

local function formatPlaceStatusDesc()
    local lines = {}
    table.insert(lines, "Island: " .. tostring(placeStatusData.islandName or "?"))
    table.insert(lines, "Island Number: " .. tostring(placeStatusData.islandNumber or "?"))
    table.insert(lines, "Farm Parts: " .. tostring(placeStatusData.farmPartsFound))
    table.insert(lines, "PET UID: " .. tostring(placeStatusData.petUID or "?"))
    
    -- Enhanced pet information display
    if placeStatusData.petInfo then
        if placeStatusData.petInfo.Type then
            table.insert(lines, "Pet Type: " .. tostring(placeStatusData.petInfo.Type))
        end
        if placeStatusData.petInfo.Rarity then
            table.insert(lines, "Rarity: " .. tostring(placeStatusData.petInfo.Rarity))
        end
    end
    
    table.insert(lines, "Places: " .. tostring(placeStatusData.totalPlaces))
    if placeStatusData.lastPosition then
        table.insert(lines, "Last Position: " .. tostring(placeStatusData.lastPosition))
    end
    if placeStatusData.validationStatus then
        table.insert(lines, "Validation: " .. tostring(placeStatusData.validationStatus))
    end
    table.insert(lines, "Last: " .. tostring(placeStatusData.lastAction))
    return table.concat(lines, "\n")
end

local function updatePlaceStatusParagraph()
    if placeStatusParagraph and placeStatusParagraph.SetDesc then
        placeStatusParagraph:SetDesc(formatPlaceStatusDesc())
    end
end

local function runAutoPlace()
    while autoPlaceEnabled do
        local ok, err = pcall(function()
            local islandName = getAssignedIslandName()
            placeStatusData.islandName = islandName
            
            if not islandName or islandName == "" then
                placeStatusData.lastAction = "Waiting for island assignment"
                updatePlaceStatusParagraph()
                task.wait(0.6)
                return
            end
            
            local islandNumber = getIslandNumberFromName(islandName)
            placeStatusData.islandNumber = islandNumber
            
            if not islandNumber then
                placeStatusData.lastAction = "Could not determine island number from: " .. tostring(islandName)
                updatePlaceStatusParagraph()
                task.wait(0.6)
                return
            end
            
            local farmParts = getFarmParts(islandNumber)
            placeStatusData.farmPartsFound = #farmParts
            
            if placeStatusData.farmPartsFound == 0 then
                placeStatusData.lastAction = "No farm parts found on Island_" .. tostring(islandNumber)
                updatePlaceStatusParagraph()
                task.wait(0.6)
                return
            end
            
            local petUID = getPetUID()
            placeStatusData.petUID = petUID
            
                    if not petUID then
            placeStatusData.lastAction = "No PET UID found in PlayerGui.Data.Egg.Name"
            placeStatusData.validationStatus = "No PET UID"
            updatePlaceStatusParagraph()
            task.wait(0.6)
            return
        end
            
            -- Enhanced pet validation and info gathering
            local isValid, validationMsg = validatePetUID(petUID)
            placeStatusData.validationStatus = validationMsg
            
            if not isValid then
                placeStatusData.lastAction = "PET UID validation failed: " .. validationMsg
                updatePlaceStatusParagraph()
                task.wait(0.6)
                return
            end
            
            -- Get pet information for better status display
            placeStatusData.petInfo = getPetInfo(petUID)
            
            -- Place pet at a random farm part
            local randomPart = farmParts[math.random(1, #farmParts)]
            local position = randomPart.Position
            placeStatusData.lastPosition = string.format("(%.1f, %.1f, %.1f)", position.X, position.Y, position.Z)
            placeStatusData.lastAction = "Placing PET " .. tostring(petUID) .. " at " .. placeStatusData.lastPosition
            updatePlaceStatusParagraph()
            
            local success = placePetAtPart(randomPart, petUID)
            if success then
                placeStatusData.totalPlaces = (placeStatusData.totalPlaces or 0) + 1
                placeStatusData.lastAction = "Successfully placed PET " .. tostring(petUID)
            else
                placeStatusData.lastAction = "Failed to place PET " .. tostring(petUID)
            end
            updatePlaceStatusParagraph()
            
            task.wait(0.5)
        end)
        
        if not ok then
            warn("Auto Place error: " .. tostring(err))
            placeStatusData.lastAction = "Error: " .. tostring(err)
            updatePlaceStatusParagraph()
            task.wait(1) -- Wait longer on error
        end
    end
end

Tabs.PlaceTab:Toggle({
    Title = "Auto Place",
    Desc = "Automatically places pets from your inventory at farm locations",
    Value = false,
    Callback = function(state)
        autoPlaceEnabled = state
        if state and not autoPlaceThread then
            autoPlaceThread = task.spawn(function()
                runAutoPlace()
                autoPlaceThread = nil
            end)
            WindUI:Notify({ Title = "Auto Place", Content = "Started", Duration = 3 })
            placeStatusData.lastAction = "Started"
            updatePlaceStatusParagraph()
        elseif (not state) and autoPlaceThread then
            WindUI:Notify({ Title = "Auto Place", Content = "Stopped", Duration = 3 })
            placeStatusData.lastAction = "Stopped"
            updatePlaceStatusParagraph()
        end
    end
})

-- Manual place button for testing
Tabs.PlaceTab:Button({
    Title = "Place Pet Now",
    Desc = "Manually place a pet at a random farm location",
    Callback = function()
        local islandName = getAssignedIslandName()
        if not islandName then
            WindUI:Notify({ Title = "Error", Content = "No island assigned", Duration = 3 })
            return
        end
        
        local islandNumber = getIslandNumberFromName(islandName)
        if not islandNumber then
            WindUI:Notify({ Title = "Error", Content = "Could not determine island number", Duration = 3 })
            return
        end
        
        local farmParts = getFarmParts(islandNumber)
        if #farmParts == 0 then
            WindUI:Notify({ Title = "Error", Content = "No farm parts found", Duration = 3 })
            return
        end
        
        local petUID = getPetUID()
        if not petUID then
            WindUI:Notify({ Title = "Error", Content = "No PET UID found in PlayerGui.Data.Egg.Name", Duration = 3 })
            return
        end
        
        -- Enhanced validation
        local isValid, validationMsg = validatePetUID(petUID)
        if not isValid then
            WindUI:Notify({ Title = "Error", Content = "PET UID validation failed: " .. validationMsg, Duration = 3 })
            return
        end
        
        local randomPart = farmParts[math.random(1, #farmParts)]
        local success = placePetAtPart(randomPart, petUID)
        
        if success then
            WindUI:Notify({ Title = "Success", Content = "Pet placed at farm location", Duration = 3 })
            placeStatusData.totalPlaces = (placeStatusData.totalPlaces or 0) + 1
            placeStatusData.lastAction = "Manual place successful"
            updatePlaceStatusParagraph()
        else
            WindUI:Notify({ Title = "Error", Content = "Failed to place pet", Duration = 3 })
            placeStatusData.lastAction = "Manual place failed"
            updatePlaceStatusParagraph()
        end
    end
})

-- Pet validation test button
Tabs.PlaceTab:Button({
    Title = "Test Pet Validation",
    Desc = "Check if current PET UID is valid",
    Callback = function()
        local petUID = getPetUID()
        if not petUID then
            WindUI:Notify({ Title = "Error", Content = "No PET UID found in PlayerGui.Data.Egg.Name", Duration = 3 })
            return
        end
        
        local isValid, validationMsg = validatePetUID(petUID)
        local petInfo = getPetInfo(petUID)
        
        local message = "PET UID: " .. tostring(petUID) .. "\n"
        message = message .. "Validation: " .. validationMsg .. "\n"
        if petInfo and petInfo.Type then
            message = message .. "Pet Type: " .. tostring(petInfo.Type)
        end
        
        WindUI:Notify({ 
            Title = isValid and "Valid PET" or "Invalid PET", 
            Content = message, 
            Duration = 5 
        })
        
        -- Update status display
        placeStatusData.petUID = petUID
        placeStatusData.petInfo = petInfo
        placeStatusData.validationStatus = validationMsg
        updatePlaceStatusParagraph()
    end
})

-- Optional helper to open the window
Window:EditOpenButton({ Title = "Build A Zoo", Icon = "monitor", Draggable = true })

-- Close callback
Window:OnClose(function()
    autoBuyEnabled = false
    autoPlaceEnabled = false
end)


