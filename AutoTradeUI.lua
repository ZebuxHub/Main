-- AutoTradeUI.lua - Custom Auto Trade System for Build A Zoo
-- Author: Zebux
-- Version: 1.0

local AutoTradeUI = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Local Player
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- UI Variables
local ScreenGui = nil
local MainFrame = nil
local isDragging = false
local dragStart = nil
local startPos = nil
local isMinimized = false
local originalSize = nil
local minimizedSize = nil

-- State Variables
local selectedTarget = "Random Player"
local currentTab = "Pets" -- "Pets", "Eggs", "Fruits"
local petMode = "Individual" -- "Individual" or "Speed"
local autoTradeEnabled = false
local petSpeedMin = 0
local petSpeedMax = 999999999

-- Data Storage
local itemConfigs = {
    pets = {}, -- {petType: {sendUntil: number, enabled: boolean}}
    eggs = {}, -- {eggType: {sendUntil: number, enabled: boolean}}
    fruits = {} -- {fruitType: {sendUntil: number, enabled: boolean}}
}

-- Filter States
local searchText = ""
local sortMode = "name_asc" -- name_asc, name_desc, owned_desc, owned_asc, price_asc, price_desc
local showZeroItems = true
local rarityFilter = "all" -- all, 1, 2, 3, 4, 5, 6
local configuredOnly = false

-- Trading State
local isTrading = false
local tradeCooldown = false
local retryAttempts = {}
local savedPosition = nil

-- External Dependencies
local WindUI = nil

-- Hardcoded Data (from existing systems)
local EggData = {
    BasicEgg = { Name = "Basic Egg", Price = "100", Icon = "rbxassetid://129248801621928", Rarity = 1 },
    RareEgg = { Name = "Rare Egg", Price = "500", Icon = "rbxassetid://71012831091414", Rarity = 2 },
    SuperRareEgg = { Name = "Super Rare Egg", Price = "2,500", Icon = "rbxassetid://93845452154351", Rarity = 2 },
    SeaweedEgg = { Name = "Seaweed Egg", Price = "200", Icon = "rbxassetid://87125339619211", Rarity = 2 },
    EpicEgg = { Name = "Epic Egg", Price = "15,000", Icon = "rbxassetid://116395645531721", Rarity = 2 },
    LegendEgg = { Name = "Legend Egg", Price = "100,000", Icon = "rbxassetid://90834918351014", Rarity = 3 },
    ClownfishEgg = { Name = "Clownfish Egg", Price = "200", Icon = "rbxassetid://124419920608938", Rarity = 3 },
    PrismaticEgg = { Name = "Prismatic Egg", Price = "1,000,000", Icon = "rbxassetid://79960683434582", Rarity = 4 },
    LionfishEgg = { Name = "Lionfish Egg", Price = "200", Icon = "rbxassetid://100181295820053", Rarity = 4 },
    HyperEgg = { Name = "Hyper Egg", Price = "2,500,000", Icon = "rbxassetid://104958288296273", Rarity = 4 },
    VoidEgg = { Name = "Void Egg", Price = "24,000,000", Icon = "rbxassetid://122396162708984", Rarity = 5 },
    BowserEgg = { Name = "Bowser Egg", Price = "130,000,000", Icon = "rbxassetid://71500536051510", Rarity = 5 },
    SharkEgg = { Name = "Shark Egg", Price = "150,000,000", Icon = "rbxassetid://71032472532652", Rarity = 5 },
    DemonEgg = { Name = "Demon Egg", Price = "400,000,000", Icon = "rbxassetid://126412407639969", Rarity = 5 },
    CornEgg = { Name = "Corn Egg", Price = "1,000,000,000", Icon = "rbxassetid://94739512852461", Rarity = 5 },
    AnglerfishEgg = { Name = "Anglerfish Egg", Price = "150,000,000", Icon = "rbxassetid://121296998588378", Rarity = 5 },
    BoneDragonEgg = { Name = "Bone Dragon Egg", Price = "2,000,000,000", Icon = "rbxassetid://83209913424562", Rarity = 5 },
    UltraEgg = { Name = "Ultra Egg", Price = "10,000,000,000", Icon = "rbxassetid://83909590718799", Rarity = 6 },
    DinoEgg = { Name = "Dino Egg", Price = "10,000,000,000", Icon = "rbxassetid://80783528632315", Rarity = 6 },
    FlyEgg = { Name = "Fly Egg", Price = "999,999,999,999", Icon = "rbxassetid://109240587278187", Rarity = 6 },
    UnicornEgg = { Name = "Unicorn Egg", Price = "40,000,000,000", Icon = "rbxassetid://123427249205445", Rarity = 6 },
    AncientEgg = { Name = "Ancient Egg", Price = "999,999,999,999", Icon = "rbxassetid://113910587565739", Rarity = 6 },
    SeaDragonEgg = { Name = "Sea Dragon Egg", Price = "999,999,999,999", Icon = "rbxassetid://130514093439717", Rarity = 6 },
    UnicornProEgg = { Name = "Unicorn Pro Egg", Price = "50,000,000,000", Icon = "rbxassetid://140138063696377", Rarity = 6 },
    SnowbunnyEgg = { Name = "Snowbunny Egg", Price = "1,500,000", Icon = "rbxassetid://136223941487914", Rarity = 3 },
    DarkGoatyEgg = { Name = "Dark Goaty Egg", Price = "100,000,000", Icon = "rbxassetid://95956060312947", Rarity = 4 },
    RhinoRockEgg = { Name = "Rhino Rock Egg", Price = "3,000,000,000", Icon = "rbxassetid://131221831910623", Rarity = 5 },
    SaberCubEgg = { Name = "Saber Cub Egg", Price = "40,000,000,000", Icon = "rbxassetid://111953502835346", Rarity = 6 },
    GeneralKongEgg = { Name = "General Kong Egg", Price = "80,000,000,000", Icon = "rbxassetid://106836613554535", Rarity = 6 },
    PegasusEgg = { Name = "Pegasus Egg", Price = "999,999,999,999", Icon = "rbxassetid://83004379343725", Rarity = 6 },
    OctopusEgg = { Name = "Octopus Egg", Price = "10,000,000,000", Icon = "rbxassetid://84758700095552", Rarity = 6 }
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
    Durian = { Name = "Durian", Price = "80,000,000,000", Icon = "🥥", Rarity = 6 },
    DragonFruit = { Name = "Dragon Fruit", Price = "1,500,000,000", Icon = "🐲", Rarity = 6 }
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

-- macOS Dark Theme Colors
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
    close = Color3.fromRGB(255, 69, 58),
    minimize = Color3.fromRGB(255, 159, 10),
    maximize = Color3.fromRGB(48, 209, 88),
    success = Color3.fromRGB(48, 209, 88),
    warning = Color3.fromRGB(255, 159, 10),
    error = Color3.fromRGB(255, 69, 58),
    disabled = Color3.fromRGB(100, 100, 100)
}

-- Utility Functions
local function formatNumber(num)
    if type(num) == "string" then return num end
    if num >= 1e12 then return string.format("%.1fT", num / 1e12)
    elseif num >= 1e9 then return string.format("%.1fB", num / 1e9)
    elseif num >= 1e6 then return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then return string.format("%.1fK", num / 1e3)
    else return tostring(num) end
end

local function parsePrice(priceStr)
    if type(priceStr) == "number" then return priceStr end
    local cleanPrice = priceStr:gsub(",", "")
    return tonumber(cleanPrice) or 0
end

local function getRarityColor(rarity)
    if rarity >= 6 then return Color3.fromRGB(255, 45, 85)
    elseif rarity >= 5 then return Color3.fromRGB(255, 69, 58)
    elseif rarity >= 4 then return Color3.fromRGB(175, 82, 222)
    elseif rarity >= 3 then return Color3.fromRGB(88, 86, 214)
    elseif rarity >= 2 then return Color3.fromRGB(48, 209, 88)
    else return Color3.fromRGB(174, 174, 178) end
end

local function safeGetAttribute(obj, attrName, default)
    if not obj then return default end
    local success, result = pcall(function() return obj:GetAttribute(attrName) end)
    return success and result or default
end

-- Tooltip System
local activeTooltip = nil
local function createTooltip(text, parent, targetElement)
    if activeTooltip then
        activeTooltip:Destroy()
        activeTooltip = nil
    end
    
    local tooltip = Instance.new("TextLabel")
    tooltip.Name = "Tooltip"
    tooltip.Size = UDim2.new(0, 200, 0, 40)
    tooltip.Position = UDim2.new(0, 0, 0, -45)
    tooltip.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    tooltip.BorderSizePixel = 0
    tooltip.Text = text
    tooltip.TextSize = 10
    tooltip.Font = Enum.Font.Gotham
    tooltip.TextColor3 = Color3.fromRGB(255, 255, 255)
    tooltip.TextWrapped = true
    tooltip.TextXAlignment = Enum.TextXAlignment.Center
    tooltip.TextYAlignment = Enum.TextYAlignment.Center
    tooltip.ZIndex = 300 -- Even higher to ensure it's above dropdowns
    tooltip.Parent = targetElement
    
    local tooltipCorner = Instance.new("UICorner")
    tooltipCorner.CornerRadius = UDim.new(0, 4)
    tooltipCorner.Parent = tooltip
    
    local tooltipStroke = Instance.new("UIStroke")
    tooltipStroke.Color = Color3.fromRGB(80, 80, 80)
    tooltipStroke.Thickness = 1
    tooltipStroke.Parent = tooltip
    
    activeTooltip = tooltip
    return tooltip
end

local function hideTooltip()
    if activeTooltip then
        activeTooltip:Destroy()
        activeTooltip = nil
    end
end

-- Forward declaration
local refreshContent

-- Daily Gift Functions
local function getTodayGiftCount()
    if not LocalPlayer or not LocalPlayer.PlayerGui or not LocalPlayer.PlayerGui.Data then
        return 0
    end
    
    local userFlag = LocalPlayer.PlayerGui.Data:FindFirstChild("UserFlag")
    if not userFlag then return 0 end
    
    return safeGetAttribute(userFlag, "TodaySendGiftCount", 0)
end

local function updateGiftCountDisplay()
    if not ScreenGui then return end
    
    local targetSection = ScreenGui.MainFrame:FindFirstChild("TargetSection")
    if not targetSection then return end
    
    local giftCountLabel = targetSection:FindFirstChild("GiftCountLabel")
    if not giftCountLabel then return end
    
    local currentCount = getTodayGiftCount()
    giftCountLabel.Text = "Today Gift: " .. currentCount .. "/200"
    
    -- Change color if approaching or at limit
    if currentCount >= 200 then
        giftCountLabel.TextColor3 = colors.error or Color3.fromRGB(255, 69, 58)
    elseif currentCount >= 180 then
        giftCountLabel.TextColor3 = colors.warning or Color3.fromRGB(255, 149, 0)
    else
        giftCountLabel.TextColor3 = colors.textSecondary
    end
end

-- Inventory Functions
local function getPlayerInventory()
    local inventory = { pets = {}, eggs = {}, fruits = {} }
    
    if not LocalPlayer or not LocalPlayer.PlayerGui or not LocalPlayer.PlayerGui.Data then
        return inventory
    end
    
    -- Get Pets (exclude placed pets with D attribute)
    local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
    if petsFolder then
        for _, petData in pairs(petsFolder:GetChildren()) do
            if petData:IsA("Configuration") then
                local petType = safeGetAttribute(petData, "T", nil)
                local isPlaced = safeGetAttribute(petData, "D", nil) ~= nil
                if petType and petType ~= "" and not isPlaced then
                    inventory.pets[petType] = (inventory.pets[petType] or 0) + 1
                end
            end
        end
    end
    
    -- Get Eggs (exclude placed eggs with D attribute)
    local eggsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
    if eggsFolder then
        for _, eggData in pairs(eggsFolder:GetChildren()) do
            if eggData:IsA("Configuration") then
                local eggType = safeGetAttribute(eggData, "T", nil)
                local isPlaced = safeGetAttribute(eggData, "D", nil) ~= nil
                if eggType and eggType ~= "" and not isPlaced then
                    inventory.eggs[eggType] = (inventory.eggs[eggType] or 0) + 1
                end
            end
        end
    end
    
    -- Get Fruits
    local asset = LocalPlayer.PlayerGui.Data:FindFirstChild("Asset")
    if asset then
        for id, item in pairs(FruitData) do
            local amount = safeGetAttribute(asset, item.Name, 0)
            if type(amount) == "string" then amount = tonumber(amount) or 0 end
            if amount > 0 then
                inventory.fruits[id] = amount
            end
        end
    end
    
    return inventory
end

local function getPetSpeed(petUID)
    local lp = Players.LocalPlayer
    local pg = lp and lp:FindFirstChild("PlayerGui")
    local ss = pg and pg:FindFirstChild("ScreenStorage")
    local frame = ss and ss:FindFirstChild("Frame")
    local content = frame and frame:FindFirstChild("ContentPet")
    local scroll = content and content:FindFirstChild("ScrollingFrame")
    local item = scroll and scroll:FindFirstChild(petUID)
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

-- Player Functions
local function getPlayerList()
    local playerList = {"Random Player"}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerList, player.Name)
        end
    end
    return playerList
end

local function getRandomPlayer()
    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(players, player)
        end
    end
    if #players > 0 then
        return players[math.random(1, #players)]
    end
    return nil
end

local function getPlayerByName(name)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name == name or player.DisplayName == name then
            return player
        end
    end
    return nil
end

-- Trading Functions
local function saveCurrentPosition()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        savedPosition = LocalPlayer.Character.HumanoidRootPart.CFrame
    end
end

local function isNearPlayer(targetPlayer, maxDistance)
    maxDistance = maxDistance or 50 -- Default 50 studs
    
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local distance = (LocalPlayer.Character.HumanoidRootPart.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
    return distance <= maxDistance
end

local function returnToSavedPosition()
    if savedPosition and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = savedPosition
        savedPosition = nil -- Clear saved position after returning
    end
end

local function teleportToPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false, "Target player not found or no character"
    end
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false, "Local player has no character"
    end
    
    -- Check if we're already near the target player
    if isNearPlayer(targetPlayer, 50) then
        return true -- No need to teleport, already close enough
    end
    
    local success, err = pcall(function()
        LocalPlayer.Character.HumanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(5, 0, 0)
    end)
    
    return success, err and tostring(err) or nil
end

local function focusItem(itemUID)
    local success, err = pcall(function()
        local args = {"Focus", itemUID}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    return success, err and tostring(err) or nil
end

local function giftToPlayer(targetPlayer)
    local success, err = pcall(function()
        local args = {targetPlayer}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(unpack(args))
    end)
    return success, err and tostring(err) or nil
end

local function performTrade(itemUID, itemType, targetPlayer, shouldReturnToPosition)
    if isTrading or tradeCooldown then
        return false, "Trade in progress or cooldown active"
    end
    
    -- Check daily gift limit
    local currentGiftCount = getTodayGiftCount()
    if currentGiftCount >= 200 then
        if WindUI then
            WindUI:Notify({
                Title = "🚫 Daily Limit Reached",
                Content = "You've reached the daily gift limit of 200. Cannot send more items today.",
                Duration = 5
            })
        end
        return false, "Daily gift limit reached (200/200)"
    end
    
    isTrading = true
    local tradeKey = itemUID .. "_" .. (targetPlayer and targetPlayer.Name or "random")
    
    -- Save position only if not already saved
    if not savedPosition then
        saveCurrentPosition()
    end
    
    -- Get target player
    local target = targetPlayer
    if not target and selectedTarget == "Random Player" then
        target = getRandomPlayer()
    elseif not target and selectedTarget ~= "Random Player" then
        target = getPlayerByName(selectedTarget)
    end
    
    if not target then
        isTrading = false
        if shouldReturnToPosition then
            returnToSavedPosition()
        end
        return false, "No target player available"
    end
    
    -- Teleport to player
    local tpSuccess, tpErr = teleportToPlayer(target)
    if not tpSuccess then
        isTrading = false
        if shouldReturnToPosition then
            returnToSavedPosition()
        end
        
        -- Increment retry count
        retryAttempts[tradeKey] = (retryAttempts[tradeKey] or 0) + 1
        if retryAttempts[tradeKey] >= 5 then
            retryAttempts[tradeKey] = 0
            if WindUI then
                WindUI:Notify({
                    Title = "❌ Trade Failed",
                    Content = "Failed to teleport to " .. target.Name .. " after 5 attempts",
                    Duration = 5
                })
            end
            return false, "Teleport failed after 5 attempts"
        end
        
        return false, "Teleport failed: " .. (tpErr or "Unknown error")
    end
    
    -- Wait a moment for teleport to complete
    task.wait(0.5)
    
    -- Focus item
    local focusSuccess, focusErr = focusItem(itemUID)
    if not focusSuccess then
        isTrading = false
        if shouldReturnToPosition then
            returnToSavedPosition()
        end
        return false, "Failed to focus item: " .. (focusErr or "Unknown error")
    end
    
    -- Wait for focus
    task.wait(0.2)
    
    -- Gift to player
    local giftSuccess, giftErr = giftToPlayer(target)
    if not giftSuccess then
        isTrading = false
        if shouldReturnToPosition then
            returnToSavedPosition()
        end
        return false, "Failed to gift item: " .. (giftErr or "Unknown error")
    end
    
    -- Wait for gift to process
    task.wait(0.5)
    
    -- Only return to saved position if requested (for manual trades or when auto-trade is done)
    if shouldReturnToPosition then
        returnToSavedPosition()
    end
    
    -- Reset retry count on success
    retryAttempts[tradeKey] = 0
    
    -- Set cooldown
    tradeCooldown = true
    task.spawn(function()
        task.wait(1) -- 1 second cooldown
        tradeCooldown = false
    end)
    
    isTrading = false
    
    -- Send webhook notification if available
    if _G.WebhookSystem and _G.WebhookSystem.SendTradeWebhook then
        local fromItems = {{
            type = itemType,
            mutation = "",
            count = 1
        }}
        _G.WebhookSystem.SendTradeWebhook(LocalPlayer.Name, target.Name, fromItems, {})
    end
    
    return true, "Trade successful"
end

-- Auto Trade Logic
local function shouldSendItem(itemType, category, ownedAmount)
    local config = itemConfigs[category][itemType]
    if not config or not config.enabled then return false end
    
    local sendUntil = config.sendUntil or 0
    return ownedAmount > sendUntil
end

local function getItemsToSend()
    local inventory = getPlayerInventory()
    local itemsToSend = {}
    
    -- Check Eggs
    for eggType, ownedAmount in pairs(inventory.eggs) do
        if shouldSendItem(eggType, "eggs", ownedAmount) then
            -- Find egg UID from inventory
            local eggsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
            if eggsFolder then
                for _, eggData in pairs(eggsFolder:GetChildren()) do
                    if eggData:IsA("Configuration") then
                        local eggDataType = safeGetAttribute(eggData, "T", nil)
                        if eggDataType == eggType then
                            table.insert(itemsToSend, {
                                uid = eggData.Name,
                                type = eggType,
                                category = "eggs"
                            })
                            break -- Only send one at a time
                        end
                    end
                end
            end
        end
    end
    
    -- Check Fruits
    for fruitType, ownedAmount in pairs(inventory.fruits) do
        if shouldSendItem(fruitType, "fruits", ownedAmount) then
            -- For fruits, we need to find the fruit UID differently
            -- This might need adjustment based on how fruits are stored
            table.insert(itemsToSend, {
                uid = fruitType, -- This might need to be adjusted
                type = fruitType,
                category = "fruits"
            })
        end
    end
    
    -- Check Pets
    if petMode == "Speed" then
        -- Speed mode: send all pets in speed range
        local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
        if petsFolder then
            for _, petData in pairs(petsFolder:GetChildren()) do
                if petData:IsA("Configuration") then
                    local petType = safeGetAttribute(petData, "T", nil)
                    if petType and petType ~= "" then
                        local petSpeed = getPetSpeed(petData.Name)
                        if petSpeed >= petSpeedMin and petSpeed <= petSpeedMax then
                            table.insert(itemsToSend, {
                                uid = petData.Name,
                                type = petType,
                                category = "pets"
                            })
                        end
                    end
                end
            end
        end
    else
        -- Individual mode: check configured pets
        for petType, ownedAmount in pairs(inventory.pets) do
            if shouldSendItem(petType, "pets", ownedAmount) then
                -- Find pet UID from inventory
                local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
                if petsFolder then
                    for _, petData in pairs(petsFolder:GetChildren()) do
                        if petData:IsA("Configuration") then
                            local petDataType = safeGetAttribute(petData, "T", nil)
                            if petDataType == petType then
                                table.insert(itemsToSend, {
                                    uid = petData.Name,
                                    type = petType,
                                    category = "pets"
                                })
                                break -- Only send one at a time
                            end
                        end
                    end
                end
            end
        end
    end
    
    return itemsToSend
end

local autoTradeConnection = nil
local function startAutoTrade()
    if autoTradeConnection then
        autoTradeConnection:Disconnect()
    end
    
    autoTradeConnection = RunService.Heartbeat:Connect(function()
        if not autoTradeEnabled or isTrading then return end
        
        -- Check daily gift limit before attempting to trade
        local currentGiftCount = getTodayGiftCount()
        if currentGiftCount >= 200 then
            -- Stop auto-trade and notify user
            autoTradeEnabled = false
            if ScreenGui and ScreenGui.MainFrame and ScreenGui.MainFrame.TargetSection then
                local autoTradeToggle = ScreenGui.MainFrame.TargetSection:FindFirstChild("AutoTradeToggle")
                if autoTradeToggle then
                    autoTradeToggle.Text = "Auto Trade: OFF"
                    autoTradeToggle.BackgroundColor3 = colors.hover
                end
            end
            
            if WindUI then
                WindUI:Notify({
                    Title = "🚫 Auto Trade Stopped",
                    Content = "Daily gift limit reached (200/200). Auto-trade has been disabled.",
                    Duration = 5
                })
            end
            return
        end
        
        local itemsToSend = getItemsToSend()
        if #itemsToSend > 0 then
            local item = itemsToSend[1] -- Send one item at a time
            -- Don't return to position during auto-trade, only when stopping
            local success, err = performTrade(item.uid, item.type, nil, false)
            if not success and WindUI then
                WindUI:Notify({
                    Title = "❌ Auto Trade Error",
                    Content = err or "Unknown error",
                    Duration = 3
                })
            end
        else
            -- No more items to send, return to saved position if we have one
            if savedPosition then
                returnToSavedPosition()
            end
        end
        
        task.wait(0.1) -- Small delay to prevent excessive checking
    end)
end

local function stopAutoTrade()
    if autoTradeConnection then
        autoTradeConnection:Disconnect()
        autoTradeConnection = nil
    end
    -- Return to saved position when stopping auto-trade
    if savedPosition then
        returnToSavedPosition()
    end
end

-- Config System
local function saveConfig()
    local configData = {
        itemConfigs = itemConfigs,
        petMode = petMode,
        petSpeedMin = petSpeedMin,
        petSpeedMax = petSpeedMax,
        currentTab = currentTab,
        searchText = searchText,
        sortMode = sortMode,
        showZeroItems = showZeroItems,
        rarityFilter = rarityFilter,
        configuredOnly = configuredOnly
    }
    
    local success, err = pcall(function()
        if not isfolder("Zebux") then makefolder("Zebux") end
        if not isfolder("Zebux/AutoTrade") then makefolder("Zebux/AutoTrade") end
        writefile("Zebux/AutoTrade/config.json", HttpService:JSONEncode(configData))
    end)
    
    return success
end

local function loadConfig()
    local success, configData = pcall(function()
        if isfile("Zebux/AutoTrade/config.json") then
            return HttpService:JSONDecode(readfile("Zebux/AutoTrade/config.json"))
        end
        return nil
    end)
    
    if success and configData then
        itemConfigs = configData.itemConfigs or itemConfigs
        petMode = configData.petMode or petMode
        petSpeedMin = configData.petSpeedMin or petSpeedMin
        petSpeedMax = configData.petSpeedMax or petSpeedMax
        currentTab = configData.currentTab or currentTab
        searchText = configData.searchText or searchText
        sortMode = configData.sortMode or sortMode
        showZeroItems = configData.showZeroItems ~= nil and configData.showZeroItems or showZeroItems
        rarityFilter = configData.rarityFilter or rarityFilter
        configuredOnly = configData.configuredOnly ~= nil and configData.configuredOnly or configuredOnly
    end
end

-- UI Creation Functions
local function createWindowControls(parent)
    local controlsContainer = Instance.new("Frame")
    controlsContainer.Name = "WindowControls"
    controlsContainer.Size = UDim2.new(0, 70, 0, 12)
    controlsContainer.Position = UDim2.new(0, 12, 0, 12)
    controlsContainer.BackgroundTransparency = 1
    controlsContainer.Parent = parent
    
    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 12, 0, 12)
    closeBtn.Position = UDim2.new(0, 0, 0, 0)
    closeBtn.BackgroundColor3 = colors.close
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = ""
    closeBtn.Parent = controlsContainer
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0.5, 0)
    closeCorner.Parent = closeBtn
    
    -- Minimize Button
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Name = "MinimizeBtn"
    minimizeBtn.Size = UDim2.new(0, 12, 0, 12)
    minimizeBtn.Position = UDim2.new(0, 18, 0, 0)
    minimizeBtn.BackgroundColor3 = colors.minimize
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Text = ""
    minimizeBtn.Parent = controlsContainer
    
    local minimizeCorner = Instance.new("UICorner")
    minimizeCorner.CornerRadius = UDim.new(0.5, 0)
    minimizeCorner.Parent = minimizeBtn
    
    return controlsContainer
end

local function createTargetSection(parent)
    local targetSection = Instance.new("Frame")
    targetSection.Name = "TargetSection"
    targetSection.Size = UDim2.new(0.35, -8, 1, -80)
    targetSection.Position = UDim2.new(0, 16, 0, 80)
    targetSection.BackgroundColor3 = colors.surface
    targetSection.BorderSizePixel = 0
    targetSection.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = targetSection
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = targetSection
    
    -- Target Player Avatar (placeholder)
    local avatar = Instance.new("ImageLabel")
    avatar.Name = "Avatar"
    avatar.Size = UDim2.new(0, 80, 0, 80)
    avatar.Position = UDim2.new(0.5, -40, 0, 20)
    avatar.BackgroundColor3 = colors.hover
    avatar.BorderSizePixel = 0
    avatar.Image = "" -- Will be set dynamically
    avatar.Parent = targetSection
    
    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(0, 8)
    avatarCorner.Parent = avatar
    
    -- Target Player Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -20, 0, 30)
    nameLabel.Position = UDim2.new(0, 10, 0, 110)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = selectedTarget
    nameLabel.TextSize = 16
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextColor3 = colors.text
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.TextWrapped = true
    nameLabel.Parent = targetSection
    
    -- Target Selection Dropdown
    local targetDropdown = Instance.new("TextButton")
    targetDropdown.Name = "TargetDropdown"
    targetDropdown.Size = UDim2.new(1, -20, 0, 35)
    targetDropdown.Position = UDim2.new(0, 10, 0, 150)
    targetDropdown.BackgroundColor3 = colors.hover
    targetDropdown.BorderSizePixel = 0
    targetDropdown.Text = "Select Target ▼"
    targetDropdown.TextSize = 14
    targetDropdown.Font = Enum.Font.Gotham
    targetDropdown.TextColor3 = colors.text
    targetDropdown.Parent = targetSection
    
    local dropdownCorner = Instance.new("UICorner")
    dropdownCorner.CornerRadius = UDim.new(0, 6)
    dropdownCorner.Parent = targetDropdown
    
    -- Dropdown List (initially hidden)
    local dropdownList = Instance.new("ScrollingFrame")
    dropdownList.Name = "DropdownList"
    dropdownList.Size = UDim2.new(1, -20, 0, 120)
    dropdownList.Position = UDim2.new(0, 10, 0, 190)
    dropdownList.BackgroundColor3 = colors.surface
    dropdownList.BorderSizePixel = 0
    dropdownList.Visible = false
    dropdownList.ScrollBarThickness = 4
    dropdownList.ScrollBarImageColor3 = colors.primary
    dropdownList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    dropdownList.ScrollingDirection = Enum.ScrollingDirection.Y
    dropdownList.ZIndex = 100
    dropdownList.Parent = targetSection
    
    local dropdownListCorner = Instance.new("UICorner")
    dropdownListCorner.CornerRadius = UDim.new(0, 6)
    dropdownListCorner.Parent = dropdownList
    
    local dropdownListStroke = Instance.new("UIStroke")
    dropdownListStroke.Color = colors.border
    dropdownListStroke.Thickness = 1
    dropdownListStroke.Parent = dropdownList
    
    local dropdownLayout = Instance.new("UIListLayout")
    dropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
    dropdownLayout.Padding = UDim.new(0, 2)
    dropdownLayout.Parent = dropdownList
    
    -- Send Button
    local sendBtn = Instance.new("TextButton")
    sendBtn.Name = "SendBtn"
    sendBtn.Size = UDim2.new(1, -20, 0, 40)
    sendBtn.Position = UDim2.new(0, 10, 0, 200)
    sendBtn.BackgroundColor3 = colors.primary
    sendBtn.BorderSizePixel = 0
    sendBtn.Text = "Send Now"
    sendBtn.TextSize = 16
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    sendBtn.Parent = targetSection
    
    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 8)
    sendCorner.Parent = sendBtn
    
    -- Auto Trade Toggle
    local autoTradeToggle = Instance.new("TextButton")
    autoTradeToggle.Name = "AutoTradeToggle"
    autoTradeToggle.Size = UDim2.new(1, -20, 0, 35)
    autoTradeToggle.Position = UDim2.new(0, 10, 0, 250)
    autoTradeToggle.BackgroundColor3 = autoTradeEnabled and colors.success or colors.hover
    autoTradeToggle.BorderSizePixel = 0
    autoTradeToggle.Text = autoTradeEnabled and "Auto Trade: ON" or "Auto Trade: OFF"
    autoTradeToggle.TextSize = 14
    autoTradeToggle.Font = Enum.Font.GothamSemibold
    autoTradeToggle.TextColor3 = colors.text
    autoTradeToggle.Parent = targetSection
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 6)
    toggleCorner.Parent = autoTradeToggle
    
    -- Daily Gift Counter Display
    local giftCountLabel = Instance.new("TextLabel")
    giftCountLabel.Name = "GiftCountLabel"
    giftCountLabel.Size = UDim2.new(1, -20, 0, 25)
    giftCountLabel.Position = UDim2.new(0, 10, 0, 295)
    giftCountLabel.BackgroundTransparency = 1
    giftCountLabel.Text = "Today Gift: 0/200"
    giftCountLabel.TextSize = 12
    giftCountLabel.Font = Enum.Font.Gotham
    giftCountLabel.TextColor3 = colors.textSecondary
    giftCountLabel.TextXAlignment = Enum.TextXAlignment.Center
    giftCountLabel.Parent = targetSection
    
    return targetSection
end

local function createFilterBar(parent)
    local filterBar = Instance.new("Frame")
    filterBar.Name = "FilterBar"
    filterBar.Size = UDim2.new(0.65, -8, 0, 50)
    filterBar.Position = UDim2.new(0.35, 8, 0, 80)
    filterBar.BackgroundColor3 = colors.surface
    filterBar.BorderSizePixel = 0
    filterBar.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = filterBar
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = filterBar
    
    -- Search Box
    local searchBox = Instance.new("TextBox")
    searchBox.Name = "SearchBox"
    searchBox.Size = UDim2.new(0.3, -5, 0, 30)
    searchBox.Position = UDim2.new(0, 10, 0, 10)
    searchBox.BackgroundColor3 = colors.hover
    searchBox.BorderSizePixel = 0
    searchBox.Text = searchText
    searchBox.PlaceholderText = "Search..."
    searchBox.TextSize = 12
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextColor3 = colors.text
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.Parent = filterBar
    
    local searchCorner = Instance.new("UICorner")
    searchCorner.CornerRadius = UDim.new(0, 4)
    searchCorner.Parent = searchBox
    
    -- Sort Dropdown
    local sortBtn = Instance.new("TextButton")
    sortBtn.Name = "SortBtn"
    sortBtn.Size = UDim2.new(0.2, -5, 0, 30)
    sortBtn.Position = UDim2.new(0.3, 5, 0, 10)
    sortBtn.BackgroundColor3 = colors.hover
    sortBtn.BorderSizePixel = 0
    sortBtn.Text = "Sort: Name ▼"
    sortBtn.TextSize = 12
    sortBtn.Font = Enum.Font.Gotham
    sortBtn.TextColor3 = colors.text
    sortBtn.Parent = filterBar
    
    local sortCorner = Instance.new("UICorner")
    sortCorner.CornerRadius = UDim.new(0, 4)
    sortCorner.Parent = sortBtn
    
    -- Sort Dropdown List
    local sortList = Instance.new("Frame")
    sortList.Name = "SortList"
    sortList.Size = UDim2.new(0.2, -5, 0, 120)
    sortList.Position = UDim2.new(0.3, 5, 0, 45)
    sortList.BackgroundColor3 = colors.surface
    sortList.BorderSizePixel = 0
    sortList.Visible = false
    sortList.ZIndex = 100
    sortList.Parent = filterBar
    
    local sortListCorner = Instance.new("UICorner")
    sortListCorner.CornerRadius = UDim.new(0, 4)
    sortListCorner.Parent = sortList
    
    local sortListStroke = Instance.new("UIStroke")
    sortListStroke.Color = colors.border
    sortListStroke.Thickness = 1
    sortListStroke.Parent = sortList
    
    local sortLayout = Instance.new("UIListLayout")
    sortLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sortLayout.Padding = UDim.new(0, 1)
    sortLayout.Parent = sortList
    
    -- Sort Options
    local sortOptions = {
        {text = "Name A-Z", mode = "name_asc"},
        {text = "Name Z-A", mode = "name_desc"},
        {text = "Most Owned", mode = "owned_desc"},
        {text = "Least Owned", mode = "owned_asc"}
    }
    
    for i, option in ipairs(sortOptions) do
        local sortOption = Instance.new("TextButton")
        sortOption.Name = "SortOption" .. i
        sortOption.Size = UDim2.new(1, 0, 0, 25)
        sortOption.BackgroundColor3 = colors.hover
        sortOption.BorderSizePixel = 0
        sortOption.Text = option.text
        sortOption.TextSize = 11
        sortOption.Font = Enum.Font.Gotham
        sortOption.TextColor3 = colors.text
        sortOption.TextXAlignment = Enum.TextXAlignment.Left
        sortOption.ZIndex = 101 -- Higher than the dropdown container
        sortOption.Parent = sortList
        
        local optionPadding = Instance.new("UIPadding")
        optionPadding.PaddingLeft = UDim.new(0, 8)
        optionPadding.Parent = sortOption
        
        sortOption.MouseEnter:Connect(function()
            sortOption.BackgroundColor3 = colors.primary
        end)
        
        sortOption.MouseLeave:Connect(function()
            sortOption.BackgroundColor3 = colors.hover
        end)
        
        sortOption.MouseButton1Click:Connect(function()
            sortMode = option.mode
            sortBtn.Text = "Sort: " .. option.text:gsub(" ", "") .. " ▼"
            sortList.Visible = false
            saveConfig()
            refreshContent()
        end)
    end
    
    -- Show Zero Toggle
    local zeroToggle = Instance.new("TextButton")
    zeroToggle.Name = "ZeroToggle"
    zeroToggle.Size = UDim2.new(0.15, -5, 0, 30)
    zeroToggle.Position = UDim2.new(0.5, 5, 0, 10)
    zeroToggle.BackgroundColor3 = showZeroItems and colors.primary or colors.hover
    zeroToggle.BorderSizePixel = 0
    zeroToggle.Text = "Show 0x"
    zeroToggle.TextSize = 12
    zeroToggle.Font = Enum.Font.Gotham
    zeroToggle.TextColor3 = colors.text
    zeroToggle.Parent = filterBar
    
    local zeroCorner = Instance.new("UICorner")
    zeroCorner.CornerRadius = UDim.new(0, 4)
    zeroCorner.Parent = zeroToggle
    
    -- Configured Only Toggle
    local configToggle = Instance.new("TextButton")
    configToggle.Name = "ConfigToggle"
    configToggle.Size = UDim2.new(0.2, -5, 0, 30)
    configToggle.Position = UDim2.new(0.65, 5, 0, 10)
    configToggle.BackgroundColor3 = configuredOnly and colors.primary or colors.hover
    configToggle.BorderSizePixel = 0
    configToggle.Text = "Configured"
    configToggle.TextSize = 12
    configToggle.Font = Enum.Font.Gotham
    configToggle.TextColor3 = colors.text
    configToggle.Parent = filterBar
    
    local configCorner = Instance.new("UICorner")
    configCorner.CornerRadius = UDim.new(0, 4)
    configCorner.Parent = configToggle
    
    -- Tooltip for Configured filter
    local configTooltip = Instance.new("TextLabel")
    configTooltip.Name = "ConfigTooltip"
    configTooltip.Size = UDim2.new(0, 200, 0, 40)
    configTooltip.Position = UDim2.new(0.65, 5, 0, 45)
    configTooltip.BackgroundColor3 = colors.background
    configTooltip.BorderSizePixel = 0
    configTooltip.Text = "Show only items with 'Send until' values configured"
    configTooltip.TextSize = 10
    configTooltip.Font = Enum.Font.Gotham
    configTooltip.TextColor3 = colors.text
    configTooltip.TextWrapped = true
    configTooltip.TextXAlignment = Enum.TextXAlignment.Center
    configTooltip.TextYAlignment = Enum.TextYAlignment.Center
    configTooltip.Visible = false
    configTooltip.Parent = filterBar
    
    local tooltipCorner = Instance.new("UICorner")
    tooltipCorner.CornerRadius = UDim.new(0, 4)
    tooltipCorner.Parent = configTooltip
    
    local tooltipStroke = Instance.new("UIStroke")
    tooltipStroke.Color = colors.border
    tooltipStroke.Thickness = 1
    tooltipStroke.Parent = configTooltip
    
    -- Tooltip hover events
    configToggle.MouseEnter:Connect(function()
        createTooltip("Show only items with 'Send until' values configured", filterBar, configToggle)
    end)
    
    configToggle.MouseLeave:Connect(function()
        hideTooltip()
    end)
    
    return filterBar
end

local function createTabSection(parent)
    local tabSection = Instance.new("Frame")
    tabSection.Name = "TabSection"
    tabSection.Size = UDim2.new(0.65, -8, 1, -140)
    tabSection.Position = UDim2.new(0.35, 8, 0, 140)
    tabSection.BackgroundColor3 = colors.surface
    tabSection.BorderSizePixel = 0
    tabSection.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = tabSection
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = tabSection
    
    -- Tab Buttons
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(1, -20, 0, 40)
    tabContainer.Position = UDim2.new(0, 10, 0, 10)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = tabSection
    
    local petsTab = Instance.new("TextButton")
    petsTab.Name = "PetsTab"
    petsTab.Size = UDim2.new(0.33, -4, 1, 0)
    petsTab.Position = UDim2.new(0, 0, 0, 0)
    petsTab.BackgroundColor3 = currentTab == "Pets" and colors.primary or colors.hover
    petsTab.BorderSizePixel = 0
    petsTab.Text = "Pets"
    petsTab.TextSize = 14
    petsTab.Font = Enum.Font.GothamSemibold
    petsTab.TextColor3 = colors.text
    petsTab.Parent = tabContainer
    
    local petsCorner = Instance.new("UICorner")
    petsCorner.CornerRadius = UDim.new(0, 6)
    petsCorner.Parent = petsTab
    
    local eggsTab = Instance.new("TextButton")
    eggsTab.Name = "EggsTab"
    eggsTab.Size = UDim2.new(0.33, -4, 1, 0)
    eggsTab.Position = UDim2.new(0.33, 2, 0, 0)
    eggsTab.BackgroundColor3 = currentTab == "Eggs" and colors.primary or colors.hover
    eggsTab.BorderSizePixel = 0
    eggsTab.Text = "Eggs"
    eggsTab.TextSize = 14
    eggsTab.Font = Enum.Font.GothamSemibold
    eggsTab.TextColor3 = colors.text
    eggsTab.Parent = tabContainer
    
    local eggsCorner = Instance.new("UICorner")
    eggsCorner.CornerRadius = UDim.new(0, 6)
    eggsCorner.Parent = eggsTab
    
    local fruitsTab = Instance.new("TextButton")
    fruitsTab.Name = "FruitsTab"
    fruitsTab.Size = UDim2.new(0.33, -4, 1, 0)
    fruitsTab.Position = UDim2.new(0.66, 4, 0, 0)
    fruitsTab.BackgroundColor3 = currentTab == "Fruits" and colors.primary or colors.hover
    fruitsTab.BorderSizePixel = 0
    fruitsTab.Text = "Fruits"
    fruitsTab.TextSize = 14
    fruitsTab.Font = Enum.Font.GothamSemibold
    fruitsTab.TextColor3 = colors.text
    fruitsTab.Parent = tabContainer
    
    local fruitsCorner = Instance.new("UICorner")
    fruitsCorner.CornerRadius = UDim.new(0, 6)
    fruitsCorner.Parent = fruitsTab
    
    -- Content Area
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -20, 1, -70)
    contentArea.Position = UDim2.new(0, 10, 0, 60)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = tabSection
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = colors.primary
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    scrollFrame.Parent = contentArea
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = scrollFrame
    
    return tabSection
end

-- Item Card Creation
local function createItemCard(itemId, itemData, category, parent)
    local inventory = getPlayerInventory()
    local ownedAmount = 0
    
    if category == "pets" then
        ownedAmount = inventory.pets[itemId] or 0
    elseif category == "eggs" then
        ownedAmount = inventory.eggs[itemId] or 0
    elseif category == "fruits" then
        ownedAmount = inventory.fruits[itemId] or 0
    end
    
    -- Check if item should be shown based on filters
    if not showZeroItems and ownedAmount == 0 then return nil end
    if configuredOnly and not (itemConfigs[category][itemId] and itemConfigs[category][itemId].enabled) then return nil end
    
    local card = Instance.new("Frame")
    card.Name = itemId
    card.Size = UDim2.new(1, 0, 0, 60)
    card.BackgroundColor3 = colors.hover
    card.BorderSizePixel = 0
    card.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = card
    
    -- Icon (for eggs and fruits)
    if category ~= "pets" then
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0, 40, 0, 40)
        icon.Position = UDim2.new(0, 10, 0, 10)
        icon.BackgroundTransparency = 1
        if category == "eggs" then
            icon.Image = itemData.Icon or ""
        else
            -- For fruits, create text icon
            icon:Destroy()
            icon = Instance.new("TextLabel")
            icon.Name = "Icon"
            icon.Size = UDim2.new(0, 40, 0, 40)
            icon.Position = UDim2.new(0, 10, 0, 10)
            icon.BackgroundTransparency = 1
            icon.Text = itemData.Icon or "🍎"
            icon.TextSize = 24
            icon.Font = Enum.Font.GothamBold
            icon.TextColor3 = getRarityColor(itemData.Rarity)
            icon.Parent = card
        end
        if category == "eggs" then
            icon.Parent = card
        end
    end
    
    -- Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(0, 150, 0, 20)
    nameLabel.Position = UDim2.new(0, category == "pets" and 10 or 60, 0, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = itemData.Name or itemId
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextColor3 = ownedAmount > 0 and colors.text or colors.disabled
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = card
    
    -- Owned Amount
    local ownedLabel = Instance.new("TextLabel")
    ownedLabel.Name = "OwnedLabel"
    ownedLabel.Size = UDim2.new(0, 80, 0, 16)
    ownedLabel.Position = UDim2.new(0, category == "pets" and 10 or 60, 0, 25)
    ownedLabel.BackgroundTransparency = 1
    ownedLabel.Text = "Own: " .. ownedAmount .. "x"
    ownedLabel.TextSize = 12
    ownedLabel.Font = Enum.Font.Gotham
    ownedLabel.TextColor3 = colors.textSecondary
    ownedLabel.TextXAlignment = Enum.TextXAlignment.Left
    ownedLabel.Parent = card
    
    -- Warning icon for insufficient items (same line as owned count)
    local warningIcon = Instance.new("TextLabel")
    warningIcon.Name = "WarningIcon"
    warningIcon.Size = UDim2.new(0, 60, 0, 16)
    warningIcon.Position = UDim2.new(0, 120, 0, 60) -- Same line as owned label
    warningIcon.BackgroundTransparency = 1
    warningIcon.Text = "⚠️"
    warningIcon.TextSize = 10
    warningIcon.Font = Enum.Font.GothamSemibold
    warningIcon.TextColor3 = colors.warning
    warningIcon.TextXAlignment = Enum.TextXAlignment.Left
    warningIcon.Visible = false
    warningIcon.Parent = card
    
    -- Send Until Input (not for speed mode pets)
    local sendInput = nil
    if not (category == "pets" and petMode == "Speed") then
        sendInput = Instance.new("TextBox")
        sendInput.Name = "SendInput"
        sendInput.Size = UDim2.new(0, 80, 0, 25)
        sendInput.Position = UDim2.new(1, -90, 0, 17.5)
        sendInput.BackgroundColor3 = colors.surface
        sendInput.BorderSizePixel = 0
        sendInput.Text = tostring((itemConfigs[category][itemId] and itemConfigs[category][itemId].sendUntil) or 0)
        sendInput.PlaceholderText = "Keep"
        sendInput.TextSize = 12
        sendInput.Font = Enum.Font.Gotham
        sendInput.TextColor3 = colors.text
        sendInput.TextXAlignment = Enum.TextXAlignment.Center
        sendInput.Parent = card
        
        local inputCorner = Instance.new("UICorner")
        inputCorner.CornerRadius = UDim.new(0, 4)
        inputCorner.Parent = sendInput
        
        -- Update config when input changes
        sendInput.FocusLost:Connect(function()
            local value = tonumber(sendInput.Text) or 0
            if not itemConfigs[category][itemId] then
                itemConfigs[category][itemId] = {}
            end
            itemConfigs[category][itemId].sendUntil = value
            itemConfigs[category][itemId].enabled = value > 0
            
            -- Update warning with new format: "nX ⚠️"
            if ownedAmount > 0 and ownedAmount <= value then
                local difference = value - ownedAmount
                warningIcon.Text = difference .. "X ⚠️"
                warningIcon.Visible = true
            else
                warningIcon.Visible = false
            end
            
            saveConfig()
        end)
        
        -- Show warning initially if needed with new format
        local currentSendUntil = (itemConfigs[category][itemId] and itemConfigs[category][itemId].sendUntil) or 0
        if ownedAmount > 0 and ownedAmount <= currentSendUntil then
            local difference = currentSendUntil - ownedAmount
            warningIcon.Text = difference .. "X ⚠️"
            warningIcon.Visible = true
        else
            warningIcon.Visible = false
        end
    end
    
    return card
end

-- Pet Speed Mode UI
local function createPetSpeedControls(parent)
    local speedFrame = Instance.new("Frame")
    speedFrame.Name = "SpeedFrame"
    speedFrame.Size = UDim2.new(1, 0, 0, 80)
    speedFrame.BackgroundColor3 = colors.surface
    speedFrame.BorderSizePixel = 0
    speedFrame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = speedFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = speedFrame
    
    -- Mode Toggle
    local modeToggle = Instance.new("TextButton")
    modeToggle.Name = "ModeToggle"
    modeToggle.Size = UDim2.new(0, 120, 0, 25)
    modeToggle.Position = UDim2.new(0, 10, 0, 10)
    modeToggle.BackgroundColor3 = petMode == "Speed" and colors.primary or colors.hover
    modeToggle.BorderSizePixel = 0
    modeToggle.Text = "Mode: " .. petMode
    modeToggle.TextSize = 12
    modeToggle.Font = Enum.Font.Gotham
    modeToggle.TextColor3 = colors.text
    modeToggle.Parent = speedFrame
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 4)
    toggleCorner.Parent = modeToggle
    
    -- Speed inputs (only visible in speed mode)
    local minSpeedInput = Instance.new("TextBox")
    minSpeedInput.Name = "MinSpeedInput"
    minSpeedInput.Size = UDim2.new(0, 80, 0, 25)
    minSpeedInput.Position = UDim2.new(0, 10, 0, 45)
    minSpeedInput.BackgroundColor3 = colors.hover
    minSpeedInput.BorderSizePixel = 0
    minSpeedInput.Text = tostring(petSpeedMin)
    minSpeedInput.PlaceholderText = "Min Speed"
    minSpeedInput.TextSize = 12
    minSpeedInput.Font = Enum.Font.Gotham
    minSpeedInput.TextColor3 = colors.text
    minSpeedInput.TextXAlignment = Enum.TextXAlignment.Center
    minSpeedInput.Visible = petMode == "Speed"
    minSpeedInput.Parent = speedFrame
    
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 4)
    minCorner.Parent = minSpeedInput
    
    local maxSpeedInput = Instance.new("TextBox")
    maxSpeedInput.Name = "MaxSpeedInput"
    maxSpeedInput.Size = UDim2.new(0, 80, 0, 25)
    maxSpeedInput.Position = UDim2.new(0, 100, 0, 45)
    maxSpeedInput.BackgroundColor3 = colors.hover
    maxSpeedInput.BorderSizePixel = 0
    maxSpeedInput.Text = tostring(petSpeedMax)
    maxSpeedInput.PlaceholderText = "Max Speed"
    maxSpeedInput.TextSize = 12
    maxSpeedInput.Font = Enum.Font.Gotham
    maxSpeedInput.TextColor3 = colors.text
    maxSpeedInput.TextXAlignment = Enum.TextXAlignment.Center
    maxSpeedInput.Visible = petMode == "Speed"
    maxSpeedInput.Parent = speedFrame
    
    local maxCorner = Instance.new("UICorner")
    maxCorner.CornerRadius = UDim.new(0, 4)
    maxCorner.Parent = maxSpeedInput
    
    return speedFrame, modeToggle, minSpeedInput, maxSpeedInput
end

-- Refresh Content
refreshContent = function()
    if not ScreenGui or not ScreenGui.Parent then return end
    
    -- Update gift count display
    updateGiftCountDisplay()
    
    local tabSection = ScreenGui.MainFrame:FindFirstChild("TabSection")
    if not tabSection then return end
    
    local scrollFrame = tabSection.ContentArea.ScrollFrame
    
    -- Clear existing content
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" then
            child:Destroy()
        end
    end
    
    -- Add pet speed controls if in pets tab
    if currentTab == "Pets" then
        local speedFrame, modeToggle, minInput, maxInput = createPetSpeedControls(scrollFrame)
        speedFrame.LayoutOrder = 1
        
        -- Mode toggle functionality
        modeToggle.MouseButton1Click:Connect(function()
            petMode = petMode == "Individual" and "Speed" or "Individual"
            modeToggle.Text = "Mode: " .. petMode
            modeToggle.BackgroundColor3 = petMode == "Speed" and colors.primary or colors.hover
            minInput.Visible = petMode == "Speed"
            maxInput.Visible = petMode == "Speed"
            saveConfig()
            refreshContent() -- Refresh to show/hide individual pet configs
        end)
        
        -- Speed input functionality (real-time updates)
        minInput.Changed:Connect(function(prop)
            if prop == "Text" then
                local newValue = tonumber(minInput.Text) or 0
                if newValue ~= petSpeedMin then
                    petSpeedMin = newValue
                    saveConfig()
                    if petMode == "Speed" then
                        refreshContent() -- Refresh to show pets matching new speed range
                    end
                end
            end
        end)
        
        maxInput.Changed:Connect(function(prop)
            if prop == "Text" then
                local newValue = tonumber(maxInput.Text) or 999999999
                if newValue ~= petSpeedMax then
                    petSpeedMax = newValue
                    saveConfig()
                    if petMode == "Speed" then
                        refreshContent() -- Refresh to show pets matching new speed range
                    end
                end
            end
        end)
    end
    
    -- Get data based on current tab
    local data = {}
    local category = ""
    
    if currentTab == "Pets" then
        category = "pets"
        if petMode == "Individual" then
            for _, petType in ipairs(HardcodedPetTypes) do
                data[petType] = { Name = petType }
            end
        else
            -- In speed mode, show pets that match current speed range
            local inventory = getPlayerInventory()
            local petsFolder = LocalPlayer.PlayerGui.Data and LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
            if petsFolder then
                for _, petData in pairs(petsFolder:GetChildren()) do
                    if petData:IsA("Configuration") then
                        local petType = safeGetAttribute(petData, "T", nil)
                        if petType and petType ~= "" then
                            local petSpeed = getPetSpeed(petData.Name)
                            if petSpeed >= petSpeedMin and petSpeed <= petSpeedMax then
                                data[petType] = { Name = petType }
                            end
                        end
                    end
                end
            end
        end
    elseif currentTab == "Eggs" then
        category = "eggs"
        data = EggData
    elseif currentTab == "Fruits" then
        category = "fruits"
        data = FruitData
    end
    
    -- Filter and sort data
    local filteredData = {}
    local searchLower = string.lower(searchText)
    
    for id, item in pairs(data) do
        local name = item.Name or id
        if searchText == "" or string.find(string.lower(name), searchLower, 1, true) then
            filteredData[id] = item
        end
    end
    
    -- Convert to array and sort
    local sortedData = {}
    for id, item in pairs(filteredData) do
        table.insert(sortedData, {id = id, data = item})
    end
    
    -- Sort based on sortMode
    local inventory = getPlayerInventory()
    table.sort(sortedData, function(a, b)
        if sortMode == "name_asc" then
            return (a.data.Name or a.id) < (b.data.Name or b.id)
        elseif sortMode == "name_desc" then
            return (a.data.Name or a.id) > (b.data.Name or b.id)
        elseif sortMode == "owned_desc" then
            local ownedA = inventory[category][a.id] or 0
            local ownedB = inventory[category][b.id] or 0
            return ownedA > ownedB
        elseif sortMode == "owned_asc" then
            local ownedA = inventory[category][a.id] or 0
            local ownedB = inventory[category][b.id] or 0
            return ownedA < ownedB
        end
        return false
    end)
    
    -- Create item cards
    local layoutOrder = currentTab == "Pets" and 2 or 1
    for _, item in ipairs(sortedData) do
        local card = createItemCard(item.id, item.data, category, scrollFrame)
        if card then
            card.LayoutOrder = layoutOrder
            layoutOrder = layoutOrder + 1
        end
    end
end

-- Create Main UI
function AutoTradeUI.CreateUI()
    if ScreenGui then
        ScreenGui:Destroy()
    end
    
    -- Calculate screen-relative size
    local screenSize = workspace.CurrentCamera.ViewportSize
    local baseWidth = 900
    local baseHeight = 600
    local scaleX = math.min(screenSize.X / 1920, 1) -- Scale down on smaller screens
    local scaleY = math.min(screenSize.Y / 1080, 1)
    local scale = math.min(scaleX, scaleY)
    
    local finalWidth = baseWidth * scale
    local finalHeight = baseHeight * scale
    
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AutoTradeUI"
    ScreenGui.Parent = PlayerGui
    
    MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, finalWidth, 0, finalHeight)
    MainFrame.Position = UDim2.new(0.5, -finalWidth/2, 0.5, -finalHeight/2)
    MainFrame.BackgroundColor3 = colors.background
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    originalSize = MainFrame.Size
    minimizedSize = UDim2.new(0, finalWidth, 0, 60)
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = MainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = MainFrame
    
    -- Window Controls
    local windowControls = createWindowControls(MainFrame)
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -200, 0, 20)
    title.Position = UDim2.new(0, 100, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "Auto Trade System"
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = colors.text
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = MainFrame
    
    -- Refresh button removed since real-time updates make it unnecessary
    
    -- Create sections
    local targetSection = createTargetSection(MainFrame)
    local filterBar = createFilterBar(MainFrame)
    local tabSection = createTabSection(MainFrame)
    
    -- Window control events
    local closeBtn = windowControls.CloseBtn
    local minimizeBtn = windowControls.MinimizeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        AutoTradeUI.Hide()
    end)
    
    minimizeBtn.MouseButton1Click:Connect(function()
        if isMinimized then
            MainFrame.Size = originalSize
            targetSection.Visible = true
            filterBar.Visible = true
            tabSection.Visible = true
            isMinimized = false
        else
            MainFrame.Size = minimizedSize
            targetSection.Visible = false
            filterBar.Visible = false
            tabSection.Visible = false
            isMinimized = true
        end
    end)
    
    -- Dragging functionality
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundTransparency = 1
    titleBar.Parent = MainFrame
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            
            local connection
            connection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                    connection:Disconnect()
                end
            end)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- Setup event handlers
    setupEventHandlers()
    
    return ScreenGui
end

-- Setup Event Handlers
function setupEventHandlers()
    if not ScreenGui then return end
    
    -- Target section events
    local targetSection = ScreenGui.MainFrame.TargetSection
    local targetDropdown = targetSection.TargetDropdown
    local sendBtn = targetSection.SendBtn
    local autoTradeToggle = targetSection.AutoTradeToggle
    
    -- Target dropdown functionality
    local function updateTargetDropdown()
        local dropdownList = targetSection.DropdownList
        -- Clear existing options
        for _, child in pairs(dropdownList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        local playerList = getPlayerList()
        for i, playerName in ipairs(playerList) do
            local option = Instance.new("TextButton")
            option.Name = "Option" .. i
            option.Size = UDim2.new(1, 0, 0, 25)
            option.BackgroundColor3 = colors.hover
            option.BorderSizePixel = 0
            option.Text = playerName
            option.TextSize = 12
            option.Font = Enum.Font.Gotham
            option.TextColor3 = colors.text
            option.TextXAlignment = Enum.TextXAlignment.Left
            option.ZIndex = 101 -- Higher than the dropdown container
            option.Parent = dropdownList
            
            local optionPadding = Instance.new("UIPadding")
            optionPadding.PaddingLeft = UDim.new(0, 8)
            optionPadding.Parent = option
            
            option.MouseEnter:Connect(function()
                option.BackgroundColor3 = colors.primary
            end)
            
            option.MouseLeave:Connect(function()
                option.BackgroundColor3 = colors.hover
            end)
            
            option.MouseButton1Click:Connect(function()
                selectedTarget = playerName
                targetSection.NameLabel.Text = selectedTarget
                targetDropdown.Text = "Select Target ▼"
                dropdownList.Visible = false
                
                -- Update avatar if not random
                if selectedTarget ~= "Random Player" then
                    local player = getPlayerByName(selectedTarget)
                    if player then
                        local avatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=150&height=150&format=png"
                        targetSection.Avatar.Image = avatarUrl
                    end
                else
                    targetSection.Avatar.Image = ""
                end
            end)
        end
    end
    
    targetDropdown.MouseButton1Click:Connect(function()
        -- Hide any active tooltips when opening dropdown
        hideTooltip()
        
        local dropdownList = targetSection.DropdownList
        dropdownList.Visible = not dropdownList.Visible
        if dropdownList.Visible then
            updateTargetDropdown()
        end
    end)
    
    -- Send button
    -- Add tooltip for Send button
    sendBtn.MouseEnter:Connect(function()
        createTooltip("Manually send one item to the selected target player", targetSection, sendBtn)
    end)
    
    sendBtn.MouseLeave:Connect(function()
        hideTooltip()
    end)
    
    sendBtn.MouseButton1Click:Connect(function()
        if isTrading then return end
        
        local itemsToSend = getItemsToSend()
        if #itemsToSend > 0 then
            local item = itemsToSend[1]
            task.spawn(function()
                -- Manual send should return to position after trade
                local success, err = performTrade(item.uid, item.type, nil, true)
                if not success and WindUI then
                    WindUI:Notify({
                        Title = "❌ Trade Failed",
                        Content = err or "Unknown error",
                        Duration = 5
                    })
                end
            end)
        else
            if WindUI then
                WindUI:Notify({
                    Title = "⚠️ No Items",
                    Content = "No items configured for trading",
                    Duration = 3
                })
            end
        end
    end)
    
    -- Auto trade toggle
    -- Add tooltip for Auto Trade toggle
    autoTradeToggle.MouseEnter:Connect(function()
        createTooltip("Enable/disable automatic trading for all configured items", targetSection, autoTradeToggle)
    end)
    
    autoTradeToggle.MouseLeave:Connect(function()
        hideTooltip()
    end)
    
    autoTradeToggle.MouseButton1Click:Connect(function()
        autoTradeEnabled = not autoTradeEnabled
        autoTradeToggle.Text = autoTradeEnabled and "Auto Trade: ON" or "Auto Trade: OFF"
        autoTradeToggle.BackgroundColor3 = autoTradeEnabled and colors.success or colors.hover
        
        if autoTradeEnabled then
            startAutoTrade()
        else
            stopAutoTrade()
        end
        
        saveConfig()
    end)
    
    -- Filter bar events
    local filterBar = ScreenGui.MainFrame.FilterBar
    local searchBox = filterBar.SearchBox
    local sortBtn = filterBar.SortBtn
    local sortList = filterBar.SortList
    local zeroToggle = filterBar.ZeroToggle
    local configToggle = filterBar.ConfigToggle
    
    searchBox.Changed:Connect(function(prop)
        if prop == "Text" then
            searchText = searchBox.Text
            saveConfig()
            refreshContent()
        end
    end)
    
    -- Sort dropdown functionality
    sortBtn.MouseButton1Click:Connect(function()
        -- Hide any active tooltips when opening dropdown
        hideTooltip()
        
        sortList.Visible = not sortList.Visible
    end)
    
    zeroToggle.MouseButton1Click:Connect(function()
        showZeroItems = not showZeroItems
        zeroToggle.BackgroundColor3 = showZeroItems and colors.primary or colors.hover
        saveConfig()
        refreshContent()
    end)
    
    configToggle.MouseButton1Click:Connect(function()
        configuredOnly = not configuredOnly
        configToggle.BackgroundColor3 = configuredOnly and colors.primary or colors.hover
        saveConfig()
        refreshContent()
    end)
    
    -- Tab events
    local tabSection = ScreenGui.MainFrame.TabSection
    local tabContainer = tabSection.TabContainer
    local petsTab = tabContainer.PetsTab
    local eggsTab = tabContainer.EggsTab
    local fruitsTab = tabContainer.FruitsTab
    
    petsTab.MouseButton1Click:Connect(function()
        currentTab = "Pets"
        petsTab.BackgroundColor3 = colors.primary
        eggsTab.BackgroundColor3 = colors.hover
        fruitsTab.BackgroundColor3 = colors.hover
        saveConfig()
        refreshContent()
    end)
    
    eggsTab.MouseButton1Click:Connect(function()
        currentTab = "Eggs"
        petsTab.BackgroundColor3 = colors.hover
        eggsTab.BackgroundColor3 = colors.primary
        fruitsTab.BackgroundColor3 = colors.hover
        saveConfig()
        refreshContent()
    end)
    
    fruitsTab.MouseButton1Click:Connect(function()
        currentTab = "Fruits"
        petsTab.BackgroundColor3 = colors.hover
        eggsTab.BackgroundColor3 = colors.hover
        fruitsTab.BackgroundColor3 = colors.primary
        saveConfig()
        refreshContent()
    end)
end

-- Public Functions
function AutoTradeUI.Init(windUIRef)
    WindUI = windUIRef
    loadConfig()
end

function AutoTradeUI.Show()
    if not ScreenGui then
        AutoTradeUI.CreateUI()
    end
    
    ScreenGui.Enabled = true
    refreshContent()
end

function AutoTradeUI.Hide()
    if ScreenGui then
        ScreenGui.Enabled = false
    end
    
    -- Stop auto trade when hiding
    if autoTradeEnabled then
        autoTradeEnabled = false
        stopAutoTrade()
        saveConfig()
    end
end

function AutoTradeUI.Toggle()
    if ScreenGui and ScreenGui.Enabled then
        AutoTradeUI.Hide()
    else
        AutoTradeUI.Show()
    end
end

function AutoTradeUI.IsVisible()
    return ScreenGui and ScreenGui.Enabled
end

-- Monitor inventory changes for auto-trade and real-time updates
local inventoryConnection = nil
local lastInventoryUpdate = 0
local function startInventoryMonitoring()
    if inventoryConnection then
        inventoryConnection:Disconnect()
    end
    
    inventoryConnection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        -- Update UI every 2 seconds for real-time inventory amounts and gift count
        if currentTime - lastInventoryUpdate >= 2 then
            lastInventoryUpdate = currentTime
            if ScreenGui and ScreenGui.Enabled then
                refreshContent() -- This now includes gift count update
            end
        end
        
        if autoTradeEnabled and not isTrading then
            -- Check for items to send every few seconds
            task.wait(2)
        end
    end)
end

-- Start monitoring when module loads
startInventoryMonitoring()

return AutoTradeUI
