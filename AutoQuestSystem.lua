-- Auto Quest System Module
local AutoQuestSystem = {}

-- Task configuration data
local TaskConfig = {
    Task_1 = { Id = "Task_1", TaskPoints = 20, RepeatCount = 1, CompleteType = "HatchEgg", CompleteValue = 5, Desc = "K_DINO_DESC_Task_1", Icon = "rbxassetid://90239318564009" },
    Task_3 = { Id = "Task_3", TaskPoints = 20, RepeatCount = 1, CompleteType = "SellPet", CompleteValue = 5, Desc = "K_DINO_DESC_Task_3", Icon = "rbxassetid://90239318564009" },
    Task_4 = { Id = "Task_4", TaskPoints = 20, RepeatCount = 1, CompleteType = "SendEgg", CompleteValue = 5, Desc = "K_DINO_DESC_Task_4", Icon = "rbxassetid://90239318564009" },
    Task_5 = { Id = "Task_5", TaskPoints = 20, RepeatCount = 1, CompleteType = "BuyMutateEgg", CompleteValue = 1, Desc = "K_DINO_DESC_Task_5", Icon = "rbxassetid://90239318564009" },
    Task_7 = { Id = "Task_7", TaskPoints = 20, RepeatCount = 1, CompleteType = "HatchEgg", CompleteValue = 10, Desc = "K_DINO_DESC_Task_7", Icon = "rbxassetid://90239318564009" },
    Task_8 = { Id = "Task_8", TaskPoints = 15, RepeatCount = 6, CompleteType = "OnlineTime", CompleteValue = 900, Desc = "K_DINO_DESC_Task_8", Icon = "rbxassetid://90239318564009" }
}

-- Quest state
local questState = {
    enabled = false,
    targetPlayer = "Random Player",
    sendEggTNames = {},
    sendEggMutations = {},
    sellPetTNames = {},
    sellPetMutations = {},
    claimAllEnabled = false,
    refreshEnabled = false,
    sessionStats = { sent = 0, sold = 0, hatched = 0, bought = 0, claimed = 0 }
}

-- External dependencies (will be set by Init)
local WindUI, Window, Config, waitForSettingsReady, LocalPlayer, ReplicatedStorage

-- Helper functions
local function getCurrentQuestTasks()
    local tasks = {}
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return tasks end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return tasks end
    
    local dinoEventTaskData = data:FindFirstChild("DinoEventTaskData")
    if not dinoEventTaskData then return tasks end
    
    local tasksFolder = dinoEventTaskData:FindFirstChild("Tasks")
    if not tasksFolder then return tasks end
    
    for i = 1, 3 do
        local taskSlot = tasksFolder:FindFirstChild(tostring(i))
        if taskSlot then
            local taskId = taskSlot:GetAttribute("Id")
            local progress = taskSlot:GetAttribute("Progress") or 0
            local claimedCount = taskSlot:GetAttribute("ClaimedCount") or 0
            
            if taskId and TaskConfig[taskId] then
                local taskInfo = TaskConfig[taskId]
                table.insert(tasks, {
                    slot = i,
                    id = taskId,
                    progress = progress,
                    claimedCount = claimedCount,
                    completeType = taskInfo.CompleteType,
                    completeValue = taskInfo.CompleteValue,
                    repeatCount = taskInfo.RepeatCount,
                    canClaim = progress >= taskInfo.CompleteValue and claimedCount < taskInfo.RepeatCount
                })
            end
        end
    end
    
    return tasks
end

local function getAllPlayers()
    local players = {"Random Player"}
    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(players, player.Name)
        end
    end
    return players
end

local function getAvailableEggTNames()
    local tNames = {}
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return tNames end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return tNames end
    
    local eggContainer = data:FindFirstChild("Egg")
    if not eggContainer then return tNames end
    
    for _, egg in ipairs(eggContainer:GetChildren()) do
        if #egg:GetChildren() == 0 then -- Available egg
            local tName = egg:GetAttribute("T")
            if tName and not table.find(tNames, tName) then
                table.insert(tNames, tName)
            end
        end
    end
    
    table.sort(tNames)
    return tNames
end

local function getAvailablePetTNames()
    local tNames = {}
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return tNames end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return tNames end
    
    local petsContainer = data:FindFirstChild("Pets")
    if not petsContainer then return tNames end
    
    for _, pet in ipairs(petsContainer:GetChildren()) do
        local tName = pet:GetAttribute("T")
        if tName and not table.find(tNames, tName) then
            table.insert(tNames, tName)
        end
    end
    
    table.sort(tNames)
    return tNames
end

local function getAvailableEggMutations()
    local mutations = {}
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return mutations end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return mutations end
    
    local eggContainer = data:FindFirstChild("Egg")
    if not eggContainer then return mutations end
    
    for _, egg in ipairs(eggContainer:GetChildren()) do
        if #egg:GetChildren() == 0 then -- Available egg
            local mutation = egg:GetAttribute("M")
            if mutation and not table.find(mutations, mutation) then
                table.insert(mutations, mutation)
            end
        end
    end
    
    table.sort(mutations)
    return mutations
end

local function getAvailablePetMutations()
    local mutations = {}
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return mutations end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return mutations end
    
    local petsContainer = data:FindFirstChild("Pets")
    if not petsContainer then return mutations end
    
    for _, pet in ipairs(petsContainer:GetChildren()) do
        local mutation = pet:GetAttribute("M")
        if mutation and not table.find(mutations, mutation) then
            table.insert(mutations, mutation)
        end
    end
    
    table.sort(mutations)
    return mutations
end

local function claimQuestReward(taskId)
    local args = {
        {
            event = "claimreward",
            id = taskId
        }
    }
    
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("DinoEventRE"):FireServer(unpack(args))
    end)
    
    if success then
        questState.sessionStats.claimed = questState.sessionStats.claimed + 1
        WindUI:Notify({ 
            Title = "📝 Quest Claimed", 
            Content = "Claimed reward for " .. taskId .. "! 🎉", 
            Duration = 3 
        })
    end
    
    return success
end

local function sendEggToPlayer(eggUID, targetPlayerName)
    if targetPlayerName == "Random Player" then
        local players = game:GetService("Players"):GetPlayers()
        local validPlayers = {}
        for _, player in ipairs(players) do
            if player ~= LocalPlayer then
                table.insert(validPlayers, player)
            end
        end
        
        if #validPlayers == 0 then
            return false, "No valid players found"
        end
        
        local randomPlayer = validPlayers[math.random(1, #validPlayers)]
        targetPlayerName = randomPlayer.Name
    end
    
    local targetPlayer = game:GetService("Players"):FindFirstChild(targetPlayerName)
    if not targetPlayer then
        return false, "Target player not found"
    end
    
    -- Focus egg first
    local focusSuccess = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer("Focus", eggUID)
    end)
    
    if not focusSuccess then
        return false, "Failed to focus egg"
    end
    
    task.wait(0.1)
    
    -- Send egg
    local sendSuccess = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(targetPlayer)
    end)
    
    if sendSuccess then
        questState.sessionStats.sent = questState.sessionStats.sent + 1
        return true, "Sent egg to " .. targetPlayerName
    else
        return false, "Failed to send egg"
    end
end

local function sellPet(petUID)
    local args = {
        "Sell",
        petUID
    }
    
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("PetRE"):FireServer(unpack(args))
    end)
    
    if success then
        questState.sessionStats.sold = questState.sessionStats.sold + 1
        return true, "Sold pet " .. petUID
    else
        return false, "Failed to sell pet"
    end
end

local function itemMatchesFilters(item, tNames, mutations)
    -- Check T name filter
    if #tNames > 0 then
        local itemT = item:GetAttribute("T")
        if not itemT or not table.find(tNames, itemT) then
            return false
        end
    end
    
    -- Check mutation filter
    if #mutations > 0 then
        local itemM = item:GetAttribute("M")
        if not itemM or not table.find(mutations, itemM) then
            return false
        end
    end
    
    return true
end

local function getAvailableItemsForAction(actionType, tNames, mutations)
    local items = {}
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return items end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return items end
    
    local container = data:FindFirstChild(actionType == "SendEgg" and "Egg" or "Pets")
    if not container then return items end
    
    for _, item in ipairs(container:GetChildren()) do
        if actionType == "SendEgg" and #item:GetChildren() == 0 then -- Available egg
            if itemMatchesFilters(item, tNames, mutations) then
                table.insert(items, item.Name)
            end
        elseif actionType == "SellPet" then
            -- Skip locked pets
            if item:GetAttribute("LK") == 1 then
                continue
            end
            if itemMatchesFilters(item, tNames, mutations) then
                table.insert(items, item.Name)
            end
        end
    end
    
    return items
end

-- Main quest execution loop
local function runAutoQuest()
    while questState.enabled do
        local currentTasks = getCurrentQuestTasks()
        
        if #currentTasks == 0 then
            task.wait(5)
            continue
        end
        
        -- Sort tasks by priority
        table.sort(currentTasks, function(a, b)
            local priorityOrder = {
                BuyMutateEgg = 1,
                HatchEgg = 2,
                SendEgg = 3,
                SellPet = 4,
                OnlineTime = 5
            }
            return (priorityOrder[a.completeType] or 999) < (priorityOrder[b.completeType] or 999)
        end)
        
        -- Execute tasks simultaneously
        for _, task in ipairs(currentTasks) do
            if not questState.enabled then break end
            
            -- Check if task is already completed
            if task.canClaim then
                if questState.claimAllEnabled then
                    claimQuestReward(task.id)
                end
                continue
            end
            
            -- Execute task based on type
            if task.completeType == "SendEgg" then
                local availableEggs = getAvailableItemsForAction("SendEgg", questState.sendEggTNames, questState.sendEggMutations)
                
                if #availableEggs == 0 then
                    -- Show dialog asking user to continue
                    local shouldContinue = false
                    Window:Dialog({
                        Title = "⚠️ No Matching Eggs",
                        Content = "No eggs match your selected filters. Continue with all eggs?",
                        Icon = "alert-triangle",
                        Buttons = {
                            {
                                Title = "❌ Cancel",
                                Variant = "Secondary",
                                Callback = function() shouldContinue = false end
                            },
                            {
                                Title = "✅ Continue",
                                Variant = "Primary",
                                Callback = function() shouldContinue = true end
                            }
                        }
                    })
                    
                    if not shouldContinue then
                        continue
                    end
                    
                    -- Get all available eggs
                    availableEggs = getAvailableItemsForAction("SendEgg", {}, {})
                end
                
                local sentCount = 0
                for _, eggUID in ipairs(availableEggs) do
                    if sentCount >= task.completeValue then break end
                    if questState.sessionStats.sent >= 5 then break end -- Safety limit
                    
                    local success, message = sendEggToPlayer(eggUID, questState.targetPlayer)
                    if success then
                        sentCount = sentCount + 1
                        task.wait(0.5) -- Rate limiting
                    end
                end
                
            elseif task.completeType == "SellPet" then
                local availablePets = getAvailableItemsForAction("SellPet", questState.sellPetTNames, questState.sellPetMutations)
                
                if #availablePets == 0 then
                    -- Show dialog asking user to continue
                    local shouldContinue = false
                    Window:Dialog({
                        Title = "⚠️ No Matching Pets",
                        Content = "No pets match your selected filters. Continue with all pets?",
                        Icon = "alert-triangle",
                        Buttons = {
                            {
                                Title = "❌ Cancel",
                                Variant = "Secondary",
                                Callback = function() shouldContinue = false end
                            },
                            {
                                Title = "✅ Continue",
                                Variant = "Primary",
                                Callback = function() shouldContinue = true end
                            }
                        }
                    })
                    
                    if not shouldContinue then
                        continue
                    end
                    
                    -- Get all available pets
                    availablePets = getAvailableItemsForAction("SellPet", {}, {})
                end
                
                local soldCount = 0
                for _, petUID in ipairs(availablePets) do
                    if soldCount >= task.completeValue then break end
                    if questState.sessionStats.sold >= 5 then break end -- Safety limit
                    
                    local success, message = sellPet(petUID)
                    if success then
                        soldCount = soldCount + 1
                        task.wait(0.5) -- Rate limiting
                    end
                end
                
            elseif task.completeType == "OnlineTime" then
                -- Just wait and claim when ready
                while task.progress < task.completeValue do
                    task.wait(1)
                    local currentTasks = getCurrentQuestTasks()
                    for _, currentTask in ipairs(currentTasks) do
                        if currentTask.id == task.id then
                            task.progress = currentTask.progress
                            break
                        end
                    end
                end
            end
            
            -- Check if task is now complete
            local updatedTasks = getCurrentQuestTasks()
            for _, updatedTask in ipairs(updatedTasks) do
                if updatedTask.id == task.id and updatedTask.canClaim then
                    claimQuestReward(task.id)
                    break
                end
            end
        end
        
        task.wait(2) -- Main loop delay
    end
end

-- Public API
function AutoQuestSystem.Init(dependencies)
    WindUI = dependencies.WindUI
    Window = dependencies.Window
    Config = dependencies.Config
    waitForSettingsReady = dependencies.waitForSettingsReady
    LocalPlayer = dependencies.LocalPlayer
    ReplicatedStorage = dependencies.ReplicatedStorage
    
    return {
        getCurrentQuestTasks = getCurrentQuestTasks,
        getAllPlayers = getAllPlayers,
        getAvailableEggTNames = getAvailableEggTNames,
        getAvailablePetTNames = getAvailablePetTNames,
        getAvailableEggMutations = getAvailableEggMutations,
        getAvailablePetMutations = getAvailablePetMutations,
        claimQuestReward = claimQuestReward,
        runAutoQuest = runAutoQuest,
        questState = questState
    }
end

return AutoQuestSystem
