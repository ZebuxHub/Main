-- Custom Egg Selector UI for Build A Zoo
-- Replaces dropdown system with visual grid selection

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Hardcoded egg data (Name, Price, Icon)
local EGG_DATA = {
    {Name = "BasicEgg", Price = "100", Icon = "rbxassetid://129248801621928"},
    {Name = "RareEgg", Price = "500", Icon = "rbxassetid://71012831091414"},
    {Name = "SuperRareEgg", Price = "2,500", Icon = "rbxassetid://93845452154351"},
    {Name = "EpicEgg", Price = "15,000", Icon = "rbxassetid://116395645531721"},
    {Name = "LegendEgg", Price = "100,000", Icon = "rbxassetid://90834918351014"},
    {Name = "PrismaticEgg", Price = "1,000,000", Icon = "rbxassetid://79960683434582"},
    {Name = "HyperEgg", Price = "3,000,000", Icon = "rbxassetid://104958288296273"},
    {Name = "VoidEgg", Price = "24,000,000", Icon = "rbxassetid://122396162708984"},
    {Name = "BowserEgg", Price = "130,000,000", Icon = "rbxassetid://71500536051510"},
    {Name = "DemonEgg", Price = "400,000,000", Icon = "rbxassetid://126412407639969"},
    {Name = "BoneDragonEgg", Price = "2,000,000,000", Icon = "rbxassetid://83209913424562"},
    {Name = "UltraEgg", Price = "10,000,000,000", Icon = "rbxassetid://83909590718799"},
    {Name = "DinoEgg", Price = "10,000,000,000", Icon = "rbxassetid://80783528632315"},
    {Name = "FlyEgg", Price = "999,999,999,999", Icon = "rbxassetid://109240587278187"},
    {Name = "UnicornEgg", Price = "40,000,000,000", Icon = "rbxassetid://123427249205445"},
    {Name = "AncientEgg", Price = "999,999,999,999", Icon = "rbxassetid://113910587565739"}
}

-- Hardcoded mutation data
local MUTATION_DATA = {
    {Name = "Golden", Color = Color3.fromHex("#ffc518")},
    {Name = "Diamond", Color = Color3.fromHex("#07e6ff")},
    {Name = "Electirc", Color = Color3.fromHex("#aa55ff")},
    {Name = "Fire", Color = Color3.fromHex("#ff3d02")},
    {Name = "Jurassic", Color = Color3.fromHex("#AE75E7")} -- Dino renamed to Jurassic
}

-- Hardcoded fruit data
local FRUIT_DATA = {
    {Name = "Strawberry", Price = "5,000"},
    {Name = "Blueberry", Price = "20,000"},
    {Name = "Watermelon", Price = "80,000"},
    {Name = "Apple", Price = "400,000"},
    {Name = "Orange", Price = "1,200,000"},
    {Name = "Corn", Price = "3,500,000"},
    {Name = "Banana", Price = "12,000,000"},
    {Name = "Grape", Price = "50,000,000"},
    {Name = "Pear", Price = "200,000,000"},
    {Name = "Pineapple", Price = "600,000,000"},
    {Name = "GoldMango", Price = "2,000,000,000"}
}

local CustomEggSelector = {}
CustomEggSelector.__index = CustomEggSelector

-- Save/Load system
local function saveSelection(selectionType, selectedItems)
    local data = {
        type = selectionType,
        items = selectedItems,
        timestamp = os.time()
    }
    
    local success = pcall(function()
        writefile("BuildAZoo_" .. selectionType .. "_Selection.json", game:GetService("HttpService"):JSONEncode(data))
    end)
    return success
end

local function loadSelection(selectionType)
    local success, data = pcall(function()
        local content = readfile("BuildAZoo_" .. selectionType .. "_Selection.json")
        return game:GetService("HttpService"):JSONDecode(content)
    end)
    
    if success and data and data.type == selectionType then
        -- Check if data is less than 24 hours old
        local currentTime = os.time()
        local timeDiff = currentTime - (data.timestamp or 0)
        local expirationTime = 24 * 60 * 60 -- 24 hours
        
        if timeDiff < expirationTime then
            return data.items or {}
        end
    end
    
    return {}
end

function CustomEggSelector.new(selectionType, callback)
    local self = setmetatable({}, CustomEggSelector)
    
    self.selectionType = selectionType -- "eggs", "mutations", "fruits"
    self.callback = callback
    self.selectedItems = {}
    self.isDragging = false
    self.dragStart = Vector2.new(0, 0)
    self.windowPosition = Vector2.new(100, 100)
    
    -- Load saved selection
    self.selectedItems = loadSelection(selectionType)
    
    self:createUI()
    return self
end

function CustomEggSelector:createUI()
    -- Create main frame
    self.mainFrame = Instance.new("Frame")
    self.mainFrame.Name = "CustomEggSelector"
    self.mainFrame.Size = UDim2.new(0, 400, 0, 500)
    self.mainFrame.Position = UDim2.new(0, self.windowPosition.X, 0, self.windowPosition.Y)
    self.mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    self.mainFrame.BorderSizePixel = 0
    self.mainFrame.Parent = game:GetService("CoreGui")
    
    -- Create title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = self.mainFrame
    
    -- Title text
    local titleText = Instance.new("TextLabel")
    titleText.Name = "Title"
    titleText.Size = UDim2.new(1, -60, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "Select " .. string.upper(self.selectionType:sub(1,1)) .. self.selectionType:sub(2)
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.TextScaled = true
    titleText.Font = Enum.Font.GothamBold
    titleText.Parent = titleBar
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -30, 0, 0)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeButton.BorderSizePixel = 0
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = titleBar
    
    -- Minimize button
    local minimizeButton = Instance.new("TextButton")
    minimizeButton.Name = "MinimizeButton"
    minimizeButton.Size = UDim2.new(0, 30, 0, 30)
    minimizeButton.Position = UDim2.new(1, -60, 0, 0)
    minimizeButton.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
    minimizeButton.BorderSizePixel = 0
    minimizeButton.Text = "-"
    minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeButton.TextScaled = true
    minimizeButton.Font = Enum.Font.GothamBold
    minimizeButton.Parent = titleBar
    
    -- Create scroll frame for items
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, -20, 1, -40)
    scrollFrame.Position = UDim2.new(0, 10, 0, 35)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = self.mainFrame
    
    -- Create grid layout
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 120, 0, 140)
    gridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.Parent = scrollFrame
    
    -- Get data based on selection type
    local data = {}
    if self.selectionType == "eggs" then
        data = EGG_DATA
    elseif self.selectionType == "mutations" then
        data = MUTATION_DATA
    elseif self.selectionType == "fruits" then
        data = FRUIT_DATA
    end
    
    -- Create item buttons
    for i, item in ipairs(data) do
        local itemButton = Instance.new("Frame")
        itemButton.Name = item.Name
        itemButton.Size = UDim2.new(0, 120, 0, 140)
        itemButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        itemButton.BorderSizePixel = 0
        itemButton.Parent = scrollFrame
        
        -- Check if item is selected
        local isSelected = table.find(self.selectedItems, item.Name) ~= nil
        if isSelected then
            itemButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        end
        
        -- Item icon
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0, 60, 0, 60)
        icon.Position = UDim2.new(0.5, -30, 0, 10)
        icon.BackgroundTransparency = 1
        icon.Image = item.Icon or "rbxassetid://129248801621928" -- Default icon
        icon.Parent = itemButton
        
        -- Item name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "Name"
        nameLabel.Size = UDim2.new(1, -10, 0, 20)
        nameLabel.Position = UDim2.new(0, 5, 0, 75)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = item.Name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.Parent = itemButton
        
        -- Item price
        local priceLabel = Instance.new("TextLabel")
        priceLabel.Name = "Price"
        priceLabel.Size = UDim2.new(1, -10, 0, 20)
        priceLabel.Position = UDim2.new(0, 5, 0, 95)
        priceLabel.BackgroundTransparency = 1
        priceLabel.Text = "$" .. item.Price
        priceLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        priceLabel.TextScaled = true
        priceLabel.Font = Enum.Font.Gotham
        priceLabel.Parent = itemButton
        
        -- Selection indicator
        local selectionIndicator = Instance.new("TextLabel")
        selectionIndicator.Name = "SelectionIndicator"
        selectionIndicator.Size = UDim2.new(0, 20, 0, 20)
        selectionIndicator.Position = UDim2.new(1, -25, 0, 5)
        selectionIndicator.BackgroundTransparency = 1
        selectionIndicator.Text = isSelected and "✓" or ""
        selectionIndicator.TextColor3 = Color3.fromRGB(255, 255, 255)
        selectionIndicator.TextScaled = true
        selectionIndicator.Font = Enum.Font.GothamBold
        selectionIndicator.Parent = itemButton
        
        -- Click handler
        itemButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                self:toggleSelection(item.Name, itemButton, selectionIndicator)
            end
        end)
    end
    
    -- Update canvas size
    local itemCount = #data
    local rows = math.ceil(itemCount / 3)
    local canvasHeight = rows * 145 + 10
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, canvasHeight)
    
    -- Add control buttons
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "ButtonFrame"
    buttonFrame.Size = UDim2.new(1, -20, 0, 40)
    buttonFrame.Position = UDim2.new(0, 10, 1, -45)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.Parent = self.mainFrame
    
    -- Select All button
    local selectAllButton = Instance.new("TextButton")
    selectAllButton.Name = "SelectAll"
    selectAllButton.Size = UDim2.new(0, 80, 0, 30)
    selectAllButton.Position = UDim2.new(0, 0, 0, 5)
    selectAllButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    selectAllButton.BorderSizePixel = 0
    selectAllButton.Text = "Select All"
    selectAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectAllButton.TextScaled = true
    selectAllButton.Font = Enum.Font.GothamBold
    selectAllButton.Parent = buttonFrame
    
    -- Clear All button
    local clearAllButton = Instance.new("TextButton")
    clearAllButton.Name = "ClearAll"
    clearAllButton.Size = UDim2.new(0, 80, 0, 30)
    clearAllButton.Position = UDim2.new(0, 90, 0, 5)
    clearAllButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    clearAllButton.BorderSizePixel = 0
    clearAllButton.Text = "Clear All"
    clearAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    clearAllButton.TextScaled = true
    clearAllButton.Font = Enum.Font.GothamBold
    clearAllButton.Parent = buttonFrame
    
    -- Save button
    local saveButton = Instance.new("TextButton")
    saveButton.Name = "Save"
    saveButton.Size = UDim2.new(0, 80, 0, 30)
    saveButton.Position = UDim2.new(1, -80, 0, 5)
    saveButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    saveButton.BorderSizePixel = 0
    saveButton.Text = "Save"
    saveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    saveButton.TextScaled = true
    saveButton.Font = Enum.Font.GothamBold
    saveButton.Parent = buttonFrame
    
    -- Button handlers
    selectAllButton.MouseButton1Click:Connect(function()
        self:selectAll()
    end)
    
    clearAllButton.MouseButton1Click:Connect(function()
        self:clearAll()
    end)
    
    saveButton.MouseButton1Click:Connect(function()
        self:saveSelection()
    end)
    
    closeButton.MouseButton1Click:Connect(function()
        self:destroy()
    end)
    
    minimizeButton.MouseButton1Click:Connect(function()
        self:toggleMinimize()
    end)
    
    -- Make window draggable
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.isDragging = true
            self.dragStart = input.Position - self.mainFrame.Position
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and self.isDragging then
            self.mainFrame.Position = UDim2.new(0, input.Position.X - self.dragStart.X, 0, input.Position.Y - self.dragStart.Y)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.isDragging = false
        end
    end)
end

function CustomEggSelector:toggleSelection(itemName, button, indicator)
    local index = table.find(self.selectedItems, itemName)
    
    if index then
        -- Remove from selection
        table.remove(self.selectedItems, index)
        button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        indicator.Text = ""
    else
        -- Add to selection
        table.insert(self.selectedItems, itemName)
        button.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        indicator.Text = "✓"
    end
    
    -- Call callback if provided
    if self.callback then
        self.callback(self.selectedItems)
    end
end

function CustomEggSelector:selectAll()
    self.selectedItems = {}
    for _, item in ipairs(EGG_DATA) do
        table.insert(self.selectedItems, item.Name)
    end
    
    -- Update UI
    for _, child in ipairs(self.mainFrame.ScrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIGridLayout" then
            child.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
            local indicator = child:FindFirstChild("SelectionIndicator")
            if indicator then
                indicator.Text = "✓"
            end
        end
    end
    
    if self.callback then
        self.callback(self.selectedItems)
    end
end

function CustomEggSelector:clearAll()
    self.selectedItems = {}
    
    -- Update UI
    for _, child in ipairs(self.mainFrame.ScrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIGridLayout" then
            child.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            local indicator = child:FindFirstChild("SelectionIndicator")
            if indicator then
                indicator.Text = ""
            end
        end
    end
    
    if self.callback then
        self.callback(self.selectedItems)
    end
end

function CustomEggSelector:saveSelection()
    local success = saveSelection(self.selectionType, self.selectedItems)
    
    if success then
        -- Show success notification
        if game:GetService("StarterGui") then
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Selection Saved",
                Text = "Your " .. self.selectionType .. " selection has been saved!",
                Duration = 3
            })
        end
    end
end

function CustomEggSelector:toggleMinimize()
    if self.mainFrame.Size.Y.Offset > 50 then
        -- Minimize
        self.mainFrame.Size = UDim2.new(0, 400, 0, 30)
        self.mainFrame.ScrollFrame.Visible = false
        self.mainFrame.ButtonFrame.Visible = false
    else
        -- Restore
        self.mainFrame.Size = UDim2.new(0, 400, 0, 500)
        self.mainFrame.ScrollFrame.Visible = true
        self.mainFrame.ButtonFrame.Visible = true
    end
end

function CustomEggSelector:destroy()
    if self.mainFrame then
        self.mainFrame:Destroy()
        self.mainFrame = nil
    end
end

function CustomEggSelector:getSelectedItems()
    return self.selectedItems
end

function CustomEggSelector:setSelectedItems(items)
    self.selectedItems = items or {}
    -- Update UI to reflect new selection
    -- This would need to be implemented based on the current UI state
end

return CustomEggSelector
