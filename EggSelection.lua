-- EggSelection.lua - macOS Style Dark Theme UI for Egg Selection
-- Author: Zebux
-- Version: 2.0

local EggSelection = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dynamic data loading from ModuleScript
local EggData = {}
local dataLoaded = false
local dataStatus = "Loading..."

-- Dynamic mutation data loading from ModuleScript
local MutationData = {}
local mutationDataLoaded = false
local mutationDataStatus = "Loading..."

-- Data loading functions
local function formatPrice(price)
    if type(price) == "string" then
        return price
    elseif type(price) == "number" then
        return tostring(price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    end
    return "0"
end

local function convertEggData(rawData)
    local convertedData = {}
    local eggCount = 0
    
    for eggId, eggInfo in pairs(rawData) do
        if eggId ~= "__index" and type(eggInfo) == "table" then
            -- Convert raw ModuleScript data to UI-friendly format
            local name = eggInfo.ID or eggId
            -- Convert ID to display name (e.g., "BasicEgg" -> "Basic Egg")
            name = name:gsub("Egg$", " Egg"):gsub("(%l)(%u)", "%1 %2")
            
            convertedData[eggId] = {
                Name = name,
                Price = formatPrice(eggInfo.Price),
                Icon = eggInfo.Icon or "rbxassetid://0",
                Rarity = eggInfo.Rarity or 1,
                Category = eggInfo.Category or "",
                Evolution = eggInfo.Evolution or false,
                Source = eggInfo.Source or "",
                -- Mark new eggs based on certain criteria (you can adjust this logic)
                IsNew = eggInfo.Evolution == true or eggInfo.Source == "Shop" or false
            }
            eggCount = eggCount + 1
        end
    end
    
    print("🥚 Loaded " .. eggCount .. " eggs from ResEgg ModuleScript")
    return convertedData
end

local function convertMutationData(rawData)
    local convertedData = {}
    local mutationCount = 0
    
    for mutationId, mutationInfo in pairs(rawData) do
        if mutationId ~= "__index" and type(mutationInfo) == "table" then
            -- Convert raw ModuleScript data to UI-friendly format
            local name = mutationInfo.ID or mutationId
            local displayName = name
            
            -- Handle special case: "Dino" should display as "Jurassic" for UI compatibility
            if mutationId == "Dino" then
                displayName = "Jurassic"
            end
            
            -- Get emoji icon based on mutation type
            local iconEmoji = "✨" -- Default
            if mutationId == "Golden" then iconEmoji = "✨"
            elseif mutationId == "Diamond" then iconEmoji = "💎"
            elseif mutationId == "Electirc" then iconEmoji = "⚡"
            elseif mutationId == "Fire" then iconEmoji = "🔥"
            elseif mutationId == "Dino" then iconEmoji = "🦕"
            elseif mutationId == "Snow" then iconEmoji = "❄️"
            end
            
            convertedData[mutationId] = {
                ID = mutationInfo.ID,
                Name = displayName, -- Use display name (Dino -> Jurassic)
                ProduceRate = mutationInfo.ProduceRate or 1,
                SellRate = mutationInfo.SellRate or 1,
                BuyRate = mutationInfo.BuyRate or 1,
                BigRate = mutationInfo.BigRate or 1,
                TextColor = mutationInfo.TextColor or "ffffff",
                Color1 = mutationInfo.Color1 or "",
                Color2 = mutationInfo.Color2 or "",
                Color3 = mutationInfo.Color3 or "",
                Neon1 = mutationInfo.Neon1 or "",
                Neon2 = mutationInfo.Neon2 or "",
                Neon3 = mutationInfo.Neon3 or "",
                RarityNum = mutationInfo.RarityNum or 10,
                Rarity = mutationInfo.RarityNum or 10, -- Use RarityNum as Rarity
                HatchTimeScale = mutationInfo.HatchTimeScale or 1,
                MinHatchTime = mutationInfo.MinHatchTime or 60,
                Icon = mutationInfo.Icon or "rbxassetid://0",
                EmojiIcon = iconEmoji,
                -- Mark new mutations (you can adjust this logic)
                IsNew = mutationId == "Snow" or false
            }
            mutationCount = mutationCount + 1
        end
    end
    
    -- Add compatibility mapping: Create "Jurassic" entry that points to "Dino" data
    if convertedData["Dino"] then
        convertedData["Jurassic"] = {
            ID = "Jurassic",
            Name = "Jurassic",
            ProduceRate = convertedData["Dino"].ProduceRate,
            SellRate = convertedData["Dino"].SellRate,
            BuyRate = convertedData["Dino"].BuyRate,
            BigRate = convertedData["Dino"].BigRate,
            TextColor = convertedData["Dino"].TextColor,
            Color1 = convertedData["Dino"].Color1,
            Color2 = convertedData["Dino"].Color2,
            Color3 = convertedData["Dino"].Color3,
            Neon1 = convertedData["Dino"].Neon1,
            Neon2 = convertedData["Dino"].Neon2,
            Neon3 = convertedData["Dino"].Neon3,
            RarityNum = convertedData["Dino"].RarityNum,
            Rarity = convertedData["Dino"].Rarity,
            HatchTimeScale = convertedData["Dino"].HatchTimeScale,
            MinHatchTime = convertedData["Dino"].MinHatchTime,
            Icon = convertedData["Dino"].Icon,
            EmojiIcon = "🦕",
            IsNew = false
        }
        print("🔄 Added Jurassic compatibility mapping for Dino mutation")
    end
    
    print("✨ Loaded " .. mutationCount .. " mutations from ResMutate ModuleScript")
    return convertedData
end

local function loadEggData()
    local success, result = pcall(function()
        local configFolder = ReplicatedStorage:WaitForChild("Config", 10)
        if not configFolder then
            error("Config folder not found")
        end
        
        local resEggModule = configFolder:WaitForChild("ResEgg", 10)
        if not resEggModule then
            error("ResEgg ModuleScript not found")
        end
        
        local rawData = require(resEggModule)
        if not rawData or type(rawData) ~= "table" then
            error("Invalid ResEgg data")
        end
        
        EggData = convertEggData(rawData)
        dataLoaded = true
        dataStatus = "✅ Loaded " .. (function()
            local count = 0
            for _ in pairs(EggData) do count = count + 1 end
            return count
        end)() .. " eggs"
        
        print("✅ EggSelection: Successfully loaded egg data from ResEgg")
        return true
    end)
    
    if not success then
        dataLoaded = false
        dataStatus = "❌ Failed to load: " .. tostring(result)
        print("❌ EggSelection: Failed to load egg data - " .. tostring(result))
        
        -- Fallback to empty data
        EggData = {}
        return false
    end
    
    return true
end

local function loadMutationData()
    local success, result = pcall(function()
        local configFolder = ReplicatedStorage:WaitForChild("Config", 10)
        if not configFolder then
            error("Config folder not found")
        end
        
        local resMutateModule = configFolder:WaitForChild("ResMutate", 10)
        if not resMutateModule then
            error("ResMutate ModuleScript not found")
        end
        
        local rawData = require(resMutateModule)
        if not rawData or type(rawData) ~= "table" then
            error("Invalid ResMutate data")
        end
        
        MutationData = convertMutationData(rawData)
        mutationDataLoaded = true
        mutationDataStatus = "✅ Loaded " .. (function()
            local count = 0
            for _ in pairs(MutationData) do count = count + 1 end
            return count
        end)() .. " mutations"
        
        print("✅ EggSelection: Successfully loaded mutation data from ResMutate")
        return true
    end)
    
    if not success then
        mutationDataLoaded = false
        mutationDataStatus = "❌ Failed to load: " .. tostring(result)
        print("❌ EggSelection: Failed to load mutation data - " .. tostring(result))
        
        -- Fallback to empty data
        MutationData = {}
        return false
    end
    
    return true
end

local function setupDataMonitoring()
    local success, result = pcall(function()
        local configFolder = ReplicatedStorage:WaitForChild("Config", 5)
        if not configFolder then return end
        
        -- Monitor for ResEgg ModuleScript changes
        configFolder.ChildAdded:Connect(function(child)
            if child.Name == "ResEgg" then
                task.wait(1) -- Wait for module to be fully loaded
                loadEggData()
                print("🔄 Reloaded egg data due to ResEgg change")
                
                -- Refresh UI if it's currently open
                if ScreenGui and ScreenGui.Enabled then
                    EggSelection.RefreshContent()
                end
            elseif child.Name == "ResMutate" then
                task.wait(1) -- Wait for module to be fully loaded
                loadMutationData()
                print("🔄 Reloaded mutation data due to ResMutate change")
                
                -- Refresh UI if it's currently open
                if ScreenGui and ScreenGui.Enabled then
                    EggSelection.RefreshContent()
                end
            end
        end)
        
        configFolder.ChildRemoved:Connect(function(child)
            if child.Name == "ResEgg" then
                dataLoaded = false
                dataStatus = "⚠️ ResEgg ModuleScript removed"
                EggData = {}
                print("⚠️ ResEgg ModuleScript was removed")
            elseif child.Name == "ResMutate" then
                mutationDataLoaded = false
                mutationDataStatus = "⚠️ ResMutate ModuleScript removed"
                MutationData = {}
                print("⚠️ ResMutate ModuleScript was removed")
            end
        end)
    end)
    
    if not success then
        print("⚠️ EggSelection: Failed to setup data monitoring - " .. tostring(result))
    end
end

-- Initialize data loading
task.spawn(function()
    loadEggData()
    loadMutationData()
    setupDataMonitoring()
end)

-- UI Variables
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ScreenGui = nil
local MainFrame = nil
local selectedItems = {}
local selectionOrder = {} -- Track order of selections for priority
local priorityNumbers = {} -- Display priority numbers on mutations
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

-- macOS Dark Theme Colors - Improved for better readability
local colors = {
    background = Color3.fromRGB(18, 18, 20), -- Darker background for better contrast
    surface = Color3.fromRGB(32, 32, 34), -- Lighter surface for cards
    primary = Color3.fromRGB(0, 122, 255), -- Brighter blue accent
    secondary = Color3.fromRGB(88, 86, 214), -- Purple accent
    text = Color3.fromRGB(255, 255, 255), -- Pure white text
    textSecondary = Color3.fromRGB(200, 200, 200), -- Brighter gray text
    textTertiary = Color3.fromRGB(150, 150, 150), -- Medium gray for placeholders
    border = Color3.fromRGB(50, 50, 52), -- Slightly darker border
    selected = Color3.fromRGB(0, 122, 255), -- Bright blue for selected
    hover = Color3.fromRGB(45, 45, 47), -- Lighter hover state
    pageActive = Color3.fromRGB(0, 122, 255), -- Bright blue for active tab
    pageInactive = Color3.fromRGB(60, 60, 62), -- Darker gray for inactive tab
    close = Color3.fromRGB(255, 69, 58), -- Red close button
    minimize = Color3.fromRGB(255, 159, 10), -- Yellow minimize
    maximize = Color3.fromRGB(48, 209, 88) -- Green maximize
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
    if rarity >= 100 then return Color3.fromRGB(255, 69, 58) -- Fire red
    elseif rarity >= 50 then return Color3.fromRGB(175, 82, 222) -- Electric purple
    elseif rarity >= 20 then return Color3.fromRGB(88, 86, 214) -- Diamond blue
    elseif rarity >= 10 then return Color3.fromRGB(255, 159, 10) -- Golden yellow
    elseif rarity >= 6 then return Color3.fromRGB(255, 45, 85) -- Ultra pink
    elseif rarity >= 5 then return Color3.fromRGB(255, 69, 58) -- Legendary red
    elseif rarity >= 4 then return Color3.fromRGB(175, 82, 222) -- Epic purple
    elseif rarity >= 3 then return Color3.fromRGB(88, 86, 214) -- Rare blue
    elseif rarity >= 2 then return Color3.fromRGB(48, 209, 88) -- Uncommon green
    else return Color3.fromRGB(174, 174, 178) -- Common gray
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

-- Create Item Card (macOS style)
local function createItemCard(itemId, itemData, parent)
    local card = Instance.new("TextButton")
    card.Name = itemId
    card.Size = UDim2.new(0.33, -8, 0, 120)
    card.BackgroundColor3 = colors.surface
    card.BorderSizePixel = 0
    card.Text = ""
    card.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = card
    
    -- Create Icon (ImageLabel for both eggs and mutations now)
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 50, 0, 50)
    icon.Position = UDim2.new(0.5, -25, 0.2, 0)
    icon.BackgroundTransparency = 1
    icon.Image = itemData.Icon
    icon.ScaleType = Enum.ScaleType.Fit
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
    
    -- Add "New" indicator for new items
    if itemData.IsNew then
        local newIndicator = Instance.new("TextLabel")
        newIndicator.Name = "NewIndicator"
        newIndicator.Size = UDim2.new(0, 30, 0, 16)
        newIndicator.Position = UDim2.new(1, -34, 0, 2)
        newIndicator.BackgroundColor3 = Color3.fromRGB(255, 69, 58) -- Red background
        newIndicator.BorderSizePixel = 0
        newIndicator.Text = "NEW"
        newIndicator.TextSize = 8
        newIndicator.Font = Enum.Font.GothamBold
        newIndicator.TextColor3 = Color3.fromRGB(255, 255, 255) -- White text
        newIndicator.TextXAlignment = Enum.TextXAlignment.Center
        newIndicator.TextYAlignment = Enum.TextYAlignment.Center
        newIndicator.Parent = card
        
        local newCorner = Instance.new("UICorner")
        newCorner.CornerRadius = UDim.new(0, 3)
        newCorner.Parent = newIndicator
    end
    
    -- Priority number for mutations (shows selection order)
    local priorityLabel = nil
    if currentPage == "mutations" then
        priorityLabel = Instance.new("TextLabel")
        priorityLabel.Name = "PriorityLabel"
        priorityLabel.Size = UDim2.new(0, 20, 0, 20)
        priorityLabel.Position = UDim2.new(0, 4, 0, 4)
        priorityLabel.BackgroundColor3 = colors.primary
        priorityLabel.BorderSizePixel = 0
        priorityLabel.Text = ""
        priorityLabel.TextSize = 12
        priorityLabel.Font = Enum.Font.GothamBold
        priorityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        priorityLabel.TextXAlignment = Enum.TextXAlignment.Center
        priorityLabel.TextYAlignment = Enum.TextYAlignment.Center
        priorityLabel.Visible = false
        priorityLabel.Parent = card
        
        local priorityCorner = Instance.new("UICorner")
        priorityCorner.CornerRadius = UDim.new(0.5, 0)
        priorityCorner.Parent = priorityLabel
    end
    
    -- Set initial selection state
    if selectedItems[itemId] then
        checkmark.Visible = true
        card.BackgroundColor3 = colors.selected
        
        -- Show priority number for mutations
        if priorityLabel and priorityNumbers[itemId] then
            priorityLabel.Text = tostring(priorityNumbers[itemId])
            priorityLabel.Visible = true
        end
    end
    
    -- Hover effect
    card.MouseEnter:Connect(function()
        if not selectedItems[itemId] then
            TweenService:Create(card, TweenInfo.new(0.2), {BackgroundColor3 = colors.hover}):Play()
        end
    end)
    
    card.MouseLeave:Connect(function()
        if not selectedItems[itemId] then
            TweenService:Create(card, TweenInfo.new(0.2), {BackgroundColor3 = colors.surface}):Play()
        end
    end)
    
    -- Click effect with priority tracking
    card.MouseButton1Click:Connect(function()
        if selectedItems[itemId] then
            -- Deselecting item
            selectedItems[itemId] = nil
            checkmark.Visible = false
            TweenService:Create(card, TweenInfo.new(0.2), {BackgroundColor3 = colors.surface}):Play()
            
            -- Remove from selection order and update priorities
            for i, orderedItem in ipairs(selectionOrder) do
                if orderedItem == itemId then
                    table.remove(selectionOrder, i)
                    break
                end
            end
            
            -- Hide priority label for mutations
            if priorityLabel then
                priorityLabel.Visible = false
                priorityNumbers[itemId] = nil
            end
            
            -- Update priority numbers for remaining mutations
            if currentPage == "mutations" then
                for i, orderedItem in ipairs(selectionOrder) do
                    if MutationData[orderedItem] then
                        priorityNumbers[orderedItem] = i
                    end
                end
                -- Refresh content to update all priority displays
                EggSelection.RefreshContent()
            end
        else
            -- Selecting item
            selectedItems[itemId] = true
            checkmark.Visible = true
            TweenService:Create(card, TweenInfo.new(0.2), {BackgroundColor3 = colors.selected}):Play()
            
            -- Add to selection order
            table.insert(selectionOrder, itemId)
            
            -- Set priority number for mutations
            if priorityLabel and currentPage == "mutations" then
                local priorityNum = 0
                for i, orderedItem in ipairs(selectionOrder) do
                    if MutationData[orderedItem] then
                        priorityNum = priorityNum + 1
                        if orderedItem == itemId then
                            priorityNumbers[itemId] = priorityNum
                            priorityLabel.Text = tostring(priorityNum)
                            priorityLabel.Visible = true
                            break
                        end
                    end
                end
            end
        end
        
        if onSelectionChanged then
            onSelectionChanged(selectedItems, selectionOrder)
        end
    end)
    
    return card
end

-- Create Search Bar (macOS style)
local function createSearchBar(parent)
    local searchContainer = Instance.new("Frame")
    searchContainer.Name = "SearchContainer"
    searchContainer.Size = UDim2.new(1, -32, 0, 32)
    searchContainer.Position = UDim2.new(0, 16, 0, 60)
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
    searchBox.PlaceholderText = "Search eggs..."
    searchBox.TextSize = 14
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextColor3 = colors.text
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.ClearTextOnFocus = false
    searchBox.Parent = searchContainer
    
    -- Set placeholder text color using a different approach
    searchBox.Focused:Connect(function()
        if searchBox.Text == "" then
            searchBox.Text = ""
        end
    end)
    
    searchBox.FocusLost:Connect(function()
        if searchBox.Text == "" then
            searchBox.Text = ""
        end
    end)
    
    -- Search functionality
    searchBox.Changed:Connect(function(prop)
        if prop == "Text" then
            searchText = searchBox.Text
            EggSelection.RefreshContent()
        end
    end)
    
    return searchContainer
end

-- Create Page Tabs (macOS style)
local function createPageTabs(parent)
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "PageTabs"
    tabContainer.Size = UDim2.new(1, -32, 0, 40)
    tabContainer.Position = UDim2.new(0, 16, 0, 100)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = parent
    
    local eggsTab = Instance.new("TextButton")
    eggsTab.Name = "EggsTab"
    eggsTab.Size = UDim2.new(0.5, -4, 1, 0)
    eggsTab.Position = UDim2.new(0, 0, 0, 0)
    eggsTab.BackgroundColor3 = colors.pageActive
    eggsTab.BorderSizePixel = 0
    eggsTab.Text = "🥚 Eggs"
    eggsTab.TextSize = 14
    eggsTab.Font = Enum.Font.GothamSemibold
    eggsTab.TextColor3 = colors.text
    eggsTab.Parent = tabContainer
    
    local eggsCorner = Instance.new("UICorner")
    eggsCorner.CornerRadius = UDim.new(0, 6)
    eggsCorner.Parent = eggsTab
    
    local mutationsTab = Instance.new("TextButton")
    mutationsTab.Name = "MutationsTab"
    mutationsTab.Size = UDim2.new(0.5, -4, 1, 0)
    mutationsTab.Position = UDim2.new(0.5, 4, 0, 0)
    mutationsTab.BackgroundColor3 = colors.pageInactive
    mutationsTab.BorderSizePixel = 0
    mutationsTab.Text = "✨ Mutations"
    mutationsTab.TextSize = 14
    mutationsTab.Font = Enum.Font.GothamSemibold
    mutationsTab.TextColor3 = colors.text
    mutationsTab.Parent = tabContainer
    
    local mutationsCorner = Instance.new("UICorner")
    mutationsCorner.CornerRadius = UDim.new(0, 6)
    mutationsCorner.Parent = mutationsTab
    
    -- Tab click events
    eggsTab.MouseButton1Click:Connect(function()
        currentPage = "eggs"
        eggsTab.BackgroundColor3 = colors.pageActive
        eggsTab.TextColor3 = colors.text
        mutationsTab.BackgroundColor3 = colors.pageInactive
        mutationsTab.TextColor3 = colors.text
        -- Update search placeholder
        local searchBox = ScreenGui.MainFrame.SearchContainer.SearchBox
        if searchBox then
            searchBox.PlaceholderText = "Search eggs..."
        end
        EggSelection.RefreshContent()
    end)
    
    mutationsTab.MouseButton1Click:Connect(function()
        currentPage = "mutations"
        mutationsTab.BackgroundColor3 = colors.pageActive
        mutationsTab.TextColor3 = colors.text
        eggsTab.BackgroundColor3 = colors.pageInactive
        eggsTab.TextColor3 = colors.text
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
    MainFrame.Size = UDim2.new(0, 600, 0, 400)
    MainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
    MainFrame.BackgroundColor3 = colors.background
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    originalSize = MainFrame.Size
    minimizedSize = UDim2.new(0, 600, 0, 60)
    
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
    title.Text = "Egg Selection"
    title.TextSize = 14
    title.Font = Enum.Font.GothamSemibold
    title.TextColor3 = colors.text
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = MainFrame
    
    -- Page Tabs
    local pageTabs = createPageTabs(MainFrame)
    
    -- Search Bar
    local searchBar = createSearchBar(MainFrame)
    
    -- Content Area
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -32, 1, -160)
    content.Position = UDim2.new(0, 16, 0, 160)
    content.BackgroundTransparency = 1
    content.Parent = MainFrame
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = colors.primary
    -- Disable AutomaticCanvasSize and handle manually for better control
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 1000) -- Start with reasonable default
    scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    scrollFrame.ScrollingEnabled = true
    scrollFrame.Parent = content
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.33, -8, 0, 120)
    gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.Parent = scrollFrame
    
    -- Add UIPadding to ensure proper scrolling
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 50)
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = scrollFrame
    
    -- Window Control Events
    local closeBtn = windowControls.CloseBtn
    local minimizeBtn = windowControls.MinimizeBtn
    local maximizeBtn = windowControls.MaximizeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        -- Save current selections and order before closing
        if onSelectionChanged then
            onSelectionChanged(selectedItems, selectionOrder)
        end
        
        if onToggleChanged then
            onToggleChanged(false)
        end
        ScreenGui:Destroy()
        ScreenGui = nil
    end)
    
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
    
    maximizeBtn.MouseButton1Click:Connect(function()
        -- Toggle between normal and full size
        if MainFrame.Size == originalSize then
            MainFrame.Size = UDim2.new(0.8, 0, 0.8, 0)
            MainFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
        else
            MainFrame.Size = originalSize
            MainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
        end
    end)
    
    -- Dragging - Fixed to work properly
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

-- Update ScrollingFrame canvas size based on content
local function updateCanvasSize(scrollFrame)
    local gridLayout = scrollFrame:FindFirstChild("UIGridLayout")
    if not gridLayout then return end
    
    -- Wait for layout to update
    task.wait(0.2)
    
    -- Calculate content size based on grid layout
    local itemCount = 0
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            itemCount = itemCount + 1
        end
    end
    
    if itemCount > 0 then
        -- Calculate rows needed (3 items per row)
        local rows = math.ceil(itemCount / 3)
        local cellHeight = 120 -- Height of each cell
        local cellPadding = 8 -- Padding between cells
        local topPadding = 8 -- Top padding from UIPadding
        local bottomPadding = 50 -- Bottom padding from UIPadding
        
        -- More accurate calculation including all padding
        local totalHeight = topPadding + (rows * cellHeight) + ((rows - 1) * cellPadding) + bottomPadding
        
        -- Always update canvas size to ensure proper scrolling
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
        
        -- Also force a canvas position reset to ensure scrollability
        scrollFrame.CanvasPosition = Vector2.new(0, 0)
    end
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
        
        -- Apply saved selection state
        if selectedItems[item.id] then
            local checkmark = card:FindFirstChild("Checkmark")
            if checkmark then
                checkmark.Visible = true
            end
            card.BackgroundColor3 = colors.selected
        end
    end
    
    -- Update canvas size to ensure proper scrolling
    -- Multiple approaches to ensure it works properly
    task.spawn(function()
        updateCanvasSize(scrollFrame)
    end)
    
    -- Also try after a longer delay as backup
    task.spawn(function()
        task.wait(0.5)
        updateCanvasSize(scrollFrame)
    end)
    
    -- Connect to layout changes for real-time updates
    local gridLayout = scrollFrame:FindFirstChild("UIGridLayout")
    if gridLayout then
        local connection = nil
        connection = gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            task.wait(0.1)
            local itemCount = 0
            for _, child in pairs(scrollFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    itemCount = itemCount + 1
                end
            end
            
            if itemCount > 0 then
                local rows = math.ceil(itemCount / 3)
                local totalHeight = 8 + (rows * 120) + ((rows - 1) * 8) + 50
                scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
            end
            
            -- Disconnect after first successful update
            if connection then
                connection:Disconnect()
                connection = nil
            end
        end)
    end
end

-- Public Functions
function EggSelection.Show(callback, toggleCallback, savedEggs, savedMutations, savedOrder)
    onSelectionChanged = callback
    onToggleChanged = toggleCallback
    
    -- Clear previous data
    selectedItems = {}
    selectionOrder = {}
    priorityNumbers = {}
    
    -- Apply saved selections if provided
    if savedEggs then
        for eggId, _ in pairs(savedEggs) do
            selectedItems[eggId] = true
            table.insert(selectionOrder, eggId)
        end
    end
    
    if savedMutations then
        for mutationId, _ in pairs(savedMutations) do
            selectedItems[mutationId] = true
            table.insert(selectionOrder, mutationId)
        end
    end
    
    -- Apply saved selection order if provided (priority preservation)
    if savedOrder then
        selectionOrder = {}
        -- First, add items from saved order that are still selected
        for _, itemId in ipairs(savedOrder) do
            if selectedItems[itemId] then
                table.insert(selectionOrder, itemId)
            end
        end
        -- Then add any newly selected items that weren't in the saved order
        for itemId, _ in pairs(selectedItems) do
            local found = false
            for _, orderedItem in ipairs(selectionOrder) do
                if orderedItem == itemId then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(selectionOrder, itemId)
            end
        end
    end
    
    -- Calculate priority numbers for mutations
    local mutationPriority = 1
    for _, itemId in ipairs(selectionOrder) do
        if MutationData[itemId] then
            priorityNumbers[itemId] = mutationPriority
            mutationPriority = mutationPriority + 1
        end
    end
    
    if not ScreenGui then
        EggSelection.CreateUI()
    end
    
    -- Wait a frame to ensure UI is created
    task.wait()
    EggSelection.RefreshContent()
    ScreenGui.Enabled = true
    ScreenGui.Parent = PlayerGui
end

function EggSelection.Hide()
    if ScreenGui then
        -- Save current selections and order before hiding
        if onSelectionChanged then
            onSelectionChanged(selectedItems, selectionOrder)
        end
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
                if checkmark then
                    if selectedItems[child.Name] then
                        checkmark.Visible = true
                        child.BackgroundColor3 = colors.selected
                    else
                        checkmark.Visible = false
                        child.BackgroundColor3 = colors.surface
                    end
                end
            end
        end
    end
end

function EggSelection.IsVisible()
    return ScreenGui and ScreenGui.Enabled
end

function EggSelection.GetCurrentSelections()
    return selectedItems
end

function EggSelection.GetSelectionOrder()
    return selectionOrder
end

function EggSelection.GetPriorityNumbers()
    return priorityNumbers
end

function EggSelection.UpdateSelections(eggs, mutations, order)
    selectedItems = {}
    selectionOrder = {}
    priorityNumbers = {}
    
    if eggs then
        for eggId, _ in pairs(eggs) do
            selectedItems[eggId] = true
            table.insert(selectionOrder, eggId)
        end
    end
    
    if mutations then
        for mutationId, _ in pairs(mutations) do
            selectedItems[mutationId] = true
            table.insert(selectionOrder, mutationId)
        end
    end
    
    if order then
        selectionOrder = {}
        for _, itemId in ipairs(order) do
            if selectedItems[itemId] then
                table.insert(selectionOrder, itemId)
            end
        end
    end
    
    -- Calculate priority numbers for mutations
    local mutationPriority = 1
    for _, itemId in ipairs(selectionOrder) do
        if MutationData[itemId] then
            priorityNumbers[itemId] = mutationPriority
            mutationPriority = mutationPriority + 1
        end
    end
    
    if ScreenGui then
        EggSelection.RefreshContent()
    end
end



-- Public API functions
function EggSelection.GetEggData()
    return EggData
end

function EggSelection.GetMutationData()
    return MutationData
end

function EggSelection.IsDataLoaded()
    return dataLoaded and mutationDataLoaded
end

function EggSelection.IsEggDataLoaded()
    return dataLoaded
end

function EggSelection.IsMutationDataLoaded()
    return mutationDataLoaded
end

function EggSelection.ReloadData()
    local eggSuccess = loadEggData()
    local mutationSuccess = loadMutationData()
    return eggSuccess and mutationSuccess
end

function EggSelection.ReloadEggData()
    return loadEggData()
end

function EggSelection.ReloadMutationData()
    return loadMutationData()
end

function EggSelection.GetDataStatus()
    return dataStatus .. " | " .. mutationDataStatus
end

function EggSelection.GetEggDataStatus()
    return dataStatus
end

function EggSelection.GetMutationDataStatus()
    return mutationDataStatus
end

-- Global access for other systems
_G.EggSelection = EggSelection

return EggSelection



