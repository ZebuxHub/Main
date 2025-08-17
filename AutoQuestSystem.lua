-- AutoQuestSystem.lua - Auto Quest Module for Build A Zoo
-- Lua 5.1 Compatible

local AutoQuestSystem = {}

-- Hardcoded data lists (always available regardless of player inventory)
local HardcodedEggTypes = {
    "BasicEgg", "RareEgg", "SuperRareEgg", "EpicEgg", "LegendEgg", 
    "PrismaticEgg", "HyperEgg", "VoidEgg", "BowserEgg", "DemonEgg", 
    "BoneDragonEgg", "UltraEgg", "DinoEgg", "FlyEgg", "UnicornEgg", "AncientEgg"
}

-- Egg hatch time data for prioritization (fastest first)
local EggHatchTimes = {
    BasicEgg = 5,
    RareEgg = 20,
    SuperRareEgg = 40,
    FlyEgg = 60,
    AncientEgg = 60,
    EpicEgg = 120,
    LegendEgg = 360,
    PrismaticEgg = 720,
    HyperEgg = 2160,
    VoidEgg = 2880,
    BowserEgg = 4320,
    DemonEgg = 5400,
    DinoEgg = 7200,
    BoneDragonEgg = 7200,
    UltraEgg = 14400,
    UnicornEgg = 14400
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

-- Status tracking for BuyMutateEgg task
local buyMutateEggStatus = "Ready"
local buyMutateEggRetries = 0
local maxBuyMutateRetries = 30 -- Give up after 30 attempts (30 seconds)
local buyMutateEggThread = nil -- Background thread for continuous monitoring

-- Auto delete settings
local autoDeleteMinSpeed = 0 -- Minimum speed threshold for auto-deletion (user configurable)

-- Smart egg placement variables
local currentPlacementTarget = nil -- Locks onto current best available option
local placementTargetTime = math.huge -- Track the locked target hatch time

-- Custom settings that need manual save/load
local customAutoQuestSettings = {
    autoDeleteMinSpeed = 0,
    currentPlacementTarget = nil,
    placementTargetTime = math.huge,
    sessionLimits = {
        sendEggCount = 0,
        sellPetCount = 0,
        maxSendEgg = 5,
        maxSellPet = 5
    }
}

-- UI elements (will be assigned during Init)
local questToggle = nil
local targetPlayerDropdown = nil
local sendEggTypeDropdown = nil
local sendEggMutationDropdown = nil
local sellPetTypeDropdown = nil
local sellPetMutationDropdown = nil
local questStatusParagraph = nil
local autoDeleteSlider = nil

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
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- File system functions
local writefile = writefile
local readfile = readfile
local isfile = isfile

-- Forward declarations
local findAndHatchReadyEggs
local getOwnerUserIdDeep
local buyAnyCheapestEgg

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

-- Custom settings save/load functions
local function saveCustomAutoQuestSettings()
    if not writefile or not HttpService then return end
    
    -- Update custom settings with current values
    customAutoQuestSettings.autoDeleteMinSpeed = autoDeleteMinSpeed
    customAutoQuestSettings.currentPlacementTarget = currentPlacementTarget
    customAutoQuestSettings.placementTargetTime = placementTargetTime
    customAutoQuestSettings.sessionLimits = {
        sendEggCount = sessionLimits.sendEggCount or 0,
        sellPetCount = sessionLimits.sellPetCount or 0,
        maxSendEgg = sessionLimits.maxSendEgg or 5,
        maxSellPet = sessionLimits.maxSellPet or 5
    }
    
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(customAutoQuestSettings)
    end)
    
    if success then
        pcall(function()
            writefile("AutoQuestCustomSettings.json", encoded)
            print("Auto Quest: Custom settings saved")
        end)
    end
end

local function loadCustomAutoQuestSettings()
    if not readfile or not isfile or not HttpService then return end
    
    if not isfile("AutoQuestCustomSettings.json") then
        print("Auto Quest: No custom settings file found, using defaults")
        return
    end
    
    local success, fileContent = pcall(function()
        return readfile("AutoQuestCustomSettings.json")
    end)
    
    if not success then
        print("Auto Quest: Failed to read custom settings file")
        return
    end
    
    local decoded = nil
    success, decoded = pcall(function()
        return HttpService:JSONDecode(fileContent)
    end)
    
    if success and decoded then
        -- Load custom settings
        autoDeleteMinSpeed = decoded.autoDeleteMinSpeed or 0
        currentPlacementTarget = decoded.currentPlacementTarget
        placementTargetTime = decoded.placementTargetTime or math.huge
        
        if decoded.sessionLimits then
            sessionLimits.sendEggCount = decoded.sessionLimits.sendEggCount or 0
            sessionLimits.sellPetCount = decoded.sessionLimits.sellPetCount or 0
            sessionLimits.maxSendEgg = decoded.sessionLimits.maxSendEgg or 5
            sessionLimits.maxSellPet = decoded.sessionLimits.maxSellPet or 5
        end
        
        -- Update UI elements if they exist
        if autoDeleteSlider and autoDeleteSlider.SetValue then
            pcall(function() autoDeleteSlider:SetValue(tostring(autoDeleteMinSpeed)) end)
        end
        
        print("Auto Quest: Custom settings loaded successfully")
    else
        print("Auto Quest: Failed to decode custom settings file")
    end
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
    -- Use the exact same logic as the main script's auto-buy but target only mutated eggs
    local islandName = safeGetAttribute(LocalPlayer, "AssignedIslandName", nil)
    if not islandName then return false, "No island assigned" end
    
    -- Get conveyor belts using the same method as main script
    local art = workspace:FindFirstChild("Art")
    if not art then return false, "Art folder not found" end
    
    local island = art:FindFirstChild(islandName)
    if not island then return false, "Island not found" end
    
    local env = island:FindFirstChild("ENV")
    if not env then return false, "ENV folder not found" end
    
    local conveyorRoot = env:FindFirstChild("Conveyor")
    if not conveyorRoot then return false, "Conveyor folder not found" end
    
    -- Check all conveyor belts for mutated eggs (exact same as main script)
    for i = 1, 9 do
        local conveyor = conveyorRoot:FindFirstChild("Conveyor" .. i)
        if conveyor then
            local belt = conveyor:FindFirstChild("Belt")
            if belt then
                for _, eggModel in ipairs(belt:GetChildren()) do
                    if eggModel:IsA("Model") then
                        -- Use the exact same mutation detection logic as main script
                        local rootPart = eggModel:FindFirstChild("RootPart")
                        if rootPart then
                            local eggGUI = rootPart:FindFirstChild("GUI/EggGUI")
                            if eggGUI then
                                local mutateText = eggGUI:FindFirstChild("Mutate")
                                if mutateText and mutateText:IsA("TextLabel") then
                                    local mutationText = mutateText.Text
                                    if mutationText and mutationText ~= "" then
                                        -- This egg has a mutation, try to buy it using the same method as main script
                                        print("Auto Quest: Found mutated egg, attempting to buy: " .. eggModel.Name)
                                        
                                        -- Use the exact same buying method as main script
                                        local buySuccess = pcall(function()
                                            local args = {"BuyEgg", eggModel.Name}
                                            ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
                                        end)
                                        
                                        if buySuccess then
                                            -- Focus the egg after buying (same as main script)
                                            wait(0.2)
                                            local focusSuccess = pcall(function()
                                                local args = {"Focus", eggModel.Name}
                                                ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
                                            end)
                                            
                                            actionCounter = actionCounter + 1
                                            print("Auto Quest: Successfully bought mutated egg: " .. eggModel.Name)
                                            return true, "Bought mutated egg: " .. eggModel.Name
                                        else
                                            print("Auto Quest: Failed to buy mutated egg: " .. eggModel.Name)
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
    
    return false, "No mutated eggs found on conveyor"
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
            wait(5)
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
                wait(1)
            -- Skip completed tasks
            elseif claimed >= maxClaimed then
                -- Task is completed, skip to next
            else
                anyTaskActive = true
                
                -- Execute task based on type
                if task.CompleteType == "HatchEgg" then
                    saveAutomationStates()
                    enableHatchingAutomation()
                    
                    -- PRIORITY 1: Check for ready-to-hatch eggs on farm first
                    local hatchSuccess, hatchMessage = findAndHatchReadyEggs()
                    if hatchSuccess then
                        print("Auto Quest HatchEgg: " .. hatchMessage)
                        wait(1) -- Brief wait after hatching ready eggs
                    else
                        -- PRIORITY 2: Check if we have eggs in inventory to place
                        local eggInventory = getEggInventory()
                        if #eggInventory > 0 then
                            -- Let existing automation handle placing and hatching
                            print("Auto Quest HatchEgg: Letting automation handle egg placement")
                            wait(2)
                        else
                            -- PRIORITY 3: No eggs available, auto placement system will handle buying
                            print("Auto Quest HatchEgg: No eggs available, auto placement will handle")
                            wait(0.5) -- Brief pause before checking other tasks
                        end
                    end
                    
                elseif task.CompleteType == "SendEgg" then
                    local eggInventory = getEggInventory()
                    if #eggInventory == 0 then
                        -- Use same Auto Buy logic as main script
                        print("Auto Quest SendEgg: No eggs in inventory, scanning conveyor belts")
                        
                        local islandName = safeGetAttribute(LocalPlayer, "AssignedIslandName", nil)
                        if islandName then
                            local art = workspace:FindFirstChild("Art")
                            if art then
                                local island = art:FindFirstChild(islandName)
                                if island then
                                    local env = island:FindFirstChild("ENV")
                                    if env then
                                        local conveyorRoot = env:FindFirstChild("Conveyor")
                                        if conveyorRoot then
                                            local foundEgg = false
                                            
                                            -- Check all conveyor belts for any eggs
                                            for i = 1, 9 do
                                                local conveyor = conveyorRoot:FindFirstChild("Conveyor" .. i)
                                                if conveyor then
                                                    local belt = conveyor:FindFirstChild("Belt")
                                                    if belt then
                                                        for _, eggModel in pairs(belt:GetChildren()) do
                                                            if eggModel:IsA("Model") then
                                                                local netWorth = LocalPlayer:GetAttribute("NetWorth") or 0
                                                                local eggType = safeGetAttribute(eggModel, "Type", nil)
                                                                local price = safeGetAttribute(eggModel, "Price", 0)
                                                                
                                                                if eggType and price and netWorth >= price then
                                                                    -- Buy this egg
                                                                    local buySuccess = pcall(function()
                                                                        local args = {"BuyEgg", eggModel.Name}
                                                                        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
                                                                        focusItem(eggModel.Name)
                                                                    end)
                                                                    
                                                                    if buySuccess then
                                                                        print("Auto Quest SendEgg: Bought egg for sending")
                                                                        foundEgg = true
                                                                        break
                                                                    end
                                                                end
                                                            end
                                                        end
                                                        if foundEgg then break end
                                                    end
                                                end
                                            end
                                            
                                            if not foundEgg then
                                                print("Auto Quest SendEgg: No affordable eggs found on conveyor")
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        
                        wait(2) -- Wait for purchase to process
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
                                    wait(1)
                                else
                                    -- Player not found, try random
                                    targetPlayer = getRandomPlayer()
                                    if targetPlayer then
                                        sendEggToPlayer(eggToSend.uid, targetPlayer)
                                        wait(1)
                                    end
                                end
                            end
                        else
                            wait(5)
                            end
                        end
                        
                elseif task.CompleteType == "SellPet" then
                    local petInventory = getPetInventory()
                    if #petInventory == 0 then
                        wait(2)
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
                                wait(1)
                            end
                        else
                            wait(5)
                        end
                    end
                    
                elseif task.CompleteType == "BuyMutateEgg" then
                    -- BuyMutateEgg runs in background thread, just skip here
                    -- The background monitor will handle buying and auto-claiming
                    
                elseif task.CompleteType == "OnlineTime" then
                        -- Just wait and claim when ready
                    wait(5)
                end
            end
        end
        
        -- Update status display
        updateQuestStatus()
        
        if not anyTaskActive then
            -- All tasks completed, restore automation states
            restoreAutomationStates()
            wait(10)
        else
            wait(1)
        end
    end
    
    -- Restore automation states when quest is disabled
    restoreAutomationStates()
end

-- Auto claim function (always active when quest enabled)
local function runAutoClaimReady()
    while questEnabled do
        local tasks = getCurrentTasks()
        
        for _, task in ipairs(tasks) do
            local progress = task.Progress or 0
            local target = task.CompleteValue or 1
            local claimed = task.ClaimedCount or 0
            local maxClaimed = task.RepeatCount or 1
            
            if progress >= target and claimed < maxClaimed then
                claimTask(task.Id)
                wait(0.5) -- Small delay between claims
            end
        end
        
        wait(2) -- Check every 2 seconds
    end
end

-- Helper function to check for empty farm tiles
local function getEmptyFarmTiles()
    local emptyTiles = {}
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    
    if not LocalPlayer or not LocalPlayer.Character then
        return emptyTiles
    end
    
    local islandsFolder = workspace:FindFirstChild("Islands")
    if not islandsFolder then
        return emptyTiles
    end
    
    local playerIslandName = LocalPlayer:GetAttribute("AssignedIslandName")
    if not playerIslandName then
        return emptyTiles
    end
    
    local playerIsland = islandsFolder:FindFirstChild(playerIslandName)
    if not playerIsland then
        return emptyTiles
    end
    
    local tilesFolder = playerIsland:FindFirstChild("Tiles")
    if not tilesFolder then
        return emptyTiles
    end
    
    -- Check each tile for occupancy
    for _, tile in pairs(tilesFolder:GetChildren()) do
        if tile:IsA("Model") and tile.Name == "Tile" then
            local hasEgg = false
            
            -- Check if tile has any eggs
            for _, child in pairs(tile:GetChildren()) do
                if child:IsA("Model") and child.Name ~= "Tile" then
                    hasEgg = true
                                    break
                                end
                            end
            
            if not hasEgg then
                table.insert(emptyTiles, tile)
                            end
                        end
                    end
                    
    return emptyTiles
end

-- Smart fallback egg selection with priority locking

-- Helper function to get best egg for placement (smart fallback system)
local function getBestEggForPlacement()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    
    if not LocalPlayer or not LocalPlayer.PlayerGui or not LocalPlayer.PlayerGui.Data then
        return nil
    end
    
    local eggFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Egg")
    if not eggFolder then
        return nil
    end
    
    local availableEggs = {}
    
    -- Collect all available eggs with their hatch times
    for _, eggData in pairs(eggFolder:GetChildren()) do
        if eggData:IsA("Configuration") then
            local eggType = eggData:GetAttribute("T")
            local eggMutation = eggData:GetAttribute("M")
            local eggValue = eggData:GetAttribute("NetWorth") or 0
            local hatchTime = EggHatchTimes[eggType] or math.huge
            
            table.insert(availableEggs, {
                uid = eggData.Name,
                type = eggType,
                mutation = eggMutation,
                value = eggValue,
                hatchTime = hatchTime
            })
        end
    end
    
    if #availableEggs == 0 then
        -- Reset target when no eggs available
        currentPlacementTarget = nil
        placementTargetTime = math.huge
        return nil
    end
    
    -- Sort eggs by hatch time (fastest first)
    table.sort(availableEggs, function(a, b) return a.hatchTime < b.hatchTime end)
    
    -- Smart fallback logic
    if not currentPlacementTarget then
        -- No current target, pick the fastest available
        currentPlacementTarget = availableEggs[1].type
        placementTargetTime = availableEggs[1].hatchTime
        print(string.format("Auto Placement: Locked onto %s (hatch: %ds) as target", 
            currentPlacementTarget, placementTargetTime))
        saveCustomAutoQuestSettings()
    end
    
    -- Look for our current target first
    for _, egg in ipairs(availableEggs) do
        if egg.type == currentPlacementTarget then
            -- Found our locked target, use it
            return egg
        end
    end
    
    -- Current target not available, check if we should upgrade
    local fastestAvailable = availableEggs[1]
    
    -- Only upgrade to significantly faster eggs (at least 2x faster)
    if fastestAvailable.hatchTime < (placementTargetTime / 2) then
        currentPlacementTarget = fastestAvailable.type
        placementTargetTime = fastestAvailable.hatchTime
        print(string.format("Auto Placement: Upgraded target to %s (hatch: %ds) - significantly faster!", 
            currentPlacementTarget, placementTargetTime))
        saveCustomAutoQuestSettings()
        return fastestAvailable
    else
        -- Fallback to next best available (don't change target)
        print(string.format("Auto Placement: Target %s unavailable, using fallback %s (hatch: %ds)", 
            currentPlacementTarget, fastestAvailable.type, fastestAvailable.hatchTime))
        return fastestAvailable
    end
end

-- Helper function to buy cheapest available egg
buyAnyCheapestEgg = function()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    
    if not LocalPlayer then
        return false, "Player not found"
    end
    
    local playerNetWorth = LocalPlayer:GetAttribute("NetWorth") or 0
    
    -- Find conveyor belts
    local conveyorBelts = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "ConveyorBelt" and obj:IsA("Model") then
            table.insert(conveyorBelts, obj)
        end
    end
    
    if #conveyorBelts == 0 then
        return false, "No conveyor belts found"
    end
    
    local cheapestEgg = nil
    local lowestPrice = math.huge
    
    -- Find cheapest affordable egg
    for _, belt in pairs(conveyorBelts) do
        for _, eggModel in pairs(belt:GetChildren()) do
            if eggModel:IsA("Model") and eggModel.Name == "Egg" then
                local eggGui = eggModel:FindFirstChild("EggGui")
                if eggGui then
                    local priceLabel = eggGui:FindFirstChild("Price")
                    if priceLabel and priceLabel:IsA("TextLabel") then
                        local priceText = priceLabel.Text
                        local price = tonumber(priceText:match("%d+"))
                        
                        if price and price < lowestPrice and price <= playerNetWorth then
                            lowestPrice = price
                            cheapestEgg = eggModel
                        end
                    end
                end
            end
        end
    end
    
    if not cheapestEgg then
        return false, "No affordable eggs found"
    end
    
    -- Buy the cheapest egg
    local proximityPrompt = cheapestEgg:FindFirstChildOfClass("ProximityPrompt")
    if proximityPrompt then
        game:GetService("ProximityPromptService"):PromptTriggered(proximityPrompt)
        wait(0.5)
        return true, "Bought cheapest egg for placement"
    end
    
    return false, "No proximity prompt found"
end

-- Helper functions for ready egg detection (same as main script)
local function isStringEmpty(s)
    return type(s) == "string" and (s == "" or s:match("^%s*$") ~= nil)
end

local function isReadyText(text)
    if type(text) ~= "string" then return false end
    -- Empty or whitespace means ready
    if isStringEmpty(text) then return true end
    -- Percent text like "100%", "100.0%", "100.00%" also counts as ready
    local num = text:match("^%s*(%d+%.?%d*)%s*%%%s*$")
    if num then
        local n = tonumber(num)
        if n and n >= 100 then return true end
    end
    -- Words that often mean ready
    local lower = string.lower(text)
    if string.find(lower, "hatch", 1, true) or string.find(lower, "ready", 1, true) then
        return true
    end
    return false
end

local function isHatchReady(model)
    -- Look for TimeBar/TXT text being empty anywhere under the model
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("TextLabel") and d.Name == "TXT" then
            local parent = d.Parent
            if parent and parent.Name == "TimeBar" then
                if isReadyText(d.Text) then
                    return true
                end
            end
        end
        if d:IsA("ProximityPrompt") and type(d.ActionText) == "string" then
            local at = string.lower(d.ActionText)
            if string.find(at, "hatch", 1, true) then
                return true
            end
        end
    end
    return false
end

local function playerOwnsInstance(inst)
    if not inst then return false end
    local ownerId = getOwnerUserIdDeep(inst)
    local lp = Players.LocalPlayer
    return ownerId ~= nil and lp and lp.UserId == ownerId
end

getOwnerUserIdDeep = function(inst)
    local current = inst
    while current and current ~= workspace do
        if current.GetAttribute then
            local uidAttr = current:GetAttribute("UserId")
            if type(uidAttr) == "number" then return uidAttr end
            if type(uidAttr) == "string" then
                local n = tonumber(uidAttr)
                if n then return n end
            end
        end
        current = current.Parent
    end
    return nil
end

local function collectOwnedEggs()
    local owned = {}
    local container = workspace:FindFirstChild("PlayerBuiltBlocks")
    if not container then
        -- No PlayerBuiltBlocks found
        return owned
    end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Model") and playerOwnsInstance(child) then
            table.insert(owned, child)
        end
    end
    -- also allow owned nested models (fallback)
    if #owned == 0 then
        for _, child in ipairs(container:GetDescendants()) do
            if child:IsA("Model") and playerOwnsInstance(child) then
                table.insert(owned, child)
            end
        end
    end
    return owned
end

local function filterReadyEggs(models)
    local ready = {}
    for _, m in ipairs(models or {}) do
        if isHatchReady(m) then table.insert(ready, m) end
    end
    return ready
end

local function pressPromptE(prompt)
    if typeof(prompt) ~= "Instance" or not prompt:IsA("ProximityPrompt") then return false end
    -- Try executor helper first
    if _G and typeof(_G.fireproximityprompt) == "function" then
        local s = pcall(function() _G.fireproximityprompt(prompt, prompt.HoldDuration or 0) end)
        if s then return true end
    end
    -- Pure client fallback: simulate the prompt key with VirtualInput
    local key = prompt.KeyboardKeyCode
    if key == Enum.KeyCode.Unknown or key == nil then key = Enum.KeyCode.E end
    -- LoS and distance flexibility
    pcall(function()
        prompt.RequiresLineOfSight = false
        prompt.Enabled = true
    end)
    local hold = prompt.HoldDuration or 0
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    if hold > 0 then wait(hold + 0.05) end
    VirtualInputManager:SendKeyEvent(false, key, false, game)
    return true
end

local function getModelPosition(model)
    if not model or not model.GetPivot then return nil end
    local ok, cf = pcall(function() return model:GetPivot() end)
    if ok and cf then return cf.Position end
    local pp = model.PrimaryPart or model:FindFirstChild("RootPart")
    return pp and pp.Position or nil
end

-- Player helpers for proximity-based placement
local function getPlayerRootPosition()
    local char = Players.LocalPlayer and Players.LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    return hrp.Position
end

local function walkTo(position, timeout)
    local char = Players.LocalPlayer and Players.LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    hum:MoveTo(position)
    local reached = hum.MoveToFinished:Wait(timeout or 5)
    return reached
end

local function tryHatchModel(model)
    -- Double-check ownership before proceeding
    if not playerOwnsInstance(model) then
        return false, "Not owner"
    end
    -- Find a ProximityPrompt named "E" or any prompt on the model
    local prompt
    -- Prefer a prompt on a part named Prompt or with ActionText that implies hatch
    for _, inst in ipairs(model:GetDescendants()) do
        if inst:IsA("ProximityPrompt") then
            prompt = inst
            if inst.ActionText and string.len(inst.ActionText) > 0 then break end
        end
    end
    if not prompt then return false, "No prompt" end
    local pos = getModelPosition(model)
    if not pos then return false, "No position" end
    walkTo(pos, 6)
    -- Ensure we are within MaxActivationDistance by nudging forward if necessary
    local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp and (hrp.Position - pos).Magnitude > (prompt.MaxActivationDistance or 10) - 1 then
        local dir = (pos - hrp.Position).Unit
        hrp.CFrame = CFrame.new(pos - dir * 1.5, pos)
        wait(0.1)
    end
    local ok = pressPromptE(prompt)
    return ok
end

-- Helper function to find and hatch ready eggs (using main script logic)
findAndHatchReadyEggs = function()
    local hatchedCount = 0
    
    -- Use the same logic as the main script
    local owned = collectOwnedEggs()
    if #owned == 0 then
        return false, "No eggs found"
    end
    
    local readyEggs = filterReadyEggs(owned)
    if #readyEggs == 0 then
        return false, "No ready eggs found"
    end
    
    -- Try nearest first
    local me = getPlayerRootPosition()
    table.sort(readyEggs, function(a, b)
        local pa = getModelPosition(a) or Vector3.new()
        local pb = getModelPosition(b) or Vector3.new()
        return (pa - me).Magnitude < (pb - me).Magnitude
    end)
    
    -- Hatch up to 5 eggs per cycle
    for i = 1, math.min(5, #readyEggs) do
        local model = readyEggs[i]
        if tryHatchModel(model) then
            hatchedCount = hatchedCount + 1
            print(string.format("Auto Placement: Hatched ready egg %d/%d", i, #readyEggs))
            wait(0.5) -- Small delay between hatches
        end
    end
    
    if hatchedCount > 0 then
        return true, string.format("Hatched %d ready eggs", hatchedCount)
    else
        return false, "Failed to hatch any eggs"
    end
end

-- Helper function to auto-delete slow pets
local function autoDeleteSlowPets(speedThreshold)
    if speedThreshold <= 0 then
        return 0, "Auto-delete disabled (speed threshold: 0)"
    end
    
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    
    if not LocalPlayer or not LocalPlayer.PlayerGui or not LocalPlayer.PlayerGui.Data then
        return 0, "Player data not found"
    end
    
    local petsFolder = LocalPlayer.PlayerGui.Data:FindFirstChild("Pets")
    if not petsFolder then
        return 0, "Pets folder not found"
    end
    
    local deletedCount = 0
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local PetRE = ReplicatedStorage:FindFirstChild("PetRE")
    
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
                wait(0.1) -- Small delay between deletions
                
                -- Limit to 5 deletions per cycle to avoid spam
                if deletedCount >= 5 then
                            break
                        end
                    end
                end
            end
    
    return deletedCount, string.format("Deleted %d pets below speed %d", deletedCount, speedThreshold)
end

-- Auto placement system
local function runAutoPlacementSystem()
    while questEnabled do
        local tasks = getCurrentTasks()
        local hasHatchTask = false
        
        -- Check if we have an active HatchEgg task
        for _, task in ipairs(tasks) do
            if task.CompleteType == "HatchEgg" then
                local progress = task.Progress or 0
                local target = task.CompleteValue or 1
                local claimed = task.ClaimedCount or 0
                local maxClaimed = task.RepeatCount or 1
                
                if progress < target and claimed < maxClaimed then
                    hasHatchTask = true
                    break
                end
            end
        end
        
        if hasHatchTask then
            -- PRIORITY 1: Check for ready-to-hatch eggs first
            local hatchSuccess, hatchMessage = findAndHatchReadyEggs()
            if hatchSuccess then
                print("Auto Placement: " .. hatchMessage)
                wait(2) -- Wait after hatching before continuing
            else
                -- PRIORITY 2: Check for empty tiles to place new eggs
                local emptyTiles = getEmptyFarmTiles()
                
                if #emptyTiles > 0 then
                    -- We have empty tiles, check for eggs to place
                    local bestEgg = getBestEggForPlacement()
                    
                                            if bestEgg then
                            -- We have an egg, try to place it
                            local ReplicatedStorage = game:GetService("ReplicatedStorage")
                            local CharacterRE = ReplicatedStorage:FindFirstChild("CharacterRE")
                            
                            if CharacterRE then
                                CharacterRE:FireServer("Focus", bestEgg.uid)
                                wait(0.5)
                                
                                -- Click on the first empty tile
                                local VirtualInputManager = game:GetService("VirtualInputManager")
                                local camera = workspace.CurrentCamera
                                local tilePosition = emptyTiles[1].Position
                                local screenPoint = camera:WorldToScreenPoint(tilePosition)
                                
                                VirtualInputManager:SendMouseButtonEvent(screenPoint.X, screenPoint.Y, 0, true, game, 1)
                                wait(0.1)
                                VirtualInputManager:SendMouseButtonEvent(screenPoint.X, screenPoint.Y, 0, false, game, 1)
                                
                                print(string.format("Auto Placement: Placed %s (hatch: %ds) on empty tile", 
                                    bestEgg.type, bestEgg.hatchTime))
                                wait(2) -- Wait before next placement attempt
                            end
                        else
                            -- No eggs available, try to buy one
                            local buySuccess, buyMessage = buyAnyCheapestEgg()
                            if buySuccess then
                                print("Auto Placement: " .. buyMessage)
                                wait(1) -- Wait for purchase to process
                            else
                                wait(5) -- Wait longer if buying failed
                            end
                        end
                    else
                        -- No empty tiles, try auto-deletion if enabled
                        if autoDeleteMinSpeed > 0 then
                            local deletedCount, deleteMessage = autoDeleteSlowPets(autoDeleteMinSpeed)
                            print("Auto Placement: " .. deleteMessage)
                            
                            if deletedCount > 0 then
                                wait(2) -- Wait for deletion to process, then check for empty tiles again
                            else
                                wait(10) -- Wait longer if no pets were deleted
                            end
                        else
                            -- Auto-delete disabled, just wait
                            wait(10)
                        end
                    end
                end
        else
            -- No HatchEgg task active, reset placement target
            if currentPlacementTarget then
                print("Auto Placement: Reset target - no HatchEgg task active")
                currentPlacementTarget = nil
                placementTargetTime = math.huge
                saveCustomAutoQuestSettings()
            end
            wait(5)
        end
    end
end

-- Background BuyMutateEgg monitor
local function runBuyMutateEggMonitor()
    while questEnabled do
        local tasks = getCurrentTasks()
        local hasBuyMutateTask = false
        
        -- Check if we have an active BuyMutateEgg task
        for _, task in ipairs(tasks) do
            if task.CompleteType == "BuyMutateEgg" then
                local progress = task.Progress or 0
                local target = task.CompleteValue or 1
                local claimed = task.ClaimedCount or 0
                local maxClaimed = task.RepeatCount or 1
                
                -- Only monitor if task is not completed
                if progress < target and claimed < maxClaimed then
                    hasBuyMutateTask = true
                    
                                        -- Try to buy mutated egg continuously until found
                    local buySuccess, statusMessage = buyMutatedEgg()
                    
                    if buySuccess then
                        buyMutateEggStatus = "Found mutated egg! Auto-claiming..."
                        buyMutateEggRetries = 0
                        
                        -- Auto-claim the task
                        wait(1) -- Brief delay to ensure egg is processed
                        claimTask(task.Id)
                        buyMutateEggStatus = "Mutated egg claimed!"
                        wait(2) -- Brief celebration pause
                    else
                        buyMutateEggRetries = buyMutateEggRetries + 1
                        buyMutateEggStatus = string.format("Monitoring for mutated eggs (%d attempts)", buyMutateEggRetries)
                        -- No break - keep trying continuously
                    end
                break
                end
            end
        end
        
        if not hasBuyMutateTask then
            buyMutateEggStatus = "No BuyMutateEgg task active"
            wait(5) -- Check less frequently when no task
        else
            wait(2) -- Check every 2 seconds when monitoring
        end
    end
end

-- Auto refresh function (always active when quest enabled)
local function runAutoRefreshTasks()
    while questEnabled do
        -- Update quest status
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
        
        wait(5) -- Refresh every 5 seconds
    end
end

-- Main quest execution function
local function runAutoQuest()
    -- Start all background threads when quest starts
    local claimThread = task.spawn(runAutoClaimReady)
    local refreshThread = task.spawn(runAutoRefreshTasks)
    buyMutateEggThread = task.spawn(runBuyMutateEggMonitor)
    local placementThread = task.spawn(runAutoPlacementSystem)
    
    while questEnabled do
        local ok, err = pcall(executeQuestTasks)
        if not ok then
            warn("Auto Quest error: " .. tostring(err))
            wait(5)
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
    pcall(function() 
        if buyMutateEggThread then
            task.cancel(buyMutateEggThread)
        end
    end)
    pcall(function() 
        if placementThread then
            task.cancel(placementThread)
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
    local QuestTab = Window:Tab({ Title = "📝 | Auto Quest"})
    
    -- Status display
    questStatusParagraph = QuestTab:Paragraph({
        Title = "Quest List:",
        Desc = "Loading quest information...",
        Image = "clipboard-list",
        ImageSize = 22
    })
    
    -- Auto-delete settings
    autoDeleteSlider = QuestTab:Input({
        Title = "Auto Delete Speed Threshold",
        Desc = "Delete pets below this speed when no tiles are empty (0 = disabled)",
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
            -- Auto-save custom settings when changed
            saveCustomAutoQuestSettings()
        end,
    })
    
    -- Main toggle
    questToggle = QuestTab:Toggle({
        Title = "📝 Auto Quest",
        Desc = "Automatically complete daily quest tasks (Auto Claim & Refresh built-in)",
        Value = false,
        Callback = function(state)
            questEnabled = state
            
            waitForSettingsReady(0.2)
            if state and not questThread then
                questThread = task.spawn(function()
                    runAutoQuest()
                    questThread = nil
                end)
                WindUI:Notify({ Title = "📝 Auto Quest", Content = "Started quest automation! (Auto Claim & Refresh enabled) 🎉", Duration = 3 })
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
        Config:Register("targetPlayer", targetPlayerDropdown)
        Config:Register("sendEggTypeFilter", sendEggTypeDropdown)
        Config:Register("sendEggMutationFilter", sendEggMutationDropdown)
        Config:Register("sellPetTypeFilter", sellPetTypeDropdown)
        Config:Register("sellPetMutationFilter", sellPetMutationDropdown)
        Config:Register("autoDeleteSpeed", autoDeleteSlider)
    end
    
    -- Load custom settings on initialization
    loadCustomAutoQuestSettings()
    
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
