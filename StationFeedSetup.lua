-- StationFeedSetup.lua - Station-First UI for Auto Feed (macOS Style)
-- Author: Zebux
-- Version: 3.0
-- Description: Two-panel UI - Left: Big Pet List, Right: Fruit Grid
-- Features: Auto-update fruit data from game, 3D model display, macOS style UI

local StationFeedSetup = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dynamic data that will be loaded from the game
local FruitData = {}

-- Cache for fruit models from ReplicatedStorage
local FruitModels = {}

-- Function to get fruit model from ReplicatedStorage
local function GetFruitModel(fruitId)
    -- Check cache first
    if FruitModels[fruitId] then
        return FruitModels[fruitId]
    end
    
    -- Try to find the model
    local success, model = pcall(function()
        -- Search in ReplicatedStorage children for PetFood folder
        for _, child in ipairs(ReplicatedStorage:GetChildren()) do
            if child:IsA("Folder") or child:IsA("Model") then
                -- Look for PetFood/FruitName pattern
                local fruitModel = child:FindFirstChild("PetFood/" .. fruitId)
                if fruitModel then
                    return fruitModel
                end
                
                -- Also try direct search
                local petFoodFolder = child:FindFirstChild("PetFood")
                if petFoodFolder then
                    fruitModel = petFoodFolder:FindFirstChild(fruitId)
                    if fruitModel then
                        return fruitModel
                    end
                end
            end
        end
        return nil
    end)
    
    if success and model then
        FruitModels[fruitId] = model
        return model
    end
    
    return nil
end

-- Function to load fruit data from the game automatically
local function LoadFruitDataFromGame()
    local success, result = pcall(function()
        local configModule = ReplicatedStorage:WaitForChild("Config", 10):WaitForChild("ResPetFood", 10)
        if configModule then
            local gameFruitData = require(configModule)
            
            -- Convert game data format to our UI format
            local convertedData = {}
            
            for fruitId, fruitInfo in pairs(gameFruitData) do
                -- Skip the __index table
                if fruitId ~= "__index" and type(fruitInfo) == "table" then
                    -- Get model from ReplicatedStorage
                    local fruitModel = GetFruitModel(fruitId)
                    
                    -- Convert to our format
                    convertedData[fruitId] = {
                        Name = fruitInfo.ID or fruitId,
                        Price = fruitInfo.Price or "0",
                        Icon = fruitInfo.Icon or "",
                        Model = fruitModel,
                        Rarity = fruitInfo.Rarity or 1,
                        FeedValue = fruitInfo.FeedValue or 0
                    }
                end
            end
            
            return convertedData
        end
    end)
    
    if success and result then
        return result
    else
        warn("[StationFeedSetup] Failed to load fruit data from game:", result)
        return {}
    end
end

-- Load fruit data on initialization
FruitData = LoadFruitDataFromGame()

-- Flag to indicate data is loaded
StationFeedSetup.DataLoaded = true

-- Helper to find BigPet station
local function findBigPetStationForPet(petPosition)
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return nil end
    
    local islandName = localPlayer:GetAttribute("AssignedIslandName")
    if not islandName then return nil end
    
    local art = workspace:FindFirstChild("Art")
    if not art then return nil end
    
    local island = art:FindFirstChild(islandName)
    if not island then return nil end
    
    local env = island:FindFirstChild("ENV")
    if not env then return nil end
    
    local bigPetFolder = env:FindFirstChild("BigPet")
    if not bigPetFolder then return nil end
    
    local closestStation = nil
    local closestDistance = math.huge
    
    for _, station in ipairs(bigPetFolder:GetChildren()) do
        if station:IsA("BasePart") then
            local distance = (station.Position - petPosition).Magnitude
            if distance < closestDistance and distance < 50 then
                closestDistance = distance
                closestStation = station.Name
            end
        end
    end
    
    return closestStation
end

-- Get player's owned Big Pets with Station IDs
local function getPlayerOwnedPets()
    local pets = {}
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return pets end
    
    local petsFolder = workspace:FindFirstChild("Pets")
    if not petsFolder then return pets end
    
    for _, petModel in ipairs(petsFolder:GetChildren()) do
        if petModel:IsA("Model") then
            local rootPart = petModel:FindFirstChild("RootPart")
            if rootPart then
                local petUserId = rootPart:GetAttribute("UserId")
                if petUserId and tostring(petUserId) == tostring(localPlayer.UserId) then
                    local bigPetGUI = rootPart:FindFirstChild("GUI/BigPetGUI")
                    if bigPetGUI then
                        local stationId = findBigPetStationForPet(rootPart.Position)
                        
                        -- Get pet type - try multiple attributes
                        local petType = rootPart:GetAttribute("T") 
                                     or rootPart:GetAttribute("Type")
                                     or rootPart:GetAttribute("PetType")
                        
                        -- If petType is still a UID-like string (long hex), don't show it
                        local displayName = "Station " .. stationId
                        if petType and #tostring(petType) <= 20 and petType ~= "" then
                            displayName = petType
                        end
                        
                        if stationId then
                            table.insert(pets, {
                                uid = petModel.Name,
                                stationId = stationId,
                                type = petType or "Unknown",
                                displayName = displayName
                            })
                        end
                    end
                end
            end
        end
    end
    
    -- Sort by station ID
    table.sort(pets, function(a, b)
        local numA = tonumber(a.stationId)
        local numB = tonumber(b.stationId)
        if numA and numB then
            return numA < numB
        end
        return a.stationId < b.stationId
    end)
    
    return pets
end

-- Get player's fruit inventory
local function getPlayerFruitInventory()
    local inventory = {}
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return inventory end
    
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return inventory end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return inventory end
    
    local asset = data:FindFirstChild("Asset")
    if not asset then return inventory end
    
    local ok, attrs = pcall(function() return asset:GetAttributes() end)
    if ok and type(attrs) == "table" then
        for fruitId, fruitData in pairs(FruitData) do
            local amount = attrs[fruitData.Name] or attrs[fruitId] or 0
            if type(amount) == "string" then amount = tonumber(amount) or 0 end
            if amount > 0 then
                inventory[fruitId] = amount
            end
        end
    end
    
    return inventory
end

-- Format large numbers
local function formatNumber(num)
    if type(num) == "string" then num = tonumber(num) or 0 end
    if num >= 1000000000000 then return string.format("%.1fT", num / 1000000000000)
    elseif num >= 1000000000 then return string.format("%.1fB", num / 1000000000)
    elseif num >= 1000000 then return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then return string.format("%.1fK", num / 1000)
    else return tostring(num) end
end

-- UI Variables
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ScreenGui = nil
local MainFrame = nil

-- NEW DATA STRUCTURE: {StationID: {FruitID: true}}
local stationFruitAssignments = {}
local savedTemplates = {} -- For future template feature
local currentSelectedStation = nil

local isDragging = false
local dragStart = nil
local startPos = nil

-- Callback
local onSaveCallback = nil
local onVisibilityCallback = nil

-- macOS Monterey Style Colors (Enhanced)
local colors = {
    background = Color3.fromRGB(18, 18, 20),
    surface = Color3.fromRGB(32, 32, 34),
    surfaceLight = Color3.fromRGB(45, 45, 47),
    primary = Color3.fromRGB(0, 122, 255),
    primaryHover = Color3.fromRGB(10, 132, 255),
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
    warning = Color3.fromRGB(255, 214, 10),
    success = Color3.fromRGB(48, 209, 88),
    shadow = Color3.fromRGB(0, 0, 0)
}

-- Utility function to get rarity color
local function getRarityColor(rarity)
    if rarity >= 6 then return Color3.fromRGB(255, 45, 85)
    elseif rarity >= 5 then return Color3.fromRGB(255, 69, 58)
    elseif rarity >= 4 then return Color3.fromRGB(175, 82, 222)
    elseif rarity >= 3 then return Color3.fromRGB(88, 86, 214)
    elseif rarity >= 2 then return Color3.fromRGB(48, 209, 88)
    else return Color3.fromRGB(174, 174, 178)
    end
end

-- Create main UI
local function createMainUI()
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "StationFeedSetupUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = PlayerGui
    
    MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 900, 0, 550)
    MainFrame.Position = UDim2.new(0.5, -450, 0.5, -275)
    MainFrame.BackgroundColor3 = colors.background
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = MainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.primary
    stroke.Thickness = 2
    stroke.Parent = MainFrame
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = colors.surface
    titleBar.BorderSizePixel = 0
    titleBar.Parent = MainFrame
    
    local titleBarCorner = Instance.new("UICorner")
    titleBarCorner.CornerRadius = UDim.new(0, 12)
    titleBarCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -100, 1, 0)
    titleLabel.Position = UDim2.new(0, 16, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🍎 Station Feed Setup"
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextColor3 = colors.text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 40, 0, 40)
    closeButton.Position = UDim2.new(1, -45, 0, 5)
    closeButton.BackgroundColor3 = colors.close
    closeButton.BorderSizePixel = 0
    closeButton.Text = "❌"
    closeButton.TextSize = 18
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(1, 0)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        StationFeedSetup.Hide()
    end)
    
    -- Draggable
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)
    
    -- Left Panel: Big Pet List
    local leftPanel = Instance.new("Frame")
    leftPanel.Size = UDim2.new(0.35, -8, 1, -120)
    leftPanel.Position = UDim2.new(0, 16, 0, 66)
    leftPanel.BackgroundColor3 = colors.surface
    leftPanel.BorderSizePixel = 0
    leftPanel.Parent = MainFrame
    
    local leftCorner = Instance.new("UICorner")
    leftCorner.CornerRadius = UDim.new(0, 8)
    leftCorner.Parent = leftPanel
    
    local leftTitle = Instance.new("TextLabel")
    leftTitle.Size = UDim2.new(1, -16, 0, 30)
    leftTitle.Position = UDim2.new(0, 8, 0, 8)
    leftTitle.BackgroundTransparency = 1
    leftTitle.Text = "🐾 Big Pets"
    leftTitle.TextSize = 13
    leftTitle.Font = Enum.Font.GothamBold
    leftTitle.TextColor3 = colors.text
    leftTitle.TextXAlignment = Enum.TextXAlignment.Left
    leftTitle.Parent = leftPanel
    
    local petScroll = Instance.new("ScrollingFrame")
    petScroll.Size = UDim2.new(1, -16, 1, -48)
    petScroll.Position = UDim2.new(0, 8, 0, 40)
    petScroll.BackgroundTransparency = 1
    petScroll.ScrollBarThickness = 4
    petScroll.ScrollBarImageColor3 = colors.primary
    petScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    petScroll.Parent = leftPanel
    
    local petLayout = Instance.new("UIListLayout")
    petLayout.Padding = UDim.new(0, 4)
    petLayout.Parent = petScroll
    
    -- Right Panel: Fruit Grid
    local rightPanel = Instance.new("Frame")
    rightPanel.Size = UDim2.new(0.65, -24, 1, -120)
    rightPanel.Position = UDim2.new(0.35, 8, 0, 66)
    rightPanel.BackgroundColor3 = colors.surface
    rightPanel.BorderSizePixel = 0
    rightPanel.Parent = MainFrame
    
    local rightCorner = Instance.new("UICorner")
    rightCorner.CornerRadius = UDim.new(0, 8)
    rightCorner.Parent = rightPanel
    
    local rightTitle = Instance.new("TextLabel")
    rightTitle.Size = UDim2.new(1, -16, 0, 30)
    rightTitle.Position = UDim2.new(0, 8, 0, 8)
    rightTitle.BackgroundTransparency = 1
    rightTitle.Text = "🍎 Select Fruits"
    rightTitle.TextSize = 13
    rightTitle.Font = Enum.Font.GothamBold
    rightTitle.TextColor3 = colors.textSecondary
    rightTitle.TextXAlignment = Enum.TextXAlignment.Left
    rightTitle.Parent = rightPanel
    
    -- Action buttons (Select All / Clear All)
    local actionButtons = Instance.new("Frame")
    actionButtons.Size = UDim2.new(1, -16, 0, 28)
    actionButtons.Position = UDim2.new(0, 8, 0, 42)
    actionButtons.BackgroundTransparency = 1
    actionButtons.Parent = rightPanel
    
    local buttonLayout = Instance.new("UIListLayout")
    buttonLayout.FillDirection = Enum.FillDirection.Horizontal
    buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    buttonLayout.Padding = UDim.new(0, 6)
    buttonLayout.Parent = actionButtons
    
    local selectAllBtn = Instance.new("TextButton")
    selectAllBtn.Size = UDim2.new(0, 100, 0, 28)
    selectAllBtn.BackgroundColor3 = colors.primary
    selectAllBtn.BorderSizePixel = 0
    selectAllBtn.Text = "✔️ Select All"
    selectAllBtn.TextSize = 11
    selectAllBtn.Font = Enum.Font.GothamMedium
    selectAllBtn.TextColor3 = colors.text
    selectAllBtn.Parent = actionButtons
    
    local selectAllCorner = Instance.new("UICorner")
    selectAllCorner.CornerRadius = UDim.new(0, 6)
    selectAllCorner.Parent = selectAllBtn
    
    local clearAllBtn = Instance.new("TextButton")
    clearAllBtn.Size = UDim2.new(0, 100, 0, 28)
    clearAllBtn.BackgroundColor3 = colors.close
    clearAllBtn.BorderSizePixel = 0
    clearAllBtn.Text = "❌ Clear All"
    clearAllBtn.TextSize = 11
    clearAllBtn.Font = Enum.Font.GothamMedium
    clearAllBtn.TextColor3 = colors.text
    clearAllBtn.Parent = actionButtons
    
    local clearAllCorner = Instance.new("UICorner")
    clearAllCorner.CornerRadius = UDim.new(0, 6)
    clearAllCorner.Parent = clearAllBtn
    
    local fruitScroll = Instance.new("ScrollingFrame")
    fruitScroll.Size = UDim2.new(1, -16, 1, -82)
    fruitScroll.Position = UDim2.new(0, 8, 0, 74)
    fruitScroll.BackgroundTransparency = 1
    fruitScroll.ScrollBarThickness = 4
    fruitScroll.ScrollBarImageColor3 = colors.primary
    fruitScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    fruitScroll.Parent = rightPanel
    
    local fruitGrid = Instance.new("UIGridLayout")
    fruitGrid.CellSize = UDim2.new(0.31, 0, 0, 130)
    fruitGrid.CellPadding = UDim2.new(0.015, 0, 0, 8)
    fruitGrid.SortOrder = Enum.SortOrder.LayoutOrder
    fruitGrid.Parent = fruitScroll
    
    local fruitPadding = Instance.new("UIPadding")
    fruitPadding.PaddingTop = UDim.new(0, 4)
    fruitPadding.PaddingBottom = UDim.new(0, 4)
    fruitPadding.Parent = fruitScroll
    
    -- Function to refresh fruit grid for selected station
    local function refreshFruitGrid(stationId)
        -- Clear existing fruits
        for _, child in ipairs(fruitScroll:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        if not stationId then
            rightTitle.Text = "🍎 Select a Big Pet first"
            rightTitle.TextColor3 = colors.textSecondary
            return
        end
        
        rightTitle.Text = "🍎 Fruits for Station " .. stationId
        rightTitle.TextColor3 = colors.text
        
        -- Initialize if not exists
        if not stationFruitAssignments[stationId] then
            stationFruitAssignments[stationId] = {}
        end
        
        local inventory = getPlayerFruitInventory()
        
        -- Sort fruits by rarity
        local sortedFruits = {}
        for fruitId, fruitData in pairs(FruitData) do
            table.insert(sortedFruits, {id = fruitId, data = fruitData})
        end
        table.sort(sortedFruits, function(a, b)
            return (a.data.Rarity or 1) < (b.data.Rarity or 1)
        end)
        
        for i, fruitInfo in ipairs(sortedFruits) do
            local fruitId = fruitInfo.id
            local fruitData = fruitInfo.data
            
            local card = Instance.new("TextButton")
            card.Name = "Fruit_" .. fruitId
            card.Size = UDim2.new(0.31, 0, 0, 130)
            card.BackgroundColor3 = stationFruitAssignments[stationId][fruitId] and colors.selected or colors.surface
            card.BorderSizePixel = 0
            card.Text = ""
            card.LayoutOrder = i
            card.Parent = fruitScroll
            
            local cardCorner = Instance.new("UICorner")
            cardCorner.CornerRadius = UDim.new(0, 8)
            cardCorner.Parent = card
            
            local cardStroke = Instance.new("UIStroke")
            cardStroke.Color = stationFruitAssignments[stationId][fruitId] and colors.selected or colors.border
            cardStroke.Thickness = stationFruitAssignments[stationId][fruitId] and 2 or 1
            cardStroke.Parent = card
            
            -- Icon Container (larger)
            local iconContainer = Instance.new("Frame")
            iconContainer.Size = UDim2.new(0, 70, 0, 70)
            iconContainer.Position = UDim2.new(0.5, -35, 0.12, 0)
            iconContainer.BackgroundTransparency = 1
            iconContainer.Parent = card
            
            -- Try to show model first, fallback to icon/emoji
            if fruitData.Model and fruitData.Model:IsA("Model") then
                local viewport = Instance.new("ViewportFrame")
                viewport.Size = UDim2.new(1, 0, 1, 0)
                viewport.BackgroundTransparency = 1
                viewport.Parent = iconContainer
                
                local modelClone = fruitData.Model:Clone()
                modelClone.Parent = viewport
                
                local camera = Instance.new("Camera")
                camera.Parent = viewport
                viewport.CurrentCamera = camera
                
                local modelCF, modelSize = modelClone:GetBoundingBox()
                local maxSize = math.max(modelSize.X, modelSize.Y, modelSize.Z)
                local distance = maxSize * 1.8
                camera.CFrame = CFrame.new(modelCF.Position + Vector3.new(distance, distance * 0.4, distance), modelCF.Position)
                
                local light = Instance.new("PointLight")
                light.Brightness = 2
                light.Range = 30
                light.Parent = camera
            elseif fruitData.Icon and fruitData.Icon ~= "" then
                if string.find(fruitData.Icon, "rbxassetid://") then
                    local imageLabel = Instance.new("ImageLabel")
                    imageLabel.Size = UDim2.new(1, 0, 1, 0)
                    imageLabel.BackgroundTransparency = 1
                    imageLabel.Image = fruitData.Icon
                    imageLabel.ScaleType = Enum.ScaleType.Fit
                    imageLabel.Parent = iconContainer
                else
                    local textLabel = Instance.new("TextLabel")
                    textLabel.Size = UDim2.new(1, 0, 1, 0)
                    textLabel.BackgroundTransparency = 1
                    textLabel.Text = fruitData.Icon
                    textLabel.TextSize = 48
                    textLabel.Font = Enum.Font.GothamBold
                    textLabel.TextColor3 = getRarityColor(fruitData.Rarity)
                    textLabel.Parent = iconContainer
                end
            else
                local textLabel = Instance.new("TextLabel")
                textLabel.Size = UDim2.new(1, 0, 1, 0)
                textLabel.BackgroundTransparency = 1
                textLabel.Text = "🍎"
                textLabel.TextSize = 48
                textLabel.Font = Enum.Font.GothamBold
                textLabel.TextColor3 = getRarityColor(fruitData.Rarity)
                textLabel.Parent = iconContainer
            end
            
            -- Name
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -12, 0, 20)
            nameLabel.Position = UDim2.new(0, 6, 0.68, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = fruitData.Name
            nameLabel.TextSize = 11
            nameLabel.Font = Enum.Font.GothamSemibold
            nameLabel.TextColor3 = colors.text
            nameLabel.TextXAlignment = Enum.TextXAlignment.Center
            nameLabel.TextWrapped = true
            nameLabel.Parent = card
            
            -- Amount
            local amount = inventory[fruitId] or 0
            local amountLabel = Instance.new("TextLabel")
            amountLabel.Size = UDim2.new(1, -12, 0, 16)
            amountLabel.Position = UDim2.new(0, 6, 0.85, 0)
            amountLabel.BackgroundTransparency = 1
            amountLabel.Text = formatNumber(amount)
            amountLabel.TextSize = 10
            amountLabel.Font = Enum.Font.Gotham
            amountLabel.TextColor3 = amount > 0 and colors.textSecondary or colors.close
            amountLabel.TextXAlignment = Enum.TextXAlignment.Center
            amountLabel.Parent = card
            
            -- Checkmark
            local checkmark = Instance.new("TextLabel")
            checkmark.Size = UDim2.new(0, 20, 0, 20)
            checkmark.Position = UDim2.new(1, -24, 0, 4)
            checkmark.BackgroundTransparency = 1
            checkmark.Text = "✓"
            checkmark.TextSize = 14
            checkmark.Font = Enum.Font.GothamBold
            checkmark.TextColor3 = colors.text
            checkmark.Visible = stationFruitAssignments[stationId][fruitId] == true
            checkmark.Parent = card
            
            -- Click handler
            card.MouseButton1Click:Connect(function()
                if stationFruitAssignments[stationId][fruitId] then
                    stationFruitAssignments[stationId][fruitId] = nil
                    checkmark.Visible = false
                    TweenService:Create(card, TweenInfo.new(0.2), {BackgroundColor3 = colors.surface}):Play()
                    TweenService:Create(cardStroke, TweenInfo.new(0.2), {
                        Color = colors.border,
                        Thickness = 1
                    }):Play()
                else
                    stationFruitAssignments[stationId][fruitId] = true
                    checkmark.Visible = true
                    TweenService:Create(card, TweenInfo.new(0.2), {BackgroundColor3 = colors.selected}):Play()
                    TweenService:Create(cardStroke, TweenInfo.new(0.2), {
                        Color = colors.selected,
                        Thickness = 2
                    }):Play()
                end
            end)
            
            -- Hover
            card.MouseEnter:Connect(function()
                if not stationFruitAssignments[stationId][fruitId] then
                    TweenService:Create(card, TweenInfo.new(0.2), {BackgroundColor3 = colors.hover}):Play()
                end
            end)
            card.MouseLeave:Connect(function()
                if not stationFruitAssignments[stationId][fruitId] then
                    TweenService:Create(card, TweenInfo.new(0.2), {BackgroundColor3 = colors.surface}):Play()
                end
            end)
        end
    end
    
    -- Select All / Clear All handlers
    selectAllBtn.MouseButton1Click:Connect(function()
        if currentSelectedStation then
            for fruitId in pairs(FruitData) do
                stationFruitAssignments[currentSelectedStation][fruitId] = true
            end
            refreshFruitGrid(currentSelectedStation)
        end
    end)
    
    clearAllBtn.MouseButton1Click:Connect(function()
        if currentSelectedStation then
            stationFruitAssignments[currentSelectedStation] = {}
            refreshFruitGrid(currentSelectedStation)
        end
    end)
    
    -- Function to refresh pet list
    local function refreshPetList()
        for _, child in ipairs(petScroll:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        local pets = getPlayerOwnedPets()
        
        if #pets == 0 then
            local noStations = Instance.new("TextLabel")
            noStations.Size = UDim2.new(1, -8, 0, 60)
            noStations.BackgroundTransparency = 1
            noStations.Text = "No Big Pets Found\n\nPlace Big Pets first"
            noStations.TextSize = 11
            noStations.Font = Enum.Font.Gotham
            noStations.TextColor3 = colors.textSecondary
            noStations.Parent = petScroll
            return
        end
        
        for i, petInfo in ipairs(pets) do
            local card = Instance.new("TextButton")
            card.Size = UDim2.new(1, 0, 0, 50)
            card.BackgroundColor3 = colors.surfaceLight
            card.BorderSizePixel = 0
            card.Text = ""
            card.Parent = petScroll
            
            local cardCorner = Instance.new("UICorner")
            cardCorner.CornerRadius = UDim.new(0, 6)
            cardCorner.Parent = card
            
            local cardStroke = Instance.new("UIStroke")
            cardStroke.Color = colors.border
            cardStroke.Thickness = 1
            cardStroke.Parent = card
            
            -- Station number badge
            local badge = Instance.new("TextLabel")
            badge.Size = UDim2.new(0, 36, 0, 36)
            badge.Position = UDim2.new(0, 8, 0.5, -18)
            badge.BackgroundColor3 = colors.primary
            badge.BorderSizePixel = 0
            badge.Text = petInfo.stationId
            badge.TextSize = 16
            badge.Font = Enum.Font.GothamBold
            badge.TextColor3 = colors.text
            badge.Parent = card
            
            local badgeCorner = Instance.new("UICorner")
            badgeCorner.CornerRadius = UDim.new(1, 0)
            badgeCorner.Parent = badge
            
            -- Pet name
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -100, 0, 18)
            nameLabel.Position = UDim2.new(0, 50, 0, 8)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = petInfo.displayName
            nameLabel.TextSize = 12
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextColor3 = colors.text
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            nameLabel.Parent = card
            
            -- Fruit count
            local fruitCount = 0
            if stationFruitAssignments[petInfo.stationId] then
                for _ in pairs(stationFruitAssignments[petInfo.stationId]) do
                    fruitCount = fruitCount + 1
                end
            end
            
            local countLabel = Instance.new("TextLabel")
            countLabel.Size = UDim2.new(1, -100, 0, 14)
            countLabel.Position = UDim2.new(0, 50, 0, 28)
            countLabel.BackgroundTransparency = 1
            countLabel.Text = string.format("🍎 %d fruits", fruitCount)
            countLabel.TextSize = 10
            countLabel.Font = Enum.Font.Gotham
            countLabel.TextColor3 = fruitCount > 0 and colors.maximize or colors.textSecondary
            countLabel.TextXAlignment = Enum.TextXAlignment.Left
            countLabel.Parent = card
            
            -- Arrow indicator
            local arrow = Instance.new("TextLabel")
            arrow.Size = UDim2.new(0, 20, 0, 20)
            arrow.Position = UDim2.new(1, -28, 0.5, -10)
            arrow.BackgroundTransparency = 1
            arrow.Text = "›"
            arrow.TextSize = 20
            arrow.Font = Enum.Font.GothamBold
            arrow.TextColor3 = colors.textSecondary
            arrow.Parent = card
            
            -- Click handler
            card.MouseButton1Click:Connect(function()
                currentSelectedStation = petInfo.stationId
                
                -- Update all cards
                for _, otherCard in ipairs(petScroll:GetChildren()) do
                    if otherCard:IsA("TextButton") then
                        local otherStroke = otherCard:FindFirstChild("UIStroke")
                        if otherCard == card then
                            TweenService:Create(otherCard, TweenInfo.new(0.2), {BackgroundColor3 = colors.selected}):Play()
                            if otherStroke then
                                otherStroke.Color = colors.selected
                                otherStroke.Thickness = 2
                            end
                        else
                            TweenService:Create(otherCard, TweenInfo.new(0.2), {BackgroundColor3 = colors.surfaceLight}):Play()
                            if otherStroke then
                                otherStroke.Color = colors.border
                                otherStroke.Thickness = 1
                            end
                        end
                    end
                end
                
                refreshFruitGrid(petInfo.stationId)
            end)
            
            -- Hover
            card.MouseEnter:Connect(function()
                if currentSelectedStation ~= petInfo.stationId then
                    TweenService:Create(card, TweenInfo.new(0.2), {BackgroundColor3 = colors.hover}):Play()
                end
            end)
            card.MouseLeave:Connect(function()
                if currentSelectedStation ~= petInfo.stationId then
                    TweenService:Create(card, TweenInfo.new(0.2), {BackgroundColor3 = colors.surfaceLight}):Play()
                end
            end)
        end
    end
    
    refreshPetList()
    
    -- Bottom buttons (macOS style)
    local actions = Instance.new("Frame")
    actions.Size = UDim2.new(1, -32, 0, 48)
    actions.Position = UDim2.new(0, 16, 1, -64)
    actions.BackgroundTransparency = 1
    actions.Parent = MainFrame
    
    local actionsLayout = Instance.new("UIListLayout")
    actionsLayout.FillDirection = Enum.FillDirection.Horizontal
    actionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    actionsLayout.Padding = UDim.new(0, 10)
    actionsLayout.Parent = actions
    
    -- Refresh
    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(0, 130, 0, 42)
    refreshBtn.BackgroundColor3 = colors.secondary
    refreshBtn.BorderSizePixel = 0
    refreshBtn.Text = "🔄 Refresh"
    refreshBtn.TextSize = 13
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextColor3 = colors.text
    refreshBtn.Parent = actions
    
    local refreshCorner = Instance.new("UICorner")
    refreshCorner.CornerRadius = UDim.new(0, 10)
    refreshCorner.Parent = refreshBtn
    
    refreshBtn.MouseEnter:Connect(function()
        TweenService:Create(refreshBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(98, 96, 224)
        }):Play()
    end)
    refreshBtn.MouseLeave:Connect(function()
        TweenService:Create(refreshBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = colors.secondary
        }):Play()
    end)
    
    refreshBtn.MouseButton1Click:Connect(function()
        refreshPetList()
        if currentSelectedStation then
            refreshFruitGrid(currentSelectedStation)
        end
    end)
    
    -- Copy to all
    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(0, 150, 0, 42)
    copyBtn.BackgroundColor3 = colors.warning
    copyBtn.BorderSizePixel = 0
    copyBtn.Text = "📋 Copy to All"
    copyBtn.TextSize = 13
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.TextColor3 = Color3.new(0, 0, 0)
    copyBtn.Parent = actions
    
    local copyCorner = Instance.new("UICorner")
    copyCorner.CornerRadius = UDim.new(0, 10)
    copyCorner.Parent = copyBtn
    
    copyBtn.MouseEnter:Connect(function()
        TweenService:Create(copyBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(255, 224, 20)
        }):Play()
    end)
    copyBtn.MouseLeave:Connect(function()
        TweenService:Create(copyBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = colors.warning
        }):Play()
    end)
    
    copyBtn.MouseButton1Click:Connect(function()
        local pets = getPlayerOwnedPets()
        if #pets == 0 then return end
        
        local firstId = pets[1].stationId
        local template = stationFruitAssignments[firstId]
        
        if not template or not next(template) then
            warn("No fruits assigned to first station")
            return
        end
        
        for _, petInfo in ipairs(pets) do
            stationFruitAssignments[petInfo.stationId] = {}
            for fruitId, _ in pairs(template) do
                stationFruitAssignments[petInfo.stationId][fruitId] = true
            end
        end
        
        refreshPetList()
        if currentSelectedStation then
            refreshFruitGrid(currentSelectedStation)
        end
    end)
    
    -- Save & Close
    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0, 160, 0, 42)
    saveBtn.BackgroundColor3 = colors.maximize
    saveBtn.BorderSizePixel = 0
    saveBtn.Text = "✓ Save & Close"
    saveBtn.TextSize = 13
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextColor3 = colors.text
    saveBtn.Parent = actions
    
    local saveCorner = Instance.new("UICorner")
    saveCorner.CornerRadius = UDim.new(0, 10)
    saveCorner.Parent = saveBtn
    
    saveBtn.MouseEnter:Connect(function()
        TweenService:Create(saveBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(58, 219, 98)
        }):Play()
    end)
    saveBtn.MouseLeave:Connect(function()
        TweenService:Create(saveBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = colors.maximize
        }):Play()
    end)
    
    saveBtn.MouseButton1Click:Connect(function()
        if onSaveCallback then
            onSaveCallback(stationFruitAssignments)
        end
        StationFeedSetup.Hide()
    end)
end

-- Public API
function StationFeedSetup.Show(saveCallback, visibilityCallback, initialData)
    onSaveCallback = saveCallback
    onVisibilityCallback = visibilityCallback
    
    if initialData then
        stationFruitAssignments = initialData
    end
    
    if not ScreenGui then
        createMainUI()
    end
    
    if ScreenGui then
        ScreenGui.Enabled = true
        if onVisibilityCallback then
            onVisibilityCallback(true)
        end
    end
end

function StationFeedSetup.Hide()
    if ScreenGui then
        ScreenGui.Enabled = false
        if onVisibilityCallback then
            onVisibilityCallback(false)
        end
    end
end

function StationFeedSetup.GetAssignments()
    return stationFruitAssignments
end

function StationFeedSetup.SetAssignments(data)
    stationFruitAssignments = data or {}
end

function StationFeedSetup.ClearAll()
    stationFruitAssignments = {}
end

-- Function to reload fruit data from the game (useful when game updates)
function StationFeedSetup.ReloadFruitData()
    local newFruitData = LoadFruitDataFromGame()
    
    if newFruitData and next(newFruitData) then
        -- Preserve existing station assignments
        local oldAssignments = {}
        for stationId, fruits in pairs(stationFruitAssignments) do
            oldAssignments[stationId] = {}
            for fruitId, _ in pairs(fruits) do
                oldAssignments[stationId][fruitId] = true
            end
        end
        
        -- Update fruit data
        FruitData = newFruitData
        
        -- Re-apply assignments that still exist in new data
        stationFruitAssignments = {}
        for stationId, fruits in pairs(oldAssignments) do
            stationFruitAssignments[stationId] = {}
            for fruitId, _ in pairs(fruits) do
                if FruitData[fruitId] then
                    stationFruitAssignments[stationId][fruitId] = true
                end
            end
        end
        
        return true
    end
    
    return false
end

-- Function to get current fruit data (for debugging)
function StationFeedSetup.GetFruitData()
    return FruitData
end

-- Function to check if data is loaded
function StationFeedSetup.IsDataLoaded()
    return StationFeedSetup.DataLoaded and next(FruitData) ~= nil
end

-- Function to wait for data to be loaded
function StationFeedSetup.WaitForDataLoad(timeout)
    local maxWait = timeout or 10
    local waited = 0
    
    while waited < maxWait do
        if StationFeedSetup.IsDataLoaded() then
            return true
        end
        task.wait(0.1)
        waited = waited + 0.1
    end
    
    warn("[StationFeedSetup] ⚠️ Data load timeout after " .. maxWait .. " seconds")
    return false
end

return StationFeedSetup
