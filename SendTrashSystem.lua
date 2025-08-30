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
    if not userId then return nil end
    return "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(userId) .. "&width=180&height=180&format=png"
end

local function sendWebhookSummary()
    if webhookSent or webhookUrl == "" or #sessionLogs == 0 then return end
    local totalSent = sessionLimits.sendPetCount
    local fields = { { name = "Items Sent", value = tostring(totalSent), inline = true } }
    local details = ""
    local startIdx = math.max(1, #sessionLogs - 9)
    for i = startIdx, #sessionLogs do
        local it = sessionLogs[i]
        local emoji = (it.kind == "egg" and EggEmojiMap[it.type or ""]) or (it.kind == "pet" and "🐾") or "📦"
        local line = string.format("%s %s • %s → %s", emoji, it.type or it.uid, it.mutation and ("[" .. it.mutation .. "]") or "[None]", it.receiver or "?")
        details = details .. line .. "\n"
    end
    local last = sessionLogs[#sessionLogs]
    local thumb = last and getIconUrlFor(last.kind, last.type) or nil
    local authorName = lastReceiverName or (sessionLogs[#sessionLogs] and sessionLogs[#sessionLogs].receiver) or nil
    local authorIcon = lastReceiverId and getAvatarUrl(lastReceiverId) or nil
    local payload = {
        embeds = {
            {
                title = "Send Trash • Session Summary",
                description = details ~= "" and details or "No items were sent.",
                color = 5814783,
                fields = fields,
                thumbnail = thumb and { url = thumb } or nil,
                image = thumb and { url = thumb } or nil,
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
local function getPetInventory()
    local pets = {}
    
    if not LocalPlayer or not LocalPlayer.PlayerGui or not LocalPlayer.PlayerGui.Data then
        return pets
    end
    
    local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
    if not petsFolder then
        return pets
    end
    
    for _, petData in pairs(petsFolder:GetChildren()) do
        if petData:IsA("Configuration") then
            local petInfo = {
                uid = petData.Name,
                type = safeGetAttribute(petData, "T", safeGetAttribute(petData, "Type", "Unknown")),
                mutation = safeGetAttribute(petData, "M", safeGetAttribute(petData, "Mutation", "")),
                speed = safeGetAttribute(petData, "Speed", 0),
                locked = safeGetAttribute(petData, "LK", 0) == 1,
                placed = safeGetAttribute(petData, "D", nil) ~= nil -- Check if pet is placed
            }
            
            table.insert(pets, petInfo)
        end
    end
    
    return pets
end

-- Get egg inventory
local function getEggInventory()
    local eggs = {}
    
    if not LocalPlayer or not LocalPlayer.PlayerGui or not LocalPlayer.PlayerGui.Data then
        return eggs
    end
    
    local eggsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
    if not eggsFolder then
        return eggs
    end
    
    for _, eggData in pairs(eggsFolder:GetChildren()) do
        if eggData:IsA("Configuration") then
            local eggInfo = {
                uid = eggData.Name,
                -- Match by T for eggs (fallback to Type)
                type = safeGetAttribute(eggData, "T", safeGetAttribute(eggData, "Type", "Unknown")),
                mutation = safeGetAttribute(eggData, "M", safeGetAttribute(eggData, "Mutation", "")),
                locked = safeGetAttribute(eggData, "LK", 0) == 1,
                placed = safeGetAttribute(eggData, "D", nil) ~= nil -- Check if egg is placed
            }
            
            table.insert(eggs, eggInfo)
        end
    end
    
    return eggs
end

-- Refresh live attributes (T/M/locked/placed) for a given uid directly from PlayerGui.Data
local function refreshItemFromData(uid, isEgg, into)
    local dataRoot = LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Data")
    if not dataRoot then return into end
    local folder = dataRoot:FindFirstChild(isEgg and "Egg" or "Pets")
    if not folder then return into end
    local conf = folder:FindFirstChild(uid)
    if conf and conf:IsA("Configuration") then
        local tVal
        tVal = safeGetAttribute(conf, "T", nil) or safeGetAttribute(conf, "Type", nil)
        local mVal = safeGetAttribute(conf, "M", nil) or safeGetAttribute(conf, "Mutation", "")
        local locked = safeGetAttribute(conf, "LK", 0) == 1
        local placed = safeGetAttribute(conf, "D", nil) ~= nil
        if into then
            into.type = tVal or into.type
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
    print("🏗️ Removing item from ground: " .. tostring(itemUID))
    
    local success, err = pcall(function()
        local args = {"Del", itemUID}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    if success then
        print("✅ Item " .. itemUID .. " removed from ground")
    else
        warn("❌ Failed to remove item " .. itemUID .. " from ground: " .. tostring(err))
    end
    
    return success
end

-- Focus pet/egg before sending/selling (exactly like manual method)
local function focusItem(itemUID)
    print("🔍 Focusing item: " .. tostring(itemUID))
    
    local success, err = pcall(function()
        local args = {"Focus", itemUID}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    if success then
        print("🎯 Focus command sent successfully for item " .. itemUID)
    else
        warn("❌ Failed to focus item " .. itemUID .. ": " .. tostring(err))
    end
    
    return success
end

-- Send item (pet or egg) to player
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
    print("🚀 Starting send process for " .. itemType .. " " .. itemUID .. " to " .. playerName)
    
    -- If item is placed on ground, remove it first
    if item.placed then
        print("🏗️ Item is placed on ground, removing first...")
        removeFromGround(itemUID)
        wait(0.1) -- Quick wait after removal
    end
    
    -- Focus the item first (REQUIRED before sending)
    focusItem(itemUID)
    print("⏳ Waiting 0.3 seconds for focus to process...")
    wait(0.3) -- Quick wait for focus to process
    
    local success, err = pcall(function()
        -- Find the target player object
        local targetPlayer = Players:FindFirstChild(playerName)
        if not targetPlayer then
            error("Player " .. playerName .. " not found")
        end
        
        print("📤 Sending to player: " .. playerName .. " (Player object found)")
        local args = {targetPlayer}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(unpack(args))
        print("📮 GiftRE fired successfully")
    end)
    
    if success then
        sessionLimits.sendPetCount = sessionLimits.sendPetCount + 1
        actionCounter = actionCounter + 1
        print("✅ Sent " .. itemType .. " " .. itemUID .. " to " .. playerName)
        -- Log for webhook
        table.insert(sessionLogs, {
            kind = itemType,
            uid = itemUID,
            type = item.type,
            mutation = (item.mutation ~= nil and item.mutation ~= "" and item.mutation) or "None",
            receiver = playerName,
        })
    else
        warn("Failed to send " .. itemType .. " " .. itemUID .. " to " .. playerName .. ": " .. tostring(err))
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
        "🔄 Actions performed: %d",
        #petInventory,
        #eggInventory,
        sessionLimits.sendPetCount, sessionLimits.maxSendPet,
        autoDeleteMinSpeed > 0 and tostring(autoDeleteMinSpeed) or "Disabled",
        actionCounter
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
                print("🎮 Dropdown returned send mode: " .. tostring(sendMode))
            else
                print("❌ Failed to get send mode from dropdown, using default: Both")
                sendMode = "Both"
            end
        else
            print("❌ Send mode dropdown not found, using default: Both")
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
                print("⚠️ Selected player not found, falling back to random")
                targetPlayerObj = getRandomPlayer()
            end
        else
            targetPlayerObj = getRandomPlayer()
        end
        local targetPlayer = targetPlayerObj and targetPlayerObj.Name or nil
        lastReceiverName = targetPlayer
        lastReceiverId = targetPlayerObj and targetPlayerObj.UserId or nil
        print("✅ Final target player for this cycle: " .. tostring(targetPlayer or "nil"))
        print("🎮 Send mode: " .. sendMode)
        
        -- Send items to other players
        local sentAnyItem = false
        
        -- Try to send pets first (respect T/M before any action)
        if sendMode == "Pets" or sendMode == "Both" then
            for _, pet in ipairs(petInventory) do
                -- Re-read attributes live before deciding
                pet = refreshItemFromData(pet.uid, false, pet)
                if shouldSendItem(pet, includePetTypes, includePetMutations) and targetPlayer then
                    local petName = pet.type or pet.uid
                    print("📦 About to send pet " .. petName .. " to target: " .. tostring(targetPlayer))
                    sendItemToPlayer(pet, targetPlayer, "pet")
                    sentAnyItem = true
                    wait(0.3)
                    break -- Send one at a time
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
                    local eggName = egg.type or egg.uid
                    print("📦 About to send egg " .. eggName .. " to target: " .. tostring(targetPlayer))
                    sendItemToPlayer(egg, targetPlayer, "egg")
                    sentAnyItem = true
                    wait(0.3)
                    break -- Send one at a time
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
        
        wait(0.5) -- Quick wait before next cycle
    end
end

-- Initialize function
function SendTrashSystem.Init(dependencies)
    WindUI = dependencies.WindUI
    Window = dependencies.Window
    Config = dependencies.Config
    
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
                    task.spawn(function()
                        local success, err = pcall(function()
                            local totalSent = sessionLimits.sendPetCount
                            local totalSold = sessionLimits.sellPetCount
                            local fields = {}
                            table.insert(fields, { name = "Items Sent", value = tostring(totalSent), inline = true })
                            
                            -- Build concise description list (last 10 items)
                            local details = ""
                            local startIdx = math.max(1, #sessionLogs - 9)
                            for i = startIdx, #sessionLogs do
                                local it = sessionLogs[i]
                                details = details .. string.format("%s • %s [%s] → %s\n", it.kind, it.type or it.uid, it.mutation or "None", it.receiver or "?")
                            end
                            
                            local payload = {
                                embeds = {
                                    {
                                        title = "Send Trash Session Summary",
                                        description = details ~= "" and details or "No items were sent.",
                                        color = 5814783,
                                        fields = fields,
                                        footer = { text = "Build A Zoo" },
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
                                    Body = json,
                                })
                            end
                        end)
                        if success then webhookSent = true end
                    end)
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
    
    -- Webhook input (optional)
    TrashTab:Input({
        Title = "Webhook URL (optional)",
        Desc = "Discord webhook to receive session summary",
        Default = webhookUrl,
        Numeric = false,
        Finished = true,
        Callback = function(value)
            webhookUrl = tostring(value or "")
            webhookSent = false
        end,
    })
    
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
    
    -- Emergency stop button
    TrashTab:Button({
        Title = "🛑 Emergency Stop",
        Desc = "Immediately stop all trash processing",
        Callback = function()
            trashEnabled = false
            if trashToggle then trashToggle:SetValue(false) end
            
            WindUI:Notify({
                Title = "🛑 Emergency Stop",
                Content = "Trash system stopped!",
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
