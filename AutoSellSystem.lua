-- Auto Sell System for Build a Zoo
-- Created by Zebux
-- Handles automatic selling of pets based on user preferences

local AutoSellSystem = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Constants
local PET_REMOTE_PATH = "Remote.PetRE"

-- Helper function to get the PetRE remote
local function getPetRemote()
    local remote = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("PetRE")
    return remote
end

-- Helper function to check if a pet has D attribute from PlayerGui
local function checkPetDAttributeFromGui(petName)
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return false end

    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return false end

    local dataGui = playerGui:FindFirstChild("Data")
    if not dataGui then return false end

    local petsData = dataGui:FindFirstChild("Pets")
    if not petsData then return false end

    local petDataInGui = petsData:FindFirstChild(petName)
    if not petDataInGui then return false end

    return petDataInGui:GetAttribute("D") or false
end

-- Function to get all pets that are available for selling
function AutoSellSystem.getSellablePets()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then
        print("🛒 Auto Sell Debug: LocalPlayer not found")
        return {}
    end

    local petsFolder = workspace:FindFirstChild("Pets")
    if not petsFolder then
        print("🛒 Auto Sell Debug: Pets folder not found")
        return {}
    end

    local sellablePets = {}
    local totalPets = 0
    local unsellablePets = 0

    for _, petModel in ipairs(petsFolder:GetChildren()) do
        if petModel:IsA("Model") then
            totalPets = totalPets + 1

            local rootPart = petModel:FindFirstChild("RootPart")
            if rootPart then
                local petUserId = rootPart:GetAttribute("UserId")

                -- Only process player's own pets
                if petUserId == localPlayer.UserId then
                    local petName = petModel.Name
                    local hasDAttributeWorkspace = rootPart:GetAttribute("D") -- D = unsellable flag from workspace
                    local hasDAttributeGui = checkPetDAttributeFromGui(petName) -- D = unsellable flag from PlayerGui
                    local hasMAttribute = rootPart:GetAttribute("M") -- M = mutation flag

                    -- Check both workspace and PlayerGui for D attribute
                    local isUnsellable = hasDAttributeWorkspace or hasDAttributeGui

                    if not isUnsellable then
                        -- Pet is sellable
                        table.insert(sellablePets, {
                            name = petName,
                            model = petModel,
                            rootPart = rootPart,
                            hasMutation = hasMAttribute or false
                        })
                        print(string.format("🛒 Auto Sell Debug: Pet %s is sellable (D_workspace:%s D_gui:%s)",
                            petName,
                            hasDAttributeWorkspace and "YES" or "NO",
                            hasDAttributeGui and "YES" or "NO"))
                    else
                        unsellablePets = unsellablePets + 1
                        print(string.format("🛒 Auto Sell Debug: Pet %s is unsellable (D_workspace:%s D_gui:%s)",
                            petName,
                            hasDAttributeWorkspace and "YES" or "NO",
                            hasDAttributeGui and "YES" or "NO"))
                    end
                end
            end
        end
    end

    print(string.format("🛒 Auto Sell Debug: Found %d total pets, %d sellable, %d unsellable",
        totalPets, #sellablePets, unsellablePets))

    return sellablePets
end

-- Function to filter pets based on mutation mode
function AutoSellSystem.filterPetsByMutation(sellablePets, mutationMode)
    if mutationMode == "Sell All" then
        return sellablePets -- Sell all sellable pets
    elseif mutationMode == "No Mutations" then
        -- Only sell pets without mutations AND double-check D attribute from PlayerGui
        local filtered = {}
        for _, pet in ipairs(sellablePets) do
            if not pet.hasMutation then
                -- Additional check for D attribute from PlayerGui for "No Mutations" mode
                local hasDAttributeGui = checkPetDAttributeFromGui(pet.name)
                if not hasDAttributeGui then
                    table.insert(filtered, pet)
                    print(string.format("🛒 Auto Sell Debug: ✅ Pet %s passed No Mutations filter (no M, no D_gui)", pet.name))
                else
                    print(string.format("🛒 Auto Sell Debug: ❌ Pet %s failed No Mutations filter (has D_gui despite no M)", pet.name))
                end
            end
        end
        return filtered
    elseif mutationMode == "Only Mutations" then
        -- Only sell pets with mutations
        local filtered = {}
        for _, pet in ipairs(sellablePets) do
            if pet.hasMutation then
                table.insert(filtered, pet)
            end
        end
        return filtered
    end

    return sellablePets -- Default to sell all
end

-- Function to sell a single pet
function AutoSellSystem.sellPet(petName)
    if not petName then
        print("🛒 Auto Sell Debug: No pet name provided for selling")
        return false
    end

    local ok, err = pcall(function()
        local remote = getPetRemote()
        local args = {
            "Sell",
            petName
        }
        remote:FireServer(unpack(args))
        print(string.format("🛒 Auto Sell Debug: Fired sell remote for pet %s", petName))
    end)

    if not ok then
        warn("Auto Sell error selling pet " .. petName .. ": " .. tostring(err))
        return false
    end

    return true
end

-- Main auto sell function
function AutoSellSystem.runAutoSell(autoSellEnabled, mutationMode, updateSellStatus)
    while autoSellEnabled do
        local shouldContinue = true
        local ok, err = pcall(function()
            -- Get all sellable pets
            local sellablePets = AutoSellSystem.getSellablePets()

            if updateSellStatus then
                updateSellStatus("sellablePets", #sellablePets)
            end

            if #sellablePets == 0 then
                if updateSellStatus then
                    updateSellStatus("lastAction", "No sellable pets found")
                end
                shouldContinue = false
                return
            end

            -- Filter pets based on mutation mode
            local targetPets = AutoSellSystem.filterPetsByMutation(sellablePets, mutationMode)

            print(string.format("🛒 Auto Sell Debug: Mutation mode '%s' - %d pets to sell out of %d sellable",
                mutationMode, #targetPets, #sellablePets))

            -- Special logging for No Mutations mode
            if mutationMode == "No Mutations" then
                print("🛒 Auto Sell Debug: No Mutations mode - Double-checking D attributes from PlayerGui")
            end

            if #targetPets == 0 then
                if updateSellStatus then
                    updateSellStatus("lastAction", string.format("No pets match mutation criteria (%s)", mutationMode))
                end
                shouldContinue = false
                return
            end

            -- Sell pets one by one with delays
            local soldCount = 0
            for _, petData in ipairs(targetPets) do
                if not autoSellEnabled then break end

                if updateSellStatus then
                    updateSellStatus("lastAction", string.format("Selling %s...", petData.name))
                end

                -- Attempt to sell the pet
                local success = AutoSellSystem.sellPet(petData.name)

                if success then
                    soldCount = soldCount + 1
                    if updateSellStatus then
                        updateSellStatus("totalSold", (updateSellStatus("totalSold") or 0) + 1)
                        updateSellStatus("lastAction", string.format("✅ Sold %s", petData.name))
                    end
                    print(string.format("🛒 Auto Sell Debug: Successfully sold pet %s", petData.name))
                else
                    if updateSellStatus then
                        updateSellStatus("lastAction", string.format("❌ Failed to sell %s", petData.name))
                    end
                    print(string.format("🛒 Auto Sell Debug: Failed to sell pet %s", petData.name))
                end

                -- Small delay between sells to avoid spam
                task.wait(0.5)
            end

            if soldCount > 0 then
                if updateSellStatus then
                    updateSellStatus("lastAction", string.format("✅ Sold %d pets this cycle", soldCount))
                end
                print(string.format("🛒 Auto Sell Debug: Cycle complete - sold %d pets", soldCount))
            else
                if updateSellStatus then
                    updateSellStatus("lastAction", "❌ No pets were sold this cycle")
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
    local localPlayer = Players.LocalPlayer
    if not localPlayer then
        print("🛒 Auto Sell Debug: LocalPlayer not found")
        return
    end

    local petsFolder = workspace:FindFirstChild("Pets")
    if not petsFolder then
        print("🛒 Auto Sell Debug: Pets folder not found")
        return
    end

    print("🛒 Auto Sell Debug: Starting comprehensive pet analysis...")

    local totalPets = 0
    local playerPets = 0
    local sellablePets = 0
    local unsellablePets = 0
    local mutationPets = 0

    for _, petModel in ipairs(petsFolder:GetChildren()) do
        if petModel:IsA("Model") then
            totalPets = totalPets + 1

            local rootPart = petModel:FindFirstChild("RootPart")
            if rootPart then
                local petUserId = rootPart:GetAttribute("UserId")
                local petName = petModel.Name
                local hasDAttributeWorkspace = rootPart:GetAttribute("D")
                local hasDAttributeGui = checkPetDAttributeFromGui(petName)
                local hasMAttribute = rootPart:GetAttribute("M")

                if petUserId == localPlayer.UserId then
                    playerPets = playerPets + 1

                    -- Check both workspace and PlayerGui for D attribute
                    local isUnsellable = hasDAttributeWorkspace or hasDAttributeGui

                    print(string.format("🛒 Auto Sell Debug: Pet %s - D_workspace:%s D_gui:%s M:%s",
                        petName,
                        hasDAttributeWorkspace and "YES" or "NO",
                        hasDAttributeGui and "YES" or "NO",
                        hasMAttribute and "YES" or "NO"))

                    if isUnsellable then
                        unsellablePets = unsellablePets + 1
                    else
                        sellablePets = sellablePets + 1
                        if hasMAttribute then
                            mutationPets = mutationPets + 1
                        end
                    end
                end
            else
                print(string.format("🛒 Auto Sell Debug: Pet %s has no RootPart", petModel.Name))
            end
        end
    end

    print("🛒 Auto Sell Debug: Summary:")
    print(string.format("  Total pets in workspace: %d", totalPets))
    print(string.format("  Your pets: %d", playerPets))
    print(string.format("  Sellable pets: %d", sellablePets))
    print(string.format("  Unsellable pets (has D): %d", unsellablePets))
    print(string.format("  Pets with mutations: %d", mutationPets))

    -- Test remote availability
    local remoteAvailable = false
    pcall(function()
        local remote = getPetRemote()
        if remote then
            remoteAvailable = true
            print("🛒 Auto Sell Debug: PetRE remote is available")
        end
    end)

    if not remoteAvailable then
        print("🛒 Auto Sell Debug: WARNING - PetRE remote not found!")
    end
end

return AutoSellSystem
