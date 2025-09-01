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
local speedThresholdSlider
local sessionLimitInput
local statusParagraph

-- State variables
local trashEnabled = false
local autoDeleteMinSpeed = 0
local actionCounter = 0
local selectedTargetName = "Random Player" -- cache target selection
local selectedPetTypes, selectedPetMuts, selectedEggTypes, selectedEggMuts -- cached selectors
local lastReceiverName, lastReceiverId -- for webhook author/avatar

-- Inventory Cache System (like auto place)
local inventoryCache = {
    pets = {},
    eggs = {},
    lastUpdateTime = 0,
    updateInterval = 0.5, -- Update every 0.5 seconds
    unknownCount = 0 -- Track items that couldn't load properly
}

-- Send operation tracking
local sendInProgress = {}
local sendTimeoutSeconds = 5

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
    for _, it in ipairs(sessionLogs) do
        local r = it.receiver or "?"
        byReceiver[r] = byReceiver[r] or { list = {}, counts = {}, total = 0 }
        local key = (it.type or it.uid or "?") .. "|" .. (it.mutation or "None") .. "|" .. (it.kind or "?")
        local rec = byReceiver[r]
        rec.counts[key] = (rec.counts[key] or 0) + 1
        rec.list[key] = { type = it.type, mutation = it.mutation or "None", kind = it.kind }
        rec.total = rec.total + 1
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
    
    table.insert(lines, "📊 **Session Summary:**")
    table.insert(lines, string.format("• Total items sent: **%d**", totalSent))
    table.insert(lines, string.format("• Players helped: **%d**", totalReceivers))
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
    local authorName = Players.LocalPlayer and Players.LocalPlayer.Name or nil
    local authorIcon = Players.LocalPlayer and getAvatarUrl(Players.LocalPlayer.UserId) or nil

    -- Use the improved embed format
    local payload = {
        embeds = {
            {
                title = "Send Trash Session Summary",
                description = description,
                color = 5814783,
                fields = { { name = "Total Sent", value = tostring(totalSent), inline = true } },
                thumbnail = thumb and { url = thumb } or nil,
                author = authorName and { name = authorName, icon_url = authorIcon } or nil,
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
                    local petType = safeGetAttribute(petData, "Type", nil)
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
                    local eggType = safeGetAttribute(eggData, "Type", nil)
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
                    local petMutation = safeGetAttribute(petData, "Mutation", nil)
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

-- Get random player
local function getRandomPlayer()
    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(players, player.Name)
        end
    end
    
    if #players > 0 then
        return players[math.random(1, #players)]
    end
    
    return nil
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
                local petType = safeGetAttribute(petData, "T", nil) or 
                               safeGetAttribute(petData, "Type", nil)
                
                -- Skip items without proper type data (not fully loaded yet)
                if not petType or petType == "" or petType == "Unknown" then
                    inventoryCache.unknownCount = inventoryCache.unknownCount + 1
                    continue -- Skip this pet until it loads properly
                end
                
                local petInfo = {
                    uid = petData.Name,
                    type = petType,
                    mutation = safeGetAttribute(petData, "M", safeGetAttribute(petData, "Mutation", "")),
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
                local eggType = safeGetAttribute(eggData, "ID", nil) or 
                               safeGetAttribute(eggData, "T", nil) or 
                               safeGetAttribute(eggData, "Type", nil)
                
                -- Skip items without proper type data (not fully loaded yet)
                if not eggType or eggType == "" or eggType == "Unknown" then
                    inventoryCache.unknownCount = inventoryCache.unknownCount + 1
                    continue -- Skip this egg until it loads properly
                end
                
                local eggInfo = {
                    uid = eggData.Name,
                    type = eggType,
                    mutation = safeGetAttribute(eggData, "M", safeGetAttribute(eggData, "Mutation", "")),
                    locked = safeGetAttribute(eggData, "LK", 0) == 1,
                    placed = safeGetAttribute(eggData, "D", nil) ~= nil
                }
                inventoryCache.eggs[eggData.Name] = eggInfo
            end
        end
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
    
    -- Force refresh inventory cache
    forceRefreshCache()
    
    local petInventory = getPetInventory()
    local eggInventory = getEggInventory()

    -- Filter to only items with D attribute empty or missing (unplaced)
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

    local filteredPets, filteredEggs = {}, {}
    for _, pet in ipairs(petInventory or {}) do
        if pet and pet.uid and hasEmptyOrNoD(pet.uid, false) then
            table.insert(filteredPets, pet)
        end
    end
    for _, egg in ipairs(eggInventory or {}) do
        if egg and egg.uid and hasEmptyOrNoD(egg.uid, true) then
            table.insert(filteredEggs, egg)
        end
    end

    petInventory = filteredPets
    eggInventory = filteredEggs
    
    local petCount = petInventory and #petInventory or 0
    local eggCount = eggInventory and #eggInventory or 0
    
    -- Build pets section
    local petsByType = {}
    if petInventory then
        for _, pet in ipairs(petInventory) do
            if pet then
                local key = (pet.type or "Unknown") .. "|" .. (pet.mutation or "None")
                petsByType[key] = (petsByType[key] or 0) + 1
            end
        end
    end
    
    -- Build eggs section
    local eggsByType = {}
    if eggInventory then
        for _, egg in ipairs(eggInventory) do
            if egg then
                local key = (egg.type or "Unknown") .. "|" .. (egg.mutation or "None")
                eggsByType[key] = (eggsByType[key] or 0) + 1
            end
        end
    end
    
    -- Create organized description
    local lines = {}
    local playerName = Players.LocalPlayer and Players.LocalPlayer.Name or "Unknown"
    
    table.insert(lines, "## 🎒 " .. playerName .. "'s Inventory")
    table.insert(lines, "")
    table.insert(lines, "📊 **Summary:**")
    table.insert(lines, string.format("• 🐾 Total Pets: **%d**", petCount))
    table.insert(lines, string.format("• 🥚 Total Eggs: **%d**", eggCount))
    table.insert(lines, string.format("• 📦 Combined: **%d**", petCount + eggCount))
    table.insert(lines, "")
    
    -- Pets section with better organization
    if petCount > 0 then
        table.insert(lines, "🐾 **Available Pets:**")
        local petEntries = {}
        for key, count in pairs(petsByType) do
            local type, mutation = key:match("([^|]+)|([^|]+)")
            type = type or "Unknown"
            mutation = (mutation and mutation ~= "None" and mutation ~= "") and mutation or nil
            local displayName = mutation and (type .. " [" .. mutation .. "]") or type
            table.insert(petEntries, { name = displayName, count = count })
        end
        table.sort(petEntries, function(a, b) return a.count > b.count end)
        for _, entry in ipairs(petEntries) do
            table.insert(lines, string.format("  🐾 %s × %d", entry.name, entry.count))
        end
    else
        table.insert(lines, "🐾 **Available Pets:** None")
    end
    
    table.insert(lines, "")
    
    -- Eggs section with better organization
    if eggCount > 0 then
        table.insert(lines, "🥚 **Available Eggs:**")
        local eggEntries = {}
        for key, count in pairs(eggsByType) do
            local type, mutation = key:match("([^|]+)|([^|]+)")
            type = type or "Unknown"
            mutation = (mutation and mutation ~= "None" and mutation ~= "") and mutation or nil
            local displayName = mutation and (type .. " [" .. mutation .. "]") or type
            local emoji = EggEmojiMap[type] or "🥚"
            table.insert(eggEntries, { name = displayName, emoji = emoji, count = count })
        end
        table.sort(eggEntries, function(a, b) return a.count > b.count end)
        for _, entry in ipairs(eggEntries) do
            table.insert(lines, string.format("  %s %s × %d", entry.emoji, entry.name, entry.count))
        end
    else
        table.insert(lines, "🥚 **Available Eggs:** None")
    end
    
    local description = table.concat(lines, "\n")
    
    -- Safety check for description
    if not description or description == "" then
        description = "No inventory data available"
    end
    
    -- Create webhook payload
    local authorName = Players.LocalPlayer and Players.LocalPlayer.Name or nil
    
    local payload = {
        embeds = {
            {
                title = "🎒 Current Inventory",
                description = description,
                color = 3066993, -- Green color
                fields = {
                    { name = "Total Pets", value = tostring(petCount), inline = true },
                    { name = "Total Eggs", value = tostring(eggCount), inline = true },
                    { name = "Combined", value = tostring(petCount + eggCount), inline = true }
                },
                author = authorName and { name = authorName } or nil,
                footer = { text = "Build A Zoo - Current Inventory" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }
    
    local json = HttpService:JSONEncode(payload)
    http_request = http_request or request or (syn and syn.request)
    if http_request then
        http_request({ 
            Url = webhookUrl, 
            Method = "POST", 
            Headers = { ["Content-Type"] = "application/json" }, 
            Body = json 
        })
        
        WindUI:Notify({
            Title = "📤 Inventory Sent",
            Content = "Current inventory sent to Discord!",
            Duration = 3
        })
    else
        WindUI:Notify({
            Title = "❌ Webhook Failed",
            Content = "HTTP request function not available",
            Duration = 3
        })
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
        if isEgg then
            tVal = safeGetAttribute(conf, "ID", nil) or 
                   safeGetAttribute(conf, "T", nil) or 
                   safeGetAttribute(conf, "Type", nil)
        else
            tVal = safeGetAttribute(conf, "T", nil) or 
                   safeGetAttribute(conf, "Type", nil)
        end
        
        local mVal = safeGetAttribute(conf, "M", nil) or safeGetAttribute(conf, "Mutation", "")
        local locked = safeGetAttribute(conf, "LK", 0) == 1
        local placed = safeGetAttribute(conf, "D", nil) ~= nil
        
        -- Skip items that haven't loaded type data yet
        if not tVal or tVal == "" or tVal == "Unknown" then
            return into -- Return unchanged if data isn't ready yet
        end
        
        if into then
            into.type = tVal
            into.mutation = mVal or into.mutation
            into.locked = locked
            into.placed = placed
            return into
        else
            return { uid = uid, type = tVal, mutation = mVal, locked = locked, placed = placed }
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

-- Send item (pet or egg) to player
--- Send item (pet or egg) to player with verification and retry
local function sendItemToPlayer(item, playerName, itemType)
    if sessionLimits.sendPetCount >= sessionLimits.maxSendPet then
        if not sessionLimits.limitReachedNotified then
            WindUI:Notify({
                Title = "⚠️ Send Limit Reached",
                Content = "Reached maximum send limit for this session (" .. sessionLimits.maxSendPet .. ")",
                Duration = 5
            })
            sessionLimits.limitReachedNotified = true
        end
        return false
    end
    
    local itemUID = item.uid
    local isEgg = itemType == "egg"
    
    -- Check if send operation is already in progress for this item
    if sendInProgress[itemUID] then
        return false -- Already being sent
    end
    
    -- Mark as in progress
    sendInProgress[itemUID] = true
    
    -- Verify item exists before attempting to send
    if not verifyItemExists(itemUID, isEgg) then
        sendInProgress[itemUID] = nil
        return false -- Item no longer exists
    end
    
    local success = false
    
    -- If item is placed on ground, remove it first
    if item.placed then
        local removeSuccess = removeFromGround(itemUID)
        if removeSuccess then
            task.wait(0.05) -- Optimized wait after removal
            -- Re-verify after removal
            if not verifyItemExists(itemUID, isEgg) then
                sendInProgress[itemUID] = nil
                return false -- Item removed during ground removal
            end
        end
    end
    
    -- Focus the item first (REQUIRED before sending)
    local focusSuccess = focusItem(itemUID)
    if focusSuccess then
        task.wait(0.1) -- Optimized wait for focus to process
    end
    
    -- Verify player is still online
    local targetPlayer = resolveTargetPlayerByName(playerName)
    if not targetPlayer then
        warn("Target player " .. playerName .. " not found online")
        sendInProgress[itemUID] = nil
        return false
    end
    
    -- Attempt to send
    local sendSuccess, err = pcall(function()
        local args = {targetPlayer}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(unpack(args))
    end)
    
    if sendSuccess then
        -- Wait a moment then verify item was actually sent by checking PlayerGui.Data
        task.wait(0.3) -- Slightly longer wait for server update
        local itemStillExists = false
        
        -- Check directly in PlayerGui.Data folders
        if LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui.Data then
            if isEgg then
                local eggsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
                if eggsFolder then
                    itemStillExists = eggsFolder:FindFirstChild(itemUID) ~= nil
                end
            else
                local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
                if petsFolder then
                    itemStillExists = petsFolder:FindFirstChild(itemUID) ~= nil
                end
            end
        end
        
        if not itemStillExists then
            -- Item successfully sent (no longer in PlayerGui.Data)
            success = true
            sessionLimits.sendPetCount = sessionLimits.sendPetCount + 1
            actionCounter = actionCounter + 1
            
            -- Log for webhook
            table.insert(sessionLogs, {
                kind = itemType,
                uid = itemUID,
                type = item.type,
                mutation = (item.mutation ~= nil and item.mutation ~= "" and item.mutation) or "None",
                receiver = playerName,
            })
        end
    end
    
    -- Clean up
    sendInProgress[itemUID] = nil
    
    if success then
        WindUI:Notify({
            Title = "✅ Sent Successfully",
            Content = itemType:gsub("^%l", string.upper) .. " " .. (item.type or "Unknown") .. " → " .. playerName,
            Duration = 2
        })
    else
        WindUI:Notify({
            Title = "❌ Send Failed",
            Content = "Failed to send " .. itemType,
            Duration = 3
        })
    end
    
    return success
end

-- Sell pet (only pets, no eggs)
-- Selling pets has been removed per user request

-- Auto-delete slow pets
local function autoDeleteSlowPets(speedThreshold)
    if speedThreshold <= 0 then
        return 0, "Auto-delete disabled (speed threshold: 0)"
    end
    
    if not LocalPlayer or not LocalPlayer.PlayerGui or not LocalPlayer.PlayerGui.Data then
        return 0, "Player data not found"
    end
    
    local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
    if not petsFolder then
        return 0, "Pets folder not found"
    end
    
    local deletedCount = 0
    local PetRE = ReplicatedStorage:FindChild("Remote") and ReplicatedStorage.Remote:FindFirstChild("PetRE")
    if not PetRE then
        return 0, "PetRE not found"
    end
    
    -- Find pets with speed below threshold
    for _, petData in pairs(petsFolder:GetChildren()) do
        if petData:IsA("Configuration") then
            local petSpeed = petData:GetAttribute("Speed") or 0
            local petLocked = petData:GetAttribute("LK") or 0
            local petUID = petData.Name
            
            -- Only delete unlocked pets below speed threshold
            if petLocked == 0 and petSpeed < speedThreshold then
                PetRE:FireServer('Sell', petUID)
                deletedCount = deletedCount + 1
                wait(0.05) -- Very quick delay between deletions
                
                -- Limit to 5 deletions per cycle to avoid spam
                if deletedCount >= 5 then
                    break
                end
            end
        end
    end
    
    return deletedCount, string.format("Deleted %d pets below speed %d", deletedCount, speedThreshold)
end

-- Update status display
local function updateStatus()
    if not statusParagraph then return end
    
    local petInventory = getPetInventory()
    local eggInventory = getEggInventory()
    
    local statusText = string.format(
        "🐾 Pets in inventory: %d\n" ..
        "🥚 Eggs in inventory: %d\n" ..
        "📤 Items sent this session: %d/%d\n" ..
        "⚡ Auto-delete speed threshold: %s\n" ..
        "🔄 Actions performed: %d%s",
        #petInventory,
        #eggInventory,
        sessionLimits.sendPetCount, sessionLimits.maxSendPet,
        autoDeleteMinSpeed > 0 and tostring(autoDeleteMinSpeed) or "Disabled",
        actionCounter,
        inventoryCache.unknownCount > 0 and ("\n⚠️ Unknown items: " .. inventoryCache.unknownCount .. " (click Fix Unknown Items)") or ""
    )
    
    statusParagraph:SetDesc(statusText)
end

-- Main trash processing function
local function processTrash()
    while trashEnabled do
        -- Get send mode setting
        local sendMode = "Both" -- Default
        if sendModeDropdown then
            local success, result = nil, nil
            
            -- Try different methods to get the value
            if sendModeDropdown.GetValue then
                success, result = pcall(function() return sendModeDropdown:GetValue() end)
            elseif sendModeDropdown.Value then
                success, result = pcall(function() return sendModeDropdown.Value end)
            end
            
            if success and result then
                sendMode = result
            else
                sendMode = "Both"
            end
        else
            sendMode = "Both"
        end
        
        local petInventory = {}
        local eggInventory = {}
        
        -- Get inventories based on send mode
        if sendMode == "Pets" or sendMode == "Both" then
            petInventory = getPetInventory()
        end
        if sendMode == "Eggs" or sendMode == "Both" then
            eggInventory = getEggInventory()
        end
        
        if #petInventory == 0 and #eggInventory == 0 then
            -- If limit reached, finalize session; else notify once
            if sessionLimits.sendPetCount >= sessionLimits.maxSendPet then
                trashEnabled = false
                if trashToggle then pcall(function() trashToggle:SetValue(false) end) end
            else
                WindUI:Notify({ Title = "ℹ️ No Items", Content = "No items matched your selectors.", Duration = 3 })
            end
            wait(1)
            continue
        end
        
        -- Get selector settings for pets (include-only)
        local includePetTypes = {}
        local includePetMutations = {}
        
        if sendPetTypeDropdown and sendPetTypeDropdown.GetValue then
            local success, result = pcall(function() return sendPetTypeDropdown:GetValue() end)
            includePetTypes = success and selectionToList(result) or {}
            selectedPetTypes = includePetTypes
        end
        
        if sendPetMutationDropdown and sendPetMutationDropdown.GetValue then
            local success, result = pcall(function() return sendPetMutationDropdown:GetValue() end)
            includePetMutations = success and selectionToList(result) or {}
            selectedPetMuts = includePetMutations
        end
        
        -- Get selector settings for eggs (include-only)
        local includeEggTypes = {}
        local includeEggMutations = {}
        
        if sendEggTypeDropdown and sendEggTypeDropdown.GetValue then
            local success, result = pcall(function() return sendEggTypeDropdown:GetValue() end)
            includeEggTypes = success and selectionToList(result) or {}
            selectedEggTypes = includeEggTypes
        end
        
        if sendEggMutationDropdown and sendEggMutationDropdown.GetValue then
            local success, result = pcall(function() return sendEggMutationDropdown:GetValue() end)
            includeEggMutations = success and selectionToList(result) or {}
            selectedEggMuts = includeEggMutations
        end
        
        -- Get target player (robust): prefer cached selection, resolve actual Player
        local targetPlayerName = selectedTargetName
        local targetPlayerObj = nil
        if targetPlayerName and targetPlayerName ~= "Random Player" then
            targetPlayerObj = resolveTargetPlayerByName(targetPlayerName)
            if not targetPlayerObj then
                targetPlayerObj = getRandomPlayer()
            end
        else
            targetPlayerObj = getRandomPlayer()
        end
        local targetPlayer = targetPlayerObj and targetPlayerObj.Name or nil
        lastReceiverName = targetPlayer
        lastReceiverId = targetPlayerObj and targetPlayerObj.UserId or nil
        
        -- Send items to other players
        local sentAnyItem = false
        
        -- Try to send pets first (respect T/M before any action)
        if sendMode == "Pets" or sendMode == "Both" then
            for _, pet in ipairs(petInventory) do
                -- Re-read attributes live before deciding
                pet = refreshItemFromData(pet.uid, false, pet)
                if shouldSendItem(pet, includePetTypes, includePetMutations) and targetPlayer then
                    local sendSuccess = sendItemToPlayer(pet, targetPlayer, "pet")
                    if sendSuccess then
                        sentAnyItem = true
                        task.wait(0.1) -- Optimized wait between successful sends
                        break -- Send one at a time
                    end
                end
            end
        end
        
        -- Try to send eggs if no pets were sent (respect T/M before any action)
        if not sentAnyItem and (sendMode == "Eggs" or sendMode == "Both") then
            for _, egg in ipairs(eggInventory) do
                egg = refreshItemFromData(egg.uid, true, egg)
                -- Use cached selectors if available to avoid UI GetValue glitches
                local tList = (selectedEggTypes and #selectedEggTypes > 0) and selectedEggTypes or includeEggTypes
                local mList = (selectedEggMuts and #selectedEggMuts > 0) and selectedEggMuts or includeEggMutations
                if shouldSendItem(egg, tList, mList) and targetPlayer then
                    local sendSuccess = sendItemToPlayer(egg, targetPlayer, "egg")
                    if sendSuccess then
                        sentAnyItem = true
                        task.wait(0.1) -- Optimized wait between successful sends
                        break -- Send one at a time
                    end
                end
            end
        end
        
        -- Selling removed
        
        -- Auto-delete slow pets if enabled (only for pets, not eggs)
        if autoDeleteMinSpeed > 0 and (sendMode == "Pets" or sendMode == "Both") then
            autoDeleteSlowPets(autoDeleteMinSpeed)
        end
        
        -- Stop if session limit reached
        if sessionLimits.sendPetCount >= sessionLimits.maxSendPet then
            -- Immediately post webhook summary when limit hit
            if not webhookSent and webhookUrl ~= "" and #sessionLogs > 0 then
                task.spawn(sendWebhookSummary)
            end
            trashEnabled = false
            if trashToggle then pcall(function() trashToggle:SetValue(false) end) end
        end
        
        -- Update status
        updateStatus()
        
        task.wait(0.3) -- Optimized wait before next cycle
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
            updateStatus()
            
            WindUI:Notify({
                Title = "🔄 Cache Refreshed",
                Content = "Inventory cache and send progress cleared!",
                Duration = 3
            })
        end
    })
    
    -- Data reload button for "Unknown" items
    TrashTab:Button({
        Title = "🔄 Fix Unknown Items",
        Desc = "Force reload data to fix 'Unknown' pets/eggs (takes a few seconds)",
        Callback = function()
            WindUI:Notify({
                Title = "🔄 Reloading Data",
                Content = "Please wait... fixing Unknown items",
                Duration = 2
            })
            
            task.spawn(function()
                local loadedPets, loadedEggs = forceDataReload()
                updateStatus()
                
                WindUI:Notify({
                    Title = "✅ Data Reloaded",
                    Content = string.format("Loaded %d pets and %d eggs successfully!", loadedPets, loadedEggs),
                    Duration = 4
                })
            end)
        end
    })
    
    -- Send current inventory webhook button
    TrashTab:Button({
        Title = "📤 Send Inventory",
        Desc = "Send current pets/eggs inventory to Discord webhook",
        Callback = function()
            task.spawn(sendCurrentInventoryWebhook)
        end
    })
    
    -- Emergency stop button
    TrashTab:Button({
        Title = "🛑 Emergency Stop",
        Desc = "Immediately stop all trash processing",
        Callback = function()
            trashEnabled = false
            if trashToggle then trashToggle:SetValue(false) end
            clearSendProgress() -- Clear any pending operations
            
            WindUI:Notify({
                Title = "🛑 Emergency Stop",
                Content = "Trash system stopped and cleared!",
                Duration = 3
            })
        end
    })
    
    -- Reset session limits button
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
            
            WindUI:Notify({
                Title = "🔄 Session Reset",
                Content = "Send/sell limits reset!",
                Duration = 2
            })
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
        Config:Register("speedThreshold", speedThresholdSlider)
        Config:Register("sessionLimit", sessionLimitInput)
    end
    
    -- Initial status update
    task.spawn(function()
        task.wait(1)
        updateStatus()
    end)
end

return SendTrashSystem
