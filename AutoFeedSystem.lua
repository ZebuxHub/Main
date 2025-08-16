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
    
    -- Check BigPet parts in workspace.Art.Island_1.ENV.BigPet
    local bigPetFolder = workspace:FindFirstChild("Art")
    if bigPetFolder then
        local island1 = bigPetFolder:FindFirstChild("Island_1")
        if island1 then
            local env = island1:FindFirstChild("ENV")
            if env then
                local bigPet = env:FindFirstChild("BigPet")
                if bigPet then
                    -- Check both BigPet parts
                    for i = 1, 2 do
                        local bigPetPart = bigPet:FindFirstChild(tostring(i))
                        if bigPetPart then
                            -- Check if this BigPet part is active
                            local active = bigPetPart:GetAttribute("Active")
                            if active and active == 1 then
                                -- Get the GridCenterPos attribute
                                local gridCenterPos = bigPetPart:GetAttribute("GridCenterPos")
                                print("🔍 BigPet", i, "GridCenterPos:", gridCenterPos)
                                if gridCenterPos then
                                    -- Look for pets in the area around this position
                                    local petsFolder = workspace:FindFirstChild("Pets")
                                    print("🔍 Pets folder found:", petsFolder and "Yes" or "No")
                                    if petsFolder then
                                        print("🔍 Total pets in folder:", #petsFolder:GetChildren())
                                        local petsInThisArea = 0 -- Count pets found in this BigPet area
                                        
                                        for _, petModel in ipairs(petsFolder:GetChildren()) do
                                            if petModel:IsA("Model") then
                                                local rootPart = petModel:FindFirstChild("RootPart")
                                                if rootPart then
                                                    -- Check if it's our pet by looking for UserId attribute
                                                    local petUserId = rootPart:GetAttribute("UserId")
                                                    print("🔍 Pet", petModel.Name, "UserId:", petUserId, "Our UserId:", localPlayer.UserId)
                                                    if petUserId and tostring(petUserId) == tostring(localPlayer.UserId) then
                                                        -- Check if pet is near the BigPet area using WorldPivot
                                                        local petWorldPivot = petModel:GetPivot()
                                                        local distance = (petWorldPivot.Position - gridCenterPos).Magnitude
                                                        print("🔍 Pet", petModel.Name, "Distance:", distance, "WorldPivot:", petWorldPivot.Position, "GridCenter:", gridCenterPos)
                                                        
                                                        -- If pet is within 20 studs of BigPet area, consider it a Big Pet
                                                        if distance < 20 then -- 20 studs radius
                                                            -- No additional verification needed - if it's in the area, it's a Big Pet
                                                            local bigPetGUI = rootPart:FindFirstChild("GUI/BigPetGUI")
                                                            table.insert(pets, {
                                                                model = petModel,
                                                                name = petModel.Name,
                                                                rootPart = rootPart,
                                                                bigPetGUI = bigPetGUI,
                                                                bigPetPart = bigPetPart.Name
                                                            })
                                                            petsInThisArea = petsInThisArea + 1
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                        
                                        -- If no pets found in this BigPet area, skip it (already handled by not adding to pets table)
                                    end
                                end
                            end
                        end
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
    return feedTime ~= "00:00"
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

function AutoFeedSystem.runAutoFeed(autoFeedEnabled, selectedFeedFruits, feedFruitStatus, updateFeedStatusParagraph)
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
                
                -- Check if we have selected fruits
                if selectedFeedFruits and next(selectedFeedFruits) then
                    -- Try to feed with selected fruits
                    for fruitName, _ in pairs(selectedFeedFruits) do
                        if not autoFeedEnabled then break end
                        
                                                 -- Update status to show which pet we're trying to feed
                         local bigPetInfo = petData.bigPetPart and " (BigPet " .. petData.bigPetPart .. ")" or ""
                         feedFruitStatus.lastAction = "Trying to feed " .. petData.name .. bigPetInfo .. " with " .. fruitName
                         updateFeedStatusParagraph()
                        
                        -- Equip the fruit first
                        if AutoFeedSystem.equipFruit(fruitName) then
                            task.wait(0.1) -- Small delay between equip and feed
                            
                            -- Feed the pet
                            if AutoFeedSystem.feedPet(petData.name) then
                                feedFruitStatus.lastFedPet = petData.name
                                feedFruitStatus.totalFeeds = feedFruitStatus.totalFeeds + 1
                                                                 local bigPetInfo = petData.bigPetPart and " (BigPet " .. petData.bigPetPart .. ")" or ""
                                 feedFruitStatus.lastAction = "✅ Fed " .. petData.name .. bigPetInfo .. " with " .. fruitName
                                updateFeedStatusParagraph()
                                
                                task.wait(1) -- Wait before trying next pet
                                break -- Move to next pet
                            else
                                                                 local bigPetInfo = petData.bigPetPart and " (BigPet " .. petData.bigPetPart .. ")" or ""
                                 feedFruitStatus.lastAction = "❌ Failed to feed " .. petData.name .. bigPetInfo .. " with " .. fruitName
                                updateFeedStatusParagraph()
                            end
                        else
                                                         local bigPetInfo = petData.bigPetPart and " (BigPet " .. petData.bigPetPart .. ")" or ""
                             feedFruitStatus.lastAction = "❌ Failed to equip " .. fruitName .. " for " .. petData.name .. bigPetInfo
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
                 local bigPetInfo = petData.bigPetPart and " (BigPet " .. petData.bigPetPart .. ")" or ""
                 feedFruitStatus.lastAction = petData.name .. bigPetInfo .. " is currently eating"
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
