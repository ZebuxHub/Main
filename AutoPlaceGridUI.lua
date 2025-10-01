-- AutoPlaceGridUI.lua - macOS-style Grid UI for Auto Place System
-- Author: Zebux
-- Version: 1.0

local AutoPlaceGridUI = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Vector library (required for placement)
local vector = {}
vector.create = function(x, y, z)
    return Vector3.new(x, y, z)
end

-- Local Player
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- UI Variables
local ScreenGui = nil
local MainFrame = nil
local GridContainer = nil
local isDragging = false
local dragStart = nil
local startPos = nil
local isMinimized = false

-- State Variables
local currentTileType = "Regular" -- "Regular" or "Water"
local selectedTileForInfo = nil
local selectedTilesForPlacement = {} -- Store MULTIPLE selected tiles for placement queue
local autoPlaceEnabled = false
local gridUpdateConnection = nil
local currentPlacementIndex = 1 -- Track which tile in the queue to place next

-- Auto Place Settings
local placeEggsEnabled = true
local placePetsEnabled = false
local selectedEggTypes = {}
local selectedMutations = {}
local minPetSpeed = 0
local petSortAscending = true
local placementSpeed = 3.0 -- Delay between placements (in seconds, adjustable 1-10s)

-- Grid State
local gridTiles = {} -- {position: {tile: Part, occupied: bool, type: "regular"/"water", data: {}}}
local tileButtons = {} -- UI buttons for each tile

-- External Dependencies
local AutoPlaceSystem = nil
local WindUI = nil

-- Remote Cache
local CharacterRE = nil

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
    hover = Color3.fromRGB(45, 45, 47),
    close = Color3.fromRGB(255, 69, 58),
    minimize = Color3.fromRGB(255, 159, 10),
    success = Color3.fromRGB(48, 209, 88),
    warning = Color3.fromRGB(255, 159, 10),
    error = Color3.fromRGB(255, 69, 58),
    -- Tile colors
    emptyRegular = Color3.fromRGB(80, 80, 82),
    emptyWater = Color3.fromRGB(52, 120, 246),
    occupied = Color3.fromRGB(255, 69, 58),
    locked = Color3.fromRGB(40, 40, 42)
}

-- Ocean Detection
local OCEAN_EGGS = {
    ["SeaweedEgg"] = true,
    ["ClownfishEgg"] = true,
    ["LionfishEgg"] = true,
    ["SharkEgg"] = true,
    ["AnglerfishEgg"] = true,
    ["OctopusEgg"] = true,
    ["SeaDragonEgg"] = true
}

local function isOceanEgg(eggType)
    return OCEAN_EGGS[eggType] == true
end

local function isOceanPet(petType)
    -- Check ReplicatedStorage config for pet category
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local cfg = ReplicatedStorage:FindFirstChild("Config")
    if cfg then
        local resPet = cfg:FindFirstChild("ResPet")
        if resPet then
            local ok, petData = pcall(function() return require(resPet) end)
            if ok and type(petData) == "table" and petData[petType] then
                local base = petData[petType]
                local category = base.Category
                if typeof(category) == "string" then
                    local c = string.lower(category)
                    if c == "ocean" or string.find(c, "ocean") then
                        return true
                    end
                end
                local limitedTag = base.LimitedTag
                if typeof(limitedTag) == "string" and string.lower(limitedTag) == "ocean" then
                    return true
                end
            end
        end
    end
    return false
end

-- Utility Functions
local function formatNumber(num)
    if type(num) == "string" then return num end
    if num >= 1e12 then return string.format("%.1fT", num / 1e12)
    elseif num >= 1e9 then return string.format("%.1fB", num / 1e9)
    elseif num >= 1e6 then return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then return string.format("%.1fK", num / 1e3)
    else return tostring(num) end
end

local function parseSpeedInput(text)
    if not text or type(text) ~= "string" then return 0 end
    local cleanText = text:gsub("[$€£¥₹/s,]", ""):gsub("^%s*(.-)%s*$", "%1")
    local number, suffix = cleanText:match("^([%d%.]+)([KkMmBbTt]?)$")
    if not number then number = cleanText:match("([%d%.]+)") end
    local numValue = tonumber(number)
    if not numValue then return 0 end
    if suffix then
        local lowerSuffix = string.lower(suffix)
        if lowerSuffix == "k" then numValue = numValue * 1000
        elseif lowerSuffix == "m" then numValue = numValue * 1000000
        elseif lowerSuffix == "b" then numValue = numValue * 1000000000
        elseif lowerSuffix == "t" then numValue = numValue * 1000000000000
        end
    end
    return numValue
end

-- Island Helper Functions
local function getAssignedIslandName()
    if not LocalPlayer then return nil end
    return LocalPlayer:GetAttribute("AssignedIslandName")
end

local function getIslandNumberFromName(islandName)
    if not islandName then return nil end
    local match = string.match(islandName, "Island_(%d+)")
    if match then return tonumber(match) end
    match = string.match(islandName, "(%d+)")
    if match then return tonumber(match) end
    return nil
end

-- Tile Detection Functions
local function getFarmTiles(islandNumber, isWater)
    if not islandNumber then return {} end
    local art = workspace:FindFirstChild("Art")
    if not art then return {} end
    
    local islandName = "Island_" .. tostring(islandNumber)
    local island = art:FindFirstChild(islandName)
    if not island then return {} end
    
    local farmTiles = {}
    local pattern = isWater and "WaterFarm_split_0_0_0" or "^Farm_split_%d+_%d+_%d+$"
    
    local function scanForTiles(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("BasePart") then
                local matches = false
                if isWater then
                    matches = child.Name == pattern
                else
                    matches = child.Name:match(pattern) ~= nil
                end
                
                if matches and child.Size == Vector3.new(8, 8, 8) then
                    -- Check for Grid attributes
                    local gridX = child:GetAttribute("GridX")
                    local gridY = child:GetAttribute("GridY")
                    local gridZ = child:GetAttribute("GridZ")
                    
                    if gridX and gridZ then
                        table.insert(farmTiles, {
                            part = child,
                            gridX = gridX,
                            gridY = gridY or 0,
                            gridZ = gridZ,
                            isWater = isWater
                        })
                    end
                end
            end
            scanForTiles(child)
        end
    end
    
    scanForTiles(island)
    
    -- Check for locked tiles
    local env = island:FindFirstChild("ENV")
    local locksFolder = env and env:FindFirstChild("Locks")
    
    if locksFolder then
        for _, tileData in ipairs(farmTiles) do
            tileData.locked = false
            for _, lockModel in ipairs(locksFolder:GetChildren()) do
                if lockModel:IsA("Model") then
                    local farmPart = lockModel:FindFirstChild("Farm")
                    if farmPart and farmPart:IsA("BasePart") and farmPart.Transparency == 0 then
                        local distance = (farmPart.Position - tileData.part.Position).Magnitude
                        if distance < 5 then
                            tileData.locked = true
                            break
                        end
                    end
                end
            end
        end
    end
    
    return farmTiles
end

local function isTileOccupied(farmPart)
    local center = farmPart.Position
    local surfacePosition = Vector3.new(
        math.floor(center.X / 8) * 8 + 4,
        center.Y + 12,
        math.floor(center.Z / 8) * 8 + 4
    )
    
    -- Check PlayerBuiltBlocks
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    if playerBuiltBlocks then
        for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
            if model:IsA("Model") then
                local modelPos = model:GetPivot().Position
                local xzDistance = math.sqrt((modelPos.X - surfacePosition.X)^2 + (modelPos.Z - surfacePosition.Z)^2)
                if xzDistance < 4.0 then
                    return true, model
                end
            end
        end
    end
    
    -- Check workspace.Pets
    local workspacePets = workspace:FindFirstChild("Pets")
    if workspacePets then
        for _, pet in ipairs(workspacePets:GetChildren()) do
            if pet:IsA("Model") then
                local petPos = pet:GetPivot().Position
                local xzDistance = math.sqrt((petPos.X - surfacePosition.X)^2 + (petPos.Z - surfacePosition.Z)^2)
                if xzDistance < 4.0 then
                    return true, pet
                end
            end
        end
    end
    
    return false, nil
end

-- Get detailed info about what's on a tile
local function getTileOccupantInfo(occupant)
    if not occupant or not occupant:IsA("Model") then return nil end
    
    local uid = occupant.Name
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local data = pg and pg:FindFirstChild("Data")
    
    -- Check if it's a pet
    local petsContainer = data and data:FindFirstChild("Pets")
    if petsContainer then
        local petNode = petsContainer:FindFirstChild(uid)
        if petNode then
            local petType = petNode:GetAttribute("T") or "Unknown"
            local mutation = petNode:GetAttribute("M")
            local level = petNode:GetAttribute("V") or 0
            
            -- Get speed from UI
            local speed = 0
            local ss = pg and pg:FindFirstChild("ScreenStorage")
            local frame = ss and ss:FindFirstChild("Frame")
            local content = frame and frame:FindFirstChild("ContentPet")
            local scroll = content and content:FindFirstChild("ScrollingFrame")
            local item = scroll and scroll:FindFirstChild(uid)
            local btn = item and item:FindFirstChild("BTN")
            local stat = btn and btn:FindFirstChild("Stat")
            local price = stat and stat:FindFirstChild("Price")
            local valueLabel = price and price:FindFirstChild("Value")
            if valueLabel and valueLabel:IsA("TextLabel") then
                speed = tonumber((valueLabel.Text:gsub("[^%d]", ""))) or 0
            end
            
            return {
                uid = uid,
                type = "Pet",
                name = petType,
                speed = speed,
                mutation = mutation,
                level = level,
                model = occupant
            }
        end
    end
    
    -- Check if it's an egg
    local eggsContainer = data and data:FindFirstChild("Egg")
    if eggsContainer then
        local eggNode = eggsContainer:FindFirstChild(uid)
        if eggNode then
            local eggType = eggNode:GetAttribute("T") or "Unknown"
            local mutation = eggNode:GetAttribute("M")
            
            return {
                uid = uid,
                type = "Egg",
                name = eggType,
                mutation = mutation,
                model = occupant
            }
        end
    end
    
    return {
        uid = uid,
        type = "Unknown",
        name = uid,
        model = occupant
    }
end

-- Inventory Functions
local function getAvailableEggs()
    local eggs = {}
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local data = pg and pg:FindFirstChild("Data")
    local eggsContainer = data and data:FindFirstChild("Egg")
    
    if eggsContainer then
        for _, eggNode in ipairs(eggsContainer:GetChildren()) do
            if #eggNode:GetChildren() == 0 then -- Available egg
                local eggType = eggNode:GetAttribute("T")
                local mutation = eggNode:GetAttribute("M")
                if eggType then
                    table.insert(eggs, {
                        uid = eggNode.Name,
                        type = eggType,
                        mutation = mutation,
                        category = "Egg",
                        isOcean = isOceanEgg(eggType)
                    })
                end
            end
        end
    end
    
    return eggs
end

local function getAvailablePets()
    local pets = {}
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local data = pg and pg:FindFirstChild("Data")
    local petsContainer = data and data:FindFirstChild("Pets")
    
    if petsContainer then
        for _, petNode in ipairs(petsContainer:GetChildren()) do
            local isPlaced = petNode:GetAttribute("D") ~= nil
            if not isPlaced then
                local petType = petNode:GetAttribute("T")
                local mutation = petNode:GetAttribute("M")
                local level = petNode:GetAttribute("V") or 0
                
                -- Get speed
                local speed = 0
                local uid = petNode.Name
                local ss = pg and pg:FindFirstChild("ScreenStorage")
                local frame = ss and ss:FindFirstChild("Frame")
                local content = frame and frame:FindFirstChild("ContentPet")
                local scroll = content and content:FindFirstChild("ScrollingFrame")
                local item = scroll and scroll:FindFirstChild(uid)
                local btn = item and item:FindFirstChild("BTN")
                local stat = btn and btn:FindFirstChild("Stat")
                local price = stat and stat:FindFirstChild("Price")
                local valueLabel = price and price:FindFirstChild("Value")
                if valueLabel and valueLabel:IsA("TextLabel") then
                    speed = tonumber((valueLabel.Text:gsub("[^%d]", ""))) or 0
                end
                
                if petType and speed >= minPetSpeed then
                    table.insert(pets, {
                        uid = uid,
                        type = petType,
                        mutation = mutation,
                        level = level,
                        speed = speed,
                        category = "Pet",
                        isOcean = isOceanPet(petType)
                    })
                end
            end
        end
    end
    
    -- Sort pets by speed
    table.sort(pets, function(a, b)
        if petSortAscending then
            return a.speed < b.speed
        else
            return a.speed > b.speed
        end
    end)
    
    return pets
end

-- Forward declarations
local refreshGrid
local updateSidebar
local showTileInfo
local placeItemOnTile
local highlightNextTile

-- Create UI Components
local function createWindowControls(parent)
    local controlsContainer = Instance.new("Frame")
    controlsContainer.Name = "WindowControls"
    controlsContainer.Size = UDim2.new(0, 70, 0, 12)
    controlsContainer.Position = UDim2.new(0, 12, 0, 12)
    controlsContainer.BackgroundTransparency = 1
    controlsContainer.Parent = parent
    
    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 12, 0, 12)
    closeBtn.Position = UDim2.new(0, 0, 0, 0)
    closeBtn.BackgroundColor3 = colors.close
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "×"
    closeBtn.TextSize = 12
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextColor3 = Color3.fromRGB(50, 50, 50)
    closeBtn.Parent = controlsContainer
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0.5, 0)
    closeCorner.Parent = closeBtn
    
    -- Minimize Button
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
    
    return controlsContainer
end

local function createSidebar(parent)
    local sidebar = Instance.new("ScrollingFrame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 280, 1, -80)
    sidebar.Position = UDim2.new(0, 16, 0, 80)
    sidebar.BackgroundColor3 = colors.surface
    sidebar.BorderSizePixel = 0
    sidebar.ScrollBarThickness = 4
    sidebar.ScrollBarImageColor3 = colors.primary
    sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sidebar.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = sidebar
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = sidebar
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 10)
    listLayout.Parent = sidebar
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = sidebar
    
    return sidebar
end

local function createGridView(parent)
    local gridFrame = Instance.new("Frame")
    gridFrame.Name = "GridFrame"
    gridFrame.Size = UDim2.new(1, -312, 1, -80)
    gridFrame.Position = UDim2.new(0, 304, 0, 80)
    gridFrame.BackgroundColor3 = colors.surface
    gridFrame.BorderSizePixel = 0
    gridFrame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = gridFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 1
    stroke.Parent = gridFrame
    
    -- Tab buttons
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(1, -20, 0, 40)
    tabContainer.Position = UDim2.new(0, 10, 0, 10)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = gridFrame
    
    local regularTab = Instance.new("TextButton")
    regularTab.Name = "RegularTab"
    regularTab.Size = UDim2.new(0.5, -2, 1, 0)
    regularTab.Position = UDim2.new(0, 0, 0, 0)
    regularTab.BackgroundColor3 = colors.primary
    regularTab.BorderSizePixel = 0
    regularTab.Text = "Regular Tiles"
    regularTab.TextSize = 14
    regularTab.Font = Enum.Font.GothamSemibold
    regularTab.TextColor3 = colors.text
    regularTab.Parent = tabContainer
    
    local regularCorner = Instance.new("UICorner")
    regularCorner.CornerRadius = UDim.new(0, 6)
    regularCorner.Parent = regularTab
    
    local waterTab = Instance.new("TextButton")
    waterTab.Name = "WaterTab"
    waterTab.Size = UDim2.new(0.5, -2, 1, 0)
    waterTab.Position = UDim2.new(0.5, 2, 0, 0)
    waterTab.BackgroundColor3 = colors.hover
    waterTab.BorderSizePixel = 0
    waterTab.Text = "Water Tiles"
    waterTab.TextSize = 14
    waterTab.Font = Enum.Font.GothamSemibold
    waterTab.TextColor3 = colors.text
    waterTab.Parent = tabContainer
    
    local waterCorner = Instance.new("UICorner")
    waterCorner.CornerRadius = UDim.new(0, 6)
    waterCorner.Parent = waterTab
    
    -- Grid scroll container
    local gridScroll = Instance.new("ScrollingFrame")
    gridScroll.Name = "GridScroll"
    gridScroll.Size = UDim2.new(1, -20, 1, -70)
    gridScroll.Position = UDim2.new(0, 10, 0, 60)
    gridScroll.BackgroundColor3 = colors.background
    gridScroll.BorderSizePixel = 0
    gridScroll.ScrollBarThickness = 6
    gridScroll.ScrollBarImageColor3 = colors.primary
    gridScroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
    gridScroll.Parent = gridFrame
    
    local gridScrollCorner = Instance.new("UICorner")
    gridScrollCorner.CornerRadius = UDim.new(0, 6)
    gridScrollCorner.Parent = gridScroll
    
    -- Center container to hold the grid
    local centerContainer = Instance.new("Frame")
    centerContainer.Name = "CenterContainer"
    centerContainer.Size = UDim2.new(1, 0, 1, 0)
    centerContainer.BackgroundTransparency = 1
    centerContainer.Parent = gridScroll
    
    local centerLayout = Instance.new("UIListLayout")
    centerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    centerLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    centerLayout.Padding = UDim.new(0, 20)
    centerLayout.Parent = centerContainer
    
    -- Grid container (will hold tile buttons)
    local gridContainer = Instance.new("Frame")
    gridContainer.Name = "GridContainer"
    gridContainer.Size = UDim2.new(1, 0, 1, 0)
    gridContainer.BackgroundTransparency = 1
    gridContainer.Parent = centerContainer
    
    return gridFrame, regularTab, waterTab, gridContainer
end

-- Create sidebar content
local function populateSidebar(sidebar)
    -- Auto Place Toggle with visual indicator
    local autoPlaceFrame = Instance.new("Frame")
    autoPlaceFrame.Name = "AutoPlaceFrame"
    autoPlaceFrame.Size = UDim2.new(1, -20, 0, 50)
    autoPlaceFrame.BackgroundColor3 = colors.hover
    autoPlaceFrame.BorderSizePixel = 0
    autoPlaceFrame.LayoutOrder = 1
    autoPlaceFrame.Parent = sidebar
    
    local autoPlaceCorner = Instance.new("UICorner")
    autoPlaceCorner.CornerRadius = UDim.new(0, 6)
    autoPlaceCorner.Parent = autoPlaceFrame
    
    local autoPlaceLabel = Instance.new("TextLabel")
    autoPlaceLabel.Size = UDim2.new(1, -80, 1, 0)
    autoPlaceLabel.Position = UDim2.new(0, 10, 0, 0)
    autoPlaceLabel.BackgroundTransparency = 1
    autoPlaceLabel.Text = "Auto Place"
    autoPlaceLabel.TextSize = 16
    autoPlaceLabel.Font = Enum.Font.GothamSemibold
    autoPlaceLabel.TextColor3 = colors.text
    autoPlaceLabel.TextXAlignment = Enum.TextXAlignment.Left
    autoPlaceLabel.Parent = autoPlaceFrame
    
    local autoPlaceToggle = Instance.new("TextButton")
    autoPlaceToggle.Name = "Toggle"
    autoPlaceToggle.Size = UDim2.new(0, 60, 0, 30)
    autoPlaceToggle.Position = UDim2.new(1, -70, 0.5, -15)
    autoPlaceToggle.BackgroundColor3 = colors.surface
    autoPlaceToggle.BorderSizePixel = 0
    autoPlaceToggle.Text = "OFF"
    autoPlaceToggle.TextSize = 12
    autoPlaceToggle.Font = Enum.Font.GothamBold
    autoPlaceToggle.TextColor3 = colors.text
    autoPlaceToggle.Parent = autoPlaceFrame
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 6)
    toggleCorner.Parent = autoPlaceToggle
    
    -- Section headers and controls will be added here
    -- Sources Section
    local sourcesLabel = Instance.new("TextLabel")
    sourcesLabel.Name = "SourcesLabel"
    sourcesLabel.Size = UDim2.new(1, -20, 0, 25)
    sourcesLabel.BackgroundTransparency = 1
    sourcesLabel.Text = "SOURCES"
    sourcesLabel.TextSize = 11
    sourcesLabel.Font = Enum.Font.GothamBold
    sourcesLabel.TextColor3 = colors.textTertiary
    sourcesLabel.TextXAlignment = Enum.TextXAlignment.Left
    sourcesLabel.LayoutOrder = 2
    sourcesLabel.Parent = sidebar
    
    -- Eggs Toggle
    local eggsToggle = Instance.new("TextButton")
    eggsToggle.Name = "EggsToggle"
    eggsToggle.Size = UDim2.new(1, -20, 0, 35)
    eggsToggle.BackgroundColor3 = placeEggsEnabled and colors.success or colors.hover
    eggsToggle.BorderSizePixel = 0
    eggsToggle.Text = "Eggs: " .. (placeEggsEnabled and "ON" or "OFF")
    eggsToggle.TextSize = 13
    eggsToggle.Font = Enum.Font.GothamSemibold
    eggsToggle.TextColor3 = colors.text
    eggsToggle.LayoutOrder = 3
    eggsToggle.Parent = sidebar
    
    local eggsCorner = Instance.new("UICorner")
    eggsCorner.CornerRadius = UDim.new(0, 6)
    eggsCorner.Parent = eggsToggle
    
    -- Pets Toggle
    local petsToggle = Instance.new("TextButton")
    petsToggle.Name = "PetsToggle"
    petsToggle.Size = UDim2.new(1, -20, 0, 35)
    petsToggle.BackgroundColor3 = placePetsEnabled and colors.success or colors.hover
    petsToggle.BorderSizePixel = 0
    petsToggle.Text = "Pets: " .. (placePetsEnabled and "ON" or "OFF")
    petsToggle.TextSize = 13
    petsToggle.Font = Enum.Font.GothamSemibold
    petsToggle.TextColor3 = colors.text
    petsToggle.LayoutOrder = 4
    petsToggle.Parent = sidebar
    
    local petsCorner = Instance.new("UICorner")
    petsCorner.CornerRadius = UDim.new(0, 6)
    petsCorner.Parent = petsToggle
    
    -- Filters Section
    local filtersLabel = Instance.new("TextLabel")
    filtersLabel.Name = "FiltersLabel"
    filtersLabel.Size = UDim2.new(1, -20, 0, 25)
    filtersLabel.BackgroundTransparency = 1
    filtersLabel.Text = "FILTERS"
    filtersLabel.TextSize = 11
    filtersLabel.Font = Enum.Font.GothamBold
    filtersLabel.TextColor3 = colors.textTertiary
    filtersLabel.TextXAlignment = Enum.TextXAlignment.Left
    filtersLabel.LayoutOrder = 5
    filtersLabel.Parent = sidebar
    
    -- Min Speed Input
    local minSpeedFrame = Instance.new("Frame")
    minSpeedFrame.Name = "MinSpeedFrame"
    minSpeedFrame.Size = UDim2.new(1, -20, 0, 60)
    minSpeedFrame.BackgroundTransparency = 1
    minSpeedFrame.LayoutOrder = 6
    minSpeedFrame.Parent = sidebar
    
    local minSpeedLabel = Instance.new("TextLabel")
    minSpeedLabel.Size = UDim2.new(1, 0, 0, 20)
    minSpeedLabel.BackgroundTransparency = 1
    minSpeedLabel.Text = "Min Pet Speed"
    minSpeedLabel.TextSize = 12
    minSpeedLabel.Font = Enum.Font.GothamSemibold
    minSpeedLabel.TextColor3 = colors.text
    minSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
    minSpeedLabel.Parent = minSpeedFrame
    
    local minSpeedInput = Instance.new("TextBox")
    minSpeedInput.Name = "Input"
    minSpeedInput.Size = UDim2.new(1, 0, 0, 30)
    minSpeedInput.Position = UDim2.new(0, 0, 0, 25)
    minSpeedInput.BackgroundColor3 = colors.hover
    minSpeedInput.BorderSizePixel = 0
    minSpeedInput.Text = "0"
    minSpeedInput.PlaceholderText = "0"
    minSpeedInput.TextSize = 13
    minSpeedInput.Font = Enum.Font.Gotham
    minSpeedInput.TextColor3 = colors.text
    minSpeedInput.TextXAlignment = Enum.TextXAlignment.Center
    minSpeedInput.ClearTextOnFocus = false
    minSpeedInput.Parent = minSpeedFrame
    
    local minSpeedCorner = Instance.new("UICorner")
    minSpeedCorner.CornerRadius = UDim.new(0, 6)
    minSpeedCorner.Parent = minSpeedInput
    
    -- Sort Order Dropdown (simplified as toggle for now)
    local sortFrame = Instance.new("Frame")
    sortFrame.Name = "SortFrame"
    sortFrame.Size = UDim2.new(1, -20, 0, 60)
    sortFrame.BackgroundTransparency = 1
    sortFrame.LayoutOrder = 7
    sortFrame.Parent = sidebar
    
    local sortLabel = Instance.new("TextLabel")
    sortLabel.Size = UDim2.new(1, 0, 0, 20)
    sortLabel.BackgroundTransparency = 1
    sortLabel.Text = "Sort Order"
    sortLabel.TextSize = 12
    sortLabel.Font = Enum.Font.GothamSemibold
    sortLabel.TextColor3 = colors.text
    sortLabel.TextXAlignment = Enum.TextXAlignment.Left
    sortLabel.Parent = sortFrame
    
    local sortToggle = Instance.new("TextButton")
    sortToggle.Name = "SortToggle"
    sortToggle.Size = UDim2.new(1, 0, 0, 30)
    sortToggle.Position = UDim2.new(0, 0, 0, 25)
    sortToggle.BackgroundColor3 = colors.hover
    sortToggle.BorderSizePixel = 0
    sortToggle.Text = petSortAscending and "Low → High" or "High → Low"
    sortToggle.TextSize = 13
    sortToggle.Font = Enum.Font.Gotham
    sortToggle.TextColor3 = colors.text
    sortToggle.Parent = sortFrame
    
    local sortCorner = Instance.new("UICorner")
    sortCorner.CornerRadius = UDim.new(0, 6)
    sortCorner.Parent = sortToggle
    
    -- Inventory Section
    local inventoryLabel = Instance.new("TextLabel")
    inventoryLabel.Name = "InventoryLabel"
    inventoryLabel.Size = UDim2.new(1, -20, 0, 25)
    inventoryLabel.BackgroundTransparency = 1
    inventoryLabel.Text = "INVENTORY"
    inventoryLabel.TextSize = 11
    inventoryLabel.Font = Enum.Font.GothamBold
    inventoryLabel.TextColor3 = colors.textTertiary
    inventoryLabel.TextXAlignment = Enum.TextXAlignment.Left
    inventoryLabel.LayoutOrder = 8
    inventoryLabel.Parent = sidebar
    
    -- Inventory container (will be populated dynamically)
    local inventoryContainer = Instance.new("Frame")
    inventoryContainer.Name = "InventoryContainer"
    inventoryContainer.Size = UDim2.new(1, -20, 0, 300)
    inventoryContainer.BackgroundColor3 = colors.background
    inventoryContainer.BorderSizePixel = 0
    inventoryContainer.LayoutOrder = 9
    inventoryContainer.Parent = sidebar
    
    local inventoryCorner = Instance.new("UICorner")
    inventoryCorner.CornerRadius = UDim.new(0, 6)
    inventoryCorner.Parent = inventoryContainer
    
    local inventoryScroll = Instance.new("ScrollingFrame")
    inventoryScroll.Name = "Scroll"
    inventoryScroll.Size = UDim2.new(1, -10, 1, -10)
    inventoryScroll.Position = UDim2.new(0, 5, 0, 5)
    inventoryScroll.BackgroundTransparency = 1
    inventoryScroll.BorderSizePixel = 0
    inventoryScroll.ScrollBarThickness = 4
    inventoryScroll.ScrollBarImageColor3 = colors.primary
    inventoryScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    inventoryScroll.Parent = inventoryContainer
    
    local inventoryLayout = Instance.new("UIListLayout")
    inventoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
    inventoryLayout.Padding = UDim.new(0, 5)
    inventoryLayout.Parent = inventoryScroll
    
    -- Placement Speed Slider (before inventory)
    local placementSpeedFrame = Instance.new("Frame")
    placementSpeedFrame.Name = "PlacementSpeedFrame"
    placementSpeedFrame.Size = UDim2.new(1, -20, 0, 65)
    placementSpeedFrame.BackgroundColor3 = colors.hover
    placementSpeedFrame.BorderSizePixel = 0
    placementSpeedFrame.LayoutOrder = 7
    placementSpeedFrame.Parent = sidebar
    
    local speedFrameCorner = Instance.new("UICorner")
    speedFrameCorner.CornerRadius = UDim.new(0, 6)
    speedFrameCorner.Parent = placementSpeedFrame
    
    local placementSpeedLabel = Instance.new("TextLabel")
    placementSpeedLabel.Name = "SpeedLabel"
    placementSpeedLabel.Size = UDim2.new(1, -20, 0, 20)
    placementSpeedLabel.Position = UDim2.new(0, 10, 0, 5)
    placementSpeedLabel.BackgroundTransparency = 1
    placementSpeedLabel.Text = "Place Speed: " .. string.format("%.1fs", placementSpeed)
    placementSpeedLabel.TextSize = 12
    placementSpeedLabel.Font = Enum.Font.GothamSemibold
    placementSpeedLabel.TextColor3 = colors.text
    placementSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
    placementSpeedLabel.Parent = placementSpeedFrame
    
    local speedSliderBg = Instance.new("Frame")
    speedSliderBg.Name = "SpeedSliderBg"
    speedSliderBg.Size = UDim2.new(1, -20, 0, 6)
    speedSliderBg.Position = UDim2.new(0, 10, 0, 30)
    speedSliderBg.BackgroundColor3 = colors.surface
    speedSliderBg.BorderSizePixel = 0
    speedSliderBg.Parent = placementSpeedFrame
    
    local speedSliderBgCorner = Instance.new("UICorner")
    speedSliderBgCorner.CornerRadius = UDim.new(0, 3)
    speedSliderBgCorner.Parent = speedSliderBg
    
    local speedSliderFill = Instance.new("Frame")
    speedSliderFill.Name = "SpeedSliderFill"
    speedSliderFill.Size = UDim2.new((placementSpeed - 1) / 9, 0, 1, 0) -- Map 1-10 to 0-1
    speedSliderFill.Position = UDim2.new(0, 0, 0, 0)
    speedSliderFill.BackgroundColor3 = colors.primary
    speedSliderFill.BorderSizePixel = 0
    speedSliderFill.Parent = speedSliderBg
    
    local speedSliderFillCorner = Instance.new("UICorner")
    speedSliderFillCorner.CornerRadius = UDim.new(0, 3)
    speedSliderFillCorner.Parent = speedSliderFill
    
    local speedSliderHandle = Instance.new("Frame")
    speedSliderHandle.Name = "SpeedSliderHandle"
    speedSliderHandle.Size = UDim2.new(0, 16, 0, 16)
    speedSliderHandle.Position = UDim2.new((placementSpeed - 1) / 9, -8, 0, 25) -- Map 1-10 to 0-1
    speedSliderHandle.BackgroundColor3 = colors.text
    speedSliderHandle.BorderSizePixel = 0
    speedSliderHandle.ZIndex = 2
    speedSliderHandle.Parent = placementSpeedFrame
    
    local speedSliderHandleCorner = Instance.new("UICorner")
    speedSliderHandleCorner.CornerRadius = UDim.new(0, 8)
    speedSliderHandleCorner.Parent = speedSliderHandle
    
    -- UI Scale Slider
    local uiScaleFrame = Instance.new("Frame")
    uiScaleFrame.Name = "UIScaleFrame"
    uiScaleFrame.Size = UDim2.new(1, -20, 0, 65)
    uiScaleFrame.BackgroundColor3 = colors.hover
    uiScaleFrame.BorderSizePixel = 0
    uiScaleFrame.LayoutOrder = 8
    uiScaleFrame.Parent = sidebar
    
    local uiScaleFrameCorner = Instance.new("UICorner")
    uiScaleFrameCorner.CornerRadius = UDim.new(0, 6)
    uiScaleFrameCorner.Parent = uiScaleFrame
    
    local uiScaleLabel = Instance.new("TextLabel")
    uiScaleLabel.Name = "UIScaleLabel"
    uiScaleLabel.Size = UDim2.new(1, -20, 0, 20)
    uiScaleLabel.Position = UDim2.new(0, 10, 0, 5)
    uiScaleLabel.BackgroundTransparency = 1
    uiScaleLabel.Text = "UI Scale: 100%"
    uiScaleLabel.TextSize = 12
    uiScaleLabel.Font = Enum.Font.GothamSemibold
    uiScaleLabel.TextColor3 = colors.text
    uiScaleLabel.TextXAlignment = Enum.TextXAlignment.Left
    uiScaleLabel.Parent = uiScaleFrame
    
    local uiScaleSliderBg = Instance.new("Frame")
    uiScaleSliderBg.Name = "UIScaleSliderBg"
    uiScaleSliderBg.Size = UDim2.new(1, -20, 0, 6)
    uiScaleSliderBg.Position = UDim2.new(0, 10, 0, 30)
    uiScaleSliderBg.BackgroundColor3 = colors.surface
    uiScaleSliderBg.BorderSizePixel = 0
    uiScaleSliderBg.Parent = uiScaleFrame
    
    local uiScaleSliderBgCorner = Instance.new("UICorner")
    uiScaleSliderBgCorner.CornerRadius = UDim.new(0, 3)
    uiScaleSliderBgCorner.Parent = uiScaleSliderBg
    
    local uiScaleSliderFill = Instance.new("Frame")
    uiScaleSliderFill.Name = "UIScaleSliderFill"
    uiScaleSliderFill.Size = UDim2.new(0.7, 0, 1, 0) -- Default 100% = 0.7 position (0.5-1.2 range)
    uiScaleSliderFill.Position = UDim2.new(0, 0, 0, 0)
    uiScaleSliderFill.BackgroundColor3 = colors.primary
    uiScaleSliderFill.BorderSizePixel = 0
    uiScaleSliderFill.Parent = uiScaleSliderBg
    
    local uiScaleSliderFillCorner = Instance.new("UICorner")
    uiScaleSliderFillCorner.CornerRadius = UDim.new(0, 3)
    uiScaleSliderFillCorner.Parent = uiScaleSliderFill
    
    local uiScaleSliderHandle = Instance.new("Frame")
    uiScaleSliderHandle.Name = "UIScaleSliderHandle"
    uiScaleSliderHandle.Size = UDim2.new(0, 16, 0, 16)
    uiScaleSliderHandle.Position = UDim2.new(0.7, -8, 0, 25) -- Default 100% position
    uiScaleSliderHandle.BackgroundColor3 = colors.text
    uiScaleSliderHandle.BorderSizePixel = 0
    uiScaleSliderHandle.ZIndex = 2
    uiScaleSliderHandle.Parent = uiScaleFrame
    
    local uiScaleSliderHandleCorner = Instance.new("UICorner")
    uiScaleSliderHandleCorner.CornerRadius = UDim.new(0, 8)
    uiScaleSliderHandleCorner.Parent = uiScaleSliderHandle
    
    return {
        autoPlaceToggle = autoPlaceToggle,
        eggsToggle = eggsToggle,
        petsToggle = petsToggle,
        minSpeedInput = minSpeedInput,
        sortToggle = sortToggle,
        inventoryScroll = inventoryScroll,
        placementSpeedLabel = placementSpeedLabel,
        speedSliderBg = speedSliderBg,
        speedSliderFill = speedSliderFill,
        speedSliderHandle = speedSliderHandle,
        uiScaleLabel = uiScaleLabel,
        uiScaleSliderBg = uiScaleSliderBg,
        uiScaleSliderFill = uiScaleSliderFill,
        uiScaleSliderHandle = uiScaleSliderHandle
    }
end

-- Create grid tiles
refreshGrid = function()
    if not GridContainer then return end
    
    -- Save current selection before clearing
    local selectedTileKeys = {}
    for _, selected in ipairs(selectedTilesForPlacement) do
        selectedTileKeys[selected.key] = true
    end
    
    -- Clear existing tiles
    for _, tileData in pairs(tileButtons) do
        if tileData and tileData.button then 
            tileData.button:Destroy() 
        end
    end
    tileButtons = {}
    
    local islandName = getAssignedIslandName()
    local islandNumber = getIslandNumberFromName(islandName)
    if not islandNumber then return end
    
    local isWater = currentTileType == "Water"
    local tiles = getFarmTiles(islandNumber, isWater)
    
    if #tiles == 0 then
        GridContainer.Size = UDim2.new(1, 0, 1, 0)
        return
    end
    
    -- Find grid bounds
    local minX, maxX = math.huge, -math.huge
    local minZ, maxZ = math.huge, -math.huge
    
    for _, tile in ipairs(tiles) do
        minX = math.min(minX, tile.gridX)
        maxX = math.max(maxX, tile.gridX)
        minZ = math.min(minZ, tile.gridZ)
        maxZ = math.max(maxZ, tile.gridZ)
    end
    
    local gridWidth = maxX - minX + 1
    local gridHeight = maxZ - minZ + 1
    
    local tileSize = 40 -- pixels per tile
    local tileSpacing = 2
    
    GridContainer.Size = UDim2.new(0, gridWidth * (tileSize + tileSpacing), 0, gridHeight * (tileSize + tileSpacing))
    
    -- Create tile buttons
    for _, tile in ipairs(tiles) do
        local x = tile.gridX - minX
        local z = tile.gridZ - minZ
        -- ROTATE 180°: Flip both X and Z axes
        local flippedX = (maxX - tile.gridX)
        local flippedZ = (maxZ - tile.gridZ)
        
        local occupied, occupant = isTileOccupied(tile.part)
        
        local btn = Instance.new("TextButton")
        btn.Name = "Tile_" .. tile.gridX .. "_" .. tile.gridZ
        btn.Size = UDim2.new(0, tileSize, 0, tileSize)
        btn.Position = UDim2.new(0, flippedX * (tileSize + tileSpacing), 0, flippedZ * (tileSize + tileSpacing))
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.Parent = GridContainer
        
        -- Set color based on state (check if was previously selected)
        local wasSelected = selectedTileKeys[btn.Name]
        
        if tile.locked then
            btn.BackgroundColor3 = colors.locked
            -- Add lock icon
            local lockIcon = Instance.new("TextLabel")
            lockIcon.Size = UDim2.new(1, 0, 1, 0)
            lockIcon.BackgroundTransparency = 1
            lockIcon.Text = "🔒"
            lockIcon.TextSize = 20
            lockIcon.TextColor3 = colors.textSecondary
            lockIcon.Parent = btn
        elseif occupied then
            btn.BackgroundColor3 = colors.occupied
        elseif wasSelected then
            -- Restore green highlight for previously selected tiles
            btn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
        else
            btn.BackgroundColor3 = isWater and colors.emptyWater or colors.emptyRegular
        end
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = btn
        
        -- Store tile data
        btn:SetAttribute("GridX", tile.gridX)
        btn:SetAttribute("GridY", tile.gridY)
        btn:SetAttribute("GridZ", tile.gridZ)
        btn:SetAttribute("IsWater", tile.isWater)
        btn:SetAttribute("Locked", tile.locked)
        btn:SetAttribute("Occupied", occupied)
        
        tileButtons[btn.Name] = {
            button = btn,
            tile = tile,
            occupant = occupant
        }
        
        -- Add click handlers for tiles
        btn.MouseButton1Click:Connect(function()
            if occupied then
                -- Show info for occupied tile
                showTileInfo(tileButtons[btn.Name])
            else
                -- Select empty tile(s) for placement queue (multi-select by default)
                if not tile.locked then
                    local tileKey = btn.Name
                    
                    -- Check if this tile is already selected
                    local isSelected = false
                    local selectedIndex = nil
                    for i, selectedTile in ipairs(selectedTilesForPlacement) do
                        if selectedTile.key == tileKey then
                            isSelected = true
                            selectedIndex = i
                            break
                        end
                    end
                    
                    -- Toggle this tile (free multi-select - no Ctrl needed)
                    if isSelected then
                        -- Deselect: remove from list
                        table.remove(selectedTilesForPlacement, selectedIndex)
                        -- Reset color
                        btn.BackgroundColor3 = tile.isWater and colors.emptyWater or colors.emptyRegular
                    else
                        -- Add to selection
                        table.insert(selectedTilesForPlacement, {
                            key = tileKey,
                            data = tileButtons[tileKey],
                            gridX = tile.gridX,
                            gridZ = tile.gridZ
                        })
                        -- Highlight selected tile green
                        btn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
                    end
                    
                    -- Sort selected tiles left-to-right, top-to-bottom
                    table.sort(selectedTilesForPlacement, function(a, b)
                        if a.gridZ == b.gridZ then
                            return a.gridX < b.gridX
                        end
                        return a.gridZ < b.gridZ
                    end)
                    
                    -- Reset placement index
                    currentPlacementIndex = 1
                    
                    -- Show feedback
                    if WindUI then
                        WindUI:Notify({
                            Title = "🎯 Tile Selection",
                            Content = #selectedTilesForPlacement .. " tile(s) selected (Click again to deselect)",
                            Duration = 2
                        })
                    end
                end
            end
        end)
        
        -- Right-click to pick up
        btn.MouseButton2Click:Connect(function()
            if occupied then
                local tileData = tileButtons[btn.Name]
                local info = getTileOccupantInfo(tileData.occupant)
                if info and info.uid and CharacterRE then
                    pcall(function()
                        CharacterRE:FireServer("Del", info.uid)
                    end)
                    task.wait(0.5)
                    refreshGrid()
                end
            end
        end)
    end
end

-- Update sidebar inventory
updateSidebar = function()
    if not ScreenGui then return end
    
    local sidebar = ScreenGui.MainFrame:FindFirstChild("Sidebar")
    if not sidebar then return end
    
    local inventoryContainer = sidebar:FindFirstChild("InventoryContainer")
    if not inventoryContainer then return end
    
    local scroll = inventoryContainer:FindFirstChild("Scroll")
    if not scroll then return end
    
    -- Clear existing items (skip UIListLayout)
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") and child.Name:find("Item_") then
            child:Destroy()
        end
    end
    
    local items = {}
    
    if placeEggsEnabled then
        for _, egg in ipairs(getAvailableEggs()) do
            table.insert(items, egg)
        end
    end
    
    if placePetsEnabled then
        for _, pet in ipairs(getAvailablePets()) do
            table.insert(items, pet)
        end
    end
    
    -- Create item cards
    for i, item in ipairs(items) do
        local card = Instance.new("Frame")
        card.Name = "Item_" .. item.uid
        card.Size = UDim2.new(1, 0, 0, 45)
        card.BackgroundColor3 = colors.hover
        card.BorderSizePixel = 0
        card.LayoutOrder = i
        card.Parent = scroll
        
        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 4)
        cardCorner.Parent = card
        
        -- Icon/Type indicator
        local typeLabel = Instance.new("TextLabel")
        typeLabel.Size = UDim2.new(0, 40, 1, 0)
        typeLabel.BackgroundTransparency = 1
        typeLabel.Text = item.category == "Egg" and "🥚" or "🐾"
        typeLabel.TextSize = 20
        typeLabel.Parent = card
        
        -- Name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -90, 0, 18)
        nameLabel.Position = UDim2.new(0, 45, 0, 5)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = item.type
        nameLabel.TextSize = 12
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextColor3 = colors.text
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = card
        
        -- Info (speed or mutation)
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(1, -90, 0, 15)
        infoLabel.Position = UDim2.new(0, 45, 0, 23)
        infoLabel.BackgroundTransparency = 1
        if item.category == "Pet" then
            infoLabel.Text = "Speed: " .. formatNumber(item.speed or 0)
        else
            -- Safe mutation display
            local mutationText = "No Mutation"
            if item.mutation and type(item.mutation) == "string" and item.mutation ~= "" then
                mutationText = "⚡ " .. item.mutation
            end
            infoLabel.Text = mutationText
        end
        infoLabel.TextSize = 10
        infoLabel.Font = Enum.Font.Gotham
        infoLabel.TextColor3 = colors.textSecondary
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.Parent = card
        
        -- Store item data for drag
        card:SetAttribute("ItemUID", item.uid)
        card:SetAttribute("ItemCategory", item.category)
        
        -- Add click to place functionality
        card.Active = true
        local clickBtn = Instance.new("TextButton")
        clickBtn.Size = UDim2.new(1, 0, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""
        clickBtn.ZIndex = 10
        clickBtn.Parent = card
        
        clickBtn.MouseButton1Click:Connect(function()
            -- Manual placement from inventory
            task.spawn(function()
                local success, err = pcall(function()
                    local targetTile = nil
                    
                    -- Check if we have selected tiles in queue
                    if selectedTilesForPlacement and type(selectedTilesForPlacement) == "table" then
                        if #selectedTilesForPlacement > 0 and currentPlacementIndex <= #selectedTilesForPlacement then
                            -- Use next tile from queue
                            local selectedEntry = selectedTilesForPlacement[currentPlacementIndex]
                            if selectedEntry and selectedEntry.data then
                                targetTile = selectedEntry.data
                                currentPlacementIndex = currentPlacementIndex + 1
                            end
                        end
                    end
                    
                    -- If no tile from queue, try to find next available tile
                    if not targetTile and highlightNextTile then
                        targetTile = highlightNextTile()
                    end
                    
                    if not targetTile then
                        if WindUI then
                            WindUI:Notify({
                                Title = "⚠️ No Tiles",
                                Content = "No empty tiles available",
                                Duration = 3
                            })
                        end
                        return
                    end
                    
                    -- Try to place on target tile
                    local placementSuccess = placeItemOnTile(item.uid, targetTile, item)
                    
                    if placementSuccess then
                        if WindUI then
                            local remaining = selectedTilesForPlacement and #selectedTilesForPlacement - currentPlacementIndex + 1 or 0
                            local queueInfo = remaining > 0 and (" | " .. remaining .. " tiles left") or ""
                            WindUI:Notify({
                                Title = "✅ Placed!",
                                Content = "Placed " .. tostring(item.type) .. queueInfo,
                                Duration = 2
                            })
                        end
                        task.wait(1) -- Wait longer for placement to register
                        pcall(refreshGrid)
                        pcall(updateSidebar)
                    else
                        if WindUI then
                            WindUI:Notify({
                                Title = "❌ Placement Failed",
                                Content = "Could not place " .. tostring(item.type) .. " - check tile type match",
                                Duration = 3
                            })
                        end
                    end
                end)
                
                if not success then
                    warn("[Grid UI] Inventory click error: " .. tostring(err))
                    if WindUI then
                        WindUI:Notify({
                            Title = "❌ Error",
                            Content = "Click error: " .. tostring(err),
                            Duration = 3
                        })
                    end
                end
            end)
        end)
    end
end

-- Show tile info panel
showTileInfo = function(tileData)
    if not tileData or not tileData.occupant then return end
    
    local info = getTileOccupantInfo(tileData.occupant)
    if not info then return end
    
    -- Create info panel (modal)
    local infoPanel = Instance.new("Frame")
    infoPanel.Name = "TileInfoPanel"
    infoPanel.Size = UDim2.new(0, 300, 0, 250)
    infoPanel.Position = UDim2.new(0.5, -150, 0.5, -125)
    infoPanel.BackgroundColor3 = colors.surface
    infoPanel.BorderSizePixel = 0
    infoPanel.ZIndex = 200
    infoPanel.Parent = ScreenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = infoPanel
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = colors.border
    stroke.Thickness = 2
    stroke.Parent = infoPanel
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = colors.close
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextColor3 = colors.text
    closeBtn.ZIndex = 201
    closeBtn.Parent = infoPanel
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0.5, 0)
    closeCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        infoPanel:Destroy()
    end)
    
    -- Content
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 1, -50)
    content.Position = UDim2.new(0, 10, 0, 40)
    content.BackgroundTransparency = 1
    content.ZIndex = 201
    content.Parent = infoPanel
    
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)
    layout.Parent = content
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.BackgroundTransparency = 1
    title.Text = info.type .. " Info"
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = colors.text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 201
    title.LayoutOrder = 1
    title.Parent = content
    
    -- Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "Name: " .. info.name
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextColor3 = colors.textSecondary
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 201
    nameLabel.LayoutOrder = 2
    nameLabel.Parent = content
    
    -- Speed (if pet)
    if info.speed then
        local speedLabel = Instance.new("TextLabel")
        speedLabel.Size = UDim2.new(1, 0, 0, 20)
        speedLabel.BackgroundTransparency = 1
        speedLabel.Text = "Speed: " .. formatNumber(info.speed)
        speedLabel.TextSize = 14
        speedLabel.Font = Enum.Font.Gotham
        speedLabel.TextColor3 = colors.textSecondary
        speedLabel.TextXAlignment = Enum.TextXAlignment.Left
        speedLabel.ZIndex = 201
        speedLabel.LayoutOrder = 3
        speedLabel.Parent = content
    end
    
    -- Mutation
    if info.mutation then
        local mutationLabel = Instance.new("TextLabel")
        mutationLabel.Size = UDim2.new(1, 0, 0, 20)
        mutationLabel.BackgroundTransparency = 1
        mutationLabel.Text = "Mutation: " .. info.mutation
        mutationLabel.TextSize = 14
        mutationLabel.Font = Enum.Font.Gotham
        mutationLabel.TextColor3 = colors.textSecondary
        mutationLabel.TextXAlignment = Enum.TextXAlignment.Left
        mutationLabel.ZIndex = 201
        mutationLabel.LayoutOrder = 4
        mutationLabel.Parent = content
    end
    
    
    -- Pick Up button
    local pickUpBtn = Instance.new("TextButton")
    pickUpBtn.Size = UDim2.new(1, 0, 0, 40)
    pickUpBtn.BackgroundColor3 = colors.error
    pickUpBtn.BorderSizePixel = 0
    pickUpBtn.Text = "🗑️ Pick Up"
    pickUpBtn.TextSize = 14
    pickUpBtn.Font = Enum.Font.GothamBold
    pickUpBtn.TextColor3 = colors.text
    pickUpBtn.ZIndex = 201
    pickUpBtn.LayoutOrder = 6
    pickUpBtn.Parent = content
    
    local pickUpCorner = Instance.new("UICorner")
    pickUpCorner.CornerRadius = UDim.new(0, 6)
    pickUpCorner.Parent = pickUpBtn
    
    pickUpBtn.MouseButton1Click:Connect(function()
        -- Pick up pet/egg
        if CharacterRE and info.uid then
            pcall(function()
                CharacterRE:FireServer("Del", info.uid)
            end)
            infoPanel:Destroy()
            task.wait(0.5)
            refreshGrid()
        end
    end)
end

-- Place an item on a tile (EXACT COPY FROM AUTOPLACESYSTEM)
local function placeItemOnTile(itemUID, tileData, itemData)
    if not CharacterRE or not itemUID or not tileData then 
        return false 
    end
    
    local tile = tileData.tile
    if not tile or not tile.part then 
        return false 
    end
    
    -- Validate tile type matches item type (ocean items need water tiles, regular items need regular tiles)
    if itemData then
        local isItemOcean = itemData.isOcean or false
        local isTileWater = tile.isWater or false
        
        if isItemOcean and not isTileWater then
            -- Ocean item can't be placed on regular tile
            if WindUI then
                WindUI:Notify({
                    Title = "❌ Wrong Tile Type",
                    Content = "Ocean " .. (itemData.category or "item") .. " needs water tile!",
                    Duration = 3
                })
            end
            return false
        elseif not isItemOcean and isTileWater then
            -- Regular item can't be placed on water tile
            if WindUI then
                WindUI:Notify({
                    Title = "❌ Wrong Tile Type",
                    Content = "Regular " .. (itemData.category or "item") .. " needs regular tile!",
                    Duration = 3
                })
            end
            return false
        end
    end
    
    local farmPart = tile.part
    
    -- Step 1: Focus the item first (CRITICAL - from AutoPlaceSystem line 690)
    local focusSuccess = pcall(function()
        CharacterRE:FireServer("Focus", itemUID)
    end)
    if not focusSuccess then
        return false
    end
    task.wait(0.2)
    
    -- Step 2: Calculate placement position with grid snapping (from AutoPlaceSystem line 704-708)
    local tileCenter = farmPart.Position
    local surfacePosition = Vector3.new(
        math.floor(tileCenter.X / 8) * 8 + 4, -- Snap to 8x8 grid center (X)
        tileCenter.Y + (farmPart.Size.Y / 2), -- Surface height
        math.floor(tileCenter.Z / 8) * 8 + 4  -- Snap to 8x8 grid center (Z)
    )
    
    -- Step 3: Set Deploy S2 attribute (from AutoPlaceSystem line 711-714)
    local deploy = LocalPlayer.PlayerGui.Data:FindFirstChild("Deploy")
    if deploy then
        deploy:SetAttribute("S2", itemUID)
    end
    
    -- Step 4: Hold egg/pet (key 2) (from AutoPlaceSystem line 717-720)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
    task.wait(0.1)
    
    -- Step 5: Fire placement command
    local args = {
        "Place",
        {
            DST = vector.create(surfacePosition.X, surfacePosition.Y, surfacePosition.Z),
            ID = itemUID
        }
    }
    
    local success, err = pcall(function()
        CharacterRE:FireServer(unpack(args))
    end)
    
    if success then
        task.wait(0.5) -- Wait for placement to register
        return true
    else
        return false
    end
end

-- Highlight next target tile
highlightNextTile = function()
    -- Clear all highlights first
    for _, tileData in pairs(tileButtons) do
        if tileData and tileData.button then
            local btn = tileData.button
            local isWater = btn:GetAttribute("IsWater")
            local occupied = btn:GetAttribute("Occupied")
            local locked = btn:GetAttribute("Locked")
            
            -- Reset to normal colors
            if locked then
                btn.BackgroundColor3 = colors.locked
            elseif occupied then
                btn.BackgroundColor3 = colors.occupied
            else
                btn.BackgroundColor3 = isWater and colors.emptyWater or colors.emptyRegular
            end
        end
    end
    
    -- Find and highlight first empty tile
    for _, tileData in pairs(tileButtons) do
        if tileData and tileData.button then
            local btn = tileData.button
            if not btn:GetAttribute("Occupied") and not btn:GetAttribute("Locked") then
                -- Highlight with bright green
                btn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
                return tileData
            end
        end
    end
    
    return nil
end

-- Auto place logic - use selected tiles queue or find tiles left-to-right, top-to-bottom
local function performAutoPlace()
    if not autoPlaceEnabled then return end
    
    -- Get available items
    local items = {}
    if placeEggsEnabled then
        for _, egg in ipairs(getAvailableEggs()) do
            table.insert(items, egg)
        end
    end
    if placePetsEnabled then
        for _, pet in ipairs(getAvailablePets()) do
            table.insert(items, pet)
        end
    end
    
    if #items == 0 then 
        -- No items available, just wait (don't stop auto place)
        return 
    end
    
    -- Determine target tile
    local targetTile = nil
    
    -- Safely check for selected tiles queue
    if selectedTilesForPlacement and type(selectedTilesForPlacement) == "table" and #selectedTilesForPlacement > 0 then
        if currentPlacementIndex <= #selectedTilesForPlacement then
            -- Use next tile from user-selected queue
            local selectedEntry = selectedTilesForPlacement[currentPlacementIndex]
            if selectedEntry and selectedEntry.data then
                targetTile = selectedEntry.data
                currentPlacementIndex = currentPlacementIndex + 1
            end
        else
            -- Queue exhausted - stop auto place and notify
            autoPlaceEnabled = false
            if WindUI then
                WindUI:Notify({
                    Title = "✅ Queue Complete",
                    Content = "All selected tiles filled!",
                    Duration = 3
                })
            end
            return
        end
    end
    
    -- If no tile from queue, find next available tile
    if not targetTile then
        
        -- Find all empty tiles and sort them
        local emptyTiles = {}
        for _, tileData in pairs(tileButtons) do
            if tileData and tileData.button then
                local btn = tileData.button
                if not btn:GetAttribute("Occupied") and not btn:GetAttribute("Locked") then
                    table.insert(emptyTiles, {
                        data = tileData,
                        gridX = btn:GetAttribute("GridX") or 0,
                        gridZ = btn:GetAttribute("GridZ") or 0
                    })
                end
            end
        end
        
        if #emptyTiles == 0 then 
            return 
        end
        
        -- Sort left-to-right, top-to-bottom
        table.sort(emptyTiles, function(a, b)
            if a.gridZ == b.gridZ then
                return a.gridX < b.gridX
            end
            return a.gridZ < b.gridZ
        end)
        
        targetTile = emptyTiles[1].data
    end
    
    if not targetTile then return end
    
    -- Place first item on target tile
    local item = items[1]
    
    if placeItemOnTile(item.uid, targetTile, item) then
        task.wait(2) -- Increased delay to avoid spam
        refreshGrid()
        updateSidebar()
    end
end

-- Auto place loop (runs in separate thread with error protection)
local autoPlaceThread = nil
local isAutoPlaceRunning = false

local function runAutoPlaceLoop()
    isAutoPlaceRunning = true
    
    while autoPlaceEnabled do
        local success = pcall(function()
            -- Try to place one item
            performAutoPlace()
            
            -- Wait between placements using adjustable speed
            task.wait(placementSpeed)
            
            -- Update UI periodically
            if autoPlaceEnabled then
                pcall(refreshGrid)
                pcall(updateSidebar)
            end
        end)
        
        if not success then
            -- Error occurred, wait a bit and continue
            task.wait(1)
        end
    end
    
    isAutoPlaceRunning = false
end

local function setupGridMonitoring()
    -- If turning off, just set flag and wait for thread to stop
    if not autoPlaceEnabled then
        autoPlaceEnabled = false
        task.wait(0.5)
        autoPlaceThread = nil
        return
    end
    
    -- If already running, don't start another thread
    if isAutoPlaceRunning then
        return
    end
    
    -- Start new auto place loop in separate thread
    autoPlaceThread = task.spawn(function()
        local success, err = pcall(runAutoPlaceLoop)
        if not success then
            warn("[Grid UI] Auto place loop error: " .. tostring(err))
            autoPlaceEnabled = false
            isAutoPlaceRunning = false
        end
    end)
end

-- Create Main UI
function AutoPlaceGridUI.CreateUI()
    if ScreenGui then
        ScreenGui:Destroy()
    end
    
    -- Cache remote
    local remotes = ReplicatedStorage:FindFirstChild("Remote")
    CharacterRE = remotes and remotes:FindFirstChild("CharacterRE")
    
    local baseWidth = 1200
    local baseHeight = 700
    
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AutoPlaceGridUI"
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = PlayerGui
    
    -- Add UIScale for responsive scaling
    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 1.0
    uiScale.Parent = ScreenGui
    
    MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, baseWidth, 0, baseHeight)
    MainFrame.Position = UDim2.new(0.5, -baseWidth/2, 0.5, -baseHeight/2)
    MainFrame.BackgroundColor3 = colors.background
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
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
    title.Size = UDim2.new(1, -200, 0, 20)
    title.Position = UDim2.new(0, 100, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "Auto Place - Grid View"
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = colors.text
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = MainFrame
    
    -- Status indicator
    local statusIndicator = Instance.new("Frame")
    statusIndicator.Name = "StatusIndicator"
    statusIndicator.Size = UDim2.new(0, 12, 0, 12)
    statusIndicator.Position = UDim2.new(1, -100, 0, 14)
    statusIndicator.BackgroundColor3 = colors.surface
    statusIndicator.BorderSizePixel = 0
    statusIndicator.Parent = MainFrame
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0.5, 0)
    statusCorner.Parent = statusIndicator
    
    -- Create sections
    local sidebar = createSidebar(MainFrame)
    local sidebarControls = populateSidebar(sidebar)
    local gridFrame, regularTab, waterTab, gridContainer = createGridView(MainFrame)
    GridContainer = gridContainer
    
    -- Setup event handlers
    local closeBtn = windowControls.CloseBtn
    local minimizeBtn = windowControls.MinimizeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        AutoPlaceGridUI.Hide()
    end)
    
    minimizeBtn.MouseButton1Click:Connect(function()
        if isMinimized then
            MainFrame.Size = UDim2.new(0, baseWidth, 0, baseHeight)
            sidebar.Visible = true
            gridFrame.Visible = true
            isMinimized = false
        else
            MainFrame.Size = UDim2.new(0, baseWidth, 0, 60)
            sidebar.Visible = false
            gridFrame.Visible = false
            isMinimized = true
        end
    end)
    
    -- Tab switching
    regularTab.MouseButton1Click:Connect(function()
        currentTileType = "Regular"
        regularTab.BackgroundColor3 = colors.primary
        waterTab.BackgroundColor3 = colors.hover
        refreshGrid()
    end)
    
    waterTab.MouseButton1Click:Connect(function()
        currentTileType = "Water"
        waterTab.BackgroundColor3 = colors.primary
        regularTab.BackgroundColor3 = colors.hover
        refreshGrid()
    end)
    
    -- Auto Place Toggle
    sidebarControls.autoPlaceToggle.MouseButton1Click:Connect(function()
        autoPlaceEnabled = not autoPlaceEnabled
        
        -- Update visual state
        sidebarControls.autoPlaceToggle.Text = autoPlaceEnabled and "ON" or "OFF"
        sidebarControls.autoPlaceToggle.BackgroundColor3 = autoPlaceEnabled and colors.success or colors.surface
        statusIndicator.BackgroundColor3 = autoPlaceEnabled and colors.success or colors.surface
        
        if WindUI then
            WindUI:Notify({
                Title = "Auto Place",
                Content = autoPlaceEnabled and "Started" or "Stopped",
                Duration = 2
            })
        end
        
        -- Start or stop the auto place loop
        setupGridMonitoring()
    end)
    
    -- Eggs Toggle
    sidebarControls.eggsToggle.MouseButton1Click:Connect(function()
        placeEggsEnabled = not placeEggsEnabled
        sidebarControls.eggsToggle.Text = "Eggs: " .. (placeEggsEnabled and "ON" or "OFF")
        sidebarControls.eggsToggle.BackgroundColor3 = placeEggsEnabled and colors.success or colors.hover
        updateSidebar()
    end)
    
    -- Pets Toggle
    sidebarControls.petsToggle.MouseButton1Click:Connect(function()
        placePetsEnabled = not placePetsEnabled
        sidebarControls.petsToggle.Text = "Pets: " .. (placePetsEnabled and "ON" or "OFF")
        sidebarControls.petsToggle.BackgroundColor3 = placePetsEnabled and colors.success or colors.hover
        updateSidebar()
    end)
    
    -- Min Speed Input
    sidebarControls.minSpeedInput.FocusLost:Connect(function()
        local value = parseSpeedInput(sidebarControls.minSpeedInput.Text)
        minPetSpeed = value
        updateSidebar()
    end)
    
    -- Sort Toggle
    sidebarControls.sortToggle.MouseButton1Click:Connect(function()
        petSortAscending = not petSortAscending
        sidebarControls.sortToggle.Text = petSortAscending and "Low → High" or "High → Low"
        updateSidebar()
    end)
    
    -- Grid tile click handlers
    task.spawn(function()
        while true do
            task.wait(0.1)
            for _, tileData in pairs(tileButtons) do
                if tileData.button then
                    -- Left click - show info if occupied
                    if not tileData.button:GetAttribute("ClickConnected") then
                        tileData.button:SetAttribute("ClickConnected", true)
                        tileData.button.MouseButton1Click:Connect(function()
                            if tileData.button:GetAttribute("Occupied") then
                                showTileInfo(tileData)
                            end
                        end)
                        
                        -- Right click - pick up (simplified as Button2)
                        tileData.button.MouseButton2Click:Connect(function()
                            if tileData.occupant then
                                local info = getTileOccupantInfo(tileData.occupant)
                                if info and info.uid and CharacterRE then
                                    pcall(function()
                                        CharacterRE:FireServer("Del", info.uid)
                                    end)
                                    task.wait(0.5)
                                    refreshGrid()
                                end
                            end
                        end)
                    end
                end
            end
        end
    end)
    
    -- Dragging functionality
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundTransparency = 1
    titleBar.Parent = MainFrame
    
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
    
    -- Placement Speed Slider Interaction
    local isDraggingSpeedSlider = false
    
    sidebarControls.speedSliderHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingSpeedSlider = true
        end
    end)
    
    sidebarControls.speedSliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingSpeedSlider = true
            local relativeX = (input.Position.X - sidebarControls.speedSliderBg.AbsolutePosition.X) / sidebarControls.speedSliderBg.AbsoluteSize.X
            relativeX = math.max(0, math.min(1, relativeX))
            placementSpeed = 1 + (relativeX * 9) -- Map 0-1 to 1-10
            
            sidebarControls.speedSliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
            sidebarControls.speedSliderHandle.Position = UDim2.new(relativeX, -8, 0, 25)
            sidebarControls.placementSpeedLabel.Text = "Place Speed: " .. string.format("%.1fs", placementSpeed)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and isDraggingSpeedSlider then
            local relativeX = (input.Position.X - sidebarControls.speedSliderBg.AbsolutePosition.X) / sidebarControls.speedSliderBg.AbsoluteSize.X
            relativeX = math.max(0, math.min(1, relativeX))
            placementSpeed = 1 + (relativeX * 9) -- Map 0-1 to 1-10
            
            sidebarControls.speedSliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
            sidebarControls.speedSliderHandle.Position = UDim2.new(relativeX, -8, 0, 25)
            sidebarControls.placementSpeedLabel.Text = "Place Speed: " .. string.format("%.1fs", placementSpeed)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingSpeedSlider = false
        end
    end)
    
    -- UI Scale Slider Interaction
    local isDraggingUIScaleSlider = false
    
    sidebarControls.uiScaleSliderHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingUIScaleSlider = true
        end
    end)
    
    sidebarControls.uiScaleSliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingUIScaleSlider = true
            local relativeX = (input.Position.X - sidebarControls.uiScaleSliderBg.AbsolutePosition.X) / sidebarControls.uiScaleSliderBg.AbsoluteSize.X
            relativeX = math.max(0, math.min(1, relativeX))
            local uiScaleValue = 0.5 + (relativeX * 0.7) -- Map 0-1 to 0.5-1.2
            
            uiScale.Scale = uiScaleValue
            sidebarControls.uiScaleSliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
            sidebarControls.uiScaleSliderHandle.Position = UDim2.new(relativeX, -8, 0, 25)
            sidebarControls.uiScaleLabel.Text = "UI Scale: " .. math.floor(uiScaleValue * 100) .. "%"
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and isDraggingUIScaleSlider then
            local relativeX = (input.Position.X - sidebarControls.uiScaleSliderBg.AbsolutePosition.X) / sidebarControls.uiScaleSliderBg.AbsoluteSize.X
            relativeX = math.max(0, math.min(1, relativeX))
            local uiScaleValue = 0.5 + (relativeX * 0.7) -- Map 0-1 to 0.5-1.2
            
            uiScale.Scale = uiScaleValue
            sidebarControls.uiScaleSliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
            sidebarControls.uiScaleSliderHandle.Position = UDim2.new(relativeX, -8, 0, 25)
            sidebarControls.uiScaleLabel.Text = "UI Scale: " .. math.floor(uiScaleValue * 100) .. "%"
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingUIScaleSlider = false
        end
    end)
    
    -- Initial load
    refreshGrid()
    updateSidebar()
    
    return ScreenGui
end

-- Public Functions
function AutoPlaceGridUI.Init(dependencies)
    AutoPlaceSystem = dependencies.AutoPlaceSystem
    WindUI = dependencies.WindUI
    return AutoPlaceGridUI
end

function AutoPlaceGridUI.Show()
    if not ScreenGui then
        AutoPlaceGridUI.CreateUI()
    end
    if MainFrame then
        MainFrame.Visible = true
    end
    refreshGrid()
    updateSidebar()
end

function AutoPlaceGridUI.Hide()
    -- Just hide the frame, keep auto place running in background
    if MainFrame then
        MainFrame.Visible = false
    end
    -- DON'T disconnect gridUpdateConnection - let it keep working!
end

function AutoPlaceGridUI.Toggle()
    if MainFrame and MainFrame.Visible then
        AutoPlaceGridUI.Hide()
    else
        AutoPlaceGridUI.Show()
    end
end

function AutoPlaceGridUI.IsVisible()
    return ScreenGui and ScreenGui.Enabled
end

return AutoPlaceGridUI

