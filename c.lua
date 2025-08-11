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
local function toKey(v)
    return string.lower(tostring(v))
end
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
    local target = toKey(eggType)
    for key, value in pairs(eggConfig) do
        if type(value) == "table" then
            local t = value.Type or value.Name or value.type or value.name or tostring(key)
            if toKey(t) == target then
                local price = value.Price or value.price or value.Cost or value.cost
                if type(price) == "number" then return price end
                if type(value.Base) == "table" and type(value.Base.Price) == "number" then return value.Base.Price end
            end
        else
            if toKey(key) == target then
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
            -- Always include the ID itself (in case ID equals belt Type)
            selectedTypeSet[toKey(idStr)] = true
            -- Also include the mapped Type from config (if available)
            local mappedType = idToTypeMap[idStr]
            if mappedType then
                selectedTypeSet[toKey(mappedType)] = true
            end
        end
        if type(selection) == "table" then
            for _, id in ipairs(selection) do
                addTypeFor(tostring(id))
            end
        elseif type(selection) == "string" then
            addTypeFor(tostring(selection))
        end
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
local autoPlaceEnabled = false

-- Status tracking
local statusData = {
    eggsFound = 0,
    lastAction = "Idle",
    lastEggName = nil,
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
    table.insert(lines, "Money: " .. tostring(statusData.netWorth))
    table.insert(lines, "Eggs on belt: " .. tostring(statusData.eggsFound))
    table.insert(lines, "Buys: " .. tostring(statusData.totalBuys))
    if statusData.lastEggName then
        table.insert(lines, "Last Egg: " .. tostring(statusData.lastEggName))
    end
    table.insert(lines, "Last: " .. tostring(statusData.lastAction))
    return table.concat(lines, "\n")
end

local function updateStatusParagraph()
    if statusParagraph and statusParagraph.SetDesc then
        statusParagraph:SetDesc(formatStatusDesc())
    end
end

local function resolveEggType(model)
    local t = model:GetAttribute("Type") or model:GetAttribute("EggType") or model:GetAttribute("Name")
    if t ~= nil then return tostring(t) end
    for _, d in ipairs(model:GetDescendants()) do
        local dt = d:GetAttribute("Type") or d:GetAttribute("EggType") or d:GetAttribute("Name")
        if dt ~= nil then return tostring(dt) end
    end
    return nil
end

local function shouldBuyEggInstance(eggInstance, playerMoney)
    if not eggInstance or not eggInstance:IsA("Model") then return false, nil, nil end
    local eggType = resolveEggType(eggInstance)
    if not eggType then return false, nil, nil end
    local key = toKey(eggType)
    if not selectedTypeSet[key] then return false, nil, nil end

    local price = eggInstance:GetAttribute("Price") or getEggPriceByType(eggType)
    if type(price) ~= "number" then return false, nil, nil end
    if playerMoney < price then return false, nil, nil end
    return true, eggInstance.Name, price, eggType
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

local function placeEggByUID(eggUID)
    -- forward declaration patch (actual implementation is below); filled by second definition
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
            statusData.lastAction = "Waiting for eggs to spawn"
            updateStatusParagraph()
            task.wait(0.5)
            continue
        end

        local matching = {}
        for _, child in ipairs(children) do
            local ok, uid, price, eggType = shouldBuyEggInstance(child, statusData.netWorth)
            if ok then
                table.insert(matching, { uid = uid, price = price, eggType = eggType })
            end
        end
        if #matching == 0 then
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

        if #affordable == 0 then
            local cheapest = matching[1]
            statusData.lastAction = "Waiting for money (cheapest " .. tostring(cheapest and cheapest.price or "?") .. ", NetWorth " .. tostring(statusData.netWorth) .. ")"
            updateStatusParagraph()
            task.wait(0.4)
            continue
        end

        local chosen = affordable[1]
        statusData.lastEggName = chosen.eggType
        statusData.lastAction = "Buying " .. tostring(chosen.eggType) .. " (UID " .. tostring(chosen.uid) .. ") for " .. tostring(chosen.price)
        updateStatusParagraph()
        buyEggByUID(chosen.uid)
        focusEggByUID(chosen.uid)
        statusData.totalBuys = (statusData.totalBuys or 0) + 1
        statusData.lastAction = "Bought + Focused " .. tostring(chosen.eggType)
        if autoPlaceEnabled then
            placeEggByUID(chosen.uid)
            statusData.lastAction = "Placed " .. tostring(chosen.eggType)
        end
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

-- Auto Place Egg
local function createVector3(x, y, z)
    local vlib = rawget(_G, "vector")
    if type(vlib) == "table" and type(vlib.create) == "function" then
        return vlib.create(x, y, z)
    end
    return Vector3.new(x, y, z)
end

local TARGET_COLOR = Color3.fromRGB(145, 98, 44)
local function colorsClose(a, b, tol)
    tol = tol or 0.01
    return math.abs(a.R - b.R) <= tol and math.abs(a.G - b.G) <= tol and math.abs(a.B - b.B) <= tol
end

local function findPlacementPart(islandName)
    local art = workspace:FindFirstChild("Art")
    if not art then return nil end
    local island = art:FindFirstChild(islandName or "")
    if not island then return nil end
    for _, inst in ipairs(island:GetDescendants()) do
        if inst:IsA("BasePart") then
            local col = inst.Color or (inst.BrickColor and inst.BrickColor.Color)
            if col and colorsClose(col, TARGET_COLOR, 0.02) then
                return inst
            end
        end
    end
    return nil
end

local function getGridVectorFromPart(part)
    if not part then return nil end
    local gx = part:GetAttribute("GridX") or part:GetAttribute("Grid X") or part:GetAttribute("gridX") or part:GetAttribute("gridx")
    local gy = part:GetAttribute("GridY") or part:GetAttribute("Grid Y") or part:GetAttribute("gridY") or part:GetAttribute("gridy")
    local gz = part:GetAttribute("GridZ") or part:GetAttribute("Grid Z") or part:GetAttribute("gridZ") or part:GetAttribute("gridz")
    if type(gx) == "number" and type(gy) == "number" and type(gz) == "number" then
        return createVector3(gx, gy, gz)
    end
    return nil
end

function placeEggByUID(eggUID)
    local islandName = getAssignedIslandName()
    if not islandName then return end
    local part = findPlacementPart(islandName)
    if not part then
        statusData.lastAction = "No placement part found"
        updateStatusParagraph()
        return
    end
    local dst = getGridVectorFromPart(part)
    if not dst then
        local p = part.Position
        dst = createVector3(p.X, p.Y, p.Z)
    end
    local args = {
        "Place",
        {
            DST = dst,
            ID = eggUID,
        }
    }
    local ok, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    if not ok then
        warn("Failed to fire Place for UID " .. tostring(eggUID) .. ": " .. tostring(err))
    end
end

Tabs.AutoTab:Toggle({
    Title = "Auto Place Egg",
    Desc = "Place bought eggs on brown tiles in your island",
    Value = false,
    Callback = function(state)
        autoPlaceEnabled = state
        statusData.lastAction = state and "Auto Place enabled" or "Auto Place disabled"
        updateStatusParagraph()
    end
})

-- Optional helper to open the window
Window:EditOpenButton({ Title = "Build A Zoo", Icon = "monitor", Draggable = true })

-- Close callback
Window:OnClose(function()
    autoBuyEnabled = false
end)


