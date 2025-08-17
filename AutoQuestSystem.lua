-- AutoQuestSystem.lua - Auto Quest Module for Build A Zoo
-- Lua 5.1 Compatible

local AutoQuestSystem = {}

-- Hardcoded data lists (always available regardless of player inventory)
local HardcodedEggTypes = {
    "BasicEgg", "RareEgg", "SuperRareEgg", "EpicEgg", "LegendEgg", 
    "PrismaticEgg", "HyperEgg", "VoidEgg", "BowserEgg", "DemonEgg", 
    "BoneDragonEgg", "UltraEgg", "DinoEgg", "FlyEgg", "UnicornEgg", "AncientEgg"
}

local HardcodedPetTypes = {
    "Capy1", "Capy2", "Pig", "Capy3", "Dog", "Cat", "CapyL1", "Cow", "CapyL2", 
    "Sheep", "CapyL3", "Horse", "Zebra", "Giraffe", "Hippo", "Elephant", "Rabbit", 
    "Mouse", "Ankylosaurus", "Tiger", "Fox", "Panda", "Toucan", "Bee", "Snake", 
    "Butterfly", "Penguin", "Velociraptor", "Stegosaurus", "Seaturtle", "Bear", 
    "Lion", "Rhino", "Kangroo", "Gorilla", "Ostrich", "Triceratops", "Pachycephalosaur", 
    "Pterosaur", "Rex", "Dragon", "Baldeagle", "Griffin", "Brontosaurus", "Plesiosaur", 
    "Spinosaurus", "Unicorn", "Toothless", "Tyrannosaurus", "Mosasaur"
}

local HardcodedMutations = {
    "Golden", "Diamond", "Electric", "Fire", "Jurassic"
}

-- Task configuration data
local TaskConfig = {
    Task_1 = {
        Id = "Task_1",
        TaskPoints = 20,
        RepeatCount = 1,
        CompleteType = "HatchEgg",
        CompleteValue = 5,
        Desc = "K_DINO_DESC_Task_1",
        Icon = "rbxassetid://90239318564009"
    },
    Task_3 = {
        Id = "Task_3",
        TaskPoints = 20,
        RepeatCount = 1,
        CompleteType = "SellPet",
        CompleteValue = 5,
        Desc = "K_DINO_DESC_Task_3",
        Icon = "rbxassetid://90239318564009"
    },
    Task_4 = {
        Id = "Task_4",
        TaskPoints = 20,
        RepeatCount = 1,
        CompleteType = "SendEgg",
        CompleteValue = 5,
        Desc = "K_DINO_DESC_Task_4",
        Icon = "rbxassetid://90239318564009"
    },
    Task_5 = {
        Id = "Task_5",
        TaskPoints = 20,
        RepeatCount = 1,
        CompleteType = "BuyMutateEgg",
        CompleteValue = 1,
        Desc = "K_DINO_DESC_Task_5",
        Icon = "rbxassetid://90239318564009"
    },
    Task_7 = {
        Id = "Task_7",
        TaskPoints = 20,
        RepeatCount = 1,
        CompleteType = "HatchEgg",
        CompleteValue = 10,
        Desc = "K_DINO_DESC_Task_7",
        Icon = "rbxassetid://90239318564009"
    },
    Task_8 = {
        Id = "Task_8",
        TaskPoints = 15,
        RepeatCount = 6,
        CompleteType = "OnlineTime",
        CompleteValue = 900,
        Desc = "K_DINO_DESC_Task_8",
        Icon = "rbxassetid://90239318564009"
    }
}

-- Module state
local questEnabled = false
local questThread = nil
local lastInventoryRefresh = 0
local actionCounter = 0
local sessionLimits = {
    sendEggCount = 0,
    sellPetCount = 0,
    maxSendEgg = 5,
    maxSellPet = 5
}

-- Saved automation states for restoration
local savedStates = {}

-- UI elements (will be assigned during Init)
local questToggle = nil
local claimReadyToggle = nil
local refreshTaskToggle = nil
local targetPlayerDropdown = nil
local sendEggTypeDropdown = nil
local sendEggMutationDropdown = nil
local sellPetTypeDropdown = nil
local sellPetMutationDropdown = nil
local questStatusParagraph = nil

-- Dependencies (passed from main script)
local WindUI = nil
local Window = nil
local Config = nil
local waitForSettingsReady = nil
local autoBuyToggle = nil
local autoPlaceToggle = nil
local autoHatchToggle = nil
local getAutoBuyEnabled = nil
local getAutoPlaceEnabled = nil
local getAutoHatchEnabled = nil

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Helper functions
local function safeGetAttribute(instance, attributeName, default)
    if not instance or not instance.GetAttribute then
        return default
    end
    local success, result = pcall(function()
        return instance:GetAttribute(attributeName)
    end)
    return success and result or default
end

local function refreshPlayerList()
    local playerNames = {"Random Player"}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerNames, player.Name)
        end
    end
    return playerNames
end

local function getRandomPlayer()
    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(players, player)
        end
    end
    if #players > 0 then
        return players[math.random(1, #players)]
    end
    return nil
end

local function getEggInventory()
    local inventory = {}
    local success, err = pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return end
    
    local data = playerGui:FindFirstChild("Data")
        if not data then return end
    
    local eggContainer = data:FindFirstChild("Egg")
        if not eggContainer then return end
        
        for _, eggConfig in ipairs(eggContainer:GetChildren()) do
            if #eggConfig:GetChildren() == 0 then -- Available egg
                local eggType = safeGetAttribute(eggConfig, "T", "Unknown")
                local eggMutation = safeGetAttribute(eggConfig, "M", nil)
                
                table.insert(inventory, {
                    uid = eggConfig.Name,
                    type = eggType,
                    mutation = eggMutation
                })
            end
        end
    end)
    
    if not success then
        warn("Failed to get egg inventory: " .. tostring(err))
    end
    
    return inventory
end

local function getPetInventory()
    local inventory = {}
    local success, err = pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return end
    
    local data = playerGui:FindFirstChild("Data")
        if not data then return end
    
    local petsContainer = data:FindFirstChild("Pets")
        if not petsContainer then return end
        
        for _, petConfig in ipairs(petsContainer:GetChildren()) do
            if petConfig:IsA("Configuration") then
                local petType = safeGetAttribute(petConfig, "T", "Unknown")
                local petMutation = safeGetAttribute(petConfig, "M", nil)
                local isLocked = safeGetAttribute(petConfig, "LK", 0)
                
                if isLocked ~= 1 then -- Skip locked pets
                    table.insert(inventory, {
                        uid = petConfig.Name,
                        type = petType,
                        mutation = petMutation
                    })
                end
            end
        end
    end)
    
    if not success then
        warn("Failed to get pet inventory: " .. tostring(err))
    end
    
    return inventory
end

local function getAllEggTypes()
    -- Return hardcoded list for eggs
    local types = {}
    for _, eggType in ipairs(HardcodedEggTypes) do
        table.insert(types, eggType)
    end
    table.sort(types)
    return types
end

local function getAllPetTypes()
    -- Return hardcoded list for pets
    local types = {}
    for _, petType in ipairs(HardcodedPetTypes) do
        table.insert(types, petType)
    end
    table.sort(types)
    return types
end

local function getAllMutations()
    -- Return hardcoded list for mutations
    local mutations = {}
    for _, mutation in ipairs(HardcodedMutations) do
        table.insert(mutations, mutation)
    end
    table.sort(mutations)
    return mutations
end

local function shouldSendItem(item, excludeTypes, excludeMutations)
    -- If no filters selected, send all
    if #excludeTypes == 0 and #excludeMutations == 0 then
        return true
    end
    
    -- Check if type should be excluded
    for _, excludeType in ipairs(excludeTypes) do
        if item.type == excludeType then
            return false
        end
    end
    
    -- Check if mutation should be excluded
    if item.mutation then
        for _, excludeMutation in ipairs(excludeMutations) do
            if item.mutation == excludeMutation then
                return false
            end
        end
    end
    
    return true
end

local function getCurrentTasks()
    local tasks = {}
    local success, err = pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return end
        
        local data = playerGui:FindFirstChild("Data")
        if not data then return end
        
        local taskData = data:FindFirstChild("DinoEventTaskData")
        if not taskData then return end
        
        local tasksContainer = taskData:FindFirstChild("Tasks")
        if not tasksContainer then return end
        
        for i = 1, 3 do
            local taskSlot = tasksContainer:FindFirstChild(tostring(i))
            if taskSlot then
                local taskId = safeGetAttribute(taskSlot, "Id", nil)
                local progress = safeGetAttribute(taskSlot, "Progress", 0)
                local claimedCount = safeGetAttribute(taskSlot, "ClaimedCount", 0)
                
                if taskId and TaskConfig[taskId] then
                    local task = {}
                    for k, v in pairs(TaskConfig[taskId]) do
                        task[k] = v
                    end
                    task.Progress = progress
                    task.ClaimedCount = claimedCount
                    task.Slot = i
                    
                    table.insert(tasks, task)
                end
            end
        end
    end)
    
    if not success then
        warn("Failed to get current tasks: " .. tostring(err))
    end
    
    return tasks
end

local function claimTask(taskId)
    local success, err = pcall(function()
    local args = {
        {
            event = "claimreward",
            id = taskId
        }
    }
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("DinoEventRE"):FireServer(unpack(args))
    end)
    
    if success then
        WindUI:Notify({ 
            Title = "🏆 Quest Complete",
            Content = "Claimed reward for " .. taskId .. "!",
            Duration = 3 
        })
    else
        warn("Failed to claim task " .. taskId .. ": " .. tostring(err))
    end
    
    return success
end

local function focusItem(itemUID)
    local success, err = pcall(function()
        local args = {"Focus", itemUID}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    if not success then
        warn("Failed to focus item " .. itemUID .. ": " .. tostring(err))
    end
    
    return success
end

local function sendEggToPlayer(eggUID, targetPlayer)
    if sessionLimits.sendEggCount >= sessionLimits.maxSendEgg then
        WindUI:Notify({
            Title = "⚠️ Send Limit",
            Content = "Reached maximum send limit for this session (" .. sessionLimits.maxSendEgg .. ")",
            Duration = 3
        })
        return false
    end
    
    local success, err = pcall(function()
        -- Focus first
        focusItem(eggUID)
        task.wait(0.2)
        
        -- Send to player
        local args = {targetPlayer}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(unpack(args))
    end)
    
    if success then
        sessionLimits.sendEggCount = sessionLimits.sendEggCount + 1
        actionCounter = actionCounter + 1
    else
        warn("Failed to send egg " .. eggUID .. " to " .. tostring(targetPlayer) .. ": " .. tostring(err))
    end
    
    return success
end

local function sellPet(petUID)
    if sessionLimits.sellPetCount >= sessionLimits.maxSellPet then
        WindUI:Notify({
            Title = "⚠️ Sell Limit",
            Content = "Reached maximum sell limit for this session (" .. sessionLimits.maxSellPet .. ")",
            Duration = 3
        })
        return false
    end
    
    local success, err = pcall(function()
        local args = {"Sell", petUID}
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("PetRE"):FireServer(unpack(args))
    end)
    
    if success then
        sessionLimits.sellPetCount = sessionLimits.sellPetCount + 1
        actionCounter = actionCounter + 1
    else
        warn("Failed to sell pet " .. petUID .. ": " .. tostring(err))
    end
    
    return success
end

local function buyMutatedEgg()
    -- Use existing auto buy logic but target only mutated eggs
    local success, foundMutatedEgg = pcall(function()
        local islandName = safeGetAttribute(LocalPlayer, "AssignedIslandName", nil)
        if not islandName then return false end
        
        -- Get conveyor belts (reuse logic from main script)
        local art = workspace:FindFirstChild("Art")
        if not art then return false end
        
        local island = art:FindFirstChild(islandName)
        if not island then return false end
        
        local env = island:FindFirstChild("ENV")
        if not env then return false end
        
        local conveyorRoot = env:FindFirstChild("Conveyor")
        if not conveyorRoot then return false end
        
        -- Check all conveyor belts for mutated eggs
        for i = 1, 9 do
            local conveyor = conveyorRoot:FindFirstChild("Conveyor" .. i)
            if conveyor then
                local belt = conveyor:FindFirstChild("Belt")
                if belt then
                    for _, eggModel in ipairs(belt:GetChildren()) do
                        if eggModel:IsA("Model") then
                            -- Check if egg has mutation
                            local eggType = safeGetAttribute(eggModel, "Type", nil)
                            if eggType then
                                -- Check for mutation by looking for GUI text
                                local rootPart = eggModel:FindFirstChild("RootPart")
                                if rootPart then
                                    local eggGUI = rootPart:FindFirstChild("GUI")
                                    if eggGUI then
                                        local mutateLabel = eggGUI:FindFirstChild("EggGUI")
                                        if mutateLabel then
                                            mutateLabel = mutateLabel:FindFirstChild("Mutate")
                                            if mutateLabel and mutateLabel:IsA("TextLabel") and mutateLabel.Text ~= "" then
                                                -- This egg has a mutation, try to buy it
                                                local buySuccess = pcall(function()
                                                    local args = {"BuyEgg", eggModel.Name}
                                                    ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
                                                    
                                                    -- Focus the egg
                                                    focusItem(eggModel.Name)
                                                    
                                                    actionCounter = actionCounter + 1
                                                end)
                                                
                                                if buySuccess then
                                                    return true
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        return false
    end)
    
    -- Return both success status and whether a mutated egg was found
    if not success then
        warn("Error in buyMutatedEgg: " .. tostring(foundMutatedEgg))
        return false, "Error occurred"
    end
    
    return foundMutatedEgg, foundMutatedEgg and "Bought mutated egg" or "Waiting for mutated egg"
end

local function saveAutomationStates()
    -- Save current automation toggle states using getter functions
    savedStates = {
        autoBuy = getAutoBuyEnabled and getAutoBuyEnabled() or false,
        autoPlace = getAutoPlaceEnabled and getAutoPlaceEnabled() or false,
        autoHatch = getAutoHatchEnabled and getAutoHatchEnabled() or false
    }
end

local function restoreAutomationStates()
    -- Restore previous automation states
    if autoBuyToggle and autoBuyToggle.SetValue and savedStates.autoBuy ~= nil then
        autoBuyToggle:SetValue(savedStates.autoBuy)
    end
    if autoPlaceToggle and autoPlaceToggle.SetValue and savedStates.autoPlace ~= nil then
        autoPlaceToggle:SetValue(savedStates.autoPlace)
    end
    if autoHatchToggle and autoHatchToggle.SetValue and savedStates.autoHatch ~= nil then
        autoHatchToggle:SetValue(savedStates.autoHatch)
        end
    end
    
local function enableHatchingAutomation()
    -- Temporarily enable automation needed for hatching tasks
    if autoBuyToggle and autoBuyToggle.SetValue then autoBuyToggle:SetValue(true) end
    if autoPlaceToggle and autoPlaceToggle.SetValue then autoPlaceToggle:SetValue(true) end
    if autoHatchToggle and autoHatchToggle.SetValue then autoHatchToggle:SetValue(true) end
end

-- Add status tracking for BuyMutateEgg task
local buyMutateEggStatus = "Ready"

local function updateQuestStatus()
    if not questStatusParagraph then return end
    
    local tasks = getCurrentTasks()
    local statusText = "📝 Quest Status:\n"
    
    if #tasks == 0 then
        statusText = statusText .. "No active tasks found."
    else
        for _, task in ipairs(tasks) do
            local progress = task.Progress or 0
            local target = task.CompleteValue or 1
            local claimed = task.ClaimedCount or 0
            local maxClaimed = task.RepeatCount or 1
            
            local progressPercent = math.floor((progress / target) * 100)
            local taskStatus = ""
            
            if claimed >= maxClaimed then
                taskStatus = "✅ COMPLETED"
            elseif progress >= target then
                taskStatus = "🏆 READY TO CLAIM"
            else
                taskStatus = string.format("⏳ %d/%d (%d%%)", progress, target, progressPercent)
                
                -- Add special status for BuyMutateEgg task
                if task.CompleteType == "BuyMutateEgg" then
                    taskStatus = taskStatus .. " - " .. buyMutateEggStatus
                end
            end
            
            statusText = statusText .. string.format("\n%s (%s): %s", task.Id, task.CompleteType, taskStatus)
        end
    end
    
    statusText = statusText .. string.format("\n\n📊 Session Limits:\nSent: %d/%d | Sold: %d/%d", 
        sessionLimits.sendEggCount, sessionLimits.maxSendEgg,
        sessionLimits.sellPetCount, sessionLimits.maxSellPet)
    
    questStatusParagraph:SetDesc(statusText)
end

local function checkInventoryDialog(taskType, requiredTypes, requiredMutations, availableItems)
    local matchingItems = {}
    
    for _, item in ipairs(availableItems) do
        if shouldSendItem(item, requiredTypes, requiredMutations) then
            table.insert(matchingItems, item)
        end
    end
    
    if #matchingItems == 0 then
        -- For Lua 5.1, we'll use a simpler approach with a shared variable
        local userChoice = nil
        
                            Window:Dialog({
            Title = "⚠️ No Matching Items",
            Content = string.format("No %s items match your selected filters.\nDo you want to continue anyway?", taskType),
                                Icon = "alert-triangle",
                                Buttons = {
                                    {
                    Title = "Cancel",
                                        Variant = "Secondary",
                    Callback = function() 
                        userChoice = false 
                    end
                                    },
                                    {
                    Title = "Continue",
                                        Variant = "Primary",
                    Callback = function() 
                        userChoice = true 
                    end
                }
            }
        })
        
        -- Wait for user choice
        while userChoice == nil do
            task.wait(0.1)
        end
        
        return userChoice
    end
    
    return true
end

local function executeQuestTasks()
    while questEnabled do
        local tasks = getCurrentTasks()
        if #tasks == 0 then
            task.wait(5)
            continue
        end
        
        -- Refresh inventory every 5 actions
        if actionCounter - lastInventoryRefresh >= 5 then
            lastInventoryRefresh = actionCounter
        end
        
        -- Sort tasks by priority: BuyMutateEgg → HatchEgg → SendEgg → SellPet → OnlineTime
        local priorityOrder = {"BuyMutateEgg", "HatchEgg", "SendEgg", "SellPet", "OnlineTime"}
        table.sort(tasks, function(a, b)
            local aPriority = 999
            local bPriority = 999
            
            for i, taskType in ipairs(priorityOrder) do
                if a.CompleteType == taskType then aPriority = i end
                if b.CompleteType == taskType then bPriority = i end
            end
            
            return aPriority < bPriority
        end)
        
        local anyTaskActive = false
        
        for _, task in ipairs(tasks) do
            if not questEnabled then break end
            
            local progress = task.Progress or 0
            local target = task.CompleteValue or 1
            local claimed = task.ClaimedCount or 0
            local maxClaimed = task.RepeatCount or 1
            
            -- Check if task is ready to claim
            if progress >= target and claimed < maxClaimed then
                claimTask(task.Id)
                task.wait(1)
            -- Skip completed tasks
            elseif claimed >= maxClaimed then
                -- Task is completed, skip to next
            else
                anyTaskActive = true
                
                -- Execute task based on type
                if task.CompleteType == "HatchEgg" then
                    saveAutomationStates()
                    enableHatchingAutomation()
                    -- Let existing automation handle hatching
                    task.wait(2)
                    
                elseif task.CompleteType == "SendEgg" then
                    local eggInventory = getEggInventory()
                    if #eggInventory == 0 then
                        task.wait(2)
                    else
                        local excludeTypes = {}
                        local excludeMutations = {}
                        
                        if sendEggTypeDropdown and sendEggTypeDropdown.GetValue then
                            local success, result = pcall(function() return sendEggTypeDropdown:GetValue() end)
                            excludeTypes = success and result or {}
                        end
                        
                        if sendEggMutationDropdown and sendEggMutationDropdown.GetValue then
                            local success, result = pcall(function() return sendEggMutationDropdown:GetValue() end)
                            excludeMutations = success and result or {}
                        end
                        
                        -- Check inventory dialog
                        local continueTask = checkInventoryDialog("egg", excludeTypes, excludeMutations, eggInventory)
                        if continueTask then
                            -- Find suitable egg to send
                            local eggToSend = nil
                            for _, egg in ipairs(eggInventory) do
                                if shouldSendItem(egg, excludeTypes, excludeMutations) then
                                    eggToSend = egg
                                    break
                                end
                            end
                            
                            if eggToSend then
                                local targetPlayerName = "Random Player"
                                if targetPlayerDropdown and targetPlayerDropdown.GetValue then
                                    local success, result = pcall(function() return targetPlayerDropdown:GetValue() end)
                                    targetPlayerName = success and result or "Random Player"
                                end
                                
                                local targetPlayer = nil
                                
                                if targetPlayerName == "Random Player" then
                                    targetPlayer = getRandomPlayer()
                                else
                                    targetPlayer = Players:FindFirstChild(targetPlayerName)
                                end
                                
                                if targetPlayer then
                                    sendEggToPlayer(eggToSend.uid, targetPlayer)
                                    task.wait(1)
                                else
                                    -- Player not found, try random
                                    targetPlayer = getRandomPlayer()
                                    if targetPlayer then
                                        sendEggToPlayer(eggToSend.uid, targetPlayer)
                                        task.wait(1)
                                    end
                                end
                            end
                        else
                            task.wait(5)
                        end
                    end
                
                elseif task.CompleteType == "SellPet" then
                    local petInventory = getPetInventory()
                    if #petInventory == 0 then
                        task.wait(2)
                    else
                        local excludeTypes = {}
                        local excludeMutations = {}
                        
                        if sellPetTypeDropdown and sellPetTypeDropdown.GetValue then
                            local success, result = pcall(function() return sellPetTypeDropdown:GetValue() end)
                            excludeTypes = success and result or {}
                        end
                        
                        if sellPetMutationDropdown and sellPetMutationDropdown.GetValue then
                            local success, result = pcall(function() return sellPetMutationDropdown:GetValue() end)
                            excludeMutations = success and result or {}
                        end
                        
                        -- Check inventory dialog
                        local continueTask = checkInventoryDialog("pet", excludeTypes, excludeMutations, petInventory)
                        if continueTask then
                            -- Find suitable pet to sell
                            local petToSell = nil
                            for _, pet in ipairs(petInventory) do
                                if shouldSendItem(pet, excludeTypes, excludeMutations) then
                                    petToSell = pet
                                    break
                                end
                            end
                            
                            if petToSell then
                                sellPet(petToSell.uid)
                                task.wait(1)
                            end
                        else
                            task.wait(5)
                        end
                    end
                    
                elseif task.CompleteType == "BuyMutateEgg" then
                    local buySuccess, statusMessage = buyMutatedEgg()
                    buyMutateEggStatus = statusMessage or "Waiting for mutated egg"
                    
                    if buySuccess then
                        task.wait(1) -- Shorter wait if successful
                    else
                        task.wait(3) -- Longer wait if no mutated eggs found
                    end
                    
                elseif task.CompleteType == "OnlineTime" then
                    -- Just wait and claim when ready
                    task.wait(5)
                end
            end
        end
        
        -- Update status display
        updateQuestStatus()
        
        if not anyTaskActive then
            -- All tasks completed, restore automation states
            restoreAutomationStates()
            task.wait(10)
        else
            task.wait(1)
        end
    end
    
    -- Restore automation states when quest is disabled
    restoreAutomationStates()
end

-- Auto claim function
local function runAutoClaimReady()
    while questEnabled and claimReadyToggle do
        local claimEnabled = false
        if claimReadyToggle.GetValue then
            local success, result = pcall(function() return claimReadyToggle:GetValue() end)
            claimEnabled = success and result or false
        end
        
        if not claimEnabled then
            task.wait(3)
            continue
        end
        
        local tasks = getCurrentTasks()
        
        for _, task in ipairs(tasks) do
            local progress = task.Progress or 0
            local target = task.CompleteValue or 1
            local claimed = task.ClaimedCount or 0
            local maxClaimed = task.RepeatCount or 1
            
            if progress >= target and claimed < maxClaimed then
                claimTask(task.Id)
            end
        end
        
        task.wait(3)
    end
end

-- Auto refresh function
local function runAutoRefreshTasks()
    while questEnabled and refreshTaskToggle do
        local refreshEnabled = false
        if refreshTaskToggle.GetValue then
            local success, result = pcall(function() return refreshTaskToggle:GetValue() end)
            refreshEnabled = success and result or false
        end
        
        if not refreshEnabled then
            task.wait(10)
            continue
        end
        
        updateQuestStatus()
        
        -- Refresh dropdowns (use SetValues method for WindUI)
        if targetPlayerDropdown and targetPlayerDropdown.SetValues then
            pcall(function() targetPlayerDropdown:SetValues(refreshPlayerList()) end)
        end
        
        if sendEggTypeDropdown and sendEggTypeDropdown.SetValues then
            pcall(function() sendEggTypeDropdown:SetValues(getAllEggTypes()) end)
        end
        
        if sendEggMutationDropdown and sendEggMutationDropdown.SetValues then
            pcall(function() sendEggMutationDropdown:SetValues(getAllMutations()) end)
        end
        
        if sellPetTypeDropdown and sellPetTypeDropdown.SetValues then
            pcall(function() sellPetTypeDropdown:SetValues(getAllPetTypes()) end)
        end
        
        if sellPetMutationDropdown and sellPetMutationDropdown.SetValues then
            pcall(function() sellPetMutationDropdown:SetValues(getAllMutations()) end)
        end
        
        task.wait(10)
    end
end

-- Main quest execution function
local function runAutoQuest()
    -- Start the auto claim and refresh threads when quest starts
    local claimThread = task.spawn(runAutoClaimReady)
    local refreshThread = task.spawn(runAutoRefreshTasks)
    
    while questEnabled do
        local ok, err = pcall(executeQuestTasks)
        if not ok then
            warn("Auto Quest error: " .. tostring(err))
            task.wait(5)
        end
    end
    
    -- Clean up threads when quest stops
    pcall(function() 
        if claimThread then
            task.cancel(claimThread)
        end
    end)
    pcall(function() 
        if refreshThread then
            task.cancel(refreshThread)
        end
    end)
end

-- Initialize function
function AutoQuestSystem.Init(dependencies)
    WindUI = dependencies.WindUI
    Window = dependencies.Window
    Config = dependencies.Config
    waitForSettingsReady = dependencies.waitForSettingsReady
    autoBuyToggle = dependencies.autoBuyToggle
    autoPlaceToggle = dependencies.autoPlaceToggle
    autoHatchToggle = dependencies.autoHatchToggle
    getAutoBuyEnabled = dependencies.getAutoBuyEnabled
    getAutoPlaceEnabled = dependencies.getAutoPlaceEnabled
    getAutoHatchEnabled = dependencies.getAutoHatchEnabled
    
    -- Create the Quest tab
    local QuestTab = Window:Tab({ Title = "📝 | Auto Quest", Icon = "clipboard-list" })
    
    -- Status display
    questStatusParagraph = QuestTab:Paragraph({
        Title = "📝 Quest Status",
        Desc = "Loading quest information...",
        Image = "clipboard-list",
        ImageSize = 22
    })
    
    -- Main toggle
    questToggle = QuestTab:Toggle({
        Title = "📝 Auto Quest",
        Desc = "Automatically complete daily quest tasks",
        Value = false,
        Callback = function(state)
            questEnabled = state
            
            waitForSettingsReady(0.2)
            if state and not questThread then
                questThread = task.spawn(function()
                    runAutoQuest()
                    questThread = nil
                end)
                WindUI:Notify({ Title = "📝 Auto Quest", Content = "Started quest automation! 🎉", Duration = 3 })
            elseif not state and questThread then
                WindUI:Notify({ Title = "📝 Auto Quest", Content = "Stopped", Duration = 3 })
            end
        end
    })
    
    QuestTab:Section({ Title = "🎯 Target Settings", Icon = "target" })
    
    -- Target player dropdown
    targetPlayerDropdown = QuestTab:Dropdown({
        Title = "🎯 Target Player",
        Desc = "Select player to send eggs to (Random = different player each time)",
        Values = refreshPlayerList(),
        Value = "Random Player",
        Callback = function(selection) end
    })
    
    QuestTab:Section({ Title = "🥚 Send Egg Filters", Icon = "mail" })
    
    -- Send egg type filter
    sendEggTypeDropdown = QuestTab:Dropdown({
        Title = "🚫 Exclude Egg Types",
        Desc = "Select egg types to NOT send (empty = send all types)",
        Values = getAllEggTypes(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection) end
    })
    
    -- Send egg mutation filter
    sendEggMutationDropdown = QuestTab:Dropdown({
        Title = "🚫 Exclude Egg Mutations", 
        Desc = "Select mutations to NOT send (empty = send all mutations)",
        Values = getAllMutations(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection) end
    })
    
    QuestTab:Section({ Title = "💰 Sell Pet Filters", Icon = "dollar-sign" })
    
    -- Sell pet type filter
    sellPetTypeDropdown = QuestTab:Dropdown({
        Title = "🚫 Exclude Pet Types",
        Desc = "Select pet types to NOT sell (empty = sell all types)",
        Values = getAllPetTypes(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection) end
    })
    
    -- Sell pet mutation filter
    sellPetMutationDropdown = QuestTab:Dropdown({
        Title = "🚫 Exclude Pet Mutations",
        Desc = "Select mutations to NOT sell (empty = sell all mutations)",
        Values = getAllMutations(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection) end
    })
    
    QuestTab:Section({ Title = "🔄 Automation", Icon = "refresh-cw" })
    
    -- Auto claim toggle
    claimReadyToggle = QuestTab:Toggle({
        Title = "🏆 Auto Claim Ready",
        Desc = "Automatically claim tasks when they reach 100%",
        Value = true,
        Callback = function(state)
            -- The runAutoClaimReady function will check the toggle state itself
            -- No need to start/stop threads here since main quest loop handles it
        end
    })
    
    -- Auto refresh toggle
    refreshTaskToggle = QuestTab:Toggle({
        Title = "🔄 Auto Refresh Tasks",
        Desc = "Automatically refresh task status and dropdown lists",
        Value = true,
        Callback = function(state)
            -- The runAutoRefreshTasks function will check the toggle state itself
            -- No need to start/stop threads here since main quest loop handles it
        end
    })
    
    QuestTab:Section({ Title = "🛠️ Manual Controls", Icon = "settings" })
    
    -- Manual claim button
    QuestTab:Button({
        Title = "🏆 Claim All Ready Now",
        Desc = "Manually claim all ready tasks right now",
        Callback = function()
            local tasks = getCurrentTasks()
            local claimedCount = 0
            
            for _, task in ipairs(tasks) do
                local progress = task.Progress or 0
                local target = task.CompleteValue or 1
                local claimed = task.ClaimedCount or 0
                local maxClaimed = task.RepeatCount or 1
                
                if progress >= target and claimed < maxClaimed then
                    if claimTask(task.Id) then
                        claimedCount = claimedCount + 1
                    end
                    task.wait(0.5)
                end
            end
            
            WindUI:Notify({
                Title = "🏆 Manual Claim",
                Content = string.format("Claimed %d tasks!", claimedCount),
                Duration = 3
            })
        end
    })
    
    -- Manual refresh button
    QuestTab:Button({
        Title = "🔄 Refresh All Now", 
        Desc = "Manually refresh status and dropdown lists",
        Callback = function()
            updateQuestStatus()
            
            -- Refresh all dropdowns
            if targetPlayerDropdown and targetPlayerDropdown.SetValues then
                pcall(function() targetPlayerDropdown:SetValues(refreshPlayerList()) end)
            end
            if sendEggTypeDropdown and sendEggTypeDropdown.SetValues then
                pcall(function() sendEggTypeDropdown:SetValues(getAllEggTypes()) end)
            end
            if sendEggMutationDropdown and sendEggMutationDropdown.SetValues then
                pcall(function() sendEggMutationDropdown:SetValues(getAllMutations()) end)
            end
            if sellPetTypeDropdown and sellPetTypeDropdown.SetValues then
                pcall(function() sellPetTypeDropdown:SetValues(getAllPetTypes()) end)
            end
            if sellPetMutationDropdown and sellPetMutationDropdown.SetValues then
                pcall(function() sellPetMutationDropdown:SetValues(getAllMutations()) end)
            end
            
            WindUI:Notify({
                Title = "🔄 Refresh Complete",
                Content = "All data refreshed!",
                Duration = 2
            })
        end
    })
    
    -- Emergency stop button
    QuestTab:Button({
        Title = "🛑 Emergency Stop",
        Desc = "Immediately stop all quest actions and restore automation states",
        Callback = function()
            questEnabled = false
            if questToggle then questToggle:SetValue(false) end
            restoreAutomationStates()
            
            WindUI:Notify({
                Title = "🛑 Emergency Stop",
                Content = "All quest actions stopped!",
                Duration = 3
            })
        end
    })
    
    -- Reset session limits button
    QuestTab:Button({
        Title = "🔄 Reset Session Limits",
        Desc = "Reset send/sell counters for this session",
        Callback = function()
            sessionLimits.sendEggCount = 0
            sessionLimits.sellPetCount = 0
            updateQuestStatus()
            
            WindUI:Notify({
                Title = "🔄 Session Reset",
                Content = "Send/sell limits reset!",
                Duration = 2
            })
        end
    })
    
    -- Register UI elements with config
    if Config then
        Config:Register("questEnabled", questToggle)
        Config:Register("claimReadyEnabled", claimReadyToggle)
        Config:Register("refreshTaskEnabled", refreshTaskToggle)
        Config:Register("targetPlayer", targetPlayerDropdown)
        Config:Register("sendEggTypeFilter", sendEggTypeDropdown)
        Config:Register("sendEggMutationFilter", sendEggMutationDropdown)
        Config:Register("sellPetTypeFilter", sellPetTypeDropdown)
        Config:Register("sellPetMutationFilter", sellPetMutationDropdown)
    end
    
    -- Initial status update
    task.spawn(function()
        task.wait(1)
        updateQuestStatus()
        
        -- Initial dropdown population
        if targetPlayerDropdown and targetPlayerDropdown.SetValues then
            pcall(function() targetPlayerDropdown:SetValues(refreshPlayerList()) end)
        end
        if sendEggTypeDropdown and sendEggTypeDropdown.SetValues then
            pcall(function() sendEggTypeDropdown:SetValues(getAllEggTypes()) end)
        end
        if sendEggMutationDropdown and sendEggMutationDropdown.SetValues then
            pcall(function() sendEggMutationDropdown:SetValues(getAllMutations()) end)
        end
        if sellPetTypeDropdown and sellPetTypeDropdown.SetValues then
            pcall(function() sellPetTypeDropdown:SetValues(getAllPetTypes()) end)
        end
        if sellPetMutationDropdown and sellPetMutationDropdown.SetValues then
            pcall(function() sellPetMutationDropdown:SetValues(getAllMutations()) end)
        end
    end)
    
    return AutoQuestSystem
end

return AutoQuestSystem
