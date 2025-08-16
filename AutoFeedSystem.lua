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
        return pets
    end
    
    -- Go through all pet models in workspace.Pets
    local petsFolder = workspace:FindFirstChild("Pets")
    if not petsFolder then
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
    
    local feedText = feedGUI:FindFirstChild("TXT")
    if not feedText or not feedText:IsA("TextLabel") then
        return true -- Assume eating if no text
    end
    
    local feedTime = feedText.Text
    return feedTime ~= "00:00" and feedTime ~= "???"
end

function AutoFeedSystem.equipFruit(fruitName)
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
        local bigPets = AutoFeedSystem.getBigPets()
        feedFruitStatus.petsFound = #bigPets
        feedFruitStatus.availablePets = 0
        
        if #bigPets == 0 then
            feedFruitStatus.lastAction = "No Big Pets found"
            updateFeedStatusParagraph()
            task.wait(2)
            continue
        end
        
        -- Check each pet for feeding opportunity
        for _, petData in ipairs(bigPets) do
            if not autoFeedEnabled then break end
            
            if not AutoFeedSystem.isPetEating(petData) then
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
                            updateFeedStatusParagraph()
                            task.wait(0.5)
                        else
                            -- Update status to show which pet we're trying to feed
                            feedFruitStatus.lastAction = "Trying to feed " .. petData.name .. " with " .. fruitName .. " (" .. fruitAmount .. " left)"
                            updateFeedStatusParagraph()
                            
                            -- Always equip the fruit before feeding (every time)
                            if AutoFeedSystem.equipFruit(fruitName) then
                                task.wait(0.1) -- Small delay between equip and feed
                                
                                -- Feed the pet
                                if AutoFeedSystem.feedPet(petData.name) then
                                    feedFruitStatus.lastFedPet = petData.name
                                    feedFruitStatus.totalFeeds = feedFruitStatus.totalFeeds + 1
                                    feedFruitStatus.lastAction = "✅ Fed " .. petData.name .. " with " .. fruitName
                                    updateFeedStatusParagraph()
                                    
                                    task.wait(1) -- Wait before trying next pet
                                    break -- Move to next pet
                                else
                                    feedFruitStatus.lastAction = "❌ Failed to feed " .. petData.name .. " with " .. fruitName
                                    updateFeedStatusParagraph()
                                end
                            else
                                feedFruitStatus.lastAction = "❌ Failed to equip " .. fruitName .. " for " .. petData.name
                                updateFeedStatusParagraph()
                            end
                            
                            task.wait(0.2) -- Small delay between fruit attempts
                        end
                    end
                else
                    feedFruitStatus.lastAction = "No fruits selected for feeding"
                    updateFeedStatusParagraph()
                end
            else
                                 -- Show which pets are currently eating
                 feedFruitStatus.lastAction = petData.name .. " is currently eating"
                updateFeedStatusParagraph()
            end
        end
        
        if feedFruitStatus.availablePets == 0 then
            feedFruitStatus.lastAction = "All pets are currently eating"
            updateFeedStatusParagraph()
        end
        
        task.wait(2) -- Check every 2 seconds
    end
end

return AutoFeedSystem
