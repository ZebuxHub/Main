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
  local sendingSpeed = 2.0 -- Speed multiplier for sending process (2.0s = normal speed, down to 0.5s)
  local globalMutationFilters = {"Any"} -- Global mutation filters for all pets/eggs (can be multiple)
  local oceanOnlyFilter = false -- Exclude ocean pets/eggs filter
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
    BasicEgg = { Name = "Basic Egg", Price = "100", Icon = "rbxassetid://86783205334263", Rarity = 1, Category = "" },
    RareEgg = { Name = "Rare Egg", Price = "600", Icon = "rbxassetid://92360220594881", Rarity = 2, Category = "" },
    SuperRareEgg = { Name = "Super Rare Egg", Price = "3,000", Icon = "rbxassetid://114593167151091", Rarity = 2, Category = "" },
    SeaweedEgg = { Name = "Seaweed Egg", Price = "300", Icon = "rbxassetid://83071703588226", Rarity = 2, Category = "Ocean" },
    EpicEgg = { Name = "Epic Egg", Price = "15,000", Icon = "rbxassetid://118390666254578", Rarity = 2, Category = "" },
    LegendEgg = { Name = "Legend Egg", Price = "100,000", Icon = "rbxassetid://70573001058005", Rarity = 3, Category = "" },
    ClownfishEgg = { Name = "Clownfish Egg", Price = "300", Icon = "rbxassetid://134581421196477", Rarity = 3, Category = "Ocean" },
    SnowbunnyEgg = { Name = "Snowbunny Egg", Price = "1,500,000", Icon = "rbxassetid://98700887273727", Rarity = 3, Category = "" },
    PrismaticEgg = { Name = "Prismatic Egg", Price = "1,000,000", Icon = "rbxassetid://116342289419267", Rarity = 4, Category = "" },
    LionfishEgg = { Name = "Lionfish Egg", Price = "300", Icon = "rbxassetid://109178769208956", Rarity = 4, Category = "Ocean" },
    HyperEgg = { Name = "Hyper Egg", Price = "2,500,000", Icon = "rbxassetid://95160801997871", Rarity = 4, Category = "" },
    DarkGoatyEgg = { Name = "Dark Goaty Egg", Price = "100,000,000", Icon = "rbxassetid://107381728103466", Rarity = 4, Category = "" },
    VoidEgg = { Name = "Void Egg", Price = "24,000,000", Icon = "rbxassetid://91598797684023", Rarity = 5, Category = "" },
    BowserEgg = { Name = "Bowser Egg", Price = "130,000,000", Icon = "rbxassetid://117118367570176", Rarity = 5, Category = "" },
    SharkEgg = { Name = "Shark Egg", Price = "10,000,000", Icon = "rbxassetid://100309591286506", Rarity = 5, Category = "Ocean" },
    DemonEgg = { Name = "Demon Egg", Price = "400,000,000", Icon = "rbxassetid://98860640309332", Rarity = 5, Category = "" },
    RhinoRockEgg = { Name = "Rhino Rock Egg", Price = "3,000,000,000", Icon = "rbxassetid://107622817209375", Rarity = 5, Category = "" },
    CornEgg = { Name = "Corn Egg", Price = "1,000,000,000", Icon = "rbxassetid://89607346860887", Rarity = 5, Category = "" },
    AnglerfishEgg = { Name = "Anglerfish Egg", Price = "10,000,000", Icon = "rbxassetid://75040057191824", Rarity = 5, Category = "Ocean" },
    BoneDragonEgg = { Name = "Bone Dragon Egg", Price = "2,000,000,000", Icon = "rbxassetid://90061673164351", Rarity = 5, Category = "" },
    UltraEgg = { Name = "Ultra Egg", Price = "10,000,000,000", Icon = "rbxassetid://125017061714581", Rarity = 6, Category = "" },
    DinoEgg = { Name = "Dino Egg", Price = "10,000,000,000", Icon = "rbxassetid://89202977833846", Rarity = 6, Category = "" },
    FlyEgg = { Name = "Fly Egg", Price = "999,999,999,999", Icon = "rbxassetid://124585798513880", Rarity = 6, Category = "" },
    SaberCubEgg = { Name = "Saber Cub Egg", Price = "40,000,000,000", Icon = "rbxassetid://139650300263607", Rarity = 6, Category = "" },
    UnicornEgg = { Name = "Unicorn Egg", Price = "40,000,000,000", Icon = "rbxassetid://136448818476629", Rarity = 6, Category = "" },
    OctopusEgg = { Name = "Octopus Egg", Price = "800,000,000", Icon = "rbxassetid://109425850264541", Rarity = 6, Category = "Ocean" },
    AncientEgg = { Name = "Ancient Egg", Price = "999,999,999,999", Icon = "rbxassetid://101395257898929", Rarity = 6, Category = "" },
    SailfishEgg = { Name = "Sailfish Egg", Price = "800,000,000", Icon = "rbxassetid://81397448808415", Rarity = 6, Category = "Ocean" },
    SeaDragonEgg = { Name = "Sea Dragon Egg", Price = "999,999,999,999", Icon = "rbxassetid://109025633299772", Rarity = 6, Category = "Ocean" },
    UnicornProEgg = { Name = "Unicorn Pro Egg", Price = "50,000,000,000", Icon = "rbxassetid://85536865895155", Rarity = 6, Category = "" },
    GeneralKongEgg = { Name = "General Kong Egg", Price = "80,000,000,000", Icon = "rbxassetid://87872914784536", Rarity = 6, Category = "" },
    PegasusEgg = { Name = "Pegasus Egg", Price = "999,999,999,999", Icon = "rbxassetid://113005786229298", Rarity = 6, Category = "" }
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

local MutationData = {
    Golden = { Name = "Golden", Icon = "✨", Rarity = 10 },
    Diamond = { Name = "Diamond", Icon = "💎", Rarity = 20 },
    Electirc = { Name = "Electirc", Icon = "⚡", Rarity = 50 },
    Fire = { Name = "Fire", Icon = "🔥", Rarity = 100 },
    Dino = { Name = "Jurassic", Icon = "🦕", Rarity = 100 },
    Snow = { Name = "Snow", Icon = "❄️", Rarity = 150 }
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
    "Phoenix", "Toothless", "Tyrannosaurus", "Mosasaur", "Octopus", "Killerwhale", "Peacock",
    "Sheep_E1", "Horse_E1", "Zebra_E1", "Giraffe_E1", "Hippo_E1", "Elephant_E1", "Rabbit_E1", 
    "Mouse_E1", "Wolverine_E1", "Tiger_E1", "Fox_E1", "Panda_E1", "Toucan_E1", "Snake_E1", 
    "Okapi_E1", "Panther_E1", "Seaturtle_E1", "Bear_E1", "Lion_E1", "Rhino_E1", "Kangroo_E1", 
    "Gorilla_E1", "Wolf_E1", "Rex_E1", "Dragon_E1", "Griffin_E1", "Penguin_E1", "Ostrich_E1", 
    "Baldeagle_E1", "Butterfly_E1", "Bee_E1"
}

-- Pet Category Data (for ocean filter)
local PetCategoryData = {
    -- Ocean Pets
    AngelFish = { Category = "Ocean" },
    Butterflyfish = { Category = "Ocean" },
    Needlefish = { Category = "Ocean" },
    Hairtail = { Category = "Ocean" },
    Tuna = { Category = "Ocean" },
    Catfish = { Category = "Ocean" },
    Tigerfish = { Category = "Ocean" },
    Flounder = { Category = "Ocean" },
    Lionfish = { Category = "Ocean" },
    ElectricEel = { Category = "Ocean" },
    Dolphin = { Category = "Ocean" },
    Shark = { Category = "Ocean" },
    Anglerfish = { Category = "Ocean" },
    Plesiosaur = { Category = "Ocean" },
    Manta = { Category = "Ocean" },
    Mosasaur = { Category = "Ocean" },
    Octopus = { Category = "Ocean" },
    Killerwhale = { Category = "Ocean" },
    Sawfish = { Category = "Ocean" },
    Seaturtle = { Category = "Ocean" },
    Seaturtle_E1 = { Category = "Ocean" },
    
    -- Evolution Pets
    Sheep_E1 = { Category = "Evolution" },
    Horse_E1 = { Category = "Evolution" },
    Zebra_E1 = { Category = "Evolution" },
    Giraffe_E1 = { Category = "Evolution" },
    Hippo_E1 = { Category = "Evolution" },
    Elephant_E1 = { Category = "Evolution" },
    Rabbit_E1 = { Category = "Evolution" },
    Mouse_E1 = { Category = "Evolution" },
    Wolverine_E1 = { Category = "Evolution" },
    Tiger_E1 = { Category = "Evolution" },
    Fox_E1 = { Category = "Evolution" },
    Panda_E1 = { Category = "Evolution" },
    Toucan_E1 = { Category = "Evolution" },
    Snake_E1 = { Category = "Evolution" },
    Okapi_E1 = { Category = "Evolution" },
    Panther_E1 = { Category = "Evolution" },
    Bear_E1 = { Category = "Evolution" },
    Lion_E1 = { Category = "Evolution" },
    Rhino_E1 = { Category = "Evolution" },
    Kangroo_E1 = { Category = "Evolution" },
    Gorilla_E1 = { Category = "Evolution" },
    Wolf_E1 = { Category = "Evolution" },
    Rex_E1 = { Category = "Evolution" },
    Dragon_E1 = { Category = "Evolution" },
    Griffin_E1 = { Category = "Evolution" },
    Penguin_E1 = { Category = "Evolution" },
    Ostrich_E1 = { Category = "Evolution" },
    Baldeagle_E1 = { Category = "Evolution" },
    Butterfly_E1 = { Category = "Evolution" },
    Bee_E1 = { Category = "Evolution" },
    
    -- All other pets have Category = "" (normal pets)
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

-- Forward declarations
local refreshContent
local updateOwnedAmounts
local updateTargetDropdown

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
    giftCountLabel.Text = "Today Gift: " .. currentCount .. "/500"
    
    -- Change color if approaching or at limit
    if currentCount >= 500 then
        giftCountLabel.TextColor3 = colors.error or Color3.fromRGB(255, 69, 58)
    elseif currentCount >= 450 then
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
    
    -- Get Fruits (using robust method like WebhookSystem)
    local asset = LocalPlayer.PlayerGui.Data:FindFirstChild("Asset")
    if asset then
        -- Name normalization helper
        local function normalizeFruitName(name)
            if type(name) ~= "string" then return "" end
            local lowered = string.lower(name)
            lowered = lowered:gsub("[%s_%-%./]", "")
            return lowered
        end
        
        -- Build canonical name map
        local FRUIT_CANONICAL = {}
        for id, item in pairs(FruitData) do
            local display = item.Name or id
            FRUIT_CANONICAL[normalizeFruitName(id)] = display
            FRUIT_CANONICAL[normalizeFruitName(display)] = display
        end
        
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
                inventory.fruits[id] = amount
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
                        -- Use the ID that matches the canonical name
                        for id, item in pairs(FruitData) do
                            if item.Name == canonical then
                                inventory.fruits[id] = amount
                                break
                            end
                        end
                    end
                end
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
    if currentGiftCount >= 500 then
        if WindUI then
            WindUI:Notify({
                Title = "🚫 Daily Limit Reached",
                Content = "You've reached the daily gift limit of 500. Cannot send more items today.",
                Duration = 5
            })
        end
        return false, "Daily gift limit reached (500/500)"
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
    
    -- Wait a moment for teleport to complete (speed-adjusted)
    task.wait(math.max(0.1, sendingSpeed * 0.25))
    
    -- Focus item
    local focusSuccess, focusErr = focusItem(itemUID)
    if not focusSuccess then
        isTrading = false
        if shouldReturnToPosition then
            returnToSavedPosition()
        end
        return false, "Failed to focus item: " .. (focusErr or "Unknown error")
    end
    
    -- Wait for focus (speed-adjusted)
    task.wait(math.max(0.05, sendingSpeed * 0.1))
    
    -- Gift to player
    local giftSuccess, giftErr = giftToPlayer(target)
    if not giftSuccess then
        isTrading = false
        if shouldReturnToPosition then
            returnToSavedPosition()
        end
        return false, "Failed to gift item: " .. (giftErr or "Unknown error")
    end
    
    -- Wait for gift to process (speed-adjusted)
    task.wait(math.max(0.1, sendingSpeed * 0.25))
    
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
    -- If sendUntil is 0, send everything (ownedAmount > 0)
    -- If sendUntil > 0, send only if we have more than the threshold
    if sendUntil == 0 then
        return ownedAmount > 0 -- Send everything when target is 0
    else
        return ownedAmount > sendUntil -- Send extras when we have more than target
    end
end

-- Check if an item matches the mutation filter
local function itemMatchesMutations(item)
    -- Apply global mutation filters
    if not (globalMutationFilters[1] == "Any" and #globalMutationFilters == 1) then
        local itemMutation = item:GetAttribute("M") or "None"
        
        -- Check if item's mutation is in the selected filters
        local matchesFilter = false
        for _, filter in ipairs(globalMutationFilters) do
            if filter == "Any" or itemMutation == filter then
                matchesFilter = true
                break
            end
        end
        
        if not matchesFilter then
            return false
        end
    end
    
    return true
end

-- Check if an item should be sent based on ocean filter
local function itemMatchesOceanFilter(itemType, category)
    if oceanOnlyFilter and (category == "pets" or category == "eggs") then
        local itemData = nil
        if category == "pets" then
            -- Check if pet is ocean type using PetCategoryData
            local petData = PetCategoryData[itemType]
            if petData and petData.Category == "Ocean" then
                return false -- Exclude ocean pets when filter is ON
            end
        elseif category == "eggs" then
            itemData = EggData[itemType]
            if itemData and itemData.Category == "Ocean" then
                return false -- Exclude ocean eggs when filter is ON
            end
        end
    end
    
    return true
end

local function getItemsToSend()
    local inventory = getPlayerInventory()
    local itemsToSend = {}
    
    -- Check Eggs
    for eggType, ownedAmount in pairs(inventory.eggs) do
        if shouldSendItem(eggType, "eggs", ownedAmount) and itemMatchesOceanFilter(eggType, "eggs") then
            -- Find egg UID from inventory that matches mutation requirements
            local eggsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
            if eggsFolder then
                for _, eggData in pairs(eggsFolder:GetChildren()) do
                    if eggData:IsA("Configuration") then
                        local eggDataType = safeGetAttribute(eggData, "T", nil)
                        local isPlaced = safeGetAttribute(eggData, "D", nil) ~= nil
                        if eggDataType == eggType and not isPlaced and itemMatchesMutations(eggData) then
                            table.insert(itemsToSend, {
                                uid = eggData.Name,
                                type = eggType,
                                category = "eggs",
                                mutation = safeGetAttribute(eggData, "M", "None")
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
        -- Speed mode: send all pets in speed range (exclude placed pets and apply ocean filter)
        local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
        if petsFolder then
            for _, petData in pairs(petsFolder:GetChildren()) do
                if petData:IsA("Configuration") then
                    local petType = safeGetAttribute(petData, "T", nil)
                    local isPlaced = safeGetAttribute(petData, "D", nil) ~= nil
                    if petType and petType ~= "" and not isPlaced then
                        local petSpeed = getPetSpeed(petData.Name)
                        if petSpeed >= petSpeedMin and petSpeed <= petSpeedMax then
                            -- Apply ocean filter and mutation filter in speed mode
                            if itemMatchesOceanFilter(petType, "pets") and itemMatchesMutations(petData) then
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
        end
    else
        -- Individual mode: check configured pets (exclude placed pets)
        for petType, ownedAmount in pairs(inventory.pets) do
            if shouldSendItem(petType, "pets", ownedAmount) and itemMatchesOceanFilter(petType, "pets") then
                -- Find pet UID from inventory
                local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
                if petsFolder then
                    for _, petData in pairs(petsFolder:GetChildren()) do
                        if petData:IsA("Configuration") then
                            local petDataType = safeGetAttribute(petData, "T", nil)
                            local isPlaced = safeGetAttribute(petData, "D", nil) ~= nil
                            if petDataType == petType and not isPlaced and itemMatchesMutations(petData) then
                                table.insert(itemsToSend, {
                                    uid = petData.Name,
                                    type = petType,
                                    category = "pets",
                                    mutation = safeGetAttribute(petData, "M", "None")
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
        if currentGiftCount >= 500 then
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
                    Content = "Daily gift limit reached (500/500). Auto-trade has been disabled.",
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
        configuredOnly = configuredOnly,
        -- New settings to save
        sendingSpeed = sendingSpeed,
        uiScale = ScreenGui and ScreenGui.UIScale and ScreenGui.UIScale.Scale or 1.0,
        globalMutationFilters = globalMutationFilters,
        oceanOnlyFilter = oceanOnlyFilter
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
        -- Load new settings
        sendingSpeed = configData.sendingSpeed or sendingSpeed
        globalMutationFilters = configData.globalMutationFilters or globalMutationFilters
        oceanOnlyFilter = configData.oceanOnlyFilter ~= nil and configData.oceanOnlyFilter or oceanOnlyFilter
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
    local targetSection = Instance.new("ScrollingFrame")
    targetSection.Name = "TargetSection"
    targetSection.Size = UDim2.new(0.35, -8, 1, -80)
    targetSection.Position = UDim2.new(0, 16, 0, 80)
    targetSection.BackgroundColor3 = colors.surface
    targetSection.BorderSizePixel = 0
    targetSection.ScrollBarThickness = 4
    targetSection.ScrollBarImageColor3 = colors.primary
    targetSection.AutomaticCanvasSize = Enum.AutomaticSize.Y
    targetSection.ScrollingDirection = Enum.ScrollingDirection.Y
    targetSection.CanvasSize = UDim2.new(0, 0, 0, 0)
    targetSection.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = targetSection
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = targetSection
    
    -- Add UIListLayout for automatic stacking (like WindUI)
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 10)
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Parent = targetSection
    
    -- Add padding
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = targetSection
    
    -- Target Player Avatar (placeholder)
    local avatar = Instance.new("ImageLabel")
    avatar.Name = "Avatar"
    avatar.Size = UDim2.new(0, 80, 0, 80)
    avatar.BackgroundColor3 = colors.hover
    avatar.BorderSizePixel = 0
    avatar.Image = "" -- Will be set dynamically
    avatar.LayoutOrder = 1
    avatar.Parent = targetSection
    
    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(0, 8)
    avatarCorner.Parent = avatar
    
    -- Target Player Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -20, 0, 30)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = selectedTarget
    nameLabel.TextSize = 16
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextColor3 = colors.text
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.TextWrapped = true
    nameLabel.LayoutOrder = 2
    nameLabel.Parent = targetSection
    
    -- Target Selection Dropdown
    local targetDropdown = Instance.new("TextButton")
    targetDropdown.Name = "TargetDropdown"
    targetDropdown.Size = UDim2.new(1, -20, 0, 35)
    targetDropdown.BackgroundColor3 = colors.hover
    targetDropdown.BorderSizePixel = 0
    targetDropdown.Text = "Select Target ▼"
    targetDropdown.TextSize = 14
    targetDropdown.Font = Enum.Font.Gotham
    targetDropdown.TextColor3 = colors.text
    targetDropdown.LayoutOrder = 3
    targetDropdown.Parent = targetSection
    
    local dropdownCorner = Instance.new("UICorner")
    dropdownCorner.CornerRadius = UDim.new(0, 6)
    dropdownCorner.Parent = targetDropdown
    
    -- Dropdown List (initially hidden)
    local dropdownList = Instance.new("ScrollingFrame")
    dropdownList.Name = "DropdownList"
    dropdownList.Size = UDim2.new(1, -20, 0, 120)
    dropdownList.BackgroundColor3 = colors.surface
    dropdownList.BorderSizePixel = 0
    dropdownList.Visible = false
    dropdownList.ScrollBarThickness = 4
    dropdownList.ScrollBarImageColor3 = colors.primary
    dropdownList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    dropdownList.ScrollingDirection = Enum.ScrollingDirection.Y
    dropdownList.ZIndex = 100
    dropdownList.LayoutOrder = 4
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
    sendBtn.BackgroundColor3 = colors.primary
    sendBtn.BorderSizePixel = 0
    sendBtn.Text = "Send Now"
    sendBtn.TextSize = 16
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    sendBtn.LayoutOrder = 5
    sendBtn.Parent = targetSection
    
    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 8)
    sendCorner.Parent = sendBtn
    
    -- Speed Control Slider
    local speedFrame = Instance.new("Frame")
    speedFrame.Name = "SpeedFrame"
    speedFrame.Size = UDim2.new(1, -20, 0, 50)
    speedFrame.BackgroundTransparency = 1
    speedFrame.LayoutOrder = 6
    speedFrame.Parent = targetSection
    
    local speedLabel = Instance.new("TextLabel")
    speedLabel.Name = "SpeedLabel"
    speedLabel.Size = UDim2.new(1, 0, 0, 20)
    speedLabel.Position = UDim2.new(0, 0, 0, 0)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = "Send Speed: " .. string.format("%.1fs", sendingSpeed)
    speedLabel.TextSize = 12
    speedLabel.Font = Enum.Font.GothamSemibold
    speedLabel.TextColor3 = colors.text
    speedLabel.TextXAlignment = Enum.TextXAlignment.Center
    speedLabel.Parent = speedFrame
    
    -- Speed Slider Background
    local sliderBg = Instance.new("Frame")
    sliderBg.Name = "SliderBg"
    sliderBg.Size = UDim2.new(1, 0, 0, 6)
    sliderBg.Position = UDim2.new(0, 0, 0, 25)
    sliderBg.BackgroundColor3 = colors.hover
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = speedFrame
    
    local sliderBgCorner = Instance.new("UICorner")
    sliderBgCorner.CornerRadius = UDim.new(0, 3)
    sliderBgCorner.Parent = sliderBg
    
    -- Speed Slider Fill
    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "SliderFill"
    sliderFill.Size = UDim2.new((2.5 - sendingSpeed) / 2.0, 0, 1, 0) -- Map 0.5-2.5 to 1-0 (inverted)
    sliderFill.Position = UDim2.new(0, 0, 0, 0)
    sliderFill.BackgroundColor3 = colors.primary
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBg
    
    local sliderFillCorner = Instance.new("UICorner")
    sliderFillCorner.CornerRadius = UDim.new(0, 3)
    sliderFillCorner.Parent = sliderFill
    
    -- Speed Slider Handle
    local sliderHandle = Instance.new("Frame")
    sliderHandle.Name = "SliderHandle"
    sliderHandle.Size = UDim2.new(0, 16, 0, 16)
    sliderHandle.Position = UDim2.new((2.5 - sendingSpeed) / 2.0, -8, 0, 20) -- Map 0.5-2.5 to 1-0 (inverted)
    sliderHandle.BackgroundColor3 = colors.text
    sliderHandle.BorderSizePixel = 0
    sliderHandle.ZIndex = 2
    sliderHandle.Parent = speedFrame
    
    local sliderHandleCorner = Instance.new("UICorner")
    sliderHandleCorner.CornerRadius = UDim.new(0, 8)
    sliderHandleCorner.Parent = sliderHandle
    
    -- Speed Slider Interaction
    local isDraggingSlider = false
    
    sliderHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingSlider = true
        end
    end)
    
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingSlider = true
            -- Update slider position immediately
            local relativeX = (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
            relativeX = math.max(0, math.min(1, relativeX))
            sendingSpeed = 2.5 - (relativeX * 2.0) -- Map 0-1 to 2.5-0.5 (inverted)
            
            -- Update UI
            sliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
            sliderHandle.Position = UDim2.new(relativeX, -8, 0, 20)
            speedLabel.Text = "Send Speed: " .. string.format("%.1fs", sendingSpeed)
            
            -- Save to config
            saveConfig()
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and isDraggingSlider then
            local relativeX = (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
            relativeX = math.max(0, math.min(1, relativeX))
            sendingSpeed = 2.5 - (relativeX * 2.0) -- Map 0-1 to 2.5-0.5 (inverted)
            
            -- Update UI
            sliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
            sliderHandle.Position = UDim2.new(relativeX, -8, 0, 20)
            speedLabel.Text = "Send Speed: " .. string.format("%.1fs", sendingSpeed)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if isDraggingSlider then
                -- Save config when user finishes dragging speed slider
                saveConfig()
            end
            isDraggingSlider = false
        end
    end)
    
    -- UI Scale Control Slider
    local scaleFrame = Instance.new("Frame")
    scaleFrame.Name = "ScaleFrame"
    scaleFrame.Size = UDim2.new(1, -20, 0, 50)
    scaleFrame.BackgroundTransparency = 1
    scaleFrame.LayoutOrder = 7
    scaleFrame.Parent = targetSection
    
    local scaleLabel = Instance.new("TextLabel")
    scaleLabel.Name = "ScaleLabel"
    scaleLabel.Size = UDim2.new(1, 0, 0, 20)
    scaleLabel.Position = UDim2.new(0, 0, 0, 0)
    scaleLabel.BackgroundTransparency = 1
    scaleLabel.Text = "UI Scale: 100%"
    scaleLabel.TextSize = 12
    scaleLabel.Font = Enum.Font.GothamSemibold
    scaleLabel.TextColor3 = colors.text
    scaleLabel.TextXAlignment = Enum.TextXAlignment.Center
    scaleLabel.Parent = scaleFrame
    
    -- Scale Slider Background
    local scaleSliderBg = Instance.new("Frame")
    scaleSliderBg.Name = "ScaleSliderBg"
    scaleSliderBg.Size = UDim2.new(1, 0, 0, 6)
    scaleSliderBg.Position = UDim2.new(0, 0, 0, 25)
    scaleSliderBg.BackgroundColor3 = colors.hover
    scaleSliderBg.BorderSizePixel = 0
    scaleSliderBg.Parent = scaleFrame
    
    local scaleSliderBgCorner = Instance.new("UICorner")
    scaleSliderBgCorner.CornerRadius = UDim.new(0, 3)
    scaleSliderBgCorner.Parent = scaleSliderBg
    
    -- Scale Slider Fill
    local scaleSliderFill = Instance.new("Frame")
    scaleSliderFill.Name = "ScaleSliderFill"
    scaleSliderFill.Size = UDim2.new(0.7, 0, 1, 0) -- Default 100% = 0.7 position (0.5-1.2 range)
    scaleSliderFill.Position = UDim2.new(0, 0, 0, 0)
    scaleSliderFill.BackgroundColor3 = colors.primary
    scaleSliderFill.BorderSizePixel = 0
    scaleSliderFill.Parent = scaleSliderBg
    
    local scaleSliderFillCorner = Instance.new("UICorner")
    scaleSliderFillCorner.CornerRadius = UDim.new(0, 3)
    scaleSliderFillCorner.Parent = scaleSliderFill
    
    -- Scale Slider Handle
    local scaleSliderHandle = Instance.new("Frame")
    scaleSliderHandle.Name = "ScaleSliderHandle"
    scaleSliderHandle.Size = UDim2.new(0, 16, 0, 16)
    scaleSliderHandle.Position = UDim2.new(0.7, -8, 0, 20) -- Default 100% position
    scaleSliderHandle.BackgroundColor3 = colors.text
    scaleSliderHandle.BorderSizePixel = 0
    scaleSliderHandle.ZIndex = 2
    scaleSliderHandle.Parent = scaleFrame
    
    local scaleSliderHandleCorner = Instance.new("UICorner")
    scaleSliderHandleCorner.CornerRadius = UDim.new(0, 8)
    scaleSliderHandleCorner.Parent = scaleSliderHandle
    
    -- Scale Slider Interaction
    local isDraggingScaleSlider = false
    
    scaleSliderHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingScaleSlider = true
        end
    end)
    
    scaleSliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingScaleSlider = true
            -- Update slider position immediately
            local relativeX = (input.Position.X - scaleSliderBg.AbsolutePosition.X) / scaleSliderBg.AbsoluteSize.X
            relativeX = math.max(0, math.min(1, relativeX))
            local uiScaleValue = 0.5 + (relativeX * 0.7) -- Map 0-1 to 0.5-1.2
            
            -- Update UI
            scaleSliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
            scaleSliderHandle.Position = UDim2.new(relativeX, -8, 0, 20)
            scaleLabel.Text = "UI Scale: " .. math.floor(uiScaleValue * 100) .. "%"
            
            -- Apply scale
            if AutoTradeUI.SetUIScale then
                AutoTradeUI.SetUIScale(uiScaleValue)
            end
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and isDraggingScaleSlider then
            local relativeX = (input.Position.X - scaleSliderBg.AbsolutePosition.X) / scaleSliderBg.AbsoluteSize.X
            relativeX = math.max(0, math.min(1, relativeX))
            local uiScaleValue = 0.5 + (relativeX * 0.7) -- Map 0-1 to 0.5-1.2
            
            -- Update UI
            scaleSliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
            scaleSliderHandle.Position = UDim2.new(relativeX, -8, 0, 20)
            scaleLabel.Text = "UI Scale: " .. math.floor(uiScaleValue * 100) .. "%"
            
            -- Apply scale
            if AutoTradeUI.SetUIScale then
                AutoTradeUI.SetUIScale(uiScaleValue)
            end
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if isDraggingScaleSlider then
                -- Save config when user finishes dragging UI scale slider
                saveConfig()
            end
            isDraggingScaleSlider = false
        end
    end)
    
    -- Filters Container (Horizontal Layout)
    local filtersContainer = Instance.new("Frame")
    filtersContainer.Name = "FiltersContainer"
    filtersContainer.Size = UDim2.new(1, -20, 0, 60) -- Height for label + dropdown
    filtersContainer.BackgroundTransparency = 1
    filtersContainer.LayoutOrder = 8
    filtersContainer.Parent = targetSection
    
    -- Left side: Mutation Filter
    local mutationContainer = Instance.new("Frame")
    mutationContainer.Name = "MutationContainer"
    mutationContainer.Size = UDim2.new(0.6, -5, 1, 0) -- 60% width minus padding
    mutationContainer.Position = UDim2.new(0, 0, 0, 0)
    mutationContainer.BackgroundTransparency = 1
    mutationContainer.Parent = filtersContainer
    
    local globalMutationLabel = Instance.new("TextLabel")
    globalMutationLabel.Name = "GlobalMutationLabel"
    globalMutationLabel.Size = UDim2.new(1, 0, 0, 15)
    globalMutationLabel.Position = UDim2.new(0, 0, 0, 0)
    globalMutationLabel.BackgroundTransparency = 1
    globalMutationLabel.Text = "Mutation Filter"
    globalMutationLabel.TextSize = 10
    globalMutationLabel.Font = Enum.Font.GothamSemibold
    globalMutationLabel.TextColor3 = colors.text
    globalMutationLabel.TextXAlignment = Enum.TextXAlignment.Center
    globalMutationLabel.Parent = mutationContainer
    
    local globalMutationDropdown = Instance.new("TextButton")
    globalMutationDropdown.Name = "GlobalMutationDropdown"
    globalMutationDropdown.Size = UDim2.new(1, 0, 0, 25)
    globalMutationDropdown.Position = UDim2.new(0, 0, 0, 20)
    globalMutationDropdown.BackgroundColor3 = colors.surface
    globalMutationDropdown.BorderSizePixel = 0
    globalMutationDropdown.Text = "Any ▼"
    globalMutationDropdown.TextSize = 11
    globalMutationDropdown.Font = Enum.Font.Gotham
    globalMutationDropdown.TextColor3 = colors.text
    globalMutationDropdown.Parent = mutationContainer
    
    local globalMutationCorner = Instance.new("UICorner")
    globalMutationCorner.CornerRadius = UDim.new(0, 4)
    globalMutationCorner.Parent = globalMutationDropdown
    
    -- Right side: Ocean Filter
    local oceanContainer = Instance.new("Frame")
    oceanContainer.Name = "OceanContainer"
    oceanContainer.Size = UDim2.new(0.4, -5, 1, 0) -- 40% width minus padding
    oceanContainer.Position = UDim2.new(0.6, 5, 0, 0)
    oceanContainer.BackgroundTransparency = 1
    oceanContainer.Parent = filtersContainer
    
    local oceanLabel = Instance.new("TextLabel")
    oceanLabel.Name = "OceanLabel"
    oceanLabel.Size = UDim2.new(1, 0, 0, 15)
    oceanLabel.Position = UDim2.new(0, 0, 0, 0)
    oceanLabel.BackgroundTransparency = 1
    oceanLabel.Text = "Exclude Ocean Pets/Egg"
    oceanLabel.TextSize = 10
    oceanLabel.Font = Enum.Font.GothamSemibold
    oceanLabel.TextColor3 = colors.text
    oceanLabel.TextXAlignment = Enum.TextXAlignment.Left
    oceanLabel.Parent = oceanContainer
    
    local oceanToggle = Instance.new("TextButton")
    oceanToggle.Name = "OceanToggle"
    oceanToggle.Size = UDim2.new(1, 0, 0, 25)
    oceanToggle.Position = UDim2.new(0, 0, 0, 20)
    oceanToggle.BackgroundColor3 = oceanOnlyFilter and colors.warning or colors.surface
    oceanToggle.BorderSizePixel = 0
    oceanToggle.Text = oceanOnlyFilter and "Yes" or "No"
    oceanToggle.TextSize = 11
    oceanToggle.Font = Enum.Font.GothamSemibold
    oceanToggle.TextColor3 = colors.text
    oceanToggle.Parent = oceanContainer
    
    local oceanToggleCorner = Instance.new("UICorner")
    oceanToggleCorner.CornerRadius = UDim.new(0, 4)
    oceanToggleCorner.Parent = oceanToggle
    
    -- Ocean toggle functionality
    oceanToggle.MouseButton1Click:Connect(function()
        oceanOnlyFilter = not oceanOnlyFilter
        
        if oceanOnlyFilter then
            oceanToggle.BackgroundColor3 = colors.warning
            oceanToggle.Text = "Yes"
        else
            oceanToggle.BackgroundColor3 = colors.surface
            oceanToggle.Text = "No"
        end
        
        -- No need to refresh content since this only affects sending, not display
        -- Save to config
        saveConfig()
    end)
    
    -- Global Mutation Dropdown List (positioned relative to filters container)
    local globalMutationList = Instance.new("ScrollingFrame")
    globalMutationList.Name = "GlobalMutationList"
    globalMutationList.Size = UDim2.new(1, -20, 0, 0)
    globalMutationList.BackgroundColor3 = colors.surface
    globalMutationList.BorderSizePixel = 0
    globalMutationList.Visible = false
    globalMutationList.ScrollBarThickness = 4
    globalMutationList.ScrollBarImageColor3 = colors.primary
    globalMutationList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    globalMutationList.ScrollingDirection = Enum.ScrollingDirection.Y
    globalMutationList.ZIndex = 100
    globalMutationList.LayoutOrder = 9
    globalMutationList.Parent = targetSection
    
    local globalMutationListCorner = Instance.new("UICorner")
    globalMutationListCorner.CornerRadius = UDim.new(0, 4)
    globalMutationListCorner.Parent = globalMutationList
    
    local globalMutationListLayout = Instance.new("UIListLayout")
    globalMutationListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    globalMutationListLayout.Padding = UDim.new(0, 2)
    globalMutationListLayout.Parent = globalMutationList
    
    -- Helper function to check if mutation is selected
    local function isMutationSelected(mutationId)
        for _, selected in ipairs(globalMutationFilters) do
            if selected == mutationId then
                return true
            end
        end
        return false
    end
    
    -- Helper function to update dropdown button text
    local function updateDropdownText()
        if #globalMutationFilters == 1 and globalMutationFilters[1] == "Any" then
            globalMutationDropdown.Text = "Any ▼"
        elseif #globalMutationFilters == 1 then
            local mutationData = MutationData[globalMutationFilters[1]]
            globalMutationDropdown.Text = (mutationData and mutationData.Icon or "?") .. " ▼"
        else
            globalMutationDropdown.Text = #globalMutationFilters .. " Selected ▼"
        end
    end
    
    -- Create global mutation options
    local globalMutationOptions = {"Any", "None", "Golden", "Diamond", "Electirc", "Fire", "Dino", "Snow"}
    for i, mutationId in ipairs(globalMutationOptions) do
        local option = Instance.new("TextButton")
        option.Name = "Option_" .. mutationId
        option.Size = UDim2.new(1, 0, 0, 25)
        option.BackgroundColor3 = isMutationSelected(mutationId) and Color3.fromRGB(0, 132, 255) or colors.surface
        option.BorderSizePixel = 0
        option.ZIndex = 101
        option.Parent = globalMutationList
        
        if mutationId == "Any" then
            option.Text = "Any Mutation"
        else
            local mutationData = MutationData[mutationId]
            option.Text = (mutationData and mutationData.Icon or "?") .. " " .. (mutationData and mutationData.Name or mutationId)
        end
        option.TextSize = 11
        option.Font = Enum.Font.Gotham
        option.TextColor3 = isMutationSelected(mutationId) and Color3.fromRGB(255, 255, 255) or colors.text
        option.TextXAlignment = Enum.TextXAlignment.Center
        
        local optionCorner = Instance.new("UICorner")
        optionCorner.CornerRadius = UDim.new(0, 4)
        optionCorner.Parent = option
        
        -- Hover effect
        option.MouseEnter:Connect(function()
            if not isMutationSelected(mutationId) then
                option.BackgroundColor3 = colors.hover
            end
        end)
        
        option.MouseLeave:Connect(function()
            if not isMutationSelected(mutationId) then
                option.BackgroundColor3 = colors.surface
            end
        end)
        
        -- Multi-selection logic
        option.MouseButton1Click:Connect(function()
            if mutationId == "Any" then
                -- If "Any" is clicked, clear all other selections
                globalMutationFilters = {"Any"}
            else
                -- Remove "Any" if it's selected and we're selecting something specific
                if globalMutationFilters[1] == "Any" and #globalMutationFilters == 1 then
                    globalMutationFilters = {}
                end
                
                -- Toggle the mutation
                local isSelected = isMutationSelected(mutationId)
                if isSelected then
                    -- Remove from selection
                    for i, selected in ipairs(globalMutationFilters) do
                        if selected == mutationId then
                            table.remove(globalMutationFilters, i)
                            break
                        end
                    end
                    -- If no mutations selected, default to "Any"
                    if #globalMutationFilters == 0 then
                        globalMutationFilters = {"Any"}
                    end
                else
                    -- Add to selection
                    table.insert(globalMutationFilters, mutationId)
                end
            end
            
            -- Update all option backgrounds
            for _, child in pairs(globalMutationList:GetChildren()) do
                if child:IsA("TextButton") then
                    local childMutationId = child.Name:gsub("Option_", "")
                    if isMutationSelected(childMutationId) then
                        child.BackgroundColor3 = Color3.fromRGB(0, 132, 255)
                        child.TextColor3 = Color3.fromRGB(255, 255, 255)
                    else
                        child.BackgroundColor3 = colors.surface
                        child.TextColor3 = colors.text
                    end
                end
            end
            
            -- Update dropdown button text
            updateDropdownText()
            
            -- Don't hide dropdown for multi-selection (let user select multiple)
            -- Hide dropdown only if "Any" was selected
            if mutationId == "Any" then
                globalMutationList.Visible = false
                globalMutationList.Size = UDim2.new(1, -20, 0, 0)
            end
            
            -- Refresh content to apply filter
            if refreshContent then
                refreshContent()
            end
            
            -- Save to config
            saveConfig()
        end)
    end
    
    -- Global mutation dropdown toggle
    globalMutationDropdown.MouseButton1Click:Connect(function()
        if globalMutationList.Visible then
            -- Hide dropdown
            globalMutationList.Visible = false
            globalMutationList.Size = UDim2.new(1, -20, 0, 0)
        else
            -- Show dropdown
            local listHeight = math.min(#globalMutationOptions * 27, 150)
            globalMutationList.Size = UDim2.new(1, -20, 0, listHeight)
            globalMutationList.Visible = true
        end
    end)
    
    
    -- Auto Trade Toggle
    local autoTradeToggle = Instance.new("TextButton")
    autoTradeToggle.Name = "AutoTradeToggle"
    autoTradeToggle.Size = UDim2.new(1, -20, 0, 35)
    autoTradeToggle.BackgroundColor3 = autoTradeEnabled and colors.success or colors.hover
    autoTradeToggle.BorderSizePixel = 0
    autoTradeToggle.Text = autoTradeEnabled and "Auto Trade: ON" or "Auto Trade: OFF"
    autoTradeToggle.TextSize = 14
    autoTradeToggle.Font = Enum.Font.GothamSemibold
    autoTradeToggle.TextColor3 = colors.text
    autoTradeToggle.LayoutOrder = 10
    autoTradeToggle.Parent = targetSection
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 6)
    toggleCorner.Parent = autoTradeToggle
    
    -- Daily Gift Counter Display
    local giftCountLabel = Instance.new("TextLabel")
    giftCountLabel.Name = "GiftCountLabel"
    giftCountLabel.Size = UDim2.new(1, -20, 0, 25)
    giftCountLabel.BackgroundTransparency = 1
    giftCountLabel.Text = "Today Gift: 0/500"
    giftCountLabel.TextSize = 12
    giftCountLabel.Font = Enum.Font.Gotham
    giftCountLabel.TextColor3 = colors.textSecondary
    giftCountLabel.TextXAlignment = Enum.TextXAlignment.Center
    giftCountLabel.LayoutOrder = 11
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
    sortBtn.Size = UDim2.new(0.18, -5, 0, 30)
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
    sortList.Size = UDim2.new(0.18, -5, 0, 120)
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
    zeroToggle.Size = UDim2.new(0.12, -5, 0, 30)
    zeroToggle.Position = UDim2.new(0.48, 8, 0, 10)
    zeroToggle.BackgroundColor3 = showZeroItems and colors.primary or colors.hover
    zeroToggle.BorderSizePixel = 0
    zeroToggle.Text = "Show 0x"
    zeroToggle.TextSize = 11
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
    configToggle.Position = UDim2.new(0.6, 5, 0, 10)
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
    card.ZIndex = 1 -- Base z-index for card
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
            icon.ZIndex = 2
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
    nameLabel.ZIndex = 2
    nameLabel.Parent = card
    
    -- Owned Amount
    local ownedLabel = Instance.new("TextLabel")
    ownedLabel.Name = "OwnedLabel"
    ownedLabel.Size = UDim2.new(0, 80, 0, 16)
    local ownedLabelX = category == "pets" and 10 or 60
    ownedLabel.Position = UDim2.new(0, ownedLabelX, 0, 25)
    ownedLabel.BackgroundTransparency = 1
    ownedLabel.Text = "Own: " .. ownedAmount .. "x"
    ownedLabel.TextSize = 12
    ownedLabel.Font = Enum.Font.Gotham
    ownedLabel.TextColor3 = colors.textSecondary
    ownedLabel.TextXAlignment = Enum.TextXAlignment.Left
    ownedLabel.ZIndex = 2
    ownedLabel.Parent = card
    
    -- Warning icon for insufficient items (same line as owned count)
    local warningIcon = Instance.new("TextLabel")
    warningIcon.Name = "WarningIcon"
    warningIcon.Size = UDim2.new(0, 70, 0, 16)
    warningIcon.Position = UDim2.new(0, ownedLabelX + 85, 0, 25) -- Same line as owned label, positioned after it
    warningIcon.BackgroundTransparency = 1
    warningIcon.Text = "⚠️"
    warningIcon.TextSize = 10
    warningIcon.Font = Enum.Font.GothamSemibold
    warningIcon.TextColor3 = colors.warning
    warningIcon.TextXAlignment = Enum.TextXAlignment.Left
    warningIcon.Visible = false
    warningIcon.ZIndex = 10 -- Ensure it appears above other elements
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
        -- Only show value if user has actually configured this item, otherwise leave empty
        local config = itemConfigs[category][itemId]
        if config and config.enabled then
            sendInput.Text = tostring(config.sendUntil or 0)
        else
            sendInput.Text = "" -- Empty field, shows placeholder "Keep"
        end
        sendInput.PlaceholderText = "Keep"
        sendInput.TextSize = 12
        sendInput.Font = Enum.Font.Gotham
        sendInput.TextColor3 = colors.text
        sendInput.TextXAlignment = Enum.TextXAlignment.Center
        sendInput.ClearTextOnFocus = false
        sendInput.ZIndex = 2
        sendInput.Parent = card
        
        -- Input validation to only allow numbers
        sendInput:GetPropertyChangedSignal("Text"):Connect(function()
            local text = sendInput.Text
            local filteredText = text:gsub("[^%d]", "") -- Only allow digits
            if text ~= filteredText then
                sendInput.Text = filteredText
            end
        end)
        
        local inputCorner = Instance.new("UICorner")
        inputCorner.CornerRadius = UDim.new(0, 4)
        inputCorner.Parent = sendInput
        
        -- Update config when input changes (with debouncing)
        local inputDebounce = false
        sendInput.FocusLost:Connect(function(enterPressed)
            if inputDebounce then return end
            inputDebounce = true
            
            -- Add small delay to prevent rapid firing
            task.wait(0.1)
            
            local inputText = sendInput.Text:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
            
            if inputText == "" then
                -- Empty input - disable this item
                if itemConfigs[category][itemId] then
                    itemConfigs[category][itemId].enabled = false
                end
            else
                -- User entered a value - enable and save it
                local value = tonumber(inputText) or 0
                if not itemConfigs[category][itemId] then
                    itemConfigs[category][itemId] = {}
                end
                itemConfigs[category][itemId].sendUntil = value
                itemConfigs[category][itemId].enabled = true
            end
            
            -- Update warning with new format: "nX ⚠️"
            local config = itemConfigs[category][itemId]
            if config and config.enabled then
                local currentValue = config.sendUntil or 0
                if currentValue == 0 then
                    -- When target is 0 (send all), no warning needed
                    warningIcon.Visible = false
                else
                    -- When target > 0, show warning only if we don't have enough
                    if ownedAmount < currentValue then
                        local difference = currentValue - ownedAmount
                        warningIcon.Text = difference .. "X ⚠️"
                        warningIcon.Visible = true
                    else
                        warningIcon.Visible = false
                    end
                end
            else
                -- No config or disabled - hide warning
                warningIcon.Visible = false
            end
            
            saveConfig()
            inputDebounce = false
        end)
        
        -- Show warning initially if needed with new format
        local config = itemConfigs[category][itemId]
        if config and config.enabled then
            local currentSendUntil = config.sendUntil or 0
            if currentSendUntil == 0 then
                -- When target is 0 (send all), no warning needed
                warningIcon.Visible = false
            else
                -- When target > 0, show warning only if we don't have enough
                if ownedAmount < currentSendUntil then
                    local difference = currentSendUntil - ownedAmount
                    warningIcon.Text = difference .. "X ⚠️"
                    warningIcon.Visible = true
                else
                    warningIcon.Visible = false
                end
            end
        else
            warningIcon.Visible = false -- No warning if not configured
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
    minSpeedInput.ClearTextOnFocus = false
    minSpeedInput.Parent = speedFrame
    
    -- Input validation for min speed (allow numbers and common suffixes)
    minSpeedInput:GetPropertyChangedSignal("Text"):Connect(function()
        local text = minSpeedInput.Text
        local filteredText = text:gsub("[^%d%.KkMmBbTt]", "") -- Allow digits, decimal, and suffixes
        if text ~= filteredText then
            minSpeedInput.Text = filteredText
        end
    end)
    
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
    maxSpeedInput.ClearTextOnFocus = false
    maxSpeedInput.Parent = speedFrame
    
    -- Input validation for max speed (allow numbers and common suffixes)
    maxSpeedInput:GetPropertyChangedSignal("Text"):Connect(function()
        local text = maxSpeedInput.Text
        local filteredText = text:gsub("[^%d%.KkMmBbTt]", "") -- Allow digits, decimal, and suffixes
        if text ~= filteredText then
            maxSpeedInput.Text = filteredText
        end
    end)
    
    local maxCorner = Instance.new("UICorner")
    maxCorner.CornerRadius = UDim.new(0, 4)
    maxCorner.Parent = maxSpeedInput
    
    return speedFrame, modeToggle, minSpeedInput, maxSpeedInput
end

-- Targeted update functions
updateOwnedAmounts = function()
    if not ScreenGui or not ScreenGui.Parent then return end
    
    local tabSection = ScreenGui.MainFrame:FindFirstChild("TabSection")
    if not tabSection then return end
    
    local scrollFrame = tabSection.ContentArea.ScrollFrame
    local inventory = getPlayerInventory()
    
    -- Update owned amounts for all visible item cards
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" then
            local ownedLabel = child:FindFirstChild("OwnedLabel")
            if ownedLabel and ownedLabel:IsA("TextLabel") then
                -- Extract item info from the card name
                local itemId = child.Name
                local ownedAmount = 0
                
                -- Determine category based on current tab
                if currentTab == "Pets" then
                    ownedAmount = inventory.pets[itemId] or 0
                elseif currentTab == "Eggs" then
                    ownedAmount = inventory.eggs[itemId] or 0
                elseif currentTab == "Fruits" then
                    ownedAmount = inventory.fruits[itemId] or 0
                end
                
                -- Update the owned label
                ownedLabel.Text = "Own: " .. ownedAmount .. "x"
                
                -- Update warning icon if needed
                local warningIcon = child:FindFirstChild("WarningIcon")
                if warningIcon then
                    local sendUntil = 0
                    local category = currentTab:lower()
                    if itemConfigs[category] and itemConfigs[category][itemId] then
                        sendUntil = itemConfigs[category][itemId].sendUntil or 0
                    end
                    
                    if sendUntil == 0 then
                        -- When target is 0 (send all), no warning needed
                        warningIcon.Visible = false
                    else
                        -- When target > 0, show warning only if we don't have enough
                        if ownedAmount < sendUntil then
                            local difference = sendUntil - ownedAmount
                            warningIcon.Text = difference .. "X ⚠️"
                            warningIcon.Visible = true
                        else
                            warningIcon.Visible = false
                        end
                    end
                end
            end
        end
    end
end

updateTargetDropdown = function()
    if not ScreenGui or not ScreenGui.Parent then return end
    
    local targetSection = ScreenGui.MainFrame:FindFirstChild("TargetSection")
    if not targetSection then return end
    
    local dropdownList = targetSection:FindFirstChild("DropdownList")
    if not dropdownList then return end
    
    -- Clear existing options
    for _, child in pairs(dropdownList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Repopulate with current players
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
        option.ZIndex = 101
        option.Parent = dropdownList
        
        local optionPadding = Instance.new("UIPadding")
        optionPadding.PaddingLeft = UDim.new(0, 8)
        optionPadding.Parent = option
        
        option.MouseButton1Click:Connect(function()
            selectedTarget = playerName
            if targetSection.NameLabel then
                targetSection.NameLabel.Text = playerName
            end
            dropdownList.Visible = false
            saveConfig()
        end)
        
        option.MouseEnter:Connect(function()
            option.BackgroundColor3 = colors.primary
        end)
        
        option.MouseLeave:Connect(function()
            option.BackgroundColor3 = colors.hover
        end)
    end
end

-- Refresh Content (only recreates UI when necessary)
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
        
        -- Speed input functionality (debounced updates)
        local minInputDebounce = false
        local maxInputDebounce = false
        
        minInput.FocusLost:Connect(function()
            if minInputDebounce then return end
            minInputDebounce = true
            
            task.wait(0.1)
            
            local newValue = tonumber(minInput.Text) or 0
            if newValue ~= petSpeedMin then
                petSpeedMin = newValue
                saveConfig()
                if petMode == "Speed" then
                    refreshContent() -- Refresh to show pets matching new speed range
                end
            end
            
            minInputDebounce = false
        end)
        
        maxInput.FocusLost:Connect(function()
            if maxInputDebounce then return end
            maxInputDebounce = true
            
            task.wait(0.1)
            
            local newValue = tonumber(maxInput.Text) or 999999999
            if newValue ~= petSpeedMax then
                petSpeedMax = newValue
                saveConfig()
                if petMode == "Speed" then
                    refreshContent() -- Refresh to show pets matching new speed range
                end
            end
            
            maxInputDebounce = false
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
            -- In speed mode, show pets that match current speed range (exclude placed pets)
            local inventory = getPlayerInventory()
            local petsFolder = LocalPlayer.PlayerGui.Data and LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
            if petsFolder then
                for _, petData in pairs(petsFolder:GetChildren()) do
                    if petData:IsA("Configuration") then
                        local petType = safeGetAttribute(petData, "T", nil)
                        local isPlaced = safeGetAttribute(petData, "D", nil) ~= nil
                        if petType and petType ~= "" and not isPlaced then
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
    
    -- Fixed UI dimensions (like WindUI - no complex scaling)
    local baseWidth = 900
    local baseHeight = 650
    
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AutoTradeUI"
    ScreenGui.Parent = PlayerGui
    
    -- Add UIScale for responsive scaling (like WindUI)
    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 1.0
    uiScale.Parent = ScreenGui
    
    -- WindUI-style responsive scaling function
    local function setUIScale(scale)
        TweenService:Create(uiScale, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Scale = scale
        }):Play()
    end
    
    -- Auto-scale based on screen size (like WindUI)
    local function checkAndAutoScale()
        local screenSize = workspace.CurrentCamera.ViewportSize
        local uiWidth = baseWidth * uiScale.Scale
        local uiHeight = baseHeight * uiScale.Scale
        
        -- If UI doesn't fit on screen (with 40px margin), scale it down
        if (screenSize.X - 40 < uiWidth) or (screenSize.Y - 40 < uiHeight) then
            -- Calculate required scale to fit
            local scaleX = (screenSize.X - 40) / baseWidth
            local scaleY = (screenSize.Y - 40) / baseHeight
            local requiredScale = math.min(scaleX, scaleY)
            
            -- Don't go below 0.3 scale (30%)
            requiredScale = math.max(requiredScale, 0.3)
            
            setUIScale(requiredScale)
        end
    end
    
    -- Store reference for external access
    AutoTradeUI.SetUIScale = setUIScale
    AutoTradeUI.CheckAutoScale = checkAndAutoScale
    
    MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, baseWidth, 0, baseHeight)
    MainFrame.Position = UDim2.new(0.5, -baseWidth/2, 0.5, -baseHeight/2)
    MainFrame.BackgroundColor3 = colors.background
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    originalSize = MainFrame.Size
    minimizedSize = UDim2.new(0, baseWidth, 0, 60)
    
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
    
    -- Apply auto-scaling after UI is created
    task.wait(0.1) -- Wait for UI to render
    checkAndAutoScale()
    
    -- Monitor screen size changes
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(checkAndAutoScale)
    
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
        
        -- Update UI every 5 seconds for real-time inventory amounts and gift count
        if currentTime - lastInventoryUpdate >= 5 then
            lastInventoryUpdate = currentTime
            if ScreenGui and ScreenGui.Enabled then
                updateOwnedAmounts() -- Only update owned amounts, don't recreate UI
                updateGiftCountDisplay() -- Update gift counter
                updateTargetDropdown() -- Update player list
            end
        end
        
        if autoTradeEnabled and not isTrading then
            -- Check for items to send with speed adjustment
            task.wait(sendingSpeed)
        end
    end)
end

-- Start monitoring when module loads
startInventoryMonitoring()

return AutoTradeUI
