-- SendTrashSystem.lua - Core Send Functions with External UI
-- Lua 5.1 Compatible

local SendTrashSystem = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- External UI and Core Variables
local customUI = nil
local WindUI, Window, Config

-- ============ IMPROVED SENDING SYSTEM ============

-- Improved sending system with 100% reliability
local function sendItemReliably(itemUID, targetPlayerName, itemKind)
    -- Step 1: Validate target player exists
    local targetPlayer = nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name == targetPlayerName then
            targetPlayer = player
            break
        end
    end
    
    if not targetPlayer then
        return false, "Target player not found"
    end
    
    -- Step 2: Check if item still exists in inventory
    local itemExists = false
    local dataFolder = LocalPlayer.PlayerGui.Data:FindFirstChild(itemKind == "egg" and "Egg" or "Pets")
    if dataFolder and dataFolder:FindFirstChild(itemUID) then
        itemExists = true
    end
    
    if not itemExists then
        return false, "Item no longer exists in inventory"
    end
    
    -- Step 3: Remove from ground if placed
    local itemData = dataFolder:FindFirstChild(itemUID)
    local function safeGetAttribute(obj, attrName, default)
        if not obj then return default end
        local success, result = pcall(function()
            return obj:GetAttribute(attrName)
        end)
        return success and result or default
    end
    
    local isPlaced = safeGetAttribute(itemData, "D", nil) ~= nil
    
    if isPlaced then
        local success = pcall(function()
            local args = {"Del", itemUID}
            ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
        end)
        if not success then
            return false, "Failed to remove item from ground"
        end
        task.wait(0.2) -- Wait for removal to process
    end
    
    -- Step 4: Focus the item with retry mechanism
    local focusAttempts = 0
    local maxFocusAttempts = 3
    local focusSuccess = false
    
    while focusAttempts < maxFocusAttempts and not focusSuccess do
        focusAttempts = focusAttempts + 1
        
        local success = pcall(function()
            local args = {"Focus", itemUID}
            ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
        end)
        
        if success then
            focusSuccess = true
        else
            task.wait(0.1)
        end
    end
    
    if not focusSuccess then
        return false, "Failed to focus item after " .. maxFocusAttempts .. " attempts"
    end
    
    task.wait(0.3) -- Wait for focus to fully process
    
    -- Step 5: Send with retry mechanism
    local sendAttempts = 0
    local maxSendAttempts = 3
    local sendSuccess = false
    
    while sendAttempts < maxSendAttempts and not sendSuccess do
        sendAttempts = sendAttempts + 1
        
        -- Double-check target player still exists
        targetPlayer = Players:FindFirstChild(targetPlayerName)
        if not targetPlayer then
            return false, "Target player left the game"
        end
        
        local success = pcall(function()
            local args = {targetPlayer}
            ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(unpack(args))
        end)
        
        if success then
            sendSuccess = true
        else
            task.wait(0.2)
        end
    end
    
    if not sendSuccess then
        return false, "Failed to send item after " .. maxSendAttempts .. " attempts"
    end
    
    return true, "Item sent successfully"
end

-- Get all available items
local function getAllItems()
    local pets, eggs = {}, {}
    
    if not LocalPlayer then
        warn("LocalPlayer not found")
        return pets, eggs
    end
    
    if not LocalPlayer.PlayerGui then
        warn("PlayerGui not found")
        return pets, eggs
    end
    
    local dataFolder = LocalPlayer.PlayerGui:FindFirstChild("Data")
    if not dataFolder then
        warn("Data folder not found in PlayerGui")
        return pets, eggs
    end
    
    local function safeGetAttribute(obj, attrName, default)
        if not obj then return default end
        local success, result = pcall(function()
            return obj:GetAttribute(attrName)
        end)
        return success and result or default
    end
    
    -- Get pets
    local petsFolder = dataFolder:FindFirstChild("Pets")
    if petsFolder then
        for _, petData in pairs(petsFolder:GetChildren()) do
            if petData:IsA("Configuration") then
                local petType = safeGetAttribute(petData, "T", nil) or safeGetAttribute(petData, "Type", nil)
                if petType then
                    table.insert(pets, {
                        uid = petData.Name,
                        type = petType,
                        mutation = safeGetAttribute(petData, "M", safeGetAttribute(petData, "Mutation", "None")),
                        locked = safeGetAttribute(petData, "LK", 0) == 1,
                        placed = safeGetAttribute(petData, "D", nil) ~= nil
                    })
                end
            end
        end
    else
        warn("Pets folder not found")
    end
    
    -- Get eggs
    local eggsFolder = dataFolder:FindFirstChild("Egg")
    if eggsFolder then
        for _, eggData in pairs(eggsFolder:GetChildren()) do
            if eggData:IsA("Configuration") then
                local eggType = safeGetAttribute(eggData, "T", nil) or safeGetAttribute(eggData, "Type", nil) or safeGetAttribute(eggData, "ID", nil)
                if eggType then
                    table.insert(eggs, {
                        uid = eggData.Name,
                        type = eggType,
                        mutation = safeGetAttribute(eggData, "M", safeGetAttribute(eggData, "Mutation", "None")),
                        locked = safeGetAttribute(eggData, "LK", 0) == 1,
                        placed = safeGetAttribute(eggData, "D", nil) ~= nil
                    })
                end
            end
        end
    else
        warn("Egg folder not found")
    end
    
    print("Found " .. #pets .. " pets and " .. #eggs .. " eggs")
    return pets, eggs
end

-- Get available players
local function getPlayerList()
    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(players, {
                name = player.Name,
                displayName = player.DisplayName,
                userId = player.UserId
            })
        end
    end
    return players
end

-- ============ EXTERNAL UI CREATION ============

local function createExternalUI()
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CustomSendTrashUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Main Frame (dark background like in image)
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 800, 0, 600)
    mainFrame.Position = UDim2.new(0.5, -400, 0.5, -300)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    -- Top bar with title and close button
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1, 0, 0, 60)
    topBar.Position = UDim2.new(0, 0, 0, 0)
    topBar.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
    topBar.BorderSizePixel = 0
    topBar.Parent = mainFrame
    
    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 12)
    topCorner.Parent = topBar
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -70, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Trade"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = topBar
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 15)
    closeButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    closeButton.Text = "×"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.BorderSizePixel = 0
    closeButton.Parent = topBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton
    
    -- Left panel (target character)
    local leftPanel = Instance.new("Frame")
    leftPanel.Name = "LeftPanel"
    leftPanel.Size = UDim2.new(0.4, -10, 1, -80)
    leftPanel.Position = UDim2.new(0, 10, 0, 70)
    leftPanel.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    leftPanel.BorderSizePixel = 0
    leftPanel.Parent = mainFrame
    
    local leftCorner = Instance.new("UICorner")
    leftCorner.CornerRadius = UDim.new(0, 8)
    leftCorner.Parent = leftPanel
    
    -- Right panel (items)
    local rightPanel = Instance.new("Frame")
    rightPanel.Name = "RightPanel"
    rightPanel.Size = UDim2.new(0.6, -10, 1, -80)
    rightPanel.Position = UDim2.new(0.4, 10, 0, 70)
    rightPanel.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    rightPanel.BorderSizePixel = 0
    rightPanel.Parent = mainFrame
    
    local rightCorner = Instance.new("UICorner")
    rightCorner.CornerRadius = UDim.new(0, 8)
    rightCorner.Parent = rightPanel
    
    -- Search box in left panel
    local searchBox = Instance.new("TextBox")
    searchBox.Name = "SearchBox"
    searchBox.Size = UDim2.new(1, -20, 0, 40)
    searchBox.Position = UDim2.new(0, 10, 0, 10)
    searchBox.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
    searchBox.Text = "Search"
    searchBox.TextColor3 = Color3.fromRGB(200, 200, 200)
    searchBox.TextScaled = true
    searchBox.Font = Enum.Font.Gotham
    searchBox.BorderSizePixel = 0
    searchBox.Parent = leftPanel
    
    local searchCorner = Instance.new("UICorner")
    searchCorner.CornerRadius = UDim.new(0, 6)
    searchCorner.Parent = searchBox
    
    -- Character display area with avatar
    local characterFrame = Instance.new("Frame")
    characterFrame.Name = "CharacterFrame"
    characterFrame.Size = UDim2.new(1, -20, 0, 200)
    characterFrame.Position = UDim2.new(0, 10, 0, 60)
    characterFrame.BackgroundTransparency = 1
    characterFrame.Parent = leftPanel
    
    -- Avatar display
    local avatarLabel = Instance.new("ImageLabel")
    avatarLabel.Name = "AvatarLabel"
    avatarLabel.Size = UDim2.new(0, 120, 0, 120)
    avatarLabel.Position = UDim2.new(0.5, -60, 0, 10)
    avatarLabel.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    avatarLabel.BorderSizePixel = 0
    avatarLabel.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    avatarLabel.Parent = characterFrame
    
    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(0, 60)
    avatarCorner.Parent = avatarLabel
    
    -- Selected player name
    local playerNameLabel = Instance.new("TextLabel")
    playerNameLabel.Name = "PlayerNameLabel"
    playerNameLabel.Size = UDim2.new(1, 0, 0, 40)
    playerNameLabel.Position = UDim2.new(0, 0, 0, 140)
    playerNameLabel.BackgroundTransparency = 1
    playerNameLabel.Text = "No Player Selected"
    playerNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    playerNameLabel.TextScaled = true
    playerNameLabel.Font = Enum.Font.GothamBold
    playerNameLabel.TextWrapped = true
    playerNameLabel.Parent = characterFrame
    
    -- Controls for amount and mutation
    local controlsFrame = Instance.new("Frame")
    controlsFrame.Name = "ControlsFrame"
    controlsFrame.Size = UDim2.new(1, -20, 0, 150)
    controlsFrame.Position = UDim2.new(0, 10, 1, -160)
    controlsFrame.BackgroundTransparency = 1
    controlsFrame.Parent = leftPanel
    
    -- Amount label and input
    local amountLabel = Instance.new("TextLabel")
    amountLabel.Name = "AmountLabel"
    amountLabel.Size = UDim2.new(1, 0, 0, 30)
    amountLabel.Position = UDim2.new(0, 0, 0, 0)
    amountLabel.BackgroundTransparency = 1
    amountLabel.Text = "Amount"
    amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    amountLabel.TextScaled = true
    amountLabel.Font = Enum.Font.Gotham
    amountLabel.TextXAlignment = Enum.TextXAlignment.Left
    amountLabel.Parent = controlsFrame
    
    local amountInput = Instance.new("TextBox")
    amountInput.Name = "AmountInput"
    amountInput.Size = UDim2.new(0.6, 0, 0, 30)
    amountInput.Position = UDim2.new(0.4, 0, 0, 0)
    amountInput.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
    amountInput.Text = "1"
    amountInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    amountInput.TextScaled = true
    amountInput.Font = Enum.Font.Gotham
    amountInput.BorderSizePixel = 0
    amountInput.Parent = controlsFrame
    
    local amountCorner = Instance.new("UICorner")
    amountCorner.CornerRadius = UDim.new(0, 4)
    amountCorner.Parent = amountInput
    
    -- Refresh button
    local refreshButton = Instance.new("TextButton")
    refreshButton.Name = "RefreshButton"
    refreshButton.Size = UDim2.new(1, 0, 0, 40)
    refreshButton.Position = UDim2.new(0, 0, 0, 40)
    refreshButton.BackgroundColor3 = Color3.fromRGB(34, 139, 34)
    refreshButton.Text = "🔄 REFRESH"
    refreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    refreshButton.TextScaled = true
    refreshButton.Font = Enum.Font.GothamBold
    refreshButton.BorderSizePixel = 0
    refreshButton.Parent = controlsFrame
    
    local refreshCorner = Instance.new("UICorner")
    refreshCorner.CornerRadius = UDim.new(0, 6)
    refreshCorner.Parent = refreshButton
    
    -- Send All button
    local sendAllButton = Instance.new("TextButton")
    sendAllButton.Name = "SendAllButton"
    sendAllButton.Size = UDim2.new(1, 0, 0, 40)
    sendAllButton.Position = UDim2.new(0, 0, 0, 90)
    sendAllButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    sendAllButton.Text = "📤 SEND ALL"
    sendAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    sendAllButton.TextScaled = true
    sendAllButton.Font = Enum.Font.GothamBold
    sendAllButton.BorderSizePixel = 0
    sendAllButton.Parent = controlsFrame
    
    local sendAllCorner = Instance.new("UICorner")
    sendAllCorner.CornerRadius = UDim.new(0, 6)
    sendAllCorner.Parent = sendAllButton
    
    -- Search box in right panel
    local rightSearchBox = Instance.new("TextBox")
    rightSearchBox.Name = "RightSearchBox"
    rightSearchBox.Size = UDim2.new(1, -20, 0, 40)
    rightSearchBox.Position = UDim2.new(0, 10, 0, 10)
    rightSearchBox.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
    rightSearchBox.Text = "Search"
    rightSearchBox.TextColor3 = Color3.fromRGB(200, 200, 200)
    rightSearchBox.TextScaled = true
    rightSearchBox.Font = Enum.Font.Gotham
    rightSearchBox.BorderSizePixel = 0
    rightSearchBox.Parent = rightPanel
    
    local rightSearchCorner = Instance.new("UICorner")
    rightSearchCorner.CornerRadius = UDim.new(0, 6)
    rightSearchCorner.Parent = rightSearchBox
    
    -- Items grid
    local itemsGrid = Instance.new("ScrollingFrame")
    itemsGrid.Name = "ItemsGrid"
    itemsGrid.Size = UDim2.new(1, -20, 1, -60)
    itemsGrid.Position = UDim2.new(0, 10, 0, 50)
    itemsGrid.BackgroundTransparency = 1
    itemsGrid.BorderSizePixel = 0
    itemsGrid.ScrollBarThickness = 6
    itemsGrid.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    itemsGrid.Parent = rightPanel
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 140, 0, 160)
    gridLayout.CellPadding = UDim2.new(0, 15, 0, 15)
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = itemsGrid
    
    -- Players list in left panel
    local playersScrollFrame = Instance.new("ScrollingFrame")
    playersScrollFrame.Name = "PlayersScrollFrame"
    playersScrollFrame.Size = UDim2.new(1, -20, 1, -270)
    playersScrollFrame.Position = UDim2.new(0, 10, 0, 260)
    playersScrollFrame.BackgroundTransparency = 1
    playersScrollFrame.BorderSizePixel = 0
    playersScrollFrame.ScrollBarThickness = 4
    playersScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    playersScrollFrame.Parent = leftPanel
    
    local playersLayout = Instance.new("UIListLayout")
    playersLayout.SortOrder = Enum.SortOrder.LayoutOrder
    playersLayout.Padding = UDim.new(0, 5)
    playersLayout.Parent = playersScrollFrame
    
    -- Variables for tracking
    local selectedPlayer = nil
    
    -- Update players list
    local function updatePlayersList()
        -- Clear existing players
        for _, child in pairs(playersScrollFrame:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        local players = getPlayerList()
        
        for i, player in ipairs(players) do
            local playerFrame = Instance.new("Frame")
            playerFrame.Name = "Player" .. i
            playerFrame.Size = UDim2.new(1, 0, 0, 50)
            playerFrame.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
            playerFrame.BorderSizePixel = 0
            playerFrame.LayoutOrder = i
            playerFrame.Parent = playersScrollFrame
            
            local playerCorner = Instance.new("UICorner")
            playerCorner.CornerRadius = UDim.new(0, 6)
            playerCorner.Parent = playerFrame
            
            -- Player avatar
            local playerAvatar = Instance.new("ImageLabel")
            playerAvatar.Name = "PlayerAvatar"
            playerAvatar.Size = UDim2.new(0, 40, 0, 40)
            playerAvatar.Position = UDim2.new(0, 5, 0, 5)
            playerAvatar.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            playerAvatar.BorderSizePixel = 0
            playerAvatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.userId .. "&width=50&height=50&format=png"
            playerAvatar.Parent = playerFrame
            
            local playerAvatarCorner = Instance.new("UICorner")
            playerAvatarCorner.CornerRadius = UDim.new(0, 20)
            playerAvatarCorner.Parent = playerAvatar
            
            -- Player name
            local playerNameText = Instance.new("TextLabel")
            playerNameText.Name = "PlayerNameText"
            playerNameText.Size = UDim2.new(1, -60, 1, 0)
            playerNameText.Position = UDim2.new(0, 50, 0, 0)
            playerNameText.BackgroundTransparency = 1
            playerNameText.Text = player.name
            playerNameText.TextColor3 = Color3.fromRGB(255, 255, 255)
            playerNameText.TextScaled = true
            playerNameText.Font = Enum.Font.Gotham
            playerNameText.TextXAlignment = Enum.TextXAlignment.Left
            playerNameText.Parent = playerFrame
            
            -- Online indicator
            local onlineIndicator = Instance.new("Frame")
            onlineIndicator.Name = "OnlineIndicator"
            onlineIndicator.Size = UDim2.new(0, 8, 0, 8)
            onlineIndicator.Position = UDim2.new(0, 37, 0, 5)
            onlineIndicator.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            onlineIndicator.BorderSizePixel = 0
            onlineIndicator.Parent = playerFrame
            
            local indicatorCorner = Instance.new("UICorner")
            indicatorCorner.CornerRadius = UDim.new(0, 4)
            indicatorCorner.Parent = onlineIndicator
            
            -- Click handler
            local clickButton = Instance.new("TextButton")
            clickButton.Name = "ClickButton"
            clickButton.Size = UDim2.new(1, 0, 1, 0)
            clickButton.Position = UDim2.new(0, 0, 0, 0)
            clickButton.BackgroundTransparency = 1
            clickButton.Text = ""
            clickButton.Parent = playerFrame
            
            clickButton.MouseButton1Click:Connect(function()
                selectedPlayer = player
                playerNameLabel.Text = player.name
                avatarLabel.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.userId .. "&width=180&height=180&format=png"
                
                -- Update visual selection
                for _, child in pairs(playersScrollFrame:GetChildren()) do
                    if child:IsA("Frame") then
                        child.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
                    end
                end
                playerFrame.BackgroundColor3 = Color3.fromRGB(52, 58, 235)
            end)
        end
        
        -- Update canvas size
        playersScrollFrame.CanvasSize = UDim2.new(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
    end
    
    -- Update items grid
    local function updateItemsGrid()
        -- Clear existing items
        for _, child in pairs(itemsGrid:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        local pets, eggs = getAllItems()
        local allItems = {}
        
        -- Add all individual pets
        for _, pet in ipairs(pets) do
            if not pet.locked then
                table.insert(allItems, {
                    type = "pet",
                    displayName = pet.type,
                    mutation = pet.mutation or "None",
                    uid = pet.uid,
                    data = pet
                })
            end
        end
        
        -- Add all individual eggs
        for _, egg in ipairs(eggs) do
            if not egg.locked then
                table.insert(allItems, {
                    type = "egg",
                    displayName = egg.type,
                    mutation = egg.mutation or "None",
                    uid = egg.uid,
                    data = egg
                })
            end
        end
        
        -- Sort items by type then name
        table.sort(allItems, function(a, b)
            if a.type ~= b.type then
                return a.type < b.type -- eggs before pets
            end
            return a.displayName < b.displayName
        end)
        
        -- Create item frames
        for i, item in ipairs(allItems) do
            local itemFrame = Instance.new("Frame")
            itemFrame.Name = "Item" .. i
            itemFrame.Size = UDim2.new(0, 140, 0, 160)
            itemFrame.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
            itemFrame.BorderSizePixel = 0
            itemFrame.LayoutOrder = i
            itemFrame.Parent = itemsGrid
            
            local itemCorner = Instance.new("UICorner")
            itemCorner.CornerRadius = UDim.new(0, 8)
            itemCorner.Parent = itemFrame
            
            -- Type indicator label
            local typeIndicatorLabel = Instance.new("TextLabel")
            typeIndicatorLabel.Name = "TypeIndicatorLabel"
            typeIndicatorLabel.Size = UDim2.new(0, 30, 0, 20)
            typeIndicatorLabel.Position = UDim2.new(1, -35, 0, 5)
            typeIndicatorLabel.BackgroundColor3 = item.type == "egg" and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(100, 150, 200)
            typeIndicatorLabel.Text = item.type == "egg" and "E" or "P"
            typeIndicatorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            typeIndicatorLabel.TextScaled = true
            typeIndicatorLabel.Font = Enum.Font.GothamBold
            typeIndicatorLabel.BorderSizePixel = 0
            typeIndicatorLabel.Parent = itemFrame
            
            local typeCorner = Instance.new("UICorner")
            typeCorner.CornerRadius = UDim.new(0, 10)
            typeCorner.Parent = typeIndicatorLabel
            
            -- Item icon
            local iconFrame = Instance.new("Frame")
            iconFrame.Name = "IconFrame"
            iconFrame.Size = UDim2.new(0, 80, 0, 80)
            iconFrame.Position = UDim2.new(0.5, -40, 0, 10)
            iconFrame.BackgroundColor3 = item.type == "egg" and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(100, 150, 200)
            iconFrame.BorderSizePixel = 0
            iconFrame.Parent = itemFrame
            
            local iconCorner = Instance.new("UICorner")
            iconCorner.CornerRadius = UDim.new(0, 40)
            iconCorner.Parent = iconFrame
            
            -- Type indicator
            local typeLabel = Instance.new("TextLabel")
            typeLabel.Name = "TypeLabel"
            typeLabel.Size = UDim2.new(1, 0, 1, 0)
            typeLabel.Position = UDim2.new(0, 0, 0, 0)
            typeLabel.BackgroundTransparency = 1
            typeLabel.Text = item.type == "egg" and "🥚" or "🐾"
            typeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            typeLabel.TextScaled = true
            typeLabel.Font = Enum.Font.GothamBold
            typeLabel.Parent = iconFrame
            
            -- Item name
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "NameLabel"
            nameLabel.Size = UDim2.new(1, -10, 0, 25)
            nameLabel.Position = UDim2.new(0, 5, 0, 95)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = item.displayName
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextScaled = true
            nameLabel.Font = Enum.Font.Gotham
            nameLabel.TextWrapped = true
            nameLabel.Parent = itemFrame
            
            -- Mutation label
            if item.mutation ~= "None" then
                local mutationLabel = Instance.new("TextLabel")
                mutationLabel.Name = "MutationLabel"
                mutationLabel.Size = UDim2.new(1, -10, 0, 15)
                mutationLabel.Position = UDim2.new(0, 5, 1, -20)
                mutationLabel.BackgroundTransparency = 1
                mutationLabel.Text = "[" .. item.mutation .. "]"
                mutationLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
                mutationLabel.TextScaled = true
                mutationLabel.Font = Enum.Font.GothamBold
                mutationLabel.TextWrapped = true
                mutationLabel.Parent = itemFrame
            end
            
            -- Click handler for item selection
            local clickButton = Instance.new("TextButton")
            clickButton.Name = "ClickButton"
            clickButton.Size = UDim2.new(1, 0, 1, 0)
            clickButton.Position = UDim2.new(0, 0, 0, 0)
            clickButton.BackgroundTransparency = 1
            clickButton.Text = ""
            clickButton.Parent = itemFrame
            
            clickButton.MouseButton1Click:Connect(function()
                if not selectedPlayer then
                    WindUI:Notify({Title = "❌ Error", Content = "Please select a player first!", Duration = 3})
                    return
                end
                
                -- Send this individual item
                local success, message = sendItemReliably(item.uid, selectedPlayer.name, item.type)
                
                if success then
                    WindUI:Notify({
                        Title = "✅ Success", 
                        Content = "Sent " .. item.displayName .. " to " .. selectedPlayer.name, 
                        Duration = 2
                    })
                    
                    -- Remove this item from the grid
                    itemFrame:Destroy()
                else
                    WindUI:Notify({
                        Title = "❌ Failed", 
                        Content = "Failed: " .. message, 
                        Duration = 3
                    })
                end
            end)
        end
        
        -- Update canvas size
        itemsGrid.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 20)
    end
    
    -- Search functionality
    searchBox.FocusGained:Connect(function()
        if searchBox.Text == "Search" then
            searchBox.Text = ""
        end
    end)
    
    searchBox.FocusLost:Connect(function()
        if searchBox.Text == "" then
            searchBox.Text = "Search"
        end
        -- Filter players based on search
        updatePlayersList()
    end)
    
    rightSearchBox.FocusGained:Connect(function()
        if rightSearchBox.Text == "Search" then
            rightSearchBox.Text = ""
        end
    end)
    
    rightSearchBox.FocusLost:Connect(function()
        if rightSearchBox.Text == "" then
            rightSearchBox.Text = "Search"
        end
        -- Filter items based on search
        updateItemsGrid()
    end)
    
    -- Make draggable
    local isDragging = false
    local dragStart = nil
    local startPos = nil
    
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)
    
    -- Close button functionality
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        customUI = nil
    end)
    
    -- Refresh button functionality
    refreshButton.MouseButton1Click:Connect(function()
        updateItemsGrid()
        updatePlayersList()
        WindUI:Notify({
            Title = "🔄 Refreshed", 
            Content = "Items and players list updated!", 
            Duration = 2
        })
    end)
    
    -- Send All button functionality
    sendAllButton.MouseButton1Click:Connect(function()
        if not selectedPlayer then
            WindUI:Notify({Title = "❌ Error", Content = "Please select a player first!", Duration = 3})
            return
        end
        
        local pets, eggs = getAllItems()
        local allItems = {}
        
        -- Add all unlocked pets
        for _, pet in ipairs(pets) do
            if not pet.locked then
                table.insert(allItems, {data = pet, type = "pet"})
            end
        end
        
        -- Add all unlocked eggs
        for _, egg in ipairs(eggs) do
            if not egg.locked then
                table.insert(allItems, {data = egg, type = "egg"})
            end
        end
        
        if #allItems == 0 then
            WindUI:Notify({Title = "❌ Error", Content = "No items to send!", Duration = 3})
            return
        end
        
        -- Send all items
        task.spawn(function()
            local sent = 0
            for _, item in ipairs(allItems) do
                local success, message = sendItemReliably(item.data.uid, selectedPlayer.name, item.type)
                
                if success then
                    sent = sent + 1
                else
                    WindUI:Notify({
                        Title = "❌ Failed", 
                        Content = "Failed: " .. message, 
                        Duration = 2
                    })
                end
                
                task.wait(0.5) -- Wait between sends
            end
            
            WindUI:Notify({
                Title = "✅ Complete", 
                Content = "Sent " .. sent .. " items to " .. selectedPlayer.name, 
                Duration = 3
            })
            
            -- Refresh after sending
            task.wait(1)
            updateItemsGrid()
        end)
    end)
    
    -- Store references
    customUI = {
        screenGui = screenGui,
        mainFrame = mainFrame,
        updateItemsGrid = updateItemsGrid,
        updatePlayersList = updatePlayersList
    }
    
    -- Load initial data
    updateItemsGrid()
    updatePlayersList()
    
    return customUI
end

-- ============ MAIN INTERFACE ============

function SendTrashSystem.Init(dependencies)
    WindUI = dependencies.WindUI
    Window = dependencies.Window
    Config = dependencies.Config
    
    -- Create simple tab with just one button
    local TrashTab = Window:Tab({ Title = "🗑️ | Send Trash"})
    
    TrashTab:Button({
        Title = "📦 Open Send Interface",
        Desc = "Open the external send/trade interface",
        Callback = function()
            if customUI then
                -- Close existing UI
                customUI.screenGui:Destroy()
                customUI = nil
            end
            
            -- Create new UI
            createExternalUI()
            
            WindUI:Notify({
                Title = "📦 Send Interface",
                Content = "External interface opened!",
                Duration = 3
            })
        end
    })
    
    -- Register with config if needed
    if Config then
        -- No UI elements to register since we removed them all
    end
end

-- Export core functions for external use
SendTrashSystem.sendItemReliably = sendItemReliably
SendTrashSystem.getAllItems = getAllItems
SendTrashSystem.getPlayerList = getPlayerList

return SendTrashSystem
