-- AutoTradeUI.lua - Advanced Auto Trade System with Custom UI
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

-- UI Variables
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ScreenGui = nil
local MainFrame = nil
local isDragging = false
local dragStart = nil
local startPos = nil
local isMinimized = false
local originalSize = nil
local minimizedSize = nil

-- Trade State
local selectedTarget = nil
local autoTradeEnabled = false
local tradeSettings = {
    eggs = {},
    fruits = {},
    pets = {}
}
local savedPosition = nil

-- Data from other modules
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
    error = Color3.fromRGB(255, 69, 58)
}

-- Utility Functions
local function formatNumber(num)
    if type(num) == "string" then
        return num
    end
    if num >= 1e12 then
        return string.format("%.1fT", num / 1e12)
    elseif num >= 1e9 then
        return string.format("%.1fB", num / 1e9)
    elseif num >= 1e6 then
        return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    else
        return tostring(num)
    end
end

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

-- Get screen size for responsive UI
local function getScreenSize()
    local camera = workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    return Vector2.new(1920, 1080) -- Default fallback
end

-- Calculate responsive size
local function getResponsiveSize(baseWidth, baseHeight)
    local screenSize = getScreenSize()
    local scaleX = screenSize.X / 1920 -- Base resolution 1920x1080
    local scaleY = screenSize.Y / 1080
    local scale = math.min(scaleX, scaleY) -- Use smaller scale to maintain aspect ratio
    scale = math.max(0.6, math.min(1.2, scale)) -- Clamp between 60% and 120%
    
    return UDim2.new(0, baseWidth * scale, 0, baseHeight * scale)
end

-- Inventory Functions
local function normalizeFruitName(name)
    if type(name) ~= "string" then return "" end
    local lowered = string.lower(name)
    lowered = lowered:gsub("[%s_%-%./]", "")
    return lowered
end

local function getPlayerFruitInventory()
    local fruitInventory = {}
    
    if not LocalPlayer or not LocalPlayer.PlayerGui then
        return fruitInventory
    end
    
    local data = LocalPlayer.PlayerGui:FindFirstChild("Data")
    if not data then
        return fruitInventory
    end
    
    local asset = data:FindFirstChild("Asset")
    if not asset then
        return fruitInventory
    end
    
    -- Read from Attributes on Asset
    local ok, attrs = pcall(function()
        return asset:GetAttributes()
    end)
    
    if ok and type(attrs) == "table" then
        for id, item in pairs(FruitData) do
            local display = item.Name or id
            local amount = attrs[display] or attrs[id]
            
            if amount == nil then
                -- Fallback by normalized key search
                local wantA, wantB = normalizeFruitName(display), normalizeFruitName(id)
                for k, v in pairs(attrs) do
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
    end
    
    return fruitInventory
end

local function getPlayerEggInventory()
    local eggInventory = {}
    
    if not LocalPlayer or not LocalPlayer.PlayerGui then
        return eggInventory
    end
    
    local data = LocalPlayer.PlayerGui:FindFirstChild("Data")
    if not data then
        return eggInventory
    end
    
    local eggsFolder = data:FindFirstChild("Egg")
    if not eggsFolder then
        return eggInventory
    end
    
    for _, eggData in pairs(eggsFolder:GetChildren()) do
        if eggData:IsA("Configuration") then
            local eggType = eggData:GetAttribute("T")
            if eggType then
                eggInventory[eggType] = (eggInventory[eggType] or 0) + 1
            end
        end
    end
    
    return eggInventory
end

local function getPlayerPetInventory()
    local petInventory = {}
    
    if not LocalPlayer or not LocalPlayer.PlayerGui then
        return petInventory
    end
    
    local data = LocalPlayer.PlayerGui:FindFirstChild("Data")
    if not data then
        return petInventory
    end
    
    local petsFolder = data:FindFirstChild("Pets")
    if not petsFolder then
        return petInventory
    end
    
    for _, petData in pairs(petsFolder:GetChildren()) do
        if petData:IsA("Configuration") then
            local petType = petData:GetAttribute("T")
            if petType then
                petInventory[petType] = (petInventory[petType] or 0) + 1
            end
        end
    end
    
    return petInventory
end

-- Player Functions
local function getPlayerList()
    local playerList = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerList, player)
        end
    end
    
    return playerList
end

local function getPlayerAvatar(player)
    if player and player.UserId then
        return "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=150&height=150&format=png"
    end
    return ""
end

-- Trade Functions
local function saveCurrentPosition()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        savedPosition = LocalPlayer.Character.HumanoidRootPart.CFrame
    end
end

local function teleportToPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then
        return false
    end
    
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not targetRoot or not myRoot then
        return false
    end
    
    -- Teleport near the target player
    local offset = Vector3.new(5, 0, 5) -- 5 studs away
    myRoot.CFrame = targetRoot.CFrame + offset
    
    return true
end

local function teleportBack()
    if savedPosition and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = savedPosition
    end
end

local function focusItem(itemUID)
    local success, err = pcall(function()
        local args = {"Focus", itemUID}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    return success
end

local function giftToPlayer(targetPlayer)
    local success, err = pcall(function()
        local args = {targetPlayer}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(unpack(args))
    end)
    
    return success
end

local function findItemUID(itemName, itemType)
    if not LocalPlayer or not LocalPlayer.PlayerGui then
        return nil
    end
    
    local data = LocalPlayer.PlayerGui:FindFirstChild("Data")
    if not data then
        return nil
    end
    
    local folder = nil
    if itemType == "egg" then
        folder = data:FindFirstChild("Egg")
    elseif itemType == "fruit" then
        folder = data:FindFirstChild("Asset")
    elseif itemType == "pet" then
        folder = data:FindFirstChild("Pets")
    end
    
    if not folder then
        return nil
    end
    
    if itemType == "fruit" then
        -- For fruits, we need to check attributes
        local amount = folder:GetAttribute(itemName)
        if amount and amount > 0 then
            return itemName -- For fruits, the name is the identifier
        end
    else
        -- For eggs and pets, check configurations
        for _, item in pairs(folder:GetChildren()) do
            if item:IsA("Configuration") then
                local itemTypeAttr = item:GetAttribute("T")
                if itemTypeAttr == itemName then
                    return item.Name -- Return the UID
                end
            end
        end
    end
    
    return nil
end

local function sendItem(itemName, itemType, targetPlayer)
    if not targetPlayer or not targetPlayer.Parent then
        return false, "Target player not found"
    end
    
    -- Save current position
    saveCurrentPosition()
    
    -- Teleport to target player
    if not teleportToPlayer(targetPlayer) then
        return false, "Failed to teleport to target"
    end
    
    task.wait(0.5) -- Wait for teleport to complete
    
    -- Find item UID
    local itemUID = findItemUID(itemName, itemType)
    if not itemUID then
        teleportBack()
        return false, "Item not found in inventory"
    end
    
    -- Focus the item
    if not focusItem(itemUID) then
        teleportBack()
        return false, "Failed to focus item"
    end
    
    task.wait(0.2) -- Wait for focus
    
    -- Gift to player
    if not giftToPlayer(targetPlayer) then
        teleportBack()
        return false, "Failed to gift item"
    end
    
    task.wait(0.5) -- Wait for gift to process
    
    -- Teleport back
    teleportBack()
    
    return true, "Item sent successfully"
end

-- UI Creation Functions
local function createWindowControls(parent)
    local controlsContainer = Instance.new("Frame")
    controlsContainer.Name = "WindowControls"
    controlsContainer.Size = UDim2.new(0, 70, 0, 12)
    controlsContainer.Position = UDim2.new(0, 12, 0, 12)
    controlsContainer.BackgroundTransparency = 1
    controlsContainer.Parent = parent
    
    -- Close Button (Red)
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
    
    -- Minimize Button (Yellow)
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
    
    -- Maximize Button (Green)
    local maximizeBtn = Instance.new("TextButton")
    maximizeBtn.Name = "MaximizeBtn"
    maximizeBtn.Size = UDim2.new(0, 12, 0, 12)
    maximizeBtn.Position = UDim2.new(0, 36, 0, 0)
    maximizeBtn.BackgroundColor3 = colors.maximize
    maximizeBtn.BorderSizePixel = 0
    maximizeBtn.Text = ""
    maximizeBtn.Parent = controlsContainer
    
    local maximizeCorner = Instance.new("UICorner")
    maximizeCorner.CornerRadius = UDim.new(0.5, 0)
    maximizeCorner.Parent = maximizeBtn
    
    return controlsContainer
end

local function createTargetPlayerCard(player, parent)
    local card = Instance.new("Frame")
    card.Name = "PlayerCard_" .. player.Name
    card.Size = UDim2.new(1, -16, 0, 80)
    card.BackgroundColor3 = selectedTarget == player and colors.selected or colors.surface
    card.BorderSizePixel = 0
    card.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = card
    
    -- Player Avatar
    local avatar = Instance.new("ImageLabel")
    avatar.Name = "Avatar"
    avatar.Size = UDim2.new(0, 60, 0, 60)
    avatar.Position = UDim2.new(0, 10, 0.5, -30)
    avatar.BackgroundTransparency = 1
    avatar.Image = getPlayerAvatar(player)
    avatar.Parent = card
    
    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(0.5, 0)
    avatarCorner.Parent = avatar
    
    -- Player Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "PlayerName"
    nameLabel.Size = UDim2.new(1, -80, 0, 25)
    nameLabel.Position = UDim2.new(0, 80, 0, 10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.DisplayName ~= player.Name and (player.DisplayName .. " (@" .. player.Name .. ")") or player.Name
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextColor3 = colors.text
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextWrapped = true
    nameLabel.Parent = card
    
    -- Send Button
    local sendBtn = Instance.new("TextButton")
    sendBtn.Name = "SendBtn"
    sendBtn.Size = UDim2.new(0, 80, 0, 25)
    sendBtn.Position = UDim2.new(1, -90, 1, -35)
    sendBtn.BackgroundColor3 = colors.primary
    sendBtn.BorderSizePixel = 0
    sendBtn.Text = "SEND"
    sendBtn.TextSize = 12
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.TextColor3 = colors.text
    sendBtn.Parent = card
    
    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 4)
    sendCorner.Parent = sendBtn
    
    -- Click to select target
    local clickBtn = Instance.new("TextButton")
    clickBtn.Name = "ClickBtn"
    clickBtn.Size = UDim2.new(1, 0, 1, 0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ""
    clickBtn.Parent = card
    
    clickBtn.MouseButton1Click:Connect(function()
        selectedTarget = player
        AutoTradeUI.RefreshTargets()
    end)
    
    -- Send button functionality
    sendBtn.MouseButton1Click:Connect(function()
        selectedTarget = player
        AutoTradeUI.StartSending()
    end)
    
    -- Hover effects
    clickBtn.MouseEnter:Connect(function()
        if selectedTarget ~= player then
            TweenService:Create(card, TweenInfo.new(0.2), {BackgroundColor3 = colors.hover}):Play()
        end
    end)
    
    clickBtn.MouseLeave:Connect(function()
        if selectedTarget ~= player then
            TweenService:Create(card, TweenInfo.new(0.2), {BackgroundColor3 = colors.surface}):Play()
        end
    end)
    
    return card
end

local function createItemCard(itemId, itemData, itemType, parent)
    local card = Instance.new("Frame")
    card.Name = itemId
    card.Size = UDim2.new(1, -16, 0, 100)
    card.BackgroundColor3 = colors.surface
    card.BorderSizePixel = 0
    card.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = card
    
    -- Item Icon
    local icon = nil
    if itemType == "egg" then
        icon = Instance.new("ImageLabel")
        icon.Image = itemData.Icon
        icon.ScaleType = Enum.ScaleType.Fit
    else
        icon = Instance.new("TextLabel")
        icon.Text = itemData.Icon
        icon.TextSize = 32
        icon.Font = Enum.Font.GothamBold
        icon.TextColor3 = getRarityColor(itemData.Rarity)
    end
    
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 60, 0, 60)
    icon.Position = UDim2.new(0, 10, 0.5, -30)
    icon.BackgroundTransparency = 1
    icon.Parent = card
    
    -- Item Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "ItemName"
    nameLabel.Size = UDim2.new(0, 150, 0, 20)
    nameLabel.Position = UDim2.new(0, 80, 0, 10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = itemData.Name
    nameLabel.TextSize = 12
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextColor3 = colors.text
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextWrapped = true
    nameLabel.Parent = card
    
    -- Amount Owned
    local amountLabel = Instance.new("TextLabel")
    amountLabel.Name = "AmountOwned"
    amountLabel.Size = UDim2.new(0, 150, 0, 15)
    amountLabel.Position = UDim2.new(0, 80, 0, 30)
    amountLabel.BackgroundTransparency = 1
    amountLabel.Text = "Loading..."
    amountLabel.TextSize = 10
    amountLabel.Font = Enum.Font.Gotham
    amountLabel.TextColor3 = colors.textSecondary
    amountLabel.TextXAlignment = Enum.TextXAlignment.Left
    amountLabel.Parent = card
    
    -- Send Amount Input
    local sendInput = Instance.new("TextBox")
    sendInput.Name = "SendAmount"
    sendInput.Size = UDim2.new(0, 60, 0, 25)
    sendInput.Position = UDim2.new(0, 80, 1, -35)
    sendInput.BackgroundColor3 = colors.hover
    sendInput.BorderSizePixel = 0
    sendInput.Text = tostring(tradeSettings[itemType .. "s"][itemId] or 0)
    sendInput.PlaceholderText = "0"
    sendInput.TextSize = 12
    sendInput.Font = Enum.Font.Gotham
    sendInput.TextColor3 = colors.text
    sendInput.TextXAlignment = Enum.TextXAlignment.Center
    sendInput.Parent = card
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 4)
    inputCorner.Parent = sendInput
    
    -- Send Amount Label
    local sendLabel = Instance.new("TextLabel")
    sendLabel.Name = "SendLabel"
    sendLabel.Size = UDim2.new(0, 80, 0, 15)
    sendLabel.Position = UDim2.new(0, 80, 0, 50)
    sendLabel.BackgroundTransparency = 1
    sendLabel.Text = "Send when ≥:"
    sendLabel.TextSize = 9
    sendLabel.Font = Enum.Font.Gotham
    sendLabel.TextColor3 = colors.textTertiary
    sendLabel.TextXAlignment = Enum.TextXAlignment.Left
    sendLabel.Parent = card
    
    -- Update inventory display
    local function updateInventoryDisplay()
        local inventory = nil
        if itemType == "egg" then
            inventory = getPlayerEggInventory()
        elseif itemType == "fruit" then
            inventory = getPlayerFruitInventory()
        elseif itemType == "pet" then
            inventory = getPlayerPetInventory()
        end
        
        local amount = 0
        if inventory then
            amount = inventory[itemData.Name] or inventory[itemId] or 0
        end
        
        amountLabel.Text = "Owned: " .. amount .. "x"
        
        if amount == 0 then
            amountLabel.TextColor3 = colors.error
        else
            amountLabel.TextColor3 = colors.textSecondary
        end
    end
    
    -- Update immediately and every 2 seconds
    updateInventoryDisplay()
    local connection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        if currentTime % 2 < 0.1 then -- Update every 2 seconds
            updateInventoryDisplay()
        end
    end)
    
    -- Clean up connection when card is destroyed
    card.AncestryChanged:Connect(function()
        if not card.Parent then
            connection:Disconnect()
        end
    end)
    
    -- Save send amount when changed
    sendInput.FocusLost:Connect(function()
        local amount = tonumber(sendInput.Text) or 0
        tradeSettings[itemType .. "s"][itemId] = amount
        AutoTradeUI.SaveSettings()
    end)
    
    -- Add "New" indicator for new items
    if itemData.IsNew then
        local newIndicator = Instance.new("TextLabel")
        newIndicator.Name = "NewIndicator"
        newIndicator.Size = UDim2.new(0, 30, 0, 16)
        newIndicator.Position = UDim2.new(1, -34, 0, 2)
        newIndicator.BackgroundColor3 = colors.error
        newIndicator.BorderSizePixel = 0
        newIndicator.Text = "NEW"
        newIndicator.TextSize = 8
        newIndicator.Font = Enum.Font.GothamBold
        newIndicator.TextColor3 = colors.text
        newIndicator.TextXAlignment = Enum.TextXAlignment.Center
        newIndicator.TextYAlignment = Enum.TextYAlignment.Center
        newIndicator.Parent = card
        
        local newCorner = Instance.new("UICorner")
        newCorner.CornerRadius = UDim.new(0, 3)
        newCorner.Parent = newIndicator
    end
    
    return card
end

-- Main UI Creation
function AutoTradeUI.CreateUI()
    if ScreenGui then
        ScreenGui:Destroy()
    end
    
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AutoTradeUI"
    ScreenGui.Parent = PlayerGui
    
    -- Calculate responsive size
    local baseSize = getResponsiveSize(1000, 600)
    
    MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = baseSize
    MainFrame.Position = UDim2.new(0.5, -baseSize.X.Offset/2, 0.5, -baseSize.Y.Offset/2)
    MainFrame.BackgroundColor3 = colors.background
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    originalSize = MainFrame.Size
    minimizedSize = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 60)
    
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
    title.Size = UDim2.new(1, -140, 0, 20)
    title.Position = UDim2.new(0, 100, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "Auto Trade System"
    title.TextSize = 14
    title.Font = Enum.Font.GothamSemibold
    title.TextColor3 = colors.text
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = MainFrame
    
    -- Auto Trade Toggle
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = "ToggleFrame"
    toggleFrame.Size = UDim2.new(1, -32, 0, 40)
    toggleFrame.Position = UDim2.new(0, 16, 0, 40)
    toggleFrame.BackgroundColor3 = colors.surface
    toggleFrame.BorderSizePixel = 0
    toggleFrame.Parent = MainFrame
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = toggleFrame
    
    local toggleLabel = Instance.new("TextLabel")
    toggleLabel.Name = "ToggleLabel"
    toggleLabel.Size = UDim2.new(1, -80, 1, 0)
    toggleLabel.Position = UDim2.new(0, 16, 0, 0)
    toggleLabel.BackgroundTransparency = 1
    toggleLabel.Text = "Auto Trade: Keep sending items when thresholds are met"
    toggleLabel.TextSize = 12
    toggleLabel.Font = Enum.Font.Gotham
    toggleLabel.TextColor3 = colors.text
    toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    toggleLabel.TextYAlignment = Enum.TextYAlignment.Center
    toggleLabel.TextWrapped = true
    toggleLabel.Parent = toggleFrame
    
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleBtn"
    toggleBtn.Size = UDim2.new(0, 60, 0, 24)
    toggleBtn.Position = UDim2.new(1, -76, 0.5, -12)
    toggleBtn.BackgroundColor3 = autoTradeEnabled and colors.success or colors.textTertiary
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = autoTradeEnabled and "ON" or "OFF"
    toggleBtn.TextSize = 10
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextColor3 = colors.text
    toggleBtn.Parent = toggleFrame
    
    local toggleBtnCorner = Instance.new("UICorner")
    toggleBtnCorner.CornerRadius = UDim.new(0, 12)
    toggleBtnCorner.Parent = toggleBtn
    
    -- Main Content Area
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -32, 1, -120)
    contentFrame.Position = UDim2.new(0, 16, 0, 100)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = MainFrame
    
    -- Left Side - Target Players
    local leftFrame = Instance.new("Frame")
    leftFrame.Name = "LeftFrame"
    leftFrame.Size = UDim2.new(0.3, -8, 1, 0)
    leftFrame.Position = UDim2.new(0, 0, 0, 0)
    leftFrame.BackgroundColor3 = colors.surface
    leftFrame.BorderSizePixel = 0
    leftFrame.Parent = contentFrame
    
    local leftCorner = Instance.new("UICorner")
    leftCorner.CornerRadius = UDim.new(0, 8)
    leftCorner.Parent = leftFrame
    
    local leftTitle = Instance.new("TextLabel")
    leftTitle.Name = "LeftTitle"
    leftTitle.Size = UDim2.new(1, -16, 0, 30)
    leftTitle.Position = UDim2.new(0, 8, 0, 8)
    leftTitle.BackgroundTransparency = 1
    leftTitle.Text = "Target Players"
    leftTitle.TextSize = 14
    leftTitle.Font = Enum.Font.GothamSemibold
    leftTitle.TextColor3 = colors.text
    leftTitle.TextXAlignment = Enum.TextXAlignment.Center
    leftTitle.Parent = leftFrame
    
    -- Refresh Players Button
    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Name = "RefreshBtn"
    refreshBtn.Size = UDim2.new(1, -16, 0, 25)
    refreshBtn.Position = UDim2.new(0, 8, 0, 40)
    refreshBtn.BackgroundColor3 = colors.primary
    refreshBtn.BorderSizePixel = 0
    refreshBtn.Text = "🔄 Refresh Players"
    refreshBtn.TextSize = 10
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextColor3 = colors.text
    refreshBtn.Parent = leftFrame
    
    local refreshCorner = Instance.new("UICorner")
    refreshCorner.CornerRadius = UDim.new(0, 4)
    refreshCorner.Parent = refreshBtn
    
    -- Players Scroll Frame
    local playersScroll = Instance.new("ScrollingFrame")
    playersScroll.Name = "PlayersScroll"
    playersScroll.Size = UDim2.new(1, -16, 1, -80)
    playersScroll.Position = UDim2.new(0, 8, 0, 72)
    playersScroll.BackgroundTransparency = 1
    playersScroll.ScrollBarThickness = 4
    playersScroll.ScrollBarImageColor3 = colors.primary
    playersScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    playersScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    playersScroll.Parent = leftFrame
    
    local playersLayout = Instance.new("UIListLayout")
    playersLayout.SortOrder = Enum.SortOrder.LayoutOrder
    playersLayout.Padding = UDim.new(0, 8)
    playersLayout.Parent = playersScroll
    
    -- Right Side - Items Configuration
    local rightFrame = Instance.new("Frame")
    rightFrame.Name = "RightFrame"
    rightFrame.Size = UDim2.new(0.7, -8, 1, 0)
    rightFrame.Position = UDim2.new(0.3, 8, 0, 0)
    rightFrame.BackgroundColor3 = colors.surface
    rightFrame.BorderSizePixel = 0
    rightFrame.Parent = contentFrame
    
    local rightCorner = Instance.new("UICorner")
    rightCorner.CornerRadius = UDim.new(0, 8)
    rightCorner.Parent = rightFrame
    
    -- Item Type Tabs
    local tabFrame = Instance.new("Frame")
    tabFrame.Name = "TabFrame"
    tabFrame.Size = UDim2.new(1, -16, 0, 35)
    tabFrame.Position = UDim2.new(0, 8, 0, 8)
    tabFrame.BackgroundTransparency = 1
    tabFrame.Parent = rightFrame
    
    local eggsTab = Instance.new("TextButton")
    eggsTab.Name = "EggsTab"
    eggsTab.Size = UDim2.new(0.33, -4, 1, 0)
    eggsTab.Position = UDim2.new(0, 0, 0, 0)
    eggsTab.BackgroundColor3 = colors.primary
    eggsTab.BorderSizePixel = 0
    eggsTab.Text = "🥚 Eggs"
    eggsTab.TextSize = 12
    eggsTab.Font = Enum.Font.GothamSemibold
    eggsTab.TextColor3 = colors.text
    eggsTab.Parent = tabFrame
    
    local eggsCorner = Instance.new("UICorner")
    eggsCorner.CornerRadius = UDim.new(0, 6)
    eggsCorner.Parent = eggsTab
    
    local fruitsTab = Instance.new("TextButton")
    fruitsTab.Name = "FruitsTab"
    fruitsTab.Size = UDim2.new(0.33, -4, 1, 0)
    fruitsTab.Position = UDim2.new(0.33, 2, 0, 0)
    fruitsTab.BackgroundColor3 = colors.textTertiary
    fruitsTab.BorderSizePixel = 0
    fruitsTab.Text = "🍎 Fruits"
    fruitsTab.TextSize = 12
    fruitsTab.Font = Enum.Font.GothamSemibold
    fruitsTab.TextColor3 = colors.text
    fruitsTab.Parent = tabFrame
    
    local fruitsCorner = Instance.new("UICorner")
    fruitsCorner.CornerRadius = UDim.new(0, 6)
    fruitsCorner.Parent = fruitsTab
    
    local petsTab = Instance.new("TextButton")
    petsTab.Name = "PetsTab"
    petsTab.Size = UDim2.new(0.33, -4, 1, 0)
    petsTab.Position = UDim2.new(0.66, 4, 0, 0)
    petsTab.BackgroundColor3 = colors.textTertiary
    petsTab.BorderSizePixel = 0
    petsTab.Text = "🐾 Pets"
    petsTab.TextSize = 12
    petsTab.Font = Enum.Font.GothamSemibold
    petsTab.TextColor3 = colors.text
    petsTab.Parent = tabFrame
    
    local petsCorner = Instance.new("UICorner")
    petsCorner.CornerRadius = UDim.new(0, 6)
    petsCorner.Parent = petsTab
    
    -- Items Scroll Frame
    local itemsScroll = Instance.new("ScrollingFrame")
    itemsScroll.Name = "ItemsScroll"
    itemsScroll.Size = UDim2.new(1, -16, 1, -55)
    itemsScroll.Position = UDim2.new(0, 8, 0, 47)
    itemsScroll.BackgroundTransparency = 1
    itemsScroll.ScrollBarThickness = 4
    itemsScroll.ScrollBarImageColor3 = colors.primary
    itemsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    itemsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    itemsScroll.Parent = rightFrame
    
    local itemsLayout = Instance.new("UIListLayout")
    itemsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    itemsLayout.Padding = UDim.new(0, 8)
    itemsLayout.Parent = itemsScroll
    
    -- Store references in a separate table to avoid conflicts
    local UIRefs = {
        ToggleBtn = toggleBtn,
        RefreshBtn = refreshBtn,
        PlayersScroll = playersScroll,
        ItemsScroll = itemsScroll,
        EggsTab = eggsTab,
        FruitsTab = fruitsTab,
        PetsTab = petsTab,
        CurrentTab = "eggs"
    }
    
    -- Store reference for access in other functions
    MainFrame.UIRefs = UIRefs
    
    -- Event Handlers with safety checks
    local closeBtn = windowControls and windowControls:FindFirstChild("CloseBtn")
    local minimizeBtn = windowControls and windowControls:FindFirstChild("MinimizeBtn")
    local maximizeBtn = windowControls and windowControls:FindFirstChild("MaximizeBtn")
    
    if closeBtn then
        closeBtn.MouseButton1Click:Connect(function()
            AutoTradeUI.Hide()
        end)
    end
    
    if minimizeBtn then
        minimizeBtn.MouseButton1Click:Connect(function()
            if isMinimized then
                MainFrame.Size = originalSize
                contentFrame.Visible = true
                toggleFrame.Visible = true
                isMinimized = false
            else
                MainFrame.Size = minimizedSize
                contentFrame.Visible = false
                toggleFrame.Visible = false
                isMinimized = true
            end
        end)
    end
    
    if maximizeBtn then
        maximizeBtn.MouseButton1Click:Connect(function()
            local screenSize = getScreenSize()
            if MainFrame.Size == originalSize then
                local maxSize = getResponsiveSize(screenSize.X * 0.9, screenSize.Y * 0.9)
                MainFrame.Size = maxSize
                MainFrame.Position = UDim2.new(0.5, -maxSize.X.Offset/2, 0.5, -maxSize.Y.Offset/2)
            else
                MainFrame.Size = originalSize
                MainFrame.Position = UDim2.new(0.5, -originalSize.X.Offset/2, 0.5, -originalSize.Y.Offset/2)
            end
        end)
    end
    
    toggleBtn.MouseButton1Click:Connect(function()
        autoTradeEnabled = not autoTradeEnabled
        toggleBtn.BackgroundColor3 = autoTradeEnabled and colors.success or colors.textTertiary
        toggleBtn.Text = autoTradeEnabled and "ON" or "OFF"
        
        if autoTradeEnabled then
            AutoTradeUI.StartAutoTrade()
        else
            AutoTradeUI.StopAutoTrade()
        end
    end)
    
    refreshBtn.MouseButton1Click:Connect(function()
        AutoTradeUI.RefreshTargets()
    end)
    
    -- Tab switching
    eggsTab.MouseButton1Click:Connect(function()
        UIRefs.CurrentTab = "eggs"
        eggsTab.BackgroundColor3 = colors.primary
        fruitsTab.BackgroundColor3 = colors.textTertiary
        petsTab.BackgroundColor3 = colors.textTertiary
        AutoTradeUI.RefreshItems()
    end)
    
    fruitsTab.MouseButton1Click:Connect(function()
        UIRefs.CurrentTab = "fruits"
        eggsTab.BackgroundColor3 = colors.textTertiary
        fruitsTab.BackgroundColor3 = colors.primary
        petsTab.BackgroundColor3 = colors.textTertiary
        AutoTradeUI.RefreshItems()
    end)
    
    petsTab.MouseButton1Click:Connect(function()
        UIRefs.CurrentTab = "pets"
        eggsTab.BackgroundColor3 = colors.textTertiary
        fruitsTab.BackgroundColor3 = colors.textTertiary
        petsTab.BackgroundColor3 = colors.primary
        AutoTradeUI.RefreshItems()
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
    
    return ScreenGui
end

-- Refresh Functions
function AutoTradeUI.RefreshTargets()
    if not ScreenGui or not MainFrame or not MainFrame.UIRefs then return end
    
    local playersScroll = MainFrame.UIRefs.PlayersScroll
    
    -- Clear existing players
    for _, child in pairs(playersScroll:GetChildren()) do
        if child:IsA("Frame") and child.Name:find("PlayerCard_") then
            child:Destroy()
        end
    end
    
    -- Add current players
    local players = getPlayerList()
    for i, player in ipairs(players) do
        local card = createTargetPlayerCard(player, playersScroll)
        card.LayoutOrder = i
    end
end

function AutoTradeUI.RefreshItems()
    if not ScreenGui or not MainFrame or not MainFrame.UIRefs then return end
    
    local itemsScroll = MainFrame.UIRefs.ItemsScroll
    local currentTab = MainFrame.UIRefs.CurrentTab or "eggs"
    
    -- Clear existing items
    for _, child in pairs(itemsScroll:GetChildren()) do
        if child:IsA("Frame") and not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    
    -- Add items based on current tab
    local data = nil
    local itemType = ""
    
    if currentTab == "eggs" then
        data = EggData
        itemType = "egg"
    elseif currentTab == "fruits" then
        data = FruitData
        itemType = "fruit"
    elseif currentTab == "pets" then
        -- Basic pet data structure
        data = {
            Capy1 = { Name = "Capy1", Icon = "🐹", Rarity = 1 },
            Pig = { Name = "Pig", Icon = "🐷", Rarity = 1 },
            Dog = { Name = "Dog", Icon = "🐕", Rarity = 1 },
            Cat = { Name = "Cat", Icon = "🐱", Rarity = 1 },
            Cow = { Name = "Cow", Icon = "🐄", Rarity = 2 },
            Sheep = { Name = "Sheep", Icon = "🐑", Rarity = 2 },
            Horse = { Name = "Horse", Icon = "🐴", Rarity = 2 },
            Tiger = { Name = "Tiger", Icon = "🐅", Rarity = 3 },
            Lion = { Name = "Lion", Icon = "🦁", Rarity = 3 },
            Bear = { Name = "Bear", Icon = "🐻", Rarity = 3 },
            Dragon = { Name = "Dragon", Icon = "🐉", Rarity = 6 },
            Phoenix = { Name = "Phoenix", Icon = "🔥", Rarity = 6 },
            Unicorn = { Name = "Unicorn", Icon = "🦄", Rarity = 6 }
        }
        itemType = "pet"
    end
    
    if data then
        local i = 1
        for itemId, itemData in pairs(data) do
            local card = createItemCard(itemId, itemData, itemType, itemsScroll)
            card.LayoutOrder = i
            i = i + 1
        end
    end
end

-- Auto Trade Logic
local autoTradeConnection = nil

function AutoTradeUI.StartAutoTrade()
    if autoTradeConnection then
        autoTradeConnection:Disconnect()
    end
    
    autoTradeConnection = RunService.Heartbeat:Connect(function()
        if not autoTradeEnabled or not selectedTarget then
            return
        end
        
        -- Check all configured items
        for itemType, items in pairs(tradeSettings) do
            for itemId, threshold in pairs(items) do
                if threshold > 0 then
                    local inventory = nil
                    local actualItemType = itemType:sub(1, -2) -- Remove 's' from end
                    
                    if actualItemType == "egg" then
                        inventory = getPlayerEggInventory()
                    elseif actualItemType == "fruit" then
                        inventory = getPlayerFruitInventory()
                    elseif actualItemType == "pet" then
                        inventory = getPlayerPetInventory()
                    end
                    
                    if inventory then
                        local itemData = nil
                        if actualItemType == "egg" then
                            itemData = EggData[itemId]
                        elseif actualItemType == "fruit" then
                            itemData = FruitData[itemId]
                        end
                        
                        if itemData then
                            local currentAmount = inventory[itemData.Name] or inventory[itemId] or 0
                            
                            if currentAmount >= threshold then
                                -- Send the item
                                task.spawn(function()
                                    local success, message = sendItem(itemData.Name, actualItemType, selectedTarget)
                                    if success then
                                        print("✅ Sent " .. itemData.Name .. " to " .. selectedTarget.Name)
                                    else
                                        print("❌ Failed to send " .. itemData.Name .. ": " .. message)
                                    end
                                end)
                                
                                -- Small delay to prevent spam
                                task.wait(1)
                            end
                        end
                    end
                end
            end
        end
        
        -- Check every 2 seconds
        task.wait(2)
    end)
end

function AutoTradeUI.StopAutoTrade()
    if autoTradeConnection then
        autoTradeConnection:Disconnect()
        autoTradeConnection = nil
    end
end

function AutoTradeUI.StartSending()
    if not selectedTarget then
        return
    end
    
    -- Send all configured items once
    task.spawn(function()
        for itemType, items in pairs(tradeSettings) do
            for itemId, threshold in pairs(items) do
                if threshold > 0 then
                    local inventory = nil
                    local actualItemType = itemType:sub(1, -2) -- Remove 's' from end
                    
                    if actualItemType == "egg" then
                        inventory = getPlayerEggInventory()
                    elseif actualItemType == "fruit" then
                        inventory = getPlayerFruitInventory()
                    elseif actualItemType == "pet" then
                        inventory = getPlayerPetInventory()
                    end
                    
                    if inventory then
                        local itemData = nil
                        if actualItemType == "egg" then
                            itemData = EggData[itemId]
                        elseif actualItemType == "fruit" then
                            itemData = FruitData[itemId]
                        end
                        
                        if itemData then
                            local currentAmount = inventory[itemData.Name] or inventory[itemId] or 0
                            
                            if currentAmount >= threshold then
                                local success, message = sendItem(itemData.Name, actualItemType, selectedTarget)
                                if success then
                                    print("✅ Sent " .. itemData.Name .. " to " .. selectedTarget.Name)
                                else
                                    print("❌ Failed to send " .. itemData.Name .. ": " .. message)
                                end
                                
                                task.wait(1) -- Delay between sends
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- Settings Management
function AutoTradeUI.SaveSettings()
    -- Save to file system if available
    local settingsData = {
        tradeSettings = tradeSettings,
        selectedTarget = selectedTarget and selectedTarget.Name or nil,
        autoTradeEnabled = autoTradeEnabled
    }
    
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(settingsData)
    end)
    
    if success and _G.writefile then
        pcall(function()
            if not _G.isfolder("Zebux") then
                _G.makefolder("Zebux")
            end
            if not _G.isfolder("Zebux/Build A Zoo") then
                _G.makefolder("Zebux/Build A Zoo")
            end
            _G.writefile("Zebux/Build A Zoo/AutoTradeSettings.json", encoded)
        end)
    end
end

function AutoTradeUI.LoadSettings()
    if _G.readfile and _G.isfile and _G.isfile("Zebux/Build A Zoo/AutoTradeSettings.json") then
        local success, data = pcall(function()
            return _G.readfile("Zebux/Build A Zoo/AutoTradeSettings.json")
        end)
        
        if success then
            local success2, decoded = pcall(function()
                return HttpService:JSONDecode(data)
            end)
            
            if success2 and type(decoded) == "table" then
                tradeSettings = decoded.tradeSettings or tradeSettings
                autoTradeEnabled = decoded.autoTradeEnabled or false
                
                if decoded.selectedTarget then
                    -- Find player by name
                    for _, player in ipairs(getPlayerList()) do
                        if player.Name == decoded.selectedTarget then
                            selectedTarget = player
                            break
                        end
                    end
                end
            end
        end
    end
end

-- Public Functions
function AutoTradeUI.Show()
    print("AutoTradeUI.Show() called")
    
    local success, error = pcall(function()
        AutoTradeUI.LoadSettings()
        
        if not ScreenGui then
            print("Creating new UI...")
            AutoTradeUI.CreateUI()
        end
        
        if ScreenGui then
            ScreenGui.Enabled = true
            print("UI enabled")
            
            -- Initial refresh with delay
            task.spawn(function()
                task.wait(0.2)
                print("Refreshing targets and items...")
                pcall(AutoTradeUI.RefreshTargets)
                pcall(AutoTradeUI.RefreshItems)
            end)
        else
            print("ERROR: ScreenGui is nil after CreateUI")
        end
    end)
    
    if not success then
        print("ERROR in AutoTradeUI.Show():", error)
        -- Try to create a simple notification if possible
        if game:GetService("StarterGui") then
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "AutoTradeUI Error",
                Text = tostring(error),
                Duration = 5
            })
        end
    end
end

function AutoTradeUI.Hide()
    AutoTradeUI.SaveSettings()
    AutoTradeUI.StopAutoTrade()
    
    if ScreenGui then
        ScreenGui:Destroy()
        ScreenGui = nil
        MainFrame = nil
    end
end

function AutoTradeUI.IsVisible()
    return ScreenGui and ScreenGui.Enabled
end

return AutoTradeUI
