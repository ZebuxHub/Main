-- Mac-Style Solo Leveling UI Library for Roblox
-- Combines macOS window aesthetics with Solo Leveling dark theme

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

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
    Close = Color3.fromRGB(255, 95, 86),       -- Red close button
    Minimize = Color3.fromRGB(255, 189, 46),   -- Yellow minimize
    Maximize = Color3.fromRGB(39, 201, 63)     -- Green maximize
}

-- Tween configurations
local TweenInfo_Fast = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TweenInfo_Smooth = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

function MacSoloUI.new(title, size, position)
    local self = setmetatable({}, MacSoloUI)
    
    -- Default values
    self.title = title or "Solo Leveling UI"
    self.size = size or UDim2.new(0, 400, 0, 300)
    self.position = position or UDim2.new(0.5, -200, 0.5, -150)
    self.minimized = false
    self.originalSize = self.size
    self.isDragging = false
    self.isResizing = false
    self.dragStart = nil
    self.startPos = nil
    
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
    
    -- Drop shadow effect
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    shadow.ImageColor3 = Color3.new(0, 0, 0)
    shadow.ImageTransparency = 0.8
    shadow.ZIndex = -1
    shadow.Parent = self.MainFrame
    
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
    self.TitleLabel.Size = UDim2.new(1, -200, 1, 0)
    self.TitleLabel.Position = UDim2.new(0, 100, 0, 0)
    self.TitleLabel.BackgroundTransparency = 1
    self.TitleLabel.Text = self.title
    self.TitleLabel.TextColor3 = Colors.Text
    self.TitleLabel.TextScaled = false
    self.TitleLabel.TextSize = 14
    self.TitleLabel.Font = Enum.Font.GothamSemibold
    self.TitleLabel.TextXAlignment = Enum.TextXAlignment.Center
    self.TitleLabel.Parent = self.TitleBar
    
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
    
    -- Resize handle visual indicator
    local resizeIndicator = Instance.new("Frame")
    resizeIndicator.Size = UDim2.new(0, 2, 0, 8)
    resizeIndicator.Position = UDim2.new(0, 8, 0, 3)
    resizeIndicator.BackgroundColor3 = Colors.SubText
    resizeIndicator.BorderSizePixel = 0
    resizeIndicator.Parent = self.ResizeHandle
    
    local resizeIndicator2 = Instance.new("Frame")
    resizeIndicator2.Size = UDim2.new(0, 8, 0, 2)
    resizeIndicator2.Position = UDim2.new(0, 3, 0, 8)
    resizeIndicator2.BackgroundColor3 = Colors.SubText
    resizeIndicator2.BorderSizePixel = 0
    resizeIndicator2.Parent = self.ResizeHandle
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
                    math.max(200, self.startSize.X.Offset + delta.X),
                    self.startSize.Y.Scale,
                    math.max(150, self.startSize.Y.Offset + delta.Y)
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

function MacSoloUI:SetTitle(title)
    self.title = title
    self.TitleLabel.Text = title
end

function MacSoloUI:AddContent(content)
    if typeof(content) == "Instance" then
        content.Parent = self.ContentFrame
    end
end

function MacSoloUI:CreateButton(text, callback, position, size)
    local button = Instance.new("TextButton")
    button.Name = text .. "Button"
    button.Size = size or UDim2.new(0, 120, 0, 35)
    button.Position = position or UDim2.new(0, 10, 0, 10)
    button.BackgroundColor3 = Colors.Secondary
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Colors.Text
    button.TextSize = 14
    button.Font = Enum.Font.Gotham
    button.Parent = self.ContentFrame
    
    -- Button styling
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Colors.Border
    stroke.Thickness = 1
    stroke.Parent = button
    
    -- Button animations
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
        -- Click animation
        TweenService:Create(button, TweenInfo.new(0.1), {Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset - 4, button.Size.Y.Scale, button.Size.Y.Offset - 2)}):Play()
        wait(0.1)
        TweenService:Create(button, TweenInfo.new(0.1), {Size = size or UDim2.new(0, 120, 0, 35)}):Play()
        
        if callback then
            callback()
        end
    end)
    
    return button
end

function MacSoloUI:CreateLabel(text, position, size)
    local label = Instance.new("TextLabel")
    label.Name = text .. "Label"
    label.Size = size or UDim2.new(1, -20, 0, 25)
    label.Position = position or UDim2.new(0, 10, 0, 10)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Colors.Text
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = self.ContentFrame
    
    return label
end

-- Example usage
local function CreateExampleUI()
    local ui = MacSoloUI.new("Solo Leveling System", UDim2.new(0, 450, 0, 350))
    
    ui:CreateLabel("Welcome to Solo Leveling UI", UDim2.new(0, 10, 0, 10))
    ui:CreateLabel("A Mac-style interface with Solo Leveling aesthetics", UDim2.new(0, 10, 0, 40))
    
    ui:CreateButton("Level Up", function()
        print("Level up clicked!")
    end, UDim2.new(0, 10, 0, 80))
    
    ui:CreateButton("Inventory", function()
        print("Inventory opened!")
    end, UDim2.new(0, 140, 0, 80))
    
    ui:CreateButton("Skills", function()
        print("Skills menu opened!")
    end, UDim2.new(0, 270, 0, 80))
    
    return ui
end

-- Export the library
return {
    MacSoloUI = MacSoloUI,
    CreateExample = CreateExampleUI,
    Colors = Colors
}
