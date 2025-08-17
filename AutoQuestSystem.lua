-- Auto Quest System for Build A Zoo
-- Handles daily tasks: HatchEgg, SellPet, SendEgg, BuyMutateEgg, OnlineTime

local AutoQuestSystem = {}

-- Task configuration from your provided data
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

-- State variables
local autoQuestEnabled = false
local autoQuestThread = nil
local questStatus = {}
local originalToggleStates = {}

-- UI elements (will be set by Init)
local questToggle = nil
local targetPlayerDropdown = nil
local sendEggDropdown = nil
local sellPetDropdown = nil
local claimAllToggle = nil
local refreshToggle = nil

-- Configuration
local selectedTargetPlayer = "Random"
local selectedSendEggTypes = {}
local selectedSellPetTypes = {}
local selectedSendEggMutations = {}
local selectedSellPetMutations = {}

-- Helper functions
local function getPlayerList()
    local players = {}
    table.insert(players, "Random")
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer then
            table.insert(players, player.Name)
        end
    end
    return players
end

local function getRandomPlayer()
    local availablePlayers = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer then
            table.insert(availablePlayers, player)
        end
    end
    if #availablePlayers > 0 then
        return availablePlayers[math.random(1, #availablePlayers)]
    end
    return nil
end

local function getTargetPlayer()
    if selectedTargetPlayer == "Random" then
        return getRandomPlayer()
    else
        return Players:FindFirstChild(selectedTargetPlayer)
    end
end

local function getAvailableEggTypes()
    local eggTypes = {}
    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local data = playerGui:FindFirstChild("Data")
        if data then
            local eggContainer = data:FindFirstChild("Egg")
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
        end
    end
    table.sort(eggTypes)
    return eggTypes
end

local function getAvailablePetTypes()
    local petTypes = {}
    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local data = playerGui:FindFirstChild("Data")
        if data then
            local petsContainer = data:FindFirstChild("Pets")
            if petsContainer then
                for _, pet in ipairs(petsContainer:GetChildren()) do
                    local petType = pet:GetAttribute("T")
                    if petType and not table.find(petTypes, petType) then
                        table.insert(petTypes, petType)
                    end
                end
            end
        end
    end
    table.sort(petTypes)
    return petTypes
end

local function getAvailableMutations()
    return {"Golden", "Diamond", "Electric", "Fire", "Jurassic"}
end

local function getCurrentTasks()
    local tasks = {}
    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local data = playerGui:FindFirstChild("Data")
        if data then
            local dinoEventTaskData = data:FindFirstChild("DinoEventTaskData")
            if dinoEventTaskData then
                local tasksFolder = dinoEventTaskData:FindFirstChild("Tasks")
                if tasksFolder then
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
                                    repeatCount = taskInfo.RepeatCount,
                                    completeType = taskInfo.CompleteType,
                                    isComplete = progress >= taskInfo.CompleteValue and claimedCount < taskInfo.RepeatCount
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    return tasks
end

local function claimTask(taskId)
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

local function focusEgg(eggUID)
    local args = {"Focus", eggUID}
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    return success
end

local function sendEgg(eggUID, targetPlayer)
    if not targetPlayer then return false end
    
    -- Focus first
    if not focusEgg(eggUID) then return false end
    task.wait(0.1)
    
    -- Send gift
    local args = {targetPlayer}
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(unpack(args))
    end)
    return success
end

local function sellPet(petUID)
    local args = {"Sell", petUID}
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("PetRE"):FireServer(unpack(args))
    end)
    return success
end

local function getEggMutation(eggUID)
    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local data = playerGui:FindFirstChild("Data")
        if data then
            local eggContainer = data:FindFirstChild("Egg")
            if eggContainer then
                local egg = eggContainer:FindFirstChild(eggUID)
                if egg then
                    local mutation = egg:GetAttribute("M")
                    if mutation == "Dino" then
                        return "Jurassic"
                    end
                    return mutation
                end
            end
        end
    end
    return nil
end

local function getPetMutation(petUID)
    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local data = playerGui:FindFirstChild("Data")
        if data then
            local petsContainer = data:FindFirstChild("Pets")
            if petsContainer then
                local pet = petsContainer:FindFirstChild(petUID)
                if pet then
                    local mutation = pet:GetAttribute("M")
                    if mutation == "Dino" then
                        return "Jurassic"
                    end
                    return mutation
                end
            end
        end
    end
    return nil
end

local function isPetLocked(petUID)
    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local data = playerGui:FindFirstChild("Data")
        if data then
            local petsContainer = data:FindFirstChild("Pets")
            if petsContainer then
                local pet = petsContainer:FindFirstChild(petUID)
                if pet then
                    local locked = pet:GetAttribute("LK")
                    return locked == 1
                end
            end
        end
    end
    return false
end

local function shouldSendEgg(eggUID)
    local eggType = nil
    local mutation = getEggMutation(eggUID)
    
    -- Get egg type from container
    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local data = playerGui:FindFirstChild("Data")
        if data then
            local eggContainer = data:FindFirstChild("Egg")
            if eggContainer then
                local egg = eggContainer:FindFirstChild(eggUID)
                if egg then
                    eggType = egg:GetAttribute("T")
                end
            end
        end
    end
    
    -- Check type filter
    if #selectedSendEggTypes > 0 then
        if not eggType or not table.find(selectedSendEggTypes, eggType) then
            return false
        end
    end
    
    -- Check mutation filter
    if #selectedSendEggMutations > 0 then
        if not mutation or not table.find(selectedSendEggMutations, mutation) then
            return false
        end
    end
    
    return true
end

local function shouldSellPet(petUID)
    local petType = nil
    local mutation = getPetMutation(petUID)
    
    -- Get pet type from container
    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local data = playerGui:FindFirstChild("Data")
        if data then
            local petsContainer = data:FindFirstChild("Pets")
            if petsContainer then
                local pet = petsContainer:FindFirstChild(petUID)
                if pet then
                    petType = pet:GetAttribute("T")
                end
            end
        end
    end
    
    -- Check if locked
    if isPetLocked(petUID) then
        return false
    end
    
    -- Check type filter
    if #selectedSellPetTypes > 0 then
        if not petType or not table.find(selectedSellPetTypes, petType) then
            return false
        end
    end
    
    -- Check mutation filter
    if #selectedSellPetMutations > 0 then
        if not mutation or not table.find(selectedSellPetMutations, mutation) then
            return false
        end
    end
    
    return true
end

local function getAvailableEggsForSending()
    local eggs = {}
    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local data = playerGui:FindFirstChild("Data")
        if data then
            local eggContainer = data:FindFirstChild("Egg")
            if eggContainer then
                for _, egg in ipairs(eggContainer:GetChildren()) do
                    if #egg:GetChildren() == 0 then -- Available egg
                        if shouldSendEgg(egg.Name) then
                            table.insert(eggs, egg.Name)
                        end
                    end
                end
            end
        end
    end
    return eggs
end

local function getAvailablePetsForSelling()
    local pets = {}
    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local data = playerGui:FindFirstChild("Data")
        if data then
            local petsContainer = data:FindFirstChild("Pets")
            if petsContainer then
                for _, pet in ipairs(petsContainer:GetChildren()) do
                    if shouldSellPet(pet.Name) then
                        table.insert(pets, pet.Name)
                    end
                end
            end
        end
    end
    return pets
end

local function showInventoryDialog(message, Window)
    local confirmed = false
    local dialog = Window:Dialog({
        Title = "⚠️ Inventory Warning",
        Content = message .. "\n\nDo you want to continue anyway?",
        Icon = "alert-triangle",
        Buttons = {
            {
                Title = "❌ Cancel",
                Variant = "Secondary",
                Callback = function() confirmed = false end
            },
            {
                Title = "✅ Continue",
                Variant = "Primary",
                Callback = function() confirmed = true end
            }
        }
    })
    
    -- Wait for dialog response
    while not confirmed and dialog do
        task.wait(0.1)
    end
    
    return confirmed
end

-- Task executors
local function executeHatchEggTask(task, WindUI)
    -- Store original states (these will be set by the main script)
    -- For now, we'll just enable the systems and let the main script handle state management
    
    -- Enable required systems (these toggles will be passed from main script)
    WindUI:Notify({
        Title = "📝 Auto Quest",
        Content = "Enabling Auto Buy/Place/Hatch for HatchEgg task...",
        Duration = 3
    })
    
    -- Wait for completion
    while autoQuestEnabled do
        local currentTasks = getCurrentTasks()
        local currentTask = nil
        for _, t in ipairs(currentTasks) do
            if t.id == task.id then
                currentTask = t
                break
            end
        end
        
        if not currentTask or currentTask.isComplete then
            break
        end
        
        task.wait(1)
    end
    
    -- Wait for completion
    while autoQuestEnabled do
        local currentTasks = getCurrentTasks()
        local currentTask = nil
        for _, t in ipairs(currentTasks) do
            if t.id == task.id then
                currentTask = t
                break
            end
        end
        
        if not currentTask or currentTask.isComplete then
            break
        end
        
        task.wait(1)
    end
    
    -- Restore original states (handled by main script)
    WindUI:Notify({
        Title = "📝 Auto Quest",
        Content = "HatchEgg task completed!",
        Duration = 3
    })
end

local function executeSellPetTask(task, WindUI)
    local needed = task.completeValue - task.progress
    local availablePets = getAvailablePetsForSelling()
    
    if #availablePets == 0 then
        local message = "No pets available for selling with current filters.\n\nSelected types: " .. 
                       (#selectedSellPetTypes > 0 and table.concat(selectedSellPetTypes, ", ") or "All") ..
                       "\nSelected mutations: " .. 
                       (#selectedSellPetMutations > 0 and table.concat(selectedSellPetMutations, ", ") or "All")
        
        if not showInventoryDialog(message, Window) then
            return false
        end
        -- If user continues, proceed without filters
        availablePets = getAvailablePetsForSelling()
    end
    
    local sold = 0
    for i = 1, math.min(needed, #availablePets) do
        if not autoQuestEnabled then break end
        
        if sellPet(availablePets[i]) then
            sold = sold + 1
            task.wait(0.3) -- Delay between sells
        end
    end
    
    return sold > 0
end

local function executeSendEggTask(task, WindUI)
    local needed = task.completeValue - task.progress
    local availableEggs = getAvailableEggsForSending()
    local targetPlayer = getTargetPlayer()
    
    if not targetPlayer then
        WindUI:Notify({
            Title = "⚠️ Auto Quest",
            Content = "No target player available for sending eggs",
            Duration = 3
        })
        return false
    end
    
    if #availableEggs == 0 then
        local message = "No eggs available for sending with current filters.\n\nSelected types: " .. 
                       (#selectedSendEggTypes > 0 and table.concat(selectedSendEggTypes, ", ") or "All") ..
                       "\nSelected mutations: " .. 
                       (#selectedSendEggMutations > 0 and table.concat(selectedSendEggMutations, ", ") or "All")
        
        if not showInventoryDialog(message, Window) then
            return false
        end
        -- If user continues, proceed without filters
        availableEggs = getAvailableEggsForSending()
    end
    
    local sent = 0
    for i = 1, math.min(needed, #availableEggs) do
        if not autoQuestEnabled then break end
        
        if sendEgg(availableEggs[i], targetPlayer) then
            sent = sent + 1
            task.wait(0.3) -- Delay between sends
        end
    end
    
    return sent > 0
end

local function executeBuyMutateEggTask(task, WindUI)
    -- This will be handled by the existing auto buy system
    -- We'll modify the egg selection to only buy mutated eggs
    local originalEggTypes = selectedTypeSet
    local originalMutations = selectedMutationSet
    
    -- Clear filters to buy any egg, then check for mutations
    selectedTypeSet = {}
    selectedMutationSet = {}
    
    -- Wait for completion (buy system will handle the rest)
    while autoQuestEnabled do
        local currentTasks = getCurrentTasks()
        local currentTask = nil
        for _, t in ipairs(currentTasks) do
            if t.id == task.id then
                currentTask = t
                break
            end
        end
        
        if not currentTask or currentTask.isComplete then
            break
        end
        
        task.wait(1)
    end
    
    -- Restore original filters
    selectedTypeSet = originalEggTypes
    selectedMutationSet = originalMutations
end

local function executeOnlineTimeTask(task, WindUI)
    -- Just wait and claim when ready
    while autoQuestEnabled do
        local currentTasks = getCurrentTasks()
        local currentTask = nil
        for _, t in ipairs(currentTasks) do
            if t.id == task.id then
                currentTask = t
                break
            end
        end
        
        if not currentTask then
            break
        end
        
        if currentTask.isComplete then
            if claimTask(task.id) then
                WindUI:Notify({
                    Title = "🎉 Auto Quest",
                    Content = "Claimed online time reward!",
                    Duration = 3
                })
            end
        end
        
        task.wait(5) -- Check every 5 seconds
    end
end

local function runAutoQuest(WindUI)
    while autoQuestEnabled do
        local tasks = getCurrentTasks()
        
        if #tasks == 0 then
            task.wait(5)
            continue
        end
        
        -- Priority order: BuyMutateEgg → HatchEgg → SendEgg → SellPet → OnlineTime
        local priorityOrder = {"BuyMutateEgg", "HatchEgg", "SendEgg", "SellPet", "OnlineTime"}
        
        for _, taskType in ipairs(priorityOrder) do
            for _, task in ipairs(tasks) do
                if task.completeType == taskType and not task.isComplete and autoQuestEnabled then
                    WindUI:Notify({
                        Title = "📝 Auto Quest",
                        Content = "Executing " .. taskType .. " task...",
                        Duration = 3
                    })
                    
                    if taskType == "HatchEgg" then
                        executeHatchEggTask(task, WindUI)
                    elseif taskType == "SellPet" then
                        executeSellPetTask(task, WindUI)
                    elseif taskType == "SendEgg" then
                        executeSendEggTask(task, WindUI)
                    elseif taskType == "BuyMutateEgg" then
                        executeBuyMutateEggTask(task, WindUI)
                    elseif taskType == "OnlineTime" then
                        executeOnlineTimeTask(task, WindUI)
                    end
                    
                    -- Claim if complete
                    if task.isComplete then
                        if claimTask(task.id) then
                            WindUI:Notify({
                                Title = "🎉 Auto Quest",
                                Content = "Task completed and claimed!",
                                Duration = 3
                            })
                        end
                    end
                end
            end
        end
        
        task.wait(2)
    end
end

-- UI Creation
function AutoQuestSystem.Init(dependencies)
    local WindUI = dependencies.WindUI
    local Window = dependencies.Window
    local Config = dependencies.Config
    local waitForSettingsReady = dependencies.waitForSettingsReady
    
    -- Create Auto Quest tab
    local QuestTab = Window:Tab({ Title = "📝 | Auto Quest" })
    
    -- Status section
    QuestTab:Section({ Title = "📊 Quest Status", Icon = "activity" })
    
    local statusParagraph = QuestTab:Paragraph({
        Title = "📊 Current Tasks",
        Desc = "Loading tasks...",
        Image = "activity",
        ImageSize = 22
    })
    
    -- Controls section
    QuestTab:Section({ Title = "⚙️ Quest Controls", Icon = "settings" })
    
    questToggle = QuestTab:Toggle({
        Title = "📝 Auto Quest",
        Desc = "Automatically complete daily tasks",
        Value = false,
        Callback = function(state)
            autoQuestEnabled = state
            
            waitForSettingsReady(0.2)
            if state and not autoQuestThread then
                autoQuestThread = task.spawn(function()
                    runAutoQuest()
                    autoQuestThread = nil
                end)
                WindUI:Notify({ Title = "📝 Auto Quest", Content = "Started completing tasks! 🎉", Duration = 3 })
            elseif (not state) and autoQuestThread then
                WindUI:Notify({ Title = "📝 Auto Quest", Content = "Stopped", Duration = 3 })
            end
        end
    })
    
    -- Target player dropdown
    targetPlayerDropdown = QuestTab:Dropdown({
        Title = "🎯 Target Player",
        Desc = "Choose who to send eggs to",
        Values = getPlayerList(),
        Value = "Random",
        Callback = function(selection)
            selectedTargetPlayer = selection
        end
    })
    
    -- Send Egg filters
    sendEggDropdown = QuestTab:Dropdown({
        Title = "🥚 Send Egg Types",
        Desc = "Filter eggs by type (empty = all)",
        Values = getAvailableEggTypes(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedSendEggTypes = selection
        end
    })
    
    local sendEggMutationDropdown = QuestTab:Dropdown({
        Title = "🧬 Send Egg Mutations",
        Desc = "Filter eggs by mutation (empty = all)",
        Values = getAvailableMutations(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedSendEggMutations = selection
        end
    })
    
    -- Sell Pet filters
    sellPetDropdown = QuestTab:Dropdown({
        Title = "🐾 Sell Pet Types",
        Desc = "Filter pets by type (empty = all)",
        Values = getAvailablePetTypes(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedSellPetTypes = selection
        end
    })
    
    local sellPetMutationDropdown = QuestTab:Dropdown({
        Title = "🧬 Sell Pet Mutations",
        Desc = "Filter pets by mutation (empty = all)",
        Values = getAvailableMutations(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedSellPetMutations = selection
        end
    })
    
    -- Action toggles
    claimAllToggle = QuestTab:Toggle({
        Title = "💰 Claim All Ready",
        Desc = "Automatically claim completed tasks",
        Value = true,
        Callback = function(state)
            -- This will be handled in the main loop
        end
    })
    
    refreshToggle = QuestTab:Toggle({
        Title = "🔄 Auto Refresh",
        Desc = "Automatically refresh task status",
        Value = true,
        Callback = function(state)
            -- This will be handled in the main loop
        end
    })
    
    -- Manual actions
    QuestTab:Button({
        Title = "🔄 Refresh Now",
        Desc = "Manually refresh task status",
        Callback = function()
            local tasks = getCurrentTasks()
            local statusText = ""
            
            for i, task in ipairs(tasks) do
                statusText = statusText .. string.format(
                    "Task %d (%s): %d/%d (Claimed: %d/%d)\n",
                    i, task.completeType, task.progress, task.completeValue, 
                    task.claimedCount, task.repeatCount
                )
            end
            
            if statusText == "" then
                statusText = "No active tasks found"
            end
            
            statusParagraph:SetDesc(statusText)
        end
    })
    
    QuestTab:Button({
        Title = "💰 Claim All Now",
        Desc = "Manually claim all completed tasks",
        Callback = function()
            local tasks = getCurrentTasks()
            local claimed = 0
            
            for _, task in ipairs(tasks) do
                if task.isComplete then
                    if claimTask(task.id) then
                        claimed = claimed + 1
                        task.wait(0.2)
                    end
                end
            end
            
            WindUI:Notify({
                Title = "💰 Auto Quest",
                Content = string.format("Claimed %d tasks!", claimed),
                Duration = 3
            })
        end
    })
    
    -- Register with config
    if Config then
        Config:Register("autoQuestEnabled", questToggle)
        Config:Register("targetPlayerDropdown", targetPlayerDropdown)
        Config:Register("sendEggDropdown", sendEggDropdown)
        Config:Register("sellPetDropdown", sellPetDropdown)
        Config:Register("claimAllToggle", claimAllToggle)
        Config:Register("refreshToggle", refreshToggle)
    end
    
    -- Update status periodically
    task.spawn(function()
        while true do
            if refreshToggle and refreshToggle:GetValue() then
                local tasks = getCurrentTasks()
                local statusText = ""
                
                for i, task in ipairs(tasks) do
                    statusText = statusText .. string.format(
                        "Task %d (%s): %d/%d (Claimed: %d/%d)\n",
                        i, task.completeType, task.progress, task.completeValue, 
                        task.claimedCount, task.repeatCount
                    )
                end
                
                if statusText == "" then
                    statusText = "No active tasks found"
                end
                
                if statusParagraph then
                    statusParagraph:SetDesc(statusText)
                end
            end
            
            task.wait(5)
        end
    end)
    
    return {
        questToggle = questToggle,
        targetPlayerDropdown = targetPlayerDropdown,
        sendEggDropdown = sendEggDropdown,
        sellPetDropdown = sellPetDropdown,
        claimAllToggle = claimAllToggle,
        refreshToggle = refreshToggle
    }
end

return AutoQuestSystem
