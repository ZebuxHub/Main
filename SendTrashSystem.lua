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
local sellPetTypeDropdown
local sellPetMutationDropdown
local speedThresholdSlider
local statusParagraph

-- State variables
local trashEnabled = false
local autoDeleteMinSpeed = 0
local actionCounter = 0

-- Session limits
local sessionLimits = {
    sendPetCount = 0,
    sellPetCount = 0,
    maxSendPet = 50,
    maxSellPet = 50
}

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
                type = safeGetAttribute(petData, "Type", "Unknown"),
                mutation = safeGetAttribute(petData, "Mutation", ""),
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
                type = safeGetAttribute(eggData, "Type", "Unknown"),
                mutation = safeGetAttribute(eggData, "Mutation", ""),
                locked = safeGetAttribute(eggData, "LK", 0) == 1,
                placed = safeGetAttribute(eggData, "D", nil) ~= nil -- Check if egg is placed
            }
            
            table.insert(eggs, eggInfo)
        end
    end
    
    return eggs
end

-- Check if item should be sent/sold based on filters
local function shouldSendItem(item, excludeTypes, excludeMutations)
    -- Don't send/sell locked items
    if item.locked then
        return false
    end
    
    -- Check type exclusions
    if excludeTypes then
        for _, excludeType in ipairs(excludeTypes) do
            if item.type == excludeType then
                return false
            end
        end
    end
    
    -- Check mutation exclusions
    if excludeMutations then
        for _, excludeMutation in ipairs(excludeMutations) do
            if item.mutation == excludeMutation then
                return false
            end
        end
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
        WindUI:Notify({
            Title = "⚠️ Send Limit",
            Content = "Reached maximum send limit for this session (" .. sessionLimits.maxSendPet .. ")",
            Duration = 3
        })
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
    else
        warn("Failed to send " .. itemType .. " " .. itemUID .. " to " .. playerName .. ": " .. tostring(err))
    end
    
    return success
end

-- Sell pet (only pets, no eggs)
local function sellPet(pet)
    if sessionLimits.sellPetCount >= sessionLimits.maxSellPet then
        WindUI:Notify({
            Title = "⚠️ Sell Limit",
            Content = "Reached maximum sell limit for this session (" .. sessionLimits.maxSellPet .. ")",
            Duration = 3
        })
        return false
    end
    
    local petUID = pet.uid
    print("💰 Starting sell process for pet " .. petUID)
    
    -- If pet is placed on ground, remove it first
    if pet.placed then
        print("🏗️ Pet is placed on ground, removing first...")
        removeFromGround(petUID)
        wait(0.1) -- Quick wait after removal
    end
    
    -- Focus the pet first
    focusItem(petUID)
    wait(0.2) -- Quick delay to ensure focus is processed
    
    local success, err = pcall(function()
        local args = {"Sell", petUID}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("PetRE"):FireServer(unpack(args))
    end)
    
    if success then
        sessionLimits.sellPetCount = sessionLimits.sellPetCount + 1
        actionCounter = actionCounter + 1
        print("✅ Sold pet " .. petUID)
    else
        warn("Failed to sell pet " .. petUID .. ": " .. tostring(err))
    end
    
    return success
end

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
    local PetRE = ReplicatedStorage:FindFirstChild("Remote"):FindFirstChild("PetRE")
    
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
        "💰 Pets sold this session: %d/%d\n" ..
        "⚡ Auto-delete speed threshold: %s\n" ..
        "🔄 Actions performed: %d",
        #petInventory,
        #eggInventory,
        sessionLimits.sendPetCount, sessionLimits.maxSendPet,
        sessionLimits.sellPetCount, sessionLimits.maxSellPet,
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
        if sendModeDropdown and sendModeDropdown.GetValue then
            local success, result = pcall(function() return sendModeDropdown:GetValue() end)
            sendMode = success and result or "Both"
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
            wait(1)
            continue
        end
        
        -- Get filter settings
        local excludeTypes = {}
        local excludeMutations = {}
        
        if sendPetTypeDropdown and sendPetTypeDropdown.GetValue then
            local success, result = pcall(function() return sendPetTypeDropdown:GetValue() end)
            excludeTypes = success and result or {}
        end
        
        if sendPetMutationDropdown and sendPetMutationDropdown.GetValue then
            local success, result = pcall(function() return sendPetMutationDropdown:GetValue() end)
            excludeMutations = success and result or {}
        end
        
        -- Get target player
        local targetPlayer = nil
        print("🔍 Checking target player selection...")
        
        if targetPlayerDropdown and targetPlayerDropdown.GetValue then
            local success, result = pcall(function() return targetPlayerDropdown:GetValue() end)
            print("📋 Dropdown GetValue success:", success, "result:", tostring(result))
            
            if success and result then
                if result == "Random Player" then
                    targetPlayer = getRandomPlayer()
                    print("🎲 Using random player: " .. tostring(targetPlayer))
                else
                    -- Use the specifically selected player
                    targetPlayer = result
                    print("🎯 Using selected target player: " .. targetPlayer)
                end
            else
                targetPlayer = getRandomPlayer()
                print("⚠️ Dropdown failed, using random player: " .. tostring(targetPlayer))
            end
        else
            targetPlayer = getRandomPlayer()
            print("❌ No dropdown found, using random player: " .. tostring(targetPlayer))
        end
        
        print("✅ Final target player for this cycle: " .. tostring(targetPlayer))
        print("🎮 Send mode: " .. sendMode)
        
        -- Send items to other players
        local sentAnyItem = false
        
        -- Try to send pets first
        if sendMode == "Pets" or sendMode == "Both" then
            for _, pet in ipairs(petInventory) do
                if shouldSendItem(pet, excludeTypes, excludeMutations) and targetPlayer then
                    print("📦 About to send pet " .. pet.uid .. " to target: " .. tostring(targetPlayer))
                    sendItemToPlayer(pet, targetPlayer, "pet")
                    sentAnyItem = true
                    print("⏸️ Waiting 0.3 seconds before next action...")
                    wait(0.3)
                    break -- Send one at a time
                end
            end
        end
        
        -- Try to send eggs if no pets were sent
        if not sentAnyItem and (sendMode == "Eggs" or sendMode == "Both") then
            for _, egg in ipairs(eggInventory) do
                if shouldSendItem(egg, excludeTypes, excludeMutations) and targetPlayer then
                    print("📦 About to send egg " .. egg.uid .. " to target: " .. tostring(targetPlayer))
                    sendItemToPlayer(egg, targetPlayer, "egg")
                    sentAnyItem = true
                    print("⏸️ Waiting 0.3 seconds before next action...")
                    wait(0.3)
                    break -- Send one at a time
                end
            end
        end
        
        -- If no items were sent, try selling pets (only pets, no eggs)
        if not sentAnyItem and (sendMode == "Pets" or sendMode == "Both") then
            local sellExcludeTypes = {}
            local sellExcludeMutations = {}
            
            if sellPetTypeDropdown and sellPetTypeDropdown.GetValue then
                local success, result = pcall(function() return sellPetTypeDropdown:GetValue() end)
                sellExcludeTypes = success and result or {}
            end
            
            if sellPetMutationDropdown and sellPetMutationDropdown.GetValue then
                local success, result = pcall(function() return sellPetMutationDropdown:GetValue() end)
                sellExcludeMutations = success and result or {}
            end
            
            for _, pet in ipairs(petInventory) do
                if shouldSendItem(pet, sellExcludeTypes, sellExcludeMutations) then
                    sellPet(pet)
                    wait(0.3)
                    break -- Sell one at a time
                end
            end
        end
        
        -- Auto-delete slow pets if enabled (only for pets, not eggs)
        if autoDeleteMinSpeed > 0 and (sendMode == "Pets" or sendMode == "Both") then
            autoDeleteSlowPets(autoDeleteMinSpeed)
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
    
    -- Speed threshold for auto-delete
    speedThresholdSlider = TrashTab:Input({
        Title = "Auto Delete Speed Threshold",
        Desc = "Delete pets below this speed automatically (0 = disabled)",
        Default = "0",
        Numeric = true,
        Finished = true,
        Callback = function(value)
            local numValue = tonumber(value) or 0
            autoDeleteMinSpeed = numValue
            if numValue > 0 then
                print("Auto Delete: Enabled for pets below speed " .. numValue)
            else
                print("Auto Delete: Disabled")
            end
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
        Callback = function(selection) end
    })
    
    TrashTab:Section({ Title = "📤 Send Pet Filters", Icon = "mail" })
    
    -- Send pet type filter
    sendPetTypeDropdown = TrashTab:Dropdown({
        Title = "🚫 Exclude Pet Types (from sending)",
        Desc = "Select pet types to NOT send (empty = send all types)",
        Values = getAllPetTypes(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection) end
    })
    
    -- Send pet mutation filter
    sendPetMutationDropdown = TrashTab:Dropdown({
        Title = "🚫 Exclude Pet Mutations (from sending)", 
        Desc = "Select mutations to NOT send (empty = send all mutations)",
        Values = getAllMutations(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection) end
    })
    
    TrashTab:Section({ Title = "💰 Sell Pet Filters", Icon = "dollar-sign" })
    
    -- Sell pet type filter
    sellPetTypeDropdown = TrashTab:Dropdown({
        Title = "🚫 Exclude Pet Types (from selling)",
        Desc = "Select pet types to NOT sell (empty = sell all types)",
        Values = getAllPetTypes(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection) end
    })
    
    -- Sell pet mutation filter
    sellPetMutationDropdown = TrashTab:Dropdown({
        Title = "🚫 Exclude Pet Mutations (from selling)",
        Desc = "Select mutations to NOT sell (empty = sell all mutations)",
        Values = getAllMutations(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection) end
    })
    
    TrashTab:Section({ Title = "🛠️ Manual Controls", Icon = "settings" })
    
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
            if sellPetTypeDropdown and sellPetTypeDropdown.SetValues then
                pcall(function() sellPetTypeDropdown:SetValues(getAllPetTypes()) end)
            end
            if sellPetMutationDropdown and sellPetMutationDropdown.SetValues then
                pcall(function() sellPetMutationDropdown:SetValues(getAllMutations()) end)
            end
            
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
            sessionLimits.sellPetCount = 0
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
        Config:Register("sellPetTypeFilter", sellPetTypeDropdown)
        Config:Register("sellPetMutationFilter", sellPetMutationDropdown)
        Config:Register("speedThreshold", speedThresholdSlider)
    end
    
    -- Initial status update
    task.spawn(function()
        task.wait(1)
        updateStatus()
    end)
end

return SendTrashSystem
