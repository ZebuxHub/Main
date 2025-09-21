-- SendTrashSystem.lua - Send/Sell Unwanted Pets Module for Build A Zoo
-- Lua 5.1 Compatible

local SendTrashSystem = {}

-- Hardcoded pet types and mutations for filtering (from game data)
local HardcodedPetTypes = {
    "Capy1", "Capy2", "Pig", "Capy3", "Dog", "AngelFish", "Cat", "CapyL1", "Cow", "CapyL2", 
    "Sheep", "CapyL3", "Horse", "Zebra", "Bighead", "Giraffe", "Hippo", "Elephant", "Rabbit", 
    "Mouse", "Butterflyfish", "Ankylosaurus", "Needlefish", "Wolverine", "Tiger", "Fox", "Hairtail", 
    "Panda", "Tuna", "Catfish", "Toucan", "Bee", "Snake", "Butterfly", "Tigerfish", "Okapi", 
    "Panther", "Penguin", "Velociraptor", "Stegosaurus", "Seaturtle", "Bear", "Flounder", "Lion", 
    "Lionfish", "Rhino", "Kangroo", "Gorilla", "Alligator", "Ostrich", "Triceratops", "Pachycephalosaur", 
    "Sawfish", "Pterosaur", "ElectricEel", "Wolf", "Rex", "Dolphin", "Dragon", "Baldeagle", "Shark", 
    "Griffin", "Brontosaurus", "Anglerfish", "Plesiosaur", "Alpaca", "Spinosaurus", "Manta", "Unicorn", 
    "Phoenix", "Toothless", "Tyrannosaurus", "Mosasaur", "Octopus", "Killerwhale", "Peacock"
}

local HardcodedEggTypes = {
    "BasicEgg", "RareEgg", "SuperRareEgg", "SeaweedEgg", "EpicEgg", "LegendEgg", "ClownfishEgg", 
    "PrismaticEgg", "LionfishEgg", "HyperEgg", "VoidEgg", "BowserEgg", "SharkEgg", "DemonEgg", 
    "CornEgg", "AnglerfishEgg", "BoneDragonEgg", "UltraEgg", "DinoEgg", "FlyEgg", "UnicornEgg", 
    "OctopusEgg", "AncientEgg", "SeaDragonEgg", "UnicornProEgg"
}

local HardcodedMutations = {
    "Golden", "Diamond", "Electric", "Fire", "Dino"
}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- UI Variables
local WindUI
local Window
local Config
-- All other UI variables removed - only Auto Trade UI button remains

-- State variables (most removed since UI elements are gone)
-- Only keeping essential variables for the Auto Trade UI integration

-- Blacklist & sticky removed per request; using round-robin random dispatch

-- Inventory Cache System (like auto place)
local inventoryCache = {
    pets = {},
    eggs = {},
    lastUpdateTime = 0,
    updateInterval = 0.5, -- Update every 0.5 seconds
    unknownCount = 0 -- Track items that couldn't load properly
}

-- Unknown resolver removed per user request
-- local unknownResolver = {
-- 	pets = {},
-- 	eggs = {},
-- 	active = false
-- }

-- Live data watchers (event-driven cache updates)
local dataWatch = {
    petConns = {},
    eggConns = {},
    rootConns = {}
}

local function disconnectConn(conn)
    if conn then pcall(function() conn:Disconnect() end) end
end

-- Canonicalize mutation names (deduplicate typos like Electric/Electirc)
local function canonicalizeMutationName(name)
    if not name or name == "" then return name end
    local lower = tostring(name):lower()
    if lower == "electric" or lower == "electirc" then return "Electirc" end
    if lower == "dino" then return "Dino" end
    if lower == "golden" then return "Golden" end
    if lower == "diamond" then return "Diamond" end
    if lower == "fire" then return "Fire" end
    return name
end

local function clearConnSet(set)
    if not set then return end
    for _, c in pairs(set) do disconnectConn(c) end
end

local function upsertFromConf(conf, isEgg)
    if not conf or not conf:IsA("Configuration") then return end
    local okT, tVal = pcall(function() return conf:GetAttribute("T") end)
    if not okT or not tVal or tVal == "" then return end
    local okM, mVal = pcall(function() return conf:GetAttribute("M") end)
    local okS, speedVal = pcall(function() return conf:GetAttribute("Speed") end)
    local okLK, lkVal = pcall(function() return conf:GetAttribute("LK") end)
    local okD, dVal = pcall(function() return conf:GetAttribute("D") end)
    local record = {
        uid = conf.Name,
        type = tVal,
        mutation = (okM and mVal) or "",
        locked = (okLK and lkVal == 1) or false,
        placed = (okD and dVal ~= nil) or false
    }
    if not isEgg then
        record.speed = (okS and speedVal) or 0
    end
    if isEgg then
        inventoryCache.eggs[conf.Name] = record
        -- unknownResolver.eggs[conf.Name] = nil -- This line is removed
    else
        inventoryCache.pets[conf.Name] = record
        -- unknownResolver.pets[conf.Name] = nil -- This line is removed
    end
end

local function watchConf(conf, isEgg)
    if not conf or not conf:IsA("Configuration") then return end
    -- Initial attempt
    upsertFromConf(conf, isEgg)
    -- Attribute watchers
    local tConn = conf:GetAttributeChangedSignal("T"):Connect(function()
        upsertFromConf(conf, isEgg)
    end)
    local mConn = conf:GetAttributeChangedSignal("M"):Connect(function()
        upsertFromConf(conf, isEgg)
    end)
    local set = isEgg and dataWatch.eggConns or dataWatch.petConns
    set[conf] = { tConn, mConn }
end

local function startDataWatchers()
    -- Avoid duplicates
    if dataWatch.rootConns.started then return end
    local dataRoot = LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Data")
    if not dataRoot then return end
    local petsFolder = dataRoot:FindFirstChild("Pets")
    local eggsFolder = dataRoot:FindFirstChild("Egg")
    if petsFolder then
        for _, ch in ipairs(petsFolder:GetChildren()) do
            watchConf(ch, false)
        end
        local addConn = petsFolder.ChildAdded:Connect(function(ch) watchConf(ch, false) end)
        local remConn = petsFolder.ChildRemoved:Connect(function(ch)
            local conns = dataWatch.petConns[ch]
            if conns then for _, c in ipairs(conns) do disconnectConn(c) end end
            dataWatch.petConns[ch] = nil
            inventoryCache.pets[ch.Name] = nil
        end)
        table.insert(dataWatch.rootConns, addConn)
        table.insert(dataWatch.rootConns, remConn)
    end
    if eggsFolder then
        for _, ch in ipairs(eggsFolder:GetChildren()) do
            watchConf(ch, true)
        end
        local addConn = eggsFolder.ChildAdded:Connect(function(ch) watchConf(ch, true) end)
        local remConn = eggsFolder.ChildRemoved:Connect(function(ch)
            local conns = dataWatch.eggConns[ch]
            if conns then for _, c in ipairs(conns) do disconnectConn(c) end end
            dataWatch.eggConns[ch] = nil
            inventoryCache.eggs[ch.Name] = nil
        end)
        table.insert(dataWatch.rootConns, addConn)
        table.insert(dataWatch.rootConns, remConn)
    end
    dataWatch.rootConns.started = true
end

local function stopDataWatchers()
    clearConnSet(dataWatch.rootConns)
    for conf, conns in pairs(dataWatch.petConns) do for _, c in ipairs(conns) do disconnectConn(c) end end
    for conf, conns in pairs(dataWatch.eggConns) do for _, c in ipairs(conns) do disconnectConn(c) end end
    dataWatch.petConns = {}
    dataWatch.eggConns = {}
    dataWatch.rootConns = {}
end

-- Remove unknown resolver helpers
-- local function trackUnknown(uid, isEgg) end
-- local function startUnknownResolver() end

-- Send operation tracking
local sendInProgress = {}
local sendTimeoutSeconds = 5
local perItemCooldownSeconds = 1.2
local pendingCooldownUntil = {}

-- Wait for a specific inventory item to be removed (conf deleted) with event + polling
local function waitForInventoryRemoval(itemUID, isEgg, timeoutSecs)
    local dataRoot = LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Data")
    if not dataRoot then return false end
    local folder = dataRoot:FindFirstChild(isEgg and "Egg" or "Pets")
    if not folder then return false end

    -- Already removed
    local existing = folder:FindFirstChild(itemUID)
    if not existing then return true end

    local removed = false
    local conn
    conn = folder.ChildRemoved:Connect(function(child)
        if child and child.Name == itemUID then
            removed = true
        end
    end)

    local deadline = os.clock() + (timeoutSecs or 2.5)
    while os.clock() < deadline and not removed do
        if not folder:FindFirstChild(itemUID) then
            removed = true
            break
        end
        task.wait(0.05)
    end

    if conn then pcall(function() conn:Disconnect() end) end
    return removed
end

-- Session management removed since UI is gone

-- Webhook and icon mapping removed since not needed



-- Helper function to safely get attribute
local function safeGetAttribute(obj, attrName, default)
    if not obj then return default end
    local success, result = pcall(function()
        return obj:GetAttribute(attrName)
    end)
    return success and result or default
end

-- Helper function to parse speed input with K/M/B/T suffixes
local function parseSpeedInput(text)
    if not text or type(text) ~= "string" then return 0 end
    
    local cleanText = text:gsub("[$€£¥₹/s,]", ""):gsub("^%s*(.-)%s*$", "%1")
    local number, suffix = cleanText:match("^([%d%.]+)([KkMmBbTt]?)$")
    
    if not number then
        number = cleanText:match("([%d%.]+)")
    end
    
    local numValue = tonumber(number)
    if not numValue then return 0 end
    
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

-- Get pet speed from UI (same as AutoSellSystem)
local function getPetSpeed(petNode)
    if not petNode then return 0 end
    -- Prefer real value from UI using the pet UID
    local uid = petNode.Name
    local lp = Players.LocalPlayer
    local pg = lp and lp:FindFirstChild("PlayerGui")
    local ss = pg and pg:FindFirstChild("ScreenStorage")
    local frame = ss and ss:FindFirstChild("Frame")
    local content = frame and frame:FindFirstChild("ContentPet")
    local scroll = content and content:FindFirstChild("ScrollingFrame")
    local item = scroll and scroll:FindFirstChild(uid)
    local btn = item and item:FindFirstChild("BTN")
    local stat = btn and btn:FindFirstChild("Stat")
    local price = stat and stat:FindFirstChild("Price")
    local valueLabel = price and price:FindFirstChild("Value")
    local txt = valueLabel and valueLabel:IsA("TextLabel") and valueLabel.Text or nil
    if not txt and price and price:IsA("TextLabel") then
        txt = price.Text
    end
    if txt then
        local n = tonumber((txt:gsub("[^%d]", ""))) or 0
        return n
    end
    return 0
end

-- Get all pet types from inventory + hardcoded list
local function getAllPetTypes()
    local types = {}
    
    -- Add hardcoded types
    for _, petType in ipairs(HardcodedPetTypes) do
        types[petType] = true
    end
    
    -- Add types from inventory
    if LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui.Data then
        local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
        if petsFolder then
            for _, petData in pairs(petsFolder:GetChildren()) do
                if petData:IsA("Configuration") then
                    local petType = safeGetAttribute(petData, "T", nil)
                    if petType then
                        types[petType] = true
                    end
                end
            end
        end
    end
    
    -- Convert to sorted array
    local sortedTypes = {}
    for petType in pairs(types) do
        table.insert(sortedTypes, petType)
    end
    table.sort(sortedTypes)
    
    return sortedTypes
end

-- Get all egg types from inventory + hardcoded list
local function getAllEggTypes()
    local types = {}
    
    -- Add hardcoded egg types
    for _, eggType in ipairs(HardcodedEggTypes) do
        types[eggType] = true
    end
    
    -- Add types from inventory
    if LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui.Data then
        local eggsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
        if eggsFolder then
            for _, eggData in pairs(eggsFolder:GetChildren()) do
                if eggData:IsA("Configuration") then
                    local eggType = safeGetAttribute(eggData, "T", nil)
                    if eggType then
                        types[eggType] = true
                    end
                end
            end
        end
    end
    
    -- Convert to sorted array
    local sortedTypes = {}
    for eggType in pairs(types) do
        table.insert(sortedTypes, eggType)
    end
    table.sort(sortedTypes)
    
    return sortedTypes
end

-- Get all mutations from inventory + hardcoded list
local function getAllMutations()
    local mutations = {}
    
    -- Add hardcoded mutations (canonicalized)
    for _, mutation in ipairs(HardcodedMutations) do
        mutations[canonicalizeMutationName(mutation)] = true
    end
    
    -- Add mutations from inventory
    if LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui.Data then
        local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
        if petsFolder then
            for _, petData in pairs(petsFolder:GetChildren()) do
                if petData:IsA("Configuration") then
                    local petMutation = canonicalizeMutationName(safeGetAttribute(petData, "M", nil))
                    if petMutation and petMutation ~= "" then
                        mutations[petMutation] = true
                    end
                end
            end
        end
    end
    
    -- Convert to sorted array
    local sortedMutations = {}
    for mutation in pairs(mutations) do
        table.insert(sortedMutations, mutation)
    end
    table.sort(sortedMutations)
    
    return sortedMutations
end

-- Get player list for sending pets
local function refreshPlayerList()
    local playerList = {"Random Player"}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerList, player.Name)
        end
    end
    
    return playerList
end

-- Resolve target player by either Username or DisplayName (case-insensitive)
local function resolveTargetPlayerByName(name)
    if not name or name == "" then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == name or p.DisplayName == name then
            return p
        end
        -- case-insensitive fallback
        if string.lower(p.Name) == string.lower(name) or string.lower(p.DisplayName) == string.lower(name) then
            return p
        end
    end
    return nil
end

local function isPlayerValid(p)
	return p and p.Parent == Players
end

local function pickRandomTarget(excludeUserId)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and (not excludeUserId or p.UserId ~= excludeUserId) then
			table.insert(list, p)
		end
	end
	if #list == 0 then return nil end
	return list[math.random(1, #list)]
end

-- Get random player
local function getRandomPlayer()
	local players = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			table.insert(players, player)
		end
	end
	if #players > 0 then
		return players[math.random(1, #players)] -- return Player object
	end
	return nil
end

-- Get a randomized list of up to N candidate players (Player objects)
	local function getRoundRobinTargets()
		local pool = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				table.insert(pool, player)
			end
		end
		table.sort(pool, function(a, b) return a.UserId < b.UserId end)
		return pool
	end

-- Convert dropdown selection into a plain string list
local function selectionToList(selection)
    local result = {}
    if type(selection) == "table" then
        -- Handle either array-style or set-style tables
        local hasIndexed = false
        for k, v in pairs(selection) do
            if type(k) == "number" then
                hasIndexed = true
                break
            end
        end
        if hasIndexed then
            for _, v in ipairs(selection) do
                v = tostring(v)
                if v ~= "" and v ~= "--" then table.insert(result, v) end
            end
        else
            for k, v in pairs(selection) do
                if v == true and type(k) == "string" and k ~= "--" and k ~= "" then
                    table.insert(result, k)
                end
            end
        end
    elseif type(selection) == "string" then
        if selection ~= "" and selection ~= "--" then table.insert(result, selection) end
    end
    return result
end

-- Sync function removed since UI controls are gone

-- Get pet inventory
--- Update inventory cache for better performance
local function updateInventoryCache()
    local currentTime = tick()
    if currentTime - inventoryCache.lastUpdateTime < inventoryCache.updateInterval then
        return -- Don't update too frequently
    end
    
    inventoryCache.lastUpdateTime = currentTime
    inventoryCache.pets = {}
    inventoryCache.eggs = {}
    inventoryCache.unknownCount = 0
    
    if not LocalPlayer or not LocalPlayer.PlayerGui or not LocalPlayer.PlayerGui.Data then
        return
    end
    
    -- Update pets cache
    local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
    if petsFolder then
        for _, petData in pairs(petsFolder:GetChildren()) do
            if petData:IsA("Configuration") then
                -- Try multiple attributes and wait for data to load
                local petType = safeGetAttribute(petData, "T", nil)
                
                -- Skip items without proper type data (not fully loaded yet)
                if not petType or petType == "" or petType == "Unknown" then
                    inventoryCache.unknownCount = inventoryCache.unknownCount + 1
                    continue -- Skip this pet until it loads properly
                end
                
                local petInfo = {
                    uid = petData.Name,
                    type = petType,
                    mutation = safeGetAttribute(petData, "M", ""),
                    speed = safeGetAttribute(petData, "Speed", 0),
                    locked = safeGetAttribute(petData, "LK", 0) == 1,
                    placed = safeGetAttribute(petData, "D", nil) ~= nil
                }
                inventoryCache.pets[petData.Name] = petInfo
            end
        end
    end
    
    -- Update eggs cache
    local eggsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
    if eggsFolder then
        for _, eggData in pairs(eggsFolder:GetChildren()) do
            if eggData:IsA("Configuration") then
                -- Try multiple attributes and wait for data to load
                local eggType = safeGetAttribute(eggData, "T", nil)
                
                -- Skip items without proper type data (not fully loaded yet)
                if not eggType or eggType == "" or eggType == "Unknown" then
                    inventoryCache.unknownCount = inventoryCache.unknownCount + 1
                    continue -- Skip this egg until it loads properly
                end
                
                local eggInfo = {
                    uid = eggData.Name,
                    type = eggType,
                    mutation = safeGetAttribute(eggData, "M", ""),
                    locked = safeGetAttribute(eggData, "LK", 0) == 1,
                    placed = safeGetAttribute(eggData, "D", nil) ~= nil
                }
                inventoryCache.eggs[eggData.Name] = eggInfo
            end
        end
    end
    
    -- If there are unknowns, start background resolver
    if inventoryCache.unknownCount > 0 then
        -- startUnknownResolver()
    end
end

--- Verify item still exists in inventory
local function verifyItemExists(itemUID, isEgg)
    updateInventoryCache()
    if isEgg then
        return inventoryCache.eggs[itemUID] ~= nil
    else
        return inventoryCache.pets[itemUID] ~= nil
    end
end

--- Force cache refresh (useful for immediate updates)
local function forceRefreshCache()
    inventoryCache.lastUpdateTime = 0
    updateInventoryCache()
end

--- Force refresh with data reload (for "Unknown" items)
local function forceDataReload()
    -- Clear cache completely
    inventoryCache.lastUpdateTime = 0
    inventoryCache.pets = {}
    inventoryCache.eggs = {}
    
    -- Wait a moment for game data to settle
    task.wait(0.5)
    
    -- Force multiple cache updates to catch data as it loads
    for i = 1, 3 do
        updateInventoryCache()
        task.wait(0.2)
    end
    
    -- Count items that loaded successfully
    local loadedPets = 0
    local loadedEggs = 0
    for _, pet in pairs(inventoryCache.pets) do
        if pet.type and pet.type ~= "" and pet.type ~= "Unknown" then
            loadedPets = loadedPets + 1
        end
    end
    for _, egg in pairs(inventoryCache.eggs) do
        if egg.type and egg.type ~= "" and egg.type ~= "Unknown" then
            loadedEggs = loadedEggs + 1
        end
    end
    
    return loadedPets, loadedEggs
end

-- Actively focus unresolved items to force replication of T/M
local function forceResolveAllNames()
	return 0, 0
end

--- Clear send operation tracking
local function clearSendProgress()
    sendInProgress = {}
end

--- Save webhook URL to config
local function saveWebhookUrl(url)
    webhookUrl = tostring(url or "")
    if Config and Config.SaveSetting then
        Config:SaveSetting("SendTrash_WebhookUrl", webhookUrl)
        if WindUI then
            WindUI:Notify({
                Title = "💾 Webhook Saved",
                Content = webhookUrl ~= "" and "Webhook URL saved successfully!" or "Webhook URL cleared",
                Duration = 2
            })
        end
    else
        if WindUI then
            WindUI:Notify({
                Title = "⚠️ Config System",
                Content = "Config system not available - webhook won't persist",
                Duration = 3
            })
        end
    end
end

--- Load webhook URL from config
local function loadWebhookUrl()
    if Config and Config.GetSetting then
        local savedUrl = Config:GetSetting("SendTrash_WebhookUrl")
        if savedUrl and savedUrl ~= "" then
            webhookUrl = tostring(savedUrl)
            return true -- Successfully loaded
        end
    end
    return false -- No saved URL or config unavailable
end

--- Get pet inventory (uses cache for better performance)
local function getPetInventory()
    updateInventoryCache()
    local pets = {}
    for _, pet in pairs(inventoryCache.pets) do
        table.insert(pets, pet)
    end
    return pets
end

--- Get egg inventory (uses cache for better performance)
local function getEggInventory()
    updateInventoryCache()
    local eggs = {}
    for _, egg in pairs(inventoryCache.eggs) do
        table.insert(eggs, egg)
    end
    return eggs
end

-- Inventory webhook function removed since not needed

-- Refresh live attributes (T/M/locked/placed) for a given uid directly from PlayerGui.Data
local function refreshItemFromData(uid, isEgg, into)
    local dataRoot = LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Data")
    if not dataRoot then return into end
    local folder = dataRoot:FindFirstChild(isEgg and "Egg" or "Pets")
    if not folder then return into end
    local conf = folder:FindFirstChild(uid)
    if conf and conf:IsA("Configuration") then
        -- Try multiple attributes for better type detection
        local tVal
        tVal = safeGetAttribute(conf, "T", nil)
        
        -- Skip items that haven't loaded type data yet
        if not tVal or tVal == "" or tVal == "Unknown" then
            return into -- Return unchanged if data isn't ready yet
        end
        
        if into then
            into.type = tVal
            into.mutation = safeGetAttribute(conf, "M", into.mutation)
            into.locked = safeGetAttribute(conf, "LK", 0) == 1
            into.placed = safeGetAttribute(conf, "D", nil) ~= nil
            return into
        else
            return { uid = uid, type = tVal, mutation = safeGetAttribute(conf, "M", ""), locked = safeGetAttribute(conf, "LK", 0) == 1, placed = safeGetAttribute(conf, "D", nil) ~= nil }
        end
    end
    return into
end

-- Re-verify live item data against current selectors before sending
local shouldSendItem
local function verifyItemMatchesFiltersLive(uid, isEgg, includeTypes, includeMutations)
    -- Read fresh snapshot from PlayerGui.Data
    local fresh = refreshItemFromData(uid, isEgg, nil)
    if not fresh then return false end
    -- Reuse shouldSendItem logic using the fresh record
    return shouldSendItem(fresh, includeTypes, includeMutations, isEgg), fresh
end

-- Check if item should be sent/sold based on filters
function shouldSendItem(item, includeTypes, includeMutations, isEgg)
    -- Don't send locked items
    if item.locked then return false end
    
    -- For pets: speed filtering removed since UI controls are gone
    if not isEgg then
        return true -- Accept all pets since no filtering UI
    end
    
    -- For eggs: keep the original type/mutation filtering logic
    -- Normalize values for robust comparison
    local function norm(v)
        return v and tostring(v):lower() or nil
    end
    local itemType = norm(item.type)
    local itemMut  = item.mutation and norm(canonicalizeMutationName(item.mutation)) or nil
    
    -- STRICT: require a valid T (type) to exist
    if not itemType or itemType == "" or itemType == "unknown" then
        return false
    end
    
    -- Build lookup sets for O(1) checks
    local typesSet, mutsSet
    if includeTypes and #includeTypes > 0 then
        typesSet = {}
        for _, t in ipairs(includeTypes) do typesSet[norm(t)] = true end
        if not typesSet[itemType] then return false end
    end
    if includeMutations and #includeMutations > 0 then
        -- STRICT for M: if selectors provided, item must have an M and it must match
        if not itemMut or itemMut == "" then return false end
        mutsSet = {}
        for _, m in ipairs(includeMutations) do mutsSet[norm(canonicalizeMutationName(m))] = true end
        if not mutsSet[itemMut] then return false end
    end
    
    return true
end

-- Remove placed item from ground
local function removeFromGround(itemUID)
    local success, err = pcall(function()
        local args = {"Del", itemUID}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    if not success then
        warn("❌ Failed to remove item " .. itemUID .. " from ground: " .. tostring(err))
    end
    
    return success
end

-- Focus pet/egg before sending/selling (exactly like manual method)
local function focusItem(itemUID)
    local success, err = pcall(function()
        local args = {"Focus", itemUID}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    if not success then
        warn("❌ Failed to focus item " .. itemUID .. ": " .. tostring(err))
    end
    
    return success
end

-- Send item (pet or egg) to player
--- Send item function simplified since session limits removed
local function sendItemToPlayer(item, target, itemType)

	local itemUID = item.uid
	local isEgg = itemType == "egg"

	-- Prevent parallel/rapid sends for the same item (cooldown + in-progress)
	local nowClock = os.clock()
	local untilTs = pendingCooldownUntil[itemUID]
	if untilTs and nowClock < untilTs then
		return false
	end
	if sendInProgress[itemUID] then return false end
	sendInProgress[itemUID] = true

	-- Verify item exists before attempting to send
	if not verifyItemExists(itemUID, isEgg) then
		sendInProgress[itemUID] = nil
		return false
	end

	-- Resolve target (accept Player instance or name)
	local targetPlayerObj = nil
	if typeof(target) == "Instance" then
		if target:IsA("Player") then targetPlayerObj = target end
	elseif type(target) == "string" then
		targetPlayerObj = resolveTargetPlayerByName(target)
	end
	if not targetPlayerObj then
		sendInProgress[itemUID] = nil
		return false -- silently skip
	end

	local success = false

	-- Skip placed items; do not auto-remove from ground
	if item.placed then
		sendInProgress[itemUID] = nil
		return false
	end

	-- Focus the item first (REQUIRED)
	local focusSuccess = focusItem(itemUID)
	if focusSuccess then task.wait(0.1) end

	-- Filter verification removed since UI controls are gone

	-- Ensure player is still online
	if not targetPlayerObj or targetPlayerObj.Parent ~= Players then
		sendInProgress[itemUID] = nil
		return false
	end

	-- Attempt to send (single attempt, we confirm via removal)
	local sendSuccess, _ = pcall(function()
		local args = { targetPlayerObj }
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(unpack(args))
	end)

	if sendSuccess then
		-- Robust confirmation: wait until inventory actually removes the item
		local removed = waitForInventoryRemoval(itemUID, isEgg, 3.0)
		if removed then
			success = true
			-- Session tracking removed
		else
			success = false
		end
	end

	sendInProgress[itemUID] = nil

	-- Apply per-item cooldown regardless of success to avoid hammering
	pendingCooldownUntil[itemUID] = os.clock() + perItemCooldownSeconds

	if success then
		WindUI:Notify({ Title = "✅ Sent Successfully", Content = itemType:gsub("^%l", string.upper) .. " " .. (item.type or "Unknown") .. " → " .. targetPlayerObj.Name, Duration = 2 })
		
		-- Send webhook notification for successful trade
		if _G.WebhookSystem and _G.WebhookSystem.SendTradeWebhook then
			local fromItems = {{
				type = item.type,
				mutation = (item.mutation ~= nil and item.mutation ~= "" and item.mutation) or "",
				count = 1
			}}
			_G.WebhookSystem.SendTradeWebhook(LocalPlayer.Name, targetPlayerObj.Name, fromItems, {})
		end
	else
		-- silent fail (no spam)
	end

	return success
end

-- Sell pet (only pets, no eggs)
-- Selling pets has been removed per user request

-- Auto-delete slow pets
-- auto-delete slow pets removed per request

-- Main processing functions removed since UI elements are gone
-- Only Auto Trade UI integration remains

-- Initialize function
function SendTrashSystem.Init(dependencies)
    WindUI = dependencies.WindUI
    Window = dependencies.Window
    Config = dependencies.Config
    local providedTab = dependencies.Tab
    
    -- Load saved webhook URL from config
    -- webhook load disabled
    
    -- Start precise event-driven watchers for T/M replication
    startDataWatchers()
    
    -- Create the Send Trash tab (or reuse provided Tab from main script)
    local TrashTab = providedTab or Window:Tab({ Title = "🗑️ | Send Trash"})
    
    -- All other UI elements removed - only Auto Trade UI button remains
    
    TrashTab:Section({ Title = "🔄 Auto Trade System", Icon = "arrow-right" })
    
    -- Auto Trade UI Button with toggle functionality
    TrashTab:Button({
        Title = "🔄 Toggle Auto Trade UI",
        Desc = "Open or close the custom auto trade interface",
        Callback = function()
            -- Check if AutoTradeUI already exists globally
            if _G.AutoTradeUI then
                -- Toggle existing UI
                if _G.AutoTradeUI.IsVisible and _G.AutoTradeUI.IsVisible() then
                    _G.AutoTradeUI.Hide()
                    WindUI:Notify({
                        Title = "🔄 Auto Trade UI",
                        Content = "Auto trade interface closed!",
                        Duration = 2
                    })
                else
                    _G.AutoTradeUI.Show()
                    WindUI:Notify({
                        Title = "🔄 Auto Trade UI",
                        Content = "Auto trade interface opened!",
                        Duration = 2
                    })
                end
            else
                -- Load and create new AutoTradeUI
                local success, AutoTradeUI = pcall(function()
                    return loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/AutoTradeUI.lua"))()
                end)
                
                if success and AutoTradeUI then
                    -- Store globally for future toggles
                    _G.AutoTradeUI = AutoTradeUI
                    AutoTradeUI.Init(WindUI)
                    AutoTradeUI.Show()
                    WindUI:Notify({
                        Title = "🔄 Auto Trade UI",
                        Content = "Custom auto trade interface loaded!",
                        Duration = 3
                    })
                else
                    WindUI:Notify({
                        Title = "❌ Error",
                        Content = "Failed to load Auto Trade UI",
                        Duration = 5
                    })
                end
            end
        end
    })
    
    
    -- No UI elements to register with config - all removed except Auto Trade UI button
end

return SendTrashSystem
