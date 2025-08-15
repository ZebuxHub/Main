-- EggSelection.lua - Modern Glass UI for Egg Selection
-- Created by Zebux

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Hardcoded data (no more module scripts)
local EggData = {
    BasicEgg = {
        Name = "Basic Egg",
        Price = "100",
        Icon = "rbxassetid://129248801621928",
        Rarity = 1
    },
    RareEgg = {
        Name = "Rare Egg", 
        Price = "500",
        Icon = "rbxassetid://71012831091414",
        Rarity = 2
    },
    SuperRareEgg = {
        Name = "Super Rare Egg",
        Price = "2,500", 
        Icon = "rbxassetid://93845452154351",
        Rarity = 2
    },
    EpicEgg = {
        Name = "Epic Egg",
        Price = "15,000",
        Icon = "rbxassetid://116395645531721", 
        Rarity = 2
    },
    LegendEgg = {
        Name = "Legend Egg",
        Price = "100,000",
        Icon = "rbxassetid://90834918351014",
        Rarity = 3
    },
    PrismaticEgg = {
        Name = "Prismatic Egg", 
        Price = "1,000,000",
        Icon = "rbxassetid://79960683434582",
        Rarity = 4
    },
    HyperEgg = {
        Name = "Hyper Egg",
        Price = "3,000,000", 
        Icon = "rbxassetid://104958288296273",
        Rarity = 5
    },
    VoidEgg = {
        Name = "Void Egg",
        Price = "24,000,000",
        Icon = "rbxassetid://122396162708984",
        Rarity = 5
    },
    BowserEgg = {
        Name = "Bowser Egg",
        Price = "130,000,000",
        Icon = "rbxassetid://71500536051510",
        Rarity = 5
    },
    DemonEgg = {
        Name = "Demon Egg",
        Price = "400,000,000",
        Icon = "rbxassetid://126412407639969",
        Rarity = 5
    },
    BoneDragonEgg = {
        Name = "Bone Dragon Egg",
        Price = "2,000,000,000",
        Icon = "rbxassetid://83209913424562",
        Rarity = 5
    },
    UltraEgg = {
        Name = "Ultra Egg",
        Price = "10,000,000,000",
        Icon = "rbxassetid://83909590718799",
        Rarity = 6
    },
    DinoEgg = {
        Name = "Dino Egg",
        Price = "10,000,000,000",
        Icon = "rbxassetid://80783528632315",
        Rarity = 6
    },
    FlyEgg = {
        Name = "Fly Egg",
        Price = "999,999,999,999",
        Icon = "rbxassetid://109240587278187",
        Rarity = 6
    },
    UnicornEgg = {
        Name = "Unicorn Egg",
        Price = "40,000,000,000",
        Icon = "rbxassetid://123427249205445",
        Rarity = 6
    },
    AncientEgg = {
        Name = "Ancient Egg",
        Price = "999,999,999,999",
        Icon = "rbxassetid://113910587565739",
        Rarity = 6
    }
}

local MutationData = {
    Golden = {
        Name = "Golden",
        Color = Color3.fromHex("#ffc518"),
        Rarity = 10
    },
    Diamond = {
        Name = "Diamond", 
        Color = Color3.fromHex("#07e6ff"),
        Rarity = 20
    },
    Electirc = {
        Name = "Electric",
        Color = Color3.fromHex("#aa55ff"),
        Rarity = 50
    },
    Fire = {
        Name = "Fire",
        Color = Color3.fromHex("#ff3d02"),
        Rarity = 100
    },
    Dino = {
        Name = "Jurassic",
        Color = Color3.fromHex("#AE75E7"),
        Rarity = 100
    }
}

-- UI State
local EggSelectionUI = {}
local isUIOpen = false
local selectedEggs = {}
local selectedMutations = {}
local isDragging = false
local dragStart = nil
local uiPosition = UDim2.new(0.5, -250, 0.5, -200)

-- Save/Load System
local function saveSettings()
    local data = {
        selectedEggs = selectedEggs,
        selectedMutations = selectedMutations,
        uiPosition = uiPosition
    }
    
    local success, result = pcall(function()
        writefile("EggSelection_Settings.json", game:GetService("HttpService"):JSONEncode(data))
    end)
    
    return success
end

local function loadSettings()
    local success, result = pcall(function()
        if isfile("EggSelection_Settings.json") then
            local data = game:GetService("HttpService"):JSONDecode(readfile("EggSelection_Settings.json"))
            selectedEggs = data.selectedEggs or {}
            selectedMutations = data.selectedMutations or {}
            uiPosition = data.uiPosition or UDim2.new(0.5, -250, 0.5, -200)
            return true
        end
    end)
    
    return success
end

-- Create Main UI Frame
local function createMainFrame()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EggSelectionUI"
    screenGui.Parent = PlayerGui
    screenGui.ResetOnSpawn = false
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 500, 0, 400)
    mainFrame.Position = uiPosition
    mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- Glass effect
    local glassEffect = Instance.new("Frame")
    glassEffect.Name = "GlassEffect"
    glassEffect.Size = UDim2.new(1, 0, 1, 0)
    glassEffect.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    glassEffect.BackgroundTransparency = 0.9
    glassEffect.BorderSizePixel = 0
    glassEffect.Parent = mainFrame
    
    -- Corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = mainFrame
    
    local glassCorner = Instance.new("UICorner")
    glassCorner.CornerRadius = UDim.new(0, 20)
    glassCorner.Parent = glassEffect
    
    -- Stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.8
    stroke.Thickness = 1
    stroke.Parent = mainFrame
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    titleBar.BackgroundTransparency = 0.1
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 20)
    titleCorner.Parent = titleBar
    
    local titleText = Instance.new("TextLabel")
    titleText.Name = "TitleText"
    titleText.Size = UDim2.new(1, -100, 1, 0)
    titleText.Position = UDim2.new(0, 20, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "🥚 Egg Selection"
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.TextScaled = true
    titleText.Font = Enum.Font.GothamBold
    titleText.Parent = titleBar
    
    -- Close Button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    closeButton.BackgroundTransparency = 0.2
    closeButton.BorderSizePixel = 0
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeButton
    
    -- Minimize Button
    local minimizeButton = Instance.new("TextButton")
    minimizeButton.Name = "MinimizeButton"
    minimizeButton.Size = UDim2.new(0, 30, 0, 30)
    minimizeButton.Position = UDim2.new(1, -80, 0, 10)
    minimizeButton.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
    minimizeButton.BackgroundTransparency = 0.2
    minimizeButton.BorderSizePixel = 0
    minimizeButton.Text = "−"
    minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeButton.TextScaled = true
    minimizeButton.Font = Enum.Font.GothamBold
    minimizeButton.Parent = titleBar
    
    local minimizeCorner = Instance.new("UICorner")
    minimizeCorner.CornerRadius = UDim.new(0, 8)
    minimizeCorner.Parent = minimizeButton
    
    -- Content Area
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -40, 1, -70)
    contentFrame.Position = UDim2.new(0, 20, 0, 50)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    
    -- Tabs
    local tabFrame = Instance.new("Frame")
    tabFrame.Name = "TabFrame"
    tabFrame.Size = UDim2.new(1, 0, 0, 40)
    tabFrame.BackgroundTransparency = 1
    tabFrame.Parent = contentFrame
    
    local eggsTab = Instance.new("TextButton")
    eggsTab.Name = "EggsTab"
    eggsTab.Size = UDim2.new(0.5, -5, 1, 0)
    eggsTab.Position = UDim2.new(0, 0, 0, 0)
    eggsTab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    eggsTab.BackgroundTransparency = 0.1
    eggsTab.BorderSizePixel = 0
    eggsTab.Text = "🥚 Eggs"
    eggsTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    eggsTab.TextScaled = true
    eggsTab.Font = Enum.Font.GothamBold
    eggsTab.Parent = tabFrame
    
    local eggsTabCorner = Instance.new("UICorner")
    eggsTabCorner.CornerRadius = UDim.new(0, 10)
    eggsTabCorner.Parent = eggsTab
    
    local mutationsTab = Instance.new("TextButton")
    mutationsTab.Name = "MutationsTab"
    mutationsTab.Size = UDim2.new(0.5, -5, 1, 0)
    mutationsTab.Position = UDim2.new(0.5, 5, 0, 0)
    mutationsTab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    mutationsTab.BackgroundTransparency = 0.1
    mutationsTab.BorderSizePixel = 0
    mutationsTab.Text = "🧬 Mutations"
    mutationsTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    mutationsTab.TextScaled = true
    mutationsTab.Font = Enum.Font.GothamBold
    mutationsTab.Parent = tabFrame
    
    local mutationsTabCorner = Instance.new("UICorner")
    mutationsTabCorner.CornerRadius = UDim.new(0, 10)
    mutationsTabCorner.Parent = mutationsTab
    
    -- Scroll Frame for Eggs
    local eggsScrollFrame = Instance.new("ScrollingFrame")
    eggsScrollFrame.Name = "EggsScrollFrame"
    eggsScrollFrame.Size = UDim2.new(1, 0, 1, -50)
    eggsScrollFrame.Position = UDim2.new(0, 0, 0, 50)
    eggsScrollFrame.BackgroundTransparency = 1
    eggsScrollFrame.ScrollBarThickness = 6
    eggsScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
    eggsScrollFrame.ScrollBarImageTransparency = 0.5
    eggsScrollFrame.Parent = contentFrame
    
    local eggsListLayout = Instance.new("UIListLayout")
    eggsListLayout.Padding = UDim.new(0, 10)
    eggsListLayout.Parent = eggsScrollFrame
    
    -- Scroll Frame for Mutations
    local mutationsScrollFrame = Instance.new("ScrollingFrame")
    mutationsScrollFrame.Name = "MutationsScrollFrame"
    mutationsScrollFrame.Size = UDim2.new(1, 0, 1, -50)
    mutationsScrollFrame.Position = UDim2.new(0, 0, 0, 50)
    mutationsScrollFrame.BackgroundTransparency = 1
    mutationsScrollFrame.ScrollBarThickness = 6
    mutationsScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
    mutationsScrollFrame.ScrollBarImageTransparency = 0.5
    mutationsScrollFrame.Visible = false
    mutationsScrollFrame.Parent = contentFrame
    
    local mutationsListLayout = Instance.new("UIListLayout")
    mutationsListLayout.Padding = UDim.new(0, 10)
    mutationsListLayout.Parent = mutationsScrollFrame
    
    -- Control Buttons
    local controlFrame = Instance.new("Frame")
    controlFrame.Name = "ControlFrame"
    controlFrame.Size = UDim2.new(1, 0, 0, 50)
    controlFrame.Position = UDim2.new(0, 0, 1, -50)
    controlFrame.BackgroundTransparency = 1
    controlFrame.Parent = contentFrame
    
    local selectAllButton = Instance.new("TextButton")
    selectAllButton.Name = "SelectAllButton"
    selectAllButton.Size = UDim2.new(0.3, -5, 1, 0)
    selectAllButton.Position = UDim2.new(0, 0, 0, 0)
    selectAllButton.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
    selectAllButton.BackgroundTransparency = 0.2
    selectAllButton.BorderSizePixel = 0
    selectAllButton.Text = "Select All"
    selectAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectAllButton.TextScaled = true
    selectAllButton.Font = Enum.Font.GothamBold
    selectAllButton.Parent = controlFrame
    
    local selectAllCorner = Instance.new("UICorner")
    selectAllCorner.CornerRadius = UDim.new(0, 10)
    selectAllCorner.Parent = selectAllButton
    
    local clearAllButton = Instance.new("TextButton")
    clearAllButton.Name = "ClearAllButton"
    clearAllButton.Size = UDim2.new(0.3, -5, 1, 0)
    clearAllButton.Position = UDim2.new(0.35, 0, 0, 0)
    clearAllButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    clearAllButton.BackgroundTransparency = 0.2
    clearAllButton.BorderSizePixel = 0
    clearAllButton.Text = "Clear All"
    clearAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    clearAllButton.TextScaled = true
    clearAllButton.Font = Enum.Font.GothamBold
    clearAllButton.Parent = controlFrame
    
    local clearAllCorner = Instance.new("UICorner")
    clearAllCorner.CornerRadius = UDim.new(0, 10)
    clearAllCorner.Parent = clearAllButton
    
    local saveButton = Instance.new("TextButton")
    saveButton.Name = "SaveButton"
    saveButton.Size = UDim2.new(0.3, -5, 1, 0)
    saveButton.Position = UDim2.new(0.7, 5, 0, 0)
    saveButton.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    saveButton.BackgroundTransparency = 0.2
    saveButton.BorderSizePixel = 0
    saveButton.Text = "Save"
    saveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    saveButton.TextScaled = true
    saveButton.Font = Enum.Font.GothamBold
    saveButton.Parent = controlFrame
    
    local saveCorner = Instance.new("UICorner")
    saveCorner.CornerRadius = UDim.new(0, 10)
    saveCorner.Parent = saveButton
    
    EggSelectionUI.screenGui = screenGui
    EggSelectionUI.mainFrame = mainFrame
    EggSelectionUI.eggsScrollFrame = eggsScrollFrame
    EggSelectionUI.mutationsScrollFrame = mutationsScrollFrame
    EggSelectionUI.eggsTab = eggsTab
    EggSelectionUI.mutationsTab = mutationsTab
    
    return screenGui
end

-- Create Egg Item
local function createEggItem(eggId, eggData)
    local itemFrame = Instance.new("Frame")
    itemFrame.Name = eggId
    itemFrame.Size = UDim2.new(1, 0, 0, 60)
    itemFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    itemFrame.BackgroundTransparency = 0.1
    itemFrame.BorderSizePixel = 0
    itemFrame.Parent = EggSelectionUI.eggsScrollFrame
    
    local itemCorner = Instance.new("UICorner")
    itemCorner.CornerRadius = UDim.new(0, 10)
    itemCorner.Parent = itemFrame
    
    local itemStroke = Instance.new("UIStroke")
    itemStroke.Color = Color3.fromRGB(255, 255, 255)
    itemStroke.Transparency = 0.5
    itemStroke.Thickness = 1
    itemStroke.Parent = itemFrame
    
    -- Icon
    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "IconFrame"
    iconFrame.Size = UDim2.new(0, 50, 0, 50)
    iconFrame.Position = UDim2.new(0, 5, 0, 5)
    iconFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    iconFrame.BackgroundTransparency = 0.1
    iconFrame.BorderSizePixel = 0
    iconFrame.Parent = itemFrame
    
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 8)
    iconCorner.Parent = iconFrame
    
    local iconImage = Instance.new("ImageLabel")
    iconImage.Name = "Icon"
    iconImage.Size = UDim2.new(0.8, 0, 0.8, 0)
    iconImage.Position = UDim2.new(0.1, 0, 0.1, 0)
    iconImage.BackgroundTransparency = 1
    iconImage.Image = eggData.Icon
    iconImage.Parent = iconFrame
    
    -- Info
    local infoFrame = Instance.new("Frame")
    infoFrame.Name = "InfoFrame"
    infoFrame.Size = UDim2.new(1, -70, 1, 0)
    infoFrame.Position = UDim2.new(0, 60, 0, 0)
    infoFrame.BackgroundTransparency = 1
    infoFrame.Parent = itemFrame
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Position = UDim2.new(0, 10, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = eggData.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = infoFrame
    
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Name = "PriceLabel"
    priceLabel.Size = UDim2.new(1, 0, 0.5, 0)
    priceLabel.Position = UDim2.new(0, 10, 0.5, 0)
    priceLabel.BackgroundTransparency = 1
    priceLabel.Text = "$" .. eggData.Price
    priceLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    priceLabel.TextScaled = true
    priceLabel.Font = Enum.Font.Gotham
    priceLabel.Parent = infoFrame
    
    -- Toggle Button
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Size = UDim2.new(0, 30, 0, 30)
    toggleButton.Position = UDim2.new(1, -35, 0.5, -15)
    toggleButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.BackgroundTransparency = 0.2
    toggleButton.BorderSizePixel = 0
    toggleButton.Text = "☐"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.TextScaled = true
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.Parent = itemFrame
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = toggleButton
    
    -- Toggle functionality
    toggleButton.MouseButton1Click:Connect(function()
        if selectedEggs[eggId] then
            selectedEggs[eggId] = nil
            toggleButton.Text = "☐"
            toggleButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        else
            selectedEggs[eggId] = true
            toggleButton.Text = "☑"
            toggleButton.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
        end
        saveSettings()
    end)
    
    -- Set initial state
    if selectedEggs[eggId] then
        toggleButton.Text = "☑"
        toggleButton.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
    end
    
    return itemFrame
end

-- Create Mutation Item
local function createMutationItem(mutationId, mutationData)
    local itemFrame = Instance.new("Frame")
    itemFrame.Name = mutationId
    itemFrame.Size = UDim2.new(1, 0, 0, 60)
    itemFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    itemFrame.BackgroundTransparency = 0.1
    itemFrame.BorderSizePixel = 0
    itemFrame.Parent = EggSelectionUI.mutationsScrollFrame
    
    local itemCorner = Instance.new("UICorner")
    itemCorner.CornerRadius = UDim.new(0, 10)
    itemCorner.Parent = itemFrame
    
    local itemStroke = Instance.new("UIStroke")
    itemStroke.Color = mutationData.Color
    itemStroke.Transparency = 0.5
    itemStroke.Thickness = 2
    itemStroke.Parent = itemFrame
    
    -- Icon (using mutation color)
    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "IconFrame"
    iconFrame.Size = UDim2.new(0, 50, 0, 50)
    iconFrame.Position = UDim2.new(0, 5, 0, 5)
    iconFrame.BackgroundColor3 = mutationData.Color
    iconFrame.BackgroundTransparency = 0.2
    iconFrame.BorderSizePixel = 0
    iconFrame.Parent = itemFrame
    
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 8)
    iconCorner.Parent = iconFrame
    
    local iconText = Instance.new("TextLabel")
    iconText.Name = "Icon"
    iconText.Size = UDim2.new(1, 0, 1, 0)
    iconText.BackgroundTransparency = 1
    iconText.Text = "🧬"
    iconText.TextColor3 = Color3.fromRGB(255, 255, 255)
    iconText.TextScaled = true
    iconText.Font = Enum.Font.GothamBold
    iconText.Parent = iconFrame
    
    -- Info
    local infoFrame = Instance.new("Frame")
    infoFrame.Name = "InfoFrame"
    infoFrame.Size = UDim2.new(1, -70, 1, 0)
    infoFrame.Position = UDim2.new(0, 60, 0, 0)
    infoFrame.BackgroundTransparency = 1
    infoFrame.Parent = itemFrame
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Position = UDim2.new(0, 10, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = mutationData.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = infoFrame
    
    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Name = "RarityLabel"
    rarityLabel.Size = UDim2.new(1, 0, 0.5, 0)
    rarityLabel.Position = UDim2.new(0, 10, 0.5, 0)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text = "Rarity: " .. mutationData.Rarity
    rarityLabel.TextColor3 = mutationData.Color
    rarityLabel.TextScaled = true
    rarityLabel.Font = Enum.Font.Gotham
    rarityLabel.Parent = infoFrame
    
    -- Toggle Button
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Size = UDim2.new(0, 30, 0, 30)
    toggleButton.Position = UDim2.new(1, -35, 0.5, -15)
    toggleButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.BackgroundTransparency = 0.2
    toggleButton.BorderSizePixel = 0
    toggleButton.Text = "☐"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.TextScaled = true
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.Parent = itemFrame
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = toggleButton
    
    -- Toggle functionality
    toggleButton.MouseButton1Click:Connect(function()
        if selectedMutations[mutationId] then
            selectedMutations[mutationId] = nil
            toggleButton.Text = "☐"
            toggleButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        else
            selectedMutations[mutationId] = true
            toggleButton.Text = "☑"
            toggleButton.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
        end
        saveSettings()
    end)
    
    -- Set initial state
    if selectedMutations[mutationId] then
        toggleButton.Text = "☑"
        toggleButton.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
    end
    
    return itemFrame
end

-- Populate UI
local function populateUI()
    -- Clear existing items
    for _, child in pairs(EggSelectionUI.eggsScrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" then
            child:Destroy()
        end
    end
    
    for _, child in pairs(EggSelectionUI.mutationsScrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" then
            child:Destroy()
        end
    end
    
    -- Create egg items
    for eggId, eggData in pairs(EggData) do
        createEggItem(eggId, eggData)
    end
    
    -- Create mutation items
    for mutationId, mutationData in pairs(MutationData) do
        createMutationItem(mutationId, mutationData)
    end
end

-- Setup Event Handlers
local function setupEventHandlers()
    local mainFrame = EggSelectionUI.mainFrame
    local closeButton = mainFrame.TitleBar.CloseButton
    local minimizeButton = mainFrame.TitleBar.MinimizeButton
    local eggsTab = EggSelectionUI.eggsTab
    local mutationsTab = EggSelectionUI.mutationsTab
    local selectAllButton = mainFrame.ContentFrame.ControlFrame.SelectAllButton
    local clearAllButton = mainFrame.ContentFrame.ControlFrame.ClearAllButton
    local saveButton = mainFrame.ContentFrame.ControlFrame.SaveButton
    
    -- Close button
    closeButton.MouseButton1Click:Connect(function()
        isUIOpen = false
        mainFrame.Visible = false
        saveSettings()
    end)
    
    -- Minimize button
    minimizeButton.MouseButton1Click:Connect(function()
        if mainFrame.Size.Y.Offset > 100 then
            -- Minimize
            TweenService:Create(mainFrame, TweenInfo.new(0.3), {Size = UDim2.new(0, 500, 0, 100)}):Play()
            mainFrame.ContentFrame.Visible = false
        else
            -- Restore
            TweenService:Create(mainFrame, TweenInfo.new(0.3), {Size = UDim2.new(0, 500, 0, 400)}):Play()
            mainFrame.ContentFrame.Visible = true
        end
    end)
    
    -- Tab switching
    eggsTab.MouseButton1Click:Connect(function()
        eggsTab.BackgroundTransparency = 0.1
        mutationsTab.BackgroundTransparency = 0.3
        EggSelectionUI.eggsScrollFrame.Visible = true
        EggSelectionUI.mutationsScrollFrame.Visible = false
    end)
    
    mutationsTab.MouseButton1Click:Connect(function()
        mutationsTab.BackgroundTransparency = 0.1
        eggsTab.BackgroundTransparency = 0.3
        EggSelectionUI.mutationsScrollFrame.Visible = true
        EggSelectionUI.eggsScrollFrame.Visible = false
    end)
    
    -- Control buttons
    selectAllButton.MouseButton1Click:Connect(function()
        if EggSelectionUI.eggsScrollFrame.Visible then
            -- Select all eggs
            for eggId, _ in pairs(EggData) do
                selectedEggs[eggId] = true
            end
        else
            -- Select all mutations
            for mutationId, _ in pairs(MutationData) do
                selectedMutations[mutationId] = true
            end
        end
        populateUI()
        saveSettings()
    end)
    
    clearAllButton.MouseButton1Click:Connect(function()
        if EggSelectionUI.eggsScrollFrame.Visible then
            -- Clear all eggs
            selectedEggs = {}
        else
            -- Clear all mutations
            selectedMutations = {}
        end
        populateUI()
        saveSettings()
    end)
    
    saveButton.MouseButton1Click:Connect(function()
        saveSettings()
        -- Show save notification
        if _G.WindUI then
            _G.WindUI:Notify({
                Title = "💾 Settings Saved",
                Content = "Egg selection preferences saved successfully!",
                Duration = 3
            })
        end
    end)
    
    -- Dragging functionality
    local titleBar = mainFrame.TitleBar
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position - mainFrame.Position
        end
    end)
    
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
            mainFrame.Position = input.Position - dragStart
            uiPosition = mainFrame.Position
        end
    end)
end

-- Public API
local EggSelection = {}

function EggSelection:Toggle()
    if not EggSelectionUI.screenGui then
        -- Create UI for first time
        createMainFrame()
        loadSettings()
        populateUI()
        setupEventHandlers()
    end
    
    isUIOpen = not isUIOpen
    EggSelectionUI.mainFrame.Visible = isUIOpen
    
    if isUIOpen then
        -- Bring to front
        EggSelectionUI.screenGui.Parent = PlayerGui
    end
end

function EggSelection:GetSelectedEggs()
    return selectedEggs
end

function EggSelection:GetSelectedMutations()
    return selectedMutations
end

function EggSelection:IsOpen()
    return isUIOpen
end

function EggSelection:SetSelectedEggs(eggs)
    selectedEggs = eggs or {}
    if EggSelectionUI.eggsScrollFrame then
        populateUI()
    end
end

function EggSelection:SetSelectedMutations(mutations)
    selectedMutations = mutations or {}
    if EggSelectionUI.mutationsScrollFrame then
        populateUI()
    end
end

-- Auto-load settings on script start
loadSettings()

return EggSelection
