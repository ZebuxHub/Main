-- AutoQuestSystem.lua - Auto Quest System for Build A Zoo
-- Author: Zebux
-- Version: 1.0

local AutoQuestSystem = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Task Configuration - Map Task IDs to Complete Types for easier reading
local TaskConfig = {
    Task_1 = { Id = "Task_1", TaskPoints = 20, RepeatCount = 1, CompleteType = "HatchEgg", CompleteValue = 5, Desc = "Hatch 5 Eggs", Icon = "rbxassetid://90239318564009" },
    Task_3 = { Id = "Task_3", TaskPoints = 20, RepeatCount = 1, CompleteType = "SellPet", CompleteValue = 5, Desc = "Sell 5 Pets", Icon = "rbxassetid://90239318564009" },
    Task_4 = { Id = "Task_4", TaskPoints = 20, RepeatCount = 1, CompleteType = "SendEgg", CompleteValue = 5, Desc = "Send 5 Eggs", Icon = "rbxassetid://90239318564009" },
    Task_5 = { Id = "Task_5", TaskPoints = 20, RepeatCount = 1, CompleteType = "BuyMutateEgg", CompleteValue = 1, Desc = "Buy 1 Mutate Egg", Icon = "rbxassetid://90239318564009" },
    Task_7 = { Id = "Task_7", TaskPoints = 20, RepeatCount = 1, CompleteType = "HatchEgg", CompleteValue = 10, Desc = "Hatch 10 Eggs", Icon = "rbxassetid://90239318564009" },
    Task_8 = { Id = "Task_8", TaskPoints = 15, RepeatCount = 6, CompleteType = "OnlineTime", CompleteValue = 900, Desc = "Online for 15 minutes", Icon = "rbxassetid://90239318564009" }
}

-- Quest State
local autoQuestEnabled = false
local autoQuestThread = nil
local currentTasks = {}
local selectedTargetPlayer = "Random"
local selectedEggTypes = {}
local selectedEggMutations = {}
local selectedPetTypes = {}
local selectedPetMutations = {}
local autoClaimEnabled = false
local autoRefreshEnabled = false

-- Quest Functions
local function getCurrentTasks()
    local tasks = {}
    local taskData = Players.LocalPlayer.PlayerGui:FindFirstChild("Data"):FindFirstChild("DinoEventTaskData")
    if not taskData then return tasks end
    
    local tasksFolder = taskData:FindFirstChild("Tasks")
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
                    completeValue = taskInfo.CompleteValue,
                    completeType = taskInfo.CompleteType,
                    repeatCount = taskInfo.RepeatCount,
                    taskPoints = taskInfo.TaskPoints,
                    isCompleted = progress >= taskInfo.CompleteValue,
                    canClaim = progress >= taskInfo.CompleteValue and claimedCount < taskInfo.RepeatCount
                })
            end
        end
    end
    
    return tasks
end

local function claimTaskReward(taskId)
    local args = {{ event = "claimreward", id = taskId }}
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("DinoEventRE"):FireServer(unpack(args))
    end)
    return success
end

local function getAvailablePlayers()
    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer then
            table.insert(players, player.Name)
        end
    end
    table.sort(players)
    return players
end

local function getRandomPlayer()
    local players = getAvailablePlayers()
    if #players > 0 then
        return players[math.random(1, #players)]
    end
    return nil
end

local function getPlayerByName(name)
    return Players:FindFirstChild(name)
end

local function getEggInventory()
    local eggs = {}
    local data = Players.LocalPlayer.PlayerGui:FindFirstChild("Data")
    if not data then return eggs end
    
    local eggContainer = data:FindFirstChild("Egg")
    if not eggContainer then return eggs end
    
    for _, egg in ipairs(eggContainer:GetChildren()) do
        if #egg:GetChildren() == 0 then
            local eggType = egg:GetAttribute("T")
            local mutation = egg:GetAttribute("M")
            
            if eggType then
                table.insert(eggs, {
                    uid = egg.Name,
                    type = eggType,
                    mutation = mutation
                })
            end
        end
    end
    
    return eggs
end

local function getPetInventory()
    local pets = {}
    local data = Players.LocalPlayer.PlayerGui:FindFirstChild("Data")
    if not data then return pets end
    
    local petsContainer = data:FindFirstChild("Pets")
    if not petsContainer then return pets end
    
    for _, pet in ipairs(petsContainer:GetChildren()) do
        if pet:IsA("Configuration") then
            local petType = pet:GetAttribute("T")
            local mutation = pet:GetAttribute("M")
            local locked = pet:GetAttribute("LK") == 1
            
            if petType then
                table.insert(pets, {
                    name = pet.Name,
                    type = petType,
                    mutation = mutation,
                    locked = locked
                })
            end
        end
    end
    
    return pets
end

local function focusEgg(eggUID)
    local args = {"Focus", eggUID}
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    return success
end

local function sendEgg(eggUID, targetPlayer)
    if not focusEgg(eggUID) then
        return false
    end
    
    task.wait(0.1)
    
    local args = {targetPlayer}
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(unpack(args))
    end)
    
    return success
end

local function sellPet(petName)
    local args = {"Sell", petName}
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("PetRE"):FireServer(unpack(args))
    end)
    return success
end

-- Task Executors
local function executeSendEggTask(task)
    local eggs = getEggInventory()
    local targetPlayer = selectedTargetPlayer
    
    if targetPlayer == "Random" then
        targetPlayer = getRandomPlayer()
    end
    
    if not targetPlayer then
        return false, "No target player available"
    end
    
    local playerInstance = getPlayerByName(targetPlayer)
    if not playerInstance then
        return false, "Target player not found"
    end
    
    local needed = task.completeValue - task.progress
    local sent = 0
    
    for _, egg in ipairs(eggs) do
        if sent >= needed then break end
        
        -- Check type filter (EXCLUDE logic)
        if #selectedEggTypes > 0 then
            local shouldExclude = false
            for _, excludedType in ipairs(selectedEggTypes) do
                if egg.type == excludedType then
                    shouldExclude = true
                    break
                end
            end
            if shouldExclude then
                continue
            end
        end
        
        -- Check mutation filter (EXCLUDE logic)
        if #selectedEggMutations > 0 and egg.mutation then
            local shouldExclude = false
            for _, excludedMutation in ipairs(selectedEggMutations) do
                if egg.mutation == excludedMutation then
                    shouldExclude = true
                    break
                end
            end
            if shouldExclude then
                continue
            end
        end
        
        if sendEgg(egg.uid, playerInstance) then
            sent = sent + 1
            task.wait(0.3)
        end
    end
    
    return sent > 0, "Sent " .. sent .. " eggs"
end

local function executeSellPetTask(task)
    local pets = getPetInventory()
    local needed = task.completeValue - task.progress
    local sold = 0
    
    for _, pet in ipairs(pets) do
        if sold >= needed then break end
        
        if pet.locked then
            continue
        end
        
        -- Check type filter (EXCLUDE logic)
        if #selectedPetTypes > 0 then
            local shouldExclude = false
            for _, excludedType in ipairs(selectedPetTypes) do
                if pet.type == excludedType then
                    shouldExclude = true
                    break
                end
            end
            if shouldExclude then
                continue
            end
        end
        
        -- Check mutation filter (EXCLUDE logic)
        if #selectedPetMutations > 0 and pet.mutation then
            local shouldExclude = false
            for _, excludedMutation in ipairs(selectedPetMutations) do
                if pet.mutation == excludedMutation then
                    shouldExclude = true
                    break
                end
            end
            if shouldExclude then
                continue
            end
        end
        
        if sellPet(pet.name) then
            sold = sold + 1
            task.wait(0.3)
        end
    end
    
    return sold > 0, "Sold " .. sold .. " pets"
end

local function executeOnlineTimeTask(task)
    if task.canClaim then
        return claimTaskReward(task.id), "Claimed online time reward"
    end
    return false, "Waiting for online time"
end

-- Main Quest Loop
local function runAutoQuest()
    while autoQuestEnabled do
        local ok, err = pcall(function()
            currentTasks = getCurrentTasks()
            
            if #currentTasks == 0 then
                task.wait(5)
                return
            end
            
            -- Sort tasks by user-defined priority order
            -- Default priority if not set: BuyMutateEgg → HatchEgg → SendEgg → SellPet → OnlineTime
            local taskPriority = taskPriorityOrder or {
                BuyMutateEgg = 1,
                HatchEgg = 2,
                SendEgg = 3,
                SellPet = 4,
                OnlineTime = 5
            }
            
            table.sort(currentTasks, function(a, b)
                local priorityA = taskPriority[a.completeType] or 999
                local priorityB = taskPriority[b.completeType] or 999
                return priorityA < priorityB
            end)
            
            local taskCompleted = false
            
            for _, task in ipairs(currentTasks) do
                if not autoQuestEnabled then break end
                
                -- Skip if task is already completed
                if task.isCompleted then
                    continue
                end
                
                -- Handle claimable tasks
                if task.canClaim then
                    if autoClaimEnabled then
                        if claimTaskReward(task.id) then
                            taskCompleted = true
                            task.wait(0.5)
                            break -- Move to next task
                        end
                    end
                    continue
                end
                
                -- Execute task based on type
                local success, message
                
                if task.completeType == "SendEgg" then
                    success, message = executeSendEggTask(task)
                elseif task.completeType == "SellPet" then
                    success, message = executeSellPetTask(task)
                elseif task.completeType == "OnlineTime" then
                    success, message = executeOnlineTimeTask(task)
                elseif task.completeType == "HatchEgg" then
                    -- HatchEgg is handled by main script's auto hatch system
                    success = true
                    message = "HatchEgg task - handled by auto hatch system"
                elseif task.completeType == "BuyMutateEgg" then
                    -- BuyMutateEgg is handled by main script's auto buy system
                    success = true
                    message = "BuyMutateEgg task - handled by auto buy system"
                end
                
                if success then
                    taskCompleted = true
                    task.wait(1)
                    break -- Move to next task after successful execution
                else
                    -- If task failed, try next task instead of waiting
                    continue
                end
            end
            
            -- If no tasks were completed, wait before next cycle
            if not taskCompleted then
                if autoRefreshEnabled then
                    task.wait(10)
                else
                    task.wait(5)
                end
            end
            
        end)
        
        if not ok then
            warn("Auto Quest error: " .. tostring(err))
            task.wait(5)
        end
    end
end

-- Public Functions
function AutoQuestSystem.StartQuest()
    if not autoQuestEnabled then
        autoQuestEnabled = true
        autoQuestThread = task.spawn(runAutoQuest)
    end
end

function AutoQuestSystem.StopQuest()
    autoQuestEnabled = false
    if autoQuestThread then
        autoQuestThread = nil
    end
end

function AutoQuestSystem.IsQuestRunning()
    return autoQuestEnabled
end

function AutoQuestSystem.GetSettings()
    return {
        targetPlayer = selectedTargetPlayer,
        eggTypes = selectedEggTypes,
        eggMutations = selectedEggMutations,
        petTypes = selectedPetTypes,
        petMutations = selectedPetMutations,
        autoClaim = autoClaimEnabled,
        autoRefresh = autoRefreshEnabled
    }
end

function AutoQuestSystem.SetSettings(settings)
    if settings then
        selectedTargetPlayer = settings.targetPlayer or "Random"
        selectedEggTypes = settings.eggTypes or {}
        selectedEggMutations = settings.eggMutations or {}
        selectedPetTypes = settings.petTypes or {}
        selectedPetMutations = settings.petMutations or {}
        autoClaimEnabled = settings.autoClaim or false
        autoRefreshEnabled = settings.autoRefresh or false
    end
end

function AutoQuestSystem.SetPriorityOrder(priorityOrder)
    if priorityOrder then
        taskPriorityOrder = priorityOrder
    end
end

-- Initialize function for main script integration
function AutoQuestSystem.Init(dependencies)
    -- Just return the AutoQuestSystem object - UI is handled in main script
    return AutoQuestSystem
end

return AutoQuestSystem
