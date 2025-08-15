-- Custom Egg Selector UI for Build A Zoo
-- Replaces dropdown with visual grid selection

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Egg and mutation data
local eggData = {
    BasicEgg = { Name = "Basic Egg", Price = "100", Icon = "rbxassetid://129248801621928", Rarity = 1 },
    RareEgg = { Name = "Rare Egg", Price = "500", Icon = "rbxassetid://71012831091414", Rarity = 2 },
    SuperRareEgg = { Name = "Super Rare Egg", Price = "2,500", Icon = "rbxassetid://93845452154351", Rarity = 2 },
    EpicEgg = { Name = "Epic Egg", Price = "15,000", Icon = "rbxassetid://116395645531721", Rarity = 2 },
    LegendEgg = { Name = "Legend Egg", Price = "100,000", Icon = "rbxassetid://90834918351014", Rarity = 3 },
    PrismaticEgg = { Name = "Prismatic Egg", Price = "1,000,000", Icon = "rbxassetid://79960683434582", Rarity = 4 },
    HyperEgg = { Name = "Hyper Egg", Price = "3,000,000", Icon = "rbxassetid://104958288296273", Rarity = 5 },
    VoidEgg = { Name = "Void Egg", Price = "24,000,000", Icon = "rbxassetid://122396162708984", Rarity = 5 },
    BowserEgg = { Name = "Bowser Egg", Price = "130,000,000", Icon = "rbxassetid://71500536051510", Rarity = 5 },
    DemonEgg = { Name = "Demon Egg", Price = "400,000,000", Icon = "rbxassetid://126412407639969", Rarity = 5 },
    BoneDragonEgg = { Name = "Bone Dragon Egg", Price = "2,000,000,000", Icon = "rbxassetid://83209913424562", Rarity = 5 },
    UltraEgg = { Name = "Ultra Egg", Price = "10,000,000,000", Icon = "rbxassetid://83909590718799", Rarity = 6 },
    DinoEgg = { Name = "Dino Egg", Price = "10,000,000,000", Icon = "rbxassetid://80783528632315", Rarity = 6 },
    FlyEgg = { Name = "Fly Egg", Price = "999,999,999,999", Icon = "rbxassetid://109240587278187", Rarity = 6 },
    UnicornEgg = { Name = "Unicorn Egg", Price = "40,000,000,000", Icon = "rbxassetid://123427249205445", Rarity = 6 },
    AncientEgg = { Name = "Ancient Egg", Price = "999,999,999,999", Icon = "rbxassetid://113910587565739", Rarity = 6 }
}

local mutationData = {
    Golden = { Name = "Golden", Color = Color3.fromHex("#ffc518"), Rarity = 10 },
    Diamond = { Name = "Diamond", Color = Color3.fromHex("#07e6ff"), Rarity = 20 },
    Electirc = { Name = "Electric", Color = Color3.fromHex("#aa55ff"), Rarity = 50 },
    Fire = { Name = "Fire", Color = Color3.fromHex("#ff3d02"), Rarity = 100 },
    Dino = { Name = "Jurassic", Color = Color3.fromHex("#AE75E7"), Rarity = 100 }
}

-- Selected items storage
local selectedEggs = {}
local selectedMutations = {}

-- Create the main UI
local function createCustomEggSelector()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CustomEggSelector"
    screenGui.Parent = game:GetService("CoreGui")
    
    -- Main frame with parchment-like style
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 600, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(245, 241, 235) -- Light beige
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- Border effect
    local border = Instance.new("Frame")
    border.Name = "Border"
    border.Size = UDim2.new(1, 4, 1, 4)
    border.Position = UDim2.new(0, -2, 0, -2)
    border.BackgroundColor3 = Color3.fromRGB(101, 67, 33) -- Dark brown
    border.BorderSizePixel = 0
    border.Parent = mainFrame
    
    local innerBorder = Instance.new("Frame")
    innerBorder.Name = "InnerBorder"
    innerBorder.Size = UDim2.new(1, -4, 1, -4)
    innerBorder.Position = UDim2.new(0, 2, 0, 2)
    innerBorder.BackgroundColor3 = Color3.fromRGB(245, 241, 235)
    innerBorder.BorderSizePixel = 0
    innerBorder.Parent = border
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(101, 67, 33)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = innerBorder
    
    local titleText = Instance.new("TextLabel")
    titleText.Name = "TitleText"
    titleText.Size = UDim2.new(1, -80, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "Egg Selection"
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.TextScaled = true
    titleText.Font = Enum.Font.GothamBold
    titleText.Parent = titleBar
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = titleBar
    
    -- Minimize button
    local minimizeButton = Instance.new("TextButton")
    minimizeButton.Name = "MinimizeButton"
    minimizeButton.Size = UDim2.new(0, 30, 0, 30)
    minimizeButton.Position = UDim2.new(1, -70, 0, 5)
    minimizeButton.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
    minimizeButton.Text = "-"
    minimizeButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    minimizeButton.TextScaled = true
    minimizeButton.Font = Enum.Font.GothamBold
    minimizeButton.Parent = titleBar
    
    -- Content area
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -20, 1, -60)
    contentFrame.Position = UDim2.new(0, 10, 0, 50)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = innerBorder
    
    -- Tab buttons
    local tabFrame = Instance.new("Frame")
    tabFrame.Name = "TabFrame"
    tabFrame.Size = UDim2.new(1, 0, 0, 40)
    tabFrame.BackgroundTransparency = 1
    tabFrame.Parent = contentFrame
    
    local eggsTab = Instance.new("TextButton")
    eggsTab.Name = "EggsTab"
    eggsTab.Size = UDim2.new(0.5, -5, 1, 0)
    eggsTab.Position = UDim2.new(0, 0, 0, 0)
    eggsTab.BackgroundColor3 = Color3.fromRGB(101, 67, 33)
    eggsTab.Text = "Eggs"
    eggsTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    eggsTab.TextScaled = true
    eggsTab.Font = Enum.Font.GothamBold
    eggsTab.Parent = tabFrame
    
    local mutationsTab = Instance.new("TextButton")
    mutationsTab.Name = "MutationsTab"
    mutationsTab.Size = UDim2.new(0.5, -5, 1, 0)
    mutationsTab.Position = UDim2.new(0.5, 5, 0, 0)
    mutationsTab.BackgroundColor3 = Color3.fromRGB(169, 169, 169)
    mutationsTab.Text = "Mutations"
    mutationsTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    mutationsTab.TextScaled = true
    mutationsTab.Font = Enum.Font.GothamBold
    mutationsTab.Parent = tabFrame
    
    -- Scroll frame for items
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, 0, 1, -50)
    scrollFrame.Position = UDim2.new(0, 0, 0, 50)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = contentFrame
    
    -- Grid layout for items
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 120, 0, 140)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.Parent = scrollFrame
    
    -- Status text
    local statusText = Instance.new("TextLabel")
    statusText.Name = "StatusText"
    statusText.Size = UDim2.new(1, 0, 0, 30)
    statusText.Position = UDim2.new(0, 0, 1, -30)
    statusText.BackgroundTransparency = 1
    statusText.Text = "Selected: 0 eggs, 0 mutations"
    statusText.TextColor3 = Color3.fromRGB(101, 67, 33)
    statusText.TextScaled = true
    statusText.Font = Enum.Font.Gotham
    statusText.Parent = contentFrame
    
    -- Create egg items
    local function createEggItems()
        for eggId, eggInfo in pairs(eggData) do
            local eggFrame = Instance.new("Frame")
            eggFrame.Name = eggId
            eggFrame.Size = UDim2.new(0, 120, 0, 140)
            eggFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            eggFrame.BorderSizePixel = 2
            eggFrame.BorderColor3 = Color3.fromRGB(101, 67, 33)
            eggFrame.Parent = scrollFrame
            
            -- Selection indicator
            local selectionIndicator = Instance.new("Frame")
            selectionIndicator.Name = "SelectionIndicator"
            selectionIndicator.Size = UDim2.new(1, 0, 0, 4)
            selectionIndicator.Position = UDim2.new(0, 0, 0, 0)
            selectionIndicator.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
            selectionIndicator.Visible = false
            selectionIndicator.Parent = eggFrame
            
            -- Egg icon
            local iconFrame = Instance.new("Frame")
            iconFrame.Name = "IconFrame"
            iconFrame.Size = UDim2.new(0, 60, 0, 60)
            iconFrame.Position = UDim2.new(0.5, -30, 0, 10)
            iconFrame.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
            iconFrame.BorderSizePixel = 1
            iconFrame.BorderColor3 = Color3.fromRGB(200, 200, 200)
            iconFrame.Parent = eggFrame
            
            local iconImage = Instance.new("ImageLabel")
            iconImage.Name = "Icon"
            iconImage.Size = UDim2.new(1, -4, 1, -4)
            iconImage.Position = UDim2.new(0, 2, 0, 2)
            iconImage.BackgroundTransparency = 1
            iconImage.Image = eggInfo.Icon
            iconImage.Parent = iconFrame
            
            -- Egg name
            local nameText = Instance.new("TextLabel")
            nameText.Name = "Name"
            nameText.Size = UDim2.new(1, -10, 0, 20)
            nameText.Position = UDim2.new(0, 5, 0, 75)
            nameText.BackgroundTransparency = 1
            nameText.Text = eggInfo.Name
            nameText.TextColor3 = Color3.fromRGB(0, 0, 0)
            nameText.TextScaled = true
            nameText.Font = Enum.Font.Gotham
            nameText.Parent = eggFrame
            
            -- Price
            local priceText = Instance.new("TextLabel")
            priceText.Name = "Price"
            priceText.Size = UDim2.new(1, -10, 0, 20)
            priceText.Position = UDim2.new(0, 5, 0, 95)
            priceText.BackgroundTransparency = 1
            priceText.Text = "$" .. eggInfo.Price
            priceText.TextColor3 = Color3.fromRGB(40, 167, 69)
            priceText.TextScaled = true
            priceText.Font = Enum.Font.GothamBold
            priceText.Parent = eggFrame
            
            -- Rarity indicator
            local rarityFrame = Instance.new("Frame")
            rarityFrame.Name = "Rarity"
            rarityFrame.Size = UDim2.new(0, 20, 0, 20)
            rarityFrame.Position = UDim2.new(1, -25, 0, 5)
            rarityFrame.BackgroundColor3 = getRarityColor(eggInfo.Rarity)
            rarityFrame.BorderSizePixel = 1
            rarityFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
            rarityFrame.Parent = eggFrame
            
            -- Click handler
            eggFrame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    toggleEggSelection(eggId, eggFrame)
                end
            end)
        end
    end
    
    -- Create mutation items
    local function createMutationItems()
        for mutationId, mutationInfo in pairs(mutationData) do
            local mutationFrame = Instance.new("Frame")
            mutationFrame.Name = mutationId
            mutationFrame.Size = UDim2.new(0, 120, 0, 140)
            mutationFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            mutationFrame.BorderSizePixel = 2
            mutationFrame.BorderColor3 = Color3.fromRGB(101, 67, 33)
            mutationFrame.Visible = false
            mutationFrame.Parent = scrollFrame
            
            -- Selection indicator
            local selectionIndicator = Instance.new("Frame")
            selectionIndicator.Name = "SelectionIndicator"
            selectionIndicator.Size = UDim2.new(1, 0, 0, 4)
            selectionIndicator.Position = UDim2.new(0, 0, 0, 0)
            selectionIndicator.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
            selectionIndicator.Visible = false
            selectionIndicator.Parent = mutationFrame
            
            -- Mutation color icon
            local colorFrame = Instance.new("Frame")
            colorFrame.Name = "ColorFrame"
            colorFrame.Size = UDim2.new(0, 60, 0, 60)
            colorFrame.Position = UDim2.new(0.5, -30, 0, 10)
            colorFrame.BackgroundColor3 = mutationInfo.Color
            colorFrame.BorderSizePixel = 2
            colorFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
            colorFrame.Parent = mutationFrame
            
            -- Mutation name
            local nameText = Instance.new("TextLabel")
            nameText.Name = "Name"
            nameText.Size = UDim2.new(1, -10, 0, 20)
            nameText.Position = UDim2.new(0, 5, 0, 75)
            nameText.BackgroundTransparency = 1
            nameText.Text = mutationInfo.Name
            nameText.TextColor3 = Color3.fromRGB(0, 0, 0)
            nameText.TextScaled = true
            nameText.Font = Enum.Font.Gotham
            nameText.Parent = mutationFrame
            
            -- Rarity
            local rarityText = Instance.new("TextLabel")
            rarityText.Name = "Rarity"
            rarityText.Size = UDim2.new(1, -10, 0, 20)
            rarityText.Position = UDim2.new(0, 5, 0, 95)
            rarityText.BackgroundTransparency = 1
            rarityText.Text = "Rarity: " .. mutationInfo.Rarity
            rarityText.TextColor3 = Color3.fromRGB(101, 67, 33)
            rarityText.TextScaled = true
            rarityText.Font = Enum.Font.GothamBold
            rarityText.Parent = mutationFrame
            
            -- Click handler
            mutationFrame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    toggleMutationSelection(mutationId, mutationFrame)
                end
            end)
        end
    end
    
    -- Helper function to get rarity color
    local function getRarityColor(rarity)
        local colors = {
            [1] = Color3.fromRGB(169, 169, 169), -- Gray
            [2] = Color3.fromRGB(0, 128, 0),     -- Green
            [3] = Color3.fromRGB(0, 0, 255),     -- Blue
            [4] = Color3.fromRGB(128, 0, 128),   -- Purple
            [5] = Color3.fromRGB(255, 215, 0),   -- Gold
            [6] = Color3.fromRGB(255, 0, 0),     -- Red
            [10] = Color3.fromRGB(255, 215, 0),  -- Golden
            [20] = Color3.fromRGB(0, 191, 255),  -- Diamond
            [50] = Color3.fromRGB(138, 43, 226), -- Electric
            [100] = Color3.fromRGB(255, 69, 0)   -- Fire
        }
        return colors[rarity] or Color3.fromRGB(169, 169, 169)
    end
    
    -- Toggle egg selection
    local function toggleEggSelection(eggId, eggFrame)
        if selectedEggs[eggId] then
            selectedEggs[eggId] = nil
            eggFrame.SelectionIndicator.Visible = false
        else
            selectedEggs[eggId] = true
            eggFrame.SelectionIndicator.Visible = true
        end
        updateStatusText()
    end
    
    -- Toggle mutation selection
    local function toggleMutationSelection(mutationId, mutationFrame)
        if selectedMutations[mutationId] then
            selectedMutations[mutationId] = nil
            mutationFrame.SelectionIndicator.Visible = false
        else
            selectedMutations[mutationId] = true
            mutationFrame.SelectionIndicator.Visible = true
        end
        updateStatusText()
    end
    
    -- Update status text
    local function updateStatusText()
        local eggCount = 0
        for _ in pairs(selectedEggs) do
            eggCount = eggCount + 1
        end
        
        local mutationCount = 0
        for _ in pairs(selectedMutations) do
            mutationCount = mutationCount + 1
        end
        
        statusText.Text = string.format("Selected: %d eggs, %d mutations", eggCount, mutationCount)
    end
    
    -- Tab switching
    eggsTab.MouseButton1Click:Connect(function()
        eggsTab.BackgroundColor3 = Color3.fromRGB(101, 67, 33)
        mutationsTab.BackgroundColor3 = Color3.fromRGB(169, 169, 169)
        
        -- Show eggs, hide mutations
        for eggId, _ in pairs(eggData) do
            local eggFrame = scrollFrame:FindFirstChild(eggId)
            if eggFrame then
                eggFrame.Visible = true
            end
        end
        
        for mutationId, _ in pairs(mutationData) do
            local mutationFrame = scrollFrame:FindFirstChild(mutationId)
            if mutationFrame then
                mutationFrame.Visible = false
            end
        end
    end)
    
    mutationsTab.MouseButton1Click:Connect(function()
        mutationsTab.BackgroundColor3 = Color3.fromRGB(101, 67, 33)
        eggsTab.BackgroundColor3 = Color3.fromRGB(169, 169, 169)
        
        -- Show mutations, hide eggs
        for eggId, _ in pairs(eggData) do
            local eggFrame = scrollFrame:FindFirstChild(eggId)
            if eggFrame then
                eggFrame.Visible = false
            end
        end
        
        for mutationId, _ in pairs(mutationData) do
            local mutationFrame = scrollFrame:FindFirstChild(mutationId)
            if mutationFrame then
                mutationFrame.Visible = true
            end
        end
    end)
    
    -- Close button
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    -- Minimize button
    local isMinimized = false
    minimizeButton.MouseButton1Click:Connect(function()
        if isMinimized then
            contentFrame.Visible = true
            mainFrame.Size = UDim2.new(0, 600, 0, 400)
            minimizeButton.Text = "-"
            isMinimized = false
        else
            contentFrame.Visible = false
            mainFrame.Size = UDim2.new(0, 600, 0, 50)
            minimizeButton.Text = "+"
            isMinimized = true
        end
    end)
    
    -- Dragging functionality
    local isDragging = false
    local dragStart = nil
    local startPos = nil
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)
    
    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- Create items
    createEggItems()
    createMutationItems()
    
    -- Return functions for external access
    return {
        GetSelectedEggs = function()
            return selectedEggs
        end,
        GetSelectedMutations = function()
            return selectedMutations
        end,
        SetSelectedEggs = function(eggs)
            selectedEggs = eggs or {}
            -- Update visual indicators
            for eggId, eggFrame in pairs(scrollFrame:GetChildren()) do
                if eggData[eggId] then
                    local indicator = eggFrame:FindFirstChild("SelectionIndicator")
                    if indicator then
                        indicator.Visible = selectedEggs[eggId] or false
                    end
                end
            end
            updateStatusText()
        end,
        SetSelectedMutations = function(mutations)
            selectedMutations = mutations or {}
            -- Update visual indicators
            for mutationId, mutationFrame in pairs(scrollFrame:GetChildren()) do
                if mutationData[mutationId] then
                    local indicator = mutationFrame:FindFirstChild("SelectionIndicator")
                    if indicator then
                        indicator.Visible = selectedMutations[mutationId] or false
                    end
                end
            end
            updateStatusText()
        end,
        Destroy = function()
            screenGui:Destroy()
        end
    }
end

-- Export the function
return createCustomEggSelector
