-- EggSelection.lua - Modern Glass UI for Egg Selection
-- Author: Zebux
-- Version: 1.0

local EggSelection = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Hardcoded data with actual Roblox asset IDs
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
        Icon = "✨",
        Rarity = 10
    },
    Diamond = {
        Name = "Diamond", 
        Icon = "💎",
        Rarity = 20
    },
    Electirc = {
        Name = "Electric",
        Icon = "⚡",
        Rarity = 50
    },
    Fire = {
        Name = "Fire",
        Icon = "🔥",
        Rarity = 100
    },
    Dino = {
        Name = "Jurassic",
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
local currentPage = "eggs" -- "eggs" or "mutations"
local searchText = ""

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
    hover = Color3.fromRGB(40, 40, 45),
    pageActive = Color3.fromRGB(100, 150, 255),
    pageInactive = Color3.fromRGB(80, 80, 90)
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

-- Price parsing function
local function parsePrice(priceStr)
    if type(priceStr) == "number" then
        return priceStr
    end
    -- Remove commas and convert to number
    local cleanPrice = priceStr:gsub(",", "")
    return tonumber(cleanPrice) or 0
end

-- Sort data by price (low to high) - only for eggs
local function sortDataByPrice(data, isEggs)
    local sortedData = {}
    for id, item in pairs(data) do
        table.insert(sortedData, {id = id, data = item})
    end
    
    if isEggs then
        table.sort(sortedData, function(a, b)
            local priceA = parsePrice(a.data.Price)
            local priceB = parsePrice(b.data.Price)
            return priceA < priceB
        end)
    else
        -- For mutations, sort by name
        table.sort(sortedData, function(a, b)
            return a.data.Name < b.data.Name
        end)
    end
    
    return sortedData
end

-- Filter data by search text
local function filterDataBySearch(data, searchText)
    if searchText == "" then
        return data
    end
    
    local filteredData = {}
    local searchLower = string.lower(searchText)
    
    for id, item in pairs(data) do
        local nameLower = string.lower(item.Name)
        if string.find(nameLower, searchLower, 1, true) then
            filteredData[id] = item
        end
    end
    
    return filteredData
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

-- Create Item Card (3 per row, landscape design)
local function createItemCard(itemId, itemData, parent)
    local card = Instance.new("TextButton")
    card.Name = itemId
    card.Size = UDim2.new(0.33, -8, 0, 120) -- 3 per row with spacing
    card.BackgroundTransparency = 1
    card.Text = ""
    card.Parent = parent
    
    local glass = createGlassEffect(card)
    glass.Size = UDim2.new(1, 0, 1, 0)
    
    -- Create Icon (ImageLabel for eggs, TextLabel for mutations)
    local icon
    if currentPage == "eggs" then
        icon = Instance.new("ImageLabel")
        icon.Image = itemData.Icon
        icon.ScaleType = Enum.ScaleType.Fit
    else
        icon = Instance.new("TextLabel")
        icon.Text = itemData.Icon
        icon.TextSize = 32
        icon.Font = Enum.Font.GothamBold
        icon.TextColor3 = getRarityColor(itemData.Rarity)
    end
    
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 50, 0, 50)
    icon.Position = UDim2.new(0.5, -25, 0.2, 0)
    icon.BackgroundTransparency = 1
    icon.Parent = card
    
    local name = Instance.new("TextLabel")
    name.Name = "Name"
    name.Size = UDim2.new(1, -16, 0, 20)
    name.Position = UDim2.new(0, 8, 0.6, 0)
    name.BackgroundTransparency = 1
    name.Text = itemData.Name
    name.TextSize = 12
    name.Font = Enum.Font.GothamSemibold
    name.TextColor3 = colors.text
    name.TextXAlignment = Enum.TextXAlignment.Center
    name.TextWrapped = true
    name.Parent = card
    
    local price = Instance.new("TextLabel")
    price.Name = "Price"
    price.Size = UDim2.new(1, -16, 0, 16)
    price.Position = UDim2.new(0, 8, 0.8, 0)
    price.BackgroundTransparency = 1
    if currentPage == "eggs" then
        price.Text = "$" .. itemData.Price
    else
        price.Text = "Mutation"
    end
    price.TextSize = 10
    price.Font = Enum.Font.Gotham
    price.TextColor3 = colors.textSecondary
    price.TextXAlignment = Enum.TextXAlignment.Center
    price.TextWrapped = true
    price.Parent = card
    
    local checkmark = Instance.new("TextLabel")
    checkmark.Name = "Checkmark"
    checkmark.Size = UDim2.new(0, 20, 0, 20)
    checkmark.Position = UDim2.new(1, -24, 0, 4)
    checkmark.BackgroundTransparency = 1
    checkmark.Text = "✓"
    checkmark.TextSize = 16
    checkmark.Font = Enum.Font.GothamBold
    checkmark.TextColor3 = colors.selected
    checkmark.Visible = false
    checkmark.Parent = card
    
    -- Set initial selection state
    if selectedItems[itemId] then
        checkmark.Visible = true
        glass.BackgroundColor3 = colors.selected
    end
    
    -- Hover effect
    card.MouseEnter:Connect(function()
        if not selectedItems[itemId] then
            TweenService:Create(glass, TweenInfo.new(0.2), {BackgroundColor3 = colors.hover}):Play()
        end
    end)
    
    card.MouseLeave:Connect(function()
        if not selectedItems[itemId] then
            TweenService:Create(glass, TweenInfo.new(0.2), {BackgroundColor3 = colors.glass}):Play()
        end
    end)
    
    -- Click effect
    card.MouseButton1Click:Connect(function()
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
    
    return card
end

-- Create Search Bar
local function createSearchBar(parent)
    local searchContainer = Instance.new("Frame")
    searchContainer.Name = "SearchContainer"
    searchContainer.Size = UDim2.new(1, -16, 0, 40)
    searchContainer.Position = UDim2.new(0, 8, 0, 0)
    searchContainer.BackgroundTransparency = 1
    searchContainer.Parent = parent
    
    local searchGlass = createGlassEffect(searchContainer)
    searchGlass.Size = UDim2.new(1, 0, 1, 0)
    
    local searchIcon = Instance.new("TextLabel")
    searchIcon.Name = "SearchIcon"
    searchIcon.Size = UDim2.new(0, 20, 0, 20)
    searchIcon.Position = UDim2.new(0, 12, 0.5, -10)
    searchIcon.BackgroundTransparency = 1
    searchIcon.Text = "🔍"
    searchIcon.TextSize = 14
    searchIcon.Font = Enum.Font.Gotham
    searchIcon.TextColor3 = colors.textSecondary
    searchIcon.Parent = searchContainer
    
    local searchBox = Instance.new("TextBox")
    searchBox.Name = "SearchBox"
    searchBox.Size = UDim2.new(1, -60, 0.8, 0)
    searchBox.Position = UDim2.new(0, 40, 0.1, 0)
    searchBox.BackgroundTransparency = 1
    searchBox.Text = ""
    searchBox.PlaceholderText = "Search eggs..."
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
            EggSelection.RefreshContent()
        end
    end)
    
    return searchContainer
end

-- Create Page Tabs
local function createPageTabs(parent)
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "PageTabs"
    tabContainer.Size = UDim2.new(1, -16, 0, 40)
    tabContainer.Position = UDim2.new(0, 8, 0, 48)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = parent
    
    local eggsTab = Instance.new("TextButton")
    eggsTab.Name = "EggsTab"
    eggsTab.Size = UDim2.new(0.5, -4, 1, 0)
    eggsTab.Position = UDim2.new(0, 0, 0, 0)
    eggsTab.BackgroundTransparency = 1
    eggsTab.Text = "🥚 Eggs"
    eggsTab.TextSize = 14
    eggsTab.Font = Enum.Font.GothamBold
    eggsTab.TextColor3 = colors.pageActive
    eggsTab.Parent = tabContainer
    
    local mutationsTab = Instance.new("TextButton")
    mutationsTab.Name = "MutationsTab"
    mutationsTab.Size = UDim2.new(0.5, -4, 1, 0)
    mutationsTab.Position = UDim2.new(0.5, 4, 0, 0)
    mutationsTab.BackgroundTransparency = 1
    mutationsTab.Text = "✨ Mutations"
    mutationsTab.TextSize = 14
    mutationsTab.Font = Enum.Font.GothamBold
    mutationsTab.TextColor3 = colors.pageInactive
    mutationsTab.Parent = tabContainer
    
    -- Tab click events
    eggsTab.MouseButton1Click:Connect(function()
        currentPage = "eggs"
        eggsTab.TextColor3 = colors.pageActive
        mutationsTab.TextColor3 = colors.pageInactive
        -- Update search placeholder
        local searchBox = ScreenGui.MainFrame.SearchContainer.SearchBox
        if searchBox then
            searchBox.PlaceholderText = "Search eggs..."
        end
        EggSelection.RefreshContent()
    end)
    
    mutationsTab.MouseButton1Click:Connect(function()
        currentPage = "mutations"
        mutationsTab.TextColor3 = colors.pageActive
        eggsTab.TextColor3 = colors.pageInactive
        -- Update search placeholder
        local searchBox = ScreenGui.MainFrame.SearchContainer.SearchBox
        if searchBox then
            searchBox.PlaceholderText = "Search mutations..."
        end
        EggSelection.RefreshContent()
    end)
    
    return tabContainer
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
    MainFrame.Size = UDim2.new(0, 600, 0, 400) -- Landscape design
    MainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
    MainFrame.BackgroundTransparency = 1
    MainFrame.Parent = ScreenGui
    
    originalSize = MainFrame.Size
    minimizedSize = UDim2.new(0, 600, 0, 60)
    
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
    
    -- Page Tabs
    local pageTabs = createPageTabs(MainFrame)
    
    -- Search Bar
    local searchBar = createSearchBar(MainFrame)
    
    -- Content Area
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -16, 1, -144)
    content.Position = UDim2.new(0, 8, 0, 144)
    content.BackgroundTransparency = 1
    content.Parent = MainFrame
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = colors.accent
    scrollFrame.Parent = content
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.33, -8, 0, 120)
    gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = scrollFrame
    
    -- Control Button Events
    minimizeBtn.MouseButton1Click:Connect(function()
        if isMinimized then
            MainFrame.Size = originalSize
            content.Visible = true
            pageTabs.Visible = true
            searchBar.Visible = true
            isMinimized = false
        else
            MainFrame.Size = minimizedSize
            content.Visible = false
            pageTabs.Visible = false
            searchBar.Visible = false
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

-- Refresh Content based on current page
function EggSelection.RefreshContent()
    if not ScreenGui then return end
    
    local scrollFrame = ScreenGui.MainFrame.Content.ScrollFrame
    if not scrollFrame then return end
    
    -- Clear existing content
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Get data based on current page
    local data = (currentPage == "eggs") and EggData or MutationData
    
    -- Filter by search
    local filteredData = filterDataBySearch(data, searchText)
    
    -- Sort by price (low to high) for eggs, by name for mutations
    local sortedData = sortDataByPrice(filteredData, currentPage == "eggs")
    
    -- Add content
    for i, item in ipairs(sortedData) do
        local card = createItemCard(item.id, item.data, scrollFrame)
        card.LayoutOrder = i -- Ensure proper ordering
    end
end

-- Public Functions
function EggSelection.Show(callback, toggleCallback)
    onSelectionChanged = callback
    onToggleChanged = toggleCallback
    
    if not ScreenGui then
        EggSelection.CreateUI()
    end
    
    EggSelection.RefreshContent()
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
