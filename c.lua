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

local function buildEggIdList()
    local ids = {}
    for id, _ in pairs(eggConfig) do
        table.insert(ids, tostring(id))
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
local selectedEggIdSet = {}

local eggDropdown
eggDropdown = Tabs.AutoTab:Dropdown({
    Title = "Egg IDs",
    Desc = "Select egg types to auto-buy (from ResEgg)",
    Values = eggIdList,
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(selection)
        selectedEggIdSet = {}
        if type(selection) == "table" then
            -- Multi selection
            for _, id in ipairs(selection) do
                selectedEggIdSet[tostring(id)] = true
            end
        elseif type(selection) == "string" then
            selectedEggIdSet[tostring(selection)] = true
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

local function shouldBuyEggInstance(eggInstance, playerMoney)
    if not eggInstance then return false, nil, nil end
    local eggType = eggInstance:GetAttribute("Type") or eggInstance:GetAttribute("EggType") or eggInstance:GetAttribute("Name")
    if not eggType then return false, nil, nil end
    eggType = tostring(eggType)
    if not selectedEggIdSet[eggType] then return false, nil, nil end

    local price = eggInstance:GetAttribute("Price") or getEggPriceById(eggType)
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

local function runAutoBuy()
    while autoBuyEnabled do
        local islandName = getAssignedIslandName()
        local beltFolder = getIslandBeltFolder(islandName)
        if beltFolder and #beltFolder:GetChildren() > 0 then
            local playerMoney = getPlayerNetWorth()
            local affordable = {}
            for _, child in ipairs(beltFolder:GetChildren()) do
                local ok, uid, price = shouldBuyEggInstance(child, playerMoney)
                if ok then
                    table.insert(affordable, { uid = uid, price = price })
                end
            end
            table.sort(affordable, function(a, b)
                return (a.price or math.huge) < (b.price or math.huge)
            end)
            if #affordable > 0 then
                buyEggByUID(affordable[1].uid)
                task.wait(0.25)
            else
                task.wait(0.4)
            end
        else
            task.wait(0.6)
        end
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
        elseif (not state) and autoBuyThread then
            WindUI:Notify({ Title = "Auto Buy", Content = "Stopped", Duration = 3 })
        end
    end
})

-- Optional helper to open the window
Window:EditOpenButton({ Title = "Build A Zoo", Icon = "monitor", Draggable = true })

-- Close callback
Window:OnClose(function()
    autoBuyEnabled = false
end)


