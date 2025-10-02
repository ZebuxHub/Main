-- FeedFruitSelection.lua - macOS Style Dark Theme UI for Fruit Selection (Auto Feed)
-- Author: Zebux
-- Version: 1.0

local FeedFruitSelection = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Name normalization helpers for inventory mapping
local function normalizeFruitName(name)
	if type(name) ~= "string" then return "" end
	local lowered = string.lower(name)
	lowered = lowered:gsub("[%s_%-%./]", "")
	return lowered
end

-- Will be filled after FruitData is defined
local FRUIT_CANONICAL = nil

-- Hardcoded fruit data for feeding
local FruitData = {
	Strawberry = {
		Name = "Strawberry",
		Price = "5,000",
		Icon = "🍓",
		Rarity = 1
	},
	Blueberry = {
		Name = "Blueberry",
		Price = "20,000",
		Icon = "🔵",
		Rarity = 1
	},
	Watermelon = {
		Name = "Watermelon",
		Price = "80,000",
		Icon = "🍉",
		Rarity = 2
	},
	Apple = {
		Name = "Apple",
		Price = "400,000",
		Icon = "🍎",
		Rarity = 2
	},
	Orange = {
		Name = "Orange",
		Price = "1,200,000",
		Icon = "🍊",
		Rarity = 3
	},
	Corn = {
		Name = "Corn",
		Price = "3,500,000",
		Icon = "🌽",
		Rarity = 3
	},
	Banana = {
		Name = "Banana",
		Price = "12,000,000",
		Icon = "🍌",
		Rarity = 4
	},
	Grape = {
		Name = "Grape",
		Price = "50,000,000",
		Icon = "🍇",
		Rarity = 4
	},
	Pear = {
		Name = "Pear",
		Price = "200,000,000",
		Icon = "🍐",
		Rarity = 5
	},
	Pineapple = {
		Name = "Pineapple",
		Price = "600,000,000",
		Icon = "🍍",
		Rarity = 5
	},
	GoldMango = {
		Name = "Gold Mango",
		Price = "2,000,000,000",
		Icon = "🥭",
		Rarity = 6
	},
	BloodstoneCycad = {
		Name = "Bloodstone Cycad",
		Price = "8,000,000,000",
		Icon = "🌿",
		Rarity = 6
	},
	ColossalPinecone = {
		Name = "Colossal Pinecone",
		Price = "40,000,000,000",
		Icon = "🌲",
		Rarity = 6
	},
	VoltGinkgo = {
		Name = "Volt Ginkgo",
		Price = "80,000,000,000",
		Icon = "⚡",
		Rarity = 6
	},
	DeepseaPearlFruit = {
		Name = "DeepseaPearlFruit",
		Price = "40,000,000,000",
		Icon = "💠",
		Rarity = 6
	},
	Durian = {
		Name = "Durian",
		Price = "80,000,000,000",
		Icon = "🥥",
		Rarity = 6,
		IsNew = true
	},
	DragonFruit = {
		Name = "Dragon Fruit",
		Price = "1,500,000,000",
		Icon = "🐲",
		Rarity = 6,
		IsNew = true
	}
}

-- Build canonical name map from FruitData
local function buildFruitCanonical()
	local map = {}
	for id, item in pairs(FruitData) do
		local display = item.Name or id
		map[normalizeFruitName(id)] = display
		map[normalizeFruitName(display)] = display
	end
	return map
end
FRUIT_CANONICAL = buildFruitCanonical()

-- Function to get player's owned Big Pets only
local function getPlayerOwnedPets()
    local pets = {}
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return pets end
    
    -- Get Big Pets from workspace.Pets (only pets with BigPetGUI)
    local petsFolder = workspace:FindFirstChild("Pets")
    if not petsFolder then return pets end
    
    for _, petModel in ipairs(petsFolder:GetChildren()) do
        if petModel:IsA("Model") then
            local rootPart = petModel:FindFirstChild("RootPart")
            if rootPart then
                -- Check if it's our pet
                local petUserId = rootPart:GetAttribute("UserId")
                if petUserId and tostring(petUserId) == tostring(localPlayer.UserId) then
                    -- Check if this is a Big Pet (has BigPetGUI)
                    local bigPetGUI = rootPart:FindFirstChild("GUI/BigPetGUI")
                    if bigPetGUI then
                        -- Get pet type for display
                        local petType = rootPart:GetAttribute("T") or petModel.Name
                        
                        table.insert(pets, {
                            name = petModel.Name, -- UID for feeding
                            type = petType,
                            displayName = petType or petModel.Name
                        })
                    end
                end
            end
        end
    end
    
    -- Sort by display name for consistent display
    table.sort(pets, function(a, b)
        return a.displayName < b.displayName
    end)
    
    return pets
end

-- Local function to read player's fruit inventory using canonical name matching
local function getPlayerFruitInventory()
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return {}
	end

	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return {}
	end

	local data = playerGui:FindFirstChild("Data")
	if not data then
		return {}
	end

	local asset = data:FindFirstChild("Asset")
	if not asset then
		return {}
	end

    local fruitInventory = {}

    -- First, read from Attributes on Asset (primary source)
    local attrMap = {}
    local ok, attrs = pcall(function()
        return asset:GetAttributes()
    end)
    if ok and type(attrs) == "table" then
        attrMap = attrs
    end
    for id, item in pairs(FruitData) do
        local display = item.Name or id
        local amount = attrMap[display] or attrMap[id]
        if amount == nil then
            -- Fallback by normalized key search
            local wantA, wantB = normalizeFruitName(display), normalizeFruitName(id)
            for k, v in pairs(attrMap) do
                local nk = normalizeFruitName(k)
                if nk == wantA or nk == wantB then
                    amount = v
                    break
                end
            end
        end
        if type(amount) == "string" then amount = tonumber(amount) or 0 end
        if type(amount) == "number" and amount > 0 then
            fruitInventory[display] = amount
        end
    end

    -- Also support legacy children-based values as fallback/merge
    for _, child in pairs(asset:GetChildren()) do
        if child:IsA("StringValue") or child:IsA("IntValue") or child:IsA("NumberValue") then
            local normalized = normalizeFruitName(child.Name)
            local canonical = FRUIT_CANONICAL and FRUIT_CANONICAL[normalized]
            if canonical then
                local amount = child.Value
                if type(amount) == "string" then amount = tonumber(amount) or 0 end
                if type(amount) == "number" and amount > 0 then
                    fruitInventory[canonical] = amount
                end
            end
        end
    end

    return fruitInventory
end

-- UI Variables
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ScreenGui = nil
local MainFrame = nil
local selectedItems = {}
local fruitPetAssignments = {} -- Table to store which pets each fruit should feed: {FruitID = {PetName1 = true, PetName2 = true}}
local isDragging = false
local dragStart = nil
local startPos = nil
local isMinimized = false
local originalSize = nil
local minimizedSize = nil
local searchText = ""

-- Callback functions
local onSelectionChanged = nil
local onToggleChanged = nil

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
    close = Color3.fromRGB(255, 69, 58),
    minimize = Color3.fromRGB(255, 159, 10),
    maximize = Color3.fromRGB(48, 209, 88)
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
    if rarity >= 100 then return Color3.fromRGB(255, 69, 58)
    elseif rarity >= 50 then return Color3.fromRGB(175, 82, 222)
    elseif rarity >= 20 then return Color3.fromRGB(88, 86, 214)
    elseif rarity >= 10 then return Color3.fromRGB(255, 159, 10)
    elseif rarity >= 6 then return Color3.fromRGB(255, 45, 85)
    elseif rarity >= 5 then return Color3.fromRGB(255, 69, 58)
    elseif rarity >= 4 then return Color3.fromRGB(175, 82, 222)
    elseif rarity >= 3 then return Color3.fromRGB(88, 86, 214)
    elseif rarity >= 2 then return Color3.fromRGB(48, 209, 88)
    else return Color3.fromRGB(174, 174, 178)
    end
end

-- Price parsing function
local function parsePrice(priceStr)
    if type(priceStr) == "number" then
        return priceStr
    end
    local cleanPrice = priceStr:gsub(",", "")
    return tonumber(cleanPrice) or 0
end

-- Sort data by price (low to high)
local function sortDataByPrice(data)
    local sortedData = {}
    for id, item in pairs(data) do
        table.insert(sortedData, {id = id, data = item})
    end
    
    table.sort(sortedData, function(a, b)
        local priceA = parsePrice(a.data.Price)
        local priceB = parsePrice(b.data.Price)
        return priceA < priceB
    end)
    
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

-- Create Pet Selection Popup
local function createPetSelectionPopup(fruitId, fruitName, parentFrame)
    -- Create overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "PetSelectionOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 100
    overlay.Parent = parentFrame
    
    -- Create popup frame
    local popup = Instance.new("Frame")
    popup.Name = "PetSelectionPopup"
    popup.Size = UDim2.new(0, 400, 0, 500)
    popup.Position = UDim2.new(0.5, -200, 0.5, -250)
    popup.BackgroundColor3 = colors.background
    popup.BorderSizePixel = 0
    popup.ZIndex = 101
    popup.Parent = overlay
    
    local popupCorner = Instance.new("UICorner")
    popupCorner.CornerRadius = UDim.new(0, 12)
    popupCorner.Parent = popup
    
    local popupStroke = Instance.new("UIStroke")
    popupStroke.Color = colors.primary
    popupStroke.Thickness = 2
    popupStroke.Parent = popup
    
    -- Title
    local popupTitle = Instance.new("TextLabel")
    popupTitle.Name = "Title"
    popupTitle.Size = UDim2.new(1, -32, 0, 40)
    popupTitle.Position = UDim2.new(0, 16, 0, 16)
    popupTitle.BackgroundTransparency = 1
    popupTitle.Text = "🍎 " .. fruitName .. " → Feed To Big Pets:"
    popupTitle.TextSize = 16
    popupTitle.Font = Enum.Font.GothamBold
    popupTitle.TextColor3 = colors.text
    popupTitle.TextXAlignment = Enum.TextXAlignment.Left
    popupTitle.ZIndex = 102
    popupTitle.Parent = popup
    
    -- Subtitle
    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Size = UDim2.new(1, -32, 0, 20)
    subtitle.Position = UDim2.new(0, 16, 0, 52)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "เลือก Big Pets ที่ต้องการให้ป้อนผลไม้นี้"
    subtitle.TextSize = 12
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextColor3 = colors.textSecondary
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.ZIndex = 102
    subtitle.Parent = popup
    
    -- Pets scroll frame
    local petsScroll = Instance.new("ScrollingFrame")
    petsScroll.Name = "PetsScroll"
    petsScroll.Size = UDim2.new(1, -32, 1, -160)
    petsScroll.Position = UDim2.new(0, 16, 0, 80)
    petsScroll.BackgroundColor3 = colors.surface
    petsScroll.BorderSizePixel = 0
    petsScroll.ScrollBarThickness = 6
    petsScroll.ScrollBarImageColor3 = colors.primary
    petsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    petsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    petsScroll.ZIndex = 102
    petsScroll.Parent = popup
    
    local petsScrollCorner = Instance.new("UICorner")
    petsScrollCorner.CornerRadius = UDim.new(0, 8)
    petsScrollCorner.Parent = petsScroll
    
    local petsLayout = Instance.new("UIListLayout")
    petsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    petsLayout.Padding = UDim.new(0, 4)
    petsLayout.Parent = petsScroll
    
    local petsPadding = Instance.new("UIPadding")
    petsPadding.PaddingTop = UDim.new(0, 8)
    petsPadding.PaddingBottom = UDim.new(0, 8)
    petsPadding.PaddingLeft = UDim.new(0, 8)
    petsPadding.PaddingRight = UDim.new(0, 8)
    petsPadding.Parent = petsScroll
    
    -- Get player's pets
    local playerPets = getPlayerOwnedPets()
    
    -- Initialize fruit pet assignments if not exists
    if not fruitPetAssignments[fruitId] then
        fruitPetAssignments[fruitId] = {}
    end
    
    -- "Select All" button
    local selectAllBtn = Instance.new("TextButton")
    selectAllBtn.Name = "SelectAll"
    selectAllBtn.Size = UDim2.new(1, -16, 0, 36)
    selectAllBtn.BackgroundColor3 = colors.primary
    selectAllBtn.BorderSizePixel = 0
    selectAllBtn.Text = "✓ เลือกทั้งหมด"
    selectAllBtn.TextSize = 14
    selectAllBtn.Font = Enum.Font.GothamBold
    selectAllBtn.TextColor3 = colors.text
    selectAllBtn.ZIndex = 103
    selectAllBtn.LayoutOrder = 0
    selectAllBtn.Parent = petsScroll
    
    local selectAllCorner = Instance.new("UICorner")
    selectAllCorner.CornerRadius = UDim.new(0, 6)
    selectAllCorner.Parent = selectAllBtn
    
    selectAllBtn.MouseButton1Click:Connect(function()
        for _, petInfo in ipairs(playerPets) do
            fruitPetAssignments[fruitId][petInfo.name] = true
        end
        -- Refresh pet items
        for _, child in ipairs(petsScroll:GetChildren()) do
            if child:IsA("TextButton") and child.Name ~= "SelectAll" and child.Name ~= "ClearAll" then
                local checkmark = child:FindFirstChild("Checkmark")
                if checkmark then
                    checkmark.Visible = true
                    child.BackgroundColor3 = colors.selected
                end
            end
        end
    end)
    
    -- "Clear All" button
    local clearAllBtn = Instance.new("TextButton")
    clearAllBtn.Name = "ClearAll"
    clearAllBtn.Size = UDim2.new(1, -16, 0, 36)
    clearAllBtn.BackgroundColor3 = colors.close
    clearAllBtn.BorderSizePixel = 0
    clearAllBtn.Text = "✗ ล้างทั้งหมด"
    clearAllBtn.TextSize = 14
    clearAllBtn.Font = Enum.Font.GothamBold
    clearAllBtn.TextColor3 = colors.text
    clearAllBtn.ZIndex = 103
    clearAllBtn.LayoutOrder = 1
    clearAllBtn.Parent = petsScroll
    
    local clearAllCorner = Instance.new("UICorner")
    clearAllCorner.CornerRadius = UDim.new(0, 6)
    clearAllCorner.Parent = clearAllBtn
    
    clearAllBtn.MouseButton1Click:Connect(function()
        fruitPetAssignments[fruitId] = {}
        -- Refresh pet items
        for _, child in ipairs(petsScroll:GetChildren()) do
            if child:IsA("TextButton") and child.Name ~= "SelectAll" and child.Name ~= "ClearAll" then
                local checkmark = child:FindFirstChild("Checkmark")
                if checkmark then
                    checkmark.Visible = false
                    child.BackgroundColor3 = colors.surface
                end
            end
        end
    end)
    
    -- Create pet items
    for i, petInfo in ipairs(playerPets) do
        local petItem = Instance.new("TextButton")
        petItem.Name = petInfo.name
        petItem.Size = UDim2.new(1, -16, 0, 44)
        petItem.BackgroundColor3 = colors.surface
        petItem.BorderSizePixel = 0
        petItem.Text = ""
        petItem.ZIndex = 103
        petItem.LayoutOrder = i + 1
        petItem.Parent = petsScroll
        
        local petItemCorner = Instance.new("UICorner")
        petItemCorner.CornerRadius = UDim.new(0, 6)
        petItemCorner.Parent = petItem
        
        local petItemStroke = Instance.new("UIStroke")
        petItemStroke.Color = colors.border
        petItemStroke.Thickness = 1
        petItemStroke.ZIndex = 103
        petItemStroke.Parent = petItem
        
        -- Pet name
        local petNameLabel = Instance.new("TextLabel")
        petNameLabel.Name = "PetName"
        petNameLabel.Size = UDim2.new(1, -48, 1, 0)
        petNameLabel.Position = UDim2.new(0, 12, 0, 0)
        petNameLabel.BackgroundTransparency = 1
        petNameLabel.Text = petInfo.displayName
        petNameLabel.TextSize = 14
        petNameLabel.Font = Enum.Font.GothamSemibold
        petNameLabel.TextColor3 = colors.text
        petNameLabel.TextXAlignment = Enum.TextXAlignment.Left
        petNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        petNameLabel.ZIndex = 104
        petNameLabel.Parent = petItem
        
        -- Checkmark
        local checkmark = Instance.new("TextLabel")
        checkmark.Name = "Checkmark"
        checkmark.Size = UDim2.new(0, 24, 0, 24)
        checkmark.Position = UDim2.new(1, -32, 0.5, -12)
        checkmark.BackgroundTransparency = 1
        checkmark.Text = "✓"
        checkmark.TextSize = 18
        checkmark.Font = Enum.Font.GothamBold
        checkmark.TextColor3 = colors.selected
        checkmark.Visible = fruitPetAssignments[fruitId][petInfo.name] == true
        checkmark.ZIndex = 104
        checkmark.Parent = petItem
        
        -- Set initial background if selected
        if fruitPetAssignments[fruitId][petInfo.name] then
            petItem.BackgroundColor3 = colors.selected
        end
        
        -- Click handler
        petItem.MouseButton1Click:Connect(function()
            if fruitPetAssignments[fruitId][petInfo.name] then
                fruitPetAssignments[fruitId][petInfo.name] = nil
                checkmark.Visible = false
                TweenService:Create(petItem, TweenInfo.new(0.2), {BackgroundColor3 = colors.surface}):Play()
            else
                fruitPetAssignments[fruitId][petInfo.name] = true
                checkmark.Visible = true
                TweenService:Create(petItem, TweenInfo.new(0.2), {BackgroundColor3 = colors.selected}):Play()
            end
        end)
        
        -- Hover effect
        petItem.MouseEnter:Connect(function()
            if not fruitPetAssignments[fruitId][petInfo.name] then
                TweenService:Create(petItem, TweenInfo.new(0.2), {BackgroundColor3 = colors.hover}):Play()
            end
        end)
        
        petItem.MouseLeave:Connect(function()
            if not fruitPetAssignments[fruitId][petInfo.name] then
                TweenService:Create(petItem, TweenInfo.new(0.2), {BackgroundColor3 = colors.surface}):Play()
            end
        end)
    end
    
    -- Bottom buttons
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Name = "ButtonContainer"
    buttonContainer.Size = UDim2.new(1, -32, 0, 44)
    buttonContainer.Position = UDim2.new(0, 16, 1, -60)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.ZIndex = 102
    buttonContainer.Parent = popup
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0.48, 0, 1, 0)
    closeBtn.Position = UDim2.new(0, 0, 0, 0)
    closeBtn.BackgroundColor3 = colors.surface
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "ปิด"
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextColor3 = colors.text
    closeBtn.ZIndex = 103
    closeBtn.Parent = buttonContainer
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 8)
    closeBtnCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)
    
    -- Save button
    local saveBtn = Instance.new("TextButton")
    saveBtn.Name = "SaveBtn"
    saveBtn.Size = UDim2.new(0.48, 0, 1, 0)
    saveBtn.Position = UDim2.new(0.52, 0, 0, 0)
    saveBtn.BackgroundColor3 = colors.primary
    saveBtn.BorderSizePixel = 0
    saveBtn.Text = "✓ บันทึก"
    saveBtn.TextSize = 14
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextColor3 = colors.text
    saveBtn.ZIndex = 103
    saveBtn.Parent = buttonContainer
    
    local saveBtnCorner = Instance.new("UICorner")
    saveBtnCorner.CornerRadius = UDim.new(0, 8)
    saveBtnCorner.Parent = saveBtn
    
    saveBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
        -- Trigger callback if needed
        if onSelectionChanged then
            onSelectionChanged(selectedItems, fruitPetAssignments)
        end
    end)
    
    -- Close on overlay click
    overlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mousePos = UserInputService:GetMouseLocation()
            local popupPos = popup.AbsolutePosition
            local popupSize = popup.AbsoluteSize
            
            -- Check if click is outside popup
            if mousePos.X < popupPos.X or mousePos.X > popupPos.X + popupSize.X or
               mousePos.Y < popupPos.Y or mousePos.Y > popupPos.Y + popupSize.Y then
                overlay:Destroy()
            end
        end
    end)
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
    
    -- Create Icon (TextLabel for fruits)
    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 50, 0, 50)
    icon.Position = UDim2.new(0.5, -25, 0.2, 0)
    icon.BackgroundTransparency = 1
    icon.Text = itemData.Icon
    icon.TextSize = 32
    icon.Font = Enum.Font.GothamBold
    icon.TextColor3 = getRarityColor(itemData.Rarity)
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
    price.Size = UDim2.new(1, -16, 0, 14)
    price.Position = UDim2.new(0, 8, 0.75, 0)
    price.BackgroundTransparency = 1
    price.Text = "Loading..." -- Will be updated with inventory count
    price.TextSize = 10
    price.Font = Enum.Font.Gotham
    price.TextColor3 = colors.textSecondary
    price.TextXAlignment = Enum.TextXAlignment.Center
    price.TextWrapped = true
    price.Parent = card
    
    -- Pet selection button
    local petSelectBtn = Instance.new("TextButton")
    petSelectBtn.Name = "PetSelectBtn"
    petSelectBtn.Size = UDim2.new(0.9, 0, 0, 22)
    petSelectBtn.Position = UDim2.new(0.05, 0, 0.88, 0)
    petSelectBtn.BackgroundColor3 = colors.primary
    petSelectBtn.BorderSizePixel = 0
    petSelectBtn.Text = "🐾 Big Pets"
    petSelectBtn.TextSize = 9
    petSelectBtn.Font = Enum.Font.GothamBold
    petSelectBtn.TextColor3 = colors.text
    petSelectBtn.ZIndex = 2
    petSelectBtn.Parent = card
    
    local petSelectCorner = Instance.new("UICorner")
    petSelectCorner.CornerRadius = UDim.new(0, 4)
    petSelectCorner.Parent = petSelectBtn
    
    -- Update button text to show assigned pet count
    local function updatePetButtonText()
        local assignedCount = 0
        if fruitPetAssignments[itemId] then
            for _ in pairs(fruitPetAssignments[itemId]) do
                assignedCount = assignedCount + 1
            end
        end
        
        if assignedCount > 0 then
            petSelectBtn.Text = string.format("🐾 %d Pets", assignedCount)
            petSelectBtn.BackgroundColor3 = colors.maximize -- Green when assigned
        else
            petSelectBtn.Text = "🐾 Big Pets"
            petSelectBtn.BackgroundColor3 = colors.primary
        end
    end
    
    -- Initial update
    updatePetButtonText()
    
    -- Click handler to open pet selection popup
    petSelectBtn.MouseButton1Click:Connect(function(input)
        -- Stop event propagation to prevent card selection
        if input then
            input:StopPropagation()
        end
        
        -- Create popup
        if ScreenGui then
            createPetSelectionPopup(itemId, itemData.Name, ScreenGui)
        end
        
        -- Update button text after popup closes (delayed)
        task.spawn(function()
            task.wait(0.5)
            while ScreenGui and ScreenGui:FindFirstChild("PetSelectionOverlay") do
                task.wait(0.2)
            end
            updatePetButtonText()
        end)
    end)
    
    -- Hover effect for pet select button
    petSelectBtn.MouseEnter:Connect(function()
        TweenService:Create(petSelectBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(
                math.min(255, petSelectBtn.BackgroundColor3.R * 255 * 1.2),
                math.min(255, petSelectBtn.BackgroundColor3.G * 255 * 1.2),
                math.min(255, petSelectBtn.BackgroundColor3.B * 255 * 1.2)
            )
        }):Play()
    end)
    
    petSelectBtn.MouseLeave:Connect(function()
        updatePetButtonText() -- Reset to original color
    end)
        -- Update price label with inventory count
    local function updateInventoryDisplay()
        local fruitInventory = getPlayerFruitInventory()
        local fruitAmount = fruitInventory[itemData.Name] or 0
        
        if fruitAmount > 0 then
            price.Text = fruitAmount .. "x"
            price.TextColor3 = colors.textSecondary
        else
            price.Text = "0x"
            price.TextColor3 = Color3.fromRGB(255, 69, 58) -- Red for 0 inventory
        end
    end
    
    -- Update immediately
    updateInventoryDisplay()
    
    -- Update every 2 seconds to keep inventory current
    local lastUpdate = 0
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not card.Parent then
            connection:Disconnect()
            return
        end
        
        -- Update every 2 seconds
        local currentTime = tick()
        if currentTime - lastUpdate >= 2 then
            updateInventoryDisplay()
            lastUpdate = currentTime
        end
    end)
    
    -- Clean up connection when card is destroyed
    card.AncestryChanged:Connect(function()
        if not card.Parent then
            connection:Disconnect()
        end
    end)
    
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
    
    -- Set initial selection state
    if selectedItems[itemId] then
        checkmark.Visible = true
        card.BackgroundColor3 = colors.selected
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
    
    -- Click effect
    card.MouseButton1Click:Connect(function()
        if selectedItems[itemId] then
            selectedItems[itemId] = nil
            checkmark.Visible = false
            TweenService:Create(card, TweenInfo.new(0.2), {BackgroundColor3 = colors.surface}):Play()
        else
            selectedItems[itemId] = true
            checkmark.Visible = true
            TweenService:Create(card, TweenInfo.new(0.2), {BackgroundColor3 = colors.selected}):Play()
        end
        
        -- Trigger callback with both selections and pet assignments
        if onSelectionChanged then
            onSelectionChanged(selectedItems, fruitPetAssignments)
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
    searchBox.PlaceholderText = "Search fruits..."
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
            FeedFruitSelection.RefreshContent()
        end
    end)
    
    return searchContainer
end

-- Create UI
function FeedFruitSelection.CreateUI()
    if ScreenGui then
        ScreenGui:Destroy()
    end
    
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FeedFruitSelectionUI"
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
    title.Text = "Feed Fruit Selection"
    title.TextSize = 14
    title.Font = Enum.Font.GothamSemibold
    title.TextColor3 = colors.text
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = MainFrame
    
    -- Search Bar
    local searchBar = createSearchBar(MainFrame)
    
    -- Content Area
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -32, 1, -120)
    content.Position = UDim2.new(0, 16, 0, 120)
    content.BackgroundTransparency = 1
    content.Parent = MainFrame
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = colors.primary
    -- Ensure manual canvas sizing for reliable scrolling
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 1000)
    scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    scrollFrame.Parent = content
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.33, -8, 0, 120)
    gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
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
            searchBar.Visible = true
            isMinimized = false
        else
            MainFrame.Size = minimizedSize
            content.Visible = false
            searchBar.Visible = false
            isMinimized = true
        end
    end)
    
    maximizeBtn.MouseButton1Click:Connect(function()
        if MainFrame.Size == originalSize then
            MainFrame.Size = UDim2.new(0.8, 0, 0.8, 0)
            MainFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
        else
            MainFrame.Size = originalSize
            MainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
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

-- Refresh Content
function FeedFruitSelection.RefreshContent()
    if not ScreenGui then return end
    
    local scrollFrame = ScreenGui.MainFrame.Content.ScrollFrame
    if not scrollFrame then return end
    
    -- Clear existing content
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Filter by search
    local filteredData = filterDataBySearch(FruitData, searchText)
    
    -- Sort by inventory count (high to low) instead of price
    local sortedData = {}
    for id, item in pairs(filteredData) do
        table.insert(sortedData, {id = id, data = item})
    end
    
    -- Sort by inventory count (high to low)
    local fruitInventory = getPlayerFruitInventory()
    table.sort(sortedData, function(a, b)
        local amountA = fruitInventory[a.data.Name] or 0
        local amountB = fruitInventory[b.data.Name] or 0
        return amountA > amountB -- High to low
    end)
    
    -- Add content
    for i, item in ipairs(sortedData) do
        local card = createItemCard(item.id, item.data, scrollFrame)
        card.LayoutOrder = i
        
        -- Apply saved selection state
        if selectedItems[item.id] then
            local checkmark = card:FindFirstChild("Checkmark")
            if checkmark then
                checkmark.Visible = true
            end
            card.BackgroundColor3 = colors.selected
        end
    end

    -- Update canvas size based on number of items (3 per row)
    local itemCount = #sortedData
    if itemCount > 0 then
        local rows = math.ceil(itemCount / 3)
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
function FeedFruitSelection.Show(callback, toggleCallback, savedFruits)
    onSelectionChanged = callback
    onToggleChanged = toggleCallback
    
    -- Apply saved selections if provided
    if savedFruits then
        for fruitId, _ in pairs(savedFruits) do
            selectedItems[fruitId] = true
        end
    end
    
    if not ScreenGui then
        FeedFruitSelection.CreateUI()
    end
    
    task.wait()
    FeedFruitSelection.RefreshContent()
    ScreenGui.Enabled = true
    ScreenGui.Parent = PlayerGui
end

function FeedFruitSelection.Hide()
    if ScreenGui then
        ScreenGui.Enabled = false
    end
end

function FeedFruitSelection.GetSelectedItems()
    return selectedItems
end

function FeedFruitSelection.SetSelectedItems(items)
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

function FeedFruitSelection.IsVisible()
    return ScreenGui and ScreenGui.Enabled
end

function FeedFruitSelection.GetCurrentSelections()
    return selectedItems
end

function FeedFruitSelection.UpdateSelections(fruits)
    selectedItems = {}
    
    if fruits then
        for fruitId, _ in pairs(fruits) do
            selectedItems[fruitId] = true
        end
    end
    
    if ScreenGui then
        FeedFruitSelection.RefreshContent()
    end
end

-- Get fruit-to-pet assignments
function FeedFruitSelection.GetPetAssignments()
    return fruitPetAssignments
end

-- Set fruit-to-pet assignments
function FeedFruitSelection.SetPetAssignments(assignments)
    if type(assignments) == "table" then
        fruitPetAssignments = assignments
    end
end

-- Get assignment for a specific fruit
function FeedFruitSelection.GetFruitAssignment(fruitId)
    return fruitPetAssignments[fruitId] or {}
end

-- Set assignment for a specific fruit
function FeedFruitSelection.SetFruitAssignment(fruitId, petList)
    if type(petList) == "table" then
        fruitPetAssignments[fruitId] = petList
    end
end

-- Clear all assignments
function FeedFruitSelection.ClearAllAssignments()
    fruitPetAssignments = {}
end

-- Get complete feeding data (fruits + pet assignments)
function FeedFruitSelection.GetFeedingData()
    return {
        selectedFruits = selectedItems,
        petAssignments = fruitPetAssignments
    }
end

-- Load complete feeding data
function FeedFruitSelection.LoadFeedingData(data)
    if type(data) ~= "table" then return end
    
    if data.selectedFruits then
        selectedItems = data.selectedFruits
    end
    
    if data.petAssignments then
        fruitPetAssignments = data.petAssignments
    end
    
    if ScreenGui then
        FeedFruitSelection.RefreshContent()
    end
end

return FeedFruitSelection
