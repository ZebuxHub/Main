-- ToggleUI.lua - Standalone Toggle Button for Build A Zoo UI
-- Author: Zebux
-- Version: 1.0

local ToggleUI = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Variables
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local toggleScreenGui = nil
local toggleButton = nil
local isDragging = false
local dragStart = nil
local startPos = nil

-- UI State
local isMainUIVisible = true
local mainWindow = nil

-- Colors (Dark theme matching Build A Zoo)
local colors = {
    background = Color3.fromRGB(28, 28, 30),
    surface = Color3.fromRGB(44, 44, 46),
    primary = Color3.fromRGB(10, 132, 255),
    primaryHover = Color3.fromRGB(64, 156, 255),
    text = Color3.fromRGB(255, 255, 255),
    textSecondary = Color3.fromRGB(174, 174, 178),
    border = Color3.fromRGB(58, 58, 60),
    green = Color3.fromRGB(52, 199, 89),
    red = Color3.fromRGB(255, 69, 58)
}

-- Create the toggle button ScreenGUI
local function createToggleUI()
    if toggleScreenGui then
        toggleScreenGui:Destroy()
    end
    
    -- Create ScreenGUI
    toggleScreenGui = Instance.new("ScreenGui")
    toggleScreenGui.Name = "BuildAZooToggle"
    toggleScreenGui.ResetOnSpawn = false
    toggleScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    toggleScreenGui.Parent = PlayerGui
    
    -- Create main toggle button
    toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Size = UDim2.new(0, 60, 0, 60)
    toggleButton.Position = UDim2.new(0, 20, 0.5, -30) -- Left side, center vertically
    toggleButton.BackgroundColor3 = colors.primary
    toggleButton.BorderSizePixel = 0
    toggleButton.Text = "🏗️"
    toggleButton.TextSize = 24
    toggleButton.Font = Enum.Font.GothamSemibold
    toggleButton.TextColor3 = colors.text
    toggleButton.AutoButtonColor = false
    toggleButton.Parent = toggleScreenGui
    
    -- Corner radius for modern look
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = toggleButton
    
    -- Stroke for better visibility
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 2
    stroke.Parent = toggleButton
    
    -- Gradient effect
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 132, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 144, 255))
    }
    gradient.Rotation = 45
    gradient.Parent = toggleButton
    
    -- Status indicator (small dot showing UI state)
    local statusDot = Instance.new("Frame")
    statusDot.Name = "StatusDot"
    statusDot.Size = UDim2.new(0, 12, 0, 12)
    statusDot.Position = UDim2.new(1, -16, 0, 4)
    statusDot.BackgroundColor3 = colors.green
    statusDot.BorderSizePixel = 0
    statusDot.Parent = toggleButton
    
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(0.5, 0) -- Make it circular
    dotCorner.Parent = statusDot
    
    -- Tooltip label
    local tooltip = Instance.new("TextLabel")
    tooltip.Name = "Tooltip"
    tooltip.Size = UDim2.new(0, 120, 0, 30)
    tooltip.Position = UDim2.new(1, 10, 0.5, -15)
    tooltip.BackgroundColor3 = colors.surface
    tooltip.BorderSizePixel = 0
    tooltip.Text = "Build A Zoo UI"
    tooltip.TextSize = 12
    tooltip.Font = Enum.Font.Gotham
    tooltip.TextColor3 = colors.text
    tooltip.TextXAlignment = Enum.TextXAlignment.Left
    tooltip.Visible = false
    tooltip.Parent = toggleButton
    
    local tooltipCorner = Instance.new("UICorner")
    tooltipCorner.CornerRadius = UDim.new(0, 8)
    tooltipCorner.Parent = tooltip
    
    local tooltipPadding = Instance.new("UIPadding")
    tooltipPadding.PaddingLeft = UDim.new(0, 8)
    tooltipPadding.PaddingRight = UDim.new(0, 8)
    tooltipPadding.Parent = tooltip
    
    return toggleButton
end

-- Update status indicator based on UI state
local function updateStatusIndicator()
    if not toggleButton then return end
    
    local statusDot = toggleButton:FindFirstChild("StatusDot")
    if statusDot then
        statusDot.BackgroundColor3 = isMainUIVisible and colors.green or colors.red
    end
    
    local tooltip = toggleButton:FindFirstChild("Tooltip")
    if tooltip then
        tooltip.Text = isMainUIVisible and "Hide Build A Zoo" or "Show Build A Zoo"
    end
end

-- Show a temporary notification
local function showNotification(text)
    local notification = Instance.new("TextLabel")
    notification.Name = "Notification"
    notification.Size = UDim2.new(0, 200, 0, 40)
    notification.Position = UDim2.new(0, 90, 0.5, -20)
    notification.BackgroundColor3 = colors.surface
    notification.BorderSizePixel = 0
    notification.Text = text
    notification.TextSize = 14
    notification.Font = Enum.Font.GothamSemibold
    notification.TextColor3 = colors.text
    notification.TextXAlignment = Enum.TextXAlignment.Center
    notification.Parent = toggleScreenGui
    
    local notifCorner = Instance.new("UICorner")
    notifCorner.CornerRadius = UDim.new(0, 8)
    notifCorner.Parent = notification
    
    local notifStroke = Instance.new("UIStroke")
    notifStroke.Color = colors.border
    notifStroke.Thickness = 1
    notifStroke.Parent = notification
    
    -- Animate in
    notification.BackgroundTransparency = 1
    notification.TextTransparency = 1
    
    local fadeIn = TweenService:Create(
        notification,
        TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0.1, TextTransparency = 0}
    )
    fadeIn:Play()
    
    -- Auto-hide after 2 seconds
    task.spawn(function()
        task.wait(2)
        if notification and notification.Parent then
            local fadeOut = TweenService:Create(
                notification,
                TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {BackgroundTransparency = 1, TextTransparency = 1}
            )
            fadeOut:Play()
            fadeOut.Completed:Connect(function()
                notification:Destroy()
            end)
        end
    end)
end

-- Toggle the main UI visibility
local function toggleMainUI()
    -- Try to find the main WindUI window
    if not mainWindow then
        -- Look for WindUI window in PlayerGui
        for _, gui in ipairs(PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name:find("WindUI") then
                mainWindow = gui
                break
            end
        end
    end
    
    if mainWindow then
        -- Toggle visibility
        isMainUIVisible = not isMainUIVisible
        mainWindow.Enabled = isMainUIVisible
        
        -- Update visual feedback
        updateStatusIndicator()
        
        -- Create tween effect for button
        local targetColor = isMainUIVisible and colors.primary or colors.red
        local tween = TweenService:Create(
            toggleButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {BackgroundColor3 = targetColor}
        )
        tween:Play()
        
        -- Show feedback
        local feedbackText = isMainUIVisible and "UI Shown" or "UI Hidden"
        showNotification(feedbackText)
    else
        -- If main window not found, try to reload the script
        showNotification("Reloading Build A Zoo...")
        task.wait(0.5)
        -- This would trigger a reload of the main script
        if _G.BuildAZooReload then
            _G.BuildAZooReload()
        end
    end
end

-- Setup button interactions
local function setupButtonEvents(button)
    -- Hover effects
    button.MouseEnter:Connect(function()
        local tooltip = button:FindFirstChild("Tooltip")
        if tooltip then
            tooltip.Visible = true
        end
        
        -- Hover animation
        local hoverTween = TweenService:Create(
            button,
            TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 65, 0, 65)}
        )
        hoverTween:Play()
    end)
    
    button.MouseLeave:Connect(function()
        local tooltip = button:FindFirstChild("Tooltip")
        if tooltip then
            tooltip.Visible = false
        end
        
        -- Restore size
        local restoreTween = TweenService:Create(
            button,
            TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 60, 0, 60)}
        )
        restoreTween:Play()
    end)
    
    -- Click effect
    button.MouseButton1Click:Connect(function()
        -- Click animation
        local clickTween = TweenService:Create(
            button,
            TweenInfo.new(0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 55, 0, 55)}
        )
        clickTween:Play()
        
        clickTween.Completed:Connect(function()
            local restoreTween = TweenService:Create(
                button,
                TweenInfo.new(0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {Size = UDim2.new(0, 60, 0, 60)}
            )
            restoreTween:Play()
        end)
        
        -- Toggle the main UI
        toggleMainUI()
    end)
    
    -- Dragging functionality
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            startPos = button.Position
        end
    end)
    
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Main initialization function
function ToggleUI.Initialize()
    local button = createToggleUI()
    setupButtonEvents(button)
    updateStatusIndicator()
    
    -- Show initial notification
    task.wait(0.5)
    showNotification("Toggle UI Ready!")
    
    return toggleScreenGui
end

-- Function to update main window reference
function ToggleUI.SetMainWindow(window)
    mainWindow = window
    if window then
        isMainUIVisible = window.Enabled
        updateStatusIndicator()
    end
end

-- Function to destroy the toggle UI
function ToggleUI.Destroy()
    if toggleScreenGui then
        toggleScreenGui:Destroy()
        toggleScreenGui = nil
        toggleButton = nil
    end
end

-- Cleanup on player leaving
LocalPlayer.AncestryChanged:Connect(function()
    if not LocalPlayer.Parent then
        ToggleUI.Destroy()
    end
end)

return ToggleUI
