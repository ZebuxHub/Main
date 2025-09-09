-- Build A Zoo: Auto Buy Egg using WindUI
repeat wait() until game:IsLoaded()

-- Load WindUI library (same as in Windui.lua)
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Add Custom Theme: DarkPurple
WindUI:AddTheme({
    Name = "DarkPurple",
    Accent = "#d32f2f",      -- deep purple for highlights
    Outline = "#ff5252",     -- soft lavender outline
    Text = "#f5f5f5",        -- light lavender text
    Placeholder = "#9e9e9e", -- muted purple for placeholders
    Background = "#121212",  -- near-black purple background
    Button = "#b71c1c",      -- vibrant purple button
    Icon = "#e53935",        -- lighter purple for icons
})

-- Set the theme to DarkPurple
WindUI:SetTheme("DarkPurple")

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local vector = { create = function(x, y, z) return Vector3.new(x, y, z) end }
local LocalPlayer = Players.LocalPlayer

-- Consolidated global state to reduce local variable count
_G.ZebuxState = {
    -- Selection state
    selectedTypeSet = {},
    selectedMutationSet = {},
    selectedMutationOrder = {},
    selectedFruits = {},
    selectedFeedFruits = {},
    settingsLoaded = true, -- Set to true initially to prevent infinite wait
    
    -- Mutation icons
    MutationIcons = {
        Golden = { ID = "Golden", Icon = "rbxassetid://12924452910" },
        Diamond = { ID = "Diamond", Icon = "rbxassetid://11937098975" },
        Electirc = { ID = "Electirc", Icon = "rbxassetid://16749221391" },
        Fire = { ID = "Fire", Icon = "rbxassetid://16633305205" },
        Jurassic = { ID = "Jurassic", Icon = "rbxassetid://93073511262401" }
    }
}

-- Shortcuts for commonly used variables
local selectedTypeSet = _G.ZebuxState.selectedTypeSet
local selectedMutationSet = _G.ZebuxState.selectedMutationSet
local selectedMutationOrder = _G.ZebuxState.selectedMutationOrder
local selectedFruits = _G.ZebuxState.selectedFruits
local selectedFeedFruits = _G.ZebuxState.selectedFeedFruits
local MutationIcons = _G.ZebuxState.MutationIcons
local function waitForSettingsReady(extraDelay)
    -- Initialize settingsLoaded if not set
    if _G.ZebuxState.settingsLoaded == nil then
        _G.ZebuxState.settingsLoaded = false
    end
    
    local maxWait = 0
    while not _G.ZebuxState.settingsLoaded and maxWait < 50 do -- Max 5 second wait
        task.wait(0.1)
        maxWait = maxWait + 1
    end
    
    if maxWait >= 50 then
        -- Settings timeout (proceeding anyway)
    end
    
    if extraDelay and extraDelay > 0 then
        task.wait(extraDelay)
    end
end
local autoFeedToggle

-- Forward declarations
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

-- Window
local Window = WindUI:CreateWindow({
    Title = "Build A Zoo",
    Icon = "app-window-mac",
    IconThemed = true,
    Author = "Zebux",
    Folder = "Zebux",
    Size = UDim2.fromOffset(520, 360),
    Transparent = true,
    Theme = "DarkPurple",
    -- No keysystem
})

local Tabs = {}
Tabs.MainSection = Window:Section({ Title = "Auto Helpers", Icon = "zap", Opened = true })
Tabs.MainTab = Tabs.MainSection:Tab({ Title = "Main", Icon = "tv"})
Tabs.PlaceTab = Tabs.MainSection:Tab({ Title = "Place Pets", Icon = "map-pin"})
Tabs.DeleteTab = Tabs.MainSection:Tab({ Title = "Auto Delete", Icon = "trash-2"})
Tabs.HatchTab = Tabs.MainSection:Tab({ Title = "Hatch Eggs", Icon = "zap"})
Tabs.ShopTab = Tabs.MainSection:Tab({ Title = "Shop", Icon = "shopping-cart"})
Tabs.FishTab = Tabs.MainSection:Tab({ Title = "Auto Fish", Icon = "anchor"})
    Tabs.PerfTab = Tabs.MainSection:Tab({ Title = "Performance", Icon = "activity" })
    Tabs.TrashTab = Tabs.MainSection:Tab({ Title = "Send Trash", Icon = "trash-2"})
    Tabs.WebhookTab = Tabs.MainSection:Tab({ Title = "Discord Webhook", Icon = "webhook"})
    Tabs.SaveTab = Tabs.MainSection:Tab({ Title = "Save Settings", Icon = "save"})

-- Load external Performance module (master toggle)
local Performance = nil
pcall(function()
    Performance = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/Performance.lua"))()
end)
if Performance and Performance.Init then
	pcall(function()
		Performance.Init({
			WindUI = WindUI,
			Tabs = Tabs,
		})
	end)
end

-- ============ Auto Sell System (external) ============
local AutoSellSystem = nil
pcall(function()
    AutoSellSystem = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/AutoSellSystem.lua"))()
end)
if AutoSellSystem and AutoSellSystem.Init then
    pcall(function()
        AutoSellSystem.Init({
            WindUI = WindUI,
            Tabs = Tabs,
            MainTab = Tabs.MainTab, -- Pass MainTab specifically for Auto Sell
            Config = autoSystemsConfig
        })
    end)
end

-- Function to load all saved settings before any function starts
local function loadAllSettings()
    -- Load WindUI config for simple UI elements
    if zebuxConfig then
        local loadSuccess, loadErr = pcall(function()
            zebuxConfig:Load()
        end)
        
        if not loadSuccess then
            warn("Failed to load WindUI config: " .. tostring(loadErr))
        end
    end
    
    -- Load auto claim delay specifically
    local delaySuccess, delayData = pcall(function()
        return loadJSONCustom("ClaimSettings.json")
    end)
    
    if delaySuccess and delayData and delayData.autoClaimDelay then
        autoClaimDelay = delayData.autoClaimDelay
    end
    
    -- Load custom selection variables from JSON files
    local success, data = pcall(function()
        return loadJSONCustom("EggSelections.json")
    end)
    
    if success and data then
        selectedTypeSet = {}
        if data.eggs then
            for _, eggId in ipairs(data.eggs) do
                selectedTypeSet[eggId] = true
            end
        end
        
        selectedMutationSet = {}
        selectedMutationOrder = {}
        if data.mutations then
            for _, mutationId in ipairs(data.mutations) do
                selectedMutationSet[mutationId] = true
            end
        end
        
        -- Load mutation order if available
        if data.mutationOrder then
            selectedMutationOrder = data.mutationOrder
        end
        
        -- Update priority display after loading
        task.spawn(function()
            task.wait(1) -- Wait for UI to be ready
            updateMutationPriorityDisplay()
        end)
    end
    
    -- Load fruit selections
    local fruitSuccess, fruitData = pcall(function()
        return loadJSONCustom("FruitSelections.json")
    end)
    
    if fruitSuccess and fruitData then
        selectedFruits = {}
        if fruitData.fruits then
            for _, fruitId in ipairs(fruitData.fruits) do
                selectedFruits[fruitId] = true
            end
        end
    end
    
    -- Load feed fruit selections
    local feedFruitSuccess, feedFruitData = pcall(function()
        return loadJSONCustom("FeedFruitSelections.json")
    end)
    
    if feedFruitSuccess and feedFruitData then
        selectedFeedFruits = {}
        if feedFruitData.fruits then
            for _, fruitId in ipairs(feedFruitData.fruits) do
                selectedFeedFruits[fruitId] = true
            end
        end
    end
    
    -- Note: Auto place selections are now handled by AutoPlaceSystem.lua
end

-- Function to save all settings (WindUI config + custom selections)
local function saveAllSettings()
    -- Save WindUI config for simple UI elements
    if zebuxConfig then
        local saveSuccess, saveErr = pcall(function()
            zebuxConfig:Save()
        end)
        
        if not saveSuccess then
            warn("Failed to save WindUI config: " .. tostring(saveErr))
        end
    end
    
    -- Save auto claim delay specifically
    pcall(function()
        local delayData = { autoClaimDelay = autoClaimDelay }
        saveJSONCustom("ClaimSettings.json", delayData)
    end)
    
    -- Save custom selection variables to JSON files
    local eggSelections = {
        eggs = {},
        mutations = {}
    }
    
    for eggId, _ in pairs(selectedTypeSet) do
        table.insert(eggSelections.eggs, eggId)
    end
    
    for mutationId, _ in pairs(selectedMutationSet) do
        table.insert(eggSelections.mutations, mutationId)
    end
    
    -- Note: Auto place selections are now handled by AutoPlaceSystem.lua
    
    pcall(function()
        saveJSONCustom("EggSelections.json", eggSelections)
    end)
    
    -- Save fruit selections
    local fruitSelections = {
        fruits = {}
    }
    
    for fruitId, _ in pairs(selectedFruits) do
        table.insert(fruitSelections.fruits, fruitId)
    end
    
    pcall(function()
        saveJSONCustom("FruitSelections.json", fruitSelections)
    end)
    
    -- Save feed fruit selections
    local feedFruitSelections = {
        fruits = {}
    }
    
    for fruitId, _ in pairs(selectedFeedFruits) do
        table.insert(feedFruitSelections.fruits, fruitId)
    end
    
    pcall(function()
        saveJSONCustom("FeedFruitSelections.json", feedFruitSelections)
    end)
end

-- Auto state variables (declared early so close handler can reference)
local autoClaimEnabled = false
local autoClaimThread = nil
local autoClaimDelay = 3.0
local autoFeedEnabled = false
local autoPlaceEnabled = false
local autoPlaceThread = nil
local autoHatchEnabled = false
local autoUnlockEnabled = false
local autoUnlockThread = nil
local antiAFKEnabled = false
local antiAFKConnection = nil
local autoHatchThread = nil
-- Priority system removed per user request

-- Egg config loader
local eggConfig = {}
local conveyorConfig = {}
local petFoodConfig = {}
local mutationConfig = {}

local function loadEggConfig()
    local ok, cfg = pcall(function()
        local cfgFolder = ReplicatedStorage:WaitForChild("Config")
        local module = cfgFolder:WaitForChild("ResEgg")
        return require(module)
    end)
    if ok and type(cfg) == "table" then
        eggConfig = cfg
    else
        eggConfig = {}
    end
end

local idToTypeMap = {}
local function loadConveyorConfig()
    local ok, cfg = pcall(function()
        local cfgFolder = ReplicatedStorage:WaitForChild("Config")
        local module = cfgFolder:WaitForChild("ResConveyor")
        return require(module)
    end)
    if ok and type(cfg) == "table" then
        conveyorConfig = cfg
    else
        conveyorConfig = {}
    end
end

local function loadPetFoodConfig()
    local ok, cfg = pcall(function()
        local cfgFolder = ReplicatedStorage:WaitForChild("Config")
        local module = cfgFolder:WaitForChild("ResPetFood")
        return require(module)
    end)
    if ok and type(cfg) == "table" then
        petFoodConfig = cfg
    else
        petFoodConfig = {}
    end
end

local function loadMutationConfig()
    local ok, cfg = pcall(function()
        local cfgFolder = ReplicatedStorage:WaitForChild("Config")
        local module = cfgFolder:WaitForChild("ResMutate")
        return require(module)
    end)
    if ok and type(cfg) == "table" then
        mutationConfig = cfg
    else
        mutationConfig = {}
    end
end
local function getTypeFromConfig(key, val)
    if type(val) == "table" then
        local t = val.Type or val.Name or val.type or val.name
        if t ~= nil then return tostring(t) end
    end
    return tostring(key)
end

local function buildEggIdList()
    idToTypeMap = {}
    local ids = {}
    for id, val in pairs(eggConfig) do
        local idStr = tostring(id)
        -- Filter out meta keys like _index, __index, and any leading underscore entries
        if not string.match(idStr, "^_%_?index$") and not string.match(idStr, "^__index$") and not idStr:match("^_") then
            table.insert(ids, idStr)
            idToTypeMap[idStr] = getTypeFromConfig(id, val)
        end
    end
    table.sort(ids)
    return ids
end

local function buildMutationList()
    local mutations = {}
    for id, val in pairs(mutationConfig) do
        local idStr = tostring(id)
        -- Filter out meta keys like _index, __index, and any leading underscore entries
        if not string.match(idStr, "^_%_?index$") and not string.match(idStr, "^__index$") and not idStr:match("^_") then
            local mutationName = val.Name or val.ID or val.Id or idStr
            mutationName = tostring(mutationName)
            
            table.insert(mutations, mutationName)
        end
    end
    table.sort(mutations)
    return mutations
end

-- UI helpers
local function tryCreateTextInput(parent, opts)
    -- Tries common method names to create a textbox-like input in WindUI
    local created
    for _, method in ipairs({"Textbox", "Input", "TextBox"}) do
        local ok, res = pcall(function()
            return parent[method](parent, opts)
        end)
        if ok and res then created = res break end
    end
    return created
end

-- Removed unused function caseInsensitiveContains

local function getEggPriceById(eggId)
    local entry = eggConfig[eggId] or eggConfig[tonumber(eggId)]
    if entry == nil then
        for key, value in pairs(eggConfig) do
            if tostring(key) == tostring(eggId) then
                entry = value
                break
            end
            if type(value) == "table" then
                if value.Id == eggId or tostring(value.Id) == tostring(eggId) or value.Name == eggId then
                    entry = value
                    break
                end
            end
        end
    end
    if type(entry) == "table" then
        local price = entry.Price or entry.price or entry.Cost or entry.cost
        if type(price) == "number" then return price end
        if type(entry.Base) == "table" and type(entry.Base.Price) == "number" then return entry.Base.Price end
    end
    return nil
end

local function getEggPriceByType(eggType)
    local target = tostring(eggType)
    for key, value in pairs(eggConfig) do
        if type(value) == "table" then
            local t = value.Type or value.Name or value.type or value.name or tostring(key)
            if tostring(t) == target then
                local price = value.Price or value.price or value.Cost or value.cost
                if type(price) == "number" then return price end
                if type(value.Base) == "table" and type(value.Base.Price) == "number" then return value.Base.Price end
            end
        else
            if tostring(key) == target then
                -- primitive mapping, try id-based
                local price = getEggPriceById(key)
                if type(price) == "number" then return price end
            end
        end
    end
    return nil
end

-- Player helpers
local function getAssignedIslandName()
    if not LocalPlayer then return nil end
    
    local success, islandName = pcall(function()
    return LocalPlayer:GetAttribute("AssignedIslandName")
    end)
    
    return success and islandName or nil
end

-- Function to read mutation from egg GUI
local function getEggMutation(eggUID)
    if not eggUID then return nil end
    
    local islandName = getAssignedIslandName()
    if not islandName then return nil end
    
    local art = workspace:FindFirstChild("Art")
    if not art then return nil end
    
    local island = art:FindFirstChild(islandName)
    if not island then return nil end
    
    local env = island:FindFirstChild("ENV")
    if not env then return nil end
    
    local conveyor = env:FindFirstChild("Conveyor")
    if not conveyor then return nil end
    
    -- Check all conveyor belts
    for i = 1, 9 do
        local conveyorBelt = conveyor:FindFirstChild("Conveyor" .. i)
        if conveyorBelt then
            local belt = conveyorBelt:FindFirstChild("Belt")
            if belt then
                local eggModel = belt:FindFirstChild(eggUID)
                if eggModel and eggModel:IsA("Model") then
                    local rootPart = eggModel:FindFirstChild("RootPart")
                    if rootPart then
                        local eggGUI = rootPart:FindFirstChild("GUI/EggGUI")
                        if eggGUI then
                            local mutateText = eggGUI:FindFirstChild("Mutate")
                            if mutateText and mutateText:IsA("TextLabel") then
                                local mutationText = mutateText.Text
                                if mutationText and mutationText ~= "" then
                                    -- Handle special case: if mutation is "Dino", return "Jurassic"
                                    if string.lower(mutationText) == "dino" then
                                        return "Jurassic"
                                    end
                                    return mutationText
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

-- Player helpers (getAssignedIslandName moved earlier to fix undefined global error)

local function getPlayerNetWorth()
    if not LocalPlayer then return 0 end
    local attrValue = LocalPlayer:GetAttribute("NetWorth")
    if type(attrValue) == "number" then return attrValue end
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local netWorthValue = leaderstats:FindFirstChild("NetWorth")
        if netWorthValue and type(netWorthValue.Value) == "number" then
            return netWorthValue.Value
        end
    end
    return 0
end

local function fireConveyorUpgrade(index)
    local args = { "Upgrade", tonumber(index) or index }
    local ok, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("ConveyorRE"):FireServer(table.unpack(args))
    end)
    if not ok then warn("Conveyor Upgrade fire failed: " .. tostring(err)) end
    return ok
end

-- World helpers
local function getIslandBelts(islandName)
    if type(islandName) ~= "string" or islandName == "" then return {} end
    local art = workspace:FindFirstChild("Art")
    if not art then return {} end
    local island = art:FindFirstChild(islandName)
    if not island then return {} end
    local env = island:FindFirstChild("ENV")
    if not env then return {} end
    local conveyorRoot = env:FindFirstChild("Conveyor")
    if not conveyorRoot then return {} end
    local belts = {}
    -- Strictly look for Conveyor1..Conveyor9 in order
    for i = 1, 9 do
        local c = conveyorRoot:FindFirstChild("Conveyor" .. i)
        if c then
            local b = c:FindFirstChild("Belt")
            if b then table.insert(belts, b) end
        end
    end
    return belts
end

-- Pick one "active" belt (with most eggs; tie -> nearest to player)
local function getActiveBelt(islandName)
    local belts = getIslandBelts(islandName)
    if #belts == 0 then return nil end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local hrpPos = hrp and hrp.Position or Vector3.new()
    local bestBelt, bestScore, bestDist
    for _, belt in ipairs(belts) do
        local children = belt:GetChildren()
        local eggs = 0
        local samplePos
        for _, ch in ipairs(children) do
            if ch:IsA("Model") then
                eggs += 1
                if not samplePos then
                    local ok, cf = pcall(function() return ch:GetPivot() end)
                    if ok and cf then samplePos = cf.Position end
                end
            end
        end
        if not samplePos then
            local p = belt.Parent and belt.Parent:FindFirstChildWhichIsA("BasePart", true)
            samplePos = p and p.Position or hrpPos
        end
        local dist = (samplePos - hrpPos).Magnitude
        -- Higher eggs preferred; for tie, closer belt preferred
        local score = eggs * 100000 - dist
        if not bestScore or score > bestScore then
            bestScore, bestDist, bestBelt = score, dist, belt
        end
    end
    return bestBelt
end

-- Auto Place helpers
local function getIslandNumberFromName(islandName)
    if not islandName then return nil end
    -- Extract number from island name (e.g., "Island_3" -> 3)
    local match = string.match(islandName, "Island_(%d+)")
    if match then
        return tonumber(match)
    end
    -- Try other patterns
    match = string.match(islandName, "(%d+)")
    if match then
        return tonumber(match)
    end
    return nil
end

-- Auto tile unlock system
local function getLockedTiles(islandNumber)
    if not islandNumber then return {} end
    local art = workspace:FindFirstChild("Art")
    if not art then return {} end
    
    local islandName = "Island_" .. tostring(islandNumber)
    local island = art:FindFirstChild(islandName)
    if not island then return {} end
    
    local env = island:FindFirstChild("ENV")
    if not env then return {} end
    
    local locksFolder = env:FindFirstChild("Locks")
    if not locksFolder then return {} end
    
    local lockedTiles = {}
    
    -- Scan for locks that start with 'F' (like F20, F30, etc.)
    for _, lockModel in ipairs(locksFolder:GetChildren()) do
        if lockModel:IsA("Model") and lockModel.Name:match("^F%d+") then
            local farmPart = lockModel:FindFirstChild("Farm")
            if farmPart and farmPart:IsA("BasePart") then
                -- Check if this lock is active (transparency = 0 means locked)
                if farmPart.Transparency == 0 then
                    local lockCost = farmPart:GetAttribute("LockCost")
                    table.insert(lockedTiles, {
                        modelName = lockModel.Name,
                        farmPart = farmPart,
                        cost = lockCost or 0,
                        model = lockModel
                    })
                end
            end
        end
    end
    
    return lockedTiles
end

-- Function to unlock a specific tile
local function unlockTile(lockInfo)
    if not lockInfo then 
        warn("❌ unlockTile: No lock info provided")
        return false 
    end
    
    if not lockInfo.farmPart then
        warn("❌ unlockTile: No farm part in lock info for " .. (lockInfo.modelName or "unknown"))
        return false
    end
    
    local args = {
        "Unlock",
        lockInfo.farmPart
    }
    
    local success, errorMsg = pcall(function()
        local remote = ReplicatedStorage:WaitForChild("Remote", 5)
        if not remote then
            error("Remote folder not found")
        end
        
        local characterRE = remote:WaitForChild("CharacterRE", 5)
        if not characterRE then
            error("CharacterRE not found")
        end
        
        characterRE:FireServer(unpack(args))
    end)
    
    if success then
        -- Silent success
    else
        warn("❌ Failed to unlock tile " .. (lockInfo.modelName or "unknown") .. ": " .. tostring(errorMsg))
    end
    
    return success
end

-- Ocean egg categories for water farm placement
local OCEAN_EGGS = {
    ["SeaweedEgg"] = true,
    ["ClownfishEgg"] = true,
    ["LionfishEgg"] = true,
    ["SharkEgg"] = true,
    ["AnglerfishEgg"] = true,
    ["OctopusEgg"] = true,
    ["SeaDragonEgg"] = true
}

-- Check if an egg type requires water farm placement
local function isOceanEgg(eggType)
    return OCEAN_EGGS[eggType] == true
end

-- Function to auto unlock tiles when needed
local function autoUnlockTilesIfNeeded(islandNumber, eggType)
    -- Input validation
    if not islandNumber then 
        warn("autoUnlockTilesIfNeeded: No island number provided")
        return false 
    end
    if not eggType then 
        warn("autoUnlockTilesIfNeeded: No egg type provided")
        return false 
    end
    
    -- Check if we have available tiles first
    local farmParts
    local isOceanEggType = false
    
    -- Safe check for ocean egg type
    local success, result = pcall(function()
        return isOceanEgg(eggType)
    end)
    
    if success then
        isOceanEggType = result
    else
        warn("autoUnlockTilesIfNeeded: Error checking ocean egg type: " .. tostring(result))
        isOceanEggType = false
    end
    
    -- Get farm parts safely
    local farmPartsSuccess, farmPartsResult = pcall(function()
        if isOceanEggType then
            return getWaterFarmParts(islandNumber)
        else
            return getFarmParts(islandNumber)
        end
    end)
    
    if farmPartsSuccess then
        farmParts = farmPartsResult or {}
    else
        warn("autoUnlockTilesIfNeeded: Error getting farm parts: " .. tostring(farmPartsResult))
        return false
    end
    
    -- Count available (unlocked and unoccupied) tiles
    local availableCount = 0
    for _, part in ipairs(farmParts) do
        local isOccupied = false
        local checkSuccess, checkResult = pcall(function()
            return isFarmTileOccupied(part, 6)
        end)
        
        if checkSuccess then
            isOccupied = checkResult
        else
            warn("autoUnlockTilesIfNeeded: Error checking tile occupation: " .. tostring(checkResult))
            isOccupied = true -- Assume occupied if we can't check
        end
        
        if not isOccupied then
            availableCount = availableCount + 1
        end
    end
    
    -- If we have less than 3 available tiles, try to unlock more
    if availableCount < 3 then
        local lockedTiles = {}
        local lockedTilesSuccess, lockedTilesResult = pcall(function()
            return getLockedTiles(islandNumber)
        end)
        
        if lockedTilesSuccess then
            lockedTiles = lockedTilesResult or {}
        else
            warn("autoUnlockTilesIfNeeded: Error getting locked tiles: " .. tostring(lockedTilesResult))
            return false
        end
        
        if #lockedTiles > 0 then
            -- For ocean eggs, we need to be more careful about which tiles to unlock
            -- because water farms and regular farms are in different locked areas
            
            -- Sort by cost (cheapest first) with error handling
            local sortSuccess, sortError = pcall(function()
                table.sort(lockedTiles, function(a, b)
                    return (a.cost or 0) < (b.cost or 0)
                end)
            end)
            
            if not sortSuccess then
                warn("autoUnlockTilesIfNeeded: Error sorting locked tiles: " .. tostring(sortError))
            end
            
            -- Try to unlock the cheapest tiles
            local unlockedCount = 0
            for _, lockInfo in ipairs(lockedTiles) do
                if unlockedCount >= 2 then break end -- Don't unlock too many at once
                
                local unlockSuccess, unlockError = pcall(function()
                    return unlockTile(lockInfo)
                end)
                
                if unlockSuccess and unlockError then
                    unlockedCount = unlockedCount + 1
                    task.wait(0.5) -- Wait between unlocks
                elseif not unlockSuccess then
                    warn("autoUnlockTilesIfNeeded: Error unlocking tile: " .. tostring(unlockError))
                end
            end
            
            if unlockedCount > 0 then
                task.wait(1) -- Wait for server to process unlocks
                return true
            end
        end
    end
    
    return false
end

local function getWaterFarmParts(islandNumber)
    if not islandNumber then return {} end
    local art = workspace:FindFirstChild("Art")
    if not art then return {} end
    
    local islandName = "Island_" .. tostring(islandNumber)
    local island = art:FindFirstChild(islandName)
    if not island then 
        -- Try alternative naming patterns
        for _, child in ipairs(art:GetChildren()) do
            if child.Name:match("^Island[_-]?" .. tostring(islandNumber) .. "$") then
                island = child
                break
            end
        end
        if not island then return {} end
    end
    
    local waterFarmParts = {}
    local function scanForWaterFarmParts(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("BasePart") and child.Name == "WaterFarm_split_0_0_0" then
                -- Additional validation: check if part is valid for placement
                if child.Size == Vector3.new(8, 8, 8) and child.CanCollide then
                    table.insert(waterFarmParts, child)
                end
            end
            scanForWaterFarmParts(child)
        end
    end
    
    scanForWaterFarmParts(island)
    
    -- Filter out locked water farm tiles by checking the Locks folder
    local unlockedWaterFarmParts = {}
    local env = island:FindFirstChild("ENV")
    local locksFolder = env and env:FindFirstChild("Locks")
    
    if locksFolder then
        -- Create a map of locked areas using position checking
        local lockedAreas = {}
        for _, lockModel in ipairs(locksFolder:GetChildren()) do
            if lockModel:IsA("Model") and lockModel.Name:match("^F%d+") then
                local farmPart = lockModel:FindFirstChild("Farm")
                if farmPart and farmPart:IsA("BasePart") then
                    -- Check if this lock is active (transparency = 0 means locked)
                    if farmPart.Transparency == 0 then
                        -- Store the lock's position and size for area checking
                        table.insert(lockedAreas, {
                            position = farmPart.Position,
                            size = farmPart.Size
                        })
                    end
                end
            end
        end
        
        -- Check each water farm part against locked areas
        for i, waterFarmPart in ipairs(waterFarmParts) do
            local isLocked = false
            
            for _, lockArea in ipairs(lockedAreas) do
                -- Check if water farm part is within the lock area
                local waterFarmPos = waterFarmPart.Position
                local lockCenter = lockArea.position
                local lockSize = lockArea.size
                
                -- Calculate the bounds of the lock area
                local lockHalfSize = lockSize / 2
                local lockMinX = lockCenter.X - lockHalfSize.X
                local lockMaxX = lockCenter.X + lockHalfSize.X
                local lockMinZ = lockCenter.Z - lockHalfSize.Z
                local lockMaxZ = lockCenter.Z + lockHalfSize.Z
                
                -- Check if water farm part is within the lock bounds
                if waterFarmPos.X >= lockMinX and waterFarmPos.X <= lockMaxX and
                   waterFarmPos.Z >= lockMinZ and waterFarmPos.Z <= lockMaxZ then
                    isLocked = true
                    break
                end
            end
            
            if not isLocked then
                table.insert(unlockedWaterFarmParts, waterFarmPart)
            end
        end
    else
        -- If no locks folder found, assume all water farm tiles are unlocked
        unlockedWaterFarmParts = waterFarmParts
    end
    
    return unlockedWaterFarmParts
end

local function getFarmParts(islandNumber)
    if not islandNumber then return {} end
    local art = workspace:FindFirstChild("Art")
    if not art then return {} end
    
    local islandName = "Island_" .. tostring(islandNumber)
    local island = art:FindFirstChild(islandName)
    if not island then 
        -- Try alternative naming patterns
        for _, child in ipairs(art:GetChildren()) do
            if child.Name:match("^Island[_-]?" .. tostring(islandNumber) .. "$") then
                island = child
                break
            end
        end
        if not island then return {} end
    end
    
    local farmParts = {}
    local function scanForFarmParts(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("BasePart") and child.Name:match("^Farm_split_%d+_%d+_%d+$") then
                -- Additional validation: check if part is valid for placement
                if child.Size == Vector3.new(8, 8, 8) and child.CanCollide then
                    table.insert(farmParts, child)
                end
            end
            scanForFarmParts(child)
        end
    end
    
    scanForFarmParts(island)
    
    -- Filter out locked tiles by checking the Locks folder
    local unlockedFarmParts = {}
    local env = island:FindFirstChild("ENV")
    local locksFolder = env and env:FindFirstChild("Locks")
    
    if locksFolder then
        -- Create a map of locked areas using CFrame and size
        local lockedAreas = {}
        for _, lockModel in ipairs(locksFolder:GetChildren()) do
            if lockModel:IsA("Model") then
                local farmPart = lockModel:FindFirstChild("Farm")
                if farmPart and farmPart:IsA("BasePart") then
                    -- Check if this lock is active (transparency = 0 means locked)
                    if farmPart.Transparency == 0 then
                        -- Store the lock's CFrame and size for area checking
                        table.insert(lockedAreas, {
                            cframe = farmPart.CFrame,
                            size = farmPart.Size,
                            position = farmPart.Position
                        })
                    end
                end
            end
        end
        
        -- Check each farm part against locked areas
        for _, farmPart in ipairs(farmParts) do
            local isLocked = false
            
            for _, lockArea in ipairs(lockedAreas) do
                -- Check if farm part is within the lock area
                -- Use CFrame and size to determine if the farm part is covered by the lock
                local farmPartPos = farmPart.Position
                local lockCenter = lockArea.position
                local lockSize = lockArea.size
                
                -- Calculate the bounds of the lock area
                local lockHalfSize = lockSize / 2
                local lockMinX = lockCenter.X - lockHalfSize.X
                local lockMaxX = lockCenter.X + lockHalfSize.X
                local lockMinZ = lockCenter.Z - lockHalfSize.Z
                local lockMaxZ = lockCenter.Z + lockHalfSize.Z
                
                -- Check if farm part is within the lock bounds
                if farmPartPos.X >= lockMinX and farmPartPos.X <= lockMaxX and
                   farmPartPos.Z >= lockMinZ and farmPartPos.Z <= lockMaxZ then
                    isLocked = true
                    break
                end
            end
            
            if not isLocked then
                table.insert(unlockedFarmParts, farmPart)
            end
        end
    else
        -- If no locks folder found, assume all tiles are unlocked
        unlockedFarmParts = farmParts
    end
    
    return unlockedFarmParts
end

-- Occupancy helpers (uses Model:GetPivot to detect nearby placed pets)
local function isPetLikeModel(model)
    if not model or not model:IsA("Model") then return false end
    -- Common signals that a model is a pet or a placed unit
    if model:FindFirstChildOfClass("Humanoid") then return true end
    if model:FindFirstChild("AnimationController") then return true end
    if model:GetAttribute("IsPet") or model:GetAttribute("PetType") or model:GetAttribute("T") then return true end
    local lowerName = string.lower(model.Name)
    if string.find(lowerName, "pet") or string.find(lowerName, "egg") then return true end
    if CollectionService and (CollectionService:HasTag(model, "Pet") or CollectionService:HasTag(model, "IdleBigPet")) then
        return true
    end
    return false
end

local function getTileCenterPosition(farmPart)
    if not farmPart or not farmPart.IsA or not farmPart:IsA("BasePart") then return nil end
    -- Middle of the farm tile (parts are 8x8x8)
    return farmPart.Position
end

local function getPetModelsOverlappingTile(farmPart)
    if not farmPart or not farmPart:IsA("BasePart") then return {} end
    local centerCF = farmPart.CFrame
    -- Slightly taller box to capture pets above the tile
    local regionSize = Vector3.new(8, 14, 8)
    local params = OverlapParams.new()
    params.RespectCanCollide = false
    -- Search within whole workspace, we will filter to models
    local parts = workspace:GetPartBoundsInBox(centerCF, regionSize, params)
    local modelMap = {}
    for _, part in ipairs(parts) do
        if part ~= farmPart then
            local model = part:FindFirstAncestorOfClass("Model")
            if model and not modelMap[model] and isPetLikeModel(model) then
                modelMap[model] = true
            end
        end
    end
    local models = {}
    for model in pairs(modelMap) do table.insert(models, model) end
    return models
end

-- Get all pet configurations that the player owns
local function getPlayerPetConfigurations()
    local petConfigs = {}
    
    if not LocalPlayer then return petConfigs end
    
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return petConfigs end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return petConfigs end
    
    local petsFolder = data:FindFirstChild("Pets")
    if not petsFolder then return petConfigs end
    
    -- Get all pet configurations
    for _, petConfig in ipairs(petsFolder:GetChildren()) do
        if petConfig:IsA("Configuration") then
            table.insert(petConfigs, {
                name = petConfig.Name,
                config = petConfig
            })
        end
    end
    
    return petConfigs
end

-- Check if a pet exists in workspace.Pets by configuration name
local function findPetInWorkspace(petConfigName)
    local workspacePets = workspace:FindFirstChild("Pets")
    if not workspacePets then return nil end
    
    local petModel = workspacePets:FindFirstChild(petConfigName)
    if petModel and petModel:IsA("Model") then
        return petModel
    end
    
    return nil
end

-- Get all player's pets that exist in workspace
local function getPlayerPetsInWorkspace()
    local petsInWorkspace = {}
    local playerPets = getPlayerPetConfigurations()
    local workspacePets = workspace:FindFirstChild("Pets")
    
    if not workspacePets then return petsInWorkspace end
    
    for _, petConfig in ipairs(playerPets) do
        local petModel = workspacePets:FindFirstChild(petConfig.name)
        if petModel and petModel:IsA("Model") then
            table.insert(petsInWorkspace, {
                name = petConfig.name,
                model = petModel,
                position = petModel:GetPivot().Position
            })
        end
    end
    
    return petsInWorkspace
end

-- Check if a farm tile is occupied by pets or eggs
local function isFarmTileOccupied(farmPart, minDistance)
    minDistance = minDistance or 6
    local center = getTileCenterPosition(farmPart)
    if not center then return true end
    
    -- Calculate surface position (same as placement logic)
    local surfacePosition = Vector3.new(
        center.X,
        center.Y + 12, -- Eggs float 12 studs above tile surface
        center.Z
    )
    
    -- Check for water farm tiles
    local isWaterFarm = farmPart.Name == "WaterFarm_split_0_0_0"
    
    -- Check for pets in PlayerBuiltBlocks (eggs/hatching pets)
    local models = getPetModelsOverlappingTile(farmPart)
    if #models > 0 then
        for i, model in ipairs(models) do
            local pivotPos = model:GetPivot().Position
            local distance = (pivotPos - surfacePosition).Magnitude
            -- Check distance to surface position instead of center
            if distance <= minDistance then
                return true
            end
        end
    end
    
    -- Check for fully hatched pets in workspace.Pets
    local playerPets = getPlayerPetsInWorkspace()
    for i, petInfo in ipairs(playerPets) do
        local petPos = petInfo.position
        local distance = (petPos - surfacePosition).Magnitude
        -- Check distance to surface position instead of center
        if distance <= minDistance then
            return true
        end
    end
    
    return false
end

local function findAvailableFarmPart(farmParts, minDistance)
    if not farmParts or #farmParts == 0 then return nil end
    
    -- First, collect all available parts
    local availableParts = {}
    for _, part in ipairs(farmParts) do
        if not isFarmTileOccupied(part, minDistance) then
            table.insert(availableParts, part)
        end
    end
    
    -- If no available parts, return nil
    if #availableParts == 0 then return nil end
    
    -- Shuffle available parts to distribute placement
    for i = #availableParts, 2, -1 do
        local j = math.random(1, i)
        availableParts[i], availableParts[j] = availableParts[j], availableParts[i]
    end
    
    return availableParts[1]
end

-- Player helpers for proximity-based placement
local function getPlayerRootPosition()
    local character = LocalPlayer and LocalPlayer.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    return hrp.Position
end

local function findAvailableFarmPartNearPosition(farmParts, minDistance, targetPosition)
    if not targetPosition then return findAvailableFarmPart(farmParts, minDistance) end
    if not farmParts or #farmParts == 0 then return nil end
    -- Sort farm parts by distance to targetPosition and pick first unoccupied
    local sorted = table.clone(farmParts)
    table.sort(sorted, function(a, b)
        return (a.Position - targetPosition).Magnitude < (b.Position - targetPosition).Magnitude
    end)
    for _, part in ipairs(sorted) do
        if not isFarmTileOccupied(part, minDistance) then
            return part
        end
    end
    return nil
end

-- Helper function to check if a specific tile position is unlocked
local function isTileUnlocked(islandName, tilePosition)
    if not islandName or not tilePosition then return false end
    
    local art = workspace:FindFirstChild("Art")
    if not art then return true end -- Assume unlocked if no Art folder
    
    local island = art:FindFirstChild(islandName)
    if not island then return true end -- Assume unlocked if island not found
    
    local locksFolder = island:FindFirstChild("ENV"):FindFirstChild("Locks")
    if not locksFolder then return true end -- Assume unlocked if no locks folder
    
    -- Check if there's a lock covering this position
    for _, lockModel in ipairs(locksFolder:GetChildren()) do
        if lockModel:IsA("Model") then
            local farmPart = lockModel:FindFirstChild("Farm")
            if farmPart and farmPart:IsA("BasePart") and farmPart.Transparency == 0 then
                -- Check if tile position is within the lock area
                local lockCenter = farmPart.Position
                local lockSize = farmPart.Size
                
                -- Calculate the bounds of the lock area
                local lockHalfSize = lockSize / 2
                local lockMinX = lockCenter.X - lockHalfSize.X
                local lockMaxX = lockCenter.X + lockHalfSize.X
                local lockMinZ = lockCenter.Z - lockHalfSize.Z
                local lockMaxZ = lockCenter.Z + lockHalfSize.Z
                
                -- Check if tile position is within the lock bounds
                if tilePosition.X >= lockMinX and tilePosition.X <= lockMaxX and
                   tilePosition.Z >= lockMinZ and tilePosition.Z <= lockMaxZ then
                    return false -- This tile is locked
                end
            end
        end
    end
    
    return true -- Tile is unlocked
end




local function getPetUID()
    if not LocalPlayer then return nil end
    
    -- Wait for PlayerGui to exist
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        -- Try to wait for it briefly
        playerGui = LocalPlayer:WaitForChild("PlayerGui", 2)
        if not playerGui then return nil end
    end
    
    -- Wait for Data folder to exist
    local data = playerGui:FindFirstChild("Data")
    if not data then
        data = playerGui:WaitForChild("Data", 2)
        if not data then return nil end
    end
    
    -- Wait for Egg object to exist
    local egg = data:FindFirstChild("Egg")
    if not egg then
        egg = data:WaitForChild("Egg", 2)
        if not egg then return nil end
    end
    
    -- The PET UID is the NAME of the egg object, not its Value
    local eggName = egg.Name
    if not eggName or eggName == "" then
        return nil
    end
    
    return eggName
end

-- Available Egg helpers (Auto Place)
local function getEggContainer()
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = pg and pg:FindFirstChild("Data")
    return data and data:FindFirstChild("Egg") or nil
end

-- Function to read mutation from egg configuration (for Auto Place)
local function getEggMutation(eggUID)
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return nil end
    
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return nil end
    
    local eggContainer = data:FindFirstChild("Egg")
    if not eggContainer then return nil end
    
    local eggConfig = eggContainer:FindFirstChild(eggUID)
    if not eggConfig then return nil end
    
    -- Read the M attribute (mutation)
    local mutation = eggConfig:GetAttribute("M")
    
    -- Map "Dino" to "Jurassic" for consistency
    if mutation == "Dino" then
        mutation = "Jurassic"
    end
    
    return mutation
end

-- Enhanced function to read mutation from GUI text on conveyor belt (for Auto Buy)
local function getEggMutationFromGUI(eggUID)
    local islandName = getAssignedIslandName()
    if not islandName then 
        warn("getEggMutationFromGUI: No island name found")
        return nil 
    end
    
    local art = workspace:FindFirstChild("Art")
    if not art then 
        warn("getEggMutationFromGUI: Art folder not found")
        return nil 
    end
    
    local island = art:FindFirstChild(islandName)
    if not island then 
        warn("getEggMutationFromGUI: Island " .. islandName .. " not found")
        return nil 
    end
    
    local env = island:FindFirstChild("ENV")
    if not env then 
        warn("getEggMutationFromGUI: ENV folder not found")
        return nil 
    end
    
    local conveyor = env:FindFirstChild("Conveyor")
    if not conveyor then 
        warn("getEggMutationFromGUI: Conveyor folder not found")
        return nil 
    end
    
    -- Check all conveyor belts
    for i = 1, 9 do
        local conveyorBelt = conveyor:FindFirstChild("Conveyor" .. i)
        if conveyorBelt then
            local belt = conveyorBelt:FindFirstChild("Belt")
            if belt then
                local eggModel = belt:FindFirstChild(eggUID)
                if eggModel and eggModel:IsA("Model") then
                    local rootPart = eggModel:FindFirstChild("RootPart")
                    if rootPart then
                        -- Try multiple GUI path patterns
                        local guiPaths = {
                            "GUI/EggGUI",
                            "EggGUI", 
                            "GUI",
                            "BillboardGui"
                        }
                        
                        for _, guiPath in ipairs(guiPaths) do
                            local eggGUI = rootPart:FindFirstChild(guiPath)
                        if eggGUI then
                                -- Try multiple mutation text label names
                                local mutationLabels = {"Mutate", "Mutation", "MutateText", "MutationLabel"}
                                
                                for _, labelName in ipairs(mutationLabels) do
                                    local mutateText = eggGUI:FindFirstChild(labelName)
                            if mutateText and mutateText:IsA("TextLabel") then
                                local mutationText = mutateText.Text
                                        if mutationText and mutationText ~= "" and mutationText ~= "None" then
                                            -- Normalize mutation text
                                            mutationText = string.gsub(mutationText, "^%s*(.-)%s*$", "%1") -- trim whitespace
                                            
                                            -- Map variations to standard names
                                            local lowerText = string.lower(mutationText)
                                            if lowerText == "dino" or lowerText == "Dino" then
                                        return "Jurassic"
                                            elseif lowerText == "golden" or lowerText == "gold" then
                                                return "Golden"
                                            elseif lowerText == "diamond" or lowerText == "💎" then
                                                return "Diamond"
                                            elseif lowerText == "electric" or lowerText == "⚡" or lowerText == "electirc" then
                                                return "Electric"
                                            elseif lowerText == "fire" or lowerText == "🔥" then
                                                return "Fire"
                                            elseif lowerText == "jurassic" or lowerText == "🦕" then
                                                return "Jurassic"
                                            else
                                                -- Return the original text if no mapping found
                                    return mutationText
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

local function listAvailableEggUIDs()
    local eg = getEggContainer()
    local uids = {}
    if not eg then return uids end
    for _, child in ipairs(eg:GetChildren()) do
        if #child:GetChildren() == 0 then -- no subfolder => available
            -- Get the actual egg type from T attribute
            local eggType = child:GetAttribute("T")
            if eggType then
                -- Get the mutation from M attribute
                local mutation = getEggMutation(child.Name)
                table.insert(uids, { 
                    uid = child.Name, 
                    type = eggType,
                    mutation = mutation
                })
            else
                table.insert(uids, { 
                    uid = child.Name, 
                    type = child.Name,
                    mutation = nil
                })
            end
        end
    end
    return uids
end

-- Enhanced pet validation based on the Pet module
local function validatePetUID(petUID)
    if not petUID or type(petUID) ~= "string" or petUID == "" then
        return false, "Invalid PET UID"
    end
    
    -- Check if pet exists in ReplicatedStorage.Pets (based on Pet module patterns)
    local petsFolder = ReplicatedStorage:FindFirstChild("Pets")
    if petsFolder then
        -- The Pet module shows pets are stored by their type (T attribute)
        -- We might need to validate the pet type exists
        return true, "Valid PET UID"
    end
    
    return true, "PET UID found (pets folder not accessible)"
end

-- Get pet information for better status display
local function getPetInfo(petUID)
    if not petUID then return nil end
    
    -- Try to get pet data from various sources
    local petData = {
        UID = petUID,
        Type = nil,
        Rarity = nil,
        Level = nil,
        Mutations = nil
    }
    
    -- Check if we can get pet type from the UID
    -- This might be stored in the player's data or we might need to parse it
    if type(petUID) == "string" then
        -- Some games store pet type in the UID itself
        petData.Type = petUID
    end
    
    return petData
end

-- ============ Auto Claim Money ============
-- Variables moved to top of file

local function getOwnedPetNames()
    local names = {}
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = playerGui and playerGui:FindFirstChild("Data")
    local petsContainer = data and data:FindFirstChild("Pets")
    if petsContainer then
        for _, child in ipairs(petsContainer:GetChildren()) do
            -- Assume children under Data.Pets are ValueBase instances or folders named as pet names
            local n
            if child:IsA("ValueBase") then
                n = tostring(child.Value)
            else
                n = tostring(child.Name)
            end
            if n and n ~= "" then
                table.insert(names, n)
            end
        end
    end
    return names
end

local function claimMoneyForPet(petName)
    if not petName or petName == "" then return false end
    local petsFolder = workspace:FindFirstChild("Pets")
    if not petsFolder then return false end
    local petModel = petsFolder:FindFirstChild(petName)
    if not petModel then return false end
    local root = petModel:FindFirstChild("RootPart")
    if not root then return false end
    local re = root:FindFirstChild("RE")
    if not re or not re.FireServer then return false end
    local ok, err = pcall(function()
        re:FireServer("Claim")
    end)
    if not ok then warn("Claim failed for pet " .. tostring(petName) .. ": " .. tostring(err)) end
    return ok
end

local function runAutoClaim()
    while autoClaimEnabled do
        local ok, err = pcall(function()
            local names = getOwnedPetNames()
            if #names == 0 then task.wait(0.8) return end
            for _, n in ipairs(names) do
                claimMoneyForPet(n)
                task.wait(autoClaimDelay or 3.0) -- Use 3 seconds as default
            end
        end)
        if not ok then
            warn("Auto Claim error: " .. tostring(err))
            task.wait(1)
        end
    end
end

-- Auto buy toggle and stats moved here to be after egg selection

-- Money Management moved below Egg Management section

-- Auto Hatch functionality moved below Egg Management section

-- Direct hatch (no walking, no ProximityPrompt) - fires RF remote directly
local hatchInFlightByUid = {}

local function getOwnerUserIdDeep(inst)
    local current = inst
    while current and current ~= workspace do
        if current.GetAttribute then
            local uidAttr = current:GetAttribute("UserId")
            if type(uidAttr) == "number" then return uidAttr end
            if type(uidAttr) == "string" then
                local n = tonumber(uidAttr)
                if n then return n end
            end
        end
        current = current.Parent
    end
    return nil
end

local function playerOwnsInstance(inst)
    if not inst then return false end
    local ownerId = getOwnerUserIdDeep(inst)
    local lp = Players.LocalPlayer
    return ownerId ~= nil and lp and lp.UserId == ownerId
end

local function isOwnedEggModel(model)
    if not model or not model:IsA("Model") then return false end
    local ownerId = getOwnerUserIdDeep(model)
    local lp = Players.LocalPlayer
    if ownerId == nil or not lp or lp.UserId ~= ownerId then return false end
    local rootPart = model:FindFirstChild("RootPart")
    if not rootPart then return false end
    local hasRF = rootPart:FindFirstChild("RF") ~= nil
    return hasRF
end

local function hatchEggDirectly(eggUID)
    if hatchInFlightByUid[eggUID] then return false end
    hatchInFlightByUid[eggUID] = true
    
    task.spawn(function()
        local success = pcall(function()
            local eggModel = workspace.PlayerBuiltBlocks:FindFirstChild(eggUID)
            if eggModel and eggModel:FindFirstChild("RootPart") and eggModel.RootPart:FindFirstChild("RF") then
                local args = {"Hatch"}
                eggModel.RootPart.RF:InvokeServer(unpack(args))
            end
        end)
        
        if not success then
            warn("Failed to hatch egg:", eggUID)
        end
        
        task.delay(2, function()
            hatchInFlightByUid[eggUID] = nil
        end)
    end)
    
    return true
end

local function collectOwnedEggs()
    local owned = {}
    local container = workspace:FindFirstChild("PlayerBuiltBlocks")
    if not container then return owned end
    
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Model") and playerOwnsInstance(child) then
            -- Check if it has RF (indicating it's an egg)
            local rootPart = child:FindFirstChild("RootPart")
            if rootPart and rootPart:FindFirstChild("RF") then
                table.insert(owned, child)
            end
        end
    end
    
    return owned
end

local function getModelPosition(model)
    if not model or not model.GetPivot then return nil end
    local ok, cf = pcall(function() return model:GetPivot() end)
    if ok and cf then return cf.Position end
    local pp = model.PrimaryPart or model:FindFirstChild("RootPart")
    return pp and pp.Position or nil
end

local function runAutoHatch()
    while autoHatchEnabled do
        local ok, err = pcall(function()
            local owned = collectOwnedEggs()
            if #owned == 0 then 
                task.wait(1.0) 
                return 
            end
            
            for _, eggModel in ipairs(owned) do
                if isOwnedEggModel(eggModel) then
                    hatchEggDirectly(eggModel.Name)
                    task.wait(0.1) -- Small delay between hatches
                end
            end
            
            task.wait(2.0) -- Wait before next scan
        end)
        if not ok then
            warn("Auto Hatch error: " .. tostring(err))
            task.wait(1)
        end
    end
end


local function placePetAtPart(farmPart, petUID)
    if not farmPart or not petUID then return false end
    
    -- Enhanced validation based on Pet module insights
    if not farmPart:IsA("BasePart") then return false end
    
    local isValid, validationMsg = validatePetUID(petUID)
    if not isValid then
        warn("Pet validation failed: " .. validationMsg)
        return false
    end
    
    -- Place pet on surface (top of the farm split tile)
    local surfacePosition = Vector3.new(
        farmPart.Position.X,
        farmPart.Position.Y + (farmPart.Size.Y / 2), -- Top surface
        farmPart.Position.Z
    )
    
    local args = {
        "Place",
        {
            DST = vector.create(surfacePosition.X, surfacePosition.Y, surfacePosition.Z),
            ID = petUID
        }
    }
    
    local ok, err = pcall(function()
        local remote = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE")
        if remote then
            remote:FireServer(unpack(args))
        else
            error("CharacterRE remote not found")
        end
    end)
    
    if not ok then
        warn("Failed to fire Place for PET UID " .. tostring(petUID) .. " at " .. tostring(surfacePosition) .. ": " .. tostring(err))
        return false
    end
    
    return true
end

-- Hardcoded Egg and Mutation Data
local EggData = {
    BasicEgg = { Name = "Basic Egg", Price = "100", Icon = "rbxassetid://129248801621928", Rarity = 1 },
    RareEgg = { Name = "Rare Egg", Price = "500", Icon = "rbxassetid://71012831091414", Rarity = 2 },
    SuperRareEgg = { Name = "Super Rare Egg", Price = "2,500", Icon = "rbxassetid://93845452154351", Rarity = 2 },
    EpicEgg = { Name = "Epic Egg", Price = "15,000", Icon = "rbxassetid://116395645531721", Rarity = 2 },
    LegendEgg = { Name = "Legend Egg", Price = "100,000", Icon = "rbxassetid://90834918351014", Rarity = 3 },
    PrismaticEgg = { Name = "Prismatic Egg", Price = "1,000,000", Icon = "rbxassetid://79960683434582", Rarity = 4 },
    HyperEgg = { Name = "Hyper Egg", Price = "2,500,000", Icon = "rbxassetid://104958288296273", Rarity = 4 },
    VoidEgg = { Name = "Void Egg", Price = "24,000,000", Icon = "rbxassetid://122396162708984", Rarity = 5 },
    BowserEgg = { Name = "Bowser Egg", Price = "130,000,000", Icon = "rbxassetid://71500536051510", Rarity = 5 },
    DemonEgg = { Name = "Demon Egg", Price = "400,000,000", Icon = "rbxassetid://126412407639969", Rarity = 5 },
    CornEgg = { Name = "Corn Egg", Price = "1,000,000,000", Icon = "rbxassetid://94739512852461", Rarity = 5 },
    BoneDragonEgg = { Name = "Bone Dragon Egg", Price = "2,000,000,000", Icon = "rbxassetid://83209913424562", Rarity = 5 },
    UltraEgg = { Name = "Ultra Egg", Price = "10,000,000,000", Icon = "rbxassetid://83909590718799", Rarity = 6 },
    DinoEgg = { Name = "Dino Egg", Price = "10,000,000,000", Icon = "rbxassetid://80783528632315", Rarity = 6 },
    FlyEgg = { Name = "Fly Egg", Price = "999,999,999,999", Icon = "rbxassetid://109240587278187", Rarity = 6 },
    UnicornEgg = { Name = "Unicorn Egg", Price = "40,000,000,000", Icon = "rbxassetid://123427249205445", Rarity = 6 },
    AncientEgg = { Name = "Ancient Egg", Price = "999,999,999,999", Icon = "rbxassetid://113910587565739", Rarity = 6 }
}

local MutationData = {
    Golden = { Name = "Golden", Icon = "✨", Rarity = 10 },
    Diamond = { Name = "Diamond", Icon = "💎", Rarity = 20 },
    Electirc = { Name = "Electric", Icon = "⚡", Rarity = 50 },
    Fire = { Name = "Fire", Icon = "🔥", Rarity = 100 },
    Jurassic = { Name = "Jurassic", Icon = "🦕", Rarity = 100 }
}

-- Load UI modules
local EggSelection = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/EggSelection.lua"))()
local FruitSelection = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/FruitSelection.lua"))()
local FeedFruitSelection = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/FeedFruitSelection.lua"))()
local AutoFeedSystem = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/AutoFeedSystem.lua"))()
-- Load Auto Fish System (GitHub only)
local AutoFishSystem = nil
task.spawn(function()
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/AutoFishSystem.lua"))()
    end)
    if success and result then
        AutoFishSystem = result
        
        -- Wait for required dependencies to be available
        local maxWaitTime = 10 -- Wait up to 10 seconds
        local waitTime = 0
        while (not WindUI or not Tabs or not Tabs.FishTab) and waitTime < maxWaitTime do
            task.wait(0.1)
            waitTime = waitTime + 0.1
        end
        
        if AutoFishSystem and AutoFishSystem.Init and Tabs.FishTab then
            -- Initialize AutoFish system after a short delay to ensure all dependencies are ready
            task.spawn(function()
                task.wait(2) -- Wait for other systems to initialize
                
            local initSuccess, initErr = pcall(function()
                    local initResult = AutoFishSystem.Init({
                    WindUI = WindUI,
                        FishTab = Tabs.FishTab,
                        ConfigManager = zebuxConfig
                    })
                    
                    if initResult then
                        print("[AutoFish] System initialized successfully")
                        
                        -- Register with config system after initialization
                        task.spawn(function()
                            task.wait(1) -- Wait for config system to be ready
                            if AutoFishSystem.GetConfigElements then
                                local fishElements = AutoFishSystem.GetConfigElements()
                                if fishElements.autoFishToggleElement and fishElements.autoFishBaitElement then
                                    print("[AutoFish] Config elements ready for registration")
                                end
                            end
                        end)
                    else
                        warn("[AutoFish] Init returned false")
                    end
            end)
            
            if not initSuccess then
                warn("Failed to initialize Auto Fish System: " .. tostring(initErr))
                -- Try initializing without config as fallback
                pcall(function()
                    AutoFishSystem.Init({
                        WindUI = WindUI,
                            FishTab = Tabs.FishTab,
                            ConfigManager = nil
                    })
                        print("[AutoFish] System initialized without config (fallback)")
                end)
            end
            end)
        else
            warn("[AutoFish] Missing dependencies - WindUI:", not not WindUI, "FishTab:", not not (Tabs and Tabs.FishTab))
        end
    else
        warn("Failed to load Auto Fish System from GitHub: " .. tostring(result))
    end
end)
-- FruitStoreSystem functions are now implemented locally in the auto buy fruit section
local SendTrashSystem = nil

-- UI state
local eggSelectionVisible = false
local fruitSelectionVisible = false
local feedFruitSelectionVisible = false




-- ============ Main Tab - Egg Management & Money ============
Tabs.MainTab:Section({ Title = "Egg Management", Icon = "package" })

Tabs.MainTab:Button({
    Title = "Open Egg Selection UI",
    Desc = "Select eggs and mutations to buy",
    Callback = function()
        if not eggSelectionVisible then
            EggSelection.Show(
                function(selectedItems, selectionOrder)
                    -- Handle selection changes with order tracking
            selectedTypeSet = {}
                    selectedMutationSet = {}
                    selectedMutationOrder = {}
                    
                    if selectedItems then
                        for itemId, isSelected in pairs(selectedItems) do
                            if isSelected then
                                -- Check if it's an egg or mutation
                                if EggData[itemId] then
                                    selectedTypeSet[itemId] = true
                                elseif MutationData[itemId] then
                                    selectedMutationSet[itemId] = true
                end
            end
                        end
                    end
                    
                    -- Track mutation selection order for priority
                    if selectionOrder then
                        local mutationOrderIndex = 1
                        for _, itemId in ipairs(selectionOrder) do
                            if selectedMutationSet[itemId] then
                                selectedMutationOrder[itemId] = mutationOrderIndex
                                mutationOrderIndex = mutationOrderIndex + 1
            end
                        end
                    end
                    
                    -- Auto-save the selections
                    updateCustomUISelection("eggSelections", {
                        eggs = selectedTypeSet,
                        mutations = selectedMutationSet,
                        mutationOrder = selectedMutationOrder
                    })
                end,
                function(isVisible)
                    eggSelectionVisible = isVisible
                end,
                selectedTypeSet, -- Pass saved egg selections
                selectedMutationSet, -- Pass saved mutation selections
                selectedMutationOrder -- Pass saved mutation order
            )
            eggSelectionVisible = true
        else
            EggSelection.Hide()
            eggSelectionVisible = false
        end
    end
})

-- Enhanced auto buy statistics with per-mutation tracking
local autoBuyStats = {
    totalAttempts = 0,
    successfulBuys = 0,
    mutationFinds = 0,
    lastMutationFound = nil,
    lastMutationTime = 0,
    mutationStats = {}, -- Track each mutation type separately
    sessionStart = os.time()
}

-- Auto buy statistics removed per user request

-- Auto buy statistics function removed per user request

-- Auto Buy Helper Functions (moved here to fix scope issues)
local beltConnections = {}
local lastBeltChildren = {}

-- Forward declarations to fix scope issues
local buyEggInstantly
local shouldBuyEggInstance

local function cleanupBeltConnections()
    for _, conn in ipairs(beltConnections) do
        pcall(function() conn:Disconnect() end)
    end
    beltConnections = {}
end

-- Enhanced belt monitoring with smart prioritization
local function setupBeltMonitoring(belt)
    if not belt then return end
    
    -- Monitor for new eggs appearing (immediate priority)
    local function onChildAdded(child)
        if not autoBuyEnabled then return end
        if child:IsA("Model") then
            task.spawn(function()
                task.wait(0.1) -- Small delay to ensure attributes are set
                buyEggInstantly(child)
            end)
        end
    end
    
    -- Enhanced egg checking with multi-mutation support
    local function checkExistingEggs()
        if not autoBuyEnabled then return end
        local children = belt:GetChildren()
        local candidates = {}
        local mutationCandidates = {} -- Separate tracking for mutations
        
        -- First pass: collect all valid eggs with their priority
        for _, child in ipairs(children) do
            if child:IsA("Model") then
                local netWorth = getPlayerNetWorth()
                local ok, uid, price, reason, priorityScore, mutation = shouldBuyEggInstance(child, netWorth)
                
                if ok then
                    local candidate = {
                        instance = child,
                        uid = uid,
                        price = price,
                        priority = priorityScore or 0,
                        mutation = mutation
                    }
                    
                    table.insert(candidates, candidate)
                    
                    -- Track mutation eggs separately for better handling
                    if mutation then
                        if not mutationCandidates[mutation] then
                            mutationCandidates[mutation] = {}
                        end
                        table.insert(mutationCandidates[mutation], candidate)
                    end
                end
            end
        end
        
        -- Sort by priority (mutations first, then by score)
        table.sort(candidates, function(a, b)
            return a.priority > b.priority
        end)
        
        -- Enhanced buying logic for multiple mutations
        if #candidates > 0 then
            local playerMoney = getPlayerNetWorth()
            local boughtCount = 0
            local maxSimultaneousBuys = 3 -- Limit concurrent purchases
            
            -- Try to buy multiple eggs if we have enough money and different mutations
            for i, candidate in ipairs(candidates) do
                if boughtCount >= maxSimultaneousBuys then break end
                
                -- Re-check if we still have enough money
                local currentMoney = getPlayerNetWorth()
                if currentMoney >= candidate.price then
                    -- Buy in separate thread to allow concurrent purchases
                    task.spawn(function()
                        buyEggInstantly(candidate.instance)
                    end)
                    boughtCount = boughtCount + 1
                    
                    -- Small delay between purchases to avoid conflicts
                    task.wait(0.05)
                else
                    break -- Not enough money for remaining eggs
                end
            end
        end
    end
    
    -- Connect events
    table.insert(beltConnections, belt.ChildAdded:Connect(onChildAdded))
    
    -- Enhanced periodic checking with adaptive timing
    local checkThread = task.spawn(function()
        while autoBuyEnabled do
            checkExistingEggs()
            
            -- Adaptive timing: faster when mutations are selected
            local checkInterval = 0.5
            if selectedMutationSet and next(selectedMutationSet) then
                checkInterval = 0.3 -- Faster checking for mutations
            end
            
            task.wait(checkInterval)
        end
    end)
    
    -- Store thread for cleanup
    beltConnections[#beltConnections + 1] = { disconnect = function() 
        if checkThread then
            task.cancel(checkThread)
            checkThread = nil 
        end
    end }
end

-- Auto Buy Function Definition (moved here to fix scope issue)
local function runAutoBuy()
    while autoBuyEnabled do
        local islandName = getAssignedIslandName()
        
        if not islandName or islandName == "" then
            task.wait(5) -- Wait when no island
        else
            local activeBelt = getActiveBelt(islandName)
            if not activeBelt then
                task.wait(5) -- Wait when no belt
            else
                -- Setup monitoring for this belt
                cleanupBeltConnections()
                setupBeltMonitoring(activeBelt)
                
                -- Wait until disabled or island changes
                while autoBuyEnabled do
                    local currentIsland = getAssignedIslandName()
                    if currentIsland ~= islandName then
                        break -- Island changed, restart monitoring
                    end
                    task.wait(0.5)
                end
            end
        end
    end
    
    cleanupBeltConnections()
end

local autoBuyToggle = Tabs.MainTab:Toggle({
    Title = "Auto Buy Eggs",
    Desc = "Buy selected eggs with smart mutation priority",
    Value = false,
    Callback = function(state)
        autoBuyEnabled = state
        
        waitForSettingsReady(0.2)
        if state and not autoBuyThread then
            autoBuyThread = task.spawn(function()
                local success, error = pcall(function()
                    runAutoBuy()
                end)
                if not success then
                    WindUI:Notify({ Title = "Auto Buy Error", Content = "Error: " .. tostring(error), Duration = 5 })
                end
                autoBuyThread = nil
            end)
            
            -- Stats update loop removed
            
            WindUI:Notify({ Title = "Auto Buy", Content = "Enhanced system started! 🎉", Duration = 3 })
        elseif (not state) and autoBuyThread then
            cleanupBeltConnections()
            WindUI:Notify({ Title = "Auto Buy", Content = "Stopped", Duration = 3 })
        end
    end
})

-- ============ Auto Get Money ============
local autoClaimToggle = Tabs.MainTab:Toggle({
    Title = "Auto Get Money",
    Desc = "Collect money from pets every 3 seconds",
    Value = false,
    Callback = function(state)
        autoClaimEnabled = state
        autoClaimDelay = 3 -- Fixed 3 second delay
        
        waitForSettingsReady(0.2)
        if state and not autoClaimThread then
            autoClaimThread = task.spawn(function()
                runAutoClaim()
                autoClaimThread = nil
            end)
            WindUI:Notify({ Title = "Auto Claim", Content = "Started collecting money every 3 seconds! 🎉", Duration = 3 })
        elseif (not state) and autoClaimThread then
            WindUI:Notify({ Title = "Auto Claim", Content = "Stopped", Duration = 3 })
        end
    end
})

-- ============ Auto Hatch Eggs ============
local autoHatchToggle = Tabs.MainTab:Toggle({
    Title = "⚡ Auto Hatch Eggs",
    Desc = "Hatch eggs instantly (no walking required)",
    Value = false,
    Callback = function(state)
        autoHatchEnabled = state
        
        waitForSettingsReady(0.2)
        if state and not autoHatchThread then
            autoHatchThread = task.spawn(function()
                runAutoHatch()
                autoHatchThread = nil
            end)
            WindUI:Notify({ Title = "⚡ Auto Hatch", Content = "Started hatching eggs! 🎉", Duration = 3 })
        elseif (not state) and autoHatchThread then
            WindUI:Notify({ Title = "⚡ Auto Hatch", Content = "Stopped", Duration = 3 })
        end
    end
})

local autoBuyEnabled = false
local autoBuyThread = nil

-- Auto Feed variables
local autoFeedEnabled = false
local autoFeedThread = nil

-- Webhook system reference
local WebhookSystem = nil

-- Webhook UI variables
local webhookUrl = ""
local autoAlertEnabled = false
local webhookUrlInput = nil
local webhookAutoAlertToggle = nil













-- Enhanced function to determine if we should buy an egg (with better accuracy)
shouldBuyEggInstance = function(eggInstance, playerMoney)
    if not eggInstance or not eggInstance:IsA("Model") then return false, nil, nil, "Invalid egg instance" end
    
    -- Read Type first - check if this is the egg type we want
    local eggType = eggInstance:GetAttribute("Type")
        or eggInstance:GetAttribute("EggType")
        or eggInstance:GetAttribute("Name")
    if not eggType then return false, nil, nil, "No egg type found" end
    eggType = tostring(eggType)
    
    -- If specific eggs are selected, check if this is the type we want
    if selectedTypeSet and next(selectedTypeSet) then
        if not selectedTypeSet[eggType] then 
            return false, nil, nil, "Egg type not selected: " .. eggType 
        end
    end
    
    -- Enhanced mutation checking with better accuracy
    local eggMutation = nil
    if selectedMutationSet and next(selectedMutationSet) then
        -- Try multiple methods to get mutation
        eggMutation = getEggMutationFromGUI(eggInstance.Name)
        
        -- If GUI method failed, try attribute method
        if not eggMutation then
            eggMutation = getEggMutation(eggInstance.Name)
        end
        
        -- If still no mutation but mutations are required, skip
        if not eggMutation then
            return false, nil, nil, "No mutation found but mutations required"
        end
        
        -- Check if egg has a selected mutation
        if not selectedMutationSet[eggMutation] then
            return false, nil, nil, "Mutation not selected: " .. eggMutation
        end
    end

    -- Enhanced price detection with multiple fallbacks
    local price = nil
    
    -- Method 1: Try hardcoded data first
    if EggData[eggType] then
        local priceStr = EggData[eggType].Price:gsub(",", "")
        price = tonumber(priceStr)
    end
    
    -- Method 2: Try instance attributes
    if not price then
        price = eggInstance:GetAttribute("Price") or getEggPriceByType(eggType)
    end
    
    -- Method 3: Try reading from GUI
    if not price then
        local rootPart = eggInstance:FindFirstChild("RootPart")
        if rootPart then
            local guiPaths = {"GUI/EggGUI", "EggGUI", "GUI", "Gui"}
            for _, guiPath in ipairs(guiPaths) do
                local eggGUI = rootPart:FindFirstChild(guiPath)
                if eggGUI then
                    local priceLabels = {"Price", "PriceLabel", "Cost", "CostLabel"}
                    for _, labelName in ipairs(priceLabels) do
                        local priceLabel = eggGUI:FindFirstChild(labelName)
                        if priceLabel and priceLabel:IsA("TextLabel") then
                            local priceText = priceLabel.Text
                            -- Enhanced price parsing - handle K, M, B suffixes
                            local numStr = priceText:gsub("[^%d%.KMBkmb]", "")
                            if numStr ~= "" then
                                -- Parse number with suffix inline (to avoid global function)
                                local num = tonumber(numStr:match("([%d%.]+)"))
                                if num then
                                    local suffix = numStr:match("[KMBkmb]")
                                    if suffix then
                                        if suffix:lower() == "k" then num = num * 1000
                                        elseif suffix:lower() == "m" then num = num * 1000000
                                        elseif suffix:lower() == "b" then num = num * 1000000000
                                        end
                                    end
                                    price = num
                                    if price then break end
                                end
                            end
                        end
                    end
                    if price then break end
                end
            end
        end
    end
    
    if type(price) ~= "number" or price <= 0 then 
        return false, nil, nil, "Invalid price: " .. tostring(price) 
    end
    if playerMoney < price then 
        return false, nil, nil, "Insufficient funds: need " .. price .. ", have " .. playerMoney 
    end
    
    -- Calculate priority score (higher = better)
    local priorityScore = 0
    
    -- Dynamic mutation priority system based on user selection order
    if eggMutation then
        priorityScore = priorityScore + 1000
        
        -- Priority based on user selection order (first selected = highest priority)
        local orderBonus = 0
        if selectedMutationOrder and selectedMutationOrder[eggMutation] then
            local orderPosition = selectedMutationOrder[eggMutation]
            -- First selected gets 1000 bonus, second gets 800, third gets 600, etc.
            orderBonus = math.max(100, 1200 - (orderPosition * 200))
        else
            -- Default bonus for mutations not in user selection (lowest priority)
            orderBonus = 50
        end
        
        priorityScore = priorityScore + orderBonus
        
        -- Extra bonus if this mutation is rare (less common in selectedMutationSet)
        local selectedMutationCount = 0
        if selectedMutationSet then
            for _ in pairs(selectedMutationSet) do
                selectedMutationCount = selectedMutationCount + 1
            end
        end
        
        -- If only 1-2 mutations selected, give higher priority
        if selectedMutationCount <= 2 then
            priorityScore = priorityScore + 200
        elseif selectedMutationCount <= 4 then
            priorityScore = priorityScore + 100
        end
    end
    
    -- Enhanced price consideration with better scaling
    local priceBonus = 0
    if price < 10000 then
        priceBonus = 500 -- Very cheap eggs get high bonus
    elseif price < 100000 then
        priceBonus = 300
    elseif price < 1000000 then
        priceBonus = 100
    else
        priceBonus = math.max(0, (10000000 - price) / 10000) -- Diminishing returns for expensive eggs
    end
    priorityScore = priorityScore + priceBonus
    
    return true, eggInstance.Name, price, "Valid", priorityScore, eggMutation
end

local function buyEggByUID(eggUID)
    local args = {
        "BuyEgg",
        eggUID
    }
    local ok, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    if not ok then
        warn("Failed to fire BuyEgg for UID " .. tostring(eggUID) .. ": " .. tostring(err))
    end
end

local function focusEggByUID(eggUID)
    local args = {
        "Focus",
        eggUID
    }
    local ok, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    if not ok then
        warn("Failed to fire Focus for UID " .. tostring(eggUID) .. ": " .. tostring(err))
    end
end

-- Enhanced Event-driven Auto Buy system
-- beltConnections and lastBeltChildren moved earlier to fix scope issues
local buyingInProgress = false
local buyQueue = {} -- Queue for managing multiple simultaneous purchases
local lastPurchaseTime = 0
local purchaseCooldown = 0.1 -- Minimum time between purchases

-- cleanupBeltConnections moved earlier to fix scope issue

-- Removed duplicate function - using the one with mutation logic above

-- Enhanced auto buy statistics with per-mutation tracking
local autoBuyStats = {
    totalAttempts = 0,
    successfulBuys = 0,
    mutationFinds = 0,
    lastMutationFound = nil,
    lastMutationTime = 0,
    mutationStats = {}, -- Track each mutation type separately
    sessionStart = os.time()
}

buyEggInstantly = function(eggInstance)
    -- Check cooldown to prevent spam purchases
    local currentTime = tick()
    if currentTime - lastPurchaseTime < purchaseCooldown then
        return -- Skip if too soon
    end
    
    if buyingInProgress then return end
    buyingInProgress = true
    lastPurchaseTime = currentTime
    
    local netWorth = getPlayerNetWorth()
    local ok, uid, price, reason, priorityScore, mutation = shouldBuyEggInstance(eggInstance, netWorth)
    
    autoBuyStats.totalAttempts = autoBuyStats.totalAttempts + 1
    
    if ok then
        -- Local helpers to confirm real purchase (avoid false positives)
        local function getAvailableEggCountInner()
            local eg = getEggContainer()
            if not eg then return 0 end
            local c = 0
            for _, child in ipairs(eg:GetChildren()) do
                if #child:GetChildren() == 0 then
                    c += 1
                end
            end
            return c
        end
        local function waitForPurchaseConfirmation(preCount, preNet, expectedPrice, timeout)
            local deadline = tick() + (timeout or 2)
            while tick() < deadline do
                local currentCount = getAvailableEggCountInner()
                local currNet = getPlayerNetWorth()
                
                if currentCount > preCount then return true end
                if type(expectedPrice) == "number" and currNet <= preNet - math.max(1, expectedPrice * 0.95) then
                    return true
                end
                task.wait(0.15)
            end
            return false
        end
        
        -- Check if player has enough money first
        if netWorth < price then
            -- Wait until player has enough money
            while autoBuyEnabled do
                local currentNetWorth = getPlayerNetWorth()
                if currentNetWorth >= price then
                    break
                end
                task.wait(1) -- Check every second
            end
            
            -- Re-check if auto buy is still enabled after waiting
            if not autoBuyEnabled then
                buyingInProgress = false
                return
            end
            
            -- Update netWorth after waiting
            netWorth = getPlayerNetWorth()
        end
        
        -- Enhanced retry mechanism with better timing
        local maxRetries = 5 -- Increased retries for important eggs
        local retryCount = 0
        local buySuccess = false
        
        while retryCount < maxRetries and not buySuccess do
            retryCount = retryCount + 1
            
            -- Check if egg still exists and is still valid
            if not eggInstance or not eggInstance.Parent then
                break
            end
            
            -- Re-validate egg before buying (mutation/price might have changed)
            local currentNetWorth = getPlayerNetWorth()
            local stillOk, stillUid, stillPrice, stillReason, stillPriority, stillMutation = shouldBuyEggInstance(eggInstance, currentNetWorth)
            
            if not stillOk then
                -- If it's just a money issue, wait a bit more
                if stillReason and stillReason:find("Insufficient funds") then
                    task.wait(2)
                    -- continue replaced with empty block (Roblox Lua doesn't support continue)
                else
                    break
                end
            end
            
            -- Try to buy with error handling
            local beforeCount = getAvailableEggCountInner()
            local beforeNet = getPlayerNetWorth()
            local sendOk = pcall(function()
                buyEggByUID(stillUid or uid)
                focusEggByUID(stillUid or uid)
            end)
            
            local confirmed = false
            if sendOk then
                confirmed = waitForPurchaseConfirmation(beforeCount, beforeNet, stillPrice, 3.0)
            end
            
            if confirmed then
                autoBuyStats.successfulBuys = autoBuyStats.successfulBuys + 1
                buySuccess = true
                
                -- Count and notify mutations only on confirmed purchases
                if stillMutation then
                    autoBuyStats.mutationFinds = autoBuyStats.mutationFinds + 1
                    autoBuyStats.lastMutationFound = stillMutation
                    autoBuyStats.lastMutationTime = os.time()
                    
                    -- Track per-mutation statistics
                    if not autoBuyStats.mutationStats[stillMutation] then
                        autoBuyStats.mutationStats[stillMutation] = {
                            count = 0,
                            totalSpent = 0,
                            lastBought = 0,
                            avgPrice = 0
                        }
                    end
                    
                    local mutStat = autoBuyStats.mutationStats[stillMutation]
                    mutStat.count = mutStat.count + 1
                    mutStat.totalSpent = mutStat.totalSpent + (stillPrice or price)
                    mutStat.lastBought = os.time()
                    mutStat.avgPrice = mutStat.totalSpent / mutStat.count
                    
                    -- Use mutation icon if available, otherwise use default
                    local mutationIcon = "🦄"
                    if MutationIcons[stillMutation] then
                        mutationIcon = "💎" -- Placeholder since we can't use image IDs in notifications
                    end
                    
                    WindUI:Notify({ 
                        Title = mutationIcon .. " " .. stillMutation .. " Found!", 
                        Content = "Bought " .. stillMutation .. " egg for " .. formatNumber(stillPrice) .. "! (Total: " .. mutStat.count .. ")", 
                        Duration = 4 
                    })
                end
            else
                -- Not confirmed (likely insufficient funds or server denied); do not notify
                local delayTime = stillMutation and 1.0 or 0.3
                task.wait(delayTime)
            end
        end
        
        -- Retry completed
    else
        -- Egg not suitable for purchase
    end
    
    buyingInProgress = false
end

-- setupBeltMonitoring moved earlier to fix scope issue

-- runAutoBuy function moved earlier to fix scope issue



-- Auto Feed Functions moved to AutoFeedSystem.lua

-- ============ Revamped Auto Place System ============
-- Load the new auto place system
local AutoPlaceSystem = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/AutoPlaceSystem.lua"))()

-- Initialize the new auto place system
local function initAutoPlaceSystem()
    if AutoPlaceSystem and AutoPlaceSystem.Init then
        local success, err = pcall(function()
            AutoPlaceSystem.Init({
                WindUI = WindUI,
                Tabs = Tabs,
                Config = zebuxConfig or nil
            })
        end)
        
        if not success then
            warn("Failed to initialize Auto Place System: " .. tostring(err))
        end
    else
        warn("Auto Place System module failed to load")
    end
end

-- Tile Management moved to AutoPlaceSystem.lua

-- Initialize after a brief delay to ensure dependencies are ready
task.spawn(function()
    task.wait(1)
    initAutoPlaceSystem()
end)

-- Note: Legacy Auto Place system removed - now handled by AutoPlaceSystem.lua




-- Function to get egg options
local function getEggOptions()
    local eggOptions = {}
    
    -- Try to get from ResEgg config first
    local eggConfig = loadEggConfig()
    if eggConfig then
        for id, data in pairs(eggConfig) do
            if type(id) == "string" and not id:match("^_") and id ~= "_index" and id ~= "__index" then
                local eggName = data.Type or data.Name or id
                table.insert(eggOptions, eggName)
            end
        end
    end
    
    -- Fallback: get from PlayerBuiltBlocks
    if #eggOptions == 0 then
        local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
        if playerBuiltBlocks then
            for _, egg in ipairs(playerBuiltBlocks:GetChildren()) do
                if egg:IsA("Model") then
                    local eggType = egg:GetAttribute("Type") or egg:GetAttribute("EggType") or egg:GetAttribute("Name")
                    if eggType and not table.find(eggOptions, eggType) then
                        table.insert(eggOptions, eggType)
                    end
                end
            end
        end
    end
    
    table.sort(eggOptions)
    return eggOptions
end

-- Note: Egg and Mutation dropdowns are now handled by AutoPlaceSystem.lua

-- Note: Dropdown sync is now handled by AutoPlaceSystem.lua


-- Note: updateAvailableEggs() is now handled by AutoPlaceSystem.lua

-- Performance optimization cache
local tileCache = {
    lastUpdate = 0,
    updateInterval = 3, -- Cache for 3 seconds
    data = {},
    eggType = nil
}

-- Function to invalidate cache when significant changes occur
local function invalidateTileCache()
    tileCache.lastUpdate = 0
    tileCache.data = {}
    tileCache.eggType = nil
end

-- Enhanced tile scanning system with intelligent caching for performance
local function scanAllTilesAndModels(eggType)
    -- Check cache first to avoid expensive operations
    local currentTime = tick()
    if currentTime - tileCache.lastUpdate < tileCache.updateInterval and 
       tileCache.eggType == eggType and 
       tileCache.data and next(tileCache.data) then
        -- Return cached data
        return tileCache.data.tileMap, tileCache.data.totalTiles, 
               tileCache.data.occupiedTiles, tileCache.data.lockedTiles
    end
    
    local islandName = getAssignedIslandName()
    local islandNumber = getIslandNumberFromName(islandName)
    
    -- Get appropriate farm parts based on egg type
    local farmParts
    if eggType and isOceanEgg(eggType) then
        farmParts = getWaterFarmParts(islandNumber)
    else
        farmParts = getFarmParts(islandNumber)
    end
    
    local tileMap = {}
    local totalTiles = #farmParts
    local occupiedTiles = 0
    local lockedTiles = 0
    
    -- Initialize all tiles as available
    for i, part in ipairs(farmParts) do
        local surfacePos = Vector3.new(
            part.Position.X,
            part.Position.Y + 12, -- Eggs float 12 studs above tile surface
            part.Position.Z
        )
        tileMap[surfacePos] = {
            part = part,
            index = i,
            available = true,
            occupiedBy = nil,
            distance = 0
        }
    end
    
    -- Scan all floating models in PlayerBuiltBlocks
        local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
        if playerBuiltBlocks then
            for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
                if model:IsA("Model") then
                    local modelPos = model:GetPivot().Position
                
                -- Find which tile this model occupies
                for surfacePos, tileInfo in pairs(tileMap) do
                    if tileInfo.available then
                        -- Calculate distance to surface position
                        local xzDistance = math.sqrt((modelPos.X - surfacePos.X)^2 + (modelPos.Z - surfacePos.Z)^2)
                        local yDistance = math.abs(modelPos.Y - surfacePos.Y)
                        
                        -- If model is within placement range (more generous to avoid missing)
                        if xzDistance < 4.0 and yDistance < 20.0 then
                            tileInfo.available = false
                            tileInfo.occupiedBy = "egg"
                            tileInfo.distance = xzDistance
                        occupiedTiles = occupiedTiles + 1
                            break -- This tile is occupied, move to next model
                        end
                    end
                    end
                end
            end
        end
        
    -- Scan all pets in workspace.Pets
    local playerPets = getPlayerPetsInWorkspace()
    for _, petInfo in ipairs(playerPets) do
        local petPos = petInfo.position
        
        -- Find which tile this pet occupies
        for surfacePos, tileInfo in pairs(tileMap) do
            if tileInfo.available then
                -- Calculate distance to surface position
                local xzDistance = math.sqrt((petPos.X - surfacePos.X)^2 + (petPos.Z - surfacePos.Z)^2)
                local yDistance = math.abs(petPos.Y - surfacePos.Y)
                
                -- If pet is within placement range (more generous to avoid missing)
                if xzDistance < 4.0 and yDistance < 20.0 then
                    tileInfo.available = false
                    tileInfo.occupiedBy = "pet"
                    tileInfo.distance = xzDistance
                    occupiedTiles = occupiedTiles + 1
                    break -- This tile is occupied, move to next pet
                end
            end
        end
    end
    
    -- Count locked tiles
    local art = workspace:FindFirstChild("Art")
    if art then
        local island = art:FindFirstChild(islandName)
        if island then
            local env = island:FindFirstChild("ENV")
            local locksFolder = env and env:FindFirstChild("Locks")
            if locksFolder then
                for _, lockModel in ipairs(locksFolder:GetChildren()) do
                    if lockModel:IsA("Model") then
                        local farmPart = lockModel:FindFirstChild("Farm")
                        if farmPart and farmPart:IsA("BasePart") and farmPart.Transparency == 0 then
                            lockedTiles = lockedTiles + 1
                        end
                    end
                end
            end
        end
    end
    
    -- Cache the results for better performance
    tileCache.data = {
        tileMap = tileMap,
        totalTiles = totalTiles,
        occupiedTiles = occupiedTiles,
        lockedTiles = lockedTiles
    }
    tileCache.lastUpdate = currentTime
    tileCache.eggType = eggType
    
    return tileMap, totalTiles, occupiedTiles, lockedTiles
end

local function updateAvailableTiles(eggType)
    local tileMap, totalTiles, occupiedTiles, lockedTiles = scanAllTilesAndModels(eggType)
    
    availableTiles = {}
    
    -- Collect all available tiles
    for surfacePos, tileInfo in pairs(tileMap) do
        if tileInfo.available then
            table.insert(availableTiles, { 
                part = tileInfo.part, 
                index = tileInfo.index,
                surfacePos = surfacePos
            })
        end
    end
    
    -- Status updates removed
    
    -- Status update removed
end


-- Place status format function removed per user request

-- Place status update function removed per user request

-- Check and remember which tiles are taken
-- Count actual placed pets in PlayerBuiltBlocks
local function countPlacedPets()
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    local count = 0
    if playerBuiltBlocks then
        for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
            if model:IsA("Model") then
                local userId = model:GetAttribute("UserId")
                if userId and tonumber(userId) == Players.LocalPlayer.UserId then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- Event-driven placement system
local function cleanupPlaceConnections()
    for _, conn in ipairs(placeConnections) do
        pcall(function() conn:Disconnect() end)
    end
    placeConnections = {}
end




local function placeEggInstantly(eggInfo, tileInfo)
    if placingInProgress then return false end
    placingInProgress = true
    
    local petUID = eggInfo.uid
    local tilePart = tileInfo.part
    
    -- Final check: is tile still available?
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    if playerBuiltBlocks then
        for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
            if model:IsA("Model") then
                local modelPos = model:GetPivot().Position
                local tilePos = tilePart.Position
                
                -- Calculate surface position (same as placement logic)
                local surfacePos = Vector3.new(
                    tilePos.X,
                    tilePos.Y + (tilePart.Size.Y / 2), -- Top surface
                    tilePos.Z
                )
                
                -- Separate X/Z and Y axis checks
                local xzDistance = math.sqrt((modelPos.X - surfacePos.X)^2 + (modelPos.Z - surfacePos.Z)^2)
                local yDistance = math.abs(modelPos.Y - surfacePos.Y)
                
                -- X/Z: 4 studs radius, Y: 8 studs radius
                if xzDistance < 4.0 and yDistance < 8.0 then
                    placingInProgress = false
                    return false
                end
            end
        end
    end
    
    -- Check for fully hatched pets in workspace.Pets
    local playerPets = getPlayerPetsInWorkspace()
    for _, petInfo in ipairs(playerPets) do
        local petPos = petInfo.position
        local tilePos = tilePart.Position
        
        -- Calculate surface position (same as placement logic)
        local surfacePos = Vector3.new(
            tilePos.X,
            tilePos.Y + 12, -- Eggs float 12 studs above tile surface
            tilePos.Z
        )
        
        -- Separate X/Z and Y axis checks
        local xzDistance = math.sqrt((petPos.X - surfacePos.X)^2 + (petPos.Z - surfacePos.Z)^2)
        local yDistance = math.abs(petPos.Y - surfacePos.Y)
        
        -- X/Z: 4 studs radius, Y: 8 studs radius
        if xzDistance < 4.0 and yDistance < 8.0 then
            placingInProgress = false
            return false
        end
    end
    
    -- Equip egg to Deploy S2
    local deploy = LocalPlayer.PlayerGui.Data:FindFirstChild("Deploy")
    if deploy then
        local eggUID = "Egg_" .. petUID
        deploy:SetAttribute("S2", eggUID)
    end
    
    -- Hold egg
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
    task.wait(0.1)
    
    -- Teleport to tile (+5 on Y axis above the part)
    local char = Players.LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local teleportPosition = Vector3.new(
                tilePart.Position.X,
                tilePart.Position.Y + 5, -- +5 on Y axis
                tilePart.Position.Z
            )
            hrp.CFrame = CFrame.new(teleportPosition)
            task.wait(0.1)
        end
    end
    
    -- Place egg on surface (top of the farm split tile)
    local surfacePosition = Vector3.new(
        tilePart.Position.X,
        tilePart.Position.Y + (tilePart.Size.Y / 2), -- Top surface
        tilePart.Position.Z
    )
    
    local args = {
        "Place",
        {
            DST = vector.create(surfacePosition.X, surfacePosition.Y, surfacePosition.Z),
            ID = petUID
        }
    }
    
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    if success then
        -- Verify placement
        task.wait(0.3)
        local placementConfirmed = false
        
        if playerBuiltBlocks then
            for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
                if model:IsA("Model") and model.Name == petUID then
                    placementConfirmed = true
                    break
                end
            end
        end
        
        if placementConfirmed then
                    -- Placement successful
            
            -- Remove egg and tile from available lists
            for i, egg in ipairs(availableEggs) do
                if egg.uid == petUID then
                    table.remove(availableEggs, i)
                    break
                end
            end
            
            for i, tile in ipairs(availableTiles) do
                if tile.index == tileInfo.index then
                    table.remove(availableTiles, i)
                    break
                end
            end
            
            -- Status update removed
            placingInProgress = false
            return true
        else
            -- Placement failed
            -- Remove the failed tile from available tiles so we don't retry it
            for i, tile in ipairs(availableTiles) do
                if tile.index == tileInfo.index then
                    table.remove(availableTiles, i)
                    break
                end
            end
            -- Status update removed
            placingInProgress = false
            return false
        end
    else
                    -- Failed to fire placement
        -- Remove the failed tile from available tiles so we don't retry it
        for i, tile in ipairs(availableTiles) do
            if tile.index == tileInfo.index then
                table.remove(availableTiles, i)
                break
            end
        end
        -- Status update removed
        placingInProgress = false
        return false
    end
end

-- Performance optimized placement attempt with rate limiting
local placementRateLimit = {
    lastAttempt = 0,
    minInterval = 0.5, -- Minimum 0.5 seconds between attempts
    cooldown = false
}

local function attemptPlacement()
    -- Rate limiting to prevent spam and lag
    local currentTime = tick()
    if currentTime - placementRateLimit.lastAttempt < placementRateLimit.minInterval then
        return -- Too soon, skip this attempt
    end
    placementRateLimit.lastAttempt = currentTime
    
    if #availableEggs == 0 then 
        warn("Auto Place stopped: No eggs available")
        return 
    end
    
    -- Pre-cache water farm availability for ocean eggs to avoid repeated scanning
    local waterFarmCache = {}
    local hasCheckedWater = false
    
    -- Try to find a placeable egg (optimized to avoid repeated expensive scans)
    local eggToPlace = nil
    local eggIndex = nil
    
    for i, egg in ipairs(availableEggs) do
        local canPlace = true
        
        -- Check if this is an ocean egg and if we have water farms available
        if isOceanEgg(egg.type) then
            -- Only scan once for all ocean eggs
            if not hasCheckedWater then
                local tileMap, totalTiles, occupiedTiles, lockedTiles = scanAllTilesAndModels(egg.type)
                
                -- Count actually available tiles using the same logic
            local availableWaterTiles = 0
                for surfacePos, tileInfo in pairs(tileMap) do
                    if tileInfo.available then
                    availableWaterTiles = availableWaterTiles + 1
                end
            end
            
                waterFarmCache.available = availableWaterTiles > 0
                hasCheckedWater = true
            end
            
            -- Use cached result
            if not waterFarmCache.available then
                canPlace = false
            end
        end
        
        if canPlace then
            eggToPlace = egg
            eggIndex = i
            break
        end
    end
    
    -- If no eggs can be placed (all are ocean eggs with no water farms), give up
    if not eggToPlace then
        warn("Auto Place stopped: No placeable eggs (ocean eggs need water farms)")
        return
    end
    
    -- Move the selected egg to the front of the list for processing
    if eggIndex > 1 then
        table.remove(availableEggs, eggIndex)
        table.insert(availableEggs, 1, eggToPlace)
    end
    
    -- Get the egg to place (now guaranteed to be placeable)
    local firstEgg = availableEggs[1]
    
    -- Update available tiles based on the egg type
    updateAvailableTiles(firstEgg.type)
    
    if #availableTiles == 0 then 
        local farmType = isOceanEgg(firstEgg.type) and "water farm" or "regular farm"
        
        -- Try to auto unlock tiles if needed (with error handling)
        local islandName = getAssignedIslandName()
        local islandNumber = getIslandNumberFromName(islandName)
        
        if islandName and islandNumber then
            local unlockSuccess, unlockError = pcall(function()
                return autoUnlockTilesIfNeeded(islandNumber, firstEgg.type)
            end)
            
            if unlockSuccess and unlockError then
                -- Tiles were unlocked, update available tiles again
                updateAvailableTiles(firstEgg.type)
                
                if #availableTiles == 0 then
                    warn("Auto Place: Still no available " .. farmType .. " tiles after unlocking")
                    return
                end
            elseif not unlockSuccess then
                warn("Auto Place: Error during unlock attempt: " .. tostring(unlockError))
                return
            else
                warn("Auto Place stopped: No available " .. farmType .. " tiles for " .. firstEgg.type)
                return
            end
        else
            warn("Auto Place: Could not determine island for unlocking")
            return
        end
    end
    
    -- Place eggs on available tiles (limit to prevent lag)
    local placed = 0
    local attempts = 0
    local maxAttempts = math.min(#availableEggs, #availableTiles, 5) -- Increase to 5 attempts max
    
    while #availableEggs > 0 and #availableTiles > 0 and attempts < maxAttempts do
        attempts = attempts + 1
        
        -- Double-check tile is still available before placing
        local tileInfo = availableTiles[1]
        local isStillAvailable = true
        
        if tileInfo then
            local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
            if playerBuiltBlocks then
                for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
                    if model:IsA("Model") then
                        local modelPos = model:GetPivot().Position
                        local tilePos = tileInfo.part.Position
                        
                        -- Calculate surface position (same as placement logic)
                        local surfacePos = Vector3.new(
                            tilePos.X,
                            tilePos.Y + 12, -- Eggs float 12 studs above tile surface
                            tilePos.Z
                        )
                        
                        -- Separate X/Z and Y axis checks
                        local xzDistance = math.sqrt((modelPos.X - surfacePos.X)^2 + (modelPos.Z - surfacePos.Z)^2)
                        local yDistance = math.abs(modelPos.Y - surfacePos.Y)
                        
                        -- X/Z: 4 studs radius, Y: 8 studs radius
                        if xzDistance < 4.0 and yDistance < 8.0 then
                            isStillAvailable = false
                            break
                        end
                    end
                end
            end
            
            -- Check for fully hatched pets in workspace.Pets
            if isStillAvailable then
                local playerPets = getPlayerPetsInWorkspace()
                for _, petInfo in ipairs(playerPets) do
                    local petPos = petInfo.position
                    local tilePos = tileInfo.part.Position
                    
                    -- Calculate surface position (same as placement logic)
                    local surfacePos = Vector3.new(
                        tilePos.X,
                        tilePos.Y + 12, -- Eggs float 12 studs above tile surface
                        tilePos.Z
                    )
                    
                    -- Separate X/Z and Y axis checks
                    local xzDistance = math.sqrt((petPos.X - surfacePos.X)^2 + (petPos.Z - surfacePos.Z)^2)
                    local yDistance = math.abs(petPos.Y - surfacePos.Y)
                    
                    -- X/Z: 4 studs radius, Y: 8 studs radius
                    if xzDistance < 4.0 and yDistance < 8.0 then
                        isStillAvailable = false
                        break
                    end
                end
            end
        end
        
        if isStillAvailable then
            if placeEggInstantly(availableEggs[1], availableTiles[1]) then
                placed = placed + 1
                task.wait(0.2) -- Longer delay between successful placements
            else
                -- Placement failed, tile was removed from availableTiles
                task.wait(0.1) -- Quick retry
            end
        else
            -- Tile is no longer available, remove it
            table.remove(availableTiles, 1)
        end
    end
    
    -- Placement attempt completed
end

local function setupPlacementMonitoring()
    -- Monitor for new eggs in PlayerGui.Data.Egg
    local eggContainer = getEggContainer()
    if eggContainer then
        local function onEggAdded(child)
            if not autoPlaceEnabled then return end
            if #child:GetChildren() == 0 then -- No subfolder = available egg
                task.wait(0.2) -- Wait for attributes to be set
                updateAvailableEggs()
                attemptPlacement()
            end
        end
        
        local function onEggRemoved(child)
            if not autoPlaceEnabled then return end
            updateAvailableEggs()
        end
        
        table.insert(placeConnections, eggContainer.ChildAdded:Connect(onEggAdded))
        table.insert(placeConnections, eggContainer.ChildRemoved:Connect(onEggRemoved))
    end
    
    -- Monitor for new tiles becoming available (when pets are removed from PlayerBuiltBlocks)
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    if playerBuiltBlocks then
        local function onBlockChanged()
            if not autoPlaceEnabled then return end
            task.wait(0.2)
            -- Update tiles based on first available egg type
            local firstEgg = availableEggs[1]
            local eggType = firstEgg and firstEgg.type or nil
            updateAvailableTiles(eggType)
            attemptPlacement()
        end
        
        table.insert(placeConnections, playerBuiltBlocks.ChildAdded:Connect(onBlockChanged))
        table.insert(placeConnections, playerBuiltBlocks.ChildRemoved:Connect(onBlockChanged))
    end
    
    -- Monitor for pets in workspace (when pets hatch and appear in workspace.Pets)
    local workspacePets = workspace:FindFirstChild("Pets")
    if workspacePets then
        local function onPetChanged()
            if not autoPlaceEnabled then return end
            task.wait(0.2)
            -- Invalidate cache when pets change to ensure fresh data
            invalidateTileCache()
            -- Update tiles based on first available egg type
            local firstEgg = availableEggs[1]
            local eggType = firstEgg and firstEgg.type or nil
            updateAvailableTiles(eggType)
            attemptPlacement()
        end
        
        table.insert(placeConnections, workspacePets.ChildAdded:Connect(onPetChanged))
        table.insert(placeConnections, workspacePets.ChildRemoved:Connect(onPetChanged))
    end
    
    -- Optimized periodic updates with intelligent batching
    local updateThread = task.spawn(function()
        local cycleCount = 0
        while autoPlaceEnabled do
            cycleCount = cycleCount + 1
            
            -- Batch operations to reduce performance impact
            if cycleCount % 2 == 1 then -- Update eggs every other cycle
            updateAvailableEggs()
            end
            
            -- Update tiles based on first available egg type (less frequently)
            local firstEgg = availableEggs[1]
            if firstEgg then
                local eggType = firstEgg.type
            updateAvailableTiles(eggType)
            attemptPlacement()
            end
            
            -- Adaptive waiting - longer when no eggs available
            local waitTime = #availableEggs > 0 and 2.5 or 5.0
            task.wait(waitTime) -- Longer intervals to reduce lag
        end
    end)
    
    table.insert(placeConnections, { disconnect = function() updateThread = nil end })
end

-- Performance throttling for auto place
local autoPlaceThrottle = {
    islandChangeTime = 0,
    setupDelay = 2.0 -- Delay before setting up monitoring after island change
}

local function runAutoPlace()
    while autoPlaceEnabled do
        local islandName = getAssignedIslandName()
        
        if not islandName or islandName == "" then
            task.wait(2) -- Longer wait when no island
        else
        
        -- Throttle setup after island changes to prevent spam
        local currentTime = tick()
        if currentTime - autoPlaceThrottle.islandChangeTime < autoPlaceThrottle.setupDelay then
            task.wait(1)
            else
        -- Setup monitoring with performance optimizations
        cleanupPlaceConnections()
        setupPlacementMonitoring()
        
        -- Wait until disabled or island changes with improved efficiency
        while autoPlaceEnabled do
            local currentIsland = getAssignedIslandName()
            if currentIsland ~= islandName then
                autoPlaceThrottle.islandChangeTime = tick()
                invalidateTileCache() -- Clear cache when island changes
                break -- Island changed, restart monitoring
            end
            task.wait(1.0) -- Longer wait to reduce CPU usage
                end
            end
        end
    end
    
    cleanupPlaceConnections()
end

-- Legacy auto place toggle (replaced by new system)
local autoPlaceToggle = {
    -- Dummy toggle for config compatibility
    SetValue = function(self, value) 
        if AutoPlaceSystem and AutoPlaceSystem.SetEnabled then
            AutoPlaceSystem.SetEnabled(value)
        end
    end
}




-- Auto Unlock Tile functionality
local autoUnlockEnabled = false
local autoUnlockThread = nil



-- Helper function to get locked tiles for current island (used by runAutoUnlock)
local function getLockedTilesForCurrentIsland()
    local lockedTiles = {}
    
    local islandName = getAssignedIslandName()
    if not islandName then return lockedTiles end
    
    local art = workspace:FindFirstChild("Art")
    if not art then return lockedTiles end
    
    local island = art:FindFirstChild(islandName)
    if not island then return lockedTiles end
    
    local env = island:FindFirstChild("ENV")
    if not env then return lockedTiles end
    
    local locksFolder = env:FindFirstChild("Locks")
    if not locksFolder then return lockedTiles end
    
    for _, lockModel in ipairs(locksFolder:GetChildren()) do
        if lockModel:IsA("Model") then
            -- Prefer a child named "Farm", else find any BasePart inside the model
            local farmPart = lockModel:FindFirstChild("Farm")
            if not (farmPart and farmPart:IsA("BasePart")) then
                farmPart = lockModel:FindFirstChild("WaterFarm") or farmPart
                if not (farmPart and farmPart:IsA("BasePart")) then
                    for _, ch in ipairs(lockModel:GetDescendants()) do
                        if ch:IsA("BasePart") then farmPart = ch break end
                    end
                end
            end
            if farmPart and farmPart:IsA("BasePart") then
                -- Consider locked if the visible blocker is opaque
                local isLocked = (tonumber(farmPart.Transparency) or 0) <= 0.01
                -- Some games toggle CanCollide for locks; treat collidable parts as locked
                if not isLocked then
                    local cc = (farmPart.CanCollide == true)
                    isLocked = cc
                end
                if isLocked then
                    local lockCost = farmPart:GetAttribute("LockCost")
                    if lockCost == nil then lockCost = lockModel:GetAttribute("LockCost") end
                    if lockCost == nil then lockCost = farmPart:GetAttribute("Cost") end
                    table.insert(lockedTiles, {
                        modelName = lockModel.Name,
                        farmPart = farmPart,
                        cost = lockCost or 0,
                        model = lockModel
                    })
                end
            end
        end
    end
    
    return lockedTiles
end

-- Duplicate function removed - using the enhanced version with better error handling

-- Local cost parser for lock costs (supports commas and K/M/B/T)
local function parseLockCost(val)
    if type(val) == "number" then return val end
    if type(val) ~= "string" then return 0 end
    local s = val:gsub("[$€£¥₹,]", "")
    local num, suf = s:match("^([%d%.]+)([KkMmBbTt]?)$")
    local n = tonumber(num)
    if not n then return 0 end
    if suf ~= nil and suf ~= "" then
        local c = suf:lower()
        if c == "k" then n = n * 1e3
        elseif c == "m" then n = n * 1e6
        elseif c == "b" then n = n * 1e9
        elseif c == "t" then n = n * 1e12 end
    end
    return n
end

local function runAutoUnlock()
    while autoUnlockEnabled do
        local ok, err = pcall(function()
            local lockedTiles = getLockedTilesForCurrentIsland() -- Call without parameters for current island
            
            if #lockedTiles == 0 then
                task.wait(2)
                return
            end
            
            -- Sort by cost ascending and try cheapest first
            table.sort(lockedTiles, function(a, b)
                local ca = parseLockCost(a.cost) or math.huge
                local cb = parseLockCost(b.cost) or math.huge
                return ca < cb
            end)

            -- Dynamically unlock while funds allow; re-check funds each attempt
            for _, lockInfo in ipairs(lockedTiles) do
                if not autoUnlockEnabled then break end
                local cost = parseLockCost(lockInfo.cost)
                local netWorthNow = getPlayerNetWorth()
                if netWorthNow >= cost then
                    if unlockTile(lockInfo) then
                        task.wait(0.5) -- Wait between unlocks
                    else
                        task.wait(0.2)
                    end
                end
            end
            
            task.wait(3) -- Wait before next scan
            
        end)
        
        if not ok then
            warn("Auto Unlock error: " .. tostring(err))
            task.wait(1)
        end
    end
end


 

-- Auto Delete functionality moved to AutoPlaceSystem.lua

-- Enhanced number parsing function to handle K, M, B, T suffixes and commas
local function parseNumberWithSuffix(text)
    if not text or type(text) ~= "string" then return nil end
    
    -- Remove common prefixes and suffixes
    local cleanText = text:gsub("[$€£¥₹/s]", ""):gsub("^%s*(.-)%s*$", "%1") -- Remove currency symbols and /s
    
    -- Handle comma-separated numbers (e.g., "1,234,567")
    cleanText = cleanText:gsub(",", "")
    
    -- Try to match number with suffix (e.g., "1.5K", "2.3M", "1.2B")
    local number, suffix = cleanText:match("^([%d%.]+)([KkMmBbTt]?)$")
    
    if not number then
        -- Try to extract just a number if no suffix pattern matches
        number = cleanText:match("([%d%.]+)")
    end
    
    local numValue = tonumber(number)
    if not numValue then return nil end
    
    -- Apply suffix multiplier
    if suffix then
        local lowerSuffix = string.lower(suffix)
        if lowerSuffix == "k" then
            numValue = numValue * 1000
        elseif lowerSuffix == "m" then
            numValue = numValue * 1000000
        elseif lowerSuffix == "b" then
            numValue = numValue * 1000000000
        elseif lowerSuffix == "t" then
            numValue = numValue * 1000000000000
        end
    end
    
    return numValue
end


-- Helper: robust ocean pet type detection (uses Config.ResPet when available)
local resPetConfigCache = nil
local function isOceanPetType(petType)
    if not petType then return false end
    local typeStr = tostring(petType)
    if typeStr == "" then return false end
    -- Lazy-load and cache ResPet config
    if resPetConfigCache == nil then
        pcall(function()
            local cfgFolder = ReplicatedStorage:FindFirstChild("Config")
            local mod = cfgFolder and cfgFolder:FindFirstChild("ResPet")
            resPetConfigCache = (mod and require(mod)) or {}
        end)
        if resPetConfigCache == nil then resPetConfigCache = {} end
    end
    local def = resPetConfigCache[typeStr]
    if def and type(def) == "table" and type(def.Category) == "string" then
        local c = string.lower(def.Category)
        if c:find("ocean") or c:find("water") or c:find("sea") then
            return true
        end
    end
    -- Fallback heuristics on the type name
    local t = string.lower(typeStr)
    local oceanKeywords = {
        "fish","shark","octopus","sea","angler","dolphin","whale","manta","turtle","eel","seal","ray"
    }
    for _, kw in ipairs(oceanKeywords) do
        if t:find(kw) then return true end
    end
    return false
end

-- Helper: fetch pet type from PlayerGui.Data.Pets by pet name (UID)
local function getPetTypeFromDataByName(petName)
    if not petName then return nil end
    local player = Players.LocalPlayer
    if not player then return nil end
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local data = pg:FindFirstChild("Data")
    if not data then return nil end
    local petsFolder = data:FindFirstChild("Pets")
    if not petsFolder then return nil end
    local conf = petsFolder:FindFirstChild(petName)
    if conf and conf:IsA("Configuration") then
        local t = conf:GetAttribute("T")
        if t and t ~= "" then return t end
    end
    return nil
end

-- Resolve pet type reliably by comparing the model's name with Data.Pets
local function getPetTypeFromDataPetsByName(petName)
    local player = Players.LocalPlayer
    if not player then return nil end
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local data = pg:FindFirstChild("Data")
    if not data then return nil end
    local petsFolder = data:FindFirstChild("Pets")
    if not petsFolder then return nil end
    local conf = petsFolder:FindFirstChild(petName)
    if conf and conf:IsA("Configuration") then
        local t = conf:GetAttribute("T")
        if t and t ~= "" then return t end
    end
    return nil
end

local function resolvePetTypeForModel(petModel)
    if not petModel then return nil end
    -- Prefer Data.Pets by name for exact mapping
    local byName = getPetTypeFromDataPetsByName(petModel.Name)
    if byName then return tostring(byName) end
    -- Fallback to attribute on the model
    local attrT = petModel:GetAttribute("T")
    if attrT and tostring(attrT) ~= "" then return tostring(attrT) end
    -- Last resort: use model name
    return tostring(petModel.Name)
end



-- Auto Delete UI elements moved to AutoPlaceSystem.lua

-- Auto Delete function moved to AutoPlaceSystem.lua



-- Enhanced Open Button UI - will be updated by mobile toggle settings
-- Initial setup happens in the auto-load section

-- Close callback
Window:OnClose(function()
    autoBuyEnabled = false
    autoPlaceEnabled = false
    autoFeedEnabled = false
    autoClaimEnabled = false
    -- autoUnlockEnabled moved to AutoPlaceSystem.lua
    
    -- Cleanup AutoFish system
    if AutoFishSystem and AutoFishSystem.Cleanup then
        pcall(function()
            AutoFishSystem.Cleanup()
            print("[AutoFish] System cleaned up on window close")
        end)
    end
end)


-- ============ Auto Claim Dino - REMOVED ============
-- Auto dino claim functionality has been removed for cleaner performance

-- ============ Shop / Auto Upgrade ============
Tabs.ShopTab:Section({ Title = "Auto Upgrade Conveyor", Icon = "arrow-up" })

-- Get current conveyor level from GameFlag
local function getCurrentConveyorLevel()
    local player = game:GetService("Players").LocalPlayer
    if not player then return 0 end
    
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return 0 end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return 0 end
    
    local gameFlag = data:FindFirstChild("GameFlag")
    if not gameFlag then return 0 end
    
    local conveyorLevel = gameFlag:GetAttribute("Conveyor")
    return tonumber(conveyorLevel) or 0
end

-- Get next upgrade to attempt (current level + 1)
local function getNextUpgradeLevel()
    local currentLevel = getCurrentConveyorLevel()
    local nextLevel = currentLevel + 1
    -- Keep within bounds 1-9
    if nextLevel > 9 then
        return nil -- Max level reached
    end
    return nextLevel
end

local function chooseAffordableUpgrades(netWorth)
    local nextLevel = getNextUpgradeLevel()
    if not nextLevel then
        return {} -- Max level reached
    end
    
    -- Find the upgrade for the next level
    for key, entry in pairs(conveyorConfig) do
        if type(entry) == "table" then
            local cost = entry.Cost or entry.Price or (entry.Base and entry.Base.Price)
            if type(cost) == "string" then
                local clean = tostring(cost):gsub("[^%d%.]", "")
                cost = tonumber(clean)
            end
            local idLike = entry.ID or entry.Id or entry.Name or key
            local idx = parseConveyorIndexFromId(idLike)
            if idx == nextLevel and type(cost) == "number" and netWorth >= cost then
                return {{ idx = idx, cost = cost }}
            end
        end
    end
    
    return {}
end

local function parseConveyorIndexFromId(idStr)
    local n = tostring(idStr):match("(%d+)")
    return n and tonumber(n) or nil
end

local autoUpgradeEnabled = false
local autoUpgradeThread = nil
local autoUpgradeToggle = Tabs.ShopTab:Toggle({
    Title = "Auto Upgrade Conveyor",
    Desc = "Upgrade next conveyor level when affordable",
    Value = false,
    Callback = function(state)
        autoUpgradeEnabled = state
        
        waitForSettingsReady(0.2)
        if state and not autoUpgradeThread then
            autoUpgradeThread = task.spawn(function()
                -- Ensure conveyor config is loaded
                if not conveyorConfig or not next(conveyorConfig) then
                    loadConveyorConfig()
                end
                while autoUpgradeEnabled do
                    -- Attempt reload if config still not present
                    if not conveyorConfig or not next(conveyorConfig) then
                        loadConveyorConfig()
                        task.wait(1)
                    else
                        local currentLevel = getCurrentConveyorLevel()
                        local nextLevel = getNextUpgradeLevel()
                        
                        if not nextLevel then
                            -- Max level reached
                            task.wait(2)
                        else
                    local net = getPlayerNetWorth()
                    local actions = chooseAffordableUpgrades(net)
                            
                    if #actions == 0 then
                        task.wait(0.8)
                    else
                        for _, a in ipairs(actions) do
                                    fireConveyorUpgrade(a.idx)
                            task.wait(0.2)
                                end
                            end
                        end
                    end
                end
            end)
            WindUI:Notify({ Title = "Shop", Content = "Auto upgrade started! 🎉", Duration = 3 })
        elseif (not state) and autoUpgradeThread then
            WindUI:Notify({ Title = "Shop", Content = "Auto upgrade stopped", Duration = 3 })
        end
    end
})



-- ============ Fruit Market (Auto Buy Fruit) ============
Tabs.ShopTab:Section({ Title = "Fruit Market", Icon = "apple" })

-- Load Fruit Selection UI
local FruitSelection = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/FruitSelection.lua"))()

-- Fruit Data for auto buy functionality
local FruitData = {
    Strawberry = { Price = "5,000" },
    Blueberry = { Price = "20,000" },
    Watermelon = { Price = "80,000" },
    Apple = { Price = "400,000" },
    Orange = { Price = "1,200,000" },
    Corn = { Price = "3,500,000" },
    Banana = { Price = "12,000,000" },
    Grape = { Price = "50,000,000" },
    Pear = { Price = "200,000,000" },
    Pineapple = { Price = "600,000,000" },
    GoldMango = { Price = "2,000,000,000" },
    BloodstoneCycad = { Price = "8,000,000,000" },
    ColossalPinecone = { Price = "40,000,000,000" },
    VoltGinkgo = { Price = "80,000,000,000" },
    DeepseaPearlFruit = { Price = "40,000,000,000" }
}



Tabs.ShopTab:Button({
    Title = "Open Fruit Selection UI",
    Desc = "Select fruits to buy automatically",
    Callback = function()
        if not fruitSelectionVisible then
            FruitSelection.Show(
                function(selectedItems)
                    -- Handle selection changes
                    selectedFruits = selectedItems
                    updateCustomUISelection("fruitSelections", selectedItems)
                end,
                function(isVisible)
                    fruitSelectionVisible = isVisible
                end,
                selectedFruits -- Pass saved fruit selections
            )
            fruitSelectionVisible = true
        else
            FruitSelection.Hide()
            fruitSelectionVisible = false
        end
    end
})

-- Auto Buy Fruit functionality
local autoBuyFruitEnabled = false
local autoBuyFruitThread = nil

-- Helper functions for fruit buying
local function getPlayerNetWorth()
    local player = Players.LocalPlayer
    if not player then return 0 end
    
    -- First try to get from Attributes (as you mentioned)
    local attrValue = player:GetAttribute("NetWorth")
    if type(attrValue) == "number" then
        return attrValue
    end
    
    -- Fallback to leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then return 0 end
    
    local netWorth = leaderstats:FindFirstChild("NetWorth")
    if not netWorth then return 0 end
    
    return netWorth.Value or 0
end

local function parsePrice(priceStr)
    if type(priceStr) == "number" then
        return priceStr
    end
    local cleanPrice = priceStr:gsub(",", "")
    return tonumber(cleanPrice) or 0
end

local function getFoodStoreUI()
    local player = Players.LocalPlayer
    if not player then return nil end
    
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    return playerGui:FindFirstChild("ScreenFoodStore")
end

local function getFoodStoreLST()
    local player = Players.LocalPlayer
    if not player then return nil end
    
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return nil end
    
    local foodStore = data:FindFirstChild("FoodStore")
    if not foodStore then return nil end
    
    local lst = foodStore:FindFirstChild("LST")
    return lst
end

local function isFruitInStock(fruitId)
    local lst = getFoodStoreLST()
    if not lst then return false end
    
    -- Try different possible key formats
    local candidates = {fruitId, string.lower(fruitId), string.upper(fruitId)}
    local underscoreVersion = fruitId:gsub(" ", "_")
    table.insert(candidates, underscoreVersion)
    table.insert(candidates, string.lower(underscoreVersion))
    
    for _, candidate in ipairs(candidates) do
        -- First try to get from Attributes (as you mentioned)
        local stockValue = lst:GetAttribute(candidate)
        if type(stockValue) == "number" and stockValue > 0 then
            return true
        end
        
        -- Fallback to TextLabel
        local stockLabel = lst:FindFirstChild(candidate)
        if stockLabel and stockLabel:IsA("TextLabel") then
            local stockText = stockLabel.Text
            local stockNumber = tonumber(stockText:match("%d+"))
            if stockNumber and stockNumber > 0 then
                return true
            end
        end
    end
    
    return false
end

local autoBuyFruitToggle = Tabs.ShopTab:Toggle({
    Title = "Auto Buy Fruit",
    Desc = "Buy selected fruits when affordable",
    Value = false,
    Callback = function(state)
        autoBuyFruitEnabled = state
        
        waitForSettingsReady(0.2)
        if state and not autoBuyFruitThread then
            autoBuyFruitThread = task.spawn(function()
                while autoBuyFruitEnabled do
                    local ok, err = pcall(function()
                        -- Auto buy fruit logic
                        if selectedFruits and next(selectedFruits) then
                            local netWorth = getPlayerNetWorth()
                            local boughtAny = false
                            
                            for fruitId, _ in pairs(selectedFruits) do
                                if FruitData[fruitId] then
                                    local fruitPrice = parsePrice(FruitData[fruitId].Price)
                                    
                                    -- Check if fruit is in stock
                                    if not isFruitInStock(fruitId) then
                                        task.wait(0.5)
                                    else
                                        -- Check if player can afford it
                                        if netWorth < fruitPrice then
                                            task.wait(0.5)
                                        else
                                            -- Try to buy the fruit
                                            local success = pcall(function()
                                                -- Fire the fruit buying remote
                                                local args = {fruitId}
                                                ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FoodStoreRE"):FireServer(unpack(args))
                                            end)
                                            
                                            if success then
                                                boughtAny = true
                                                -- refresh net worth after a purchase attempt
                                                netWorth = getPlayerNetWorth()
                                            end
                                            
                                            task.wait(0.5) -- Wait between each fruit purchase
                                        end
                                    end
                                end
                            end
                            
                            -- If no fruits were bought, wait longer before next attempt
                            if not boughtAny then
                                task.wait(2)
                            else
                                task.wait(1) -- Shorter wait if we bought something
                            end
                        else
                            task.wait(2)
                        end
                    end)
                    if not ok then
                        warn("Auto Buy Fruit error: " .. tostring(err))
                        task.wait(1)
                    end
                end
                autoBuyFruitThread = nil
            end)
            WindUI:Notify({ Title = "Auto Buy Fruit", Content = "Started buying fruits! 🎉", Duration = 3 })
        elseif (not state) and autoBuyFruitThread then
            WindUI:Notify({ Title = "Auto Buy Fruit", Content = "Stopped", Duration = 3 })
        end
    end
})

 

 

-- ============ WindUI ConfigManager System ============

-- 1. Load ConfigManager
local ConfigManager = Window.ConfigManager

-- 2. Create Config Files for different categories
local mainConfig = ConfigManager:CreateConfig("BuildAZoo_Main")
local autoSystemsConfig = ConfigManager:CreateConfig("BuildAZoo_AutoSystems") 
local customUIConfig = ConfigManager:CreateConfig("BuildAZoo_CustomUI")

-- Legacy support
local zebuxConfig = mainConfig -- For backward compatibility

-- Optimized Config I/O (organized under WindUI/Zebux/custom with migration from legacy flat files)
local HttpService = game:GetService("HttpService")
local BASE_CFG_FOLDER = "WindUI/Zebux"
local CUSTOM_CFG_FOLDER = BASE_CFG_FOLDER .. "/custom"
pcall(function() if not isfolder(BASE_CFG_FOLDER) then makefolder(BASE_CFG_FOLDER) end end)
pcall(function() if not isfolder(CUSTOM_CFG_FOLDER) then makefolder(CUSTOM_CFG_FOLDER) end end)

local function legacyNameFor(fileName)
    if fileName == "ClaimSettings.json" then return "Zebux_ClaimSettings.json" end
    if fileName == "EggSelections.json" then return "Zebux_EggSelections.json" end
    if fileName == "FruitSelections.json" then return "Zebux_FruitSelections.json" end
    if fileName == "FeedFruitSelections.json" then return "Zebux_FeedFruitSelections.json" end
    if fileName == "CustomSelections.json" then return "Zebux_CustomSelections.json" end
    return nil
end

local function cfgPath(fileName)
    return string.format("%s/%s", CUSTOM_CFG_FOLDER, fileName)
end

local function saveJSONCustom(fileName, data)
    pcall(function()
        local path = cfgPath(fileName)
        writefile(path, HttpService:JSONEncode(data))
    end)
end

local function loadJSONCustom(fileName)
    local ok, result = pcall(function()
        local path = cfgPath(fileName)
        if isfile(path) then
            return HttpService:JSONDecode(readfile(path))
        end
        -- Migration from legacy flat files (root)
        local legacy = legacyNameFor(fileName)
        if legacy and isfile(legacy) then
            local jsonData = readfile(legacy)
            local decoded = HttpService:JSONDecode(jsonData)
            -- Write to new organized path and remove legacy
            writefile(path, jsonData)
            pcall(function() delfile(legacy) end)
            return decoded
        end
        return nil
    end)
    if ok then return result end
    return nil
end

-- Custom UI selections storage (separate from WindUI config)
local customSelections = {
    eggSelections = {},
    fruitSelections = {},
    feedFruitSelections = {}
}

-- Function to save custom UI selections
function saveCustomSelections()
    local success, err = pcall(function()
        saveJSONCustom("CustomSelections.json", customSelections)
    end)
    
    if not success then
        warn("Failed to save custom selections: " .. tostring(err))
    end
end

-- Function to load custom UI selections
function loadCustomSelections()
    local success, err = pcall(function()
        local loaded = loadJSONCustom("CustomSelections.json")
        if loaded then
            customSelections = loaded
            
            -- Apply loaded selections to variables
            if customSelections.eggSelections then
                selectedTypeSet = {}
                for _, eggId in ipairs(customSelections.eggSelections.eggs or {}) do
                    selectedTypeSet[eggId] = true
                end
                selectedMutationSet = {}
                for _, mutationId in ipairs(customSelections.eggSelections.mutations or {}) do
                    selectedMutationSet[mutationId] = true
                end
            end
            
            if customSelections.fruitSelections then
                selectedFruits = {}
                for _, fruitId in ipairs(customSelections.fruitSelections or {}) do
                    selectedFruits[fruitId] = true
                end
            end
            
            if customSelections.feedFruitSelections then
                selectedFeedFruits = {}
                for _, fruitId in ipairs(customSelections.feedFruitSelections or {}) do
                    selectedFeedFruits[fruitId] = true
                end
            end
        end
    end)
    
    if not success then
        warn("Failed to load custom selections: " .. tostring(err))
    end
end

-- Function to update custom UI selections
updateCustomUISelection = function(uiType, selections)
    if uiType == "eggSelections" then
        customSelections.eggSelections = {
            eggs = {},
            mutations = {}
        }
        for eggId, _ in pairs(selections.eggs or {}) do
            table.insert(customSelections.eggSelections.eggs, eggId)
        end
        for mutationId, _ in pairs(selections.mutations or {}) do
            table.insert(customSelections.eggSelections.mutations, mutationId)
        end
    elseif uiType == "fruitSelections" then
        customSelections.fruitSelections = {}
        for fruitId, _ in pairs(selections) do
            table.insert(customSelections.fruitSelections, fruitId)
        end
    elseif uiType == "feedFruitSelections" then
        customSelections.feedFruitSelections = {}
        for fruitId, _ in pairs(selections) do
            table.insert(customSelections.feedFruitSelections, fruitId)
        end
    end
    
    saveCustomSelections()
end

-- Register all UI elements with WindUI ConfigManager (Enhanced)
function registerUIElements()
    -- Helper function with better error handling
    local function registerIfExists(config, key, element, description)
        if element then
            local success, err = pcall(function()
                config:Register(key, element)
            end)
            if not success then
                warn("❌ Failed to register " .. (description or key) .. ":", err)
            end
        end
    end
    
    -- ============ Main Config (Core toggles and settings) ============
    registerIfExists(mainConfig, "autoBuyEnabled", autoBuyToggle, "Auto Buy Toggle")
    registerIfExists(mainConfig, "autoHatchEnabled", autoHatchToggle, "Auto Hatch Toggle")
    registerIfExists(mainConfig, "autoClaimEnabled", autoClaimToggle, "Auto Claim Toggle")
    registerIfExists(mainConfig, "autoPlaceEnabled", autoPlaceToggle, "Auto Place Toggle")
    -- autoUnlockEnabled moved to AutoPlaceSystem.lua
    
    -- ============ Auto Systems Config (Advanced automation) ============
    -- Auto Delete and Auto Unlock moved to AutoPlaceSystem.lua
    registerIfExists(autoSystemsConfig, "autoUpgradeEnabled", autoUpgradeToggle, "Auto Upgrade Toggle")
    registerIfExists(autoSystemsConfig, "autoBuyFruitEnabled", autoBuyFruitToggle, "Auto Buy Fruit Toggle")
    registerIfExists(autoSystemsConfig, "autoFeedEnabled", autoFeedToggle, "Auto Feed Toggle")
    
    -- Register AutoFish system elements
    if AutoFishSystem then
        local fishElements = AutoFishSystem.GetConfigElements and AutoFishSystem.GetConfigElements() or {}
        registerIfExists(autoSystemsConfig, "autoFishToggle", fishElements.autoFishToggleElement, "Auto Fish Toggle")
        registerIfExists(autoSystemsConfig, "autoFishBait", fishElements.autoFishBaitElement, "Auto Fish Bait Dropdown")
        print("[Config] Registered AutoFish elements:", fishElements.autoFishToggleElement and "toggle OK" or "toggle missing", fishElements.autoFishBaitElement and "bait OK" or "bait missing")
    end
    
    -- ============ Custom UI Config (Dropdowns and UI selections) ============
    -- Auto Place dropdowns are now handled by AutoPlaceSystem.lua
    if AutoPlaceSystem then
        registerIfExists(customUIConfig, "autoPlaceEggDropdown", AutoPlaceSystem.EggDropdown, "Auto Place Egg Dropdown")
        registerIfExists(customUIConfig, "autoPlaceMutationDropdown", AutoPlaceSystem.MutationDropdown, "Auto Place Mutation Dropdown")
    end
    
    -- UI element registration complete
end

-- ============ Built-in Anti-AFK System (GitHub Loading) ============

-- Load Anti-AFK System from GitHub
local AntiAFKSystem = nil
task.spawn(function()
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/AntiAFKSystem.lua"))()
    end)
    if success and result then
        AntiAFKSystem = result        
        -- Initialize the Anti-AFK system
        if AntiAFKSystem and AntiAFKSystem.Init then
            local initSuccess, initErr = pcall(function()
                AntiAFKSystem.Init({
                    autoStart = true -- Start automatically
                })
                print("[AntiAFK] System initialized and started")
            end)
            
            if not initSuccess then
                warn("Failed to initialize Anti-AFK System: " .. tostring(initErr))
                -- Fallback to basic anti-AFK
                _G.ZebuxState.setupFallbackAntiAFK()
            end
        else
            warn("[AntiAFK] System module invalid, using fallback")
            _G.ZebuxState.setupFallbackAntiAFK()
        end
    else
        warn("Failed to load Anti-AFK System from GitHub: " .. tostring(result))
        _G.ZebuxState.setupFallbackAntiAFK()
        end
    end)
    
-- Fallback anti-AFK function (moved to global scope)
_G.ZebuxState.setupFallbackAntiAFK = function()
    if not antiAFKEnabled then
        antiAFKEnabled = true
        antiAFKConnection = game:GetService("Players").LocalPlayer.Idled:Connect(function()
            game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        end)
        print("[AntiAFK] Fallback system activated")
    end
end

-- Legacy functions for compatibility
setupAntiAFK = function()
    if AntiAFKSystem and AntiAFKSystem.Enable then
        AntiAFKSystem.Enable()
    else
        _G.ZebuxState.setupFallbackAntiAFK()
    end
end

disableAntiAFK = function()
    if AntiAFKSystem and AntiAFKSystem.Disable then
        AntiAFKSystem.Disable()
    elseif antiAFKEnabled then
        antiAFKEnabled = false
        if antiAFKConnection then
            antiAFKConnection:Disconnect()
            antiAFKConnection = nil
        end
    end
end

-- ============ Save Settings Tab ============
Tabs.SaveTab:Section({ Title = "💾 Save & Load", Icon = "save" })

Tabs.SaveTab:Paragraph({
    Title = "💾 Enhanced Settings Manager",
    Desc = "Advanced WindUI ConfigManager system with organized categories:\n" ..
           "🔵 Main Config - Core automation (Buy, Hatch, Claim, Place, Unlock)\n" ..
           "🤖 Auto Systems - Advanced features (Delete, Dino, Upgrade, Feed)\n" ..
           "🎨 Custom UI - Dropdowns and selections\n" ..
           "📁 Custom Selections - Egg/Fruit choices saved separately",
    Image = "save",
    ImageSize = 18,
})

-- ============ Enhanced Config Management ============

-- Enhanced save function
function saveAllConfigs()
    local results = {}
    
    -- Save main config
    local mainSuccess, mainErr = pcall(function()
        mainConfig:Save()
    end)
    results.mainConfig = mainSuccess and "✅ Success" or ("❌ " .. tostring(mainErr))
    
    -- Save auto systems config
    local autoSuccess, autoErr = pcall(function()
        autoSystemsConfig:Save()
    end)
    results.autoSystemsConfig = autoSuccess and "✅ Success" or ("❌ " .. tostring(autoErr))
    
    -- Save custom UI config
    local customUISuccess, customUIErr = pcall(function()
        customUIConfig:Save()
    end)
    results.customUIConfig = customUISuccess and "✅ Success" or ("❌ " .. tostring(customUIErr))
    
    -- Save custom selections
    local customSuccess, customErr = pcall(function()
        saveCustomSelections()
    end)
    results.customSelections = customSuccess and "✅ Success" or ("❌ " .. tostring(customErr))
    
    return results
end

-- Enhanced load function
function loadAllConfigs()
    local results = {}
    
    -- Load main config
    local mainSuccess, mainErr = pcall(function()
        mainConfig:Load()
    end)
    results.mainConfig = mainSuccess and "✅ Success" or ("❌ " .. tostring(mainErr))
    
    -- Load auto systems config
    local autoSuccess, autoErr = pcall(function()
        autoSystemsConfig:Load()
    end)
    results.autoSystemsConfig = autoSuccess and "✅ Success" or ("❌ " .. tostring(autoErr))
    
    -- Load custom UI config
    local customUISuccess, customUIErr = pcall(function()
        customUIConfig:Load()
    end)
    results.customUIConfig = customUISuccess and "✅ Success" or ("❌ " .. tostring(customUIErr))
    
    -- Load custom selections
    local customSuccess, customErr = pcall(function()
        loadCustomSelections()
    end)
    results.customSelections = customSuccess and "✅ Success" or ("❌ " .. tostring(customErr))
    
            -- Note: UI sync is now handled by AutoPlaceSystem.lua
    
    return results
end

Tabs.SaveTab:Button({
    Title = "💾 Save All Settings",
    Desc = "Save all settings across all config categories",
    Callback = function()
        local results = saveAllConfigs()
        local totalSuccess = 0
        local totalCount = 0
        
        for category, result in pairs(results) do
            totalCount = totalCount + 1
            if result:find("✅") then
                totalSuccess = totalSuccess + 1
            end
        end
        
        local message = string.format("Saved %d/%d categories successfully!", totalSuccess, totalCount)
        WindUI:Notify({ 
            Title = "💾 Save Complete", 
            Content = message, 
            Duration = 3 
        })
        
        -- Save operation completed
    end
})

Tabs.SaveTab:Button({
    Title = "📂 Load All Settings",
    Desc = "Load all saved settings from all config categories",
    Callback = function()
        local results = loadAllConfigs()
        local totalSuccess = 0
        local totalCount = 0
        
        for category, result in pairs(results) do
            totalCount = totalCount + 1
            if result:find("✅") then
                totalSuccess = totalSuccess + 1
            end
        end
        
        local message = string.format("Loaded %d/%d categories successfully!", totalSuccess, totalCount)
        WindUI:Notify({ 
            Title = "📂 Load Complete", 
            Content = message, 
            Duration = 3 
        })
        
        -- Load operation completed
    end
})

-- ============ Individual Config Management ============
Tabs.SaveTab:Section({ Title = "🗂️ Individual Configs", Icon = "folder" })

Tabs.SaveTab:Button({
    Title = "💾 Save Main Config Only",
    Desc = "Save core settings (Auto Buy, Hatch, Claim, Place, Unlock)",
    Callback = function()
        local success, err = pcall(function()
            mainConfig:Save()
        end)
        local message = success and "Main config saved!" or ("Failed: " .. tostring(err))
        WindUI:Notify({ Title = "💾 Main Config", Content = message, Duration = 2 })
    end
})

Tabs.SaveTab:Button({
    Title = "🤖 Save Auto Systems Config",
    Desc = "Save advanced automation (Delete, Dino, Upgrade, Fruit, Feed)",
    Callback = function()
        local success, err = pcall(function()
            autoSystemsConfig:Save()
        end)
        local message = success and "Auto systems saved!" or ("Failed: " .. tostring(err))
        WindUI:Notify({ Title = "🤖 Auto Systems", Content = message, Duration = 2 })
    end
})

Tabs.SaveTab:Button({
    Title = "🎨 Save Custom UI Config",
    Desc = "Save dropdowns and UI element states",
    Callback = function()
        local success, err = pcall(function()
            customUIConfig:Save()
        end)
        local message = success and "Custom UI saved!" or ("Failed: " .. tostring(err))
        WindUI:Notify({ Title = "🎨 Custom UI", Content = message, Duration = 2 })
    end
})

-- ============ Config Browser ============
Tabs.SaveTab:Section({ Title = "📋 Config Browser", Icon = "list" })

Tabs.SaveTab:Button({
    Title = "📋 View All Configs",
    Desc = "Show all available config files and their contents",
    Callback = function()
        local allConfigs = ConfigManager:AllConfigs()
        -- Config details available in console
        
        WindUI:Notify({ 
            Title = "📋 Config Browser", 
            Content = "Config details printed to console!", 
            Duration = 3 
        })
    end
})

Tabs.SaveTab:Button({
    Title = "🛡️ Anti-AFK Status",
    Desc = "Shows anti-AFK system status (loaded from GitHub)",
    Callback = function()
        local status = "❓ Unknown"
        local source = "GitHub System"
        
        if AntiAFKSystem then
            if AntiAFKSystem.GetStatus then
                status = AntiAFKSystem.GetStatus() and "✅ Active" or "❌ Disabled"
            else
                status = "✅ Loaded"
            end
        elseif antiAFKEnabled then
            status = "✅ Active (Fallback)"
            source = "Fallback System"
        else
            status = "❌ Not Active"
        end
        
        WindUI:Notify({ 
            Title = "🛡️ Anti-AFK Status", 
            Content = "Status: " .. status .. "\nSource: " .. source .. "\nLoaded from GitHub automatically!", 
            Duration = 4 
        })
    end
})

-- Open button will be set up at the end of the script

 

Tabs.SaveTab:Button({
    Title = "🔄 Manual Load Settings",
    Desc = "Manually load all settings (WindUI + Custom)",
    Callback = function()
        -- Load WindUI config
        local configSuccess, configErr = pcall(function()
            zebuxConfig:Load()
        end)
        if not configSuccess then
            warn("Failed to load WindUI config: " .. tostring(configErr))
        end
        
        -- Load custom selections
        local customSuccess, customErr = pcall(function()
            loadCustomSelections()
        end)
        
        -- Note: Dropdown sync is now handled by AutoPlaceSystem.lua

        if customSuccess then
            WindUI:Notify({ Title = "✅ Manual Load", Content = "Settings loaded successfully!", Duration = 3 })
        else
            warn("Failed to load custom selections: " .. tostring(customErr))
            WindUI:Notify({ Title = "⚠️ Manual Load", Content = "Settings loaded but custom selections failed", Duration = 3 })
        end
    end
})

Tabs.SaveTab:Button({
    Title = "📤 Export Settings",
    Desc = "Export your settings to clipboard",
    Callback = function()
        local success, err = pcall(function()
            -- Get WindUI config data
            local configData = ConfigManager:AllConfigs()
            -- Combine with custom selections
            local exportData = {
                windUIConfig = configData,
                customSelections = customSelections
            }
            local jsonData = game:GetService("HttpService"):JSONEncode(exportData)
            setclipboard(jsonData)
        end)
        
        if success then
            WindUI:Notify({ 
                Title = "📤 Settings Exported", 
                Content = "Settings copied to clipboard! 🎉", 
                Duration = 3 
            })
        else
            WindUI:Notify({ 
                Title = "❌ Export Failed", 
                Content = "Failed to export settings: " .. tostring(err), 
                Duration = 5 
            })
        end
    end
})

Tabs.SaveTab:Button({
    Title = "📥 Import Settings",
    Desc = "Import settings from clipboard",
    Callback = function()
        local success, err = pcall(function()
            local clipboardData = getclipboard()
            local importedData = game:GetService("HttpService"):JSONDecode(clipboardData)
            
            if importedData and importedData.windUIConfig then
                -- Import WindUI config
                for configName, configData in pairs(importedData.windUIConfig) do
                    local config = ConfigManager:GetConfig(configName)
                    if config then
                        config:LoadFromData(configData)
                    end
                end
                
                -- Import custom selections
                if importedData.customSelections then
                    customSelections = importedData.customSelections
                    saveCustomSelections()
                end
                
                WindUI:Notify({ 
                    Title = "📥 Settings Imported", 
                    Content = "Settings imported successfully! 🎉", 
                    Duration = 3 
                })
            else
                error("Invalid settings format")
            end
        end)
        
        if not success then
            WindUI:Notify({ 
                Title = "❌ Import Failed", 
                Content = "Failed to import settings: " .. tostring(err), 
                Duration = 5 
            })
        end
    end
})

Tabs.SaveTab:Button({
    Title = "🔄 Reset Settings",
    Desc = "Reset all settings to default",
    Callback = function()
        Window:Dialog({
            Title = "🔄 Reset Settings",
            Content = "Are you sure you want to reset all settings to default?",
            Icon = "alert-triangle",
            Buttons = {
                {
                    Title = "❌ Cancel",
                    Variant = "Secondary",
                    Callback = function() end
                },
                {
                    Title = "✅ Reset",
                    Variant = "Primary",
                    Callback = function()
                        local success, err = pcall(function()
                            -- Delete WindUI config files
                            local configFiles = listfiles("WindUI/Zebux/config")
                            for _, file in ipairs(configFiles) do
                                if file:match("zebuxConfig%.json$") then
                                    delfile(file)
                                end
                            end
                            
                            -- Delete organized custom selections folder
                            if isfolder(CUSTOM_CFG_FOLDER) then
                                for _, f in ipairs(listfiles(CUSTOM_CFG_FOLDER)) do
                                    pcall(function() delfile(f) end)
                                end
                            end
                            
                            -- Reset custom selections
                            customSelections = {
                                eggSelections = {},
                                fruitSelections = {},
                                feedFruitSelections = {}
                            }
                            
                            -- Reset all variables to defaults
                            autoBuyEnabled = false
                            autoHatchEnabled = false
                            autoClaimEnabled = false
                            autoPlaceEnabled = false
                            autoUnlockEnabled = false
                            autoDeleteEnabled = false
                            -- autoDinoEnabled removed
                            autoUpgradeEnabled = false
                            autoBuyFruitEnabled = false
                            autoFeedEnabled = false
                            
                            selectedTypeSet = {}
                            selectedMutationSet = {}
                            selectedFruits = {}
                            selectedFeedFruits = {}
                            
                            -- Refresh UI if visible
                            local function safeRefresh(uiModule, moduleName)
                                if uiModule then
                                    if uiModule.RefreshContent then
                                        local ok, refreshErr = pcall(function()
                                            uiModule.RefreshContent()
                                        end)
                                        if not ok then
                                            warn("Failed to refresh " .. moduleName .. " UI: " .. tostring(refreshErr))
                                        end
                                    else
                                        warn(moduleName .. " UI module exists but has no RefreshContent method")
                                    end
                                else
                                    warn(moduleName .. " UI module is nil - not loaded yet")
                                end
                            end
                            
                            safeRefresh(EggSelection, "EggSelection")
                            safeRefresh(FruitSelection, "FruitSelection")
                            safeRefresh(FeedFruitSelection, "FeedFruitSelection")
                            
                            WindUI:Notify({ 
                                Title = "🔄 Settings Reset", 
                                Content = "All settings have been reset to default! 🎉", 
                                Duration = 3 
                            })
                        end)
                        
                        if not success then
                            warn("Failed to reset settings: " .. tostring(err))
                            WindUI:Notify({ 
                                Title = "⚠️ Reset Error", 
                                Content = "Failed to reset some settings. Please try again.", 
                                Duration = 3 
                            })
                        end
                    end
                }
            }
        })
    end
})

-- Auto-load settings after all UI elements are created
task.spawn(function()
    task.wait(3) -- Wait longer for UI to fully load
    
    -- Show loading notification
        WindUI:Notify({ 
        Title = "📂 Loading Settings", 
        Content = "Loading your saved settings...", 
        Duration = 2 
    })
    
    -- Register all UI elements with WindUI config
    registerUIElements()

    -- Load local SendTrash module and initialize its UI. Keep it after base UI exists so it can attach to Window and Config
    -- Load Send Trash System
    pcall(function()
        local sendTrashModule = nil
            local success, result = pcall(function()
                return loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/SendTrashSystem.lua"))()
            end)
            if success then
                sendTrashModule = result
        end
        if sendTrashModule and sendTrashModule.Init then
            sendTrashModule.Init({
                WindUI = WindUI,
                Window = Window,
                Config = zebuxConfig,
                Tab = Tabs.TrashTab
            })
        end
    end)
    
    -- Load Discord Webhook System (core functions only)
    pcall(function()
        local success, result = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/WebhookSystem.lua"))()
        end)
        
        if success then
            WebhookSystem = result
            -- Make WebhookSystem globally available for other modules
            _G.WebhookSystem = WebhookSystem
            
            -- Initialize core functions without UI
            if WebhookSystem and WebhookSystem.InitCore then
                WebhookSystem.InitCore({
                WindUI = WindUI,
                Window = Window,
                Config = zebuxConfig
            })
                
                -- Sync settings from config if available
                task.spawn(function()
                    -- Wait for UI elements to be created
                    local maxWait = 10
                    local waited = 0
                    while (not webhookUrlInput or not webhookAutoAlertToggle) and waited < maxWait do
                        task.wait(0.5)
                        waited = waited + 0.5
                    end
                    
                    -- Load saved webhook settings and apply to UI
                    if WebhookSystem.GetConfigElements then
                        local config = WebhookSystem.GetConfigElements()
                        
                        if config.webhookUrl and string.len(config.webhookUrl) > 0 then
                            webhookUrl = config.webhookUrl
                            if webhookUrlInput and webhookUrlInput.SetValue then
                                webhookUrlInput:SetValue(config.webhookUrl)
                            end
                        end
                        
                        if config.autoAlertEnabled ~= nil then
                            autoAlertEnabled = config.autoAlertEnabled
                            if webhookAutoAlertToggle and webhookAutoAlertToggle.SetValue then
                                webhookAutoAlertToggle:SetValue(config.autoAlertEnabled)
                            end
                        end
                    end
                end)
            end
        end
    end)
    
    -- Enhanced auto-load using new config system
    local loadResults = loadAllConfigs()
    
    -- Count successful loads
    local successCount = 0
    local totalCount = 0
    for category, result in pairs(loadResults) do
        totalCount = totalCount + 1
        if result:find("✅") then
            successCount = successCount + 1
        end
    end
    
    -- Auto-load operation completed
    
    -- Note: UI sync is now handled by AutoPlaceSystem.lua

    -- Show appropriate notification based on results
    local notificationTitle = "📂 Auto-Load Complete"
    local notificationContent
    
    if successCount == totalCount then
        notificationContent = string.format("All %d config categories loaded successfully! 🎉", totalCount)
    elseif successCount > 0 then
        notificationContent = string.format("Loaded %d/%d config categories (partial success)", successCount, totalCount)
    else
        notificationContent = "No configs found - using default settings"
        notificationTitle = "📂 Auto-Load (Defaults)"
    end

    WindUI:Notify({ 
        Title = notificationTitle, 
        Content = notificationContent, 
            Duration = 3 
        })
    _G.ZebuxState.settingsLoaded = true
end)

-- ============ Auto Feed ============
Tabs.ShopTab:Section({ Title = "Auto Feed", Icon = "coffee" })

-- Feed Fruit Selection UI Button
Tabs.ShopTab:Button({
    Title = "Open Feed Fruit Selection UI",
    Desc = "Select fruits to feed pets",
    Callback = function()
        if not feedFruitSelectionVisible then
            FeedFruitSelection.Show(
                function(selectedItems)
                    -- Handle selection changes
                    selectedFeedFruits = selectedItems
                    updateCustomUISelection("feedFruitSelections", selectedItems)
                end,
                function(isVisible)
                    feedFruitSelectionVisible = isVisible
                end,
                selectedFeedFruits -- Pass saved fruit selections
            )
            feedFruitSelectionVisible = true
        else
            FeedFruitSelection.Hide()
            feedFruitSelectionVisible = false
        end
    end
})

-- Auto Feed Toggle
autoFeedToggle = Tabs.ShopTab:Toggle({
    Title = "Auto Feed Pets",
    Desc = "Feed big pets with selected fruits",
    Value = false,
    Callback = function(state)
        autoFeedEnabled = state
        
        waitForSettingsReady(0.2)
        if state and not autoFeedThread then
            autoFeedThread = task.spawn(function()
                -- Ensure selections are loaded before starting
                local function getSelected()
                    -- if empty, try to lazy-load from file once
                    if not selectedFeedFruits or not next(selectedFeedFruits) then
                        pcall(function()
                            local data = loadJSONCustom("FeedFruitSelections.json")
                            if data and data.fruits then
                                selectedFeedFruits = {}
                                for _, id in ipairs(data.fruits) do selectedFeedFruits[id] = true end
                            end
                        end)
                    end
                    return selectedFeedFruits
                end
                
                -- Wrap the auto feed call in error handling
                local ok, err = pcall(function()
                    AutoFeedSystem.runAutoFeed(autoFeedEnabled, {}, function() end, getSelected)
                end)
                
                if not ok then
                    warn("Auto Feed thread error: " .. tostring(err))
                    WindUI:Notify({ 
                        Title = "Auto Feed Error", 
                        Content = "Auto Feed stopped due to error: " .. tostring(err), 
                        Duration = 5 
                    })
                end
                
                autoFeedThread = nil
            end)
            WindUI:Notify({ Title = "Auto Feed", Content = "Started - Feeding Big Pets! 🎉", Duration = 3 })
        elseif (not state) and autoFeedThread then
            WindUI:Notify({ Title = "Auto Feed", Content = "Stopped", Duration = 3 })
        end
    end
})

-- Late-register Auto Feed toggle after it exists, then re-load to apply saved value
task.spawn(function()
    -- Wait until settings load sequence either completed or shortly timed in
    local tries = 0
    while not (zebuxConfig and autoFeedToggle) and tries < 50 do
        tries += 1
        task.wait(0.05)
    end
    if autoSystemsConfig and autoFeedToggle then
        pcall(function()
            autoSystemsConfig:Register("autoFeedEnabled", autoFeedToggle)
            -- If settings already loaded, load again to apply saved value to this control
            if settingsLoaded then
                autoSystemsConfig:Load()
            end
        end)
    end
end)

-- Late-register Auto Fish toggle after it exists, then re-load to apply saved value
-- AutoFish toggle registration will be handled by AutoFishSystem.lua itself
-- No need to register here since it's a separate system






-- ============ Discord Webhook UI ============
-- UI elements in main file, core functions from WebhookSystem module

-- Create webhook UI elements
Tabs.WebhookTab:Section({ Title = "Discord Integration", Icon = "webhook" })


-- Webhook URL Input
webhookUrlInput = Tabs.WebhookTab:Input({
    Title = "Discord Webhook URL",
    Desc = "Enter your Discord webhook URL",
    Value = webhookUrl,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(input)
        webhookUrl = input or ""
        if WebhookSystem and WebhookSystem.SetWebhookUrl then
            WebhookSystem.SetWebhookUrl(input)
        end
    end
})

-- Inventory sort mode dropdown
local webhookSortDropdown = Tabs.WebhookTab:Dropdown({
    Title = "Inventory Sort Mode",
    Desc = "Choose how inventory is summarized in webhook",
    Values = {"Most Count","Least Count","Egg Mutation Most","Pet Highest Speed"},
    Value = "Most Count",
    Callback = function(v)
        if WebhookSystem and WebhookSystem.SetInventorySortMode then
            local map = {
                ["Most Count"] = "most_count",
                ["Least Count"] = "least_count",
                ["Egg Mutation Most"] = "egg_mutation_most",
                ["Pet Highest Speed"] = "pet_highest_speed",
            }
            WebhookSystem.SetInventorySortMode(map[v] or "most_count")
            _G.WebhookInventorySortMode = map[v] or "most_count"
        end
    end
})

-- Send Inventory Button
Tabs.WebhookTab:Button({
    Title = "Send Inventory",
    Desc = "Send current inventory snapshot to Discord",
    Icon = "send",
    Callback = function()
        if WebhookSystem and WebhookSystem.SendInventory then
            WebhookSystem.SendInventory()
        else
            WindUI:Notify({
                Title = "Webhook Error",
                Content = "Webhook system not loaded",
                Duration = 3
            })
        end
    end
})

Tabs.WebhookTab:Divider()

-- Auto Alert Toggle
webhookAutoAlertToggle = Tabs.WebhookTab:Toggle({
    Title = "Auto Alert",
    Desc = "Automatically send alerts for trades and desired items",
    Icon = "bell",
    Value = autoAlertEnabled,
    Callback = function(state)
        autoAlertEnabled = state
        
        -- Update core system if loaded
        if WebhookSystem and WebhookSystem.SetAutoAlert then
            WebhookSystem.SetAutoAlert(state)
        end
        
        if state then
            WindUI:Notify({
                Title = "Auto Alert",
                Content = "Auto alert system started",
                Duration = 3
            })
        else
            WindUI:Notify({
                Title = "Auto Alert",
                Content = "Auto alert system stopped",
                Duration = 3
            })
        end
    end
})

-- Session Stats Display
Tabs.WebhookTab:Paragraph({
    Title = "Session Statistics",
    Desc = "Current session tracking data for alerts",
    Image = "bar-chart",
    ImageSize = 16
})

-- Test Alert Button
Tabs.WebhookTab:Button({
    Title = "Test Alert",
    Desc = "Send a test alert to verify webhook",
    Icon = "zap",
    Callback = function()
        if WebhookSystem and WebhookSystem.SendAlert then
            WebhookSystem.SendAlert("Test Alert", "This is a test alert from the webhook system.")
        else
            WindUI:Notify({
                Title = "Webhook Error",
                Content = "Webhook system not loaded",
                Duration = 3
            })
        end
    end
})

-- Register webhook UI elements with config system
task.spawn(function()
    task.wait(1) -- Wait for config system to be ready
    if autoSystemsConfig then
        pcall(function()
            autoSystemsConfig:Register("webhookUrlInput", webhookUrlInput)
            autoSystemsConfig:Register("webhookAutoAlertToggle", webhookAutoAlertToggle)
            autoSystemsConfig:Register("webhookInventorySortMode", webhookSortDropdown)
        end)
    end
end)

-- Safe window close handler
pcall(function()
Window:OnClose(function()
        -- Window closed
end)
end)

-- Setup open button immediately after window creation
Window:EditOpenButton({
    Title = "🏗️ Build A Zoo",
    Icon = "monitor", 
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 2,
    Color = ColorSequence.new( -- gradient
        Color3.fromHex("FF0F7B"), 
        Color3.fromHex("F89B29")
    ),
    OnlyMobile = false,  -- Shows on both desktop and mobile
    Enabled = true,      -- Always enabled
    Draggable = true,    -- Can be moved around
})

-- Build A Zoo UI button created

-- Anti-AFK system loads automatically from GitHub via the task.spawn above
-- No additional setup needed as it auto-starts


