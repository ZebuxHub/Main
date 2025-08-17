-- Enhanced Mac-Style Solo Leveling UI Library for Roblox
-- Includes Input, Dropdown, Toggle, and Save Manager functionality

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local MacSoloUI = {}
MacSoloUI.__index = MacSoloUI

-- Solo Leveling Color Palette
local Colors = {
    Primary = Color3.fromRGB(25, 25, 35),      -- Dark blue-gray
    Secondary = Color3.fromRGB(35, 35, 45),    -- Slightly lighter
    Accent = Color3.fromRGB(100, 150, 255),    -- Blue accent
    Gold = Color3.fromRGB(255, 215, 0),        -- Solo Leveling gold
    Purple = Color3.fromRGB(147, 112, 219),    -- Magic purple
    Text = Color3.fromRGB(255, 255, 255),      -- White text
    SubText = Color3.fromRGB(180, 180, 180),   -- Gray text
    Border = Color3.fromRGB(60, 60, 70),       -- Border color
    Success = Color3.fromRGB(39, 201, 63),     -- Green success
    Warning = Color3.fromRGB(255, 189, 46),    -- Yellow warning
    Error = Color3.fromRGB(255, 95, 86),       -- Red error
    Close = Color3.fromRGB(255, 95, 86),       -- Red close button
    Minimize = Color3.fromRGB(255, 189, 46),   -- Yellow minimize
    Maximize = Color3.fromRGB(39, 201, 63)     -- Green maximize
}

-- Tween configurations
local TweenInfo_Fast = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TweenInfo_Smooth = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- Config Manager
local ConfigManager = {
    configs = {},
    currentConfig = "default"
}

function ConfigManager:SaveConfig(configName, data)
    if not configName then configName = self.currentConfig end
    self.configs[configName] = data
    
    -- In a real implementation, you would save to DataStore
    -- For now, we'll use a simple table storage
    print("Config '" .. configName .. "' saved successfully!")
    return true
end

function ConfigManager:LoadConfig(configName)
    if not configName then configName = self.currentConfig end
    return self.configs[configName] or {}
end

function ConfigManager:DeleteConfig(configName)
    if self.configs[configName] then
        self.configs[configName] = nil
        print("Config '" .. configName .. "' deleted!")
        return true
    end
    return false
end

function ConfigManager:GetConfigList()
    local list = {}
    for name, _ in pairs(self.configs) do
        table.insert(list, name)
    end
    return list
end

function MacSoloUI.new(title, size, position)
    local self = setmetatable({}, MacSoloUI)
    
    -- Default values
    self.title = title or "Solo Leveling UI"
    self.size = size or UDim2.new(0, 500, 0, 400)
    self.position = position or UDim2.new(0.5, -250, 0.5, -200)
    self.minimized = false
    self.originalSize = self.size
    self.isDragging = false
    self.isResizing = false
    self.dragStart = nil
    self.startPos = nil
    
    -- Config system
    self.configData = {}
    self.configCallbacks = {}
    
    self:CreateUI()
    self:SetupEvents()
    
    return self
end

function MacSoloUI:CreateUI()
    -- Main ScreenGui
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "MacSoloUI"
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Main Frame (Window)
    self.MainFrame = Instance.new("Frame")
    self.MainFrame.Name = "Window"
    self.MainFrame.Size = self.size
    self.MainFrame.Position = self.position
    self.MainFrame.BackgroundColor3 = Colors.Primary
    self.MainFrame.BorderSizePixel = 0
    self.MainFrame.Parent = self.ScreenGui
    
    -- Window border glow effect
    local borderGlow = Instance.new("UIStroke")
    borderGlow.Color = Colors.Accent
    borderGlow.Thickness = 1
    borderGlow.Transparency = 0.7
    borderGlow.Parent = self.MainFrame
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = self.MainFrame
    
    -- Title Bar
    self.TitleBar = Instance.new("Frame")
    self.TitleBar.Name = "TitleBar"
    self.TitleBar.Size = UDim2.new(1, 0, 0, 35)
    self.TitleBar.Position = UDim2.new(0, 0, 0, 0)
    self.TitleBar.BackgroundColor3 = Colors.Secondary
    self.TitleBar.BorderSizePixel = 0
    self.TitleBar.Parent = self.MainFrame
    
    -- Title bar corners
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = self.TitleBar
    
    -- Title bar bottom mask
    local titleMask = Instance.new("Frame")
    titleMask.Size = UDim2.new(1, 0, 0, 12)
    titleMask.Position = UDim2.new(0, 0, 1, -12)
    titleMask.BackgroundColor3 = Colors.Secondary
    titleMask.BorderSizePixel = 0
    titleMask.Parent = self.TitleBar
    
    -- Window Controls Container
    self.ControlsFrame = Instance.new("Frame")
    self.ControlsFrame.Name = "Controls"
    self.ControlsFrame.Size = UDim2.new(0, 80, 1, 0)
    self.ControlsFrame.Position = UDim2.new(0, 10, 0, 0)
    self.ControlsFrame.BackgroundTransparency = 1
    self.ControlsFrame.Parent = self.TitleBar
    
    -- Close Button
    self.CloseButton = self:CreateControlButton(Colors.Close, UDim2.new(0, 0, 0.5, -6))
    self.CloseButton.Parent = self.ControlsFrame
    
    -- Minimize Button
    self.MinimizeButton = self:CreateControlButton(Colors.Minimize, UDim2.new(0, 20, 0.5, -6))
    self.MinimizeButton.Parent = self.ControlsFrame
    
    -- Maximize Button (for resize)
    self.MaximizeButton = self:CreateControlButton(Colors.Maximize, UDim2.new(0, 40, 0.5, -6))
    self.MaximizeButton.Parent = self.ControlsFrame
    
    -- Title Label
    self.TitleLabel = Instance.new("TextLabel")
    self.TitleLabel.Name = "Title"
    self.TitleLabel.Size = UDim2.new(1, -250, 1, 0)
    self.TitleLabel.Position = UDim2.new(0, 100, 0, 0)
    self.TitleLabel.BackgroundTransparency = 1
    self.TitleLabel.Text = self.title
    self.TitleLabel.TextColor3 = Colors.Text
    self.TitleLabel.TextScaled = false
    self.TitleLabel.TextSize = 14
    self.TitleLabel.Font = Enum.Font.GothamSemibold
    self.TitleLabel.TextXAlignment = Enum.TextXAlignment.Center
    self.TitleLabel.Parent = self.TitleBar
    
    -- Config Controls in Title Bar
    self:CreateConfigControls()
    
    -- Content Frame
    self.ContentFrame = Instance.new("ScrollingFrame")
    self.ContentFrame.Name = "Content"
    self.ContentFrame.Size = UDim2.new(1, -20, 1, -55)
    self.ContentFrame.Position = UDim2.new(0, 10, 0, 45)
    self.ContentFrame.BackgroundColor3 = Colors.Primary
    self.ContentFrame.BorderSizePixel = 0
    self.ContentFrame.ScrollBarThickness = 4
    self.ContentFrame.ScrollBarImageColor3 = Colors.Accent
    self.ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    self.ContentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    self.ContentFrame.Parent = self.MainFrame
    
    -- Content frame corners
    local contentCorner = Instance.new("UICorner")
    contentCorner.CornerRadius = UDim.new(0, 8)
    contentCorner.Parent = self.ContentFrame
    
    -- Layout for content
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.Parent = self.ContentFrame
    
    -- Resize Handle (bottom-right corner)
    self.ResizeHandle = Instance.new("Frame")
    self.ResizeHandle.Name = "ResizeHandle"
    self.ResizeHandle.Size = UDim2.new(0, 15, 0, 15)
    self.ResizeHandle.Position = UDim2.new(1, -15, 1, -15)
    self.ResizeHandle.BackgroundColor3 = Colors.Border
    self.ResizeHandle.BorderSizePixel = 0
    self.ResizeHandle.Parent = self.MainFrame
    
    local resizeCorner = Instance.new("UICorner")
    resizeCorner.CornerRadius = UDim.new(0, 4)
    resizeCorner.Parent = self.ResizeHandle
end

function MacSoloUI:CreateConfigControls()
    -- Config controls container
    local configFrame = Instance.new("Frame")
    configFrame.Name = "ConfigFrame"
    configFrame.Size = UDim2.new(0, 140, 1, 0)
    configFrame.Position = UDim2.new(1, -150, 0, 0)
    configFrame.BackgroundTransparency = 1
    configFrame.Parent = self.TitleBar
    
    -- Save button
    local saveBtn = Instance.new("TextButton")
    saveBtn.Name = "SaveBtn"
    saveBtn.Size = UDim2.new(0, 30, 0, 20)
    saveBtn.Position = UDim2.new(0, 0, 0.5, -10)
    saveBtn.BackgroundColor3 = Colors.Success
    saveBtn.BorderSizePixel = 0
    saveBtn.Text = "💾"
    saveBtn.TextColor3 = Colors.Text
    saveBtn.TextSize = 12
    saveBtn.Font = Enum.Font.Gotham
    saveBtn.Parent = configFrame
    
    local saveCorner = Instance.new("UICorner")
    saveCorner.CornerRadius = UDim.new(0, 4)
    saveCorner.Parent = saveBtn
    
    -- Load button
    local loadBtn = Instance.new("TextButton")
    loadBtn.Name = "LoadBtn"
    loadBtn.Size = UDim2.new(0, 30, 0, 20)
    loadBtn.Position = UDim2.new(0, 35, 0.5, -10)
    loadBtn.BackgroundColor3 = Colors.Accent
    loadBtn.BorderSizePixel = 0
    loadBtn.Text = "📁"
    loadBtn.TextColor3 = Colors.Text
    loadBtn.TextSize = 12
    loadBtn.Font = Enum.Font.Gotham
    loadBtn.Parent = configFrame
    
    local loadCorner = Instance.new("UICorner")
    loadCorner.CornerRadius = UDim.new(0, 4)
    loadCorner.Parent = loadBtn
    
    -- Config name input
    local configInput = Instance.new("TextBox")
    configInput.Name = "ConfigInput"
    configInput.Size = UDim2.new(0, 70, 0, 20)
    configInput.Position = UDim2.new(0, 70, 0.5, -10)
    configInput.BackgroundColor3 = Colors.Secondary
    configInput.BorderSizePixel = 0
    configInput.Text = "default"
    configInput.TextColor3 = Colors.Text
    configInput.TextSize = 10
    configInput.Font = Enum.Font.Gotham
    configInput.PlaceholderText = "Config name"
    configInput.PlaceholderColor3 = Colors.SubText
    configInput.Parent = configFrame
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 4)
    inputCorner.Parent = configInput
    
    -- Button events
    saveBtn.MouseButton1Click:Connect(function()
        self:SaveCurrentConfig(configInput.Text)
    end)
    
    loadBtn.MouseButton1Click:Connect(function()
        self:LoadConfig(configInput.Text)
    end)
end

function MacSoloUI:CreateControlButton(color, position)
    local button = Instance.new("Frame")
    button.Size = UDim2.new(0, 12, 0, 12)
    button.Position = position
    button.BackgroundColor3 = color
    button.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = button
    
    -- Button hover effect
    local detector = Instance.new("TextButton")
    detector.Size = UDim2.new(1, 4, 1, 4)
    detector.Position = UDim2.new(0, -2, 0, -2)
    detector.BackgroundTransparency = 1
    detector.Text = ""
    detector.Parent = button
    
    -- Hover animation
    detector.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo_Fast, {Size = UDim2.new(0, 14, 0, 14)}):Play()
    end)
    
    detector.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo_Fast, {Size = UDim2.new(0, 12, 0, 12)}):Play()
    end)
    
    return button
end

function MacSoloUI:SetupEvents()
    -- Close button
    self.CloseButton:FindFirstChildOfClass("TextButton").MouseButton1Click:Connect(function()
        self:Close()
    end)
    
    -- Minimize button
    self.MinimizeButton:FindFirstChildOfClass("TextButton").MouseButton1Click:Connect(function()
        self:ToggleMinimize()
    end)
    
    -- Title bar dragging
    self.TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.isDragging = true
            self.dragStart = input.Position
            self.startPos = self.MainFrame.Position
        end
    end)
    
    -- Resize handle
    self.ResizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.isResizing = true
            self.dragStart = input.Position
            self.startSize = self.MainFrame.Size
        end
    end)
    
    -- Global input handling
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if self.isDragging and self.dragStart then
                local delta = input.Position - self.dragStart
                local newPos = UDim2.new(
                    self.startPos.X.Scale,
                    self.startPos.X.Offset + delta.X,
                    self.startPos.Y.Scale,
                    self.startPos.Y.Offset + delta.Y
                )
                self.MainFrame.Position = newPos
            elseif self.isResizing and self.dragStart then
                local delta = input.Position - self.dragStart
                local newSize = UDim2.new(
                    self.startSize.X.Scale,
                    math.max(300, self.startSize.X.Offset + delta.X),
                    self.startSize.Y.Scale,
                    math.max(200, self.startSize.Y.Offset + delta.Y)
                )
                self.MainFrame.Size = newSize
                self.originalSize = newSize
            end
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.isDragging = false
            self.isResizing = false
            self.dragStart = nil
        end
    end)
end

function MacSoloUI:ToggleMinimize()
    if self.minimized then
        -- Restore
        TweenService:Create(self.MainFrame, TweenInfo_Smooth, {
            Size = self.originalSize
        }):Play()
        self.minimized = false
        self.ContentFrame.Visible = true
        self.ResizeHandle.Visible = true
    else
        -- Minimize
        TweenService:Create(self.MainFrame, TweenInfo_Smooth, {
            Size = UDim2.new(self.originalSize.X.Scale, self.originalSize.X.Offset, 0, 35)
        }):Play()
        self.minimized = true
        self.ContentFrame.Visible = false
        self.ResizeHandle.Visible = false
    end
end

function MacSoloUI:Close()
    -- Fade out animation
    TweenService:Create(self.MainFrame, TweenInfo_Fast, {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(
            self.MainFrame.Position.X.Scale,
            self.MainFrame.Position.X.Offset + self.MainFrame.Size.X.Offset/2,
            self.MainFrame.Position.Y.Scale,
            self.MainFrame.Position.Y.Offset + self.MainFrame.Size.Y.Offset/2
        )
    }):Play()
    
    wait(0.2)
    self.ScreenGui:Destroy()
end

-- Enhanced UI Components

function MacSoloUI:CreateButton(text, callback, key)
    local container = Instance.new("Frame")
    container.Name = text .. "Container"
    container.Size = UDim2.new(1, -20, 0, 40)
    container.BackgroundTransparency = 1
    container.Parent = self.ContentFrame
    
    local button = Instance.new("TextButton")
    button.Name = text .. "Button"
    button.Size = UDim2.new(1, -10, 1, -5)
    button.Position = UDim2.new(0, 5, 0, 0)
    button.BackgroundColor3 = Colors.Secondary
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Colors.Text
    button.TextSize = 14
    button.Font = Enum.Font.Gotham
    button.Parent = container
    
    -- Button styling
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Colors.Border
    stroke.Thickness = 1
    stroke.Parent = button
    
    -- Button animations and callback
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo_Fast, {
            BackgroundColor3 = Colors.Accent,
            TextColor3 = Colors.Primary
        }):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo_Fast, {
            BackgroundColor3 = Colors.Secondary,
            TextColor3 = Colors.Text
        }):Play()
    end)
    
    button.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
    
    return container
end

function MacSoloUI:CreateToggle(text, defaultValue, callback, key)
    local container = Instance.new("Frame")
    container.Name = text .. "ToggleContainer"
    container.Size = UDim2.new(1, -20, 0, 35)
    container.BackgroundTransparency = 1
    container.Parent = self.ContentFrame
    
    -- Label
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Colors.Text
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    -- Toggle frame
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(0, 50, 0, 25)
    toggleFrame.Position = UDim2.new(1, -55, 0.5, -12.5)
    toggleFrame.BackgroundColor3 = defaultValue and Colors.Success or Colors.Border
    toggleFrame.BorderSizePixel = 0
    toggleFrame.Parent = container
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0.5, 0)
    toggleCorner.Parent = toggleFrame
    
    -- Toggle button
    local toggleButton = Instance.new("Frame")
    toggleButton.Size = UDim2.new(0, 21, 0, 21)
    toggleButton.Position = defaultValue and UDim2.new(1, -23, 0.5, -10.5) or UDim2.new(0, 2, 0.5, -10.5)
    toggleButton.BackgroundColor3 = Colors.Text
    toggleButton.BorderSizePixel = 0
    toggleButton.Parent = toggleFrame
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0.5, 0)
    buttonCorner.Parent = toggleButton
    
    -- Toggle state
    local isToggled = defaultValue
    if key then
        self.configData[key] = isToggled
        if callback then self.configCallbacks[key] = callback end
    end
    
    -- Click detector
    local clickDetector = Instance.new("TextButton")
    clickDetector.Size = UDim2.new(1, 0, 1, 0)
    clickDetector.BackgroundTransparency = 1
    clickDetector.Text = ""
    clickDetector.Parent = toggleFrame
    
    clickDetector.MouseButton1Click:Connect(function()
        isToggled = not isToggled
        
        if key then self.configData[key] = isToggled end
        
        -- Animate toggle
        local newPos = isToggled and UDim2.new(1, -23, 0.5, -10.5) or UDim2.new(0, 2, 0.5, -10.5)
        local newColor = isToggled and Colors.Success or Colors.Border
        
        TweenService:Create(toggleButton, TweenInfo_Fast, {Position = newPos}):Play()
        TweenService:Create(toggleFrame, TweenInfo_Fast, {BackgroundColor3 = newColor}):Play()
        
        if callback then callback(isToggled) end
    end)
    
    return container
end

function MacSoloUI:CreateInput(text, placeholder, callback, key)
    local container = Instance.new("Frame")
    container.Name = text .. "InputContainer"
    container.Size = UDim2.new(1, -20, 0, 60)
    container.BackgroundTransparency = 1
    container.Parent = self.ContentFrame
    
    -- Label
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, 20)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Colors.Text
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    -- Input frame
    local inputFrame = Instance.new("Frame")
    inputFrame.Size = UDim2.new(1, -10, 0, 35)
    inputFrame.Position = UDim2.new(0, 5, 0, 25)
    inputFrame.BackgroundColor3 = Colors.Secondary
    inputFrame.BorderSizePixel = 0
    inputFrame.Parent = container
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = inputFrame
    
    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Colors.Border
    inputStroke.Thickness = 1
    inputStroke.Parent = inputFrame
    
    -- Text input
    local textInput = Instance.new("TextBox")
    textInput.Size = UDim2.new(1, -20, 1, 0)
    textInput.Position = UDim2.new(0, 10, 0, 0)
    textInput.BackgroundTransparency = 1
    textInput.Text = ""
    textInput.PlaceholderText = placeholder or "Enter text..."
    textInput.PlaceholderColor3 = Colors.SubText
    textInput.TextColor3 = Colors.Text
    textInput.TextSize = 14
    textInput.Font = Enum.Font.Gotham
    textInput.TextXAlignment = Enum.TextXAlignment.Left
    textInput.Parent = inputFrame
    
    if key then
        self.configData[key] = ""
        if callback then self.configCallbacks[key] = callback end
    end
    
    -- Focus effects
    textInput.Focused:Connect(function()
        TweenService:Create(inputStroke, TweenInfo_Fast, {Color = Colors.Accent, Thickness = 2}):Play()
    end)
    
    textInput.FocusLost:Connect(function()
        TweenService:Create(inputStroke, TweenInfo_Fast, {Color = Colors.Border, Thickness = 1}):Play()
        if key then self.configData[key] = textInput.Text end
        if callback then callback(textInput.Text) end
    end)
    
    return container
end

function MacSoloUI:CreateDropdown(text, options, defaultOption, callback, key)
    local container = Instance.new("Frame")
    container.Name = text .. "DropdownContainer"
    container.Size = UDim2.new(1, -20, 0, 60)
    container.BackgroundTransparency = 1
    container.Parent = self.ContentFrame
    
    -- Label
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, 20)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Colors.Text
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    -- Dropdown frame
    local dropdownFrame = Instance.new("Frame")
    dropdownFrame.Size = UDim2.new(1, -10, 0, 35)
    dropdownFrame.Position = UDim2.new(0, 5, 0, 25)
    dropdownFrame.BackgroundColor3 = Colors.Secondary
    dropdownFrame.BorderSizePixel = 0
    dropdownFrame.Parent = container
    
    local dropdownCorner = Instance.new("UICorner")
    dropdownCorner.CornerRadius = UDim.new(0, 6)
    dropdownCorner.Parent = dropdownFrame
    
    local dropdownStroke = Instance.new("UIStroke")
    dropdownStroke.Color = Colors.Border
    dropdownStroke.Thickness = 1
    dropdownStroke.Parent = dropdownFrame
    
    -- Selected text
    local selectedText = Instance.new("TextLabel")
    selectedText.Size = UDim2.new(1, -50, 1, 0)
    selectedText.Position = UDim2.new(0, 15, 0, 0)
    selectedText.BackgroundTransparency = 1
    selectedText.Text = defaultOption or options[1] or "Select..."
    selectedText.TextColor3 = Colors.Text
    selectedText.TextSize = 14
    selectedText.Font = Enum.Font.Gotham
    selectedText.TextXAlignment = Enum.TextXAlignment.Left
    selectedText.Parent = dropdownFrame
    
    -- Arrow
    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 30, 1, 0)
    arrow.Position = UDim2.new(1, -30, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.TextColor3 = Colors.SubText
    arrow.TextSize = 12
    arrow.Font = Enum.Font.Gotham
    arrow.Parent = dropdownFrame
    
    -- Options frame
    local optionsFrame = Instance.new("Frame")
    optionsFrame.Size = UDim2.new(1, 0, 0, #options * 30)
    optionsFrame.Position = UDim2.new(0, 0, 1, 5)
    optionsFrame.BackgroundColor3 = Colors.Secondary
    optionsFrame.BorderSizePixel = 0
    optionsFrame.Visible = false
    optionsFrame.ZIndex = 10
    optionsFrame.Parent = dropdownFrame
    
    local optionsCorner = Instance.new("UICorner")
    optionsCorner.CornerRadius = UDim.new(0, 6)
    optionsCorner.Parent = optionsFrame
    
    local optionsStroke = Instance.new("UIStroke")
    optionsStroke.Color = Colors.Border
    optionsStroke.Thickness = 1
    optionsStroke.Parent = optionsFrame
    
    -- Options layout
    local optionsLayout = Instance.new("UIListLayout")
    optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    optionsLayout.Parent = optionsFrame
    
    local selectedValue = defaultOption or options[1]
    if key then
        self.configData[key] = selectedValue
        if callback then self.configCallbacks[key] = callback end
    end
    
    -- Create option buttons
    for i, option in ipairs(options) do
        local optionButton = Instance.new("TextButton")
        optionButton.Size = UDim2.new(1, 0, 0, 30)
        optionButton.BackgroundColor3 = Colors.Secondary
        optionButton.BorderSizePixel = 0
        optionButton.Text = option
        optionButton.TextColor3 = Colors.Text
        optionButton.TextSize = 14
        optionButton.Font = Enum.Font.Gotham
        optionButton.TextXAlignment = Enum.TextXAlignment.Left
        optionButton.Parent = optionsFrame
        
        -- Option padding
        local optionPadding = Instance.new("UIPadding")
        optionPadding.PaddingLeft = UDim.new(0, 15)
        optionPadding.Parent = optionButton
        
        -- Option hover
        optionButton.MouseEnter:Connect(function()
            TweenService:Create(optionButton, TweenInfo_Fast, {BackgroundColor3 = Colors.Accent}):Play()
        end)
        
        optionButton.MouseLeave:Connect(function()
            TweenService:Create(optionButton, TweenInfo_Fast, {BackgroundColor3 = Colors.Secondary}):Play()
        end)
        
        optionButton.MouseButton1Click:Connect(function()
            selectedValue = option
            selectedText.Text = option
            optionsFrame.Visible = false
            
            TweenService:Create(arrow, TweenInfo_Fast, {Rotation = 0}):Play()
            
            if key then self.configData[key] = selectedValue end
            if callback then callback(selectedValue) end
        end)
    end
    
    -- Dropdown click detector
    local clickDetector = Instance.new("TextButton")
    clickDetector.Size = UDim2.new(1, 0, 1, 0)
    clickDetector.BackgroundTransparency = 1
    clickDetector.Text = ""
    clickDetector.Parent = dropdownFrame
    
    clickDetector.MouseButton1Click:Connect(function()
        local isOpen = optionsFrame.Visible
        optionsFrame.Visible = not isOpen
        
        local newRotation = isOpen and 0 or 180
        TweenService:Create(arrow, TweenInfo_Fast, {Rotation = newRotation}):Play()
    end)
    
    return container
end

function MacSoloUI:CreateSlider(text, min, max, defaultValue, callback, key)
    local container = Instance.new("Frame")
    container.Name = text .. "SliderContainer"
    container.Size = UDim2.new(1, -20, 0, 60)
    container.BackgroundTransparency = 1
    container.Parent = self.ContentFrame
    
    -- Label with value
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 0, 20)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Colors.Text
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    -- Value display
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 50, 0, 20)
    valueLabel.Position = UDim2.new(1, -55, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(defaultValue or min)
    valueLabel.TextColor3 = Colors.Gold
    valueLabel.TextSize = 12
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = container
    
    -- Slider track
    local sliderTrack = Instance.new("Frame")
    sliderTrack.Size = UDim2.new(1, -10, 0, 6)
    sliderTrack.Position = UDim2.new(0, 5, 0, 35)
    sliderTrack.BackgroundColor3 = Colors.Border
    sliderTrack.BorderSizePixel = 0
    sliderTrack.Parent = container
    
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0.5, 0)
    trackCorner.Parent = sliderTrack
    
    -- Slider fill
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((defaultValue or min) / (max - min), 0, 1, 0)
    sliderFill.Position = UDim2.new(0, 0, 0, 0)
    sliderFill.BackgroundColor3 = Colors.Accent
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderTrack
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0.5, 0)
    fillCorner.Parent = sliderFill
    
    -- Slider handle
    local sliderHandle = Instance.new("Frame")
    sliderHandle.Size = UDim2.new(0, 16, 0, 16)
    sliderHandle.Position = UDim2.new((defaultValue or min) / (max - min), -8, 0.5, -8)
    sliderHandle.BackgroundColor3 = Colors.Text
    sliderHandle.BorderSizePixel = 0
    sliderHandle.Parent = sliderTrack
    
    local handleCorner = Instance.new("UICorner")
    handleCorner.CornerRadius = UDim.new(0.5, 0)
    handleCorner.Parent = sliderHandle
    
    -- Slider interaction
    local isDragging = false
    local currentValue = defaultValue or min
    
    if key then
        self.configData[key] = currentValue
        if callback then self.configCallbacks[key] = callback end
    end
    
    local function updateSlider(input)
        local relativePos = math.clamp((input.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1)
        currentValue = math.floor(min + (max - min) * relativePos)
        
        valueLabel.Text = tostring(currentValue)
        
        TweenService:Create(sliderFill, TweenInfo_Fast, {Size = UDim2.new(relativePos, 0, 1, 0)}):Play()
        TweenService:Create(sliderHandle, TweenInfo_Fast, {Position = UDim2.new(relativePos, -8, 0.5, -8)}):Play()
        
        if key then self.configData[key] = currentValue end
        if callback then callback(currentValue) end
    end
    
    sliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            updateSlider(input)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)
    
    return container
end

function MacSoloUI:CreateLabel(text)
    local container = Instance.new("Frame")
    container.Name = text .. "LabelContainer"
    container.Size = UDim2.new(1, -20, 0, 25)
    container.BackgroundTransparency = 1
    container.Parent = self.ContentFrame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Colors.Text
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = container
    
    return container
end

function MacSoloUI:CreateSection(title)
    local container = Instance.new("Frame")
    container.Name = title .. "SectionContainer"
    container.Size = UDim2.new(1, -20, 0, 40)
    container.BackgroundTransparency = 1
    container.Parent = self.ContentFrame
    
    -- Section line
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, -10, 0, 1)
    line.Position = UDim2.new(0, 5, 0.5, 0)
    line.BackgroundColor3 = Colors.Border
    line.BorderSizePixel = 0
    line.Parent = container
    
    -- Section title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0, 0, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.BackgroundColor3 = Colors.Primary
    titleLabel.BorderSizePixel = 0
    titleLabel.Text = " " .. title .. " "
    titleLabel.TextColor3 = Colors.Gold
    titleLabel.TextSize = 12
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.AutomaticSize = Enum.AutomaticSize.X
    titleLabel.Parent = container
    
    return container
end

-- Config Management Functions
function MacSoloUI:SaveCurrentConfig(configName)
    if not configName or configName == "" then
        configName = "default"
    end
    
    local success = ConfigManager:SaveConfig(configName, self.configData)
    
    if success then
        -- Visual feedback
        local notification = self:ShowNotification("Config '" .. configName .. "' saved!", Colors.Success)
    end
    
    return success
end

function MacSoloUI:LoadConfig(configName)
    if not configName or configName == "" then
        configName = "default"
    end
    
    local data = ConfigManager:LoadConfig(configName)
    
    if data and next(data) then
        self.configData = data
        
        -- Apply loaded values to UI elements
        for key, value in pairs(data) do
            if self.configCallbacks[key] then
                self.configCallbacks[key](value)
            end
        end
        
        local notification = self:ShowNotification("Config '" .. configName .. "' loaded!", Colors.Success)
    else
        local notification = self:ShowNotification("Config '" .. configName .. "' not found!", Colors.Error)
    end
end

function MacSoloUI:ShowNotification(text, color)
    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(0, 250, 0, 40)
    notification.Position = UDim2.new(1, -260, 0, 50)
    notification.BackgroundColor3 = color or Colors.Accent
    notification.BorderSizePixel = 0
    notification.Parent = self.ScreenGui
    
    local notifCorner = Instance.new("UICorner")
    notifCorner.CornerRadius = UDim.new(0, 8)
    notifCorner.Parent = notification
    
    local notifText = Instance.new("TextLabel")
    notifText.Size = UDim2.new(1, -20, 1, 0)
    notifText.Position = UDim2.new(0, 10, 0, 0)
    notifText.BackgroundTransparency = 1
    notifText.Text = text
    notifText.TextColor3 = Colors.Text
    notifText.TextSize = 12
    notifText.Font = Enum.Font.Gotham
    notifText.TextXAlignment = Enum.TextXAlignment.Left
    notifText.Parent = notification
    
    -- Slide in
    notification.Position = UDim2.new(1, 10, 0, 50)
    TweenService:Create(notification, TweenInfo_Smooth, {Position = UDim2.new(1, -260, 0, 50)}):Play()
    
    -- Auto hide after 3 seconds
    wait(3)
    TweenService:Create(notification, TweenInfo_Smooth, {Position = UDim2.new(1, 10, 0, 50)}):Play()
    wait(0.3)
    notification:Destroy()
end

function MacSoloUI:GetConfigList()
    return ConfigManager:GetConfigList()
end

function MacSoloUI:SetTitle(title)
    self.title = title
    self.TitleLabel.Text = title
end

-- Example usage function
local function CreateAdvancedExample()
    local ui = MacSoloUI.new("Solo Leveling Advanced UI", UDim2.new(0, 600, 0, 500))
    
    -- Header section
    ui:CreateSection("Player Settings")
    
    -- Toggle examples
    ui:CreateToggle("Auto Farm", false, function(value)
        print("Auto Farm:", value)
    end, "autoFarm")
    
    ui:CreateToggle("God Mode", false, function(value)
        print("God Mode:", value)
    end, "godMode")
    
    -- Input examples
    ui:CreateInput("Player Name", "Enter your name...", function(text)
        print("Player Name:", text)
    end, "playerName")
    
    ui:CreateInput("Target Level", "Enter target level...", function(text)
        print("Target Level:", text)
    end, "targetLevel")
    
    -- Dropdown example
    ui:CreateDropdown("Weapon Type", {"Sword", "Dagger", "Staff", "Bow"}, "Sword", function(selected)
        print("Weapon Type:", selected)
    end, "weaponType")
    
    ui:CreateDropdown("Difficulty", {"Easy", "Normal", "Hard", "Nightmare"}, "Normal", function(selected)
        print("Difficulty:", selected)
    end, "difficulty")
    
    -- Slider examples
    ui:CreateSection("Combat Settings")
    
    ui:CreateSlider("Attack Speed", 1, 10, 5, function(value)
        print("Attack Speed:", value)
    end, "attackSpeed")
    
    ui:CreateSlider("Health Multiplier", 1, 20, 1, function(value)
        print("Health Multiplier:", value)
    end, "healthMultiplier")
    
    -- Buttons
    ui:CreateSection("Actions")
    
    ui:CreateButton("Start Leveling", function()
        print("Started leveling with config:", ui.configData)
    end)
    
    ui:CreateButton("Reset Progress", function()
        print("Progress reset!")
    end)
    
    return ui
end

-- Export the library
return {
    MacSoloUI = MacSoloUI,
    ConfigManager = ConfigManager,
    Colors = Colors,
    CreateAdvancedExample = CreateAdvancedExample
}
