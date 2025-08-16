-- AutoFeedSystem.lua - Auto Feed functionality for Build A Zoo
-- Author: Zebux
-- Version: 1.0

local AutoFeedSystem = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
                
                -- Check if we have selected fruits
                if selectedFeedFruits and next(selectedFeedFruits) then
                    -- Try to feed with selected fruits
                    for fruitName, _ in pairs(selectedFeedFruits) do
                        if not autoFeedEnabled then break end
                        
                                                 -- Update status to show which pet we're trying to feed
                         feedFruitStatus.lastAction = "Trying to feed " .. petData.name .. " with " .. fruitName
                         updateFeedStatusParagraph()
                        
                        -- Equip the fruit first
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
