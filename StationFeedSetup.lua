-- StationFeedSetup.lua - Station-First UI for Auto Feed (macOS Style)
-- Author: Zebux
-- Version: 3.0
-- Description: Redesigned UI where you select Station → Fruits instead of Fruit → Pets
-- Features: Auto-update fruit data from game, 3D model display, macOS style UI

local StationFeedSetup = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dynamic data that will be loaded from the game
local FruitData = {}

-- Cache for fruit models from ReplicatedStorage
local FruitModels = {}

-- Function to get fruit model from ReplicatedStorage
local function GetFruitModel(fruitId)
    -- Check cache first
    if FruitModels[fruitId] then
        return FruitModels[fruitId]
    end
    
    -- Try to find the model
    local success, model = pcall(function()
        -- Search in ReplicatedStorage children for PetFood folder
        for _, child in ipairs(ReplicatedStorage:GetChildren()) do
            if child:IsA("Folder") or child:IsA("Model") then
                -- Look for PetFood/FruitName pattern
                local fruitModel = child:FindFirstChild("PetFood/" .. fruitId)
                if fruitModel then
                    return fruitModel
                end
                
                -- Also try direct search
                local petFoodFolder = child:FindFirstChild("PetFood")
                if petFoodFolder then
                    fruitModel = petFoodFolder:FindFirstChild(fruitId)
                    if fruitModel then
                        return fruitModel
                    end
                end
            end
        end
        return nil
    end)
    
    if success and model then
        FruitModels[fruitId] = model
        return model
    end
    
    return nil
end

-- Function to load fruit data from the game automatically
local function LoadFruitDataFromGame()
    local success, result = pcall(function()
        local configModule = ReplicatedStorage:WaitForChild("Config", 10):WaitForChild("ResPetFood", 10)
        if configModule then
            local gameFruitData = require(configModule)
            
            -- Convert game data format to our UI format
            local convertedData = {}
            
            for fruitId, fruitInfo in pairs(gameFruitData) do
                -- Skip the __index table
                if fruitId ~= "__index" and type(fruitInfo) == "table" then
                    -- Get model from ReplicatedStorage
                    local fruitModel = GetFruitModel(fruitId)
                    
                    -- Convert to our format
                    convertedData[fruitId] = {
                        Name = fruitInfo.ID or fruitId,
                        Price = fruitInfo.Price or "0",
                        Icon = fruitInfo.Icon or "",
                        Model = fruitModel,
                        Rarity = fruitInfo.Rarity or 1,
                        FeedValue = fruitInfo.FeedValue or 0
                    }
                end
            end
            
            return convertedData
        end
    end)
    
    if success and result then
        return result
    else
        warn("[StationFeedSetup] Failed to load fruit data from game:", result)
        return {}
    end
end

-- Load fruit data on initialization
FruitData = LoadFruitDataFromGame()

-- Flag to indicate data is loaded
StationFeedSetup.DataLoaded = true

-- Helper to find BigPet station
local function findBigPetStationForPet(petPosition)
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return nil end
    
    local islandName = localPlayer:GetAttribute("AssignedIslandName")
    if not islandName then return nil end
    
    local art = workspace:FindFirstChild("Art")
    if not art then return nil end
    
    local island = art:FindFirstChild(islandName)
    if not island then return nil end
    
    local env = island:FindFirstChild("ENV")
    if not env then return nil end
    
    local bigPetFolder = env:FindFirstChild("BigPet")
    if not bigPetFolder then return nil end
    
    local closestStation = nil
    local closestDistance = math.huge
    
    for _, station in ipairs(bigPetFolder:GetChildren()) do
        if station:IsA("BasePart") then
            local distance = (station.Position - petPosition).Magnitude
            if distance < closestDistance and distance < 50 then
                closestDistance = distance
                closestStation = station.Name
            end
        end
    end
    
    return closestStation
end

-- Get player's owned Big Pets with Station IDs
local function getPlayerOwnedPets()
    local pets = {}
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return pets end
    
    local petsFolder = workspace:FindFirstChild("Pets")
    if not petsFolder then return pets end
    
    for _, petModel in ipairs(petsFolder:GetChildren()) do
        if petModel:IsA("Model") then
            local rootPart = petModel:FindFirstChild("RootPart")
            if rootPart then
                local petUserId = rootPart:GetAttribute("UserId")
                if petUserId and tostring(petUserId) == tostring(localPlayer.UserId) then
                    local bigPetGUI = rootPart:FindFirstChild("GUI/BigPetGUI")
                    if bigPetGUI then
                        local stationId = findBigPetStationForPet(rootPart.Position)
                        
                        -- Get pet type - try multiple attributes
                        local petType = rootPart:GetAttribute("T") 
                                     or rootPart:GetAttribute("Type")
                                     or rootPart:GetAttribute("PetType")
                        
                        -- If petType is still a UID-like string (long hex), don't show it
                        local displayName = "Station " .. stationId
                        if petType and #tostring(petType) <= 20 and petType ~= "" then
                            displayName = "Station " .. stationId .. " (" .. petType .. ")"
                        end
                        
                        if stationId then
                            table.insert(pets, {
                                uid = petModel.Name,
                                stationId = stationId,
                                type = petType or "Unknown",
                                displayName = displayName
                            })
                        end
                    end
                end
            end
        end
    end
    
    -- Sort by station ID
    table.sort(pets, function(a, b)
        local numA = tonumber(a.stationId)
        local numB = tonumber(b.stationId)
        if numA and numB then
            return numA < numB
        end
        return a.stationId < b.stationId
    end)
    
    return pets
end

-- Get player's fruit inventory
local function getPlayerFruitInventory()
    local inventory = {}
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return inventory end
    
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return inventory end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return inventory end
    
    local asset = data:FindFirstChild("Asset")
    if not asset then return inventory end
    
    local ok, attrs = pcall(function() return asset:GetAttributes() end)
    if ok and type(attrs) == "table" then
        for fruitId, fruitData in pairs(FruitData) do
            local amount = attrs[fruitData.Name] or attrs[fruitId] or 0
            if type(amount) == "string" then amount = tonumber(amount) or 0 end
            if amount > 0 then
                inventory[fruitId] = amount
            end
        end
    end
    
    return inventory
end

-- Format large numbers
local function formatNumber(num)
    if type(num) == "string" then num = tonumber(num) or 0 end
    if num >= 1000000000000 then return string.format("%.1fT", num / 1000000000000)
    elseif num >= 1000000000 then return string.format("%.1fB", num / 1000000000)
    elseif num >= 1000000 then return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then return string.format("%.1fK", num / 1000)
    else return tostring(num) end
end

-- UI Variables
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ScreenGui = nil
local MainFrame = nil

-- NEW DATA STRUCTURE: {StationID: {FruitID: true}}
local stationFruitAssignments = {}
local savedTemplates = {} -- For future template feature

local isDragging = false
local dragStart = nil
local startPos = nil

-- Callback
local onSaveCallback = nil
local onVisibilityCallback = nil

-- macOS Monterey Style Colors (Enhanced)
local colors = {
    background = Color3.fromRGB(18, 18, 20),
    surface = Color3.fromRGB(32, 32, 34),
    surfaceLight = Color3.fromRGB(45, 45, 47),
    primary = Color3.fromRGB(0, 122, 255),
    primaryHover = Color3.fromRGB(10, 132, 255),
    secondary = Color3.fromRGB(88, 86, 214),
    text = Color3.fromRGB(255, 255, 255),
    textSecondary = Color3.fromRGB(200, 200, 200),
    textTertiary = Color3.fromRGB(150, 150, 150),
    border = Color3.fromRGB(50, 50, 52),
    selected = Color3.fromRGB(0, 122, 255),
    hover = Color3.fromRGB(45, 45, 47),
    close = Color3.fromRGB(255, 69, 58),
    minimize = Color3.fromRGB(255, 159, 10),
    maximize = Color3.fromRGB(48, 209, 88),
    warning = Color3.fromRGB(255, 214, 10),
    success = Color3.fromRGB(48, 209, 88),
    shadow = Color3.fromRGB(0, 0, 0)
}

-- Utility function to get rarity color
local function getRarityColor(rarity)
    if rarity >= 6 then return Color3.fromRGB(255, 45, 85)
    elseif rarity >= 5 then return Color3.fromRGB(255, 69, 58)
    elseif rarity >= 4 then return Color3.fromRGB(175, 82, 222)
    elseif rarity >= 3 then return Color3.fromRGB(88, 86, 214)
    elseif rarity >= 2 then return Color3.fromRGB(48, 209, 88)
    else return Color3.fromRGB(174, 174, 178)
    end
end

-- Create Fruit Selection Popup for a specific Station
local function createFruitSelectionPopup(stationId, stationDisplayName, parentFrame, refreshCallback)
    -- Initialize station's fruit assignments if not exists
    if not stationFruitAssignments[stationId] then
        stationFruitAssignments[stationId] = {}
    end
    
    local overlay = Instance.new("Frame")
    overlay.Name = "FruitSelectionOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 200
    overlay.Parent = parentFrame
    
    local popup = Instance.new("Frame")
    popup.Name = "FruitSelectionPopup"
    popup.Size = UDim2.new(0, 400, 0, 500)
    popup.Position = UDim2.new(0.5, -200, 0.5, -250)
    popup.BackgroundColor3 = colors.background
    popup.BorderSizePixel = 0
    popup.ZIndex = 201
    popup.Parent = overlay
    
    local popupCorner = Instance.new("UICorner")
    popupCorner.CornerRadius = UDim.new(0, 12)
    popupCorner.Parent = popup
    
    local popupStroke = Instance.new("UIStroke")
    popupStroke.Color = colors.primary
    popupStroke.Thickness = 2
    popupStroke.Parent = popup
    
    -- Title (แสดงเฉพาะส่วน Station X ไม่รวม UID)
    local cleanDisplayName = stationDisplayName
    -- ถ้ามี pattern "Station X (Type)" ให้ใช้แบบนั้น, ถ้าไม่ใช่ให้ตัดส่วนที่เป็น UID ออก
    if not stationDisplayName:match("^Station %d+") then
        -- ถ้าไม่ใช่รูปแบบ Station X แปลว่ามี UID ต่อท้าย ให้ใช้แค่ส่วน type
        cleanDisplayName = stationDisplayName
    end
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -32, 0, 30)
    title.Position = UDim2.new(0, 16, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "🍎 " .. cleanDisplayName .. " → Fruits"
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = colors.text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 202
    title.Parent = popup
    
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -32, 0, 18)
    subtitle.Position = UDim2.new(0, 16, 0, 42)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Select fruits to feed this station"
    subtitle.TextSize = 11
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextColor3 = colors.textSecondary
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.ZIndex = 202
    subtitle.Parent = popup
    
    -- Scroll frame
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -32, 1, -140)
    scroll.Position = UDim2.new(0, 16, 0, 65)
    scroll.BackgroundColor3 = colors.surface
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.ScrollBarImageColor3 = colors.primary
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ZIndex = 202
    scroll.Parent = popup
    
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 8)
    scrollCorner.Parent = scroll
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.Parent = scroll
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = scroll
    
    local inventory = getPlayerFruitInventory()
    
    -- Initialize if not exists
    if not stationFruitAssignments[stationId] then
        stationFruitAssignments[stationId] = {}
    end
    
    -- Select All button
    -- "Select All" button (macOS style)
    local selectAll = Instance.new("TextButton")
    selectAll.Size = UDim2.new(1, -16, 0, 40)
    selectAll.BackgroundColor3 = colors.primary
    selectAll.BorderSizePixel = 0
    selectAll.Text = "✔️ Select All"
    selectAll.TextSize = 14
    selectAll.Font = Enum.Font.GothamMedium
    selectAll.TextColor3 = colors.text
    selectAll.ZIndex = 203
    selectAll.Parent = scroll
    
    local selectAllCorner = Instance.new("UICorner")
    selectAllCorner.CornerRadius = UDim.new(0, 8)
    selectAllCorner.Parent = selectAll
    
    selectAll.MouseEnter:Connect(function()
        TweenService:Create(selectAll, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            BackgroundColor3 = colors.primaryHover,
            Size = UDim2.new(1, -16, 0, 42)
        }):Play()
    end)
    selectAll.MouseLeave:Connect(function()
        TweenService:Create(selectAll, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            BackgroundColor3 = colors.primary,
            Size = UDim2.new(1, -16, 0, 40)
        }):Play()
    end)
    
    selectAll.MouseButton1Click:Connect(function()
        for fruitId in pairs(FruitData) do
            stationFruitAssignments[stationId][fruitId] = true
        end
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("TextButton") and child.Name:match("^Fruit_") then
                local checkCont = child:FindFirstChild("CheckContainer")
                local check = checkCont and checkCont:FindFirstChild("Checkmark")
                if check then check.Visible = true end
                if checkCont then checkCont.BackgroundColor3 = colors.success end
                child.BackgroundColor3 = colors.selected
            end
        end
    end)
    
    -- "Clear All" button (macOS style)
    local clearAll = Instance.new("TextButton")
    clearAll.Size = UDim2.new(1, -16, 0, 40)
    clearAll.BackgroundColor3 = colors.close
    clearAll.BorderSizePixel = 0
    clearAll.Text = "❌ Clear All"
    clearAll.TextSize = 14
    clearAll.Font = Enum.Font.GothamMedium
    clearAll.TextColor3 = colors.text
    clearAll.ZIndex = 203
    clearAll.Parent = scroll
    
    local clearAllCorner = Instance.new("UICorner")
    clearAllCorner.CornerRadius = UDim.new(0, 8)
    clearAllCorner.Parent = clearAll
    
    clearAll.MouseEnter:Connect(function()
        TweenService:Create(clearAll, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            BackgroundColor3 = Color3.fromRGB(255, 59, 48),
            Size = UDim2.new(1, -16, 0, 42)
        }):Play()
    end)
    clearAll.MouseLeave:Connect(function()
        TweenService:Create(clearAll, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            BackgroundColor3 = colors.close,
            Size = UDim2.new(1, -16, 0, 40)
        }):Play()
    end)
    
    clearAll.MouseButton1Click:Connect(function()
        stationFruitAssignments[stationId] = {}
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("TextButton") and child.Name:match("^Fruit_") then
                local checkCont = child:FindFirstChild("CheckContainer")
                local check = checkCont and checkCont:FindFirstChild("Checkmark")
                if check then check.Visible = false end
                if checkCont then checkCont.BackgroundColor3 = Color3.fromRGB(70, 70, 73) end
                child.BackgroundColor3 = colors.surfaceLight
            end
        end
    end)
    
    -- Create fruit items
    for fruitId, fruitData in pairs(FruitData) do
        local item = Instance.new("TextButton")
        item.Name = "Fruit_" .. fruitId
        item.Size = UDim2.new(1, -16, 0, 56)
        item.BackgroundColor3 = stationFruitAssignments[stationId][fruitId] and colors.selected or colors.surfaceLight
        item.BorderSizePixel = 0
        item.Text = ""
        item.ZIndex = 203
        item.Parent = scroll
        
        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 10)
        itemCorner.Parent = item
        
        local itemStroke = Instance.new("UIStroke")
        itemStroke.Color = stationFruitAssignments[stationId][fruitId] and colors.selected or colors.border
        itemStroke.Thickness = stationFruitAssignments[stationId][fruitId] and 2 or 1
        itemStroke.Transparency = 0.3
        itemStroke.Parent = item
        
        -- Icon Container (for 3D model or icon)
        local iconContainer = Instance.new("Frame")
        iconContainer.Name = "IconContainer"
        iconContainer.Size = UDim2.new(0, 40, 0, 40)
        iconContainer.Position = UDim2.new(0, 8, 0.5, -20)
        iconContainer.BackgroundTransparency = 1
        iconContainer.ZIndex = 204
        iconContainer.Parent = item
        
        -- Try to show model first, fallback to icon/emoji
        if fruitData.Model and fruitData.Model:IsA("Model") then
            -- Create ViewportFrame for 3D model
            local viewport = Instance.new("ViewportFrame")
            viewport.Name = "ModelViewport"
            viewport.Size = UDim2.new(1, 0, 1, 0)
            viewport.BackgroundTransparency = 1
            viewport.ZIndex = 205
            viewport.Parent = iconContainer
            
            -- Clone the model
            local modelClone = fruitData.Model:Clone()
            modelClone.Parent = viewport
            
            -- Create camera
            local camera = Instance.new("Camera")
            camera.Parent = viewport
            viewport.CurrentCamera = camera
            
            -- Position camera to show the model
            local modelCF, modelSize = modelClone:GetBoundingBox()
            local maxSize = math.max(modelSize.X, modelSize.Y, modelSize.Z)
            local distance = maxSize * 1.8
            camera.CFrame = CFrame.new(modelCF.Position + Vector3.new(distance, distance * 0.4, distance), modelCF.Position)
            
            -- Add lighting
            local light = Instance.new("PointLight")
            light.Brightness = 2
            light.Range = 30
            light.Parent = camera
        elseif fruitData.Icon and fruitData.Icon ~= "" then
            -- Use ImageLabel for rbxassetid icons
            if string.find(fruitData.Icon, "rbxassetid://") then
                local imageLabel = Instance.new("ImageLabel")
                imageLabel.Name = "IconImage"
                imageLabel.Size = UDim2.new(1, 0, 1, 0)
                imageLabel.BackgroundTransparency = 1
                imageLabel.Image = fruitData.Icon
                imageLabel.ScaleType = Enum.ScaleType.Fit
                imageLabel.ZIndex = 205
                imageLabel.Parent = iconContainer
            else
                -- Fallback to text (emoji)
                local textLabel = Instance.new("TextLabel")
                textLabel.Name = "IconText"
                textLabel.Size = UDim2.new(1, 0, 1, 0)
                textLabel.BackgroundTransparency = 1
                textLabel.Text = fruitData.Icon
                textLabel.TextSize = 28
                textLabel.Font = Enum.Font.GothamBold
                textLabel.TextColor3 = getRarityColor(fruitData.Rarity)
                textLabel.ZIndex = 205
                textLabel.Parent = iconContainer
            end
        else
            -- Default emoji if nothing available
            local textLabel = Instance.new("TextLabel")
            textLabel.Name = "IconText"
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.BackgroundTransparency = 1
            textLabel.Text = "🍎"
            textLabel.TextSize = 28
            textLabel.Font = Enum.Font.GothamBold
            textLabel.TextColor3 = getRarityColor(fruitData.Rarity)
            textLabel.ZIndex = 205
            textLabel.Parent = iconContainer
        end
        
        -- Name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -120, 0, 20)
        nameLabel.Position = UDim2.new(0, 52, 0, 8)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = fruitData.Name
        nameLabel.TextSize = 14
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextColor3 = colors.text
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.ZIndex = 204
        nameLabel.Parent = item
        
        -- Amount
        local amount = inventory[fruitId] or 0
        local amountLabel = Instance.new("TextLabel")
        amountLabel.Size = UDim2.new(1, -120, 0, 16)
        amountLabel.Position = UDim2.new(0, 52, 0, 28)
        amountLabel.BackgroundTransparency = 1
        amountLabel.Text = "Have: " .. formatNumber(amount)
        amountLabel.TextSize = 11
        amountLabel.Font = Enum.Font.Gotham
        amountLabel.TextColor3 = amount > 0 and colors.textSecondary or colors.close
        amountLabel.TextXAlignment = Enum.TextXAlignment.Left
        amountLabel.ZIndex = 204
        amountLabel.Parent = item
        
        -- Checkmark (macOS style circle with check)
        local checkContainer = Instance.new("Frame")
        checkContainer.Name = "CheckContainer"
        checkContainer.Size = UDim2.new(0, 28, 0, 28)
        checkContainer.Position = UDim2.new(1, -38, 0.5, -14)
        checkContainer.BackgroundColor3 = stationFruitAssignments[stationId][fruitId] and colors.success or Color3.fromRGB(70, 70, 73)
        checkContainer.BorderSizePixel = 0
        checkContainer.ZIndex = 204
        checkContainer.Parent = item
        
        local checkCorner = Instance.new("UICorner")
        checkCorner.CornerRadius = UDim.new(1, 0)
        checkCorner.Parent = checkContainer
        
        local check = Instance.new("TextLabel")
        check.Name = "Checkmark"
        check.Size = UDim2.new(1, 0, 1, 0)
        check.BackgroundTransparency = 1
        check.Text = "✔️"
        check.TextSize = 16
        check.Font = Enum.Font.GothamBold
        check.TextColor3 = colors.text
        check.Visible = stationFruitAssignments[stationId][fruitId] == true
        check.ZIndex = 205
        check.Parent = checkContainer
        
        -- Click handler (macOS style animation)
        item.MouseButton1Click:Connect(function()
            if stationFruitAssignments[stationId][fruitId] then
                stationFruitAssignments[stationId][fruitId] = nil
                check.Visible = false
                TweenService:Create(item, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {
                    BackgroundColor3 = colors.surfaceLight
                }):Play()
                TweenService:Create(itemStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {
                    Color = colors.border,
                    Thickness = 1
                }):Play()
                TweenService:Create(checkContainer, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
                    BackgroundColor3 = Color3.fromRGB(70, 70, 73),
                    Size = UDim2.new(0, 24, 0, 24)
                }):Play()
            else
                stationFruitAssignments[stationId][fruitId] = true
                check.Visible = true
                TweenService:Create(item, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {
                    BackgroundColor3 = colors.selected
                }):Play()
                TweenService:Create(itemStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {
                    Color = colors.selected,
                    Thickness = 2
                }):Play()
                TweenService:Create(checkContainer, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
                    BackgroundColor3 = colors.success,
                    Size = UDim2.new(0, 28, 0, 28)
                }):Play()
            end
        end)
        
        -- Hover (macOS style)
        item.MouseEnter:Connect(function()
            if not stationFruitAssignments[stationId][fruitId] then
                TweenService:Create(item, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
                    BackgroundColor3 = colors.hover,
                    Size = UDim2.new(1, -16, 0, 58)
                }):Play()
            else
                TweenService:Create(item, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
                    Size = UDim2.new(1, -16, 0, 58)
                }):Play()
            end
        end)
        item.MouseLeave:Connect(function()
            TweenService:Create(item, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
                BackgroundColor3 = stationFruitAssignments[stationId][fruitId] and colors.selected or colors.surfaceLight,
                Size = UDim2.new(1, -16, 0, 56)
            }):Play()
        end)
    end
    
    -- Bottom buttons
    local btnsContainer = Instance.new("Frame")
    btnsContainer.Size = UDim2.new(1, -32, 0, 60)
    btnsContainer.Position = UDim2.new(0, 16, 1, -76)
    btnsContainer.BackgroundTransparency = 1
    btnsContainer.ZIndex = 202
    btnsContainer.Parent = popup
    
    local btnsLayout = Instance.new("UIListLayout")
    btnsLayout.FillDirection = Enum.FillDirection.Horizontal
    btnsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    btnsLayout.Padding = UDim.new(0, 8)
    btnsLayout.Parent = btnsContainer
    
    -- Close button (macOS style)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 100, 0, 44)
    closeBtn.BackgroundColor3 = colors.surfaceLight
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "Close"
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamMedium
    closeBtn.TextColor3 = colors.text
    closeBtn.ZIndex = 203
    closeBtn.Parent = btnsContainer
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 10)
    closeBtnCorner.Parent = closeBtn
    
    -- Save button (macOS style)
    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0, 120, 0, 44)
    saveBtn.BackgroundColor3 = colors.primary
    saveBtn.BorderSizePixel = 0
    saveBtn.Text = "✔️ Save"
    saveBtn.TextSize = 14
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextColor3 = colors.text
    saveBtn.ZIndex = 203
    saveBtn.Parent = btnsContainer
    
    local saveBtnCorner = Instance.new("UICorner")
    saveBtnCorner.CornerRadius = UDim.new(0, 10)
    saveBtnCorner.Parent = saveBtn
    
    -- Button hover effects
    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            BackgroundColor3 = colors.hover
        }):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            BackgroundColor3 = colors.surfaceLight
        }):Play()
    end)
    
    saveBtn.MouseEnter:Connect(function()
        TweenService:Create(saveBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            BackgroundColor3 = colors.primaryHover
        }):Play()
    end)
    saveBtn.MouseLeave:Connect(function()
        TweenService:Create(saveBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            BackgroundColor3 = colors.primary
        }):Play()
    end)
    
    local function close()
        overlay:Destroy()
        if refreshCallback then refreshCallback() end
    end
    
    closeBtn.MouseButton1Click:Connect(close)
    saveBtn.MouseButton1Click:Connect(function()
        -- Trigger save callback when user clicks Save in popup
        if onSaveCallback then
            onSaveCallback(stationFruitAssignments)
        end
        close()
    end)
    
    -- Click outside to close
    overlay.MouseButton1Click:Connect(function(input)
        local pos = input.Position
        if pos.Y < popup.AbsolutePosition.Y or pos.Y > popup.AbsolutePosition.Y + popup.AbsoluteSize.Y or
           pos.X < popup.AbsolutePosition.X or pos.X > popup.AbsolutePosition.X + popup.AbsoluteSize.X then
            close()
        end
    end)
end

-- Create main UI
local function createMainUI()
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "StationFeedSetupUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = PlayerGui
    
    MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 450, 0, 500)
    MainFrame.Position = UDim2.new(0.5, -225, 0.5, -250)
    MainFrame.BackgroundColor3 = colors.background
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = MainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.primary
    stroke.Thickness = 2
    stroke.Parent = MainFrame
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = colors.surface
    titleBar.BorderSizePixel = 0
    titleBar.Parent = MainFrame
    
    local titleBarCorner = Instance.new("UICorner")
    titleBarCorner.CornerRadius = UDim.new(0, 12)
    titleBarCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -100, 1, 0)
    titleLabel.Position = UDim2.new(0, 16, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🍎 Station Feed Setup"
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextColor3 = colors.text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 40, 0, 40)
    closeButton.Position = UDim2.new(1, -45, 0, 5)
    closeButton.BackgroundColor3 = colors.close
    closeButton.BorderSizePixel = 0
    closeButton.Text = "❌"
    closeButton.TextSize = 18
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(1, 0)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        StationFeedSetup.Hide()
    end)
    
    -- Draggable
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)
    
    -- Stations scroll
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -32, 1, -170)
    scroll.Position = UDim2.new(0, 16, 0, 66)
    scroll.BackgroundColor3 = colors.surface
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.ScrollBarImageColor3 = colors.primary
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = MainFrame
    
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 8)
    scrollCorner.Parent = scroll
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = scroll
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = scroll
    
    -- Refresh station list
    local function refreshStations()
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end
        
        local pets = getPlayerOwnedPets()
        
        if #pets == 0 then
            local noStations = Instance.new("TextLabel")
            noStations.Size = UDim2.new(1, -24, 0, 100)
            noStations.BackgroundTransparency = 1
            noStations.Text = "No Big Pets Found\nPlease place Big Pets first"
            noStations.TextSize = 14
            noStations.Font = Enum.Font.Gotham
            noStations.TextColor3 = colors.textSecondary
            noStations.Parent = scroll
            return
        end
        
        for _, petInfo in ipairs(pets) do
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, 0, 0, 70)
            card.BackgroundColor3 = colors.background
            card.BorderSizePixel = 0
            card.Parent = scroll
            
            local cardCorner = Instance.new("UICorner")
            cardCorner.CornerRadius = UDim.new(0, 8)
            cardCorner.Parent = card
            
            local cardStroke = Instance.new("UIStroke")
            cardStroke.Color = colors.border
            cardStroke.Thickness = 1
            cardStroke.Parent = card
            
            local stationLabel = Instance.new("TextLabel")
            stationLabel.Size = UDim2.new(1, -100, 0, 20)
            stationLabel.Position = UDim2.new(0, 10, 0, 10)
            stationLabel.BackgroundTransparency = 1
            stationLabel.Text = petInfo.displayName
            stationLabel.TextSize = 13
            stationLabel.Font = Enum.Font.GothamBold
            stationLabel.TextColor3 = colors.text
            stationLabel.TextXAlignment = Enum.TextXAlignment.Left
            stationLabel.Parent = card
            
            local fruitCount = 0
            if stationFruitAssignments[petInfo.stationId] then
                for _ in pairs(stationFruitAssignments[petInfo.stationId]) do
                    fruitCount = fruitCount + 1
                end
            end
            
            local countLabel = Instance.new("TextLabel")
            countLabel.Size = UDim2.new(1, -100, 0, 16)
            countLabel.Position = UDim2.new(0, 10, 0, 32)
            countLabel.BackgroundTransparency = 1
            countLabel.Text = string.format("🍎 %d fruits", fruitCount)
            countLabel.TextSize = 10
            countLabel.Font = Enum.Font.Gotham
            countLabel.TextColor3 = fruitCount > 0 and colors.maximize or colors.textSecondary
            countLabel.TextXAlignment = Enum.TextXAlignment.Left
            countLabel.Parent = card
            
            local selectBtn = Instance.new("TextButton")
            selectBtn.Size = UDim2.new(0, 85, 0, 28)
            selectBtn.Position = UDim2.new(1, -92, 0.5, -14)
            selectBtn.BackgroundColor3 = colors.primary
            selectBtn.BorderSizePixel = 0
            selectBtn.Text = "Select"
            selectBtn.TextSize = 11
            selectBtn.Font = Enum.Font.GothamBold
            selectBtn.TextColor3 = colors.text
            selectBtn.Parent = card
            
            local selectBtnCorner = Instance.new("UICorner")
            selectBtnCorner.CornerRadius = UDim.new(0, 6)
            selectBtnCorner.Parent = selectBtn
            
            selectBtn.MouseButton1Click:Connect(function()
                createFruitSelectionPopup(petInfo.stationId, petInfo.displayName, ScreenGui, refreshStations)
            end)
            
            selectBtn.MouseEnter:Connect(function()
                TweenService:Create(selectBtn, TweenInfo.new(0.2), {BackgroundColor3 = colors.selected}):Play()
            end)
            selectBtn.MouseLeave:Connect(function()
                TweenService:Create(selectBtn, TweenInfo.new(0.2), {BackgroundColor3 = colors.primary}):Play()
            end)
        end
    end
    
    refreshStations()
    
    -- Bottom buttons
    local actions = Instance.new("Frame")
    actions.Size = UDim2.new(1, -32, 0, 80)
    actions.Position = UDim2.new(0, 16, 1, -96)
    actions.BackgroundTransparency = 1
    actions.Parent = MainFrame
    
    local actionsLayout = Instance.new("UIListLayout")
    actionsLayout.FillDirection = Enum.FillDirection.Horizontal
    actionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    actionsLayout.Padding = UDim.new(0, 8)
    actionsLayout.Parent = actions
    
    -- Refresh
    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(0, 120, 0, 36)
    refreshBtn.BackgroundColor3 = colors.secondary
    refreshBtn.BorderSizePixel = 0
    refreshBtn.Text = "🔄 Refresh"
    refreshBtn.TextSize = 12
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextColor3 = colors.text
    refreshBtn.Parent = actions
    
    local refreshCorner = Instance.new("UICorner")
    refreshCorner.CornerRadius = UDim.new(0, 8)
    refreshCorner.Parent = refreshBtn
    
    refreshBtn.MouseButton1Click:Connect(refreshStations)
    
    -- Copy to all
    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(0, 140, 0, 36)
    copyBtn.BackgroundColor3 = colors.warning
    copyBtn.BorderSizePixel = 0
    copyBtn.Text = "📋 Copy to All"
    copyBtn.TextSize = 12
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.TextColor3 = Color3.new(0, 0, 0)
    copyBtn.Parent = actions
    
    local copyCorner = Instance.new("UICorner")
    copyCorner.CornerRadius = UDim.new(0, 8)
    copyCorner.Parent = copyBtn
    
    copyBtn.MouseButton1Click:Connect(function()
        local pets = getPlayerOwnedPets()
        if #pets == 0 then return end
        
        local firstId = pets[1].stationId
        local template = stationFruitAssignments[firstId]
        
        if not template or not next(template) then
            warn("No fruits assigned to first station")
            return
        end
        
        for _, petInfo in ipairs(pets) do
            stationFruitAssignments[petInfo.stationId] = {}
            for fruitId, _ in pairs(template) do
                stationFruitAssignments[petInfo.stationId][fruitId] = true
            end
        end
        
        refreshStations()
    end)
    
    -- Save & Close
    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0, 150, 0, 36)
    saveBtn.BackgroundColor3 = colors.maximize
    saveBtn.BorderSizePixel = 0
    saveBtn.Text = "✓ Save & Close"
    saveBtn.TextSize = 12
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextColor3 = colors.text
    saveBtn.Parent = actions
    
    local saveCorner = Instance.new("UICorner")
    saveCorner.CornerRadius = UDim.new(0, 8)
    saveCorner.Parent = saveBtn
    
    saveBtn.MouseButton1Click:Connect(function()
        if onSaveCallback then
            onSaveCallback(stationFruitAssignments)
        end
        StationFeedSetup.Hide()
    end)
end

-- Public API
function StationFeedSetup.Show(saveCallback, visibilityCallback, initialData)
    onSaveCallback = saveCallback
    onVisibilityCallback = visibilityCallback
    
    if initialData then
        stationFruitAssignments = initialData
    end
    
    if not ScreenGui then
        createMainUI()
    end
    
    if ScreenGui then
        ScreenGui.Enabled = true
        if onVisibilityCallback then
            onVisibilityCallback(true)
        end
    end
end

function StationFeedSetup.Hide()
    if ScreenGui then
        ScreenGui.Enabled = false
        if onVisibilityCallback then
            onVisibilityCallback(false)
        end
    end
end

function StationFeedSetup.GetAssignments()
    return stationFruitAssignments
end

function StationFeedSetup.SetAssignments(data)
    stationFruitAssignments = data or {}
end

function StationFeedSetup.ClearAll()
    stationFruitAssignments = {}
end

-- Function to reload fruit data from the game (useful when game updates)
function StationFeedSetup.ReloadFruitData()
    local newFruitData = LoadFruitDataFromGame()
    
    if newFruitData and next(newFruitData) then
        -- Preserve existing station assignments
        local oldAssignments = {}
        for stationId, fruits in pairs(stationFruitAssignments) do
            oldAssignments[stationId] = {}
            for fruitId, _ in pairs(fruits) do
                oldAssignments[stationId][fruitId] = true
            end
        end
        
        -- Update fruit data
        FruitData = newFruitData
        
        -- Re-apply assignments that still exist in new data
        stationFruitAssignments = {}
        for stationId, fruits in pairs(oldAssignments) do
            stationFruitAssignments[stationId] = {}
            for fruitId, _ in pairs(fruits) do
                if FruitData[fruitId] then
                    stationFruitAssignments[stationId][fruitId] = true
                end
            end
        end
        
        return true
    end
    
    return false
end

-- Function to get current fruit data (for debugging)
function StationFeedSetup.GetFruitData()
    return FruitData
end

-- Function to check if data is loaded
function StationFeedSetup.IsDataLoaded()
    return StationFeedSetup.DataLoaded and next(FruitData) ~= nil
end

-- Function to wait for data to be loaded
function StationFeedSetup.WaitForDataLoad(timeout)
    local maxWait = timeout or 10
    local waited = 0
    
    while waited < maxWait do
        if StationFeedSetup.IsDataLoaded() then
            return true
        end
        task.wait(0.1)
        waited = waited + 0.1
    end
    
    warn("[StationFeedSetup] ⚠️ Data load timeout after " .. maxWait .. " seconds")
    return false
end

return StationFeedSetup

