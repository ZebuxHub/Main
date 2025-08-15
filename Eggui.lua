-- Custom Egg Selection UI for Build A Zoo
-- Replaces dropdown with visual egg selection interface

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Egg data from ResEgg
local eggData = {
    BasicEgg = {
        Name = "Basic Egg",
        Price = "100",
        Icon = "rbxassetid://129248801621928",
        ID = "BasicEgg"
    },
    RareEgg = {
        Name = "Rare Egg", 
        Price = "500",
        Icon = "rbxassetid://71012831091414",
        ID = "RareEgg"
    },
    SuperRareEgg = {
        Name = "Super Rare Egg",
        Price = "2,500", 
        Icon = "rbxassetid://93845452154351",
        ID = "SuperRareEgg"
    },
    EpicEgg = {
        Name = "Epic Egg",
        Price = "15,000",
        Icon = "rbxassetid://116395645531721", 
        ID = "EpicEgg"
    },
    LegendEgg = {
        Name = "Legend Egg",
        Price = "100,000",
        Icon = "rbxassetid://90834918351014",
        ID = "LegendEgg"
    },
    PrismaticEgg = {
        Name = "Prismatic Egg", 
        Price = "1,000,000",
        Icon = "rbxassetid://79960683434582",
        ID = "PrismaticEgg"
    },
    HyperEgg = {
        Name = "Hyper Egg",
        Price = "3,000,000", 
        Icon = "rbxassetid://104958288296273",
        ID = "HyperEgg"
    },
    VoidEgg = {
        Name = "Void Egg",
        Price = "24,000,000",
        Icon = "rbxassetid://122396162708984",
        ID = "VoidEgg"
    },
    BowserEgg = {
        Name = "Bowser Egg",
        Price = "130,000,000", 
        Icon = "rbxassetid://71500536051510",
        ID = "BowserEgg"
    },
    DemonEgg = {
        Name = "Demon Egg",
        Price = "400,000,000",
        Icon = "rbxassetid://126412407639969", 
        ID = "DemonEgg"
    },
    BoneDragonEgg = {
        Name = "Bone Dragon Egg",
        Price = "2,000,000,000",
        Icon = "rbxassetid://83209913424562",
        ID = "BoneDragonEgg"
    },
    UltraEgg = {
        Name = "Ultra Egg",
        Price = "10,000,000,000",
        Icon = "rbxassetid://83909590718799",
        ID = "UltraEgg"
    },
    DinoEgg = {
        Name = "Dino Egg",
        Price = "10,000,000,000",
        Icon = "rbxassetid://80783528632315",
        ID = "DinoEgg"
    },
    FlyEgg = {
        Name = "Fly Egg",
        Price = "999,999,999,999",
        Icon = "rbxassetid://109240587278187",
        ID = "FlyEgg"
    },
    UnicornEgg = {
        Name = "Unicorn Egg",
        Price = "40,000,000,000",
        Icon = "rbxassetid://123427249205445",
        ID = "UnicornEgg"
    },
    AncientEgg = {
        Name = "Ancient Egg",
        Price = "999,999,999,999",
        Icon = "rbxassetid://113910587565739",
        ID = "AncientEgg"
    }
}

-- Custom Egg Selection UI Class
local CustomEggUI = {}
CustomEggUI.__index = CustomEggUI

function CustomEggUI.new(parent, callback)
    local self = setmetatable({}, CustomEggUI)
    
    self.parent = parent
    self.callback = callback
    self.selectedEggs = {}
    self.isDragging = false
    self.dragStart = nil
    self.originalPosition = nil
    
    self:createUI()
    self:setupDragging()
    
    return self
end

function CustomEggUI:createUI()
    -- Main Frame
    self.mainFrame = Instance.new("Frame")
    self.mainFrame.Name = "CustomEggUI"
    self.mainFrame.Size = UDim2.new(0, 400, 0, 500)
    self.mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
    self.mainFrame.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
    self.mainFrame.BorderSizePixel = 0
    self.mainFrame.Parent = self.parent
    
    -- Corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = self.mainFrame
    
    -- Drop shadow
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://1316045217"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.6
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    shadow.Parent = self.mainFrame
    
    -- Title Bar
    self.titleBar = Instance.new("Frame")
    self.titleBar.Name = "TitleBar"
    self.titleBar.Size = UDim2.new(1, 0, 0, 50)
    self.titleBar.Position = UDim2.new(0, 0, 0, 0)
    self.titleBar.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    self.titleBar.BorderSizePixel = 0
    self.titleBar.Parent = self.mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = self.titleBar
    
    -- Title Text
    self.titleText = Instance.new("TextLabel")
    self.titleText.Name = "Title"
    self.titleText.Size = UDim2.new(1, -100, 1, 0)
    self.titleText.Position = UDim2.new(0, 15, 0, 0)
    self.titleText.BackgroundTransparency = 1
    self.titleText.Text = "🥚 Select Eggs"
    self.titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.titleText.TextScaled = true
    self.titleText.Font = Enum.Font.GothamBold
    self.titleText.Parent = self.titleBar
    
    -- Close Button
    self.closeButton = Instance.new("TextButton")
    self.closeButton.Name = "CloseButton"
    self.closeButton.Size = UDim2.new(0, 30, 0, 30)
    self.closeButton.Position = UDim2.new(1, -40, 0, 10)
    self.closeButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    self.closeButton.BorderSizePixel = 0
    self.closeButton.Text = "×"
    self.closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.closeButton.TextScaled = true
    self.closeButton.Font = Enum.Font.GothamBold
    self.closeButton.Parent = self.titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = self.closeButton
    
    -- Minimize Button
    self.minimizeButton = Instance.new("TextButton")
    self.minimizeButton.Name = "MinimizeButton"
    self.minimizeButton.Size = UDim2.new(0, 30, 0, 30)
    self.minimizeButton.Position = UDim2.new(1, -75, 0, 10)
    self.minimizeButton.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
    self.minimizeButton.BorderSizePixel = 0
    self.minimizeButton.Text = "−"
    self.minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.minimizeButton.TextScaled = true
    self.minimizeButton.Font = Enum.Font.GothamBold
    self.minimizeButton.Parent = self.titleBar
    
    local minimizeCorner = Instance.new("UICorner")
    minimizeCorner.CornerRadius = UDim.new(0, 6)
    minimizeCorner.Parent = self.minimizeButton
    
    -- Content Frame
    self.contentFrame = Instance.new("Frame")
    self.contentFrame.Name = "Content"
    self.contentFrame.Size = UDim2.new(1, -20, 1, -70)
    self.contentFrame.Position = UDim2.new(0, 10, 0, 60)
    self.contentFrame.BackgroundTransparency = 1
    self.contentFrame.Parent = self.mainFrame
    
    -- Scroll Frame
    self.scrollFrame = Instance.new("ScrollingFrame")
    self.scrollFrame.Name = "ScrollFrame"
    self.scrollFrame.Size = UDim2.new(1, 0, 1, -60)
    self.scrollFrame.Position = UDim2.new(0, 0, 0, 0)
    self.scrollFrame.BackgroundTransparency = 1
    self.scrollFrame.BorderSizePixel = 0
    self.scrollFrame.ScrollBarThickness = 6
    self.scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    self.scrollFrame.Parent = self.contentFrame
    
    -- Grid Layout
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 120, 0, 140)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    gridLayout.Parent = self.scrollFrame
    
    -- Buttons Frame
    self.buttonsFrame = Instance.new("Frame")
    self.buttonsFrame.Name = "Buttons"
    self.buttonsFrame.Size = UDim2.new(1, 0, 0, 50)
    self.buttonsFrame.Position = UDim2.new(0, 0, 1, -50)
    self.buttonsFrame.BackgroundTransparency = 1
    self.buttonsFrame.Parent = self.contentFrame
    
    -- Select All Button
    self.selectAllButton = Instance.new("TextButton")
    self.selectAllButton.Name = "SelectAll"
    self.selectAllButton.Size = UDim2.new(0, 100, 0, 35)
    self.selectAllButton.Position = UDim2.new(0, 10, 0, 7)
    self.selectAllButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
    self.selectAllButton.BorderSizePixel = 0
    self.selectAllButton.Text = "Select All"
    self.selectAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.selectAllButton.TextScaled = true
    self.selectAllButton.Font = Enum.Font.GothamBold
    self.selectAllButton.Parent = self.buttonsFrame
    
    local selectAllCorner = Instance.new("UICorner")
    selectAllCorner.CornerRadius = UDim.new(0, 8)
    selectAllCorner.Parent = self.selectAllButton
    
    -- Clear All Button
    self.clearAllButton = Instance.new("TextButton")
    self.clearAllButton.Name = "ClearAll"
    self.clearAllButton.Size = UDim2.new(0, 100, 0, 35)
    self.clearAllButton.Position = UDim2.new(0, 120, 0, 7)
    self.clearAllButton.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
    self.clearAllButton.BorderSizePixel = 0
    self.clearAllButton.Text = "Clear All"
    self.clearAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.clearAllButton.TextScaled = true
    self.clearAllButton.Font = Enum.Font.GothamBold
    self.clearAllButton.Parent = self.buttonsFrame
    
    local clearAllCorner = Instance.new("UICorner")
    clearAllCorner.CornerRadius = UDim.new(0, 8)
    clearAllCorner.Parent = self.clearAllButton
    
    -- Confirm Button
    self.confirmButton = Instance.new("TextButton")
    self.confirmButton.Name = "Confirm"
    self.confirmButton.Size = UDim2.new(0, 100, 0, 35)
    self.confirmButton.Position = UDim2.new(1, -110, 0, 7)
    self.confirmButton.BackgroundColor3 = Color3.fromRGB(33, 150, 243)
    self.confirmButton.BorderSizePixel = 0
    self.confirmButton.Text = "Confirm"
    self.confirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.confirmButton.TextScaled = true
    self.confirmButton.Font = Enum.Font.GothamBold
    self.confirmButton.Parent = self.buttonsFrame
    
    local confirmCorner = Instance.new("UICorner")
    confirmCorner.CornerRadius = UDim.new(0, 8)
    confirmCorner.Parent = self.confirmButton
    
    -- Create egg buttons
    self:createEggButtons()
    self:setupConnections()
end

function CustomEggUI:createEggButtons()
    self.eggButtons = {}
    
    for eggId, eggInfo in pairs(eggData) do
        local eggButton = Instance.new("TextButton")
        eggButton.Name = eggId
        eggButton.Size = UDim2.new(0, 120, 0, 140)
        eggButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        eggButton.BorderSizePixel = 0
        eggButton.Text = ""
        eggButton.Parent = self.scrollFrame
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 8)
        buttonCorner.Parent = eggButton
        
        -- Border for selection
        local border = Instance.new("UIStroke")
        border.Color = Color3.fromRGB(200, 200, 200)
        border.Thickness = 2
        border.Parent = eggButton
        
        -- Egg Icon
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0, 60, 0, 60)
        icon.Position = UDim2.new(0.5, -30, 0, 10)
        icon.BackgroundTransparency = 1
        icon.Image = eggInfo.Icon
        icon.ImageRectSize = Vector2.new(100, 100)
        icon.ImageRectOffset = Vector2.new(0, 0)
        icon.Parent = eggButton
        
        -- Egg Name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "Name"
        nameLabel.Size = UDim2.new(1, -10, 0, 20)
        nameLabel.Position = UDim2.new(0, 5, 0, 80)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = eggInfo.Name
        nameLabel.TextColor3 = Color3.fromRGB(50, 50, 50)
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.Parent = eggButton
        
        -- Price
        local priceLabel = Instance.new("TextLabel")
        priceLabel.Name = "Price"
        priceLabel.Size = UDim2.new(1, -10, 0, 20)
        priceLabel.Position = UDim2.new(0, 5, 0, 100)
        priceLabel.BackgroundTransparency = 1
        priceLabel.Text = "$" .. eggInfo.Price
        priceLabel.TextColor3 = Color3.fromRGB(76, 175, 80)
        priceLabel.TextScaled = true
        priceLabel.Font = Enum.Font.GothamBold
        priceLabel.Parent = eggButton
        
        -- Selection indicator
        local selectionIndicator = Instance.new("Frame")
        selectionIndicator.Name = "SelectionIndicator"
        selectionIndicator.Size = UDim2.new(1, 0, 1, 0)
        selectionIndicator.Position = UDim2.new(0, 0, 0, 0)
        selectionIndicator.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        selectionIndicator.BackgroundTransparency = 0.8
        selectionIndicator.Visible = false
        selectionIndicator.Parent = eggButton
        
        local indicatorCorner = Instance.new("UICorner")
        indicatorCorner.CornerRadius = UDim.new(0, 8)
        indicatorCorner.Parent = selectionIndicator
        
        -- Check mark
        local checkMark = Instance.new("TextLabel")
        checkMark.Name = "CheckMark"
        checkMark.Size = UDim2.new(0, 30, 0, 30)
        checkMark.Position = UDim2.new(1, -35, 0, 5)
        checkMark.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        checkMark.BorderSizePixel = 0
        checkMark.Text = "✓"
        checkMark.TextColor3 = Color3.fromRGB(255, 255, 255)
        checkMark.TextScaled = true
        checkMark.Font = Enum.Font.GothamBold
        checkMark.Visible = false
        checkMark.Parent = eggButton
        
        local checkCorner = Instance.new("UICorner")
        checkCorner.CornerRadius = UDim.new(0, 15)
        checkCorner.Parent = checkMark
        
        -- Button click handler
        eggButton.MouseButton1Click:Connect(function()
            self:toggleEggSelection(eggId, eggButton)
        end)
        
        self.eggButtons[eggId] = {
            button = eggButton,
            indicator = selectionIndicator,
            checkMark = checkMark,
            border = border
        }
    end
    
    -- Update canvas size
    local gridLayout = self.scrollFrame:FindFirstChild("UIGridLayout")
    if gridLayout then
        local numEggs = 0
        for _ in pairs(eggData) do
            numEggs = numEggs + 1
        end
        
        local rows = math.ceil(numEggs / 3)
        local canvasHeight = rows * 150 + (rows - 1) * 10
        self.scrollFrame.CanvasSize = UDim2.new(0, 0, 0, canvasHeight)
    end
end

function CustomEggUI:toggleEggSelection(eggId, eggButton)
    local buttonData = self.eggButtons[eggId]
    
    if self.selectedEggs[eggId] then
        -- Deselect
        self.selectedEggs[eggId] = nil
        buttonData.indicator.Visible = false
        buttonData.checkMark.Visible = false
        buttonData.border.Color = Color3.fromRGB(200, 200, 200)
    else
        -- Select
        self.selectedEggs[eggId] = true
        buttonData.indicator.Visible = true
        buttonData.checkMark.Visible = true
        buttonData.border.Color = Color3.fromRGB(76, 175, 80)
    end
    
    -- Update button text
    self:updateButtonText()
end

function CustomEggUI:updateButtonText()
    local count = 0
    for _ in pairs(self.selectedEggs) do
        count = count + 1
    end
    
    if count == 0 then
        self.confirmButton.Text = "Confirm"
    else
        self.confirmButton.Text = "Confirm (" .. count .. ")"
    end
end

function CustomEggUI:setupConnections()
    -- Close button
    self.closeButton.MouseButton1Click:Connect(function()
        self:hide()
    end)
    
    -- Minimize button
    self.minimizeButton.MouseButton1Click:Connect(function()
        self:minimize()
    end)
    
    -- Select All button
    self.selectAllButton.MouseButton1Click:Connect(function()
        self:selectAll()
    end)
    
    -- Clear All button
    self.clearAllButton.MouseButton1Click:Connect(function()
        self:clearAll()
    end)
    
    -- Confirm button
    self.confirmButton.MouseButton1Click:Connect(function()
        self:confirm()
    end)
end

function CustomEggUI:setupDragging()
    self.titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.isDragging = true
            self.dragStart = input.Position
            self.originalPosition = self.mainFrame.Position
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and self.isDragging then
            local delta = input.Position - self.dragStart
            self.mainFrame.Position = UDim2.new(
                self.originalPosition.X.Scale,
                self.originalPosition.X.Offset + delta.X,
                self.originalPosition.Y.Scale,
                self.originalPosition.Y.Offset + delta.Y
            )
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.isDragging = false
        end
    end)
end

function CustomEggUI:selectAll()
    for eggId, buttonData in pairs(self.eggButtons) do
        self.selectedEggs[eggId] = true
        buttonData.indicator.Visible = true
        buttonData.checkMark.Visible = true
        buttonData.border.Color = Color3.fromRGB(76, 175, 80)
    end
    self:updateButtonText()
end

function CustomEggUI:clearAll()
    for eggId, buttonData in pairs(self.eggButtons) do
        self.selectedEggs[eggId] = nil
        buttonData.indicator.Visible = false
        buttonData.checkMark.Visible = false
        buttonData.border.Color = Color3.fromRGB(200, 200, 200)
    end
    self:updateButtonText()
end

function CustomEggUI:confirm()
    if self.callback then
        self.callback(self.selectedEggs)
    end
    self:hide()
end

function CustomEggUI:show()
    self.mainFrame.Visible = true
    self.mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
end

function CustomEggUI:hide()
    self.mainFrame.Visible = false
end

function CustomEggUI:minimize()
    if self.mainFrame.Size.Y.Offset > 100 then
        -- Minimize
        local tween = TweenService:Create(self.mainFrame, TweenInfo.new(0.3), {
            Size = UDim2.new(0, 400, 0, 100)
        })
        tween:Play()
        self.minimizeButton.Text = "□"
    else
        -- Restore
        local tween = TweenService:Create(self.mainFrame, TweenInfo.new(0.3), {
            Size = UDim2.new(0, 400, 0, 500)
        })
        tween:Play()
        self.minimizeButton.Text = "−"
    end
end

function CustomEggUI:getSelectedEggs()
    return self.selectedEggs
end

function CustomEggUI:setSelectedEggs(selectedEggs)
    self.selectedEggs = selectedEggs or {}
    
    -- Update UI
    for eggId, buttonData in pairs(self.eggButtons) do
        if self.selectedEggs[eggId] then
            buttonData.indicator.Visible = true
            buttonData.checkMark.Visible = true
            buttonData.border.Color = Color3.fromRGB(76, 175, 80)
        else
            buttonData.indicator.Visible = false
            buttonData.checkMark.Visible = false
            buttonData.border.Color = Color3.fromRGB(200, 200, 200)
        end
    end
    
    self:updateButtonText()
end

return CustomEggUI
