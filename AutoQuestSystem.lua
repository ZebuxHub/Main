-- Auto Quest System for Build A Zoo
-- Handles daily quests: HatchEgg, SellPet, SendEgg, BuyMutateEgg, OnlineTime

local AutoQuestSystem = {}

-- Task configuration from your decompiled data
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

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- State variables
local autoQuestEnabled = false
local autoQuestThread = nil
local selectedTargetPlayer = nil
local selectedEggTypes = {}
local selectedEggMutations = {}
local selectedPetTypes = {}
local selectedPetMutations = {}
local claimAllReadyEnabled = false
local refreshTasksEnabled = false

-- UI elements (will be set by main script)
local questTab = nil
local questToggle = nil
local targetPlayerDropdown = nil
local sendEggTypesDropdown = nil
local sendEggMutationsDropdown = nil
local sellPetTypesDropdown = nil
local sellPetMutationsDropdown = nil
local claimAllToggle = nil
local refreshTasksToggle = nil
local statusParagraph = nil

-- Task execution state
local activeTasks = {}
local taskProgress = {}
local originalAutoStates = {}

-- Helper functions
local function getPlayerGui()
    return LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
end

local function getDataFolder()
    local playerGui = getPlayerGui()
    return playerGui and playerGui:FindFirstChild("Data")
end

local function getDinoEventTaskData()
    local data = getDataFolder()
    return data and data:FindFirstChild("DinoEventTaskData")
end

local function getTasksFolder()
    local dinoEventData = getDinoEventTaskData()
    return dinoEventData and dinoEventData:FindFirstChild("Tasks")
end

local function getEggContainer()
    local data = getDataFolder()
    return data and data:FindFirstChild("Egg")
end

local function getPetsContainer()
    local data = getDataFolder()
    return data and data:FindFirstChild("Pets")
end

-- Get all available players (excluding self)
local function getAvailablePlayers()
    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(players, player.Name)
        end
    end
    table.sort(players)
    return players
end

-- Get all egg types from inventory
local function getAvailableEggTypes()
    local eggTypes = {}
    local eggContainer = getEggContainer()
    if eggContainer then
        for _, egg in ipairs(eggContainer:GetChildren()) do
            if #egg:GetChildren() == 0 then -- Available egg
                local eggType = egg:GetAttribute("T")
                if eggType and not table.find(eggTypes, eggType) then
                    table.insert(eggTypes, eggType)
                end
            end
        end
    end
    table.sort(eggTypes)
    return eggTypes
end

-- Get all egg mutations from inventory
local function getAvailableEggMutations()
    local mutations = {}
    local eggContainer = getEggContainer()
    if eggContainer then
        for _, egg in ipairs(eggContainer:GetChildren()) do
            if #egg:GetChildren() == 0 then -- Available egg
                local mutation = egg:GetAttribute("M")
                if mutation and not table.find(mutations, mutation) then
                    table.insert(mutations, mutation)
                end
            end
        end
    end
    table.sort(mutations)
    return mutations
end

-- Get all pet types from inventory
local function getAvailablePetTypes()
    local petTypes = {}
    local petsContainer = getPetsContainer()
    if petsContainer then
        for _, pet in ipairs(petsContainer:GetChildren()) do
            local petType = pet:GetAttribute("T")
            if petType and not table.find(petTypes, petType) then
                table.insert(petTypes, petType)
            end
        end
    end
    table.sort(petTypes)
    return petTypes
end

-- Get all pet mutations from inventory
local function getAvailablePetMutations()
    local mutations = {}
    local petsContainer = getPetsContainer()
    if petsContainer then
        for _, pet in ipairs(petsContainer:GetChildren()) do
            local mutation = pet:GetAttribute("M")
            if mutation and not table.find(mutations, mutation) then
                table.insert(mutations, mutation)
            end
        end
    end
    table.sort(mutations)
    return mutations
end

-- Read current tasks from game
local function readCurrentTasks()
    local tasks = {}
    local tasksFolder = getTasksFolder()
    if not tasksFolder then return tasks end
    
    for i = 1, 3 do
        local taskSlot = tasksFolder:FindFirstChild(tostring(i))
        if taskSlot then
            local taskId = taskSlot:GetAttribute("Id")
            local progress = taskSlot:GetAttribute("Progress") or 0
            local claimedCount = taskSlot:GetAttribute("ClaimedCount") or 0
            
            if taskId and TaskConfig[taskId] then
                local taskInfo = TaskConfig[taskId]
                tasks[i] = {
                    slot = i,
                    id = taskId,
                    type = taskInfo.CompleteType,
                    target = taskInfo.CompleteValue,
                    progress = progress,
                    claimedCount = claimedCount,
                    maxClaims = taskInfo.RepeatCount,
                    config = taskInfo
                }
            end
        end
    end
    
    return tasks
end

-- Update status display
local function updateStatus()
    if not statusParagraph then return end
    
    local tasks = readCurrentTasks()
    local statusText = "📋 Current Tasks:\n"
    
    for i, task in ipairs(tasks) do
        if task then
            local progressPercent = math.floor((task.progress / task.target) * 100)
            local statusIcon = task.progress >= task.target and "✅" or "⏳"
            local claimStatus = task.claimedCount >= task.maxClaims and " (Claimed)" or ""
            
            statusText = statusText .. string.format("%s Task %d: %s (%s)\n", 
                statusIcon, i, task.type, task.id)
            statusText = statusText .. string.format("   Progress: %d/%d (%d%%)%s\n",
                task.progress, task.target, progressPercent, claimStatus)
        else
            statusText = statusText .. string.format("❌ Task %d: No task\n", i)
        end
    end
    
    statusText = statusText .. "\n🎯 Target Player: " .. (selectedTargetPlayer or "None")
    statusText = statusText .. "\n🥚 Send Egg Types: " .. (#selectedEggTypes > 0 and table.concat(selectedEggTypes, ", ") or "All")
    statusText = statusText .. "\n🧬 Send Egg Mutations: " .. (#selectedEggMutations > 0 and table.concat(selectedEggMutations, ", ") or "All")
    statusText = statusText .. "\n🐾 Sell Pet Types: " .. (#selectedPetTypes > 0 and table.concat(selectedPetTypes, ", ") or "All")
    statusText = statusText .. "\n🧬 Sell Pet Mutations: " .. (#selectedPetMutations > 0 and table.concat(selectedPetMutations, ", ") or "All")
    
    statusParagraph:SetDesc(statusText)
end

-- Claim task reward
local function claimTaskReward(taskId)
    local args = {
        {
            event = "claimreward",
            id = taskId
        }
    }
    
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("DinoEventRE"):FireServer(unpack(args))
    end)
    
    return success
end

-- Focus egg/pet for gifting
local function focusItem(itemUID)
    local args = {
        "Focus",
        itemUID
    }
    
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    return success
end

-- Gift egg to player
local function giftEgg(eggUID, targetPlayer)
    if not targetPlayer then return false end
    
    -- Focus the egg first
    if not focusItem(eggUID) then
        return false
    end
    
    task.wait(0.1)
    
    -- Gift the egg
    local args = {targetPlayer}
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(unpack(args))
    end)
    
    return success
end

-- Sell pet
local function sellPet(petUID)
    local args = {
        "Sell",
        petUID
    }
    
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("PetRE"):FireServer(unpack(args))
    end)
    
    return success
end

-- Buy egg (for BuyMutateEgg task)
local function buyEgg(eggUID)
    local args = {
        "BuyEgg",
        eggUID
    }
    
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    return success
end

-- Focus egg (for BuyMutateEgg task)
local function focusEgg(eggUID)
    local args = {
        "Focus",
        eggUID
    }
    
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    return success
end

-- Check if egg has mutation
local function hasEggMutation(eggUID)
    local eggContainer = getEggContainer()
    if not eggContainer then return false end
    
    local egg = eggContainer:FindFirstChild(eggUID)
    if not egg then return false end
    
    local mutation = egg:GetAttribute("M")
    return mutation and mutation ~= ""
end

-- Get available eggs for sending (filtered by type and mutation)
local function getAvailableEggsForSending()
    local eggs = {}
    local eggContainer = getEggContainer()
    if not eggContainer then return eggs end
    
    for _, egg in ipairs(eggContainer:GetChildren()) do
        if #egg:GetChildren() == 0 then -- Available egg
            local eggType = egg:GetAttribute("T")
            local mutation = egg:GetAttribute("M")
            local isLocked = egg:GetAttribute("LK") == 1
            
            if not isLocked then
                local shouldInclude = true
                
                -- Check type filter
                if #selectedEggTypes > 0 then
                    if not table.find(selectedEggTypes, eggType) then
                        shouldInclude = false
                    end
                end
                
                -- Check mutation filter
                if shouldInclude and #selectedEggMutations > 0 then
                    if not mutation or not table.find(selectedEggMutations, mutation) then
                        shouldInclude = false
                    end
                end
                
                if shouldInclude then
                    table.insert(eggs, {
                        uid = egg.Name,
                        type = eggType,
                        mutation = mutation
                    })
                end
            end
        end
    end
    
    return eggs
end

-- Get available pets for selling (filtered by type and mutation)
local function getAvailablePetsForSelling()
    local pets = {}
    local petsContainer = getPetsContainer()
    if not petsContainer then return pets end
    
    for _, pet in ipairs(petsContainer:GetChildren()) do
        local petType = pet:GetAttribute("T")
        local mutation = pet:GetAttribute("M")
        local isLocked = pet:GetAttribute("LK") == 1
        
        if not isLocked then
            local shouldInclude = true
            
            -- Check type filter
            if #selectedPetTypes > 0 then
                if not table.find(selectedPetTypes, petType) then
                    shouldInclude = false
                end
            end
            
            -- Check mutation filter
            if shouldInclude and #selectedPetMutations > 0 then
                if not mutation or not table.find(selectedPetMutations, mutation) then
                    shouldInclude = false
                end
            end
            
            if shouldInclude then
                table.insert(pets, {
                    uid = pet.Name,
                    type = petType,
                    mutation = mutation
                })
            end
        end
    end
    
    return pets
end

-- Execute HatchEgg task
local function executeHatchEggTask(task)
    -- Store original auto states
    originalAutoStates.autoBuy = _G.autoBuyEnabled
    originalAutoStates.autoPlace = _G.autoPlaceEnabled
    originalAutoStates.autoHatch = _G.autoHatchEnabled
    
    -- Enable required automations
    if _G.autoBuyToggle then _G.autoBuyToggle:SetValue(true) end
    if _G.autoPlaceToggle then _G.autoPlaceToggle:SetValue(true) end
    if _G.autoHatchToggle then _G.autoHatchToggle:SetValue(true) end
    
    -- Wait for task completion
    while autoQuestEnabled do
        local currentTasks = readCurrentTasks()
        local currentTask = currentTasks[task.slot]
        
        if not currentTask or currentTask.id ~= task.id then
            break -- Task changed or completed
        end
        
        if currentTask.progress >= currentTask.target then
            -- Task completed, claim reward
            if claimTaskReward(task.id) then
                break
            end
        end
        
        task.wait(1)
    end
    
    -- Restore original states
    if _G.autoBuyToggle then _G.autoBuyToggle:SetValue(originalAutoStates.autoBuy) end
    if _G.autoPlaceToggle then _G.autoPlaceToggle:SetValue(originalAutoStates.autoPlace) end
    if _G.autoHatchToggle then _G.autoHatchToggle:SetValue(originalAutoStates.autoHatch) end
end

-- Execute SellPet task
local function executeSellPetTask(task)
    local needed = task.target - task.progress
    if needed <= 0 then return end
    
    local pets = getAvailablePetsForSelling()
    if #pets == 0 then
        -- Show dialog asking user to continue
        if WindUI then
            WindUI:Dialog({
                Title = "⚠️ No Pets Available",
                Content = "No pets match your selected filters. Continue anyway?",
                Icon = "alert-triangle",
                Buttons = {
                    {
                        Title = "❌ Cancel",
                        Variant = "Secondary",
                        Callback = function() end
                    },
                    {
                        Title = "✅ Continue",
                        Variant = "Primary",
                        Callback = function()
                            -- Continue with all pets (ignore filters)
                            local petsContainer = getPetsContainer()
                            local allPets = {}
                            if petsContainer then
                                for _, pet in ipairs(petsContainer:GetChildren()) do
                                    local isLocked = pet:GetAttribute("LK") == 1
                                    if not isLocked then
                                        table.insert(allPets, {
                                            uid = pet.Name,
                                            type = pet:GetAttribute("T"),
                                            mutation = pet:GetAttribute("M")
                                        })
                                    end
                                end
                            end
                            for i = 1, math.min(needed, #allPets) do
                                if sellPet(allPets[i].uid) then
                                    task.wait(0.3)
                                end
                            end
                        end
                    }
                }
            })
        end
        return
    end
    
    -- Sell pets
    for i = 1, math.min(needed, #pets) do
        if not autoQuestEnabled then break end
        if sellPet(pets[i].uid) then
            task.wait(0.3)
        end
    end
end

-- Execute SendEgg task
local function executeSendEggTask(task)
    local needed = task.target - task.progress
    if needed <= 0 then return end
    
    if not selectedTargetPlayer or selectedTargetPlayer == "Random" then
        -- Pick random player
        local players = getAvailablePlayers()
        if #players == 0 then
            if WindUI then
                WindUI:Notify({
                    Title = "⚠️ No Players",
                    Content = "No other players found for gifting",
                    Duration = 3
                })
            end
            return
        end
        selectedTargetPlayer = Players:FindFirstChild(players[math.random(1, #players)])
    else
        selectedTargetPlayer = Players:FindFirstChild(selectedTargetPlayer)
    end
    
    if not selectedTargetPlayer then
        if WindUI then
            WindUI:Notify({
                Title = "⚠️ Player Not Found",
                Content = "Target player is no longer in the game",
                Duration = 3
            })
        end
        return
    end
    
    local eggs = getAvailableEggsForSending()
    if #eggs == 0 then
        -- Show dialog asking user to continue
        if WindUI then
            WindUI:Dialog({
                Title = "⚠️ No Eggs Available",
                Content = "No eggs match your selected filters. Continue anyway?",
                Icon = "alert-triangle",
                Buttons = {
                    {
                        Title = "❌ Cancel",
                        Variant = "Secondary",
                        Callback = function() end
                    },
                    {
                        Title = "✅ Continue",
                        Variant = "Primary",
                        Callback = function() 
                            -- Continue with all eggs (ignore filters)
                            local eggContainer = getEggContainer()
                            local allEggs = {}
                            if eggContainer then
                                for _, egg in ipairs(eggContainer:GetChildren()) do
                                    if #egg:GetChildren() == 0 then -- Available egg
                                        local isLocked = egg:GetAttribute("LK") == 1
                                        if not isLocked then
                                            table.insert(allEggs, {
                                                uid = egg.Name,
                                                type = egg:GetAttribute("T"),
                                                mutation = egg:GetAttribute("M")
                                            })
                                        end
                                    end
                                end
                            end
                            for i = 1, math.min(needed, #allEggs) do
                                if giftEgg(allEggs[i].uid, selectedTargetPlayer) then
                                    task.wait(0.3)
                                end
                            end
                        end
                    }
                }
            })
        end
        return
    end
    
    -- Gift eggs
    for i = 1, math.min(needed, #eggs) do
        if not autoQuestEnabled then break end
        if giftEgg(eggs[i].uid, selectedTargetPlayer) then
            task.wait(0.3)
        end
    end
end

-- Execute BuyMutateEgg task
local function executeBuyMutateEggTask(task)
    local needed = task.target - task.progress
    if needed <= 0 then return end
    
    -- Store original auto states
    originalAutoStates.autoBuy = _G.autoBuyEnabled
    
    -- Enable auto buy for mutated eggs only
    if _G.autoBuyToggle then _G.autoBuyToggle:SetValue(true) end
    
    -- Set a flag to indicate we're in BuyMutateEgg mode
    _G.buyMutateEggMode = true
    
    -- Wait for task completion
    while autoQuestEnabled do
        local currentTasks = readCurrentTasks()
        local currentTask = currentTasks[task.slot]
        
        if not currentTask or currentTask.id ~= task.id then
            break -- Task changed or completed
        end
        
        if currentTask.progress >= currentTask.target then
            -- Task completed, claim reward
            if claimTaskReward(task.id) then
                break
            end
        end
        
        task.wait(1)
    end
    
    -- Restore original state
    _G.buyMutateEggMode = false
    if _G.autoBuyToggle then _G.autoBuyToggle:SetValue(originalAutoStates.autoBuy) end
end

-- Execute OnlineTime task
local function executeOnlineTimeTask(task)
    -- This task just requires being online, no actions needed
    -- Just claim when ready
    while autoQuestEnabled do
        local currentTasks = readCurrentTasks()
        local currentTask = currentTasks[task.slot]
        
        if not currentTask or currentTask.id ~= task.id then
            break -- Task changed or completed
        end
        
        if currentTask.progress >= currentTask.target and currentTask.claimedCount < currentTask.maxClaims then
            -- Ready to claim
            if claimTaskReward(task.id) then
                task.wait(1) -- Wait before checking next claim
            end
        end
        
        task.wait(5) -- Check every 5 seconds
    end
end

-- Main quest execution loop
local function runAutoQuest()
    while autoQuestEnabled do
        local tasks = readCurrentTasks()
        local activeTask = nil
        
        -- Find the highest priority task that needs work
        for i = 1, 3 do
            local task = tasks[i]
            if task and task.progress < task.target and task.claimedCount < task.maxClaims then
                activeTask = task
                break
            end
        end
        
        if not activeTask then
            -- All tasks completed or claimed
            task.wait(5)
            updateStatus()
            continue
        end
        
        -- Execute task based on type
        if activeTask.type == "HatchEgg" then
            executeHatchEggTask(activeTask)
        elseif activeTask.type == "SellPet" then
            executeSellPetTask(activeTask)
        elseif activeTask.type == "SendEgg" then
            executeSendEggTask(activeTask)
        elseif activeTask.type == "BuyMutateEgg" then
            executeBuyMutateEggTask(activeTask)
        elseif activeTask.type == "OnlineTime" then
            executeOnlineTimeTask(activeTask)
        end
        
        updateStatus()
        task.wait(1)
    end
end

-- Claim all ready tasks
local function claimAllReadyTasks()
    local tasks = readCurrentTasks()
    local claimedCount = 0
    
    for _, task in ipairs(tasks) do
        if task and task.progress >= task.target and task.claimedCount < task.maxClaims then
            if claimTaskReward(task.id) then
                claimedCount = claimedCount + 1
                task.wait(0.5)
            end
        end
    end
    
    if claimedCount > 0 and WindUI then
        WindUI:Notify({
            Title = "🎉 Tasks Claimed",
            Content = string.format("Claimed %d task rewards!", claimedCount),
            Duration = 3
        })
    end
    
    updateStatus()
end

-- Refresh tasks
local function refreshTasks()
    updateStatus()
    if WindUI then
        WindUI:Notify({
            Title = "🔄 Tasks Refreshed",
            Content = "Task status updated",
            Duration = 2
        })
    end
end

-- Initialize the Auto Quest system
function AutoQuestSystem.Init(dependencies)
    local WindUI = dependencies.WindUI
    local Window = dependencies.Window
    local Config = dependencies.Config
    local waitForSettingsReady = dependencies.waitForSettingsReady
    
    -- Create Auto Quest tab
    questTab = Window:Tab({ Title = "📝 | Auto Quest", Icon = "list-checks" })
    
    -- Status display
    statusParagraph = questTab:Paragraph({
        Title = "📋 Quest Status",
        Desc = "Loading quest status...",
        Image = "activity",
        ImageSize = 22
    })
    
    -- Main toggle
    questToggle = questTab:Toggle({
        Title = "📝 Auto Quest",
        Desc = "Automatically complete daily quests and claim rewards",
        Value = false,
        Callback = function(state)
            autoQuestEnabled = state
            
            waitForSettingsReady(0.2)
            if state and not autoQuestThread then
                autoQuestThread = task.spawn(function()
                    runAutoQuest()
                    autoQuestThread = nil
                end)
                if WindUI then
                    WindUI:Notify({
                        Title = "📝 Auto Quest",
                        Content = "Started completing quests! 🎉",
                        Duration = 3
                    })
                end
            elseif (not state) and autoQuestThread then
                if WindUI then
                    WindUI:Notify({
                        Title = "📝 Auto Quest",
                        Content = "Stopped",
                        Duration = 3
                    })
                end
            end
        end
    })
    
    -- Target player dropdown
    local function updateTargetPlayerDropdown()
        local players = getAvailablePlayers()
        table.insert(players, 1, "Random")
        
        if targetPlayerDropdown then
            targetPlayerDropdown:Refresh(players)
        else
            targetPlayerDropdown = questTab:Dropdown({
                Title = "🎯 Target Player",
                Desc = "Choose who to send eggs to (Random picks any player)",
                Values = players,
                Value = "Random",
                Callback = function(selection)
                    selectedTargetPlayer = selection
                    updateStatus()
                end
            })
        end
    end
    
    -- Send Egg Types dropdown
    local function updateSendEggTypesDropdown()
        local eggTypes = getAvailableEggTypes()
        
        if sendEggTypesDropdown then
            sendEggTypesDropdown:Refresh(eggTypes)
        else
            sendEggTypesDropdown = questTab:Dropdown({
                Title = "🥚 Send Egg Types",
                Desc = "Choose which egg types to send (empty = all types)",
                Values = eggTypes,
                Value = {},
                Multi = true,
                AllowNone = true,
                Callback = function(selection)
                    selectedEggTypes = selection
                    updateStatus()
                end
            })
        end
    end
    
    -- Send Egg Mutations dropdown
    local function updateSendEggMutationsDropdown()
        local mutations = getAvailableEggMutations()
        
        if sendEggMutationsDropdown then
            sendEggMutationsDropdown:Refresh(mutations)
        else
            sendEggMutationsDropdown = questTab:Dropdown({
                Title = "🧬 Send Egg Mutations",
                Desc = "Choose which egg mutations to send (empty = all mutations)",
                Values = mutations,
                Value = {},
                Multi = true,
                AllowNone = true,
                Callback = function(selection)
                    selectedEggMutations = selection
                    updateStatus()
                end
            })
        end
    end
    
    -- Sell Pet Types dropdown
    local function updateSellPetTypesDropdown()
        local petTypes = getAvailablePetTypes()
        
        if sellPetTypesDropdown then
            sellPetTypesDropdown:Refresh(petTypes)
        else
            sellPetTypesDropdown = questTab:Dropdown({
                Title = "🐾 Sell Pet Types",
                Desc = "Choose which pet types to sell (empty = all types)",
                Values = petTypes,
                Value = {},
                Multi = true,
                AllowNone = true,
                Callback = function(selection)
                    selectedPetTypes = selection
                    updateStatus()
                end
            })
        end
    end
    
    -- Sell Pet Mutations dropdown
    local function updateSellPetMutationsDropdown()
        local mutations = getAvailablePetMutations()
        
        if sellPetMutationsDropdown then
            sellPetMutationsDropdown:Refresh(mutations)
        else
            sellPetMutationsDropdown = questTab:Dropdown({
                Title = "🧬 Sell Pet Mutations",
                Desc = "Choose which pet mutations to sell (empty = all mutations)",
                Values = mutations,
                Value = {},
                Multi = true,
                AllowNone = true,
                Callback = function(selection)
                    selectedPetMutations = selection
                    updateStatus()
                end
            })
        end
    end
    
    -- Claim All Ready toggle
    claimAllToggle = questTab:Toggle({
        Title = "🎉 Auto Claim Ready",
        Desc = "Automatically claim all completed tasks",
        Value = false,
        Callback = function(state)
            claimAllReadyEnabled = state
            if state then
                claimAllReadyEnabled = true
                task.spawn(function()
                    while claimAllReadyEnabled do
                        claimAllReadyTasks()
                        task.wait(5) -- Check every 5 seconds
                    end
                end)
            else
                claimAllReadyEnabled = false
            end
        end
    })
    
    -- Refresh Tasks toggle
    refreshTasksToggle = questTab:Toggle({
        Title = "🔄 Auto Refresh Tasks",
        Desc = "Automatically refresh task status",
        Value = false,
        Callback = function(state)
            refreshTasksEnabled = state
            if state then
                task.spawn(function()
                    while refreshTasksEnabled do
                        refreshTasks()
                        task.wait(10) -- Refresh every 10 seconds
                    end
                end)
            end
        end
    })
    
    -- Manual buttons
    questTab:Button({
        Title = "🎉 Claim All Ready Now",
        Desc = "Manually claim all completed tasks",
        Callback = function()
            claimAllReadyTasks()
        end
    })
    
    questTab:Button({
        Title = "🔄 Refresh Tasks Now",
        Desc = "Manually refresh task status",
        Callback = function()
            refreshTasks()
        end
    })
    
    questTab:Button({
        Title = "🔄 Update Dropdowns",
        Desc = "Refresh all dropdown options",
        Callback = function()
            updateTargetPlayerDropdown()
            updateSendEggTypesDropdown()
            updateSendEggMutationsDropdown()
            updateSellPetTypesDropdown()
            updateSellPetMutationsDropdown()
            updateStatus()
        end
    })
    
         -- Register with config (only register elements that exist)
     if Config then
         Config:Register("autoQuestEnabled", questToggle)
         Config:Register("claimAllReadyEnabled", claimAllToggle)
         Config:Register("refreshTasksEnabled", refreshTasksToggle)
         
         -- Register dropdowns after they're created
         task.spawn(function()
             task.wait(1) -- Wait for dropdowns to be created
             if targetPlayerDropdown then Config:Register("targetPlayerDropdown", targetPlayerDropdown) end
             if sendEggTypesDropdown then Config:Register("sendEggTypesDropdown", sendEggTypesDropdown) end
             if sendEggMutationsDropdown then Config:Register("sendEggMutationsDropdown", sendEggMutationsDropdown) end
             if sellPetTypesDropdown then Config:Register("sellPetTypesDropdown", sellPetTypesDropdown) end
             if sellPetMutationsDropdown then Config:Register("sellPetMutationsDropdown", sellPetMutationsDropdown) end
         end)
     end
    
    -- Initialize dropdowns
    task.spawn(function()
        task.wait(2) -- Wait for game to load
        updateTargetPlayerDropdown()
        updateSendEggTypesDropdown()
        updateSendEggMutationsDropdown()
        updateSellPetTypesDropdown()
        updateSellPetMutationsDropdown()
        updateStatus()
    end)
    
    return {
        questToggle = questToggle,
        updateStatus = updateStatus,
        readCurrentTasks = readCurrentTasks,
        claimAllReadyTasks = claimAllReadyTasks,
        refreshTasks = refreshTasks
    }
end

return AutoQuestSystem
