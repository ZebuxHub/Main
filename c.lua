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

-- Status tracking and UI (define early so callbacks can use them)
local statusData = {
    eggsFound = 0,
    matchingFound = 0,
    affordableFound = 0,
    lastAction = "Idle",
    lastUID = nil,
    totalBuys = 0,
    netWorth = 0,
    islandName = nil,
    seenTypes = nil,
    selectedTypes = nil,
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

-- UI state
loadEggConfig()
local eggIdList = buildEggIdList()
local selectedTypeSet = {}
local selectedTypeSetLower = {}

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
        selectedTypeSetLower = {}
        local function addTypeFor(idStr)
            -- Always include the ID itself (many games set Type directly to the config ID, e.g., "BasicEgg")
            selectedTypeSet[idStr] = true
            selectedTypeSetLower[string.lower(idStr)] = true
            -- Also include the mapped Type from config (if available and different)
            local mappedType = idToTypeMap[idStr]
            if mappedType and tostring(mappedType) ~= idStr then
                selectedTypeSet[tostring(mappedType)] = true
                selectedTypeSetLower[string.lower(tostring(mappedType))] = true
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

local function shouldBuyEggInstance(eggInstance, playerMoney)
    if not eggInstance or not eggInstance:IsA("Model") then return false, nil, nil end
    -- Read Type primarily; some games may store as EggType or Name
    local eggType = eggInstance:GetAttribute("Type")
        or eggInstance:GetAttribute("EggType")
        or eggInstance:GetAttribute("Name")
    if not eggType then return false, nil, nil end
    eggType = tostring(eggType)
    if not (selectedTypeSet[eggType] or selectedTypeSetLower[string.lower(eggType)]) then return false, nil, nil end

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

        local seen = {}
        local matching = {}
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

-- Optional helper to open the window
Window:EditOpenButton({ Title = "Build A Zoo", Icon = "monitor", Draggable = true })

-- ===== Auto Place Egg (Island_3 Farm_split_* models) =====

local function vectorCreate(x, y, z)
    local vlib = rawget(_G, "vector") or _G.vector
    if type(vlib) == "table" and type(vlib.create) == "function" then
        return vlib.create(x, y, z)
    end
    return Vector3.new(x, y, z)
end

local function getIsland3()
    local art = workspace:FindFirstChild("Art")
    if not art then return nil end
    return art:FindFirstChild("Island_3")
end

local function isFarmSplitName(nameStr)
    local n = tostring(nameStr or "")
    return string.sub(n, 1, string.len("Farm_split_")) == "Farm_split_"
end

local function findIsland3FarmSplitModels()
    local island3 = getIsland3()
    if not island3 then return {} end
    local list = {}
    for _, child in ipairs(island3:GetChildren()) do -- only direct children Models
        if child:IsA("Model") and isFarmSplitName(child.Name) then
            table.insert(list, child)
        end
    end
    return list
end

local function getModelPosition(model)
    if not model or not model:IsA("Model") then return nil end
    local cf
    if typeof(model.GetPivot) == "function" then
        cf = model:GetPivot()
    end
    if not cf then
        local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        cf = part and part.CFrame or nil
    end
    return cf and cf.Position or nil
end

local function getInventoryEggUIDs()
    local list = {}
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = pg and pg:FindFirstChild("Data")
    local eggFolder = data and data:FindFirstChild("Egg")
    if eggFolder then
        for _, ch in ipairs(eggFolder:GetChildren()) do
            table.insert(list, tostring(ch.Name))
        end
    end
    return list
end

local function placeEggUIDAt(eggUID, position)
    if not eggUID or not position then return false end
    local args = {
        "Place",
        {
            DST = vectorCreate(position.X, position.Y, position.Z),
            ID = eggUID,
        }
    }
    local ok, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    if not ok then
        warn("Failed to fire Place for UID " .. tostring(eggUID) .. ": " .. tostring(err))
        return false
    end
    return true
end

local autoPlaceEnabled = false
local autoPlaceThread = nil

Tabs.AutoTab:Toggle({
    Title = "Auto Place Egg",
    Desc = "Places PET eggs on Island_3 Farm_split_* tiles",
    Value = false,
    Callback = function(state)
        autoPlaceEnabled = state
        if state and not autoPlaceThread then
            autoPlaceThread = task.spawn(function()
                local attemptedAt = {}
                while autoPlaceEnabled do
                    local uids = getInventoryEggUIDs()
                    if #uids == 0 then
                        statusData.lastAction = "Auto Place: no eggs in PlayerGui.Data.Egg"
                        updateStatusParagraph()
                        task.wait(0.6)
                        continue
                    end

                    local tiles = findIsland3FarmSplitModels()
                    if #tiles == 0 then
                        statusData.lastAction = "Auto Place: no Farm_split_* models under Island_3"
                        updateStatusParagraph()
                        task.wait(0.6)
                        continue
                    end

                    local chosenUid
                    for _, uid in ipairs(uids) do
                        local last = attemptedAt[uid]
                        if not last or (os.clock() - last) > 2.0 then
                            chosenUid = uid
                            break
                        end
                    end
                    if not chosenUid then
                        task.wait(0.25)
                        continue
                    end

                    local targetPos, targetName
                    for _, tile in ipairs(tiles) do
                        local pos = getModelPosition(tile)
                        if pos then
                            targetPos = pos
                            targetName = tile.Name
                            break
                        end
                    end
                    if not targetPos then
                        statusData.lastAction = "Auto Place: tiles found, but no CFrame positions"
                        updateStatusParagraph()
                        task.wait(0.4)
                        continue
                    end

                    statusData.lastAction = "Auto Place: placing UID " .. tostring(chosenUid) .. " at " .. tostring(targetName)
                    updateStatusParagraph()
                    if placeEggUIDAt(chosenUid, targetPos) then
                        statusData.lastAction = string.format("Auto Place: placed %s at %s", tostring(chosenUid), tostring(targetName))
                        updateStatusParagraph()
                        attemptedAt[chosenUid] = os.clock()
                        task.wait(0.3)
                    else
                        attemptedAt[chosenUid] = os.clock()
                        task.wait(0.3)
                    end
                end
                autoPlaceThread = nil
            end)
            WindUI:Notify({ Title = "Auto Place", Content = "Started", Duration = 3 })
            statusData.lastAction = "Auto Place: started"
            updateStatusParagraph()
        elseif (not state) and autoPlaceThread then
            WindUI:Notify({ Title = "Auto Place", Content = "Stopped", Duration = 3 })
            statusData.lastAction = "Auto Place: stopped"
            updateStatusParagraph()
        end
    end
})

-- Close callback
Window:OnClose(function()
    autoBuyEnabled = false
    autoPlaceEnabled = false
end)


