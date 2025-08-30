-- CustomSelectionUI.lua - Modern Tweened Selection Interface for Build A Zoo
-- Author: Zebux
-- Version: 1.0

local CustomSelectionUI = {}

-- Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- UI Configuration
local UIConfig = {
    -- Main frame settings
    MainFrameSize = UDim2.new(0, 800, 0, 600),
    MainFramePosition = UDim2.new(0.5, -400, 0.5, -300),
    
    -- Item settings
    ItemSize = UDim2.new(0, 120, 0, 140),
    ItemPadding = UDim2.new(0, 10, 0, 10),
    ItemsPerRow = 6,
    
    -- Tween settings
    TweenInfo = TweenInfo.new(
        0.3, -- Duration
        Enum.EasingStyle.Quint,
        Enum.EasingDirection.Out,
        0, -- RepeatCount
        false, -- Reverses
        0 -- DelayTime
    ),
    
    -- Animation settings
    HoverScale = 1.1,
    SelectedScale = 1.05,
    NormalScale = 1.0,
    
    -- Colors
    BackgroundColor = Color3.fromRGB(25, 25, 35),
    SelectedColor = Color3.fromRGB(0, 255, 127),
    HoverColor = Color3.fromRGB(100, 100, 120),
    NormalColor = Color3.fromRGB(60, 60, 70),
    TextColor = Color3.fromRGB(255, 255, 255),
    
    -- Effects
    CornerRadius = UDim.new(0, 12),
    StrokeThickness = 2,
    BackgroundTransparency = 0.1,
    ItemTransparency = 0.05
}

-- Active UI instances
local currentUI = nil
local currentType = nil -- "egg" or "fruit"
local isVisible = false

-- Data storage
local EggData = {}
local FruitData = {}
local MutationData = {}

-- Tween utilities
local function createTween(object, properties)
    return TweenService:Create(object, UIConfig.TweenInfo, properties)
end

local function animateIn(frame)
    frame.Size = UDim2.new(0, 0, 0, 0)
    frame.BackgroundTransparency = 1
    
    local sizeTween = createTween(frame, {
        Size = UIConfig.MainFrameSize,
        BackgroundTransparency = UIConfig.BackgroundTransparency
    })
    
    sizeTween:Play()
    return sizeTween
end

local function animateOut(frame, callback)
    local sizeTween = createTween(frame, {
        Size = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1
    })
    
    sizeTween.Completed:Connect(function()
        if callback then callback() end
    end)
    
    sizeTween:Play()
    return sizeTween
end

-- Item animation functions
local function animateItemHover(item, isHovering)
    local scale = isHovering and UIConfig.HoverScale or UIConfig.NormalScale
    local color = isHovering and UIConfig.HoverColor or UIConfig.NormalColor
    
    local scaleTween = createTween(item, {
        Size = UDim2.new(0, UIConfig.ItemSize.X.Offset * scale, 0, UIConfig.ItemSize.Y.Offset * scale)
    })
    
    local colorTween = createTween(item, {
        BackgroundColor3 = color
    })
    
    scaleTween:Play()
    colorTween:Play()
end

local function animateItemSelection(item, isSelected)
    local color = isSelected and UIConfig.SelectedColor or UIConfig.NormalColor
    local scale = isSelected and UIConfig.SelectedScale or UIConfig.NormalScale
    
    local colorTween = createTween(item, {
        BackgroundColor3 = color
    })
    
    local scaleTween = createTween(item, {
        Size = UDim2.new(0, UIConfig.ItemSize.X.Offset * scale, 0, UIConfig.ItemSize.Y.Offset * scale)
    })
    
    colorTween:Play()
    scaleTween:Play()
    
    -- Add ripple effect
    local ripple = Instance.new("Frame")
    ripple.Size = UDim2.new(0, 0, 0, 0)
    ripple.Position = UDim2.new(0.5, 0, 0.5, 0)
    ripple.AnchorPoint = Vector2.new(0.5, 0.5)
    ripple.BackgroundColor3 = UIConfig.SelectedColor
    ripple.BackgroundTransparency = 0.5
    ripple.BorderSizePixel = 0
    ripple.Parent = item
    
    local rippleCorner = Instance.new("UICorner")
    rippleCorner.CornerRadius = UIConfig.CornerRadius
    rippleCorner.Parent = ripple
    
    local rippleTween = createTween(ripple, {
        Size = UDim2.new(1, 20, 1, 20),
        BackgroundTransparency = 1
    })
    
    rippleTween.Completed:Connect(function()
        ripple:Destroy()
    end)
    
    rippleTween:Play()
end

-- Create UI elements
local function createMainFrame()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CustomSelectionUI"
    screenGui.Parent = CoreGui
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Background overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.Parent = screenGui
    
    -- Main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UIConfig.MainFrameSize
    mainFrame.Position = UIConfig.MainFramePosition
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = UIConfig.BackgroundColor
    mainFrame.BackgroundTransparency = UIConfig.BackgroundTransparency
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- Corner rounding
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UIConfig.CornerRadius
    corner.Parent = mainFrame
    
    -- Stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = UIConfig.SelectedColor
    stroke.Thickness = UIConfig.StrokeThickness
    stroke.Transparency = 0.3
    stroke.Parent = mainFrame
    
    return screenGui, mainFrame, overlay
end

local function createHeader(parent, title)
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 60)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundTransparency = 1
    header.Parent = parent
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -120, 1, 0)
    titleLabel.Position = UDim2.new(0, 20, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = UIConfig.TextColor
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = header
    
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 40, 0, 40)
    closeButton.Position = UDim2.new(1, -60, 0.5, -20)
    closeButton.AnchorPoint = Vector2.new(0, 0.5)
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeButton.BackgroundTransparency = 0.1
    closeButton.BorderSizePixel = 0
    closeButton.Text = "✕"
    closeButton.TextColor3 = UIConfig.TextColor
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = header
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeButton
    
    return header, closeButton
end

local function createScrollFrame(parent)
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, -40, 1, -120)
    scrollFrame.Position = UDim2.new(0, 20, 0, 80)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = UIConfig.SelectedColor
    scrollFrame.Parent = parent
    
    local layout = Instance.new("UIGridLayout")
    layout.CellSize = UIConfig.ItemSize
    layout.CellPadding = UIConfig.ItemPadding
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.SortOrder = Enum.SortOrder.Name
    layout.Parent = scrollFrame
    
    return scrollFrame, layout
end

local function createItemFrame(parent, itemData, isSelected, onToggle)
    local itemFrame = Instance.new("TextButton")
    itemFrame.Name = itemData.id
    itemFrame.Size = UIConfig.ItemSize
    itemFrame.BackgroundColor3 = isSelected and UIConfig.SelectedColor or UIConfig.NormalColor
    itemFrame.BackgroundTransparency = UIConfig.ItemTransparency
    itemFrame.BorderSizePixel = 0
    itemFrame.Text = ""
    itemFrame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UIConfig.CornerRadius
    corner.Parent = itemFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = isSelected and UIConfig.SelectedColor or UIConfig.NormalColor
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = itemFrame
    
    -- Item icon
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 80, 0, 80)
    icon.Position = UDim2.new(0.5, -40, 0, 10)
    icon.BackgroundTransparency = 1
    icon.Image = itemData.image or ""
    icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
    icon.Parent = itemFrame
    
    -- Item name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -10, 0, 40)
    nameLabel.Position = UDim2.new(0, 5, 1, -45)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = itemData.name or itemData.id
    nameLabel.TextColor3 = UIConfig.TextColor
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextWrapped = true
    nameLabel.Parent = itemFrame
    
    -- Selection indicator
    local indicator = Instance.new("Frame")
    indicator.Name = "Indicator"
    indicator.Size = UDim2.new(0, 20, 0, 20)
    indicator.Position = UDim2.new(1, -25, 0, 5)
    indicator.BackgroundColor3 = UIConfig.SelectedColor
    indicator.BackgroundTransparency = isSelected and 0 or 1
    indicator.BorderSizePixel = 0
    indicator.Parent = itemFrame
    
    local indicatorCorner = Instance.new("UICorner")
    indicatorCorner.CornerRadius = UDim.new(0.5, 0)
    indicatorCorner.Parent = indicator
    
    local checkmark = Instance.new("TextLabel")
    checkmark.Size = UDim2.new(1, 0, 1, 0)
    checkmark.BackgroundTransparency = 1
    checkmark.Text = "✓"
    checkmark.TextColor3 = Color3.fromRGB(255, 255, 255)
    checkmark.TextScaled = true
    checkmark.Font = Enum.Font.GothamBold
    checkmark.Parent = indicator
    
    -- Event handlers
    itemFrame.MouseEnter:Connect(function()
        animateItemHover(itemFrame, true)
    end)
    
    itemFrame.MouseLeave:Connect(function()
        animateItemHover(itemFrame, false)
    end)
    
    itemFrame.MouseButton1Click:Connect(function()
        local newSelected = not isSelected
        isSelected = newSelected
        
        animateItemSelection(itemFrame, isSelected)
        
        -- Update indicator
        local indicatorTween = createTween(indicator, {
            BackgroundTransparency = isSelected and 0 or 1
        })
        indicatorTween:Play()
        
        -- Update stroke
        local strokeTween = createTween(stroke, {
            Color = isSelected and UIConfig.SelectedColor or UIConfig.NormalColor
        })
        strokeTween:Play()
        
        if onToggle then
            onToggle(itemData.id, isSelected)
        end
    end)
    
    return itemFrame
end

-- Public API
function CustomSelectionUI.ShowEggSelection(onSelectionChange, onVisibilityChange, currentSelections)
    if isVisible then
        CustomSelectionUI.Hide()
        return
    end
    
    currentType = "egg"
    local selections = currentSelections or {}
    
    local screenGui, mainFrame, overlay = createMainFrame()
    local header, closeButton = createHeader(mainFrame, "🥚 Egg Selection")
    local scrollFrame, layout = createScrollFrame(mainFrame)
    
    currentUI = screenGui
    isVisible = true
    
    -- Load egg data and create items
    for eggId, eggData in pairs(EggData) do
        local isSelected = selections[eggId] or false
        createItemFrame(scrollFrame, {
            id = eggId,
            name = eggData.name or eggId,
            image = eggData.image
        }, isSelected, function(id, selected)
            selections[id] = selected or nil
            if onSelectionChange then
                onSelectionChange(selections)
            end
        end)
    end
    
    -- Add mutations
    for mutationId, mutationData in pairs(MutationData) do
        local isSelected = selections[mutationId] or false
        createItemFrame(scrollFrame, {
            id = mutationId,
            name = mutationData.name or mutationId,
            image = mutationData.image
        }, isSelected, function(id, selected)
            selections[id] = selected or nil
            if onSelectionChange then
                onSelectionChange(selections)
            end
        end)
    end
    
    -- Update scroll canvas size
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    
    -- Close button event
    closeButton.MouseButton1Click:Connect(function()
        CustomSelectionUI.Hide()
    end)
    
    -- Close on overlay click
    overlay.MouseButton1Click:Connect(function()
        CustomSelectionUI.Hide()
    end)
    
    -- Animate in
    animateIn(mainFrame)
    
    if onVisibilityChange then
        onVisibilityChange(true)
    end
end

function CustomSelectionUI.ShowFruitSelection(onSelectionChange, onVisibilityChange, currentSelections)
    if isVisible then
        CustomSelectionUI.Hide()
        return
    end
    
    currentType = "fruit"
    local selections = currentSelections or {}
    
    local screenGui, mainFrame, overlay = createMainFrame()
    local header, closeButton = createHeader(mainFrame, "🍎 Fruit Selection")
    local scrollFrame, layout = createScrollFrame(mainFrame)
    
    currentUI = screenGui
    isVisible = true
    
    -- Load fruit data and create items
    for fruitId, fruitData in pairs(FruitData) do
        local isSelected = selections[fruitId] or false
        createItemFrame(scrollFrame, {
            id = fruitId,
            name = fruitData.name or fruitId,
            image = fruitData.image
        }, isSelected, function(id, selected)
            selections[id] = selected or nil
            if onSelectionChange then
                onSelectionChange(selections)
            end
        end)
    end
    
    -- Update scroll canvas size
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    
    -- Close button event
    closeButton.MouseButton1Click:Connect(function()
        CustomSelectionUI.Hide()
    end)
    
    -- Close on overlay click
    overlay.MouseButton1Click:Connect(function()
        CustomSelectionUI.Hide()
    end)
    
    -- Animate in
    animateIn(mainFrame)
    
    if onVisibilityChange then
        onVisibilityChange(true)
    end
end

function CustomSelectionUI.Hide()
    if not isVisible or not currentUI then return end
    
    local mainFrame = currentUI:FindFirstChild("MainFrame")
    if mainFrame then
        animateOut(mainFrame, function()
            if currentUI then
                currentUI:Destroy()
                currentUI = nil
            end
        end)
    else
        if currentUI then
            currentUI:Destroy()
            currentUI = nil
        end
    end
    
    isVisible = false
    currentType = nil
end

function CustomSelectionUI.IsVisible()
    return isVisible
end

function CustomSelectionUI.SetEggData(data)
    EggData = data or {}
end

function CustomSelectionUI.SetFruitData(data)
    FruitData = data or {}
end

function CustomSelectionUI.SetMutationData(data)
    MutationData = data or {}
end

function CustomSelectionUI.UpdateUIConfig(config)
    for key, value in pairs(config) do
        UIConfig[key] = value
    end
end

return CustomSelectionUI
