-- AutoFeedSystem.lua - Auto Feed functionality for Build A Zoo
-- Author: Zebux
-- Version: 1.0

local AutoFeedSystem = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

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
}

local CANONICAL_FRUIT_BY_NORMALIZED = {}
for _, fruitName in ipairs(KNOWN_FRUITS) do
    CANONICAL_FRUIT_BY_NORMALIZED[normalizeFruitName(fruitName)] = fruitName
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
                        -- This is a Big Pet, add it to the list
                        table.insert(pets, {
                            model = petModel,
                            name = petModel.Name,
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
                print("🍎 Auto Feed Debug - Pet " .. petKey .. " stuck at 00:01 for " .. string.format("%.1f", stuckDuration) .. "s, Feed visible: " .. tostring(feedGUI.Visible))
                
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
        warn("Auto Feed: Invalid fruit name for equip: " .. tostring(fruitName))
        return false
    end
    
    local args = {
        "Focus",
        fruitName
    }
    local ok, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    if not ok then
        warn("Failed to equip fruit " .. tostring(fruitName) .. ": " .. tostring(err))
        return false
    end
    return true
end

function AutoFeedSystem.feedPet(petName)
    if not petName or type(petName) ~= "string" then
        warn("Auto Feed: Invalid pet name for feeding: " .. tostring(petName))
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

function AutoFeedSystem.runAutoFeed(autoFeedEnabled, feedFruitStatus, updateFeedStatusParagraph, getSelectedFruits)
    while autoFeedEnabled do
        local shouldContinue = true
        local ok, err = pcall(function()
            local bigPets = AutoFeedSystem.getBigPets()
            feedFruitStatus.petsFound = #bigPets
            feedFruitStatus.availablePets = 0
            
            if #bigPets == 0 then
                feedFruitStatus.lastAction = "No Big Pets found"
                if updateFeedStatusParagraph then
                    updateFeedStatusParagraph()
                end
                shouldContinue = false
                return
            end
            
            -- Check each pet for feeding opportunity
            for _, petData in ipairs(bigPets) do
                if not autoFeedEnabled then break end
                
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
                
                print("🍎 Auto Feed Debug - Pet " .. petData.name .. " feed time: '" .. tostring(feedTimeText) .. "' eating status: " .. tostring(isEating))
                
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
                        print("🍎 Auto Feed Debug - Current selections:", table.concat(fruitList, ", "))
                    else
                        print("🍎 Auto Feed Debug - No fruit selections found!")
                    end
                    
                    -- Check if we have selected fruits
                    if selectedFeedFruits and fruitCount > 0 then
                        -- Get player's fruit inventory
                        local fruitInventory = AutoFeedSystem.getPlayerFruitInventory()
                        
                        -- Try to feed with selected fruits
                        for fruitName, _ in pairs(selectedFeedFruits) do
                            if not autoFeedEnabled then break end
                            
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
        print("🍎 Auto Feed Debug: LocalPlayer not found")
        return
    end
    
    local petsFolder = workspace:FindFirstChild("Pets")
    if not petsFolder then
        print("🍎 Auto Feed Debug: Pets folder not found")
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
                                print("🍎 Auto Feed Debug - Pet " .. petModel.Name .. " feed time: '" .. tostring(feedTime) .. "' visible: " .. tostring(feedVisible))
                                
                                -- Check if ready using the same logic as isPetEating
                                local isReady = false
                                if not feedVisible then
                                    isReady = true
                                elseif feedTime == "00:00" or feedTime == "???" or feedTime == "" then
                                    isReady = true
                                end
                                
                                if isReady then
                                    availablePets = availablePets + 1
                                    print("🍎 Auto Feed Debug: Pet " .. petModel.Name .. " is ready to eat")
                                else
                                    print("🍎 Auto Feed Debug: Pet " .. petModel.Name .. " is eating (" .. feedTime .. ")")
                                end
                            else
                                print("🍎 Auto Feed Debug: Pet " .. petModel.Name .. " has no feed text")
                            end
                        else
                            print("🍎 Auto Feed Debug: Pet " .. petModel.Name .. " has no feed GUI")
                        end
                    else
                        print("🍎 Auto Feed Debug: Pet " .. petModel.Name .. " is not a Big Pet")
                    end
                end
            end
        end
    end
    
    print("🍎 Auto Feed Debug Summary:")
    print("  Total pets in workspace: " .. totalPets)
    print("  My pets: " .. myPets)
    print("  Big pets: " .. bigPets)
    print("  Available for feeding: " .. availablePets)
    
    -- Check fruit inventory
    local fruitInventory = AutoFeedSystem.getPlayerFruitInventory()
    local fruitCount = 0
    for fruitName, amount in pairs(fruitInventory) do
        if amount > 0 then
            fruitCount = fruitCount + 1
            print("🍎 Auto Feed Debug: Have " .. amount .. "x " .. fruitName)
        end
    end
    
    if fruitCount == 0 then
        print("🍎 Auto Feed Debug: No fruits in inventory")
    end
end

return AutoFeedSystem
