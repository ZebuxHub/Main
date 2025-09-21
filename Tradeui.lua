-- TradeUI.lua - Custom Auto Trade Interface for Build A Zoo
-- Author: Zebux
-- Version: 1.0

local TradeUI = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local WindUI = nil
local Config = nil
local SendTrashSystem = nil

-- UI Variables
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ScreenGui = nil
local MainFrame = nil
local isDragging = false
local dragStart = nil
local startPos = nil
local isMinimized = false
local originalSize = nil
local minimizedSize = nil
local currentPage = "pets" -- "pets", "eggs", "fruits"
local searchText = ""

-- Trade settings
local selectedTarget = "Random Player"
local tradeSettings = {
    pets = {},
    eggs = {},
    fruits = {}
}
local autoTradeEnabled = false
local savedPlayerPosition = nil

-- macOS Dark Theme Colors
local colors = {
    background = Color3.fromRGB(18, 18, 20),
    surface = Color3.fromRGB(32, 32, 34),
    primary = Color3.fromRGB(0, 122, 255),
    secondary = Color3.fromRGB(88, 86, 214),
    text = Color3.fromRGB(255, 255, 255),
    textSecondary = Color3.fromRGB(200, 200, 200),
    textTertiary = Color3.fromRGB(150, 150, 150),
    border = Color3.fromRGB(50, 50, 52),
    selected = Color3.fromRGB(0, 122, 255),
    hover = Color3.fromRGB(45, 45, 47),
    pageActive = Color3.fromRGB(0, 122, 255),
    pageInactive = Color3.fromRGB(60, 60, 62),
    close = Color3.fromRGB(255, 69, 58),
    minimize = Color3.fromRGB(255, 159, 10),
    maximize = Color3.fromRGB(48, 209, 88),
    success = Color3.fromRGB(48, 209, 88),
    warning = Color3.fromRGB(255, 159, 10),
    error = Color3.fromRGB(255, 69, 58)
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

-- Get player list for target selection
local function getPlayerList()
    local playerList = {"Random Player"}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerList, player.Name)
        end
    end
    
    return playerList
end

-- Get player avatar thumbnail
local function getPlayerAvatar(player)
    if not player then return nil end
    
    local success, result = pcall(function()
        return Players:GetUserThumbnailAsync(
            player.UserId,
            Enum.ThumbnailType.AvatarBust,
            Enum.ThumbnailSize.Size100x100
        )
    end)
    
    return success and result or "rbxasset://textures/ui/GuiImagePlaceholder.png"
end

-- Save/Load player position for teleportation
local function savePlayerPosition()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        savedPlayerPosition = LocalPlayer.Character.HumanoidRootPart.CFrame
    end
end

local function restorePlayerPosition()
    if savedPlayerPosition and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = savedPlayerPosition
    end
end

-- Teleport near target player
local function teleportNearTarget(targetPlayer)
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local targetPosition = targetPlayer.Character.HumanoidRootPart.CFrame
    local nearPosition = targetPosition * CFrame.new(5, 0, 0) -- 5 studs away
    
    LocalPlayer.Character.HumanoidRootPart.CFrame = nearPosition
    return true
end

-- Focus item before sending
local function focusItem(itemUID)
    local success, err = pcall(function()
        local args = {"Focus", itemUID}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    return success
end

-- Send item to target player
local function sendItemToTarget(itemUID, targetPlayer, itemType)
    if not targetPlayer or targetPlayer.Parent ~= Players then
        return false
    end
    
    -- Save current position
    savePlayerPosition()
    
    -- Teleport near target
    if not teleportNearTarget(targetPlayer) then
        return false
    end
    
    task.wait(0.5) -- Wait for teleport
    
    -- Focus the item
    if not focusItem(itemUID) then
        restorePlayerPosition()
        return false
    end
    
    task.wait(0.2) -- Wait for focus
    
    -- Send the item
    local success = pcall(function()
        local args = {targetPlayer}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(unpack(args))
    end)
    
    task.wait(0.5) -- Wait for send
    
    -- Restore position
    restorePlayerPosition()
    
    if success and WindUI then
        WindUI:Notify({
            Title = "✅ Item Sent",
            Content = string.format("%s sent to %s", itemType, targetPlayer.Name),
            Duration = 3
        })
    end
    
    return success
end

-- Create macOS Style Window Controls
local function createWindowControls(parent)
    local controlsContainer = Instance.new("Frame")
    controlsContainer.Name = "WindowControls"
    controlsContainer.Size = UDim2.new(0, 70, 0, 12)
    controlsContainer.Position = UDim2.new(0, 12, 0, 12)
    controlsContainer.BackgroundTransparency = 1
    controlsContainer.Parent = parent
    
    -- Close Button (Red)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 12, 0, 12)
    closeBtn.Position = UDim2.new(0, 0, 0, 0)
    closeBtn.BackgroundColor3 = colors.close
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = ""
    closeBtn.Parent = controlsContainer
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0.5, 0)
    closeCorner.Parent = closeBtn
    
    -- Minimize Button (Yellow)
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Name = "MinimizeBtn"
    minimizeBtn.Size = UDim2.new(0, 12, 0, 12)
    minimizeBtn.Position = UDim2.new(0, 18, 0, 0)
    minimizeBtn.BackgroundColor3 = colors.minimize
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Text = ""
    minimizeBtn.Parent = controlsContainer
    
    local minimizeCorner = Instance.new("UICorner")
    minimizeCorner.CornerRadius = UDim.new(0.5, 0)
    minimizeCorner.Parent = minimizeBtn
    
    -- Maximize Button (Green)
    local maximizeBtn = Instance.new("TextButton")
    maximizeBtn.Name = "MaximizeBtn"
    maximizeBtn.Size = UDim2.new(0, 12, 0, 12)
    maximizeBtn.Position = UDim2.new(0, 36, 0, 0)
    maximizeBtn.BackgroundColor3 = colors.maximize
    maximizeBtn.BorderSizePixel = 0
    maximizeBtn.Text = ""
    maximizeBtn.Parent = controlsContainer
    
    local maximizeCorner = Instance.new("UICorner")
    maximizeCorner.CornerRadius = UDim.new(0.5, 0)
    maximizeCorner.Parent = maximizeBtn
    
    return controlsContainer
end

-- Create Target Selection Panel
local function createTargetPanel(parent)
    local targetPanel = Instance.new("Frame")
    targetPanel.Name = "TargetPanel"
    targetPanel.Size = UDim2.new(0.3, -8, 1, -40)
    targetPanel.Position = UDim2.new(0, 8, 0, 40)
    targetPanel.BackgroundColor3 = colors.surface
    targetPanel.BorderSizePixel = 0
    targetPanel.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = targetPanel
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = targetPanel
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -16, 0, 30)
    title.Position = UDim2.new(0, 8, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "Target Player"
    title.TextSize = 16
    title.Font = Enum.Font.GothamSemibold
    title.TextColor3 = colors.text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = targetPanel
    
    -- Player Avatar
    local avatarFrame = Instance.new("Frame")
    avatarFrame.Name = "AvatarFrame"
    avatarFrame.Size = UDim2.new(0, 80, 0, 80)
    avatarFrame.Position = UDim2.new(0.5, -40, 0, 50)
    avatarFrame.BackgroundColor3 = colors.background
    avatarFrame.BorderSizePixel = 0
    avatarFrame.Parent = targetPanel
    
    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(0, 8)
    avatarCorner.Parent = avatarFrame
    
    local avatarImage = Instance.new("ImageLabel")
    avatarImage.Name = "AvatarImage"
    avatarImage.Size = UDim2.new(1, -4, 1, -4)
    avatarImage.Position = UDim2.new(0, 2, 0, 2)
    avatarImage.BackgroundTransparency = 1
    avatarImage.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    avatarImage.ScaleType = Enum.ScaleType.Crop
    avatarImage.Parent = avatarFrame
    
    local avatarImageCorner = Instance.new("UICorner")
    avatarImageCorner.CornerRadius = UDim.new(0, 6)
    avatarImageCorner.Parent = avatarImage
    
    -- Player Name
    local playerName = Instance.new("TextLabel")
    playerName.Name = "PlayerName"
    playerName.Size = UDim2.new(1, -16, 0, 25)
    playerName.Position = UDim2.new(0, 8, 0, 140)
    playerName.BackgroundTransparency = 1
    playerName.Text = "Random Player"
    playerName.TextSize = 14
    playerName.Font = Enum.Font.GothamSemibold
    playerName.TextColor3 = colors.text
    playerName.TextXAlignment = Enum.TextXAlignment.Center
    playerName.Parent = targetPanel
    
    -- Player List Scroll
    local playerListFrame = Instance.new("Frame")
    playerListFrame.Name = "PlayerListFrame"
    playerListFrame.Size = UDim2.new(1, -16, 1, -180)
    playerListFrame.Position = UDim2.new(0, 8, 0, 170)
    playerListFrame.BackgroundColor3 = colors.background
    playerListFrame.BorderSizePixel = 0
    playerListFrame.Parent = targetPanel
    
    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 6)
    listCorner.Parent = playerListFrame
    
    local playerScroll = Instance.new("ScrollingFrame")
    playerScroll.Name = "PlayerScroll"
    playerScroll.Size = UDim2.new(1, 0, 1, 0)
    playerScroll.BackgroundTransparency = 1
    playerScroll.ScrollBarThickness = 4
    playerScroll.ScrollBarImageColor3 = colors.primary
    playerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    playerScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    playerScroll.Parent = playerListFrame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = playerScroll
    
    -- Refresh Players Button
    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Name = "RefreshBtn"
    refreshBtn.Size = UDim2.new(1, -16, 0, 30)
    refreshBtn.Position = UDim2.new(0, 8, 1, -38)
    refreshBtn.BackgroundColor3 = colors.primary
    refreshBtn.BorderSizePixel = 0
    refreshBtn.Text = "🔄 Refresh Players"
    refreshBtn.TextSize = 12
    refreshBtn.Font = Enum.Font.GothamSemibold
    refreshBtn.TextColor3 = colors.text
    refreshBtn.Parent = targetPanel
    
    local refreshCorner = Instance.new("UICorner")
    refreshCorner.CornerRadius = UDim.new(0, 6)
    refreshCorner.Parent = refreshBtn
    
    -- Function to update player list
    local function updatePlayerList()
        -- Clear existing players
        for _, child in pairs(playerScroll:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        local playerList = getPlayerList()
        
        for i, playerNameStr in ipairs(playerList) do
            local playerBtn = Instance.new("TextButton")
            playerBtn.Name = "Player_" .. i
            playerBtn.Size = UDim2.new(1, -8, 0, 25)
            playerBtn.BackgroundColor3 = (playerNameStr == selectedTarget) and colors.selected or colors.surface
            playerBtn.BorderSizePixel = 0
            playerBtn.Text = playerNameStr
            playerBtn.TextSize = 11
            playerBtn.Font = Enum.Font.Gotham
            playerBtn.TextColor3 = colors.text
            playerBtn.TextXAlignment = Enum.TextXAlignment.Left
            playerBtn.LayoutOrder = i
            playerBtn.Parent = playerScroll
            
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 4)
            btnCorner.Parent = playerBtn
            
            local padding = Instance.new("UIPadding")
            padding.PaddingLeft = UDim.new(0, 8)
            padding.Parent = playerBtn
            
            -- Click event
            playerBtn.MouseButton1Click:Connect(function()
                selectedTarget = playerNameStr
                playerName.Text = playerNameStr
                
                -- Update avatar
                if playerNameStr ~= "Random Player" then
                    local targetPlayer = Players:FindFirstChild(playerNameStr)
                    if targetPlayer then
                        avatarImage.Image = getPlayerAvatar(targetPlayer)
                    end
                else
                    avatarImage.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
                end
                
                -- Update button colors
                for _, btn in pairs(playerScroll:GetChildren()) do
                    if btn:IsA("TextButton") then
                        btn.BackgroundColor3 = (btn.Text == selectedTarget) and colors.selected or colors.surface
                    end
                end
            end)
            
            -- Hover effects
            playerBtn.MouseEnter:Connect(function()
                if playerNameStr ~= selectedTarget then
                    TweenService:Create(playerBtn, TweenInfo.new(0.2), {BackgroundColor3 = colors.hover}):Play()
                end
            end)
            
            playerBtn.MouseLeave:Connect(function()
                if playerNameStr ~= selectedTarget then
                    TweenService:Create(playerBtn, TweenInfo.new(0.2), {BackgroundColor3 = colors.surface}):Play()
                end
            end)
        end
    end
    
    -- Refresh button click
    refreshBtn.MouseButton1Click:Connect(function()
        updatePlayerList()
        if WindUI then
            WindUI:Notify({
                Title = "🔄 Players Refreshed",
                Content = "Player list updated successfully",
                Duration = 2
            })
        end
    end)
    
    -- Initial load
    updatePlayerList()
    
    return targetPanel
end

-- Create Page Tabs
local function createPageTabs(parent)
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "PageTabs"
    tabContainer.Size = UDim2.new(0.7, -16, 0, 40)
    tabContainer.Position = UDim2.new(0.3, 8, 0, 40)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = parent
    
    local petsTab = Instance.new("TextButton")
    petsTab.Name = "PetsTab"
    petsTab.Size = UDim2.new(0.33, -4, 1, 0)
    petsTab.Position = UDim2.new(0, 0, 0, 0)
    petsTab.BackgroundColor3 = colors.pageActive
    petsTab.BorderSizePixel = 0
    petsTab.Text = "🐾 Pets"
    petsTab.TextSize = 14
    petsTab.Font = Enum.Font.GothamSemibold
    petsTab.TextColor3 = colors.text
    petsTab.Parent = tabContainer
    
    local petsCorner = Instance.new("UICorner")
    petsCorner.CornerRadius = UDim.new(0, 6)
    petsCorner.Parent = petsTab
    
    local eggsTab = Instance.new("TextButton")
    eggsTab.Name = "EggsTab"
    eggsTab.Size = UDim2.new(0.33, -4, 1, 0)
    eggsTab.Position = UDim2.new(0.33, 2, 0, 0)
    eggsTab.BackgroundColor3 = colors.pageInactive
    eggsTab.BorderSizePixel = 0
    eggsTab.Text = "🥚 Eggs"
    eggsTab.TextSize = 14
    eggsTab.Font = Enum.Font.GothamSemibold
    eggsTab.TextColor3 = colors.text
    eggsTab.Parent = tabContainer
    
    local eggsCorner = Instance.new("UICorner")
    eggsCorner.CornerRadius = UDim.new(0, 6)
    eggsCorner.Parent = eggsTab
    
    local fruitsTab = Instance.new("TextButton")
    fruitsTab.Name = "FruitsTab"
    fruitsTab.Size = UDim2.new(0.33, -4, 1, 0)
    fruitsTab.Position = UDim2.new(0.66, 4, 0, 0)
    fruitsTab.BackgroundColor3 = colors.pageInactive
    fruitsTab.BorderSizePixel = 0
    fruitsTab.Text = "🍎 Fruits"
    fruitsTab.TextSize = 14
    fruitsTab.Font = Enum.Font.GothamSemibold
    fruitsTab.TextColor3 = colors.text
    fruitsTab.Parent = tabContainer
    
    local fruitsCorner = Instance.new("UICorner")
    fruitsCorner.CornerRadius = UDim.new(0, 6)
    fruitsCorner.Parent = fruitsTab
    
    -- Tab click events
    petsTab.MouseButton1Click:Connect(function()
        currentPage = "pets"
        petsTab.BackgroundColor3 = colors.pageActive
        eggsTab.BackgroundColor3 = colors.pageInactive
        fruitsTab.BackgroundColor3 = colors.pageInactive
        TradeUI.RefreshContent()
    end)
    
    eggsTab.MouseButton1Click:Connect(function()
        currentPage = "eggs"
        eggsTab.BackgroundColor3 = colors.pageActive
        petsTab.BackgroundColor3 = colors.pageInactive
        fruitsTab.BackgroundColor3 = colors.pageInactive
        TradeUI.RefreshContent()
    end)
    
    fruitsTab.MouseButton1Click:Connect(function()
        currentPage = "fruits"
        fruitsTab.BackgroundColor3 = colors.pageActive
        petsTab.BackgroundColor3 = colors.pageInactive
        eggsTab.BackgroundColor3 = colors.pageInactive
        TradeUI.RefreshContent()
    end)
    
    return tabContainer
end

-- Create Search Bar
local function createSearchBar(parent)
    local searchContainer = Instance.new("Frame")
    searchContainer.Name = "SearchContainer"
    searchContainer.Size = UDim2.new(0.7, -16, 0, 32)
    searchContainer.Position = UDim2.new(0.3, 8, 0, 88)
    searchContainer.BackgroundColor3 = colors.surface
    searchContainer.BorderSizePixel = 0
    searchContainer.Parent = parent
    
    local searchCorner = Instance.new("UICorner")
    searchCorner.CornerRadius = UDim.new(0, 8)
    searchCorner.Parent = searchContainer
    
    local searchStroke = Instance.new("UIStroke")
    searchStroke.Color = colors.border
    searchStroke.Thickness = 1
    searchStroke.Parent = searchContainer
    
    local searchIcon = Instance.new("TextLabel")
    searchIcon.Name = "SearchIcon"
    searchIcon.Size = UDim2.new(0, 16, 0, 16)
    searchIcon.Position = UDim2.new(0, 12, 0.5, -8)
    searchIcon.BackgroundTransparency = 1
    searchIcon.Text = "🔍"
    searchIcon.TextSize = 12
    searchIcon.Font = Enum.Font.Gotham
    searchIcon.TextColor3 = colors.textSecondary
    searchIcon.Parent = searchContainer
    
    local searchBox = Instance.new("TextBox")
    searchBox.Name = "SearchBox"
    searchBox.Size = UDim2.new(1, -44, 0.8, 0)
    searchBox.Position = UDim2.new(0, 36, 0.1, 0)
    searchBox.BackgroundTransparency = 1
    searchBox.Text = ""
    searchBox.PlaceholderText = "Search items..."
    searchBox.TextSize = 14
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextColor3 = colors.text
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.ClearTextOnFocus = false
    searchBox.Parent = searchContainer
    
    -- Search functionality
    searchBox.Changed:Connect(function(prop)
        if prop == "Text" then
            searchText = searchBox.Text
            TradeUI.RefreshContent()
        end
    end)
    
    return searchContainer
end

-- Create Item Card with send amount input
local function createItemCard(itemId, itemData, parent)
    local card = Instance.new("Frame")
    card.Name = itemId
    card.Size = UDim2.new(0.5, -4, 0, 120)
    card.BackgroundColor3 = colors.surface
    card.BorderSizePixel = 0
    card.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = card
    
    -- Item Icon/Image
    local icon
    if currentPage == "fruits" then
        -- Use TextLabel for emoji icons
        icon = Instance.new("TextLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0, 40, 0, 40)
        icon.Position = UDim2.new(0, 8, 0, 8)
        icon.BackgroundTransparency = 1
        icon.Text = itemData.Icon or "🍎"
        icon.TextSize = 28
        icon.Font = Enum.Font.GothamBold
        icon.TextColor3 = colors.text
        icon.TextXAlignment = Enum.TextXAlignment.Center
        icon.TextYAlignment = Enum.TextYAlignment.Center
        icon.Parent = card
    else
        -- Use ImageLabel for asset icons
        icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0, 40, 0, 40)
        icon.Position = UDim2.new(0, 8, 0, 8)
        icon.BackgroundTransparency = 1
        icon.Image = itemData.Icon or "rbxasset://textures/ui/GuiImagePlaceholder.png"
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Parent = card
    end
    
    -- Item Name
    local name = Instance.new("TextLabel")
    name.Name = "Name"
    name.Size = UDim2.new(1, -60, 0, 20)
    name.Position = UDim2.new(0, 56, 0, 8)
    name.BackgroundTransparency = 1
    name.Text = itemData.Name or itemId
    name.TextSize = 12
    name.Font = Enum.Font.GothamSemibold
    name.TextColor3 = colors.text
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.TextWrapped = true
    name.Parent = card
    
    -- Amount Owned
    local ownedLabel = Instance.new("TextLabel")
    ownedLabel.Name = "OwnedLabel"
    ownedLabel.Size = UDim2.new(1, -60, 0, 16)
    ownedLabel.Position = UDim2.new(0, 56, 0, 28)
    ownedLabel.BackgroundTransparency = 1
    ownedLabel.Text = "Owned: 0x"
    ownedLabel.TextSize = 10
    ownedLabel.Font = Enum.Font.Gotham
    ownedLabel.TextColor3 = colors.textSecondary
    ownedLabel.TextXAlignment = Enum.TextXAlignment.Left
    ownedLabel.Parent = card
    
    -- Send Amount Input
    local sendAmountFrame = Instance.new("Frame")
    sendAmountFrame.Name = "SendAmountFrame"
    sendAmountFrame.Size = UDim2.new(1, -16, 0, 25)
    sendAmountFrame.Position = UDim2.new(0, 8, 0, 56)
    sendAmountFrame.BackgroundColor3 = colors.background
    sendAmountFrame.BorderSizePixel = 0
    sendAmountFrame.Parent = card
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 4)
    inputCorner.Parent = sendAmountFrame
    
    local sendLabel = Instance.new("TextLabel")
    sendLabel.Name = "SendLabel"
    sendLabel.Size = UDim2.new(0, 40, 1, 0)
    sendLabel.Position = UDim2.new(0, 4, 0, 0)
    sendLabel.BackgroundTransparency = 1
    sendLabel.Text = "Send:"
    sendLabel.TextSize = 10
    sendLabel.Font = Enum.Font.Gotham
    sendLabel.TextColor3 = colors.textSecondary
    sendLabel.TextXAlignment = Enum.TextXAlignment.Left
    sendLabel.TextYAlignment = Enum.TextYAlignment.Center
    sendLabel.Parent = sendAmountFrame
    
    local sendInput = Instance.new("TextBox")
    sendInput.Name = "SendInput"
    sendInput.Size = UDim2.new(1, -48, 1, -4)
    sendInput.Position = UDim2.new(0, 44, 0, 2)
    sendInput.BackgroundTransparency = 1
    sendInput.Text = "0"
    sendInput.PlaceholderText = "0"
    sendInput.TextSize = 11
    sendInput.Font = Enum.Font.Gotham
    sendInput.TextColor3 = colors.text
    sendInput.TextXAlignment = Enum.TextXAlignment.Center
    sendInput.Parent = sendAmountFrame
    
    -- Send Button
    local sendBtn = Instance.new("TextButton")
    sendBtn.Name = "SendBtn"
    sendBtn.Size = UDim2.new(1, -16, 0, 20)
    sendBtn.Position = UDim2.new(0, 8, 0, 88)
    sendBtn.BackgroundColor3 = colors.primary
    sendBtn.BorderSizePixel = 0
    sendBtn.Text = "Send Now"
    sendBtn.TextSize = 10
    sendBtn.Font = Enum.Font.GothamSemibold
    sendBtn.TextColor3 = colors.text
    sendBtn.Parent = card
    
    local sendBtnCorner = Instance.new("UICorner")
    sendBtnCorner.CornerRadius = UDim.new(0, 4)
    sendBtnCorner.Parent = sendBtn
    
    -- Update owned amount based on item type
    local function updateOwnedAmount()
        local amount = 0
        
        if currentPage == "pets" then
            -- Get pet inventory count
            if SendTrashSystem and SendTrashSystem.getPetInventory then
                local petInventory = SendTrashSystem.getPetInventory()
                for _, pet in ipairs(petInventory) do
                    if pet.type == itemId then
                        amount = amount + 1
                    end
                end
            end
        elseif currentPage == "eggs" then
            -- Get egg inventory count
            if SendTrashSystem and SendTrashSystem.getEggInventory then
                local eggInventory = SendTrashSystem.getEggInventory()
                for _, egg in ipairs(eggInventory) do
                    if egg.type == itemId then
                        amount = amount + 1
                    end
                end
            end
        elseif currentPage == "fruits" then
            -- Get fruit inventory count
            if SendTrashSystem and SendTrashSystem.getPlayerFruitInventory then
                local fruitInventory = SendTrashSystem.getPlayerFruitInventory()
                amount = fruitInventory[itemId] or 0
            end
        end
        
        ownedLabel.Text = "Owned: " .. amount .. "x"
        
        -- Change color based on amount
        if amount > 0 then
            ownedLabel.TextColor3 = colors.success
        else
            ownedLabel.TextColor3 = colors.error
        end
    end
    
    -- Initial update
    updateOwnedAmount()
    
    -- Update every 2 seconds
    local lastUpdate = 0
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not card.Parent then
            connection:Disconnect()
            return
        end
        
        local currentTime = tick()
        if currentTime - lastUpdate >= 2 then
            updateOwnedAmount()
            lastUpdate = currentTime
        end
    end)
    
    -- Send input validation
    sendInput.Changed:Connect(function(prop)
        if prop == "Text" then
            local value = tonumber(sendInput.Text) or 0
            if value < 0 then
                sendInput.Text = "0"
            end
            
            -- Save to trade settings
            if not tradeSettings[currentPage] then
                tradeSettings[currentPage] = {}
            end
            tradeSettings[currentPage][itemId] = value
        end
    end)
    
    -- Send button click
    sendBtn.MouseButton1Click:Connect(function()
        local sendAmount = tonumber(sendInput.Text) or 0
        if sendAmount <= 0 then
            if WindUI then
                WindUI:Notify({
                    Title = "⚠️ Invalid Amount",
                    Content = "Please enter a valid send amount",
                    Duration = 3
                })
            end
            return
        end
        
        -- TODO: Implement manual send logic here
        if WindUI then
            WindUI:Notify({
                Title = "🚀 Manual Send",
                Content = string.format("Sending %d %s to %s", sendAmount, itemId, selectedTarget),
                Duration = 3
            })
        end
    end)
    
    return card
end

-- Create Content Area
local function createContentArea(parent)
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(0.7, -16, 1, -160)
    content.Position = UDim2.new(0.3, 8, 0, 128)
    content.BackgroundTransparency = 1
    content.Parent = parent
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = colors.primary
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 1000)
    scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    scrollFrame.Parent = content
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.5, -4, 0, 120)
    gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = scrollFrame
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 50)
    padding.PaddingLeft = UDim2.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = scrollFrame
    
    return content
end

-- Create Auto Trade Controls
local function createAutoTradeControls(parent)
    local controlsFrame = Instance.new("Frame")
    controlsFrame.Name = "AutoTradeControls"
    controlsFrame.Size = UDim2.new(0.7, -16, 0, 40)
    controlsFrame.Position = UDim2.new(0.3, 8, 1, -48)
    controlsFrame.BackgroundColor3 = colors.surface
    controlsFrame.BorderSizePixel = 0
    controlsFrame.Parent = parent
    
    local controlsCorner = Instance.new("UICorner")
    controlsCorner.CornerRadius = UDim.new(0, 8)
    controlsCorner.Parent = controlsFrame
    
    local controlsStroke = Instance.new("UIStroke")
    controlsStroke.Color = colors.border
    controlsStroke.Thickness = 1
    controlsStroke.Parent = controlsFrame
    
    -- Auto Trade Toggle
    local autoTradeBtn = Instance.new("TextButton")
    autoTradeBtn.Name = "AutoTradeBtn"
    autoTradeBtn.Size = UDim2.new(0.5, -4, 1, -8)
    autoTradeBtn.Position = UDim2.new(0, 4, 0, 4)
    autoTradeBtn.BackgroundColor3 = autoTradeEnabled and colors.success or colors.error
    autoTradeBtn.BorderSizePixel = 0
    autoTradeBtn.Text = autoTradeEnabled and "🟢 Auto Trade ON" or "🔴 Auto Trade OFF"
    autoTradeBtn.TextSize = 12
    autoTradeBtn.Font = Enum.Font.GothamSemibold
    autoTradeBtn.TextColor3 = colors.text
    autoTradeBtn.Parent = controlsFrame
    
    local autoTradeCorner = Instance.new("UICorner")
    autoTradeCorner.CornerRadius = UDim.new(0, 6)
    autoTradeCorner.Parent = autoTradeBtn
    
    -- Save Settings Button
    local saveBtn = Instance.new("TextButton")
    saveBtn.Name = "SaveBtn"
    saveBtn.Size = UDim2.new(0.5, -4, 1, -8)
    saveBtn.Position = UDim2.new(0.5, 4, 0, 4)
    saveBtn.BackgroundColor3 = colors.primary
    saveBtn.BorderSizePixel = 0
    saveBtn.Text = "💾 Save Settings"
    saveBtn.TextSize = 12
    saveBtn.Font = Enum.Font.GothamSemibold
    saveBtn.TextColor3 = colors.text
    saveBtn.Parent = controlsFrame
    
    local saveCorner = Instance.new("UICorner")
    saveCorner.CornerRadius = UDim.new(0, 6)
    saveCorner.Parent = saveBtn
    
    -- Auto Trade Toggle Click
    autoTradeBtn.MouseButton1Click:Connect(function()
        autoTradeEnabled = not autoTradeEnabled
        autoTradeBtn.BackgroundColor3 = autoTradeEnabled and colors.success or colors.error
        autoTradeBtn.Text = autoTradeEnabled and "🟢 Auto Trade ON" or "🔴 Auto Trade OFF"
        
        if WindUI then
            WindUI:Notify({
                Title = autoTradeEnabled and "✅ Auto Trade Started" or "⏹️ Auto Trade Stopped",
                Content = autoTradeEnabled and "Auto trading is now active" or "Auto trading has been stopped",
                Duration = 3
            })
        end
        
        -- TODO: Start/stop auto trade logic
    end)
    
    -- Save Button Click
    saveBtn.MouseButton1Click:Connect(function()
        -- TODO: Save settings to config
        if WindUI then
            WindUI:Notify({
                Title = "💾 Settings Saved",
                Content = "Trade settings have been saved",
                Duration = 2
            })
        end
    end)
    
    return controlsFrame
end

-- Create UI
function TradeUI.CreateUI()
    if ScreenGui then
        ScreenGui:Destroy()
    end
    
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "TradeUI"
    ScreenGui.Parent = PlayerGui
    
    MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 900, 0, 600)
    MainFrame.Position = UDim2.new(0.5, -450, 0.5, -300)
    MainFrame.BackgroundColor3 = colors.background
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    originalSize = MainFrame.Size
    minimizedSize = UDim2.new(0, 900, 0, 60)
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = MainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = MainFrame
    
    -- Window Controls
    local windowControls = createWindowControls(MainFrame)
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -140, 0, 20)
    title.Position = UDim2.new(0, 100, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "Auto Trade System"
    title.TextSize = 14
    title.Font = Enum.Font.GothamSemibold
    title.TextColor3 = colors.text
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = MainFrame
    
    -- Create panels
    local targetPanel = createTargetPanel(MainFrame)
    local pageTabs = createPageTabs(MainFrame)
    local searchBar = createSearchBar(MainFrame)
    local content = createContentArea(MainFrame)
    local controls = createAutoTradeControls(MainFrame)
    
    -- Window Control Events
    local closeBtn = windowControls.CloseBtn
    local minimizeBtn = windowControls.MinimizeBtn
    local maximizeBtn = windowControls.MaximizeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
        ScreenGui = nil
    end)
    
    minimizeBtn.MouseButton1Click:Connect(function()
        if isMinimized then
            MainFrame.Size = originalSize
            targetPanel.Visible = true
            pageTabs.Visible = true
            searchBar.Visible = true
            content.Visible = true
            controls.Visible = true
            isMinimized = false
        else
            MainFrame.Size = minimizedSize
            targetPanel.Visible = false
            pageTabs.Visible = false
            searchBar.Visible = false
            content.Visible = false
            controls.Visible = false
            isMinimized = true
        end
    end)
    
    maximizeBtn.MouseButton1Click:Connect(function()
        if MainFrame.Size == originalSize then
            MainFrame.Size = UDim2.new(0.9, 0, 0.9, 0)
            MainFrame.Position = UDim2.new(0.05, 0, 0.05, 0)
        else
            MainFrame.Size = originalSize
            MainFrame.Position = UDim2.new(0.5, -450, 0.5, -300)
        end
    end)
    
    -- Dragging
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundTransparency = 1
    titleBar.Parent = MainFrame
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            
            local connection
            connection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                    connection:Disconnect()
                end
            end)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    return ScreenGui
end

-- Fruit data from FeedFruitSelection
local FruitData = {
    Strawberry = { Name = "Strawberry", Icon = "🍓", Rarity = 1 },
    Blueberry = { Name = "Blueberry", Icon = "🔵", Rarity = 1 },
    Watermelon = { Name = "Watermelon", Icon = "🍉", Rarity = 2 },
    Apple = { Name = "Apple", Icon = "🍎", Rarity = 2 },
    Orange = { Name = "Orange", Icon = "🍊", Rarity = 3 },
    Corn = { Name = "Corn", Icon = "🌽", Rarity = 3 },
    Banana = { Name = "Banana", Icon = "🍌", Rarity = 4 },
    Grape = { Name = "Grape", Icon = "🍇", Rarity = 4 },
    Pear = { Name = "Pear", Icon = "🍐", Rarity = 5 },
    Pineapple = { Name = "Pineapple", Icon = "🍍", Rarity = 5 },
    GoldMango = { Name = "Gold Mango", Icon = "🥭", Rarity = 6 },
    BloodstoneCycad = { Name = "Bloodstone Cycad", Icon = "🌿", Rarity = 6 },
    ColossalPinecone = { Name = "Colossal Pinecone", Icon = "🌲", Rarity = 6 },
    VoltGinkgo = { Name = "Volt Ginkgo", Icon = "⚡", Rarity = 6 },
    DeepseaPearlFruit = { Name = "DeepseaPearlFruit", Icon = "💠", Rarity = 6 },
    Durian = { Name = "Durian", Icon = "🥥", Rarity = 6, IsNew = true },
    DragonFruit = { Name = "Dragon Fruit", Icon = "🐲", Rarity = 6, IsNew = true }
}

-- Egg data from EggSelection
local EggData = {
    BasicEgg = { Name = "Basic Egg", Icon = "rbxassetid://129248801621928", Rarity = 1 },
    RareEgg = { Name = "Rare Egg", Icon = "rbxassetid://71012831091414", Rarity = 2 },
    SuperRareEgg = { Name = "Super Rare Egg", Icon = "rbxassetid://93845452154351", Rarity = 2 },
    EpicEgg = { Name = "Epic Egg", Icon = "rbxassetid://116395645531721", Rarity = 2 },
    LegendEgg = { Name = "Legend Egg", Icon = "rbxassetid://90834918351014", Rarity = 3 },
    PrismaticEgg = { Name = "Prismatic Egg", Icon = "rbxassetid://79960683434582", Rarity = 4 },
    HyperEgg = { Name = "Hyper Egg", Icon = "rbxassetid://104958288296273", Rarity = 4 },
    VoidEgg = { Name = "Void Egg", Icon = "rbxassetid://122396162708984", Rarity = 5 },
    BowserEgg = { Name = "Bowser Egg", Icon = "rbxassetid://71500536051510", Rarity = 5 },
    DemonEgg = { Name = "Demon Egg", Icon = "rbxassetid://126412407639969", Rarity = 5 },
    CornEgg = { Name = "Corn Egg", Icon = "rbxassetid://94739512852461", Rarity = 5 },
    BoneDragonEgg = { Name = "Bone Dragon Egg", Icon = "rbxassetid://83209913424562", Rarity = 5 },
    UltraEgg = { Name = "Ultra Egg", Icon = "rbxassetid://83909590718799", Rarity = 6 },
    DinoEgg = { Name = "Dino Egg", Icon = "rbxassetid://80783528632315", Rarity = 6 },
    FlyEgg = { Name = "Fly Egg", Icon = "rbxassetid://109240587278187", Rarity = 6 },
    UnicornEgg = { Name = "Unicorn Egg", Icon = "rbxassetid://123427249205445", Rarity = 6 },
    AncientEgg = { Name = "Ancient Egg", Icon = "rbxassetid://113910587565739", Rarity = 6 },
    UnicornProEgg = { Name = "Unicorn Pro Egg", Icon = "rbxassetid://140138063696377", Rarity = 6 },
    SnowbunnyEgg = { Name = "Snowbunny Egg", Icon = "rbxassetid://136223941487914", Rarity = 3, IsNew = true },
    DarkGoatyEgg = { Name = "Dark Goaty Egg", Icon = "rbxassetid://95956060312947", Rarity = 4, IsNew = true },
    RhinoRockEgg = { Name = "Rhino Rock Egg", Icon = "rbxassetid://131221831910623", Rarity = 5, IsNew = true },
    SaberCubEgg = { Name = "Saber Cub Egg", Icon = "rbxassetid://111953502835346", Rarity = 6, IsNew = true },
    GeneralKongEgg = { Name = "General Kong Egg", Icon = "rbxassetid://106836613554535", Rarity = 6, IsNew = true },
    PegasusEgg = { Name = "Pegasus Egg", Icon = "rbxassetid://83004379343725", Rarity = 6, IsNew = true }
}

-- Refresh Content based on current page
function TradeUI.RefreshContent()
    if not ScreenGui then return end
    
    local scrollFrame = ScreenGui.MainFrame.Content.ScrollFrame
    if not scrollFrame then return end
    
    -- Clear existing content
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIGridLayout" and child.Name ~= "UIPadding" then
            child:Destroy()
        end
    end
    
    -- Get data based on current page
    local itemData = {}
    
    if currentPage == "pets" then
        -- Get pet types from SendTrashSystem
        if SendTrashSystem and SendTrashSystem.getAllPetTypes then
            local petTypes = SendTrashSystem.getAllPetTypes()
            for _, petType in ipairs(petTypes) do
                if searchText == "" or string.find(string.lower(petType), string.lower(searchText), 1, true) then
                    itemData[petType] = {
                        Name = petType,
                        Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png"
                    }
                end
            end
        end
    elseif currentPage == "eggs" then
        -- Use hardcoded egg data with icons
        for eggId, eggInfo in pairs(EggData) do
            if searchText == "" or string.find(string.lower(eggInfo.Name), string.lower(searchText), 1, true) then
                itemData[eggId] = eggInfo
            end
        end
    elseif currentPage == "fruits" then
        -- Use hardcoded fruit data with emoji icons
        for fruitId, fruitInfo in pairs(FruitData) do
            if searchText == "" or string.find(string.lower(fruitInfo.Name), string.lower(searchText), 1, true) then
                itemData[fruitId] = fruitInfo
            end
        end
    end
    
    -- Sort items by rarity and name
    local sortedItems = {}
    for itemId, data in pairs(itemData) do
        table.insert(sortedItems, {id = itemId, data = data})
    end
    
    table.sort(sortedItems, function(a, b)
        if a.data.Rarity and b.data.Rarity then
            if a.data.Rarity ~= b.data.Rarity then
                return a.data.Rarity < b.data.Rarity
            end
        end
        return a.data.Name < b.data.Name
    end)
    
    -- Create cards
    for i, item in ipairs(sortedItems) do
        local card = createItemCard(item.id, item.data, scrollFrame)
        card.LayoutOrder = i
        
        -- Apply saved settings
        if tradeSettings[currentPage] and tradeSettings[currentPage][item.id] then
            local sendInput = card.SendAmountFrame.SendInput
            if sendInput then
                sendInput.Text = tostring(tradeSettings[currentPage][item.id])
            end
        end
    end
    
    -- Update canvas size
    local itemCount = #sortedItems
    if itemCount > 0 then
        local rows = math.ceil(itemCount / 2)
        local cellHeight = 120
        local cellPadding = 8
        local topPadding = 8
        local bottomPadding = 50
        local totalHeight = topPadding + (rows * cellHeight) + ((rows - 1) * cellPadding) + bottomPadding
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
        scrollFrame.CanvasPosition = Vector2.new(0, 0)
    end
end

-- Public Functions
function TradeUI.Show()
    if not ScreenGui then
        TradeUI.CreateUI()
    end
    
    task.wait()
    TradeUI.RefreshContent()
    ScreenGui.Enabled = true
    ScreenGui.Parent = PlayerGui
end

function TradeUI.Hide()
    if ScreenGui then
        ScreenGui.Enabled = false
    end
end

function TradeUI.Init(dependencies)
    WindUI = dependencies.WindUI
    Config = dependencies.Config
    SendTrashSystem = dependencies.SendTrashSystem
end

return TradeUI
