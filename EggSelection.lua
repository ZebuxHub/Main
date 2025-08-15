-- EggSelection.lua - Lightweight Egg Selection UI
-- Matches rustic parchment style from the game UI
-- Hardcoded data instead of module scripts

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Hardcoded Egg Data (Name, Price, Icon)
local EGG_DATA = {
    {
        Name = "Basic Egg",
        Price = "100",
        Icon = "rbxassetid://129248801621928",
        Rarity = 1
    },
    {
        Name = "Rare Egg", 
        Price = "500",
        Icon = "rbxassetid://71012831091414",
        Rarity = 2
    },
    {
        Name = "Super Rare Egg",
        Price = "2,500", 
        Icon = "rbxassetid://93845452154351",
        Rarity = 2
    },
    {
        Name = "Epic Egg",
        Price = "15,000",
        Icon = "rbxassetid://116395645531721", 
        Rarity = 2
    },
    {
        Name = "Legend Egg",
        Price = "100,000",
        Icon = "rbxassetid://90834918351014",
        Rarity = 3
    },
    {
        Name = "Prismatic Egg", 
        Price = "1,000,000",
        Icon = "rbxassetid://79960683434582",
        Rarity = 4
    },
    {
        Name = "Hyper Egg",
        Price = "3,000,000", 
        Icon = "rbxassetid://104958288296273",
        Rarity = 5
    },
    {
        Name = "Void Egg",
        Price = "24,000,000",
        Icon = "rbxassetid://122396162708984",
        Rarity = 5
    },
    {
        Name = "Bowser Egg",
        Price = "130,000,000", 
        Icon = "rbxassetid://71500536051510",
        Rarity = 5
    },
    {
        Name = "Demon Egg",
        Price = "400,000,000",
        Icon = "rbxassetid://126412407639969",
        Rarity = 5
    },
    {
        Name = "Bone Dragon Egg",
        Price = "2,000,000,000",
        Icon = "rbxassetid://83209913424562", 
        Rarity = 5
    },
    {
        Name = "Ultra Egg",
        Price = "10,000,000,000",
        Icon = "rbxassetid://83909590718799",
        Rarity = 6
    },
    {
        Name = "Dino Egg", 
        Price = "10,000,000,000",
        Icon = "rbxassetid://80783528632315",
        Rarity = 6
    },
    {
        Name = "Fly Egg",
        Price = "999,999,999,999", 
        Icon = "rbxassetid://109240587278187",
        Rarity = 6
    },
    {
        Name = "Unicorn Egg",
        Price = "40,000,000,000",
        Icon = "rbxassetid://123427249205445",
        Rarity = 6
    },
    {
        Name = "Ancient Egg",
        Price = "999,999,999,999",
        Icon = "rbxassetid://113910587565739",
        Rarity = 6
    }
}

-- Hardcoded Mutation Data
local MUTATION_DATA = {
    {
        Name = "Golden",
        Color = Color3.fromHex("#ffc518"),
        Rarity = 10
    },
    {
        Name = "Diamond", 
        Color = Color3.fromHex("#07e6ff"),
        Rarity = 20
    },
    {
        Name = "Electric",
        Color = Color3.fromHex("#aa55ff"), 
        Rarity = 50
    },
    {
        Name = "Fire",
        Color = Color3.fromHex("#ff3d02"),
        Rarity = 100
    },
    {
        Name = "Jurassic", -- Maps to Dino
        Color = Color3.fromHex("#AE75E7"),
        Rarity = 100
    }
}

-- Rarity Colors
local RARITY_COLORS = {
    [1] = Color3.fromRGB(200, 200, 200), -- Common (Gray)
    [2] = Color3.fromRGB(0, 255, 0),     -- Uncommon (Green) 
    [3] = Color3.fromRGB(0, 100, 255),   -- Rare (Blue)
    [4] = Color3.fromRGB(255, 0, 255),   -- Epic (Purple)
    [5] = Color3.fromRGB(255, 165, 0),   -- Legendary (Orange)
    [6] = Color3.fromRGB(255, 0, 0)      -- Mythic (Red)
}

-- UI State
local selectedEggs = {}
local selectedMutations = {}
local isDragging = false
local dragStart = Vector2.new()
local uiPosition = Vector2.new(100, 100)
local isMinimized = false

-- Create Main UI
local function createEggSelectionUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EggSelectionUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = PlayerGui

    -- Main Frame (Parchment Style)
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 400, 0, 500)
    mainFrame.Position = UDim2.new(0, uiPosition.X, 0, uiPosition.Y)
    mainFrame.BackgroundColor3 = Color3.fromRGB(245, 235, 215) -- Parchment color
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    -- Parchment Border
    local border = Instance.new("Frame")
    border.Name = "Border"
    border.Size = UDim2.new(1, 0, 1, 0)
    border.Position = UDim2.new(0, 0, 0, 0)
    border.BackgroundColor3 = Color3.fromRGB(139, 69, 19) -- Dark brown border
    border.BorderSizePixel = 0
    border.Parent = mainFrame

    local innerFrame = Instance.new("Frame")
    innerFrame.Name = "InnerFrame"
    innerFrame.Size = UDim2.new(1, -4, 1, -4)
    innerFrame.Position = UDim2.new(0, 2, 0, 2)
    innerFrame.BackgroundColor3 = Color3.fromRGB(245, 235, 215)
    innerFrame.BorderSizePixel = 0
    innerFrame.Parent = border

    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(139, 69, 19)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = innerFrame

    local titleText = Instance.new("TextLabel")
    titleText.Name = "TitleText"
    titleText.Size = UDim2.new(1, -80, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "EGG SELECTION"
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.TextScaled = true
    titleText.Font = Enum.Font.GothamBold
    titleText.Parent = titleBar

    -- Control Buttons
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Name = "MinimizeBtn"
    minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
    minimizeBtn.Position = UDim2.new(1, -70, 0, 5)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(160, 82, 45)
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Text = "−"
    minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeBtn.TextScaled = true
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(220, 20, 60)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextScaled = true
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar

    -- Content Area
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -20, 1, -50)
    contentFrame.Position = UDim2.new(0, 10, 0, 40)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = innerFrame

    -- Tabs
    local tabFrame = Instance.new("Frame")
    tabFrame.Name = "TabFrame"
    tabFrame.Size = UDim2.new(1, 0, 0, 40)
    tabFrame.Position = UDim2.new(0, 0, 0, 0)
    tabFrame.BackgroundColor3 = Color3.fromRGB(160, 82, 45)
    tabFrame.BorderSizePixel = 0
    tabFrame.Parent = contentFrame

    local eggsTab = Instance.new("TextButton")
    eggsTab.Name = "EggsTab"
    eggsTab.Size = UDim2.new(0.5, 0, 1, 0)
    eggsTab.Position = UDim2.new(0, 0, 0, 0)
    eggsTab.BackgroundColor3 = Color3.fromRGB(139, 69, 19)
    eggsTab.BorderSizePixel = 0
    eggsTab.Text = "EGGS"
    eggsTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    eggsTab.TextScaled = true
    eggsTab.Font = Enum.Font.GothamBold
    eggsTab.Parent = tabFrame

    local mutationsTab = Instance.new("TextButton")
    mutationsTab.Name = "MutationsTab"
    mutationsTab.Size = UDim2.new(0.5, 0, 1, 0)
    mutationsTab.Position = UDim2.new(0.5, 0, 0, 0)
    mutationsTab.BackgroundColor3 = Color3.fromRGB(160, 82, 45)
    mutationsTab.BorderSizePixel = 0
    mutationsTab.Text = "MUTATIONS"
    mutationsTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    mutationsTab.TextScaled = true
    mutationsTab.Font = Enum.Font.GothamBold
    mutationsTab.Parent = tabFrame

    -- Scroll Frame for Items
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, 0, 1, -50)
    scrollFrame.Position = UDim2.new(0, 0, 0, 40)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(139, 69, 19)
    scrollFrame.Parent = contentFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Parent = scrollFrame
    listLayout.Padding = UDim.new(0, 5)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Create Egg Items
    for i, eggData in ipairs(EGG_DATA) do
        local eggItem = Instance.new("Frame")
        eggItem.Name = eggData.Name
        eggItem.Size = UDim2.new(1, 0, 0, 60)
        eggItem.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
        eggItem.BorderSizePixel = 0
        eggItem.Parent = scrollFrame

        local eggBorder = Instance.new("Frame")
        eggBorder.Name = "Border"
        eggBorder.Size = UDim2.new(1, 0, 1, 0)
        eggBorder.Position = UDim2.new(0, 0, 0, 0)
        eggBorder.BackgroundColor3 = RARITY_COLORS[eggData.Rarity]
        eggBorder.BorderSizePixel = 0
        eggBorder.Parent = eggItem

        local eggInner = Instance.new("Frame")
        eggInner.Name = "Inner"
        eggInner.Size = UDim2.new(1, -2, 1, -2)
        eggInner.Position = UDim2.new(0, 1, 0, 1)
        eggInner.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
        eggInner.BorderSizePixel = 0
        eggInner.Parent = eggBorder

        local eggIcon = Instance.new("ImageLabel")
        eggIcon.Name = "Icon"
        eggIcon.Size = UDim2.new(0, 50, 0, 50)
        eggIcon.Position = UDim2.new(0, 5, 0, 5)
        eggIcon.BackgroundTransparency = 1
        eggIcon.Image = eggData.Icon
        eggIcon.Parent = eggInner

        local eggName = Instance.new("TextLabel")
        eggName.Name = "Name"
        eggName.Size = UDim2.new(1, -120, 0.5, 0)
        eggName.Position = UDim2.new(0, 60, 0, 5)
        eggName.BackgroundTransparency = 1
        eggName.Text = eggData.Name
        eggName.TextColor3 = Color3.fromRGB(0, 0, 0)
        eggName.TextScaled = true
        eggName.Font = Enum.Font.GothamBold
        eggName.Parent = eggInner

        local eggPrice = Instance.new("TextLabel")
        eggPrice.Name = "Price"
        eggPrice.Size = UDim2.new(1, -120, 0.5, 0)
        eggPrice.Position = UDim2.new(0, 60, 0.5, 0)
        eggPrice.BackgroundTransparency = 1
        eggPrice.Text = "$" .. eggData.Price
        eggPrice.TextColor3 = Color3.fromRGB(0, 100, 0)
        eggPrice.TextScaled = true
        eggPrice.Font = Enum.Font.Gotham
        eggPrice.Parent = eggInner

        local selectBtn = Instance.new("TextButton")
        selectBtn.Name = "SelectBtn"
        selectBtn.Size = UDim2.new(0, 80, 0, 30)
        selectBtn.Position = UDim2.new(1, -85, 0.5, -15)
        selectBtn.BackgroundColor3 = Color3.fromRGB(139, 69, 19)
        selectBtn.BorderSizePixel = 0
        selectBtn.Text = "SELECT"
        selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        selectBtn.TextScaled = true
        selectBtn.Font = Enum.Font.GothamBold
        selectBtn.Parent = eggInner

        -- Selection Logic
        selectBtn.MouseButton1Click:Connect(function()
            if selectedEggs[eggData.Name] then
                selectedEggs[eggData.Name] = nil
                selectBtn.Text = "SELECT"
                selectBtn.BackgroundColor3 = Color3.fromRGB(139, 69, 19)
            else
                selectedEggs[eggData.Name] = true
                selectBtn.Text = "SELECTED"
                selectBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
            end
        end)
    end

    -- Dragging Logic
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position - mainFrame.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
            mainFrame.Position = UDim2.new(0, input.Position.X - dragStart.X, 0, input.Position.Y - dragStart.Y)
            uiPosition = Vector2.new(mainFrame.Position.X.Offset, mainFrame.Position.Y.Offset)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)

    -- Control Button Logic
    minimizeBtn.MouseButton1Click:Connect(function()
        if isMinimized then
            contentFrame.Visible = true
            mainFrame.Size = UDim2.new(0, 400, 0, 500)
            isMinimized = false
        else
            contentFrame.Visible = false
            mainFrame.Size = UDim2.new(0, 400, 0, 40)
            isMinimized = true
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- Tab Switching Logic
    eggsTab.MouseButton1Click:Connect(function()
        eggsTab.BackgroundColor3 = Color3.fromRGB(139, 69, 19)
        mutationsTab.BackgroundColor3 = Color3.fromRGB(160, 82, 45)
        -- Show eggs content
    end)

    mutationsTab.MouseButton1Click:Connect(function()
        mutationsTab.BackgroundColor3 = Color3.fromRGB(139, 69, 19)
        eggsTab.BackgroundColor3 = Color3.fromRGB(160, 82, 45)
        -- Show mutations content
    end)

    return screenGui
end

-- Save/Load Functions
local function saveSelection()
    local data = {
        selectedEggs = selectedEggs,
        selectedMutations = selectedMutations,
        uiPosition = uiPosition,
        isMinimized = isMinimized
    }
    
    local success, result = pcall(function()
        writefile("EggSelection_Config.json", game:GetService("HttpService"):JSONEncode(data))
    end)
    
    return success
end

local function loadSelection()
    local success, result = pcall(function()
        local data = game:GetService("HttpService"):JSONDecode(readfile("EggSelection_Config.json"))
        selectedEggs = data.selectedEggs or {}
        selectedMutations = data.selectedMutations or {}
        uiPosition = data.uiPosition or Vector2.new(100, 100)
        isMinimized = data.isMinimized or false
        return true
    end)
    
    return success
end

-- Public API
local EggSelection = {}

function EggSelection:Create()
    -- Load saved data
    loadSelection()
    
    -- Create UI
    local ui = createEggSelectionUI()
    
    -- Auto-save every 30 seconds
    spawn(function()
        while ui and ui.Parent do
            wait(30)
            saveSelection()
        end
    end)
    
    return ui
end

function EggSelection:GetSelectedEggs()
    local eggs = {}
    for eggName, _ in pairs(selectedEggs) do
        table.insert(eggs, eggName)
    end
    return eggs
end

function EggSelection:GetSelectedMutations()
    local mutations = {}
    for mutationName, _ in pairs(selectedMutations) do
        table.insert(mutations, mutationName)
    end
    return mutations
end

function EggSelection:Save()
    return saveSelection()
end

function EggSelection:Load()
    return loadSelection()
end

return EggSelection
