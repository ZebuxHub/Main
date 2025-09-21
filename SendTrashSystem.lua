-- SendTrashSystem.lua - Auto Trade/Send System for Build A Zoo
-- Lua 5.1 Compatible

local SendTrashSystem = {}

-- Hardcoded data from game
local EggData = {
    BasicEgg = { Name = "Basic Egg", Price = "100", Icon = "rbxassetid://129248801621928", Rarity = 1 },
    RareEgg = { Name = "Rare Egg", Price = "500", Icon = "rbxassetid://71012831091414", Rarity = 2 },
    SuperRareEgg = { Name = "Super Rare Egg", Price = "2,500", Icon = "rbxassetid://93845452154351", Rarity = 2 },
    EpicEgg = { Name = "Epic Egg", Price = "15,000", Icon = "rbxassetid://116395645531721", Rarity = 2 },
    LegendEgg = { Name = "Legend Egg", Price = "100,000", Icon = "rbxassetid://90834918351014", Rarity = 3 },
    PrismaticEgg = { Name = "Prismatic Egg", Price = "1,000,000", Icon = "rbxassetid://79960683434582", Rarity = 4 },
    HyperEgg = { Name = "Hyper Egg", Price = "2,500,000", Icon = "rbxassetid://104958288296273", Rarity = 4 },
    VoidEgg = { Name = "Void Egg", Price = "24,000,000", Icon = "rbxassetid://122396162708984", Rarity = 5 },
    BowserEgg = { Name = "Bowser Egg", Price = "130,000,000", Icon = "rbxassetid://71500536051510", Rarity = 5 },
    DemonEgg = { Name = "Demon Egg", Price = "400,000,000", Icon = "rbxassetid://126412407639969", Rarity = 5 },
    CornEgg = { Name = "Corn Egg", Price = "1,000,000,000", Icon = "rbxassetid://94739512852461", Rarity = 5 },
    BoneDragonEgg = { Name = "Bone Dragon Egg", Price = "2,000,000,000", Icon = "rbxassetid://83209913424562", Rarity = 5 },
    UltraEgg = { Name = "Ultra Egg", Price = "10,000,000,000", Icon = "rbxassetid://83909590718799", Rarity = 6 },
    DinoEgg = { Name = "Dino Egg", Price = "10,000,000,000", Icon = "rbxassetid://80783528632315", Rarity = 6 },
    FlyEgg = { Name = "Fly Egg", Price = "999,999,999,999", Icon = "rbxassetid://109240587278187", Rarity = 6 },
    UnicornEgg = { Name = "Unicorn Egg", Price = "40,000,000,000", Icon = "rbxassetid://123427249205445", Rarity = 6 },
    AncientEgg = { Name = "Ancient Egg", Price = "999,999,999,999", Icon = "rbxassetid://113910587565739", Rarity = 6 },
    UnicornProEgg = { Name = "Unicorn Pro Egg", Price = "50,000,000,000", Icon = "rbxassetid://140138063696377", Rarity = 6 },
    SnowbunnyEgg = { Name = "Snowbunny Egg", Price = "1,500,000", Icon = "rbxassetid://136223941487914", Rarity = 3, IsNew = true },
    DarkGoatyEgg = { Name = "Dark Goaty Egg", Price = "100,000,000", Icon = "rbxassetid://95956060312947", Rarity = 4, IsNew = true },
    RhinoRockEgg = { Name = "Rhino Rock Egg", Price = "3,000,000,000", Icon = "rbxassetid://131221831910623", Rarity = 5, IsNew = true },
    SaberCubEgg = { Name = "Saber Cub Egg", Price = "40,000,000,000", Icon = "rbxassetid://111953502835346", Rarity = 6, IsNew = true },
    GeneralKongEgg = { Name = "General Kong Egg", Price = "80,000,000,000", Icon = "rbxassetid://106836613554535", Rarity = 6, IsNew = true },
    PegasusEgg = { Name = "Pegasus Egg", Price = "999,999,999,999", Icon = "rbxassetid://83004379343725", Rarity = 6, IsNew = true }
}

local FruitData = {
    Strawberry = { Name = "Strawberry", Price = "5,000", Icon = "🍓", Rarity = 1 },
    Blueberry = { Name = "Blueberry", Price = "20,000", Icon = "🔵", Rarity = 1 },
    Watermelon = { Name = "Watermelon", Price = "80,000", Icon = "🍉", Rarity = 2 },
    Apple = { Name = "Apple", Price = "400,000", Icon = "🍎", Rarity = 2 },
    Orange = { Name = "Orange", Price = "1,200,000", Icon = "🍊", Rarity = 3 },
    Corn = { Name = "Corn", Price = "3,500,000", Icon = "🌽", Rarity = 3 },
    Banana = { Name = "Banana", Price = "12,000,000", Icon = "🍌", Rarity = 4 },
    Grape = { Name = "Grape", Price = "50,000,000", Icon = "🍇", Rarity = 4 },
    Pear = { Name = "Pear", Price = "200,000,000", Icon = "🍐", Rarity = 5 },
    Pineapple = { Name = "Pineapple", Price = "600,000,000", Icon = "🍍", Rarity = 5 },
    GoldMango = { Name = "Gold Mango", Price = "2,000,000,000", Icon = "🥭", Rarity = 6 },
    BloodstoneCycad = { Name = "Bloodstone Cycad", Price = "8,000,000,000", Icon = "🌿", Rarity = 6 },
    ColossalPinecone = { Name = "Colossal Pinecone", Price = "40,000,000,000", Icon = "🌲", Rarity = 6 },
    VoltGinkgo = { Name = "Volt Ginkgo", Price = "80,000,000,000", Icon = "⚡", Rarity = 6 },
    DeepseaPearlFruit = { Name = "DeepseaPearlFruit", Price = "40,000,000,000", Icon = "💠", Rarity = 6 },
    Durian = { Name = "Durian", Price = "80,000,000,000", Icon = "🥥", Rarity = 6, IsNew = true },
    DragonFruit = { Name = "Dragon Fruit", Price = "1,500,000,000", Icon = "🐲", Rarity = 6, IsNew = true }
}

local HardcodedPetTypes = {
    "Capy1", "Capy2", "Pig", "Capy3", "Dog", "AngelFish", "Cat", "CapyL1", "Cow", "CapyL2", 
    "Sheep", "CapyL3", "Horse", "Zebra", "Bighead", "Giraffe", "Hippo", "Elephant", "Rabbit", 
    "Mouse", "Butterflyfish", "Ankylosaurus", "Needlefish", "Wolverine", "Tiger", "Fox", "Hairtail", 
    "Panda", "Tuna", "Catfish", "Toucan", "Bee", "Snake", "Butterfly", "Tigerfish", "Okapi", 
    "Panther", "Penguin", "Velociraptor", "Stegosaurus", "Seaturtle", "Bear", "Flounder", "Lion", 
    "Lionfish", "Rhino", "Kangroo", "Gorilla", "Alligator", "Ostrich", "Triceratops", "Pachycephalosaur", 
    "Sawfish", "Pterosaur", "ElectricEel", "Wolf", "Rex", "Dolphin", "Dragon", "Baldeagle", "Shark", 
    "Griffin", "Brontosaurus", "Anglerfish", "Plesiosaur", "Alpaca", "Spinosaurus", "Manta", "Unicorn", 
    "Phoenix", "Toothless", "Tyrannosaurus", "Mosasaur", "Octopus", "Killerwhale", "Peacock"
}

local HardcodedMutations = {
    "Golden", "Diamond", "Electric", "Fire", "Dino", "Snow"
}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- UI Variables
local WindUI
local Window
local Config
local trashToggle
local targetPlayerDropdown
local sendModeDropdown
local petMinSpeedInput
local petMaxSpeedInput
local statusParagraph
local keepTrackingToggle

-- Custom UI Variables
local customUI = {
    screenGui = nil,
    mainFrame = nil,
    eggSelectionFrame = nil,
    fruitSelectionFrame = nil,
    currentPage = "eggs", -- "eggs", "fruits", "pets"
    selectedItems = {},
    sendAmounts = {} -- How much of each item to send
}

-- State variables
local trashEnabled = false
local actionCounter = 0
local selectedTargetName = "Random Player"
local selectedSendTypes = {"Pets"} -- Multi-select: "Pets", "Eggs", "Fruits"
local petMinSpeed, petMaxSpeed = 0, 999999999
local stopRequested = false
local keepTrackingWhenEmpty = false

-- Random target state (for "Random Player" mode)
local randomTargetState = { rrIndex = 1 }

-- Blacklist & sticky removed per request; using round-robin random dispatch

-- Inventory Cache System (like auto place)
local inventoryCache = {
    pets = {},
    eggs = {},
    fruits = {},
    lastUpdateTime = 0,
    updateInterval = 0.5, -- Update every 0.5 seconds
    unknownCount = 0 -- Track items that couldn't load properly
}

-- Fruit name normalization helpers
local function normalizeFruitName(name)
    if type(name) ~= "string" then return "" end
    local lowered = string.lower(name)
    lowered = lowered:gsub("[%s_%-%./]", "")
    return lowered
end

-- Build canonical name map from FruitData
local function buildFruitCanonical()
    local map = {}
    for id, item in pairs(FruitData) do
        local display = item.Name or id
        map[normalizeFruitName(id)] = display
        map[normalizeFruitName(display)] = display
    end
    return map
end
local FRUIT_CANONICAL = buildFruitCanonical()

-- Get player's fruit inventory
local function getPlayerFruitInventory()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return {} end

    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return {} end

    local data = playerGui:FindFirstChild("Data")
    if not data then return {} end

    local asset = data:FindFirstChild("Asset")
    if not asset then return {} end

    local fruitInventory = {}

    -- Read from Attributes on Asset (primary source)
    local attrMap = {}
    local ok, attrs = pcall(function()
        return asset:GetAttributes()
    end)
    if ok and type(attrs) == "table" then
        attrMap = attrs
    end
    
    for id, item in pairs(FruitData) do
        local display = item.Name or id
        local amount = attrMap[display] or attrMap[id]
        if amount == nil then
            -- Fallback by normalized key search
            local wantA, wantB = normalizeFruitName(display), normalizeFruitName(id)
            for k, v in pairs(attrMap) do
                local nk = normalizeFruitName(k)
                if nk == wantA or nk == wantB then
                    amount = v
                    break
                end
            end
        end
        if type(amount) == "string" then amount = tonumber(amount) or 0 end
        if type(amount) == "number" and amount > 0 then
            fruitInventory[display] = amount
        end
    end

    -- Also support legacy children-based values as fallback/merge
    for _, child in pairs(asset:GetChildren()) do
        if child:IsA("StringValue") or child:IsA("IntValue") or child:IsA("NumberValue") then
            local normalized = normalizeFruitName(child.Name)
            local canonical = FRUIT_CANONICAL and FRUIT_CANONICAL[normalized]
            if canonical then
                local amount = child.Value
                if type(amount) == "string" then amount = tonumber(amount) or 0 end
                if type(amount) == "number" and amount > 0 then
                    fruitInventory[canonical] = amount
                end
            end
        end
    end

    return fruitInventory
end

-- Get player's egg inventory
local function getPlayerEggInventory()
    local eggInventory = {}
    
    if not LocalPlayer or not LocalPlayer.PlayerGui or not LocalPlayer.PlayerGui.Data then
        return eggInventory
    end
    
    local eggsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
    if eggsFolder then
        for _, eggData in pairs(eggsFolder:GetChildren()) do
            if eggData:IsA("Configuration") then
                local eggType = safeGetAttribute(eggData, "T", nil)
                if eggType and eggType ~= "" and eggType ~= "Unknown" then
                    -- Find matching egg in EggData
                    for id, item in pairs(EggData) do
                        if item.Name == eggType or id == eggType then
                            eggInventory[item.Name] = (eggInventory[item.Name] or 0) + 1
                            break
                        end
                    end
                end
            end
        end
    end
    
    return eggInventory
end

-- Unknown resolver removed per user request
-- local unknownResolver = {
-- 	pets = {},
-- 	eggs = {},
-- 	active = false
-- }

-- Live data watchers (event-driven cache updates)
local dataWatch = {
    petConns = {},
    eggConns = {},
    rootConns = {}
}

local function disconnectConn(conn)
    if conn then pcall(function() conn:Disconnect() end) end
end

-- Canonicalize mutation names (deduplicate typos like Electric/Electirc)
local function canonicalizeMutationName(name)
    if not name or name == "" then return name end
    local lower = tostring(name):lower()
    if lower == "electric" or lower == "electirc" then return "Electirc" end
    if lower == "dino" then return "Dino" end
    if lower == "golden" then return "Golden" end
    if lower == "diamond" then return "Diamond" end
    if lower == "fire" then return "Fire" end
    return name
end

local function clearConnSet(set)
    if not set then return end
    for _, c in pairs(set) do disconnectConn(c) end
end

local function upsertFromConf(conf, isEgg)
    if not conf or not conf:IsA("Configuration") then return end
    local okT, tVal = pcall(function() return conf:GetAttribute("T") end)
    if not okT or not tVal or tVal == "" then return end
    local okM, mVal = pcall(function() return conf:GetAttribute("M") end)
    local okS, speedVal = pcall(function() return conf:GetAttribute("Speed") end)
    local okLK, lkVal = pcall(function() return conf:GetAttribute("LK") end)
    local okD, dVal = pcall(function() return conf:GetAttribute("D") end)
    local record = {
        uid = conf.Name,
        type = tVal,
        mutation = (okM and mVal) or "",
        locked = (okLK and lkVal == 1) or false,
        placed = (okD and dVal ~= nil) or false
    }
    if not isEgg then
        record.speed = (okS and speedVal) or 0
    end
    if isEgg then
        inventoryCache.eggs[conf.Name] = record
        -- unknownResolver.eggs[conf.Name] = nil -- This line is removed
    else
        inventoryCache.pets[conf.Name] = record
        -- unknownResolver.pets[conf.Name] = nil -- This line is removed
    end
end

local function watchConf(conf, isEgg)
    if not conf or not conf:IsA("Configuration") then return end
    -- Initial attempt
    upsertFromConf(conf, isEgg)
    -- Attribute watchers
    local tConn = conf:GetAttributeChangedSignal("T"):Connect(function()
        upsertFromConf(conf, isEgg)
    end)
    local mConn = conf:GetAttributeChangedSignal("M"):Connect(function()
        upsertFromConf(conf, isEgg)
    end)
    local set = isEgg and dataWatch.eggConns or dataWatch.petConns
    set[conf] = { tConn, mConn }
end

local function startDataWatchers()
    -- Avoid duplicates
    if dataWatch.rootConns.started then return end
    local dataRoot = LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Data")
    if not dataRoot then return end
    local petsFolder = dataRoot:FindFirstChild("Pets")
    local eggsFolder = dataRoot:FindFirstChild("Egg")
    if petsFolder then
        for _, ch in ipairs(petsFolder:GetChildren()) do
            watchConf(ch, false)
        end
        local addConn = petsFolder.ChildAdded:Connect(function(ch) watchConf(ch, false) end)
        local remConn = petsFolder.ChildRemoved:Connect(function(ch)
            local conns = dataWatch.petConns[ch]
            if conns then for _, c in ipairs(conns) do disconnectConn(c) end end
            dataWatch.petConns[ch] = nil
            inventoryCache.pets[ch.Name] = nil
        end)
        table.insert(dataWatch.rootConns, addConn)
        table.insert(dataWatch.rootConns, remConn)
    end
    if eggsFolder then
        for _, ch in ipairs(eggsFolder:GetChildren()) do
            watchConf(ch, true)
        end
        local addConn = eggsFolder.ChildAdded:Connect(function(ch) watchConf(ch, true) end)
        local remConn = eggsFolder.ChildRemoved:Connect(function(ch)
            local conns = dataWatch.eggConns[ch]
            if conns then for _, c in ipairs(conns) do disconnectConn(c) end end
            dataWatch.eggConns[ch] = nil
            inventoryCache.eggs[ch.Name] = nil
        end)
        table.insert(dataWatch.rootConns, addConn)
        table.insert(dataWatch.rootConns, remConn)
    end
    dataWatch.rootConns.started = true
end

local function stopDataWatchers()
    clearConnSet(dataWatch.rootConns)
    for conf, conns in pairs(dataWatch.petConns) do for _, c in ipairs(conns) do disconnectConn(c) end end
    for conf, conns in pairs(dataWatch.eggConns) do for _, c in ipairs(conns) do disconnectConn(c) end end
    dataWatch.petConns = {}
    dataWatch.eggConns = {}
    dataWatch.rootConns = {}
end

-- Remove unknown resolver helpers
-- local function trackUnknown(uid, isEgg) end
-- local function startUnknownResolver() end

-- Send operation tracking
local sendInProgress = {}
local sendTimeoutSeconds = 5
local perItemCooldownSeconds = 1.2
local pendingCooldownUntil = {}

-- Wait for a specific inventory item to be removed (conf deleted) with event + polling
local function waitForInventoryRemoval(itemUID, isEgg, timeoutSecs)
    local dataRoot = LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Data")
    if not dataRoot then return false end
    local folder = dataRoot:FindFirstChild(isEgg and "Egg" or "Pets")
    if not folder then return false end

    -- Already removed
    local existing = folder:FindFirstChild(itemUID)
    if not existing then return true end

    local removed = false
    local conn
    conn = folder.ChildRemoved:Connect(function(child)
        if child and child.Name == itemUID then
            removed = true
        end
    end)

    local deadline = os.clock() + (timeoutSecs or 2.5)
    while os.clock() < deadline and not removed do
        if not folder:FindFirstChild(itemUID) then
            removed = true
            break
        end
        task.wait(0.05)
    end

    if conn then pcall(function() conn:Disconnect() end) end
    return removed
end

-- Webhook removed
local webhookUrl = ""
local sessionLogs = {}
local webhookSent = false

-- Removed session limits as requested

-- macOS Dark Theme Colors for Custom UI
local colors = {
    background = Color3.fromRGB(18, 18, 20),
    surface = Color3.fromRGB(32, 32, 34),
    primary = Color3.fromRGB(0, 122, 255),
    secondary = Color3.fromRGB(88, 86, 214),
    text = Color3.fromRGB(255, 255, 255),
    textSecondary = Color3.fromRGB(200, 200, 200),
    textTertiary = Color3.fromRGB(150, 150, 150),
    border = Color3.fromRGB(50, 50, 52),
    selected = Color3.fromRGB(0, 122, 255),
    hover = Color3.fromRGB(45, 45, 47),
    pageActive = Color3.fromRGB(0, 122, 255),
    pageInactive = Color3.fromRGB(60, 60, 62),
    close = Color3.fromRGB(255, 69, 58),
    minimize = Color3.fromRGB(255, 159, 10),
    maximize = Color3.fromRGB(48, 209, 88)
}

-- Utility Functions for Custom UI
local function getRarityColor(rarity)
    if rarity >= 100 then return Color3.fromRGB(255, 69, 58)
    elseif rarity >= 50 then return Color3.fromRGB(175, 82, 222)
    elseif rarity >= 20 then return Color3.fromRGB(88, 86, 214)
    elseif rarity >= 10 then return Color3.fromRGB(255, 159, 10)
    elseif rarity >= 6 then return Color3.fromRGB(255, 45, 85)
    elseif rarity >= 5 then return Color3.fromRGB(255, 69, 58)
    elseif rarity >= 4 then return Color3.fromRGB(175, 82, 222)
    elseif rarity >= 3 then return Color3.fromRGB(88, 86, 214)
    elseif rarity >= 2 then return Color3.fromRGB(48, 209, 88)
    else return Color3.fromRGB(174, 174, 178)
    end
end

local function formatNumber(num)
    if type(num) == "string" then return num end
    if num >= 1e12 then return string.format("%.1fT", num / 1e12)
    elseif num >= 1e9 then return string.format("%.1fB", num / 1e9)
    elseif num >= 1e6 then return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then return string.format("%.1fK", num / 1e3)
    else return tostring(num)
    end
end

local function robloxIconUrl(assetId)
    return nil
end

local function getIconUrlFor(kind, typeName)
    return nil
end

-- Cute emoji for readability in Discord
local EggEmojiMap = {}

local function getAvatarUrl(userId)
    return nil
end

local function sendWebhookSummary()
    -- disabled
end

-- Custom UI Creation Functions
local function createCustomUI()
    if customUI.screenGui then
        customUI.screenGui:Destroy()
    end
    
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    
    customUI.screenGui = Instance.new("ScreenGui")
    customUI.screenGui.Name = "SendTrashCustomUI"
    customUI.screenGui.Parent = PlayerGui
    
    customUI.mainFrame = Instance.new("Frame")
    customUI.mainFrame.Name = "MainFrame"
    customUI.mainFrame.Size = UDim2.new(0, 800, 0, 600)
    customUI.mainFrame.Position = UDim2.new(0.5, -400, 0.5, -300)
    customUI.mainFrame.BackgroundColor3 = colors.background
    customUI.mainFrame.BorderSizePixel = 0
    customUI.mainFrame.Parent = customUI.screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = customUI.mainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = customUI.mainFrame
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = colors.surface
    titleBar.BorderSizePixel = 0
    titleBar.Parent = customUI.mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -100, 1, 0)
    title.Position = UDim2.new(0, 50, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Auto Trade System"
    title.TextSize = 16
    title.Font = Enum.Font.GothamSemibold
    title.TextColor3 = colors.text
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = titleBar
    
    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = colors.close
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "×"
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Parent = titleBar
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0.5, 0)
    closeBtnCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        customUI.screenGui.Enabled = false
    end)
    
    -- Page Tabs
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(1, -20, 0, 40)
    tabContainer.Position = UDim2.new(0, 10, 0, 50)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = customUI.mainFrame
    
    local eggsTab = Instance.new("TextButton")
    eggsTab.Name = "EggsTab"
    eggsTab.Size = UDim2.new(0.5, -5, 1, 0)
    eggsTab.Position = UDim2.new(0, 0, 0, 0)
    eggsTab.BackgroundColor3 = colors.pageActive
    eggsTab.BorderSizePixel = 0
    eggsTab.Text = "🥚 Eggs"
    eggsTab.TextSize = 14
    eggsTab.Font = Enum.Font.GothamSemibold
    eggsTab.TextColor3 = colors.text
    eggsTab.Parent = tabContainer
    
    local eggsCorner = Instance.new("UICorner")
    eggsCorner.CornerRadius = UDim.new(0, 6)
    eggsCorner.Parent = eggsTab
    
    local fruitsTab = Instance.new("TextButton")
    fruitsTab.Name = "FruitsTab"
    fruitsTab.Size = UDim2.new(0.5, -5, 1, 0)
    fruitsTab.Position = UDim2.new(0.5, 5, 0, 0)
    fruitsTab.BackgroundColor3 = colors.pageInactive
    fruitsTab.BorderSizePixel = 0
    fruitsTab.Text = "🍓 Fruits"
    fruitsTab.TextSize = 14
    fruitsTab.Font = Enum.Font.GothamSemibold
    fruitsTab.TextColor3 = colors.text
    fruitsTab.Parent = tabContainer
    
    local fruitsCorner = Instance.new("UICorner")
    fruitsCorner.CornerRadius = UDim.new(0, 6)
    fruitsCorner.Parent = fruitsTab
    
    -- Content Frame
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -20, 1, -140)
    contentFrame.Position = UDim2.new(0, 10, 0, 100)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = customUI.mainFrame
    
    -- Scroll Frame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = colors.primary
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 1000)
    scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    scrollFrame.Parent = contentFrame
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.25, -10, 0, 150)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = scrollFrame
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 50)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = scrollFrame
    
    -- Tab Click Events
    eggsTab.MouseButton1Click:Connect(function()
        customUI.currentPage = "eggs"
        eggsTab.BackgroundColor3 = colors.pageActive
        fruitsTab.BackgroundColor3 = colors.pageInactive
        refreshCustomUIContent()
    end)
    
    fruitsTab.MouseButton1Click:Connect(function()
        customUI.currentPage = "fruits"
        fruitsTab.BackgroundColor3 = colors.pageActive
        eggsTab.BackgroundColor3 = colors.pageInactive
        refreshCustomUIContent()
    end)
    
    -- Set default page to eggs
    customUI.currentPage = "eggs"
    
    return customUI.screenGui
end

local function createItemCard(itemId, itemData, parent, itemType)
    print("Creating card:", itemId, itemData.Name, itemType)
    local card = Instance.new("Frame")
    card.Name = itemId
    card.Size = UDim2.new(1, 0, 1, 0)
    card.BackgroundColor3 = colors.surface
    card.BorderSizePixel = 0
    card.Parent = parent
    print("Card created and parented")
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = card
    
    -- Icon
    local icon
    if itemType == "fruit" then
        icon = Instance.new("TextLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0, 60, 0, 60)
        icon.Position = UDim2.new(0.5, -30, 0, 10)
        icon.BackgroundTransparency = 1
        icon.Text = itemData.Icon
        icon.TextSize = 40
        icon.Font = Enum.Font.GothamBold
        icon.TextColor3 = getRarityColor(itemData.Rarity)
        icon.Parent = card
    else
        icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0, 60, 0, 60)
        icon.Position = UDim2.new(0.5, -30, 0, 10)
        icon.BackgroundTransparency = 1
        icon.Image = itemData.Icon
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Parent = card
    end
    
    -- Name
    local name = Instance.new("TextLabel")
    name.Name = "Name"
    name.Size = UDim2.new(1, -10, 0, 20)
    name.Position = UDim2.new(0, 5, 0, 75)
    name.BackgroundTransparency = 1
    name.Text = itemData.Name
    name.TextSize = 12
    name.Font = Enum.Font.GothamSemibold
    name.TextColor3 = colors.text
    name.TextXAlignment = Enum.TextXAlignment.Center
    name.TextWrapped = true
    name.Parent = card
    
    -- Amount owned
    local amountLabel = Instance.new("TextLabel")
    amountLabel.Name = "AmountLabel"
    amountLabel.Size = UDim2.new(1, -10, 0, 16)
    amountLabel.Position = UDim2.new(0, 5, 0, 95)
    amountLabel.BackgroundTransparency = 1
    amountLabel.Text = "0x"
    amountLabel.TextSize = 10
    amountLabel.Font = Enum.Font.Gotham
    amountLabel.TextColor3 = colors.textSecondary
    amountLabel.TextXAlignment = Enum.TextXAlignment.Center
    amountLabel.Parent = card
    
    -- Send amount input
    local sendInput = Instance.new("TextBox")
    sendInput.Name = "SendInput"
    sendInput.Size = UDim2.new(0.8, 0, 0, 20)
    sendInput.Position = UDim2.new(0.1, 0, 0, 115)
    sendInput.BackgroundColor3 = colors.background
    sendInput.BorderSizePixel = 0
    sendInput.Text = "0"
    sendInput.PlaceholderText = "Amount to send"
    sendInput.TextSize = 10
    sendInput.Font = Enum.Font.Gotham
    sendInput.TextColor3 = colors.text
    sendInput.TextXAlignment = Enum.TextXAlignment.Center
    sendInput.Parent = card
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 4)
    inputCorner.Parent = sendInput
    
    -- New indicator
    if itemData.IsNew then
        local newIndicator = Instance.new("TextLabel")
        newIndicator.Name = "NewIndicator"
        newIndicator.Size = UDim2.new(0, 30, 0, 16)
        newIndicator.Position = UDim2.new(1, -34, 0, 2)
        newIndicator.BackgroundColor3 = Color3.fromRGB(255, 69, 58)
        newIndicator.BorderSizePixel = 0
        newIndicator.Text = "NEW"
        newIndicator.TextSize = 8
        newIndicator.Font = Enum.Font.GothamBold
        newIndicator.TextColor3 = Color3.fromRGB(255, 255, 255)
        newIndicator.TextXAlignment = Enum.TextXAlignment.Center
        newIndicator.TextYAlignment = Enum.TextYAlignment.Center
        newIndicator.Parent = card
        
        local newCorner = Instance.new("UICorner")
        newCorner.CornerRadius = UDim.new(0, 3)
        newCorner.Parent = newIndicator
    end
    
    return card
end

function refreshCustomUIContent()
    if not customUI.screenGui then 
        print("No screenGui found")
        return 
    end
    
    local contentFrame = customUI.mainFrame:FindFirstChild("ContentFrame")
    if not contentFrame then 
        print("No ContentFrame found")
        return 
    end
    
    local scrollFrame = contentFrame:FindFirstChild("ScrollFrame")
    if not scrollFrame then 
        print("No ScrollFrame found")
        return 
    end
    
    -- Clear existing content
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIGridLayout" and child.Name ~= "UIPadding" then
            child:Destroy()
        end
    end
    
    local data, itemType
    if customUI.currentPage == "eggs" then
        data = EggData
        itemType = "egg"
        local count = 0
        for _ in pairs(data) do count = count + 1 end
        print("Loading eggs, data count:", count)
    elseif customUI.currentPage == "fruits" then
        data = FruitData
        itemType = "fruit"
        local count = 0
        for _ in pairs(data) do count = count + 1 end
        print("Loading fruits, data count:", count)
    else
        print("Unknown page:", customUI.currentPage)
        return -- Pets not implemented yet
    end
    
    print("Current page:", customUI.currentPage, "Item type:", itemType)
    
    -- Sort by inventory amount (high to low)
    local sortedData = {}
    for id, item in pairs(data) do
        table.insert(sortedData, {id = id, data = item})
    end
    
    local inventory
    if itemType == "fruit" then
        inventory = getPlayerFruitInventory()
    elseif itemType == "egg" then
        inventory = getPlayerEggInventory()
    end
    
    table.sort(sortedData, function(a, b)
        local amountA = inventory[a.data.Name] or 0
        local amountB = inventory[b.data.Name] or 0
        return amountA > amountB
    end)
    
    -- Create cards
    print("Creating", #sortedData, "cards")
    for i, item in ipairs(sortedData) do
        print("Creating card for:", item.id, item.data.Name)
        local card = createItemCard(item.id, item.data, scrollFrame, itemType)
        card.LayoutOrder = i
        
        -- Update inventory display
        local amountLabel = card:FindFirstChild("AmountLabel")
        local sendInput = card:FindFirstChild("SendInput")
        
        if amountLabel then
            local amount = inventory[item.data.Name] or 0
            amountLabel.Text = amount .. "x"
            
            if amount > 0 then
                amountLabel.TextColor3 = colors.textSecondary
            else
                amountLabel.TextColor3 = Color3.fromRGB(255, 69, 58)
            end
        end
        
        -- Restore send amount if exists
        if sendInput then
            local sendAmount = customUI.sendAmounts[item.id] or 0
            sendInput.Text = tostring(sendAmount)
            
            -- Handle send amount input
            sendInput.FocusLost:Connect(function()
                local amount = tonumber(sendInput.Text) or 0
                if amount < 0 then amount = 0 end
                sendInput.Text = tostring(amount)
                
                customUI.sendAmounts[item.id] = amount
                
                -- Update selection state
                if amount > 0 then
                    customUI.selectedItems[item.id] = true
                    card.BackgroundColor3 = colors.selected
                else
                    customUI.selectedItems[item.id] = nil
                    card.BackgroundColor3 = colors.surface
                end
            end)
            
            -- Restore selection state
            if sendAmount > 0 then
                customUI.selectedItems[item.id] = true
                card.BackgroundColor3 = colors.selected
            end
        end
    end
    
    -- Update canvas size
    local itemCount = #sortedData
    if itemCount > 0 then
        local rows = math.ceil(itemCount / 4) -- 4 items per row
        local cellHeight = 150
        local cellPadding = 10
        local topPadding = 10
        local bottomPadding = 50
        local totalHeight = topPadding + (rows * cellHeight) + ((rows - 1) * cellPadding) + bottomPadding
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    end
end



-- Helper function to safely get attribute
local function safeGetAttribute(obj, attrName, default)
    if not obj then return default end
    local success, result = pcall(function()
        return obj:GetAttribute(attrName)
    end)
    return success and result or default
end

-- Helper function to parse speed input with K/M/B/T suffixes
local function parseSpeedInput(text)
    if not text or type(text) ~= "string" then return 0 end
    
    local cleanText = text:gsub("[$€£¥₹/s,]", ""):gsub("^%s*(.-)%s*$", "%1")
    local number, suffix = cleanText:match("^([%d%.]+)([KkMmBbTt]?)$")
    
    if not number then
        number = cleanText:match("([%d%.]+)")
    end
    
    local numValue = tonumber(number)
    if not numValue then return 0 end
    
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

-- Get pet speed from UI (same as AutoSellSystem)
local function getPetSpeed(petNode)
    if not petNode then return 0 end
    -- Prefer real value from UI using the pet UID
    local uid = petNode.Name
    local lp = Players.LocalPlayer
    local pg = lp and lp:FindFirstChild("PlayerGui")
    local ss = pg and pg:FindFirstChild("ScreenStorage")
    local frame = ss and ss:FindFirstChild("Frame")
    local content = frame and frame:FindFirstChild("ContentPet")
    local scroll = content and content:FindFirstChild("ScrollingFrame")
    local item = scroll and scroll:FindFirstChild(uid)
    local btn = item and item:FindFirstChild("BTN")
    local stat = btn and btn:FindFirstChild("Stat")
    local price = stat and stat:FindFirstChild("Price")
    local valueLabel = price and price:FindFirstChild("Value")
    local txt = valueLabel and valueLabel:IsA("TextLabel") and valueLabel.Text or nil
    if not txt and price and price:IsA("TextLabel") then
        txt = price.Text
    end
    if txt then
        local n = tonumber((txt:gsub("[^%d]", ""))) or 0
        return n
    end
    return 0
end

-- Get all pet types from inventory + hardcoded list
local function getAllPetTypes()
    local types = {}
    
    -- Add hardcoded types
    for _, petType in ipairs(HardcodedPetTypes) do
        types[petType] = true
    end
    
    -- Add types from inventory
    if LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui.Data then
        local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
        if petsFolder then
            for _, petData in pairs(petsFolder:GetChildren()) do
                if petData:IsA("Configuration") then
                    local petType = safeGetAttribute(petData, "T", nil)
                    if petType then
                        types[petType] = true
                    end
                end
            end
        end
    end
    
    -- Convert to sorted array
    local sortedTypes = {}
    for petType in pairs(types) do
        table.insert(sortedTypes, petType)
    end
    table.sort(sortedTypes)
    
    return sortedTypes
end

-- Get all egg types from inventory + hardcoded list
local function getAllEggTypes()
    local types = {}
    
    -- Add egg types from EggData
    for _, eggData in pairs(EggData) do
        types[eggData.Name] = true
    end
    
    -- Add types from inventory
    if LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui.Data then
        local eggsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
        if eggsFolder then
            for _, eggData in pairs(eggsFolder:GetChildren()) do
                if eggData:IsA("Configuration") then
                    local eggType = safeGetAttribute(eggData, "T", nil)
                    if eggType then
                        types[eggType] = true
                    end
                end
            end
        end
    end
    
    -- Convert to sorted array
    local sortedTypes = {}
    for eggType in pairs(types) do
        table.insert(sortedTypes, eggType)
    end
    table.sort(sortedTypes)
    
    return sortedTypes
end

-- Get all mutations from inventory + hardcoded list
local function getAllMutations()
    local mutations = {}
    
    -- Add hardcoded mutations (canonicalized)
    for _, mutation in ipairs(HardcodedMutations) do
        mutations[canonicalizeMutationName(mutation)] = true
    end
    
    -- Add mutations from inventory
    if LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui.Data then
        local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
        if petsFolder then
            for _, petData in pairs(petsFolder:GetChildren()) do
                if petData:IsA("Configuration") then
                    local petMutation = canonicalizeMutationName(safeGetAttribute(petData, "M", nil))
                    if petMutation and petMutation ~= "" then
                        mutations[petMutation] = true
                    end
                end
            end
        end
    end
    
    -- Convert to sorted array
    local sortedMutations = {}
    for mutation in pairs(mutations) do
        table.insert(sortedMutations, mutation)
    end
    table.sort(sortedMutations)
    
    return sortedMutations
end

-- Get player list for sending pets
local function refreshPlayerList()
    local playerList = {"Random Player"}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerList, player.Name)
        end
    end
    
    return playerList
end

-- Resolve target player by either Username or DisplayName (case-insensitive)
local function resolveTargetPlayerByName(name)
    if not name or name == "" then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == name or p.DisplayName == name then
            return p
        end
        -- case-insensitive fallback
        if string.lower(p.Name) == string.lower(name) or string.lower(p.DisplayName) == string.lower(name) then
            return p
        end
    end
    return nil
end

local function isPlayerValid(p)
	return p and p.Parent == Players
end

local function pickRandomTarget(excludeUserId)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and (not excludeUserId or p.UserId ~= excludeUserId) then
			table.insert(list, p)
		end
	end
	if #list == 0 then return nil end
	return list[math.random(1, #list)]
end

-- Get random player
local function getRandomPlayer()
	local players = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			table.insert(players, player)
		end
	end
	if #players > 0 then
		return players[math.random(1, #players)] -- return Player object
	end
	return nil
end

-- Get a randomized list of up to N candidate players (Player objects)
	local function getRoundRobinTargets()
		local pool = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				table.insert(pool, player)
			end
		end
		table.sort(pool, function(a, b) return a.UserId < b.UserId end)
		return pool
	end

-- Convert dropdown selection into a plain string list
local function selectionToList(selection)
    local result = {}
    if type(selection) == "table" then
        -- Handle either array-style or set-style tables
        local hasIndexed = false
        for k, v in pairs(selection) do
            if type(k) == "number" then
                hasIndexed = true
                break
            end
        end
        if hasIndexed then
            for _, v in ipairs(selection) do
                v = tostring(v)
                if v ~= "" and v ~= "--" then table.insert(result, v) end
            end
        else
            for k, v in pairs(selection) do
                if v == true and type(k) == "string" and k ~= "--" and k ~= "" then
                    table.insert(result, k)
                end
            end
        end
    elseif type(selection) == "string" then
        if selection ~= "" and selection ~= "--" then table.insert(result, selection) end
    end
    return result
end

-- Sync cached selector variables from current UI controls (needed after config load)
local function syncSelectorsFromControls()
    local function readControl(ctrl)
        if not ctrl then return nil end
        local ok, v
        if ctrl.GetValue then
            ok, v = pcall(function() return ctrl:GetValue() end)
        elseif ctrl.Value ~= nil then
            ok, v = true, ctrl.Value
        end
        if ok then return v end
        return nil
    end

    -- Sync pet speed values
    local minSpeedVal = readControl(petMinSpeedInput)
    local maxSpeedVal = readControl(petMaxSpeedInput)
    
    if minSpeedVal ~= nil then petMinSpeed = parseSpeedInput(tostring(minSpeedVal)) end
    if maxSpeedVal ~= nil then petMaxSpeed = parseSpeedInput(tostring(maxSpeedVal)) end
    
    -- Egg filters removed (now using custom UI)
end

-- Get pet inventory
--- Update inventory cache for better performance
local function updateInventoryCache()
    local currentTime = tick()
    if currentTime - inventoryCache.lastUpdateTime < inventoryCache.updateInterval then
        return -- Don't update too frequently
    end
    
    inventoryCache.lastUpdateTime = currentTime
    inventoryCache.pets = {}
    inventoryCache.eggs = {}
    inventoryCache.unknownCount = 0
    
    if not LocalPlayer or not LocalPlayer.PlayerGui or not LocalPlayer.PlayerGui.Data then
        return
    end
    
    -- Update pets cache
    local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
    if petsFolder then
        for _, petData in pairs(petsFolder:GetChildren()) do
            if petData:IsA("Configuration") then
                -- Try multiple attributes and wait for data to load
                local petType = safeGetAttribute(petData, "T", nil)
                
                -- Skip items without proper type data (not fully loaded yet)
                if not petType or petType == "" or petType == "Unknown" then
                    inventoryCache.unknownCount = inventoryCache.unknownCount + 1
                    continue -- Skip this pet until it loads properly
                end
                
                local petInfo = {
                    uid = petData.Name,
                    type = petType,
                    mutation = safeGetAttribute(petData, "M", ""),
                    speed = safeGetAttribute(petData, "Speed", 0),
                    locked = safeGetAttribute(petData, "LK", 0) == 1,
                    placed = safeGetAttribute(petData, "D", nil) ~= nil
                }
                inventoryCache.pets[petData.Name] = petInfo
            end
        end
    end
    
    -- Update eggs cache
    local eggsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
    if eggsFolder then
        for _, eggData in pairs(eggsFolder:GetChildren()) do
            if eggData:IsA("Configuration") then
                -- Try multiple attributes and wait for data to load
                local eggType = safeGetAttribute(eggData, "T", nil)
                
                -- Skip items without proper type data (not fully loaded yet)
                if not eggType or eggType == "" or eggType == "Unknown" then
                    inventoryCache.unknownCount = inventoryCache.unknownCount + 1
                    continue -- Skip this egg until it loads properly
                end
                
                local eggInfo = {
                    uid = eggData.Name,
                    type = eggType,
                    mutation = safeGetAttribute(eggData, "M", ""),
                    locked = safeGetAttribute(eggData, "LK", 0) == 1,
                    placed = safeGetAttribute(eggData, "D", nil) ~= nil
                }
                inventoryCache.eggs[eggData.Name] = eggInfo
            end
        end
    end
    
    -- If there are unknowns, start background resolver
    if inventoryCache.unknownCount > 0 then
        -- startUnknownResolver()
    end
end

--- Verify item still exists in inventory
local function verifyItemExists(itemUID, isEgg)
    updateInventoryCache()
    if isEgg then
        return inventoryCache.eggs[itemUID] ~= nil
    else
        return inventoryCache.pets[itemUID] ~= nil
    end
end

--- Force cache refresh (useful for immediate updates)
local function forceRefreshCache()
    inventoryCache.lastUpdateTime = 0
    updateInventoryCache()
end

--- Force refresh with data reload (for "Unknown" items)
local function forceDataReload()
    -- Clear cache completely
    inventoryCache.lastUpdateTime = 0
    inventoryCache.pets = {}
    inventoryCache.eggs = {}
    
    -- Wait a moment for game data to settle
    task.wait(0.5)
    
    -- Force multiple cache updates to catch data as it loads
    for i = 1, 3 do
        updateInventoryCache()
        task.wait(0.2)
    end
    
    -- Count items that loaded successfully
    local loadedPets = 0
    local loadedEggs = 0
    for _, pet in pairs(inventoryCache.pets) do
        if pet.type and pet.type ~= "" and pet.type ~= "Unknown" then
            loadedPets = loadedPets + 1
        end
    end
    for _, egg in pairs(inventoryCache.eggs) do
        if egg.type and egg.type ~= "" and egg.type ~= "Unknown" then
            loadedEggs = loadedEggs + 1
        end
    end
    
    return loadedPets, loadedEggs
end

-- Actively focus unresolved items to force replication of T/M
local function forceResolveAllNames()
	return 0, 0
end

--- Clear send operation tracking
local function clearSendProgress()
    sendInProgress = {}
end

--- Save webhook URL to config
local function saveWebhookUrl(url)
    webhookUrl = tostring(url or "")
    if Config and Config.SaveSetting then
        Config:SaveSetting("SendTrash_WebhookUrl", webhookUrl)
        if WindUI then
            WindUI:Notify({
                Title = "💾 Webhook Saved",
                Content = webhookUrl ~= "" and "Webhook URL saved successfully!" or "Webhook URL cleared",
                Duration = 2
            })
        end
    else
        if WindUI then
            WindUI:Notify({
                Title = "⚠️ Config System",
                Content = "Config system not available - webhook won't persist",
                Duration = 3
            })
        end
    end
end

--- Load webhook URL from config
local function loadWebhookUrl()
    if Config and Config.GetSetting then
        local savedUrl = Config:GetSetting("SendTrash_WebhookUrl")
        if savedUrl and savedUrl ~= "" then
            webhookUrl = tostring(savedUrl)
            return true -- Successfully loaded
        end
    end
    return false -- No saved URL or config unavailable
end

--- Get pet inventory (uses cache for better performance)
local function getPetInventory()
    updateInventoryCache()
    local pets = {}
    for _, pet in pairs(inventoryCache.pets) do
        table.insert(pets, pet)
    end
    return pets
end

--- Get egg inventory (uses cache for better performance)
local function getEggInventory()
    updateInventoryCache()
    local eggs = {}
    for _, egg in pairs(inventoryCache.eggs) do
        table.insert(eggs, egg)
    end
    return eggs
end

--- Send current inventory webhook
local function sendCurrentInventoryWebhook()
    -- disabled

    -- Small helpers
    local function compactNumber(n)
        if type(n) ~= "number" then return tostring(n) end
        local a = math.abs(n)
        if a >= 1e12 then return string.format("%.2fT", n/1e12) end
        if a >= 1e9  then return string.format("%.2fB", n/1e9)  end
        if a >= 1e6  then return string.format("%.2fM", n/1e6)  end
        if a >= 1e3  then return string.format("%.2fK", n/1e3)  end
        return tostring(math.floor(n))
    end
    local function takeTopLines(map, prefix, maxLines)
        local arr = {}
        for name, count in pairs(map) do
            table.insert(arr, { name = name, count = count })
        end
        table.sort(arr, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return (a.name or "") < (b.name or "")
        end)
        local out = {}
        local limit = math.min(maxLines or 10, #arr)
        for i = 1, limit do
            table.insert(out, string.format("%s %s × %d", prefix, arr[i].name, arr[i].count))
        end
        if #arr > limit then
            table.insert(out, string.format("… and %d more", #arr - limit))
        end
        return table.concat(out, "\n")
    end

    -- Force refresh inventory cache for precision
    forceRefreshCache()

    local petInventoryAll = getPetInventory()
    local eggInventoryAll = getEggInventory()
    local allPetCount = petInventoryAll and #petInventoryAll or 0
    local allEggCount = eggInventoryAll and #eggInventoryAll or 0

    -- Filter to only items with D attribute empty or missing (unplaced/available)
    local function hasEmptyOrNoD(uid, isEgg)
        local dataRoot = LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Data")
        if not dataRoot then return false end
        local folder = dataRoot:FindFirstChild(isEgg and "Egg" or "Pets")
        if not folder then return false end
        local conf = folder:FindFirstChild(uid)
        if not conf or not conf:IsA("Configuration") then return false end
        local dAttr = safeGetAttribute(conf, "D", nil)
        if dAttr == nil then return true end
        if type(dAttr) == "string" then
            local s = dAttr
            return s == "" or s == "nil"
        end
        return false
    end

    local petInventory, eggInventory = {}, {}
    for _, pet in ipairs(petInventoryAll or {}) do
        if pet and pet.uid and hasEmptyOrNoD(pet.uid, false) then
            table.insert(petInventory, pet)
        end
    end
    for _, egg in ipairs(eggInventoryAll or {}) do
        if egg and egg.uid and hasEmptyOrNoD(egg.uid, true) then
            table.insert(eggInventory, egg)
        end
    end

    local unplacedPetCount = #petInventory
    local unplacedEggCount = #eggInventory

    -- Build summaries (type + mutation distributions)
    local petsByType, eggsByType = {}, {}
    local petMutations, eggMutations = {}, {}
    local eggMutsByType = {}
    local petMutsByType = {}
    for _, pet in ipairs(petInventory) do
        local t = pet.type or "Unknown"
        petsByType[t] = (petsByType[t] or 0) + 1
        local m = pet.mutation
        if m and m ~= "" and m ~= "None" then
            petMutations[m] = (petMutations[m] or 0) + 1
            petMutsByType[t] = petMutsByType[t] or {}
            petMutsByType[t][m] = (petMutsByType[t][m] or 0) + 1
        end
    end
    for _, egg in ipairs(eggInventory) do
        local t = egg.type or "Unknown"
        eggsByType[t] = (eggsByType[t] or 0) + 1
        local m = egg.mutation
        if m and m ~= "" and m ~= "None" then
            eggMutations[m] = (eggMutations[m] or 0) + 1
            eggMutsByType[t] = eggMutsByType[t] or {}
            eggMutsByType[t][m] = (eggMutsByType[t][m] or 0) + 1
        end
    end

    -- Hierarchical eggs display with per-type mutations
    local function eggHierarchy(maxTypes, maxMutsPerType)
        local typesArr = {}
        for name, count in pairs(eggsByType) do
            table.insert(typesArr, { name = name, count = count })
        end
        table.sort(typesArr, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return (a.name or "") < (b.name or "")
        end)

        local lines = {}
        local limit = math.min(maxTypes or 10, #typesArr)
        for i = 1, limit do
            local t = typesArr[i]
            table.insert(lines, string.format(":trophy: %s × %d", t.name, t.count))
            local muts = eggMutsByType[t.name] or {}
            local mutsArr = {}
            for m, c in pairs(muts) do table.insert(mutsArr, { m = m, c = c }) end
            table.sort(mutsArr, function(a, b)
                if a.c ~= b.c then return a.c > b.c end
                return (a.m or "") < (b.m or "")
            end)
            local mLimit = math.min(maxMutsPerType or 5, #mutsArr)
            for j = 1, mLimit do
                table.insert(lines, string.format("L :dna: %s × %d", mutsArr[j].m, mutsArr[j].c))
            end
            if #mutsArr > mLimit then
                table.insert(lines, string.format("L … and %d more", #mutsArr - mLimit))
            end
        end
        if #typesArr > limit then
            table.insert(lines, string.format("… and %d more egg types", #typesArr - limit))
        end
        return table.concat(lines, "\n"), (typesArr[1] and typesArr[1].name or nil)
    end

    local topEggsText, topEggName = eggHierarchy(12, 5)

    -- Hierarchical pets display with per-type mutations
    local function petHierarchy(maxTypes, maxMutsPerType)
        local typesArr = {}
        for name, count in pairs(petsByType) do
            table.insert(typesArr, { name = name, count = count })
        end
        table.sort(typesArr, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return (a.name or "") < (b.name or "")
        end)

        local lines = {}
        local limit = math.min(maxTypes or 10, #typesArr)
        for i = 1, limit do
            local t = typesArr[i]
            table.insert(lines, string.format("🐾 %s × %d", t.name, t.count))
            local muts = petMutsByType[t.name] or {}
            local mutsArr = {}
            for m, c in pairs(muts) do table.insert(mutsArr, { m = m, c = c }) end
            table.sort(mutsArr, function(a, b)
                if a.c ~= b.c then return a.c > b.c end
                return (a.m or "") < (b.m or "")
            end)
            local mLimit = math.min(maxMutsPerType or 5, #mutsArr)
            for j = 1, mLimit do
                table.insert(lines, string.format("L :dna: %s × %d", mutsArr[j].m, mutsArr[j].c))
            end
            if #mutsArr > mLimit then
                table.insert(lines, string.format("L … and %d more", #mutsArr - mLimit))
            end
        end
        if #typesArr > limit then
            table.insert(lines, string.format("… and %d more pet types", #typesArr - limit))
        end
        return table.concat(lines, "\n")
    end

    local topPetsText = petHierarchy(12, 5)

    local playerName = Players.LocalPlayer and Players.LocalPlayer.Name or "Unknown"
    local playerId = Players.LocalPlayer and Players.LocalPlayer.UserId or nil
    local authorBlock = {
        name = playerName .. " — Inventory Snapshot",
        icon_url = playerId and getAvatarUrl(playerId) or nil
    }
    local thumb = topEggName and getIconUrlFor("egg", topEggName) or nil
    local netWorth = (Players.LocalPlayer and Players.LocalPlayer:GetAttribute("NetWorth")) or 0
    local unknownNote = inventoryCache and inventoryCache.unknownCount or 0

    -- Compose embed
    local overviewValue = table.concat({
        "Net Worth: **" .. compactNumber(netWorth) .. "**",
        string.format("Pets: **%d** (unplaced **%d**)", allPetCount, unplacedPetCount),
        string.format("Eggs: **%d** (unplaced **%d**)", allEggCount, unplacedEggCount)
    }, "\n")

    local fields = {
        { name = "Overview", value = overviewValue, inline = false },
    }
    if topPetsText ~= "" then table.insert(fields, { name = "Top Pets", value = topPetsText, inline = true }) end
    if topEggsText ~= "" then table.insert(fields, { name = "Top Eggs", value = topEggsText, inline = true }) end
    if unknownNote and unknownNote > 0 then
        table.insert(fields, { name = "Note", value = "Some items are still loading (" .. tostring(unknownNote) .. ")", inline = false })
    end

    local payload = {
        embeds = {
            {
                title = "ZEBUX • Inventory Snapshot",
                description = "A precise snapshot of your current inventory.",
                color = 5793266, -- Discord blurple-ish
                author = authorBlock,
                thumbnail = thumb and { url = thumb } or nil,
                fields = fields,
                footer = { text = "Build A Zoo" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }

    -- webhook disabled
end

-- Refresh live attributes (T/M/locked/placed) for a given uid directly from PlayerGui.Data
local function refreshItemFromData(uid, isEgg, into)
    local dataRoot = LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Data")
    if not dataRoot then return into end
    local folder = dataRoot:FindFirstChild(isEgg and "Egg" or "Pets")
    if not folder then return into end
    local conf = folder:FindFirstChild(uid)
    if conf and conf:IsA("Configuration") then
        -- Try multiple attributes for better type detection
        local tVal
        tVal = safeGetAttribute(conf, "T", nil)
        
        -- Skip items that haven't loaded type data yet
        if not tVal or tVal == "" or tVal == "Unknown" then
            return into -- Return unchanged if data isn't ready yet
        end
        
        if into then
            into.type = tVal
            into.mutation = safeGetAttribute(conf, "M", into.mutation)
            into.locked = safeGetAttribute(conf, "LK", 0) == 1
            into.placed = safeGetAttribute(conf, "D", nil) ~= nil
            return into
        else
            return { uid = uid, type = tVal, mutation = safeGetAttribute(conf, "M", ""), locked = safeGetAttribute(conf, "LK", 0) == 1, placed = safeGetAttribute(conf, "D", nil) ~= nil }
        end
    end
    return into
end

-- Re-verify live item data against current selectors before sending
local shouldSendItem
local function verifyItemMatchesFiltersLive(uid, isEgg, includeTypes, includeMutations)
    -- Read fresh snapshot from PlayerGui.Data
    local fresh = refreshItemFromData(uid, isEgg, nil)
    if not fresh then return false end
    -- Reuse shouldSendItem logic using the fresh record
    return shouldSendItem(fresh, includeTypes, includeMutations, isEgg), fresh
end

-- Check if item should be sent/sold based on filters
function shouldSendItem(item, includeTypes, includeMutations, isEgg)
    -- Don't send locked items
    if item.locked then return false end
    
    -- For pets: use speed filtering instead of type/mutation
    if not isEgg then
        -- Get pet speed using the existing getPetSpeed function
        local petSpeed = getPetSpeed({ Name = item.uid })
        
        -- Check if speed is within the specified range
        if petSpeed < petMinSpeed or petSpeed > petMaxSpeed then
            return false
        end
        
        return true -- If speed is in range, send the pet
    end
    
    -- For eggs: keep the original type/mutation filtering logic
    -- Normalize values for robust comparison
    local function norm(v)
        return v and tostring(v):lower() or nil
    end
    local itemType = norm(item.type)
    local itemMut  = item.mutation and norm(canonicalizeMutationName(item.mutation)) or nil
    
    -- STRICT: require a valid T (type) to exist
    if not itemType or itemType == "" or itemType == "unknown" then
        return false
    end
    
    -- Build lookup sets for O(1) checks
    local typesSet, mutsSet
    if includeTypes and #includeTypes > 0 then
        typesSet = {}
        for _, t in ipairs(includeTypes) do typesSet[norm(t)] = true end
        if not typesSet[itemType] then return false end
    end
    if includeMutations and #includeMutations > 0 then
        -- STRICT for M: if selectors provided, item must have an M and it must match
        if not itemMut or itemMut == "" then return false end
        mutsSet = {}
        for _, m in ipairs(includeMutations) do mutsSet[norm(canonicalizeMutationName(m))] = true end
        if not mutsSet[itemMut] then return false end
    end
    
    return true
end

-- Remove placed item from ground
local function removeFromGround(itemUID)
    local success, err = pcall(function()
        local args = {"Del", itemUID}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    if not success then
        warn("❌ Failed to remove item " .. itemUID .. " from ground: " .. tostring(err))
    end
    
    return success
end

-- Focus pet/egg before sending/selling (exactly like manual method)
local function focusItem(itemUID)
    local success, err = pcall(function()
        local args = {"Focus", itemUID}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    if not success then
        warn("❌ Failed to focus item " .. itemUID .. ": " .. tostring(err))
    end
    
    return success
end

-- Send item (pet or egg) to player
--- Send item (pet or egg) to player with verification and retry
local function sendItemToPlayer(item, target, itemType)
	-- Session limits removed

	local itemUID = item.uid
	local isEgg = itemType == "egg"

	-- Prevent parallel/rapid sends for the same item (cooldown + in-progress)
	local nowClock = os.clock()
	local untilTs = pendingCooldownUntil[itemUID]
	if untilTs and nowClock < untilTs then
		return false
	end
	if sendInProgress[itemUID] then return false end
	sendInProgress[itemUID] = true

	-- Verify item exists before attempting to send
	if not verifyItemExists(itemUID, isEgg) then
		sendInProgress[itemUID] = nil
		return false
	end

	-- Resolve target (accept Player instance or name)
	local targetPlayerObj = nil
	if typeof(target) == "Instance" then
		if target:IsA("Player") then targetPlayerObj = target end
	elseif type(target) == "string" then
		targetPlayerObj = resolveTargetPlayerByName(target)
	end
	if not targetPlayerObj then
		sendInProgress[itemUID] = nil
		return false -- silently skip
	end

	local success = false

	-- Skip placed items; do not auto-remove from ground
	if item.placed then
		sendInProgress[itemUID] = nil
		return false
	end

	-- Focus the item first (REQUIRED)
	local focusSuccess = focusItem(itemUID)
	if focusSuccess then task.wait(0.1) end

	-- Skip filter verification for custom UI (items are pre-selected)

	-- Ensure player is still online
	if not targetPlayerObj or targetPlayerObj.Parent ~= Players then
		sendInProgress[itemUID] = nil
		return false
	end

	-- Attempt to send (single attempt, we confirm via removal)
	local sendSuccess, _ = pcall(function()
		local args = { targetPlayerObj }
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(unpack(args))
	end)

	if sendSuccess then
		-- Robust confirmation: wait until inventory actually removes the item
		local removed = waitForInventoryRemoval(itemUID, isEgg, 3.0)
		if removed then
			-- Use freshest data captured earlier if available to ensure correct type/name/mutation in logs
			success = true
			actionCounter = actionCounter + 1
			local logged = item
			table.insert(sessionLogs, { kind = itemType, uid = itemUID, type = logged and logged.type or item.type, mutation = (logged and logged.mutation) and logged.mutation or ((item.mutation ~= nil and item.mutation ~= "" and item.mutation) or "None"), receiver = targetPlayerObj.Name })
		else
			-- Not removed → treat as failure (do not count/log)
			success = false
		end
	end

	sendInProgress[itemUID] = nil

	-- Apply per-item cooldown regardless of success to avoid hammering
	pendingCooldownUntil[itemUID] = os.clock() + perItemCooldownSeconds

	if success then
		WindUI:Notify({ Title = "✅ Sent Successfully", Content = itemType:gsub("^%l", string.upper) .. " " .. (item.type or "Unknown") .. " → " .. targetPlayerObj.Name, Duration = 2 })
		
		-- Send webhook notification for successful trade
		if _G.WebhookSystem and _G.WebhookSystem.SendTradeWebhook then
			local fromItems = {{
				type = item.type,
				mutation = (item.mutation ~= nil and item.mutation ~= "" and item.mutation) or "",
				count = 1
			}}
			_G.WebhookSystem.SendTradeWebhook(LocalPlayer.Name, targetPlayerObj.Name, fromItems, {})
		end
	else
		-- silent fail (no spam)
	end

	return success
end

-- Sell pet (only pets, no eggs)
-- Selling pets has been removed per user request

-- Auto-delete slow pets
-- auto-delete slow pets removed per request

-- Update status display
local function updateStatus()
    if not statusParagraph then return end
    
    local petInventory = getPetInventory()
    local eggInventory = getEggInventory()
    
    -- Format speed values nicely
    local function formatSpeed(speed)
        if speed >= 1000000000000 then
            return string.format("%.1fT", speed / 1000000000000)
        elseif speed >= 1000000000 then
            return string.format("%.1fB", speed / 1000000000)
        elseif speed >= 1000000 then
            return string.format("%.1fM", speed / 1000000)
        elseif speed >= 1000 then
            return string.format("%.1fK", speed / 1000)
        else
            return tostring(speed)
        end
    end
    
    local statusText = string.format(
        "🐾 Pets in inventory: %d\n" ..
        "🥚 Eggs in inventory: %d\n" ..
        "⚡ Pet speed range: %s - %s\n" ..
        "🔄 Actions performed: %d\n" ..
        "📡 Keep tracking when empty: %s",
        #petInventory,
        #eggInventory,
        formatSpeed(petMinSpeed),
        formatSpeed(petMaxSpeed),
        actionCounter,
        keepTrackingWhenEmpty and "Enabled" or "Disabled"
    )

    -- Blacklist removed

    statusParagraph:SetDesc(statusText)
end

-- Main trash processing function (updated for custom UI)
local function processTrash()
	while trashEnabled do
		-- Check if we have any items selected to send
		local hasItemsToSend = false
		for itemId, amount in pairs(customUI.sendAmounts) do
			if amount > 0 then
				hasItemsToSend = true
				break
			end
		end
		
		if not hasItemsToSend then
			if not keepTrackingWhenEmpty then
				trashEnabled = false
				if trashToggle then pcall(function() trashToggle:SetValue(false) end) end
				WindUI:Notify({ Title = "Send Trash Stopped", Content = "No items selected to send.", Duration = 4 })
				break
			else
				updateStatus()
				task.wait(2.0)
				continue
			end
		end

		-- Determine targets
		local targets = {}
		local randomMode = (selectedTargetName == "Random Player")
		if randomMode then
			targets = getRoundRobinTargets()
			if #targets > 0 then
				if randomTargetState.rrIndex > #targets then randomTargetState.rrIndex = 1 end
				targets = { targets[randomTargetState.rrIndex] }
				randomTargetState.rrIndex = randomTargetState.rrIndex + 1
			end
		else
			local tp = resolveTargetPlayerByName(selectedTargetName)
			if tp then
				targets = { tp }
			else
				trashEnabled = false
				if trashToggle then pcall(function() trashToggle:SetValue(false) end) end
				WindUI:Notify({ Title = "Send Trash Stopped", Content = "Target unavailable.", Duration = 4 })
				break
			end
		end

		local sentAnyItem = false
		
		-- Try to send items based on custom UI selections
		for _, targetPlayerObj in ipairs(targets) do
			if not targetPlayerObj or targetPlayerObj.Parent ~= Players then continue end
			if stopRequested then break end
			
			-- Try to send eggs
			for itemId, amount in pairs(customUI.sendAmounts) do
				if amount > 0 and EggData[itemId] then
					local eggInventory = getPlayerEggInventory()
					local available = eggInventory[EggData[itemId].Name] or 0
					
					if available > 0 then
						-- Create a mock egg item for sending
						local eggItem = {
							uid = itemId .. "_" .. tick(), -- Unique ID
							type = EggData[itemId].Name,
							mutation = "",
							locked = false,
							placed = false
						}
						
						if sendItemToPlayer(eggItem, targetPlayerObj, "egg") then
							customUI.sendAmounts[itemId] = math.max(0, amount - 1)
							sentAnyItem = true
							break -- Send one item per cycle
						end
					end
				end
			end
			
			-- Try to send fruits (if fruit sending is implemented)
			if not sentAnyItem then
				for itemId, amount in pairs(customUI.sendAmounts) do
					if amount > 0 and FruitData[itemId] then
						local fruitInventory = getPlayerFruitInventory()
						local available = fruitInventory[FruitData[itemId].Name] or 0
						
						if available > 0 then
							-- Create a mock fruit item for sending
							local fruitItem = {
								uid = itemId .. "_" .. tick(),
								type = FruitData[itemId].Name,
								mutation = "",
								locked = false,
								placed = false
							}
							
							if sendItemToPlayer(fruitItem, targetPlayerObj, "fruit") then
								customUI.sendAmounts[itemId] = math.max(0, amount - 1)
								sentAnyItem = true
								break
							end
						end
					end
				end
			end
			
			if sentAnyItem then break end
		end

		updateStatus()
		task.wait(0.45)
		if stopRequested then break end
	end
end

-- Initialize function
function SendTrashSystem.Init(dependencies)
    WindUI = dependencies.WindUI
    Window = dependencies.Window
    Config = dependencies.Config
    local providedTab = dependencies.Tab
    
    -- Load saved webhook URL from config
    -- webhook load disabled
    
    -- Start precise event-driven watchers for T/M replication
    startDataWatchers()
    
    -- Create the Send Trash tab (or reuse provided Tab from main script)
    local TrashTab = providedTab or Window:Tab({ Title = "🗑️ | Send Trash"})
    
    -- Status display
    statusParagraph = TrashTab:Paragraph({
        Title = "Trash System Status:",
        Desc = "Loading pet information...",
        Image = "trash-2",
        ImageSize = 22
    })
    
    -- Keep tracking toggle
    keepTrackingToggle = TrashTab:Toggle({
        Title = "Keep Tracking When Empty",
        Desc = "Continue monitoring even when no items match filters",
        Value = false,
        Callback = function(state)
            keepTrackingWhenEmpty = state
            if state then
                WindUI:Notify({ Title = "Keep Tracking", Content = "Keeps monitoring when no items are available", Duration = 3 })
            else
                WindUI:Notify({ Title = "Stop When Empty", Content = "Stops when no items match filters", Duration = 3 })
            end
        end
    })
    
    
    -- Session limits removed as requested

    -- Main toggle
    trashToggle = TrashTab:Toggle({
        Title = "Send Trash",
        Desc = "Automatically send selected pets/eggs",
        Value = false,
        Callback = function(state)
			trashEnabled = state
			
			if state then
				-- Start of a new run/session: do not reset logs, only reset webhookSent
				webhookSent = false
				stopRequested = false
				-- Session limits removed
				task.spawn(function()
					syncSelectorsFromControls()
					processTrash()
				end)
				WindUI:Notify({ Title = "Send Trash", Content = "Started", Duration = 3 })
			else
				-- Graceful stop: request stop, allow in-flight send to conclude
				stopRequested = true
				WindUI:Notify({ Title = "Send Trash", Content = "Stopped", Duration = 3 })
				-- no immediate webhook here; let processTrash() handle it after it exits
			end
		end
    })
    
    TrashTab:Section({ Title = "Target Settings", Icon = "target" })
    
    -- Send mode multi-select dropdown (remove "Both" option)
    sendModeDropdown = TrashTab:Dropdown({
        Title = "Send Types",
        Desc = "Choose what types to send",
        Values = {"Pets", "Eggs", "Fruits"},
        Value = {"Pets"},
        Multi = true,
        Callback = function(selection)
            selectedSendTypes = {}
            if type(selection) == "table" then
                for k, v in pairs(selection) do
                    if v == true and type(k) == "string" then
                        table.insert(selectedSendTypes, k)
                    end
                end
            end
        end
    })
    
    -- Target player dropdown
    targetPlayerDropdown = TrashTab:Dropdown({
        Title = "Target Player",
        Desc = "Random cycles through players",
        Values = refreshPlayerList(),
        Value = "Random Player",
        Callback = function(selection)
            selectedTargetName = selection or "Random Player"
            -- Reset random target state when user changes selection
            randomTargetState.current = nil
            randomTargetState.fails = 0
        end
    })
    
    -- Refresh Target List button (placed directly below target dropdown)
    TrashTab:Button({
        Title = "Refresh Target List",
        Desc = "Update player list",
        Callback = function()
            if targetPlayerDropdown and targetPlayerDropdown.SetValues then
                local newPlayerList = refreshPlayerList()
                pcall(function() 
                    targetPlayerDropdown:SetValues(newPlayerList)
                    WindUI:Notify({
                        Title = "Target List Updated",
                        Content = "Found " .. (#newPlayerList - 1) .. " players online",
                        Duration = 2
                    })
                end)
            end
        end
    })
    
    TrashTab:Section({ Title = "Pet Speed Filters", Icon = "zap" })
    
    -- Pet minimum speed input
    petMinSpeedInput = TrashTab:Input({
        Title = "⚡ Min Pet Speed",
        Desc = "Minimum speed to send pets (supports K/M/B/T)",
        Value = "0",
        Numeric = false,
        Finished = true,
        Callback = function(value)
            local parsedValue = parseSpeedInput(value)
            petMinSpeed = parsedValue
            print("Pet min speed set to:", petMinSpeed)
        end
    })
    
    -- Pet maximum speed input
    petMaxSpeedInput = TrashTab:Input({
        Title = "⚡ Max Pet Speed", 
        Desc = "Maximum speed to send pets (supports K/M/B/T)",
        Value = "999999999",
        Numeric = false,
        Finished = true,
        Callback = function(value)
            local parsedValue = parseSpeedInput(value)
            petMaxSpeed = parsedValue
            print("Pet max speed set to:", petMaxSpeed)
        end
    })
    
    TrashTab:Section({ Title = "Item Selection", Icon = "package" })
    
    -- Custom UI Button
    TrashTab:Button({
        Title = "Open Item Selection UI",
        Desc = "Select eggs, fruits, and pets to send with custom amounts",
        Callback = function()
            if not customUI.screenGui then
                createCustomUI()
                refreshCustomUIContent()
            end
            customUI.screenGui.Enabled = true
        end
    })
    
    -- Show current selections
    local selectionStatus = TrashTab:Paragraph({
        Title = "Current Selections:",
        Desc = "No items selected",
        Image = "list",
        ImageSize = 16
    })
    
    -- Update selection status periodically
    task.spawn(function()
        while true do
            if selectionStatus and selectionStatus.SetDesc then
                local totalSelected = 0
                local totalAmount = 0
                for itemId, amount in pairs(customUI.sendAmounts) do
                    if amount > 0 then
                        totalSelected = totalSelected + 1
                        totalAmount = totalAmount + amount
                    end
                end
                
                if totalSelected > 0 then
                    selectionStatus:SetDesc(string.format("%d items selected, %d total to send", totalSelected, totalAmount))
                else
                    selectionStatus:SetDesc("No items selected")
                end
            end
            task.wait(2)
        end
    end)
    
    -- Selling UI removed per request
    
    TrashTab:Section({ Title = "🛠️ Manual Controls", Icon = "settings" })
    
    -- Webhook input (optional) - Auto-saves to config
    -- webhook UI removed
    
    -- Ensure the loaded webhook URL is displayed in the input field
    --
    
    -- Removed generic "Refresh Lists" button (target-specific refresh placed under target dropdown)
    
    -- Cache refresh button
    TrashTab:Button({
        Title = "🔄 Refresh Cache",
        Desc = "Force refresh inventory cache and clear send progress",
        Callback = function()
            forceRefreshCache()
            clearSendProgress()
            updateStatus()
            
            WindUI:Notify({
                Title = "🔄 Cache Refreshed",
                Content = "Inventory cache and send progress cleared!",
                Duration = 3
            })
        end
    })

    -- Removed: Fix Unknown Items and Force Resolve Names buttons

    -- Send current inventory webhook button
    -- webhook send button removed
    
    
    -- Register UI elements with config
    if Config then
        Config:Register("trashEnabled", trashToggle)
        Config:Register("sendTypes", sendModeDropdown)
        Config:Register("targetPlayer", targetPlayerDropdown)
        Config:Register("petMinSpeed", petMinSpeedInput)
        Config:Register("petMaxSpeed", petMaxSpeedInput)
        Config:Register("keepTrackingWhenEmpty", keepTrackingToggle)
        
        -- Save custom UI selections
        Config:SaveSetting("customUISelections", customUI.selectedItems)
        Config:SaveSetting("customUISendAmounts", customUI.sendAmounts)
        
        -- Load custom UI selections
        local savedSelections = Config:GetSetting("customUISelections")
        local savedAmounts = Config:GetSetting("customUISendAmounts")
        
        if savedSelections then
            customUI.selectedItems = savedSelections
        end
        
        if savedAmounts then
            customUI.sendAmounts = savedAmounts
        end
    end
    
    -- Initial status update
    task.spawn(function()
        task.wait(1)
        -- Ensure selectors reflect dropdowns after config load
        syncSelectorsFromControls()
        updateStatus()
    end)
end

return SendTrashSystem
