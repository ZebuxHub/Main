-- EggSelection.lua - Modern Glass UI for Egg Selection
-- Author: Zebux
-- Version: 1.0

local EggSelection = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Hardcoded data (no more module scripts)
local EggData = {
    BasicEgg = {
        Name = "Basic Egg",
        Price = "100",
        Icon = "🥚",
        Rarity = 1
    },
    RareEgg = {
        Name = "Rare Egg", 
        Price = "500",
        Icon = "🥚",
        Rarity = 2
    },
    SuperRareEgg = {
        Name = "Super Rare Egg",
        Price = "2,500", 
        Icon = "🥚",
        Rarity = 2
    },
    EpicEgg = {
        Name = "Epic Egg",
        Price = "15,000",
        Icon = "🥚", 
        Rarity = 2
    },
    LegendEgg = {
        Name = "Legend Egg",
        Price = "100,000",
        Icon = "🥚",
        Rarity = 3
    },
    PrismaticEgg = {
        Name = "Prismatic Egg", 
        Price = "1,000,000",
        Icon = "🥚",
        Rarity = 4
    },
    HyperEgg = {
        Name = "Hyper Egg",
        Price = "3,000,000",
        Icon = "🥚",
        Rarity = 5
    },
    VoidEgg = {
        Name = "Void Egg",
        Price = "24,000,000", 
        Icon = "🥚",
        Rarity = 5
    },
    BowserEgg = {
        Name = "Bowser Egg",
        Price = "130,000,000",
        Icon = "🥚",
        Rarity = 5
    },
    DemonEgg = {
        Name = "Demon Egg",
        Price = "400,000,000",
        Icon = "🥚",
        Rarity = 5
    },
    BoneDragonEgg = {
        Name = "Bone Dragon Egg",
        Price = "2,000,000,000",
        Icon = "🥚",
        Rarity = 5
    },
    UltraEgg = {
        Name = "Ultra Egg",
        Price = "10,000,000,000",
        Icon = "🥚",
        Rarity = 6
    },
    DinoEgg = {
        Name = "Dino Egg",
        Price = "10,000,000,000",
        Icon = "🥚",
        Rarity = 6
    },
    FlyEgg = {
        Name = "Fly Egg",
        Price = "999,999,999,999",
        Icon = "🥚",
        Rarity = 6
    },
    UnicornEgg = {
        Name = "Unicorn Egg",
        Price = "40,000,000,000",
        Icon = "🥚",
        Rarity = 6
    },
    AncientEgg = {
        Name = "Ancient Egg",
        Price = "999,999,999,999",
        Icon = "🥚",
        Rarity = 6
    }
}

local MutationData = {
    Golden = {
        Name = "Golden",
        Price = "Premium",
        Icon = "✨",
        Rarity = 10
    },
    Diamond = {
        Name = "Diamond",
        Price = "Premium", 
        Icon = "💎",
        Rarity = 20
    },
    Electirc = {
        Name = "Electric",
        Price = "Premium",
        Icon = "⚡",
        Rarity = 50
    },
    Fire = {
        Name = "Fire",
        Price = "Premium",
        Icon = "🔥",
        Rarity = 100
    },
    Dino = {
        Name = "Jurassic",
        Price = "Premium",
        Icon = "🦕",
        Rarity = 100
    }
}

-- UI Variables
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ScreenGui = nil
local MainFrame = nil
local selectedItems = {}
local isDragging = false
local dragStart = nil
local startPos = nil
local isMinimized = false
local originalSize = nil
local minimizedSize = nil

-- Callback functions
local onSelectionChanged = nil
local onToggleChanged = nil

-- Colors
local colors = {
    background = Color3.fromRGB(20, 20, 25),
    glass = Color3.fromRGB(30, 30, 35),
    accent = Color3.fromRGB(100, 150, 255),
    text = Color3.fromRGB(255, 255, 255),
    textSecondary = Color3.fromRGB(180, 180, 180),
    border = Color3.fromRGB(60, 60, 70),
    selected = Color3.fromRGB(100, 150, 255),
    hover = Color3.fromRGB(40, 40, 45)
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
    if rarity >= 100 then return Color3.fromRGB(255, 61, 2) -- Fire
    elseif rarity >= 50 then return Color3.fromRGB(170, 85, 255) -- Electric
    elseif rarity >= 20 then return Color3.fromRGB(7, 230, 255) -- Diamond
    elseif rarity >= 10 then return Color3.fromRGB(255, 197, 24) -- Golden
    elseif rarity >= 6 then return Color3.fromRGB(255, 0, 255) -- Ultra
    elseif rarity >= 5 then return Color3.fromRGB(255, 0, 0) -- Legendary
    elseif rarity >= 4 then return Color3.fromRGB(255, 0, 255) -- Epic
    elseif rarity >= 3 then return Color3.fromRGB(0, 255, 255) -- Rare
    elseif rarity >= 2 then return Color3.fromRGB(0, 255, 0) -- Uncommon
    else return Color3.fromRGB(255, 255, 255) -- Common
    end
end

-- Create Glass Effect
local function createGlassEffect(parent)
    local glass = Instance.new("Frame")
    glass.Name = "Glass"
    glass.BackgroundColor3 = colors.glass
    glass.BorderSizePixel = 0
    glass.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = glass
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = glass
    
    local transparency = Instance.new("UIGradient")
    transparency.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255, 0.1)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255, 0.05))
    })
    transparency.Parent = glass
    
    return glass
end

-- Create Item Button
local function createItemButton(itemId, itemData, parent)
    local button = Instance.new("TextButton")
    button.Name = itemId
    button.Size = UDim2.new(1, 0, 0, 50)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.Parent = parent
    
    local glass = createGlassEffect(button)
    glass.Size = UDim2.new(1, -4, 1, -4)
    glass.Position = UDim2.new(0, 2, 0, 2)
    
    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 40, 1, 0)
    icon.Position = UDim2.new(0, 8, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text = itemData.Icon
    icon.TextSize = 24
    icon.Font = Enum.Font.GothamBold
    icon.TextColor3 = getRarityColor(itemData.Rarity)
    icon.Parent = button
    
    local name = Instance.new("TextLabel")
    name.Name = "Name"
    name.Size = UDim2.new(1, -120, 0.5, 0)
    name.Position = UDim2.new(0, 56, 0, 0)
    name.BackgroundTransparency = 1
    name.Text = itemData.Name
    name.TextSize = 14
    name.Font = Enum.Font.GothamSemibold
    name.TextColor3 = colors.text
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Parent = button
    
    local price = Instance.new("TextLabel")
    price.Name = "Price"
    price.Size = UDim2.new(1, -120, 0.5, 0)
    price.Position = UDim2.new(0, 56, 0.5, 0)
    price.BackgroundTransparency = 1
    price.Text = "$" .. itemData.Price
    price.TextSize = 12
    price.Font = Enum.Font.Gotham
    price.TextColor3 = colors.textSecondary
    price.TextXAlignment = Enum.TextXAlignment.Left
    price.Parent = button
    
    local checkmark = Instance.new("TextLabel")
    checkmark.Name = "Checkmark"
    checkmark.Size = UDim2.new(0, 20, 0, 20)
    checkmark.Position = UDim2.new(1, -28, 0.5, -10)
    checkmark.BackgroundTransparency = 1
    checkmark.Text = "✓"
    checkmark.TextSize = 16
    checkmark.Font = Enum.Font.GothamBold
    checkmark.TextColor3 = colors.selected
    checkmark.Visible = false
    checkmark.Parent = button
    
    -- Hover effect
    button.MouseEnter:Connect(function()
        if not selectedItems[itemId] then
            TweenService:Create(glass, TweenInfo.new(0.2), {BackgroundColor3 = colors.hover}):Play()
        end
    end)
    
    button.MouseLeave:Connect(function()
        if not selectedItems[itemId] then
            TweenService:Create(glass, TweenInfo.new(0.2), {BackgroundColor3 = colors.glass}):Play()
        end
    end)
    
    -- Click effect
    button.MouseButton1Click:Connect(function()
        if selectedItems[itemId] then
            selectedItems[itemId] = nil
            checkmark.Visible = false
            TweenService:Create(glass, TweenInfo.new(0.2), {BackgroundColor3 = colors.glass}):Play()
        else
            selectedItems[itemId] = true
            checkmark.Visible = true
            TweenService:Create(glass, TweenInfo.new(0.2), {BackgroundColor3 = colors.selected}):Play()
        end
        
        if onSelectionChanged then
            onSelectionChanged(selectedItems)
        end
    end)
    
    return button
end

-- Create UI
function EggSelection.CreateUI()
    if ScreenGui then
        ScreenGui:Destroy()
    end
    
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "EggSelectionUI"
    ScreenGui.Parent = PlayerGui
    
    MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 350, 0, 500)
    MainFrame.Position = UDim2.new(0.5, -175, 0.5, -250)
    MainFrame.BackgroundTransparency = 1
    MainFrame.Parent = ScreenGui
    
    originalSize = MainFrame.Size
    minimizedSize = UDim2.new(0, 350, 0, 60)
    
    local mainGlass = createGlassEffect(MainFrame)
    mainGlass.Size = UDim2.new(1, 0, 1, 0)
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundTransparency = 1
    titleBar.Parent = MainFrame
    
    local titleGlass = createGlassEffect(titleBar)
    titleGlass.Size = UDim2.new(1, 0, 1, 0)
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🥚 Egg Selection"
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = colors.text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Control Buttons
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Name = "MinimizeBtn"
    minimizeBtn.Size = UDim2.new(0, 20, 0, 20)
    minimizeBtn.Position = UDim2.new(1, -50, 0.5, -10)
    minimizeBtn.BackgroundTransparency = 1
    minimizeBtn.Text = "−"
    minimizeBtn.TextSize = 16
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextColor3 = colors.text
    minimizeBtn.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -25, 0.5, -10)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "×"
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.Parent = titleBar
    
    -- Content Area
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -16, 1, -56)
    content.Position = UDim2.new(0, 8, 0, 48)
    content.BackgroundTransparency = 1
    content.Parent = MainFrame
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = colors.accent
    scrollFrame.Parent = content
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.Name
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = scrollFrame
    
    -- Add Eggs
    local eggSection = Instance.new("TextLabel")
    eggSection.Name = "EggSection"
    eggSection.Size = UDim2.new(1, 0, 0, 30)
    eggSection.BackgroundTransparency = 1
    eggSection.Text = "🥚 EGGS"
    eggSection.TextSize = 14
    eggSection.Font = Enum.Font.GothamBold
    eggSection.TextColor3 = colors.accent
    eggSection.TextXAlignment = Enum.TextXAlignment.Left
    eggSection.Parent = scrollFrame
    
    for eggId, eggData in pairs(EggData) do
        createItemButton(eggId, eggData, scrollFrame)
    end
    
    -- Add Mutations
    local mutationSection = Instance.new("TextLabel")
    mutationSection.Name = "MutationSection"
    mutationSection.Size = UDim2.new(1, 0, 0, 30)
    mutationSection.BackgroundTransparency = 1
    mutationSection.Text = "✨ MUTATIONS"
    mutationSection.TextSize = 14
    mutationSection.Font = Enum.Font.GothamBold
    mutationSection.TextColor3 = colors.accent
    mutationSection.TextXAlignment = Enum.TextXAlignment.Left
    mutationSection.Parent = scrollFrame
    
    for mutationId, mutationData in pairs(MutationData) do
        createItemButton(mutationId, mutationData, scrollFrame)
    end
    
    -- Control Button Events
    minimizeBtn.MouseButton1Click:Connect(function()
        if isMinimized then
            MainFrame.Size = originalSize
            content.Visible = true
            isMinimized = false
        else
            MainFrame.Size = minimizedSize
            content.Visible = false
            isMinimized = true
        end
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        if onToggleChanged then
            onToggleChanged(false)
        end
        ScreenGui:Destroy()
        ScreenGui = nil
    end)
    
    -- Dragging
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)
    
    return ScreenGui
end

-- Public Functions
function EggSelection.Show(callback, toggleCallback)
    onSelectionChanged = callback
    onToggleChanged = toggleCallback
    
    if not ScreenGui then
        EggSelection.CreateUI()
    end
    
    ScreenGui.Enabled = true
    ScreenGui.Parent = PlayerGui
end

function EggSelection.Hide()
    if ScreenGui then
        ScreenGui.Enabled = false
    end
end

function EggSelection.GetSelectedItems()
    return selectedItems
end

function EggSelection.SetSelectedItems(items)
    selectedItems = items or {}
    
    if ScreenGui then
        local scrollFrame = ScreenGui.MainFrame.Content.ScrollFrame
        for _, child in pairs(scrollFrame:GetChildren()) do
            if child:IsA("TextButton") then
                local checkmark = child:FindFirstChild("Checkmark")
                local glass = child:FindFirstChild("Glass")
                if checkmark and glass then
                    if selectedItems[child.Name] then
                        checkmark.Visible = true
                        glass.BackgroundColor3 = colors.selected
                    else
                        checkmark.Visible = false
                        glass.BackgroundColor3 = colors.glass
                    end
                end
            end
        end
    end
end

function EggSelection.IsVisible()
    return ScreenGui and ScreenGui.Enabled
end

return EggSelection
