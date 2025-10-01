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
local FeedFruitSelection = nil

-- UI Elements
local autoFeedToggle = nil
local bigPetDropdown = nil

-- State variables
local autoFeedEnabled = false
local autoFeedThread = nil
local selectedBigPets = {}
local selectedFeedFruits = {}
local feedFruitSelectionVisible = false

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
    -- Newly supported fruits (ensure inventory recognition + equip)
    "Pineapple",
    "GoldMango",
    "BloodstoneCycad",
    "ColossalPinecone",
    "VoltGinkgo",
    "DeepseaPearlFruit",
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
    
    -- Go through all pet models in workspace.Pets
    local petsFolder = workspace:FindFirstChild("Pets")
    if not petsFolder then
        warn("Auto Feed: Pets folder not found")
        return pets
    end
    
    for _, petModel in ipairs(petsFolder:GetChildren()) do
        if petModel:IsA("Model") then
            local rootPart = petModel:FindFirstChild("RootPart")
            if rootPart then
                -- Check if it's our pet by looking for UserId attribute
                local petUserId = rootPart:GetAttribute("UserId")
                if petUserId and tostring(petUserId) == tostring(localPlayer.UserId) then
                    -- Check if this pet has BigPetGUI
                    local bigPetGUI = rootPart:FindFirstChild("GUI/BigPetGUI")
                    if bigPetGUI then
                        -- Find which station this pet is at
                        local stationId = findBigPetStationForPet(rootPart.Position)
                        
                            -- This is a Big Pet, add it to the list
                            table.insert(pets, {
                                model = petModel,
                                name = petModel.Name,
                            stationId = stationId, -- The BigPet Part name like "1", "2", "3"
                                rootPart = rootPart,
                                bigPetGUI = bigPetGUI
                            })
                    end
                end
            end
        end
    end
    
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
    if not petData or not petData.bigPetGUI then
        return true -- Assume eating if we can't check
    end
    
    local feedGUI = petData.bigPetGUI:FindFirstChild("Feed")
    if not feedGUI then
        return true -- Assume eating if no feed GUI
    end
    
    -- Check if Feed frame is visible - if not visible, pet is ready to feed
    if not feedGUI.Visible then
        return false -- Pet is ready to feed
    end
    
    local feedText = feedGUI:FindFirstChild("TXT")
    if not feedText or not feedText:IsA("TextLabel") then
        return true -- Assume eating if no text
    end
    
    local feedTime = feedText.Text
    if not feedTime or type(feedTime) ~= "string" then
        return true -- Assume eating if no valid text
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
                -- Been stuck for more than 2 seconds, check if Feed frame is visible
                
                if not feedGUI.Visible then
                    -- Feed frame not visible, pet is ready to feed
                    AutoFeedSystem.stuckTimers[petKey] = nil -- Reset timer
                    return false
                end
            end
            return true -- Still eating
        end
    else
        -- Timer is not 00:01, reset stuck timer
        AutoFeedSystem.stuckTimers[petKey] = nil
        
        -- Check if the pet is currently eating (not ready to eat)
        -- Return true if eating, false if ready to eat
        -- Pet is ready to eat when text is "00:00", "???", or ""
        return feedTime ~= "00:00" and feedTime ~= "???" and feedTime ~= ""
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
            local allBigPets = AutoFeedSystem.getBigPets()
            
            -- Get current selection dynamically
            local selectedBigPets = getSelectedBigPets and getSelectedBigPets() or {}
            
            -- Filter pets based on selection
            local bigPets = {}
            if selectedBigPets and next(selectedBigPets) then
                -- Only feed selected pets
                for _, petData in ipairs(allBigPets) do
                    if petData.stationId then
                        -- Check if this pet's station is selected
                        -- selectedBigPets keys are like "1", "2", "3" or "1 (Dragon)"
                        local isSelected = false
                        
                        for selectedName, _ in pairs(selectedBigPets) do
                            -- Match exact station ID or station ID with type info
                            -- e.g., "1" matches "1" or "1 (Dragon)"
                            if selectedName == petData.stationId or selectedName:match("^" .. petData.stationId .. "%s") then
                                isSelected = true
                                break
                            end
                        end
                        
                        if isSelected then
                            table.insert(bigPets, petData)
                        end
                    end
                end
            else
                -- No selection = feed all pets
                bigPets = allBigPets
            end
            
            feedFruitStatus.petsFound = #bigPets
            feedFruitStatus.availablePets = 0
            
            -- Log which stations are being fed
            if selectedBigPets and next(selectedBigPets) then
                local stationList = {}
                for _, petData in ipairs(bigPets) do
                    if petData.stationId then
                        table.insert(stationList, petData.stationId)
                    end
                end
                if #stationList > 0 then
                    print("[Auto Feed] Feeding stations: " .. table.concat(stationList, ", "))
                end
            end
            
            if #bigPets == 0 then
                if selectedBigPets and next(selectedBigPets) then
                    feedFruitStatus.lastAction = "No selected Big Pets found"
                else
                feedFruitStatus.lastAction = "No Big Pets found"
                end
                if updateFeedStatusParagraph then
                    updateFeedStatusParagraph()
                end
                shouldContinue = false
                return
            end
            
            -- Check each pet for feeding opportunity
            for _, petData in ipairs(bigPets) do
                if not getAutoFeedEnabled() then break end
                
                local isEating = AutoFeedSystem.isPetEating(petData)
                
                -- Get the actual feed time text for debugging
                local feedTimeText = "unknown"
                if petData.bigPetGUI then
                    local feedGUI = petData.bigPetGUI:FindFirstChild("Feed")
                    if feedGUI then
                        local feedText = feedGUI:FindFirstChild("TXT")
                        if feedText and feedText:IsA("TextLabel") then
                            feedTimeText = feedText.Text
                        end
                    end
                end
                
                
                if not isEating then
                    feedFruitStatus.availablePets = feedFruitStatus.availablePets + 1
                    
                    -- Get current selected fruits from main script
                    local selectedFeedFruits = getSelectedFruits and getSelectedFruits() or {}
                    
                    -- Debug: Check if selections are being lost
                    local fruitCount = 0
                    local fruitList = {}
                    if selectedFeedFruits then
                        for fruitName, _ in pairs(selectedFeedFruits) do
                            fruitCount = fruitCount + 1
                            table.insert(fruitList, fruitName)
                        end
                    end
                    
                    -- Log current selections for debugging
                    if fruitCount > 0 then
                    else
                    end
                    
                    -- Check if we have selected fruits
                    if selectedFeedFruits and fruitCount > 0 then
                        -- Get player's fruit inventory
                        local fruitInventory = AutoFeedSystem.getPlayerFruitInventory()
                        
                        -- Try to feed with selected fruits
                        for fruitName, _ in pairs(selectedFeedFruits) do
                            if not getAutoFeedEnabled() then break end
                            
                            -- Check if player has this fruit
                            local fruitAmount = fruitInventory[fruitName] or 0
                            if fruitAmount <= 0 then
                                feedFruitStatus.lastAction = "❌ No " .. fruitName .. " in inventory"
                                if updateFeedStatusParagraph then
                                    updateFeedStatusParagraph()
                                end
                                task.wait(0.5)
                            else
                                -- Update status to show which pet we're trying to feed
                                feedFruitStatus.lastAction = "Trying to feed " .. petData.name .. " with " .. fruitName .. " (" .. fruitAmount .. " left)"
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
                                    task.wait(0.2) -- Small delay between equip and feed
                                    
                                    -- Feed the pet - with retry
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
                                        feedFruitStatus.lastFedPet = petData.name
                                        feedFruitStatus.totalFeeds = feedFruitStatus.totalFeeds + 1
                                        feedFruitStatus.lastAction = "✅ Fed " .. petData.name .. " with " .. fruitName
                                        if updateFeedStatusParagraph then
                                            updateFeedStatusParagraph()
                                        end
                                        
                                        task.wait(1.5) -- Wait longer before trying next pet
                                        break -- Move to next pet
                                    else
                                        feedFruitStatus.lastAction = "❌ Failed to feed " .. petData.name .. " with " .. fruitName .. " after 3 attempts"
                                        if updateFeedStatusParagraph then
                                            updateFeedStatusParagraph()
                                        end
                                    end
                                else
                                    feedFruitStatus.lastAction = "❌ Failed to equip " .. fruitName .. " for " .. petData.name .. " after 3 attempts"
                                    if updateFeedStatusParagraph then
                                        updateFeedStatusParagraph()
                                    end
                                end
                                
                                task.wait(0.3) -- Small delay between fruit attempts
                            end
                        end
                    else
                        feedFruitStatus.lastAction = "No fruits selected for feeding"
                        if updateFeedStatusParagraph then
                            updateFeedStatusParagraph()
                        end
                    end
                else
                    -- Show which pets are currently eating
                    feedFruitStatus.lastAction = petData.name .. " is currently eating"
                    if updateFeedStatusParagraph then
                        updateFeedStatusParagraph()
                    end
                end
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

-- Helper function to get island name
local function getAssignedIslandName()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return nil end
    return localPlayer:GetAttribute("AssignedIslandName")
end

-- Helper function to get available Big pets from current island
local function getAvailableBigPets()
    local bigPets = {}
    
    local islandName = getAssignedIslandName()
    if not islandName then return bigPets end
    
    local art = workspace:FindFirstChild("Art")
    if not art then return bigPets end
    
    local island = art:FindFirstChild(islandName)
    if not island then return bigPets end
    
    local env = island:FindFirstChild("ENV")
    if not env then return bigPets end
    
    local bigPetFolder = env:FindFirstChild("BigPet")
    if not bigPetFolder then return bigPets end
    
    -- Get only Parts from BigPet folder
    for _, child in ipairs(bigPetFolder:GetChildren()) do
        if child:IsA("BasePart") then
            local displayName = child.Name
            
            -- Try to get a better name from attributes
            local petType = child:GetAttribute("Type") 
                or child:GetAttribute("T") 
                or child:GetAttribute("PetType")
            
            if petType and tostring(petType) ~= "" then
                displayName = displayName .. " (" .. tostring(petType) .. ")"
            end
            
            if not table.find(bigPets, displayName) then
                table.insert(bigPets, displayName)
            end
        end
    end
    
    -- Sort numerically if names are numbers
    table.sort(bigPets, function(a, b)
        local numA = tonumber(a:match("^(%d+)"))
        local numB = tonumber(b:match("^(%d+)"))
        if numA and numB then
            return numA < numB
        end
        return a < b
    end)
    
    return bigPets
end

-- Callback to update custom UI selections
local function updateCustomUISelection(uiType, selections)
    -- This will be called to save selections
    if not CustomUIConfig then return end
    
    -- Convert selections to array format for saving
    local selectionsArray = {}
    for key, _ in pairs(selections) do
        table.insert(selectionsArray, key)
    end
    
    -- Save using CustomUIConfig
    pcall(function()
        if uiType == "bigPetSelections" then
            CustomUIConfig:Set("bigPetSelections", selectionsArray)
            CustomUIConfig:Save()
        elseif uiType == "feedFruitSelections" then
            CustomUIConfig:Set("feedFruitSelections", selectionsArray)
            CustomUIConfig:Save()
        end
    end)
end

-- Initialize the Auto Feed System
function AutoFeedSystem.Init(windUIRef, tabsRef, autoSystemsConfigRef, customUIConfigRef, feedFruitSelectionRef)
    WindUI = windUIRef
    Tabs = tabsRef
    AutoSystemsConfig = autoSystemsConfigRef
    CustomUIConfig = customUIConfigRef
    FeedFruitSelection = feedFruitSelectionRef
    
    -- Load saved selections from CustomUIConfig
    if CustomUIConfig then
        pcall(function()
            local savedBigPets = CustomUIConfig:Get("bigPetSelections") or {}
            local savedFeedFruits = CustomUIConfig:Get("feedFruitSelections") or {}
            
            -- Convert array to set
            selectedBigPets = {}
            for _, petName in ipairs(savedBigPets) do
                selectedBigPets[petName] = true
            end
            
            selectedFeedFruits = {}
            for _, fruitId in ipairs(savedFeedFruits) do
                selectedFeedFruits[fruitId] = true
            end
        end)
    end
end

-- Create UI function
function AutoFeedSystem.CreateUI()
    if not Tabs or not Tabs.ShopTab then
        warn("[AutoFeedSystem] Tabs.ShopTab not available")
        return
    end
    
    -- Section header
    Tabs.ShopTab:Section({ Title = "Auto Feed", Icon = "coffee" })
    
    -- Feed Fruit Selection UI Button
    Tabs.ShopTab:Button({
        Title = "Open Feed Fruit Selection UI",
        Desc = "Select fruits to feed pets",
        Callback = function()
            if not feedFruitSelectionVisible then
                if FeedFruitSelection then
                    FeedFruitSelection.Show(
                        function(selectedItems)
                            selectedFeedFruits = selectedItems
                            updateCustomUISelection("feedFruitSelections", selectedItems)
                        end,
                        function(isVisible)
                            feedFruitSelectionVisible = isVisible
                        end,
                        selectedFeedFruits
                    )
                    feedFruitSelectionVisible = true
                end
            else
                if FeedFruitSelection then
                    FeedFruitSelection.Hide()
                end
                feedFruitSelectionVisible = false
            end
        end
    })
    
    -- Big Pet Selection Dropdown
    bigPetDropdown = Tabs.ShopTab:Dropdown({
        Title = "Select Big Pets to Feed",
        Desc = "Choose which Big pets should be fed (empty = feed all)",
        Values = getAvailableBigPets(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            -- Convert array to set
            selectedBigPets = {}
            for _, petName in ipairs(selection) do
                selectedBigPets[petName] = true
            end
            
            -- Save selection
            updateCustomUISelection("bigPetSelections", selectedBigPets)
            
            -- Log selection change (removed notification to reduce spam)
            if #selection == 0 then
                print("[AutoFeed] Big Pet selection updated: Feeding ALL Big Pets")
            else
                print("[AutoFeed] Big Pet selection updated:", table.concat(selection, ", "))
            end
        end
    })
    
    -- Refresh Big Pet list button
    Tabs.ShopTab:Button({
        Title = "🔄 Refresh Big Pet List",
        Desc = "Update the list of available Big pets",
        Callback = function()
            local availablePets = getAvailableBigPets()
            if bigPetDropdown and bigPetDropdown.Refresh then
                bigPetDropdown:Refresh(availablePets)
                if WindUI then
                    WindUI:Notify({ 
                        Title = "Big Pets Refreshed", 
                        Content = "Found " .. #availablePets .. " Big pets", 
                        Duration = 2 
                    })
                end
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
                    
                    -- Get selected Big Pets function (dynamically reads current selection)
                    local function getSelectedBigPets()
                        return selectedBigPets
                    end
                    
                    -- Get selected fruits function
                    local function getSelectedFruits()
                        return selectedFeedFruits
                    end
                    
                    -- Wrap in error handling
                    local ok, err = pcall(function()
                        AutoFeedSystem.runAutoFeed(getAutoFeedEnabled, getSelectedBigPets, function() end, getSelectedFruits)
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
    
    if CustomUIConfig and bigPetDropdown then
        pcall(function()
            CustomUIConfig:Register("bigPetDropdown", bigPetDropdown)
        end)
    end
end

-- Get config elements for external registration
function AutoFeedSystem.GetConfigElements()
    return {
        AutoFeedToggle = autoFeedToggle,
        BigPetDropdown = bigPetDropdown
    }
end

-- Sync loaded values (called after config load)
function AutoFeedSystem.SyncLoadedValues()
    -- Load selections from CustomUIConfig if available
    if CustomUIConfig then
        pcall(function()
            local savedBigPets = CustomUIConfig:Get("bigPetSelections") or {}
            local savedFeedFruits = CustomUIConfig:Get("feedFruitSelections") or {}
            
            -- Convert array to set
            selectedBigPets = {}
            for _, petName in ipairs(savedBigPets) do
                selectedBigPets[petName] = true
            end
            
            selectedFeedFruits = {}
            for _, fruitId in ipairs(savedFeedFruits) do
                selectedFeedFruits[fruitId] = true
            end
            
            print("[AutoFeed] Synced Big Pets:", #savedBigPets, "Synced Fruits:", #savedFeedFruits)
        end)
    end
end

return AutoFeedSystem
