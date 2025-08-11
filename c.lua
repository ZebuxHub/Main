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

-- ===== Auto Place (Island_3 parts) =====
local autoPlaceEnabled = false
local autoPlaceThread = nil
local usedPartNames = {}

local function vectorCreate(x, y, z)
    local vlib = rawget(_G, "vector")
    if type(vlib) == "table" and type(vlib.create) == "function" then
        return vlib.create(x, y, z)
    end
    return Vector3.new(x, y, z)
end

local function getIsland3Parts()
    local parts = {}
    local art = workspace:FindFirstChild("Art")
    if not art then return parts end
    local island3 = art:FindFirstChild("Island_3")
    if not island3 then return parts end
    
    for _, inst in ipairs(island3:GetChildren()) do
        if inst:IsA("BasePart") and inst.Size == Vector3.new(8, 8, 8) then
            table.insert(parts, inst)
        end
    end
    table.sort(parts, function(a, b) return tostring(a.Name) < tostring(b.Name) end)
    return parts
end

local function getInventoryPetUIDs()
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

local function placeUIDAtPartCenter(uid, part)
    if not (uid and part and part:IsA("BasePart")) then return end
    local pos = part.CFrame.Position
    local dst = vectorCreate(pos.X, pos.Y, pos.Z)
    local args = {
        "Place",
        {
            DST = dst,
            ID = uid,
        }
    }
    pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
end

local function runAutoPlace()
    usedPartNames = {}
    while autoPlaceEnabled do
        local uids = getInventoryPetUIDs()
        if #uids == 0 then
            statusData.lastAction = "Auto Place: no pets in inventory"
            updateStatusParagraph()
            task.wait(0.5)
            continue
        end

        local parts = getIsland3Parts()
        if #parts == 0 then
            statusData.lastAction = "Auto Place: no 8x8x8 parts in Island_3"
            updateStatusParagraph()
            task.wait(0.5)
            continue
        end

        local available = {}
        for _, p in ipairs(parts) do
            if not usedPartNames[p.Name] then
                table.insert(available, p)
            end
        end
        if #available == 0 then
            statusData.lastAction = "Auto Place: no unused parts"
            updateStatusParagraph()
            task.wait(0.5)
            continue
        end

        local count = math.min(#uids, #available)
        for i = 1, count do
            local uid = uids[i]
            local part = available[i]
            usedPartNames[part.Name] = true
            task.spawn(function()
                placeUIDAtPartCenter(uid, part)
            end)
        end
        statusData.lastAction = "Auto Place: placed " .. tostring(count) .. " pets"
        updateStatusParagraph()
        task.wait(0.3)
    end
end

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

-- Auto Place UI toggle
Tabs.AutoTab:Toggle({
    Title = "Auto Place Pets (Island_3)",
    Desc = "Places inventory pets on Island_3 8x8x8 parts (center)",
    Value = false,
    Callback = function(state)
        autoPlaceEnabled = state
        if state and not autoPlaceThread then
            autoPlaceThread = task.spawn(function()
                runAutoPlace()
                autoPlaceThread = nil
            end)
            WindUI:Notify({ Title = "Auto Place", Content = "Started", Duration = 3 })
            statusData.lastAction = "Auto Place Started"
            updateStatusParagraph()
        elseif (not state) and autoPlaceThread then
            WindUI:Notify({ Title = "Auto Place", Content = "Stopped", Duration = 3 })
            statusData.lastAction = "Auto Place Stopped"
            updateStatusParagraph()
        end
    end
})

-- Optional helper to open the window
Window:EditOpenButton({ Title = "Build A Zoo", Icon = "monitor", Draggable = true })

-- Close callback
Window:OnClose(function()
    autoBuyEnabled = false
    autoPlaceEnabled = false
end)
