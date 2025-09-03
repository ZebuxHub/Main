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
    "Phoenix", "Toothless", "Tyrannosaurus", "Mosasaur", "Octopus", "Killerwhale"
}

local HardcodedEggTypes = {
    "BasicEgg", "RareEgg", "SuperRareEgg", "SeaweedEgg", "EpicEgg", "LegendEgg", "ClownfishEgg", 
    "PrismaticEgg", "LionfishEgg", "HyperEgg", "VoidEgg", "BowserEgg", "SharkEgg", "DemonEgg", 
    "CornEgg", "AnglerfishEgg", "BoneDragonEgg", "UltraEgg", "DinoEgg", "FlyEgg", "UnicornEgg", 
    "OctopusEgg", "AncientEgg", "SeaDragonEgg"
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
local trashToggle
local targetPlayerDropdown
local sendModeDropdown
local sendPetTypeDropdown
local sendPetMutationDropdown
local sendEggTypeDropdown
local sendEggMutationDropdown
local sessionLimitInput
local statusParagraph

-- State variables
local trashEnabled = false
local actionCounter = 0
local selectedTargetName = "Random Player" -- cache target selection
local selectedPetTypes, selectedPetMuts, selectedEggTypes, selectedEggMuts -- cached selectors
local lastReceiverName, lastReceiverId -- for webhook author/avatar

-- Random target state (for "Random Player" mode)
local randomTargetState = { current = nil, fails = 0 }

-- Target blacklist (userId -> true)
local targetBlacklist = {}
local blacklistedNames = {} -- userId -> name for status display

-- Sticky target (preferred receiver after a successful send)
local stickyTarget = nil
local stickyFails = 0

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
local sendAttempts = {} -- Track send attempts per item to prevent double-sending
local sendVerificationRetries = 3 -- Number of verification retries
local sessionLimitReservations = 0 -- Track reserved session limit slots

-- Session limit reservation system
local function reserveSessionLimitSlot()
    if sessionLimits.sendPetCount + sessionLimitReservations >= sessionLimits.maxSendPet then
        return false -- No slots available
    end
    sessionLimitReservations = sessionLimitReservations + 1
    return true -- Slot reserved
end

local function releaseSessionLimitSlot()
    if sessionLimitReservations > 0 then
        sessionLimitReservations = sessionLimitReservations - 1
    end
end

local function getEffectiveSessionCount()
    return sessionLimits.sendPetCount + sessionLimitReservations
end

-- Webhook/session reporting
local webhookUrl = ""
local sessionLogs = {}
local webhookSent = false

-- Session limits
local sessionLimits = {
    sendPetCount = 0,
    maxSendPet = 50,
    limitReachedNotified = false -- Track if user has been notified
}

-- Pretty Discord embed assets
local EggIconMap = {
    BasicEgg = 129248801621928,
    RareEgg = 71012831091414,
    SuperRareEgg = 93845452154351,
    SeaweedEgg = 87125339619211,
    EpicEgg = 116395645531721,
    LegendEgg = 90834918351014,
    ClownfishEgg = 124419920608938,
    PrismaticEgg = 79960683434582,
    LionfishEgg = 100181295820053,
    HyperEgg = 104958288296273,
    VoidEgg = 122396162708984,
    BowserEgg = 71500536051510,
    SharkEgg = 71032472532652,
    DemonEgg = 126412407639969,
    CornEgg = 94739512852461,
    AnglerfishEgg = 121296998588378,
    BoneDragonEgg = 83209913424562,
    UltraEgg = 83909590718799,
    DinoEgg = 80783528632315,
    FlyEgg = 109240587278187,
    UnicornEgg = 123427249205445,
    OctopusEgg = 84758700095552,
    AncientEgg = 113910587565739,
    SeaDragonEgg = 130514093439717,
}

local function robloxIconUrl(assetId)
    if not assetId then return nil end
    return "https://www.roblox.com/asset-thumbnail/image?assetId=" .. tostring(assetId) .. "&width=420&height=420&format=png"
end

local function getIconUrlFor(kind, typeName)
    if kind == "egg" and typeName and EggIconMap[typeName] then
        return robloxIconUrl(EggIconMap[typeName])
    end
    return nil
end

-- Cute emoji for readability in Discord
local EggEmojiMap = {
    BasicEgg = "🥚",
    RareEgg = "🔷",
    SuperRareEgg = "💎",
    EpicEgg = "🌟",
    LegendEgg = "🏆",
    PrismaticEgg = "✨",
    HyperEgg = "⚡",
    VoidEgg = "🕳️",
    BowserEgg = "🐢",
    SharkEgg = "🦈",
    LionfishEgg = "🐟",
    ClownfishEgg = "🐠",
    AnglerfishEgg = "🐡",
    OctopusEgg = "🐙",
    SeaweedEgg = "🐚",
    BoneDragonEgg = "💀",
    DinoEgg = "🦖",
    FlyEgg = "🪶",
    UnicornEgg = "🦄",
    AncientEgg = "🗿",
    UltraEgg = "🚀",
    CornEgg = "🌽",
    SeaDragonEgg = "🐉",
}

local function getAvatarUrl(userId)
    if not userId or userId == "" then return nil end
    local userIdStr = tostring(userId)
    if userIdStr == "nil" then return nil end
    return "https://www.roblox.com/headshot-thumbnail/image?userId=" .. userIdStr .. "&width=180&height=180&format=png"
end

local function sendWebhookSummary()
    if webhookSent or webhookUrl == "" or #sessionLogs == 0 then return end
    local totalSent = sessionLimits.sendPetCount

    -- Group events by receiver and by type/mutation for readable blocks
    local byReceiver = {}
    local failedAttempts = 0
    local totalAttempts = 0

    for _, it in ipairs(sessionLogs) do
        local r = it.receiver or "?"
        byReceiver[r] = byReceiver[r] or { list = {}, counts = {}, total = 0, attempts = 0 }
        local key = (it.type or it.uid or "?") .. "|" .. (it.mutation or "None") .. "|" .. (it.kind or "?")
        local rec = byReceiver[r]
        rec.counts[key] = (rec.counts[key] or 0) + 1
        rec.list[key] = { type = it.type, mutation = it.mutation or "None", kind = it.kind }
        rec.total = rec.total + 1
        rec.attempts = rec.attempts + (it.attempts or 1)
        totalAttempts = totalAttempts + (it.attempts or 1)

        -- Count failed attempts (attempts > 1 means there were failures)
        if (it.attempts or 1) > 1 then
            failedAttempts = failedAttempts + ((it.attempts or 1) - 1)
        end
    end

    -- Build organized description for better readability
    local lines = {}
    local playerName = Players.LocalPlayer and Players.LocalPlayer.Name or "Player"
    
    -- Header section
    table.insert(lines, "## 🎁 " .. playerName .. "'s Send Session")
    table.insert(lines, "")
    
    -- Summary section
    local totalReceivers = 0
    for _ in pairs(byReceiver) do totalReceivers = totalReceivers + 1 end

    -- Calculate success rate
    local successRate = totalAttempts > 0 and (totalSent / totalAttempts * 100) or 100

    table.insert(lines, "📊 **Session Summary:**")
    table.insert(lines, string.format("• Total items sent: **%d**", totalSent))
    table.insert(lines, string.format("• Players helped: **%d**", totalReceivers))
    table.insert(lines, string.format("• Success rate: **%.1f%%** (%d/%d)", successRate, totalSent, totalAttempts))
    if failedAttempts > 0 then
        table.insert(lines, string.format("• Failed attempts: **%d**", failedAttempts))
    end
    table.insert(lines, "")
    
    -- Detailed breakdown by receiver
    table.insert(lines, "🎯 **Recipients & Items:**")
    
    -- Sort receivers for consistent display
    local sortedReceivers = {}
    for receiver, rec in pairs(byReceiver) do
        table.insert(sortedReceivers, {name = receiver, data = rec})
    end
    table.sort(sortedReceivers, function(a, b) return a.data.total > b.data.total end)
    
    for _, receiverInfo in ipairs(sortedReceivers) do
        local receiver = receiverInfo.name
        local rec = receiverInfo.data
        
        table.insert(lines, "")
        table.insert(lines, string.format("**👤 %s** (%d items)", receiver, rec.total))
        
        -- Sort items by type and count for better organization
        local sortedItems = {}
        for key, count in pairs(rec.counts) do
            local entry = rec.list[key]
            table.insert(sortedItems, {
                key = key,
                entry = entry,
                count = count,
                sortOrder = (entry.kind == "pet" and "1" or "2") .. entry.type .. (entry.mutation or "")
            })
        end
        table.sort(sortedItems, function(a, b) 
            if a.count ~= b.count then return a.count > b.count end
            return a.sortOrder < b.sortOrder
        end)
        
        for _, item in ipairs(sortedItems) do
            local entry = item.entry
            local count = item.count
            local emoji = (entry.kind == "egg" and EggEmojiMap[entry.type or ""]) or 
                         (entry.kind == "pet" and "🐾") or "📦"
            local mutationText = (entry.mutation and entry.mutation ~= "None" and entry.mutation ~= "") 
                               and (" [" .. entry.mutation .. "]") or ""
            table.insert(lines, string.format("  %s %s%s × %d", emoji, entry.type or "Unknown", mutationText, count))
        end
    end
    
    local description = table.concat(lines, "\n")

    -- Visuals
    local last = sessionLogs[#sessionLogs]
    local thumb = last and getIconUrlFor(last.kind, last.type) or nil
    -- remove author info from embed

    -- Use the improved embed format
    local payload = {
        embeds = {
            {
                title = "ZEBUX | https://discord.gg/yXPpRCgTQY",
                description = description,
                color = 5814783,
                fields = { { name = "Total Sent", value = tostring(totalSent), inline = true } },
                thumbnail = thumb and { url = thumb } or nil,
                author = nil,
                footer = { text = "Build A Zoo" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }
    local json = HttpService:JSONEncode(payload)
    http_request = http_request or request or (syn and syn.request)
    if http_request then
        http_request({ Url = webhookUrl, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = json })
        webhookSent = true
    end
end



-- Helper function to safely get attribute
local function safeGetAttribute(obj, attrName, default)
    if not obj then return default end
    local success, result = pcall(function()
        return obj:GetAttribute(attrName)
    end)
    return success and result or default
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
    
    -- Add hardcoded mutations
    for _, mutation in ipairs(HardcodedMutations) do
        mutations[mutation] = true
    end
    
    -- Add mutations from inventory
    if LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui.Data then
        local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
        if petsFolder then
            for _, petData in pairs(petsFolder:GetChildren()) do
                if petData:IsA("Configuration") then
                    local petMutation = safeGetAttribute(petData, "M", nil)
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
local function getRandomTargets(maxCount)
	local pool = {}
	local now = time()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and not targetBlacklist[player.UserId] then
			table.insert(pool, player)
		end
	end
	-- Fisher-Yates shuffle
	for i = #pool, 2, -1 do
		local j = math.random(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local out = {}
	local limit = math.min(maxCount or 5, #pool)
	for i = 1, limit do out[i] = pool[i] end
	return out
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
    sendAttempts = {}
    -- Release all session limit reservations on clear
    sessionLimitReservations = 0
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

--- Send current inventory webhook
local function sendCurrentInventoryWebhook()
    if webhookUrl == "" then
        WindUI:Notify({
            Title = "⚠️ No Webhook",
            Content = "Please set a webhook URL first",
            Duration = 3
        })
        return
    end

    -- Small helpers
    local function compactNumber(n)
        if type(n) ~= "number" then return tostring(n) end
        local a = math.abs(n)
        if a >= 1e12 then return string.format("%.2fT", n/1e12) end
        if a >= 1e9  then return string.format("%.2fB", n/1e9)  end
        if a >= 1e6  then return string.format("%.2fM", n/1e6)  end
        if a >= 1e3  then return string.format("%.2fK", n/1e3)  end
        return tostring(math.floor(n))
    end
    local function takeTopLines(map, prefix, maxLines)
        local arr = {}
        for name, count in pairs(map) do
            table.insert(arr, { name = name, count = count })
        end
        table.sort(arr, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return (a.name or "") < (b.name or "")
        end)
        local out = {}
        local limit = math.min(maxLines or 10, #arr)
        for i = 1, limit do
            table.insert(out, string.format("%s %s × %d", prefix, arr[i].name, arr[i].count))
        end
        if #arr > limit then
            table.insert(out, string.format("… and %d more", #arr - limit))
        end
        return table.concat(out, "\n")
    end

    -- Force refresh inventory cache for precision
    forceRefreshCache()

    local petInventoryAll = getPetInventory()
    local eggInventoryAll = getEggInventory()
    local allPetCount = petInventoryAll and #petInventoryAll or 0
    local allEggCount = eggInventoryAll and #eggInventoryAll or 0

    -- Filter to only items with D attribute empty or missing (unplaced/available)
    local function hasEmptyOrNoD(uid, isEgg)
        local dataRoot = LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Data")
        if not dataRoot then return false end
        local folder = dataRoot:FindFirstChild(isEgg and "Egg" or "Pets")
        if not folder then return false end
        local conf = folder:FindFirstChild(uid)
        if not conf or not conf:IsA("Configuration") then return false end
        local dAttr = safeGetAttribute(conf, "D", nil)
        if dAttr == nil then return true end
        if type(dAttr) == "string" then
            local s = dAttr
            return s == "" or s == "nil"
        end
        return false
    end

    local petInventory, eggInventory = {}, {}
    for _, pet in ipairs(petInventoryAll or {}) do
        if pet and pet.uid and hasEmptyOrNoD(pet.uid, false) then
            table.insert(petInventory, pet)
        end
    end
    for _, egg in ipairs(eggInventoryAll or {}) do
        if egg and egg.uid and hasEmptyOrNoD(egg.uid, true) then
            table.insert(eggInventory, egg)
        end
    end

    local unplacedPetCount = #petInventory
    local unplacedEggCount = #eggInventory

    -- Build summaries (type + mutation distributions)
    local petsByType, eggsByType = {}, {}
    local petMutations, eggMutations = {}, {}
    local eggMutsByType = {}
    local petMutsByType = {}
    for _, pet in ipairs(petInventory) do
        local t = pet.type or "Unknown"
        petsByType[t] = (petsByType[t] or 0) + 1
        local m = pet.mutation
        if m and m ~= "" and m ~= "None" then
            petMutations[m] = (petMutations[m] or 0) + 1
            petMutsByType[t] = petMutsByType[t] or {}
            petMutsByType[t][m] = (petMutsByType[t][m] or 0) + 1
        end
    end
    for _, egg in ipairs(eggInventory) do
        local t = egg.type or "Unknown"
        eggsByType[t] = (eggsByType[t] or 0) + 1
        local m = egg.mutation
        if m and m ~= "" and m ~= "None" then
            eggMutations[m] = (eggMutations[m] or 0) + 1
            eggMutsByType[t] = eggMutsByType[t] or {}
            eggMutsByType[t][m] = (eggMutsByType[t][m] or 0) + 1
        end
    end

    -- Hierarchical eggs display with per-type mutations
    local function eggHierarchy(maxTypes, maxMutsPerType)
        local typesArr = {}
        for name, count in pairs(eggsByType) do
            table.insert(typesArr, { name = name, count = count })
        end
        table.sort(typesArr, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return (a.name or "") < (b.name or "")
        end)

        local lines = {}
        local limit = math.min(maxTypes or 10, #typesArr)
        for i = 1, limit do
            local t = typesArr[i]
            table.insert(lines, string.format(":trophy: %s × %d", t.name, t.count))
            local muts = eggMutsByType[t.name] or {}
            local mutsArr = {}
            for m, c in pairs(muts) do table.insert(mutsArr, { m = m, c = c }) end
            table.sort(mutsArr, function(a, b)
                if a.c ~= b.c then return a.c > b.c end
                return (a.m or "") < (b.m or "")
            end)
            local mLimit = math.min(maxMutsPerType or 5, #mutsArr)
            for j = 1, mLimit do
                table.insert(lines, string.format("L :dna: %s × %d", mutsArr[j].m, mutsArr[j].c))
            end
            if #mutsArr > mLimit then
                table.insert(lines, string.format("L … and %d more", #mutsArr - mLimit))
            end
        end
        if #typesArr > limit then
            table.insert(lines, string.format("… and %d more egg types", #typesArr - limit))
        end
        return table.concat(lines, "\n"), (typesArr[1] and typesArr[1].name or nil)
    end

    local topEggsText, topEggName = eggHierarchy(12, 5)

    -- Hierarchical pets display with per-type mutations
    local function petHierarchy(maxTypes, maxMutsPerType)
        local typesArr = {}
        for name, count in pairs(petsByType) do
            table.insert(typesArr, { name = name, count = count })
        end
        table.sort(typesArr, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return (a.name or "") < (b.name or "")
        end)

        local lines = {}
        local limit = math.min(maxTypes or 10, #typesArr)
        for i = 1, limit do
            local t = typesArr[i]
            table.insert(lines, string.format("🐾 %s × %d", t.name, t.count))
            local muts = petMutsByType[t.name] or {}
            local mutsArr = {}
            for m, c in pairs(muts) do table.insert(mutsArr, { m = m, c = c }) end
            table.sort(mutsArr, function(a, b)
                if a.c ~= b.c then return a.c > b.c end
                return (a.m or "") < (b.m or "")
            end)
            local mLimit = math.min(maxMutsPerType or 5, #mutsArr)
            for j = 1, mLimit do
                table.insert(lines, string.format("L :dna: %s × %d", mutsArr[j].m, mutsArr[j].c))
            end
            if #mutsArr > mLimit then
                table.insert(lines, string.format("L … and %d more", #mutsArr - mLimit))
            end
        end
        if #typesArr > limit then
            table.insert(lines, string.format("… and %d more pet types", #typesArr - limit))
        end
        return table.concat(lines, "\n")
    end

    local topPetsText = petHierarchy(12, 5)

    local playerName = Players.LocalPlayer and Players.LocalPlayer.Name or "Unknown"
    local playerId = Players.LocalPlayer and Players.LocalPlayer.UserId or nil
    local authorBlock = {
        name = playerName .. " — Inventory Snapshot",
        icon_url = playerId and getAvatarUrl(playerId) or nil
    }
    local thumb = topEggName and getIconUrlFor("egg", topEggName) or nil
    local netWorth = (Players.LocalPlayer and Players.LocalPlayer:GetAttribute("NetWorth")) or 0
    local unknownNote = inventoryCache and inventoryCache.unknownCount or 0

    -- Compose embed
    local overviewValue = table.concat({
        "🧾 Net Worth: **" .. compactNumber(netWorth) .. "**",
        string.format("🐾 Pets: **%d** (unplaced **%d**)", allPetCount, unplacedPetCount),
        string.format("🥚 Eggs: **%d** (unplaced **%d**)", allEggCount, unplacedEggCount)
    }, "\n")

    local fields = {
        { name = "Overview", value = overviewValue, inline = false },
    }
    if topPetsText ~= "" then table.insert(fields, { name = "Top Pets", value = topPetsText, inline = true }) end
    if topEggsText ~= "" then table.insert(fields, { name = "Top Eggs", value = topEggsText, inline = true }) end
    if unknownNote and unknownNote > 0 then
        table.insert(fields, { name = "Note", value = "Some items are still loading (" .. tostring(unknownNote) .. ")", inline = false })
    end

    local payload = {
        embeds = {
            {
                title = "ZEBUX • Inventory Snapshot",
                description = "A precise snapshot of your current inventory.",
                color = 5793266, -- Discord blurple-ish
                author = authorBlock,
                thumbnail = thumb and { url = thumb } or nil,
                fields = fields,
                footer = { text = "Build A Zoo" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }

    local json = HttpService:JSONEncode(payload)
    http_request = http_request or request or (syn and syn.request)
    if http_request then
        http_request({ Url = webhookUrl, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = json })
        WindUI:Notify({ Title = "📤 Inventory Sent", Content = "Current inventory sent to Discord!", Duration = 3 })
    else
        WindUI:Notify({ Title = "❌ Webhook Failed", Content = "HTTP request function not available", Duration = 3 })
    end
end

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

-- Check if item should be sent/sold based on filters
local function shouldSendItem(item, includeTypes, includeMutations)
    -- Don't send locked items
    if item.locked then return false end
    
    -- Normalize values for robust comparison
    local function norm(v)
        return v and tostring(v):lower() or nil
    end
    local itemType = norm(item.type)
    local itemMut  = norm(item.mutation)
    
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
        for _, m in ipairs(includeMutations) do mutsSet[norm(m)] = true end
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

-- Verify item was successfully sent with adaptive timing
local function verifyItemSent(itemUID, isEgg, maxRetries)
	maxRetries = maxRetries or sendVerificationRetries

	    for attempt = 1, maxRetries do
		-- Adaptive wait time: longer for first attempt, shorter for retries
		local waitTime = attempt == 1 and 0.3 or 0.15
		task.wait(waitTime)

		local itemStillExists = false
		if LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui.Data then
			if isEgg then
				local eggsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
				if eggsFolder then itemStillExists = eggsFolder:FindFirstChild(itemUID) ~= nil end
			else
				local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
				if petsFolder then itemStillExists = petsFolder:FindFirstChild(itemUID) ~= nil end
			end
		end

		if not itemStillExists then
			return true -- Item successfully sent
		end

		-- If still exists and this is the last attempt, consider it failed
		if attempt == maxRetries then
			return false
		end
	end

	return false
end

-- Send item (pet or egg) to player with improved verification and retry logic
local function sendItemToPlayer(item, target, itemType)
	-- Reserve a session limit slot before starting
	if not reserveSessionLimitSlot() then
		if not sessionLimits.limitReachedNotified then
			local effectiveCount = getEffectiveSessionCount()
			WindUI:Notify({
				Title = "⚠️ Send Limit Reached",
				Content = string.format("Reached maximum send limit for this session (%d/%d)", effectiveCount, sessionLimits.maxSendPet),
				Duration = 5
			})
			sessionLimits.limitReachedNotified = true
		end
		return false
	end

	local itemUID = item.uid
	local isEgg = itemType == "egg"

	-- Prevent double-sending: track attempts per item
	if not sendAttempts[itemUID] then
		sendAttempts[itemUID] = 0
	end

	-- Limit to maximum 3 attempts per item to prevent infinite loops
	if sendAttempts[itemUID] >= 3 then
		releaseSessionLimitSlot()
		return false
	end

	-- Prevent parallel sends for the same item
	if sendInProgress[itemUID] then return false end
	sendInProgress[itemUID] = true
	sendAttempts[itemUID] = sendAttempts[itemUID] + 1

	-- Verify item exists before attempting to send
	if not verifyItemExists(itemUID, isEgg) then
		sendInProgress[itemUID] = nil
		sendAttempts[itemUID] = sendAttempts[itemUID] - 1 -- Decrement on failure
		releaseSessionLimitSlot()
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
		sendAttempts[itemUID] = sendAttempts[itemUID] - 1 -- Decrement on failure
		releaseSessionLimitSlot()
		return false -- silently skip
	end

	local success = false

	-- If item is placed on ground, remove it first
	if item.placed then
		local removeSuccess = removeFromGround(itemUID)
		if removeSuccess then
			task.wait(0.05) -- Optimized wait after remove
			if not verifyItemExists(itemUID, isEgg) then
				sendInProgress[itemUID] = nil
				sendAttempts[itemUID] = sendAttempts[itemUID] - 1 -- Decrement on failure
				releaseSessionLimitSlot()
				return false
			end
		end
	end

	-- Focus the item first (REQUIRED)
	local focusSuccess = focusItem(itemUID)
	if focusSuccess then task.wait(0.1) end -- Optimized wait after focus

	-- Ensure player is still online
	if not targetPlayerObj or targetPlayerObj.Parent ~= Players then
		sendInProgress[itemUID] = nil
		sendAttempts[itemUID] = sendAttempts[itemUID] - 1 -- Decrement on failure
		releaseSessionLimitSlot()
		return false
	end

	-- Attempt to send
	local sendSuccess, sendError = pcall(function()
		local args = { targetPlayerObj }
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(unpack(args))
	end)

	if sendSuccess then
		-- Use improved verification with retries
		local verifiedSent = verifyItemSent(itemUID, isEgg, sendVerificationRetries)

		if verifiedSent then
			success = true
			sessionLimits.sendPetCount = sessionLimits.sendPetCount + 1
			actionCounter = actionCounter + 1

			-- Log to webhook with more details for debugging
			local logEntry = {
				kind = itemType,
				uid = itemUID,
				type = item.type,
				mutation = (item.mutation ~= nil and item.mutation ~= "" and item.mutation) or "None",
				receiver = targetPlayerObj.Name,
				attempts = sendAttempts[itemUID],
				timestamp = os.time()
			}
			table.insert(sessionLogs, logEntry)

			-- Reset attempt counter on success
			sendAttempts[itemUID] = 0
		else
			-- Verification failed - item still exists, don't count it
			sendAttempts[itemUID] = sendAttempts[itemUID] - 1 -- Decrement on verification failure
			releaseSessionLimitSlot() -- Release reservation on verification failure
		end
	else
		-- Send failed - decrement attempt counter
		sendAttempts[itemUID] = sendAttempts[itemUID] - 1
		releaseSessionLimitSlot() -- Release reservation on send failure
	end

	sendInProgress[itemUID] = nil

	if success then
		WindUI:Notify({
			Title = "✅ Sent Successfully",
			Content = itemType:gsub("^%l", string.upper) .. " " .. (item.type or "Unknown") ..
					 (item.mutation and item.mutation ~= "" and item.mutation ~= "None" and " [" .. item.mutation .. "]" or "") ..
					 " → " .. targetPlayerObj.Name,
			Duration = 2
		})
	else
		-- Only show notification on final failure (after all attempts exhausted)
		if sendAttempts[itemUID] >= 3 then
			WindUI:Notify({
				Title = "❌ Send Failed",
				Content = "Failed to send " .. itemType .. " " .. (item.type or "Unknown") .. " after " .. sendAttempts[itemUID] .. " attempts",
				Duration = 3
			})
			sendAttempts[itemUID] = 0 -- Reset after notification
		end
	end

	return success
end

-- Sell pet (only pets, no eggs)
-- Selling pets has been removed per user request



-- Update status display
local function updateStatus()
    if not statusParagraph then return end

    local petInventory = getPetInventory()
    local eggInventory = getEggInventory()

    -- Calculate active send attempts
    local activeAttempts = 0
    for uid, attempts in pairs(sendAttempts) do
        if attempts > 0 then
            activeAttempts = activeAttempts + attempts
        end
    end

    local effectiveCount = getEffectiveSessionCount()
    local statusText = string.format(
        "🐾 Pets in inventory: %d\n" ..
        "🥚 Eggs in inventory: %d\n" ..
        "📤 Items sent this session: %d/%d (%d reserved)\n" ..
        "🔄 Active send attempts: %d\n" ..
        "🔄 Actions performed: %d",
        #petInventory,
        #eggInventory,
        sessionLimits.sendPetCount, sessionLimits.maxSendPet, sessionLimitReservations,
        activeAttempts,
        actionCounter
    )

    -- Append blacklist info
    local blNames = {}
    for uid, name in pairs(blacklistedNames) do table.insert(blNames, name) end
    table.sort(blNames)
    if #blNames > 0 then
        statusText = statusText .. string.format("\n⛔ Blacklisted targets (%d): %s", #blNames, table.concat(blNames, ", "))
    end

    statusParagraph:SetDesc(statusText)
end

-- Main trash processing function
local function processTrash()
	while trashEnabled do
		-- Get send mode setting
		local sendMode = "Both" -- Default
		if sendModeDropdown then
			local success, result = nil, nil
			if sendModeDropdown.GetValue then
				success, result = pcall(function() return sendModeDropdown:GetValue() end)
			elseif sendModeDropdown.Value then
				success, result = pcall(function() return sendModeDropdown.Value end)
			end
			sendMode = (success and result) and result or "Both"
		else
			sendMode = "Both"
		end

		local petInventory = {}
		local eggInventory = {}
		if sendMode == "Pets" or sendMode == "Both" then petInventory = getPetInventory() end
		if sendMode == "Eggs" or sendMode == "Both" then eggInventory = getEggInventory() end

		if #petInventory == 0 and #eggInventory == 0 then
			if sessionLimits.sendPetCount >= sessionLimits.maxSendPet then
				trashEnabled = false
				if trashToggle then pcall(function() trashToggle:SetValue(false) end) end
			else
				WindUI:Notify({ Title = "ℹ️ No Items", Content = "No items matched your selectors.", Duration = 3 })
			end
			wait(1)
			continue
		end

		-- Determine targets with sticky preference
		local targets = {}
		local randomMode = (selectedTargetName == "Random Player")
		if stickyTarget and stickyTarget.Parent == Players and not targetBlacklist[stickyTarget.UserId] then
			targets = { stickyTarget }
		else
			stickyTarget = nil
			stickyFails = 0
			if randomMode then
				targets = getRandomTargets(8)
			else
				local tp = resolveTargetPlayerByName(selectedTargetName)
				if tp and not targetBlacklist[tp.UserId] then
					targets = { tp }
				else
					targets = getRandomTargets(5)
				end
			end
		end

		local sentAnyItem = false
		local function trySendToTarget(targetPlayerObj)
			local anyAttempt = false
			if not targetPlayerObj or targetPlayerObj.Parent ~= Players then return false, false end
			-- attempt pets
			if sendMode == "Pets" or sendMode == "Both" then
				for _, pet in ipairs(petInventory) do
					pet = refreshItemFromData(pet.uid, false, pet)
					if shouldSendItem(pet, selectedPetTypes, selectedPetMuts) then
						anyAttempt = true
						if sendItemToPlayer(pet, targetPlayerObj, "pet") then return true, true end
					end
				end
			end
			-- attempt eggs
			if sendMode == "Eggs" or sendMode == "Both" then
				for _, egg in ipairs(eggInventory) do
					egg = refreshItemFromData(egg.uid, true, egg)
					local tList = selectedEggTypes or {}
					local mList = selectedEggMuts or {}
					if shouldSendItem(egg, tList, mList) then
						anyAttempt = true
						if sendItemToPlayer(egg, targetPlayerObj, "egg") then return true, true end
					end
				end
			end
			return false, anyAttempt
		end

		-- If we have a sticky target: keep trying only them until failure
		if #targets > 0 and targets[1] == stickyTarget then
			local ok, attempted = trySendToTarget(stickyTarget)
			sentAnyItem = ok
			if not ok and attempted then
				stickyFails = stickyFails + 1
				if stickyFails >= 1 then -- one failed cycle un-sticks
					stickyTarget = nil
					stickyFails = 0
				end
			else
				if ok then stickyFails = 0 end
			end
		else
			-- No sticky: iterate candidates; each gets up to 2 attempts this cycle
			for _, targetPlayerObj in ipairs(targets) do
				local attempts = 0
				local ok = false
				local attempted = false
				while attempts < 2 and not ok do
					local r1, a1 = trySendToTarget(targetPlayerObj)
					ok = r1
					attempted = attempted or a1
					attempts = attempts + 1
				end
				if ok then
					sentAnyItem = true
					stickyTarget = targetPlayerObj -- stick to winner
					stickyFails = 0
					break
				else
					if attempted then
						targetBlacklist[targetPlayerObj.UserId] = true
						blacklistedNames[targetPlayerObj.UserId] = targetPlayerObj.Name
					end
				end
			end
		end

		if sessionLimits.sendPetCount >= sessionLimits.maxSendPet then
			if not webhookSent and webhookUrl ~= "" and #sessionLogs > 0 then
				task.spawn(sendWebhookSummary)
			end
			trashEnabled = false
			if trashToggle then pcall(function() trashToggle:SetValue(false) end) end
		end

		updateStatus()
		task.wait(0.3)
	end
end

-- Initialize function
function SendTrashSystem.Init(dependencies)
    WindUI = dependencies.WindUI
    Window = dependencies.Window
    Config = dependencies.Config
    
    -- Load saved webhook URL from config
    local loadedWebhook = loadWebhookUrl()
    if loadedWebhook and WindUI then
        WindUI:Notify({
            Title = "📥 Webhook Loaded",
            Content = "Saved webhook URL loaded from config",
            Duration = 2
        })
    end
    
    -- Start precise event-driven watchers for T/M replication
    startDataWatchers()
    
    -- Create the Send Trash tab
    local TrashTab = Window:Tab({ Title = "🗑️ | Send Trash"})
    
    -- Status display
    statusParagraph = TrashTab:Paragraph({
        Title = "Trash System Status:",
        Desc = "Loading pet information...",
        Image = "trash-2",
        ImageSize = 22
    })
    
    
    -- Session limit input
    sessionLimitInput = TrashTab:Input({
        Title = "Session Limit",
        Desc = "Maximum items to send/sell per session (default: 50)",
        Default = "50",
        Numeric = true,
        Finished = true,
        Callback = function(value)
            local numValue = tonumber(value) or 50
            if numValue < 1 then numValue = 1 end -- Minimum of 1
            sessionLimits.maxSendPet = numValue
            sessionLimits.limitReachedNotified = false -- Reset notification
            print("Session limits updated: " .. numValue .. " items per session")
        end,
    })

    -- Reset session limits button (moved directly under Session Limit)
    TrashTab:Button({
        Title = "🔄 Reset Session Limits",
        Desc = "Reset send/sell counters for this session",
        Callback = function()
            sessionLimits.sendPetCount = 0
            sessionLimits.limitReachedNotified = false -- Reset notification
            webhookSent = false
            sessionLogs = {}
            actionCounter = 0
            updateStatus()
            WindUI:Notify({ Title = "🔄 Session Reset", Content = "Send/sell limits reset!", Duration = 2 })
        end
    })

    -- Main toggle
    trashToggle = TrashTab:Toggle({
        Title = "🗑️ Send Trash System",
        Desc = "Automatically send/sell unwanted pets based on filters",
        Value = false,
        Callback = function(state)
            trashEnabled = state
            
            if state then
                task.spawn(function()
                    processTrash()
                end)
                WindUI:Notify({ Title = "🗑️ Send Trash", Content = "Started trash system! 🎉", Duration = 3 })
            else
                WindUI:Notify({ Title = "🗑️ Send Trash", Content = "Stopped", Duration = 3 })
                -- Send webhook once per session when turned off
                if not webhookSent and webhookUrl ~= "" and #sessionLogs > 0 then
                    task.spawn(sendWebhookSummary)
                end
            end
        end
    })
    
    TrashTab:Section({ Title = "🎯 Target Settings", Icon = "target" })
    
    -- Send mode dropdown
    sendModeDropdown = TrashTab:Dropdown({
        Title = "📦 Send Type",
        Desc = "Choose what to send: Pets only, Eggs only, or Both",
        Values = {"Pets", "Eggs", "Both"},
        Value = "Both",
        Callback = function(selection) end
    })
    
    -- Target player dropdown
    targetPlayerDropdown = TrashTab:Dropdown({
        Title = "🎯 Target Player (for sending)",
        Desc = "Select player to send items to (Random = different player each time)",
        Values = refreshPlayerList(),
        Value = "Random Player",
        Callback = function(selection)
            selectedTargetName = selection or "Random Player"
            -- Reset random target state when user changes selection
            randomTargetState.current = nil
            randomTargetState.fails = 0
        end
    })
    
    TrashTab:Section({ Title = "📤 Send Pet Selectors", Icon = "mail" })
    
    -- Send pet type filter (now include-only)
    sendPetTypeDropdown = TrashTab:Dropdown({
        Title = "✅ Pet Types to Send",
        Desc = "Select pet types to send (empty = allow all)",
        Values = getAllPetTypes(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedPetTypes = selectionToList(selection)
        end
    })
    
    -- Send pet mutation filter (now include-only)
    sendPetMutationDropdown = TrashTab:Dropdown({
        Title = "✅ Pet Mutations to Send", 
        Desc = "Select mutations to send (empty = allow all)",
        Values = getAllMutations(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedPetMuts = selectionToList(selection)
        end
    })
    
    TrashTab:Section({ Title = "🥚 Send Egg Selectors", Icon = "mail" })
    
    -- Send egg type filter (now include-only)
    sendEggTypeDropdown = TrashTab:Dropdown({
        Title = "✅ Egg Types to Send",
        Desc = "Select egg types to send (empty = allow all)",
        Values = getAllEggTypes(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedEggTypes = selectionToList(selection)
        end
    })
    
    -- Send egg mutation filter (now include-only)
    sendEggMutationDropdown = TrashTab:Dropdown({
        Title = "✅ Egg Mutations to Send", 
        Desc = "Select mutations to send (empty = allow all)",
        Values = getAllMutations(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedEggMuts = selectionToList(selection)
        end
    })
    
    -- Selling UI removed per request
    
    TrashTab:Section({ Title = "🛠️ Manual Controls", Icon = "settings" })
    
    -- Webhook input (optional) - Auto-saves to config
    local webhookInput = TrashTab:Input({
        Title = "📡 Webhook URL (auto-saved)",
        Desc = "Discord webhook to receive session summary - automatically saved to config",
        Default = webhookUrl,
        Numeric = false,
        Finished = true,
        Callback = function(value)
            local newUrl = tostring(value or "")
            -- Only save if the URL actually changed
            if newUrl ~= webhookUrl then
                saveWebhookUrl(newUrl)
                webhookSent = false -- Reset webhook sent flag for new URL
            end
        end,
    })
    
    -- Ensure the loaded webhook URL is displayed in the input field
    if webhookUrl and webhookUrl ~= "" then
        webhookInput:SetValue(webhookUrl)
    end
    
    -- Manual refresh button
    TrashTab:Button({
        Title = "🔄 Refresh Lists", 
        Desc = "Manually refresh player and pet lists",
        Callback = function()
            -- Refresh all dropdowns
            if targetPlayerDropdown and targetPlayerDropdown.SetValues then
                pcall(function() targetPlayerDropdown:SetValues(refreshPlayerList()) end)
            end
            if sendPetTypeDropdown and sendPetTypeDropdown.SetValues then
                pcall(function() sendPetTypeDropdown:SetValues(getAllPetTypes()) end)
            end
            if sendPetMutationDropdown and sendPetMutationDropdown.SetValues then
                pcall(function() sendPetMutationDropdown:SetValues(getAllMutations()) end)
            end
            if sendEggTypeDropdown and sendEggTypeDropdown.SetValues then
                pcall(function() sendEggTypeDropdown:SetValues(getAllEggTypes()) end)
            end
            if sendEggMutationDropdown and sendEggMutationDropdown.SetValues then
                pcall(function() sendEggMutationDropdown:SetValues(getAllMutations()) end)
            end
            -- Selling UI removed
            
            updateStatus()
            
            WindUI:Notify({
                Title = "🔄 Refresh Complete",
                Content = "All lists refreshed!",
                Duration = 2
            })
        end
    })
    
    -- Cache refresh button
    TrashTab:Button({
        Title = "🔄 Refresh Cache",
        Desc = "Force refresh inventory cache and clear send progress",
        Callback = function()
            forceRefreshCache()
            clearSendProgress()
            -- Also clear send attempts tracking and session limit reservations
            sendAttempts = {}
            sessionLimitReservations = 0
            updateStatus()

            WindUI:Notify({
                Title = "🔄 Cache Refreshed",
                Content = "Inventory cache, send progress, and attempts cleared!",
                Duration = 3
            })
        end
    })

    -- Removed: Fix Unknown Items and Force Resolve Names buttons

    -- Send current inventory webhook button
    TrashTab:Button({
        Title = "📤 Send Inventory",
        Desc = "Send current pets/eggs inventory to Discord webhook",
        Callback = function()
            task.spawn(sendCurrentInventoryWebhook)
        end
    })
    
    
    -- Register UI elements with config
    if Config then
        Config:Register("trashEnabled", trashToggle)
        Config:Register("sendMode", sendModeDropdown)
        Config:Register("targetPlayer", targetPlayerDropdown)
        Config:Register("sendPetTypeFilter", sendPetTypeDropdown)
        Config:Register("sendPetMutationFilter", sendPetMutationDropdown)
        Config:Register("sendEggTypeFilter", sendEggTypeDropdown)
        Config:Register("sendEggMutationFilter", sendEggMutationDropdown)
        Config:Register("webhookInput", webhookInput)
        -- Selling config removed
        Config:Register("sessionLimit", sessionLimitInput)
    end
    
    -- Initial status update
    task.spawn(function()
        task.wait(1)
        updateStatus()
    end)
end

return SendTrashSystem
