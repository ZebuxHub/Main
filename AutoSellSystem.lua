-- AutoSellSystem.lua - Auto Sell Pet functionality for Build A Zoo
-- Author: Zebux
-- Version: 1.0

local AutoSellSystem = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Get the local player
local function getLocalPlayer()
    return Players.LocalPlayer
end

-- Get all sellable pets (pets without "D" attribute)
function AutoSellSystem.getSellablePets()
    local localPlayer = getLocalPlayer()
    if not localPlayer then
        warn("Auto Sell Debug: LocalPlayer not found")
        return {}
    end

    local petsFolder = workspace:FindFirstChild("Pets")
    if not petsFolder then
        warn("Auto Sell Debug: Pets folder not found")
        return {}
    end

    local sellablePets = {}

    for _, petModel in ipairs(petsFolder:GetChildren()) do
        if petModel:IsA("Model") then
            local rootPart = petModel:FindFirstChild("RootPart")
            if rootPart then
                local petUserId = rootPart:GetAttribute("UserId")
                local petId = rootPart:GetAttribute("ID")

                -- Check if this pet belongs to the local player
                if petUserId == localPlayer.UserId and petId then
                    -- Check if pet has "D" attribute (not sellable if it has "D")
                    local hasD = rootPart:GetAttribute("D")
                    local hasM = rootPart:GetAttribute("M")

                    if not hasD then -- Only add if no "D" attribute
                        table.insert(sellablePets, {
                            model = petModel,
                            id = petId,
                            name = petModel.Name or "Unknown Pet",
                            hasMutation = hasM ~= nil,
                            rootPart = rootPart
                        })
                    else
                        print("🛒 Auto Sell Debug - Skipping pet " .. (petModel.Name or "Unknown") .. " (has D attribute)")
                    end
                end
            end
        end
    end

    return sellablePets
end

-- Check if a pet should be sold based on mutation setting
function AutoSellSystem.shouldSellPet(petData, sellMutations)
    if sellMutations == "Sell All" then
        return true
    elseif sellMutations == "No Mutations" then
        return not petData.hasMutation
    elseif sellMutations == "Only Mutations" then
        return petData.hasMutation
    end
    return false -- Default to not selling
end

-- Sell a single pet
function AutoSellSystem.sellPet(petId)
    if not petId then
        return false
    end

    local PetRE = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("PetRE")
    if not PetRE then
        warn("Auto Sell Debug: PetRE remote not found")
        return false
    end

    -- Fire the sell remote
    local args = {
        "Sell",
        petId
    }

    local success = pcall(function()
        PetRE:FireServer(unpack(args))
    end)

    if success then
        print("🛒 Auto Sell Debug - Successfully sold pet with ID: " .. petId)
        return true
    else
        warn("Auto Sell Debug - Failed to sell pet with ID: " .. petId)
        return false
    end
end

-- Main auto sell function
function AutoSellSystem.runAutoSell(autoSellEnabled, sellMutations, updateSellStatus)
    while autoSellEnabled do
        local shouldContinue = true
        local ok, err = pcall(function()
            local sellablePets = AutoSellSystem.getSellablePets()

            if updateSellStatus then
                updateSellStatus("sellablePets", #sellablePets)
            end

            if #sellablePets == 0 then
                print("🛒 Auto Sell Debug - No sellable pets found")
                if updateSellStatus then
                    updateSellStatus("lastAction", "No sellable pets found")
                end
                shouldContinue = false
                return
            end

            local petsSold = 0
            local soldPetNames = {}

            print("🛒 Auto Sell Debug - Found " .. #sellablePets .. " sellable pets")

            for _, petData in ipairs(sellablePets) do
                if not autoSellEnabled then break end

                -- Check if we should sell this pet based on mutation setting
                if AutoSellSystem.shouldSellPet(petData, sellMutations) then
                    if updateSellStatus then
                        updateSellStatus("lastAction", "Selling " .. petData.name)
                    end

                    -- Attempt to sell the pet with retry
                    local sellSuccess = false
                    for retry = 1, 3 do
                        if AutoSellSystem.sellPet(petData.id) then
                            sellSuccess = true
                            break
                        else
                            task.wait(0.2) -- Wait before retry
                        end
                    end

                    if sellSuccess then
                        petsSold = petsSold + 1
                        table.insert(soldPetNames, petData.name)
                        print("🛒 Auto Sell Debug - Successfully sold " .. petData.name)

                        -- Small delay between sells
                        task.wait(0.3)
                    else
                        warn("Auto Sell Debug - Failed to sell " .. petData.name .. " after 3 attempts")
                        if updateSellStatus then
                            updateSellStatus("lastAction", "Failed to sell " .. petData.name)
                        end
                    end
                else
                    local skipReason = petData.hasMutation and "has mutation (skipped)" or "no mutation (skipped)"
                    print("🛒 Auto Sell Debug - Skipping " .. petData.name .. " (" .. skipReason .. ")")
                end
            end

            -- Update final status
            if petsSold > 0 then
                local petNamesText = table.concat(soldPetNames, ", ")
                print("🛒 Auto Sell Debug - Cycle complete: Sold " .. petsSold .. " pets: " .. petNamesText)
                if updateSellStatus then
                    updateSellStatus("lastAction", "Sold " .. petsSold .. " pets: " .. petNamesText)
                    updateSellStatus("totalSold", (updateSellStatus("totalSold") or 0) + petsSold)
                end
            else
                print("🛒 Auto Sell Debug - No pets were sold this cycle")
                if updateSellStatus then
                    updateSellStatus("lastAction", "No pets sold (check settings)")
                end
            end
        end)

        if not ok then
            warn("Auto Sell error: " .. tostring(err))
            if updateSellStatus then
                updateSellStatus("lastAction", "Error: " .. tostring(err))
            end
            task.wait(1) -- Wait before retrying
        elseif not shouldContinue then
            -- No sellable pets found, wait longer before checking again
            task.wait(5)
        else
            -- Normal operation, wait before next cycle
            task.wait(3)
        end
    end
end

-- Debug function to help troubleshoot auto sell issues
function AutoSellSystem.debugAutoSell()
    local localPlayer = getLocalPlayer()
    if not localPlayer then
        print("🛒 Auto Sell Debug: LocalPlayer not found")
        return
    end

    local petsFolder = workspace:FindFirstChild("Pets")
    if not petsFolder then
        print("🛒 Auto Sell Debug: Pets folder not found")
        return
    end

    local totalPets = 0
    local myPets = 0
    local sellablePets = 0
    local petsWithD = 0
    local petsWithM = 0

    for _, petModel in ipairs(petsFolder:GetChildren()) do
        if petModel:IsA("Model") then
            totalPets = totalPets + 1
            local rootPart = petModel:FindFirstChild("RootPart")
            if rootPart then
                local petUserId = rootPart:GetAttribute("UserId")
                local petId = rootPart:GetAttribute("ID")
                local hasD = rootPart:GetAttribute("D")
                local hasM = rootPart:GetAttribute("M")

                if petUserId == localPlayer.UserId then
                    myPets = myPets + 1
                    print(string.format("🛒 My Pet: %s (ID: %s, D: %s, M: %s)",
                        petModel.Name or "Unknown",
                        petId or "No ID",
                        tostring(hasD),
                        tostring(hasM)
                    ))

                    if hasD then
                        petsWithD = petsWithD + 1
                    else
                        sellablePets = sellablePets + 1
                    end

                    if hasM then
                        petsWithM = petsWithM + 1
                    end
                end
            end
        end
    end

    print("🛒 Auto Sell Debug Summary:")
    print("  Total Pets: " .. totalPets)
    print("  My Pets: " .. myPets)
    print("  Sellable Pets: " .. sellablePets)
    print("  Pets with D (unsellable): " .. petsWithD)
    print("  Pets with M (mutations): " .. petsWithM)
end

return AutoSellSystem
