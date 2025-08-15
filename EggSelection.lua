-- EggSelection.lua - Modern macOS-style UI for Egg Selection
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

-- macOS-style Colors (Dark Theme)
local colors = {
    background = Color3.fromRGB(28, 28, 30),
    window = Color3.fromRGB(44, 44, 46),
    card = Color3.fromRGB(58, 58, 60),
    cardHover = Color3.fromRGB(68, 68, 70),
    cardSelected = Color3.fromRGB(0, 122, 255),
    border = Color3.fromRGB(72, 72, 74),
    text = Color3.fromRGB(255, 255, 255),
    textSecondary = Color3.fromRGB(174, 174, 178),
    accent = Color3.fromRGB(0, 122, 255),
    selected = Color3.fromRGB(0, 122, 255),
    hover = Color3.fromRGB(68, 68, 70),
    pageActive = Color3.fromRGB(0, 122, 255),
    pageInactive = Color3.fromRGB(174, 174, 178),
    searchBackground = Color3.fromRGB(58, 58, 60),
    searchBorder = Color3.fromRGB(72, 72, 74),
    shadow = Color3.fromRGB(0, 0, 0, 0.3)
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
    if rarity >= 100 then return Color3.fromRGB(255, 59, 48)
    elseif rarity >= 50 then return Color3.fromRGB(175, 82, 222)
    elseif rarity >= 20 then return Color3.fromRGB(90, 200, 250)
    elseif rarity >= 10 then return Color3.fromRGB(255, 204, 0)
    elseif rarity >= 6 then return Color3.fromRGB(255, 45, 85)
    elseif rarity >= 5 then return Color3.fromRGB(255, 149, 0)
    elseif rarity >= 4 then return Color3.fromRGB(88, 86, 214)
    elseif rarity >= 3 then return Color3.fromRGB(52, 199, 89)
    elseif rarity >= 2 then return Color3.fromRGB(255, 149, 0)
    else return Color3.fromRGB(142, 142, 147)
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

-- Create macOS-style shadow
local function createShadow(parent)
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 4, 1, 4)
    shadow.Position = UDim2.new(0, -2, 0, -2)
    shadow.BackgroundColor3 = colors.shadow
    shadow.BorderSizePixel = 0
    shadow.ZIndex = parent.ZIndex - 1
    shadow.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = shadow
    
    return shadow
end

-- Create macOS-style card
local function createMacCard(parent)
    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.new(1, 0, 1, 0)
    card.BackgroundColor3 = colors.card
    card.BorderSizePixel = 0
    card.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = card
    
    return card
end

-- Create Item Card (3 per row, macOS design)
local function createItemCard(itemId, itemData, parent)
    local card = Instance.new("TextButton")
    card.Name = itemId
    card.Size = UDim2.new(0.33, -8, 0, 140)
    card.BackgroundTransparency = 1
    card.Text = ""
    card.Parent = parent
    
    createShadow(card)
    local mainCard = createMacCard(card)
    
    -- Create Icon
    local icon
    if currentPage == "eggs" then
        icon = Instance.new("ImageLabel")
        icon.Image = itemData.Icon
        icon.ScaleType = Enum.ScaleType.Fit
    else
        icon = Instance.new("TextLabel")
        icon.Text = itemData.Icon
        icon.TextSize = 36
        icon.Font = Enum.Font.GothamBold
        icon.TextColor3 = getRarityColor(itemData.Rarity)
    end
    
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 60, 0, 60)
    icon.Position = UDim2.new(0.5, -30, 0.15, 0)
    icon.BackgroundTransparency = 1
    icon.Parent = mainCard
    
    local name = Instance.new("TextLabel")
    name.Name = "Name"
    name.Size = UDim2.new(1, -16, 0, 20)
    name.Position = UDim2.new(0, 8, 0.6, 0)
    name.BackgroundTransparency = 1
    name.Text = itemData.Name
    name.TextSize = 13
    name.Font = Enum.Font.GothamSemibold
    name.TextColor3 = colors.text
    name.TextXAlignment = Enum.TextXAlignment.Center
    name.TextWrapped = true
    name.Parent = mainCard
    
    local price = Instance.new("TextLabel")
    price.Name = "Price"
    price.Size = UDim2.new(1, -16, 0, 16)
    price.Position = UDim2.new(0, 8, 0.75, 0)
    price.BackgroundTransparency = 1
    if currentPage == "eggs" then
        price.Text = "$" .. itemData.Price
    else
        price.Text = "Mutation"
    end
    price.TextSize = 11
    price.Font = Enum.Font.Gotham
    price.TextColor3 = colors.textSecondary
    price.TextXAlignment = Enum.TextXAlignment.Center
    price.TextWrapped = true
    price.Parent = mainCard
    
    local checkmark = Instance.new("TextLabel")
    checkmark.Name = "Checkmark"
    checkmark.Size = UDim2.new(0, 24, 0, 24)
    checkmark.Position = UDim2.new(1, -28, 0, 8)
    checkmark.BackgroundTransparency = 1
    checkmark.Text = "✓"
    checkmark.TextSize = 18
    checkmark.Font = Enum.Font.GothamBold
    checkmark.TextColor3 = colors.selected
    checkmark.Visible = false
    checkmark.Parent = mainCard
    
    -- Set initial selection state
    if selectedItems[itemId] then
        checkmark.Visible = true
        mainCard.BackgroundColor3 = colors.cardSelected
        mainCard.UIStroke.Color = colors.cardSelected
    end
    
    -- Hover effect
    card.MouseEnter:Connect(function()
        if not selectedItems[itemId] then
            TweenService:Create(mainCard, TweenInfo.new(0.2), {BackgroundColor3 = colors.cardHover}):Play()
        end
    end)
    
    card.MouseLeave:Connect(function()
        if not selectedItems[itemId] then
            TweenService:Create(mainCard, TweenInfo.new(0.2), {BackgroundColor3 = colors.card}):Play()
        end
    end)
    
    -- Click effect
    card.MouseButton1Click:Connect(function()
        if selectedItems[itemId] then
            selectedItems[itemId] = nil
            checkmark.Visible = false
            TweenService:Create(mainCard, TweenInfo.new(0.2), {BackgroundColor3 = colors.card}):Play()
            TweenService:Create(mainCard.UIStroke, TweenInfo.new(0.2), {Color = colors.border}):Play()
        else
            selectedItems[itemId] = true
            checkmark.Visible = true
            TweenService:Create(mainCard, TweenInfo.new(0.2), {BackgroundColor3 = colors.cardSelected}):Play()
            TweenService:Create(mainCard.UIStroke, TweenInfo.new(0.2), {Color = colors.cardSelected}):Play()
        end
        
        if onSelectionChanged then
            onSelectionChanged(selectedItems)
        end
    end)
    
    return card
end

-- Create macOS-style search bar
local function createSearchBar(parent)
    local searchContainer = Instance.new("Frame")
    searchContainer.Name = "SearchContainer"
    searchContainer.Size = UDim2.new(1, -16, 0, 36)
    searchContainer.Position = UDim2.new(0, 8, 0, 0)
    searchContainer.BackgroundTransparency = 1
    searchContainer.Parent = parent
    
    local searchBackground = Instance.new("Frame")
    searchBackground.Name = "SearchBackground"
    searchBackground.Size = UDim2.new(1, 0, 1, 0)
    searchBackground.BackgroundColor3 = colors.searchBackground
    searchBackground.BorderSizePixel = 0
    searchBackground.Parent = searchContainer
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim2.new(0, 8)
    corner.Parent = searchBackground
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.searchBorder
    stroke.Thickness = 1
    stroke.Parent = searchBackground
    
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
    eggsTab.BackgroundColor3 = colors.card
    eggsTab.BorderSizePixel = 0
    eggsTab.Text = "🥚 Eggs"
    eggsTab.TextSize = 14
    eggsTab.Font = Enum.Font.GothamBold
    eggsTab.TextColor3 = colors.pageActive
    eggsTab.Parent = tabContainer
    
    local eggsCorner = Instance.new("UICorner")
    eggsCorner.CornerRadius = UDim2.new(0, 6)
    eggsCorner.Parent = eggsTab
    
    local mutationsTab = Instance.new("TextButton")
    mutationsTab.Name = "MutationsTab"
    mutationsTab.Size = UDim2.new(0.5, -4, 1, 0)
    mutationsTab.Position = UDim2.new(0.5, 4, 0, 0)
    mutationsTab.BackgroundColor3 = colors.card
    mutationsTab.BorderSizePixel = 0
    mutationsTab.Text = "✨ Mutations"
    mutationsTab.TextSize = 14
    mutationsTab.Font = Enum.Font.GothamBold
    mutationsTab.TextColor3 = colors.pageInactive
    mutationsTab.Parent = tabContainer
    
    local mutationsCorner = Instance.new("UICorner")
    mutationsCorner.CornerRadius = UDim2.new(0, 6)
    mutationsCorner.Parent = mutationsTab
    
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
    MainFrame.Size = UDim2.new(0, 800, 0, 500)
    MainFrame.Position = UDim2.new(0.5, -400, 0.5, -250)
    MainFrame.BackgroundTransparency = 1
    MainFrame.Parent = ScreenGui
    
    originalSize = MainFrame.Size
    minimizedSize = UDim2.new(0, 800, 0, 60)
    
    createShadow(MainFrame)
    local mainWindow = createMacCard(MainFrame)
    
    -- Title Bar (macOS style)
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 32)
    titleBar.BackgroundColor3 = colors.window
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainWindow
    
    local titleBarCorner = Instance.new("UICorner")
    titleBarCorner.CornerRadius = UDim2.new(0, 8, 0, 0)
    titleBarCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🥚 Egg Selection"
    title.TextSize = 14
    title.Font = Enum.Font.GothamSemibold
    title.TextColor3 = colors.text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- macOS-style traffic light buttons
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 12, 0, 12)
    closeBtn.Position = UDim2.new(0, 12, 0.5, -6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 95, 87)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = ""
    closeBtn.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim2.new(0.5, 0)
    closeCorner.Parent = closeBtn
    
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Name = "MinimizeBtn"
    minimizeBtn.Size = UDim2.new(0, 12, 0, 12)
    minimizeBtn.Position = UDim2.new(0, 30, 0.5, -6)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(255, 189, 46)
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Text = ""
    minimizeBtn.Parent = titleBar
    
    local minimizeCorner = Instance.new("UICorner")
    minimizeCorner.CornerRadius = UDim2.new(0.5, 0)
    minimizeCorner.Parent = minimizeBtn
    
    local maximizeBtn = Instance.new("TextButton")
    maximizeBtn.Name = "MaximizeBtn"
    maximizeBtn.Size = UDim2.new(0, 12, 0, 12)
    maximizeBtn.Position = UDim2.new(0, 48, 0.5, -6)
    maximizeBtn.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
    maximizeBtn.BorderSizePixel = 0
    maximizeBtn.Text = ""
    maximizeBtn.Parent = titleBar
    
    local maximizeCorner = Instance.new("UICorner")
    maximizeCorner.CornerRadius = UDim2.new(0.5, 0)
    maximizeCorner.Parent = maximizeBtn
    
    -- Sidebar (macOS style)
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 200, 1, -32)
    sidebar.Position = UDim2.new(0, 0, 0, 32)
    sidebar.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainWindow
    
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim2.new(0, 0, 0, 8)
    sidebarCorner.Parent = sidebar
    
    -- Sidebar content
    local sidebarContent = Instance.new("ScrollingFrame")
    sidebarContent.Name = "SidebarContent"
    sidebarContent.Size = UDim2.new(1, -16, 1, -16)
    sidebarContent.Position = UDim2.new(0, 8, 0, 8)
    sidebarContent.BackgroundTransparency = 1
    sidebarContent.ScrollBarThickness = 4
    sidebarContent.ScrollBarImageColor3 = colors.accent
    sidebarContent.Parent = sidebar
    
    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Padding = UDim2.new(0, 8)
    sidebarLayout.Parent = sidebarContent
    
    -- Favorites section
    local favoritesSection = Instance.new("TextLabel")
    favoritesSection.Name = "FavoritesSection"
    favoritesSection.Size = UDim2.new(1, 0, 0, 20)
    favoritesSection.BackgroundTransparency = 1
    favoritesSection.Text = "Favorites"
    favoritesSection.TextSize = 12
    favoritesSection.Font = Enum.Font.GothamBold
    favoritesSection.TextColor3 = colors.textSecondary
    favoritesSection.TextXAlignment = Enum.TextXAlignment.Left
    favoritesSection.LayoutOrder = 1
    favoritesSection.Parent = sidebarContent
    
    -- Eggs tab
    local eggsTab = Instance.new("TextButton")
    eggsTab.Name = "EggsTab"
    eggsTab.Size = UDim2.new(1, 0, 0, 32)
    eggsTab.BackgroundColor3 = colors.selected
    eggsTab.BorderSizePixel = 0
    eggsTab.Text = "🥚 Eggs"
    eggsTab.TextSize = 14
    eggsTab.Font = Enum.Font.GothamSemibold
    eggsTab.TextColor3 = colors.window
    eggsTab.TextXAlignment = Enum.TextXAlignment.Left
    eggsTab.LayoutOrder = 2
    eggsTab.Parent = sidebarContent
    
    local eggsCorner = Instance.new("UICorner")
    eggsCorner.CornerRadius = UDim2.new(0, 6)
    eggsCorner.Parent = eggsTab
    
    -- Mutations tab
    local mutationsTab = Instance.new("TextButton")
    mutationsTab.Name = "MutationsTab"
    mutationsTab.Size = UDim2.new(1, 0, 0, 32)
    mutationsTab.BackgroundColor3 = colors.window
    mutationsTab.BorderSizePixel = 0
    mutationsTab.Text = "✨ Mutations"
    mutationsTab.TextSize = 14
    mutationsTab.Font = Enum.Font.GothamSemibold
    mutationsTab.TextColor3 = colors.text
    mutationsTab.TextXAlignment = Enum.TextXAlignment.Left
    mutationsTab.LayoutOrder = 3
    mutationsTab.Parent = sidebarContent
    
    local mutationsCorner = Instance.new("UICorner")
    mutationsCorner.CornerRadius = UDim2.new(0, 6)
    mutationsCorner.Parent = mutationsTab
    
    -- Main content area
    local mainContent = Instance.new("Frame")
    mainContent.Name = "MainContent"
    mainContent.Size = UDim2.new(1, -200, 1, -32)
    mainContent.Position = UDim2.new(0, 200, 0, 32)
    mainContent.BackgroundTransparency = 1
    mainContent.Parent = mainWindow
    
    -- Search Bar
    local searchBar = createSearchBar(mainContent)
    searchBar.Position = UDim2.new(0, 8, 0, 8)
    
    -- Content Area
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -16, 1, -60)
    content.Position = UDim2.new(0, 8, 0, 60)
    content.BackgroundTransparency = 1
    content.Parent = mainContent
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = colors.accent
    scrollFrame.Parent = content
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.33, -8, 0, 140)
    gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = scrollFrame
    
    -- Tab click events
    eggsTab.MouseButton1Click:Connect(function()
        currentPage = "eggs"
        eggsTab.BackgroundColor3 = colors.selected
        eggsTab.TextColor3 = colors.window
        mutationsTab.BackgroundColor3 = colors.window
        mutationsTab.TextColor3 = colors.text
        local searchBox = ScreenGui.MainFrame.Card.MainContent.SearchContainer.SearchBox
        if searchBox then searchBox.PlaceholderText = "Search eggs..." end
        EggSelection.RefreshContent()
    end)
    
    mutationsTab.MouseButton1Click:Connect(function()
        currentPage = "mutations"
        mutationsTab.BackgroundColor3 = colors.selected
        mutationsTab.TextColor3 = colors.window
        eggsTab.BackgroundColor3 = colors.window
        eggsTab.TextColor3 = colors.text
        local searchBox = ScreenGui.MainFrame.Card.MainContent.SearchContainer.SearchBox
        if searchBox then searchBox.PlaceholderText = "Search mutations..." end
        EggSelection.RefreshContent()
    end)
    
    -- Control Button Events
    minimizeBtn.MouseButton1Click:Connect(function()
        if isMinimized then
            MainFrame.Size = originalSize
            mainContent.Visible = true
            sidebar.Visible = true
            isMinimized = false
        else
            MainFrame.Size = minimizedSize
            mainContent.Visible = false
            sidebar.Visible = false
            isMinimized = true
        end
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        if onToggleChanged then onToggleChanged(false) end
        ScreenGui:Destroy()
        ScreenGui = nil
    end)
    
    maximizeBtn.MouseButton1Click:Connect(function()
        if MainFrame.Size == originalSize then
            MainFrame.Size = UDim2.new(0.9, 0, 0.9, 0)
            MainFrame.Position = UDim2.new(0.05, 0, 0.05, 0)
        else
            MainFrame.Size = originalSize
            MainFrame.Position = UDim2.new(0.5, -400, 0.5, -250)
        end
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
    
    local scrollFrame = ScreenGui.MainFrame.Card.MainContent.Content.ScrollFrame
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
        card.LayoutOrder = i
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
        local scrollFrame = ScreenGui.MainFrame.Card.MainContent.Content.ScrollFrame
        for _, child in pairs(scrollFrame:GetChildren()) do
            if child:IsA("TextButton") then
                local checkmark = child.Card.Checkmark
                local mainCard = child.Card
                if checkmark and mainCard then
                    if selectedItems[child.Name] then
                        checkmark.Visible = true
                        mainCard.BackgroundColor3 = colors.cardSelected
                        mainCard.UIStroke.Color = colors.cardSelected
                    else
                        checkmark.Visible = false
                        mainCard.BackgroundColor3 = colors.card
                        mainCard.UIStroke.Color = colors.border
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
