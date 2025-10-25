-- AutoFeedSystem.lua - Auto Feed functionality for Build A Zoo
-- Author: Zebux
-- Version: 1.0

local AutoFeedSystem = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Dependencies (will be set during Init)
local WindUI = nil
local Tabs = nil
local AutoSystemsConfig = nil
local CustomUIConfig = nil
local StationFeedSetup = nil -- NEW: Station-First UI

-- UI Elements
local autoFeedToggle = nil

-- State variables
local autoFeedEnabled = false
local autoFeedThread = nil
local selectedFeedFruits = {}
local feedFruitSelectionVisible = false

-- Export stationFruitAssignments for external access
-- NEW STRUCTURE: {StationID: {FruitID: true}}
AutoFeedSystem.stationFruitAssignments = {}

-- Normalization helpers to robustly match fruit names from PlayerGui.Data.Asset
local function normalizeFruitName(name)
    if type(name) ~= "string" then return "" end
    local lowered = string.lower(name)
    lowered = lowered:gsub("[%s_%-%./]", "")
    return lowered
end

-- Canonical fruit list used by the auto-feed system
local KNOWN_FRUITS = {
    "Strawberry",
    "Blueberry",
    "Watermelon",
    "Apple",
    "Orange",
    "Corn",
    "Banana",
    "Grape",
    "Pear",
    "Peach",
    "Pineapple",
    "GoldMango",
    "BloodstoneCycad",
    "ColossalPinecone",
    "VoltGinkgo",
    "DeepseaPearlFruit",
    "DragonFruit",
    "Durian",
}

local CANONICAL_FRUIT_BY_NORMALIZED = {}
for _, fruitName in ipairs(KNOWN_FRUITS) do
    CANONICAL_FRUIT_BY_NORMALIZED[normalizeFruitName(fruitName)] = fruitName
end

-- Augment canonical map from the player's Asset attributes dynamically
local function augmentCanonicalFromAsset(asset)
    if not asset then return end
    local ok, attrs = pcall(function()
        return asset:GetAttributes()
    end)
    if ok and type(attrs) == "table" then
        for k, _ in pairs(attrs) do
            local n = normalizeFruitName(k)
            if n ~= "" and not CANONICAL_FRUIT_BY_NORMALIZED[n] then
                CANONICAL_FRUIT_BY_NORMALIZED[n] = k
            end
        end
    end
end

-- Helper function to find which BigPet station a pet is near
local function findBigPetStationForPet(petPosition)
    local localPlayer = game:GetService("Players").LocalPlayer
    if not localPlayer then return nil end
    
    -- Get player's island
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
    
    -- Find closest BigPet station
    local closestStation = nil
    local closestDistance = math.huge
    
    for _, station in ipairs(bigPetFolder:GetChildren()) do
        if station:IsA("BasePart") then
            local distance = (station.Position - petPosition).Magnitude
            if distance < closestDistance and distance < 50 then -- Within 50 studs
                closestDistance = distance
                closestStation = station.Name
            end
        end
    end
    
    return closestStation
end

-- Auto Feed Functions
function AutoFeedSystem.getBigPets()
    local pets = {}
    local localPlayer = game:GetService("Players").LocalPlayer
    
    if not localPlayer then
        warn("Auto Feed: LocalPlayer not found")
        return pets
    end
    
    -- Get Data.Pets folder (PRIMARY SOURCE - same as StationFeedSetup)
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then 
        print("[AutoFeed] ❌ PlayerGui not found")
        return pets 
    end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then 
        print("[AutoFeed] ❌ Data not found")
        return pets 
    end
    
    local petsDataFolder = data:FindFirstChild("Pets")
    if not petsDataFolder then 
        print("[AutoFeed] ❌ Pets folder not found in Data")
        return pets 
    end
    
    print("[AutoFeed] 🔍 Scanning Data.Pets for BPSK/BPV attributes...")
    
    -- Scan all pet configurations (SAME AS StationFeedSetup)
    for _, petConfig in ipairs(petsDataFolder:GetChildren()) do
        if petConfig:IsA("Configuration") then
            -- Check if this is a Big Pet by looking for BPSK or BPV attributes
            local bpsk = petConfig:GetAttribute("BPSK")
            local bpv = petConfig:GetAttribute("BPV")
            
            if bpsk or bpv then
                print("[AutoFeed] ✅ Found Big Pet: " .. petConfig.Name)
                
                -- This is a Big Pet!
                local petUID = petConfig.Name
                
                -- Try to find the pet model in workspace.Pets to get position and GUI
                local workspacePets = workspace:FindFirstChild("Pets")
                local petModel = workspacePets and workspacePets:FindFirstChild(petUID)
                
                local stationId = nil
                local bigPetGUI = nil
                local rootPart = nil
                
                -- If pet is in workspace, get additional info
                if petModel then
                    rootPart = petModel:FindFirstChild("RootPart")
                    if rootPart then
                        stationId = findBigPetStationForPet(rootPart.Position)
                        
                        -- Get BigPetGUI for feeding status
                        local gui = rootPart:FindFirstChild("GUI")
                        if gui then
                            bigPetGUI = gui:FindFirstChild("BigPetGUI")
                        end
                    end
                end
                
                -- Use BPSK as station ID if available and no station found
                if not stationId and bpsk then
                    stationId = tostring(bpsk)
                end
                
                -- If still no station ID, use a placeholder
                if not stationId then
                    stationId = "Unknown"
                end
                
                print("[AutoFeed] 📍 Station ID: " .. stationId)
                
                -- Add to list
                table.insert(pets, {
                    model = petModel,
                    name = petUID,
                    stationId = stationId,
                    rootPart = rootPart,
                    bigPetGUI = bigPetGUI
                })
            end
        end
    end
    
    print("[AutoFeed] 📊 Total Big Pets found: " .. #pets)
    
    return pets
end

-- Function to get player's fruit inventory
function AutoFeedSystem.getPlayerFruitInventory()
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
    
    -- 1) Read from Attributes (primary source in many games)
    local attrMap = {}
    local ok, attrs = pcall(function()
        return asset:GetAttributes()
    end)
    if ok and type(attrs) == "table" then
        attrMap = attrs
    end

    -- Include all attribute keys in canonical mapping to support new fruits
    augmentCanonicalFromAsset(asset)

    for _, canonicalName in ipairs(KNOWN_FRUITS) do
        local amount = attrMap[canonicalName]
        if amount == nil then
            -- try normalized key match
            local want = normalizeFruitName(canonicalName)
            for k, v in pairs(attrMap) do
                if normalizeFruitName(k) == want then
                    amount = v
                    break
                end
            end
        end
        if type(amount) == "string" then amount = tonumber(amount) or 0 end
        if type(amount) == "number" and amount > 0 then
            fruitInventory[canonicalName] = amount
        end
    end

    -- 2) Merge children values as fallback
    for _, child in pairs(asset:GetChildren()) do
        if child:IsA("StringValue") or child:IsA("IntValue") or child:IsA("NumberValue") then
            local rawName = child.Name
            local normalized = normalizeFruitName(rawName)
            local canonicalName = CANONICAL_FRUIT_BY_NORMALIZED[normalized]
            if canonicalName then
                local fruitAmount = child.Value
                if type(fruitAmount) == "string" then
                    fruitAmount = tonumber(fruitAmount) or 0
                end
                if fruitAmount and fruitAmount > 0 then
                    fruitInventory[canonicalName] = fruitAmount
                end
            end
        end
    end
    
    return fruitInventory
end

function AutoFeedSystem.isPetEating(petData)
    if not petData then
        return true -- Assume eating if no pet data
    end
    
    -- If no GUI, assume pet is ready (don't block feeding)
    if not petData.bigPetGUI then
        return false -- Pet is ready to feed
    end
    
    local feedGUI = petData.bigPetGUI:FindFirstChild("Feed")
    if not feedGUI then
        return false -- No feed GUI, assume ready to feed
    end
    
    -- Check if Feed frame is visible - if not visible, pet is ready to feed
    if not feedGUI.Visible then
        return false -- Pet is ready to feed
    end
    
    local feedText = feedGUI:FindFirstChild("TXT")
    if not feedText or not feedText:IsA("TextLabel") then
        return false -- No text, assume ready to feed
    end
    
    local feedTime = feedText.Text
    if not feedTime or type(feedTime) ~= "string" then
        return false -- No valid text, assume ready to feed
    end
    
    -- Pet is ready to eat when text is "00:00", "???", or ""
    if feedTime == "00:00" or feedTime == "???" or feedTime == "" then
        return false -- Pet is ready to feed
    end
    
    -- Check for stuck timer (00:01 for more than 2 seconds)
    local currentTime = tick()
    local petKey = petData.name
    
    -- Initialize stuck timer tracking if not exists
    if not AutoFeedSystem.stuckTimers then
        AutoFeedSystem.stuckTimers = {}
    end
    
    if feedTime == "00:01" then
        if not AutoFeedSystem.stuckTimers[petKey] then
            -- First time seeing 00:01, start timer
            AutoFeedSystem.stuckTimers[petKey] = currentTime
            return true -- Still eating for now
        else
            -- Check how long it's been stuck at 00:01
            local stuckDuration = currentTime - AutoFeedSystem.stuckTimers[petKey]
            if stuckDuration > 2 then
                -- Been stuck for more than 2 seconds, treat as ready
                AutoFeedSystem.stuckTimers[petKey] = nil -- Reset timer
                return false -- Pet is ready to feed
            end
            return true -- Still eating
        end
    else
        -- Timer is not 00:01, reset stuck timer
        AutoFeedSystem.stuckTimers[petKey] = nil
        
        -- If timer shows any other time, pet is eating
        return true
    end
end

function AutoFeedSystem.equipFruit(fruitName)
    if not fruitName or type(fruitName) ~= "string" then
        return false
    end
    
    -- Try multiple candidate keys to maximize compatibility
    local candidates = {}
    table.insert(candidates, fruitName)
    local lower = string.lower(fruitName)
    local upper = string.upper(fruitName)
    table.insert(candidates, lower)
    table.insert(candidates, upper)
    local underscored = tostring(fruitName):gsub(" ", "_")
    table.insert(candidates, underscored)
    table.insert(candidates, string.lower(underscored))
    -- Also try canonical name if we can resolve it via normalization
    local canonical = CANONICAL_FRUIT_BY_NORMALIZED[normalizeFruitName(fruitName)]
    if canonical and canonical ~= fruitName then table.insert(candidates, canonical) end

    for _, key in ipairs(candidates) do
        local args = { "Focus", key }
        local ok, err = pcall(function()
            ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
        end)
        if ok then
            return true
        end
    end
    warn("Failed to equip fruit after trying candidates for " .. tostring(fruitName))
    return false
end

function AutoFeedSystem.feedPet(petName)
    if not petName or type(petName) ~= "string" then
        return false
    end
    
    local args = {
        "Feed",
        petName
    }
    local ok, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("PetRE"):FireServer(unpack(args))
    end)
    if not ok then
        warn("Failed to feed pet " .. tostring(petName) .. ": " .. tostring(err))
        return false
    end
    return true
end

function AutoFeedSystem.runAutoFeed(getAutoFeedEnabled, getSelectedBigPets, updateFeedStatusParagraph, getSelectedFruits)
    print("[AutoFeed] 🚀 Starting Auto Feed system...")
    
    -- Initialize feedFruitStatus if needed (for backward compatibility)
    local feedFruitStatus = {
        petsFound = 0,
        availablePets = 0,
        totalFeeds = 0,
        lastFedPet = nil,
        lastAction = ""
    }
    
    while getAutoFeedEnabled() do
        local shouldContinue = true
        local ok, err = pcall(function()
            print("[AutoFeed] 🔍 Scanning for Big Pets...")
            local allBigPets = AutoFeedSystem.getBigPets()
            
            feedFruitStatus.petsFound = #allBigPets
            feedFruitStatus.availablePets = 0
            
            print("[AutoFeed] 📊 Found " .. #allBigPets .. " Big Pets")
            
            if #allBigPets == 0 then
                feedFruitStatus.lastAction = "No Big Pets found"
                print("[AutoFeed] ❌ No Big Pets found")
                if updateFeedStatusParagraph then
                    updateFeedStatusParagraph()
                end
                shouldContinue = false
                return
            end
            
            -- Check each pet for feeding opportunity
            for _, petData in ipairs(allBigPets) do
                if not getAutoFeedEnabled() then break end
                
                print("[AutoFeed] 🐾 Checking pet: " .. (petData.stationId or petData.name))
                
                local isEating = AutoFeedSystem.isPetEating(petData)
                
                print("[AutoFeed] 🍽️ Pet eating status: " .. tostring(isEating))
                
                if not isEating then
                    feedFruitStatus.availablePets = feedFruitStatus.availablePets + 1
                    
                        -- Get player's fruit inventory
                        local fruitInventory = AutoFeedSystem.getPlayerFruitInventory()
                        
                        -- Debug: Print player's fruit inventory
                        print("[AutoFeed] 🎒 Player fruit inventory:")
                        for fruitName, amount in pairs(fruitInventory) do
                            print("  - " .. tostring(fruitName) .. ": " .. tostring(amount))
                        end
                        
                    -- Get station-fruit assignments (NEW STRUCTURE)
                    local stationFruitAssignments = AutoFeedSystem.stationFruitAssignments or {}
                    
                    -- Check if this station has any fruit assignments
                    local stationId = petData.stationId
                    local assignedFruits = stationFruitAssignments[stationId]
                    
                    print("[AutoFeed] 🎯 Station " .. (stationId or "?") .. " - Checking fruit assignments...")
                    
                    -- Debug: Print all assigned fruits for this station
                    if assignedFruits and next(assignedFruits) then
                        print("[AutoFeed] 📋 Assigned fruits for Station " .. (stationId or "?") .. ":")
                        for fruitId, _ in pairs(assignedFruits) do
                            print("  - " .. tostring(fruitId))
                        end
                    end
                    
                    if not assignedFruits or not next(assignedFruits) then
                        -- No fruits assigned to this station = skip
                        feedFruitStatus.lastAction = "⏭️ Station " .. (stationId or "?") .. " has no fruit assignments"
                        print("[AutoFeed] ⏭️ No fruits assigned to Station " .. (stationId or "?"))
                        if updateFeedStatusParagraph then
                            updateFeedStatusParagraph()
                                end
                            else
                            -- Try to feed with assigned fruits only
                            print("[AutoFeed] 🍎 Trying assigned fruits for Station " .. (stationId or "?"))
                            for fruitName, _ in pairs(assignedFruits) do
                                if not getAutoFeedEnabled() then break end
                                
                                print("[AutoFeed] 🍎 Checking fruit: " .. fruitName)
                                
                                -- Check if player has this fruit
                                local fruitAmount = fruitInventory[fruitName] or 0
                                if fruitAmount <= 0 then
                                feedFruitStatus.lastAction = "❌ No " .. fruitName .. " in inventory"
                                print("[AutoFeed] ❌ No " .. fruitName .. " in inventory")
                                if updateFeedStatusParagraph then
                                    updateFeedStatusParagraph()
                                end
                                task.wait(0.5)
                            else
                                    -- Update status to show which pet we're trying to feed (use Station ID)
                                    local petDisplayName = petData.stationId or petData.name
                                    feedFruitStatus.lastAction = "Trying to feed Station " .. petDisplayName .. " with " .. fruitName .. " (" .. fruitAmount .. " left)"
                                    print("[AutoFeed] 🎯 Attempting to feed Station " .. petDisplayName .. " with " .. fruitName .. " (" .. fruitAmount .. " available)")
                                if updateFeedStatusParagraph then
                                    updateFeedStatusParagraph()
                                end
                                
                                -- Always equip the fruit before feeding (every time) - with retry
                                local equipSuccess = false
                                for retry = 1, 3 do -- Try up to 3 times
                                    if AutoFeedSystem.equipFruit(fruitName) then
                                        equipSuccess = true
                                        break
                                    else
                                        task.wait(0.2) -- Wait before retry
                                    end
                                end
                                
                                if equipSuccess then
                                    task.wait(0.5) -- Wait for equip to register before feeding
                                    
                                        -- Feed the pet - with retry (still use UID for server call)
                                    local feedSuccess = false
                                    for retry = 1, 3 do -- Try up to 3 times
                                        if AutoFeedSystem.feedPet(petData.name) then
                                            feedSuccess = true
                                            break
                                        else
                                            task.wait(0.2) -- Wait before retry
                                        end
                                    end
                                    
                                    if feedSuccess then
                                            feedFruitStatus.lastFedPet = petDisplayName
                                        feedFruitStatus.totalFeeds = feedFruitStatus.totalFeeds + 1
                                            feedFruitStatus.lastAction = "✅ Fed Station " .. petDisplayName .. " with " .. fruitName
                                        if updateFeedStatusParagraph then
                                            updateFeedStatusParagraph()
                                        end
                                        
                                        task.wait(1.5) -- Wait longer before trying next pet
                                        break -- Move to next pet
                                    else
                                            feedFruitStatus.lastAction = "❌ Failed to feed Station " .. petDisplayName .. " with " .. fruitName .. " after 3 attempts"
                                        if updateFeedStatusParagraph then
                                            updateFeedStatusParagraph()
                                        end
                                    end
                                else
                                        feedFruitStatus.lastAction = "❌ Failed to equip " .. fruitName .. " for Station " .. petDisplayName .. " after 3 attempts"
                                    if updateFeedStatusParagraph then
                                        updateFeedStatusParagraph()
                                    end
                                end
                                
                                task.wait(0.3) -- Small delay between fruit attempts
                            end
                        end
                        end -- Close if not assignedFruits
                    else
                    -- Show which pets are currently eating (use Station ID)
                    local petDisplayName = petData.stationId or petData.name
                    feedFruitStatus.lastAction = "Station " .. petDisplayName .. " is currently eating"
                        if updateFeedStatusParagraph then
                            updateFeedStatusParagraph()
                        end
                end -- Close for _, petData
            end
            
            if feedFruitStatus.availablePets == 0 then
                feedFruitStatus.lastAction = "All pets are currently eating"
                if updateFeedStatusParagraph then
                    updateFeedStatusParagraph()
                end
            end
        end)
        
        if not ok then
            warn("Auto Feed error: " .. tostring(err))
            feedFruitStatus.lastAction = "Error: " .. tostring(err)
            if updateFeedStatusParagraph then
                updateFeedStatusParagraph()
            end
            task.wait(1) -- Wait before retrying
        elseif not shouldContinue then
            -- No big pets found, wait longer before checking again
            task.wait(3)
        else
            -- Normal operation, wait before next cycle
            task.wait(2)
        end
    end
end

-- Debug function to help troubleshoot auto feed issues
function AutoFeedSystem.debugAutoFeed()
    local localPlayer = game:GetService("Players").LocalPlayer
    if not localPlayer then
        return
    end
    
    local petsFolder = workspace:FindFirstChild("Pets")
    if not petsFolder then
        return
    end
    
    local totalPets = 0
    local myPets = 0
    local bigPets = 0
    local availablePets = 0
    
    for _, petModel in ipairs(petsFolder:GetChildren()) do
        if petModel:IsA("Model") then
            totalPets = totalPets + 1
            local rootPart = petModel:FindFirstChild("RootPart")
            if rootPart then
                local petUserId = rootPart:GetAttribute("UserId")
                if petUserId and tostring(petUserId) == tostring(localPlayer.UserId) then
                    myPets = myPets + 1
                    local bigPetGUI = rootPart:FindFirstChild("GUI/BigPetGUI")
                    if bigPetGUI then
                        bigPets = bigPets + 1
                        
                        -- Check feed status
                        local feedGUI = bigPetGUI:FindFirstChild("Feed")
                        if feedGUI then
                            local feedText = feedGUI:FindFirstChild("TXT")
                            if feedText and feedText:IsA("TextLabel") then
                                local feedTime = feedText.Text
                                local feedVisible = feedGUI.Visible
                                
                                -- Check if ready using the same logic as isPetEating
                                local isReady = false
                                if not feedVisible then
                                    isReady = true
                                elseif feedTime == "00:00" or feedTime == "???" or feedTime == "" then
                                    isReady = true
                                end
                                
                                if isReady then
                                    availablePets = availablePets + 1
                                else
                                end
                            else
                            end
                        else
                        end
                    else
                    end
                end
            end
        end
    end
    
    -- Check fruit inventory
    local fruitInventory = AutoFeedSystem.getPlayerFruitInventory()
    local fruitCount = 0
    for fruitName, amount in pairs(fruitInventory) do
        if amount > 0 then
            fruitCount = fruitCount + 1
        end
    end

end

-- (Removed unused helper functions: getAssignedIslandName, getAvailableBigPets, updateCustomUISelection)

-- Initialize the Auto Feed System
function AutoFeedSystem.Init(windUIRef, tabsRef, autoSystemsConfigRef, customUIConfigRef, stationFeedSetupRef)
    WindUI = windUIRef
    Tabs = tabsRef
    AutoSystemsConfig = autoSystemsConfigRef
    CustomUIConfig = customUIConfigRef
    StationFeedSetup = stationFeedSetupRef -- NEW: Station-First UI
    
    -- Load saved assignments from customSelections (JSON file)
    task.wait(0.1)  -- Small delay to ensure customSelections is loaded
    
    if _G.customSelections and _G.customSelections.stationFruitAssignments then
        local success, err = pcall(function()
            local savedStationAssignments = _G.customSelections.stationFruitAssignments or {}
            
            -- Deep copy to ensure we have a proper table structure
            AutoFeedSystem.stationFruitAssignments = {}
            for stationId, fruits in pairs(savedStationAssignments) do
                AutoFeedSystem.stationFruitAssignments[stationId] = {}
                for fruitId, value in pairs(fruits) do
                    AutoFeedSystem.stationFruitAssignments[stationId][fruitId] = value
        end
    end
    
            -- Count loaded stations (silent)
            local stationCount = 0
            for stationId, fruits in pairs(AutoFeedSystem.stationFruitAssignments) do
                stationCount = stationCount + 1
            end
        end)
        
        if not success then
            warn("[AutoFeed] ❌ Failed to load: " .. tostring(err))
        end
    else
        AutoFeedSystem.stationFruitAssignments = {}
    end
end

-- Helper function to count table keys
function AutoFeedSystem.getTableKeys(tbl)
    local keys = {}
    if type(tbl) == "table" then
        for k, _ in pairs(tbl) do
            table.insert(keys, k)
        end
    end
    return keys
end

-- Create UI function
function AutoFeedSystem.CreateUI()
    if not Tabs or not Tabs.ShopTab then
        warn("[AutoFeedSystem] Tabs.ShopTab not available")
        return
    end
    
    -- Section header
    Tabs.ShopTab:Section({ Title = "Auto Feed", Icon = "coffee" })
    
    -- NEW: Station Feed Setup UI Button
    Tabs.ShopTab:Button({
        Title = "Open Station Feed Setup",
        Desc = "Assign fruits to each station (One click!)",
        Callback = function()
            if not feedFruitSelectionVisible then
                if StationFeedSetup then
                    StationFeedSetup.Show(
                        function(stationAssignments)
                            -- Save station-fruit assignments (NEW STRUCTURE)
                            AutoFeedSystem.stationFruitAssignments = stationAssignments or {}
                            
                            -- Save to customSelections (JSON file - same as FruitSelection)
                            local success, err = pcall(function()
                                if _G.customSelections then
                                    _G.customSelections.stationFruitAssignments = stationAssignments or {}
                                end
                                
                                -- Trigger save
                                if _G.saveCustomSelections then
                                    _G.saveCustomSelections()
                                end
                                
                                -- Count stations (silent)
                                local count = 0
                                for _ in pairs(stationAssignments or {}) do
                                    count = count + 1
                                end
                            end)
                            
                            if not success then
                                warn("[AutoFeed] ❌ Failed to save: " .. tostring(err))
                            end
                        end,
                        function(isVisible)
                            feedFruitSelectionVisible = isVisible
                        end,
                        AutoFeedSystem.stationFruitAssignments
                    )
                    feedFruitSelectionVisible = true
                end
            else
                if StationFeedSetup then
                    StationFeedSetup.Hide()
                end
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
            
            if state and not autoFeedThread then
                autoFeedThread = task.spawn(function()
                    -- Get auto feed enabled status (dynamically checks current state)
                    local function getAutoFeedEnabled()
                        return autoFeedEnabled
                    end
                    
                    -- Get selected fruits function
                    local function getSelectedFruits()
                        return selectedFeedFruits
                    end
                    
                    -- Wrap in error handling
                    local ok, err = pcall(function()
                        AutoFeedSystem.runAutoFeed(getAutoFeedEnabled, nil, function() end, getSelectedFruits)
                    end)
                    
                    if not ok then
                        warn("Auto Feed thread error: " .. tostring(err))
            if WindUI then
                WindUI:Notify({
                                Title = "Auto Feed Error", 
                                Content = "Auto Feed stopped due to error: " .. tostring(err), 
                                Duration = 5 
                            })
                        end
                    end
                    
                    autoFeedThread = nil
                end)
                
                if WindUI then
                    WindUI:Notify({ Title = "Auto Feed", Content = "Started - Feeding Big Pets! 🎉", Duration = 3 })
                end
            elseif (not state) and autoFeedThread then
                if WindUI then
                    WindUI:Notify({ Title = "Auto Feed", Content = "Stopped", Duration = 3 })
                end
            end
        end
    })
    
    -- Register UI elements with config
    if AutoSystemsConfig and autoFeedToggle then
        pcall(function()
            AutoSystemsConfig:Register("autoFeedEnabled", autoFeedToggle)
        end)
    end
end

-- Get config elements for external registration
function AutoFeedSystem.GetConfigElements()
    return {
        AutoFeedToggle = autoFeedToggle
    }
end

-- Sync loaded values (called after config load)
function AutoFeedSystem.SyncLoadedValues()
    -- Load assignments from customSelections (JSON file)
    if _G.customSelections and _G.customSelections.stationFruitAssignments then
        pcall(function()
            local savedStationAssignments = _G.customSelections.stationFruitAssignments or {}
            
            -- Load station-fruit assignments (NEW STRUCTURE)
            AutoFeedSystem.stationFruitAssignments = savedStationAssignments
        end)
    end
end

return AutoFeedSystem
