-- Auto Quest System for Build A Zoo
-- Handles daily tasks: HatchEgg, SellPet, SendEgg, BuyMutateEgg, OnlineTime

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

-- Priority order for task execution
local TaskPriority = {
    "BuyMutateEgg",
    "HatchEgg", 
    "SendEgg",
    "SellPet",
    "OnlineTime"
}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- State variables
local autoQuestEnabled = false
local autoQuestThread = nil
local questStatus = {}
local originalStates = {}
local actionCount = 0
local lastInventoryRefresh = 0
local maxActionsPerSession = 5

-- UI elements (will be set by Init function)
local WindUI = nil
local Window = nil
local Config = nil
local waitForSettingsReady = nil

-- Integration with existing auto systems
local autoBuyEnabled = nil
local autoPlaceEnabled = nil
local autoHatchEnabled = nil
local setAutoBuyEnabled = nil
local setAutoPlaceEnabled = nil
local setAutoHatchEnabled = nil
local autoBuyToggle = nil
local autoPlaceToggle = nil
local autoHatchToggle = nil

-- UI controls
local autoQuestToggle = nil
local targetPlayerDropdown = nil
local sendEggTFilterDropdown = nil
local sendEggMFilterDropdown = nil
local sellPetTFilterDropdown = nil
local sellPetMFilterDropdown = nil
local claimAllToggle = nil
local refreshTasksToggle = nil
local questStatusParagraph = nil

-- Helper functions
local function getPlayerList()
    local players = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(players, player.Name)
        end
    end
    table.insert(players, "Random Player")
    return players
end

local function getRandomPlayer()
    local availablePlayers = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(availablePlayers, player)
        end
    end
    if #availablePlayers > 0 then
        return availablePlayers[math.random(1, #availablePlayers)]
    end
    return nil
end

local function getTargetPlayer()
    if not targetPlayerDropdown then return nil end
    
    local selected = targetPlayerDropdown:GetValue()
    if type(selected) == "table" and #selected > 0 then
        local targetName = selected[1]
        if targetName == "Random Player" then
            return getRandomPlayer()
        else
            return Players:FindFirstChild(targetName)
        end
    end
    return nil
end

local function getTaskData()
    local tasks = {}
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
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
                    taskPoints = taskInfo.TaskPoints
                })
            end
        end
    end
    
    return tasks
end

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

local function shouldRefreshInventory()
    actionCount = actionCount + 1
    return actionCount % 5 == 0
end

local function getInventoryItems(containerPath, attributeName)
    local items = {}
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return items end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return items end
    
    local container = data:FindFirstChild(containerPath)
    if not container then return items end
    
    for _, item in pairs(container:GetChildren()) do
        if #item:GetChildren() == 0 then -- Available item
            local attrValue = item:GetAttribute(attributeName)
            if attrValue then
                table.insert(items, {
                    uid = item.Name,
                    value = attrValue
                })
            end
        end
    end
    
    return items
end

local function getEggInventory()
    return getInventoryItems("Egg", "T")
end

local function getPetInventory()
    return getInventoryItems("Pets", "T")
end

local function getEggMutation(eggUID)
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return nil end
    
    local eggContainer = data:FindFirstChild("Egg")
    if not eggContainer then return nil end
    
    local eggConfig = eggContainer:FindFirstChild(eggUID)
    if not eggConfig then return nil end
    
    local mutation = eggConfig:GetAttribute("M")
    if mutation == "Dino" then
        mutation = "Jurassic"
    end
    
    return mutation
end

local function getPetMutation(petUID)
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return nil end
    
    local petsContainer = data:FindFirstChild("Pets")
    if not petsContainer then return nil end
    
    local petConfig = petsContainer:FindFirstChild(petUID)
    if not petConfig then return nil end
    
    local mutation = petConfig:GetAttribute("M")
    if mutation == "Dino" then
        mutation = "Jurassic"
    end
    
    return mutation
end

local function filterItemsBySelection(items, tFilter, mFilter, getMutationFunc)
    if not items or #items == 0 then return {} end
    
    local filtered = {}
    local tFilterSet = {}
    local mFilterSet = {}
    
    -- Build filter sets
    if tFilter and type(tFilter) == "table" then
        for _, t in pairs(tFilter) do
            tFilterSet[t] = true
        end
    end
    
    if mFilter and type(mFilter) == "table" then
        for _, m in pairs(mFilter) do
            mFilterSet[m] = true
        end
    end
    
    for _, item in pairs(items) do
        local shouldInclude = true
        
        -- Check T filter (exclude if selected)
        if next(tFilterSet) and tFilterSet[item.value] then
            shouldInclude = false
        end
        
        -- Check M filter (exclude if selected)
        if shouldInclude and next(mFilterSet) then
            local mutation = getMutationFunc(item.uid)
            if mutation and mFilterSet[mutation] then
                shouldInclude = false
            end
        end
        
        if shouldInclude then
            table.insert(filtered, item)
        end
    end
    
    return filtered
end

local function showSafetyDialog(message, callback)
    if not WindUI then return false end
    
    local confirmed = false
    WindUI:Dialog({
        Title = "⚠️ Safety Check",
        Content = message,
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
    
    if confirmed and callback then
        callback()
    end
    
    return confirmed
end

local function updateQuestStatus()
    if not questStatusParagraph then return end
    
    local tasks = getTaskData()
    local statusText = "📋 Active Tasks:\n"
    
    for _, task in pairs(tasks) do
        local progressPercent = math.floor((task.progress / task.completeValue) * 100)
        local statusIcon = task.progress >= task.completeValue and "✅" or "⏳"
        
        statusText = statusText .. string.format("%s %s: %d/%d (%d%%) [%s]\n", 
            statusIcon, task.id, task.progress, task.completeValue, progressPercent, task.completeType)
    end
    
    if #tasks == 0 then
        statusText = statusText .. "No active tasks found"
    end
    
    questStatusParagraph:SetDesc(statusText)
end

-- Task executors
local function executeBuyMutateEgg(task)
    -- Store original states
    if not questTaskActive then
        originalStates.autoBuy = autoBuyEnabled
        originalStates.autoPlace = autoPlaceEnabled
        originalStates.autoHatch = autoHatchEnabled
        questTaskActive = true
    end
    
    -- Enable Auto Buy to handle mutation egg buying
    if setAutoBuyEnabled then
        setAutoBuyEnabled(true)
        if autoBuyToggle then
            autoBuyToggle:SetValue(true)
        end
    end
    
    -- Wait for task to complete
    local startTime = tick()
    while autoQuestEnabled and tick() - startTime < 300 do -- 5 minute timeout
        local tasks = getTaskData()
        for _, currentTask in pairs(tasks) do
            if currentTask.id == task.id and currentTask.progress >= currentTask.completeValue then
                -- Task completed, restore original states
                if setAutoBuyEnabled then
                    setAutoBuyEnabled(originalStates.autoBuy)
                    if autoBuyToggle then
                        autoBuyToggle:SetValue(originalStates.autoBuy)
                    end
                end
                questTaskActive = false
                return true
            end
        end
        wait(2)
    end
    
    -- Timeout or disabled, restore original states
    if setAutoBuyEnabled then
        setAutoBuyEnabled(originalStates.autoBuy)
        if autoBuyToggle then
            autoBuyToggle:SetValue(originalStates.autoBuy)
        end
    end
    questTaskActive = false
    return false
end

local function executeHatchEgg(task)
    -- Store original states
    if not questTaskActive then
        originalStates.autoBuy = autoBuyEnabled
        originalStates.autoPlace = autoPlaceEnabled
        originalStates.autoHatch = autoHatchEnabled
        questTaskActive = true
    end
    
    -- Enable Auto Buy, Place, and Hatch for egg hatching
    if setAutoBuyEnabled then setAutoBuyEnabled(true) end
    if setAutoPlaceEnabled then setAutoPlaceEnabled(true) end
    if setAutoHatchEnabled then setAutoHatchEnabled(true) end
    
    if autoBuyToggle then autoBuyToggle:SetValue(true) end
    if autoPlaceToggle then autoPlaceToggle:SetValue(true) end
    if autoHatchToggle then autoHatchToggle:SetValue(true) end
    
    -- Wait for task to complete
    local startTime = tick()
    while autoQuestEnabled and tick() - startTime < 600 do -- 10 minute timeout
        local tasks = getTaskData()
        for _, currentTask in pairs(tasks) do
            if currentTask.id == task.id and currentTask.progress >= currentTask.completeValue then
                -- Task completed, restore original states
                if setAutoBuyEnabled then setAutoBuyEnabled(originalStates.autoBuy) end
                if setAutoPlaceEnabled then setAutoPlaceEnabled(originalStates.autoPlace) end
                if setAutoHatchEnabled then setAutoHatchEnabled(originalStates.autoHatch) end
                
                if autoBuyToggle then autoBuyToggle:SetValue(originalStates.autoBuy) end
                if autoPlaceToggle then autoPlaceToggle:SetValue(originalStates.autoPlace) end
                if autoHatchToggle then autoHatchToggle:SetValue(originalStates.autoHatch) end
                
                questTaskActive = false
                return true
            end
        end
        wait(2)
    end
    
    -- Timeout or disabled, restore original states
    if setAutoBuyEnabled then setAutoBuyEnabled(originalStates.autoBuy) end
    if setAutoPlaceEnabled then setAutoPlaceEnabled(originalStates.autoPlace) end
    if setAutoHatchEnabled then setAutoHatchEnabled(originalStates.autoHatch) end
    
    if autoBuyToggle then autoBuyToggle:SetValue(originalStates.autoBuy) end
    if autoPlaceToggle then autoPlaceToggle:SetValue(originalStates.autoPlace) end
    if autoHatchToggle then autoHatchToggle:SetValue(originalStates.autoHatch) end
    
    questTaskActive = false
    return false
end

local function executeSendEgg(task)
    local eggs = getEggInventory()
    local tFilter = sendEggTFilterDropdown and sendEggTFilterDropdown:GetValue() or {}
    local mFilter = sendEggMFilterDropdown and sendEggMFilterDropdown:GetValue() or {}
    
    local filteredEggs = filterItemsBySelection(eggs, tFilter, mFilter, getEggMutation)
    
    if #filteredEggs == 0 then
        local tFilterText = "None"
        local mFilterText = "None"
        if next(tFilter) then
            local tList = {}
            for _, t in pairs(tFilter) do
                table.insert(tList, t)
            end
            tFilterText = table.concat(tList, ", ")
        end
        if next(mFilter) then
            local mList = {}
            for _, m in pairs(mFilter) do
                table.insert(mList, m)
            end
            mFilterText = table.concat(mList, ", ")
        end
        
        local message = "No eggs match your current filters.\n\nT-Filter: " .. tFilterText ..
                       "\nM-Filter: " .. mFilterText ..
                       "\n\nContinue anyway?"
        
        return showSafetyDialog(message, function()
            -- Continue with all eggs
            filteredEggs = eggs
        end)
    end
    
    local targetPlayer = getTargetPlayer()
    if not targetPlayer then
        WindUI:Notify({ Title = "❌ Send Egg", Content = "No target player selected", Duration = 3 })
            return false
    end
    
    local needed = task.completeValue - task.progress
    local sent = 0
    
    for i = 1, math.min(needed, #filteredEggs, maxActionsPerSession) do
        local egg = filteredEggs[i]
        
        -- Focus egg
        local focusSuccess = pcall(function()
            local args = { "Focus", egg.uid }
            ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
        end)
        
        if focusSuccess then
            wait(0.2)
            
            -- Send egg
            local sendSuccess = pcall(function()
                local args = { targetPlayer }
                ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(unpack(args))
            end)
            
            if sendSuccess then
                sent = sent + 1
                WindUI:Notify({ Title = "🎁 Sent Egg", Content = "Sent " .. egg.value .. " to " .. targetPlayer.Name, Duration = 2 })
            end
        end
        
        wait(0.5)
        
        if shouldRefreshInventory() then
            eggs = getEggInventory()
            filteredEggs = filterItemsBySelection(eggs, tFilter, mFilter, getEggMutation)
        end
    end
    
    return sent > 0
end

local function executeSellPet(task)
    local pets = getPetInventory()
    local tFilter = sellPetTFilterDropdown and sellPetTFilterDropdown:GetValue() or {}
    local mFilter = sellPetMFilterDropdown and sellPetMFilterDropdown:GetValue() or {}
    
    local filteredPets = filterItemsBySelection(pets, tFilter, mFilter, getPetMutation)
    
    if #filteredPets == 0 then
        local tFilterText = "None"
        local mFilterText = "None"
        if next(tFilter) then
            local tList = {}
            for _, t in pairs(tFilter) do
                table.insert(tList, t)
            end
            tFilterText = table.concat(tList, ", ")
        end
        if next(mFilter) then
            local mList = {}
            for _, m in pairs(mFilter) do
                table.insert(mList, m)
            end
            mFilterText = table.concat(mList, ", ")
        end
        
        local message = "No pets match your current filters.\n\nT-Filter: " .. tFilterText ..
                       "\nM-Filter: " .. mFilterText ..
                       "\n\nContinue anyway?"
        
        return showSafetyDialog(message, function()
            -- Continue with all pets
            filteredPets = pets
        end)
    end
    
    local needed = task.completeValue - task.progress
    local sold = 0
    
    for i = 1, math.min(needed, #filteredPets, maxActionsPerSession) do
        local pet = filteredPets[i]
        
        -- Check if pet is locked
        local shouldSkip = false
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            local data = playerGui:FindFirstChild("Data")
            if data then
                local petsContainer = data:FindFirstChild("Pets")
                if petsContainer then
                    local petConfig = petsContainer:FindFirstChild(pet.uid)
                    if petConfig and petConfig:GetAttribute("LK") == 1 then
            -- Skip locked pets
                        shouldSkip = true
                    end
                end
            end
        end
        
        if not shouldSkip then
            -- Sell pet
            local sellSuccess = pcall(function()
                local args = { "Sell", pet.uid }
                ReplicatedStorage:WaitForChild("Remote"):WaitForChild("PetRE"):FireServer(unpack(args))
            end)
            
            if sellSuccess then
                sold = sold + 1
                WindUI:Notify({ Title = "💰 Sold Pet", Content = "Sold " .. pet.value, Duration = 2 })
            end
        end
        
        wait(0.5)
        
        if shouldRefreshInventory() then
            pets = getPetInventory()
            filteredPets = filterItemsBySelection(pets, tFilter, mFilter, getPetMutation)
        end
    end
    
    return sold > 0
end

local function executeOnlineTime(task)
    -- Online time tasks are handled by the game automatically
    -- We just need to claim when ready
    if task.progress >= task.completeValue and task.claimedCount < task.repeatCount then
        return claimTaskReward(task.id)
    end
    return false
end

-- Main quest execution loop
local function runAutoQuest()
    while autoQuestEnabled do
        local tasks = getTaskData()
        if #tasks == 0 then
            wait(5)
        else
            -- Sort tasks by priority
            table.sort(tasks, function(a, b)
                local aPriority = 999
                local bPriority = 999
                for i, priorityType in ipairs(TaskPriority) do
                    if priorityType == a.completeType then
                        aPriority = i
                    end
                    if priorityType == b.completeType then
                        bPriority = i
                    end
                end
                return aPriority < bPriority
            end)
            
            local actionTaken = false
            
            for _, task in pairs(tasks) do
                if not autoQuestEnabled then break end
                
                -- Check if task is complete
                if task.progress >= task.completeValue and task.claimedCount < task.repeatCount then
                    if claimTaskReward(task.id) then
                        WindUI:Notify({ Title = "🎉 Task Complete", Content = "Claimed reward for " .. task.id, Duration = 3 })
                        actionTaken = true
                        wait(1)
                    end
                else
                    -- Execute task based on type
                    local success = false
                    if task.completeType == "BuyMutateEgg" then
                        success = executeBuyMutateEgg(task)
                    elseif task.completeType == "HatchEgg" then
                        success = executeHatchEgg(task)
                    elseif task.completeType == "SendEgg" then
                        success = executeSendEgg(task)
                    elseif task.completeType == "SellPet" then
                        success = executeSellPet(task)
                    elseif task.completeType == "OnlineTime" then
                        success = executeOnlineTime(task)
                    end
                    
                    if success then
                        actionTaken = true
                        wait(1)
                    end
                end
            end
            
            if not actionTaken then
                wait(3)
            end
            
            -- Update status
            updateQuestStatus()
        end
    end
end

-- Initialize function
function AutoQuestSystem.Init(dependencies)
    WindUI = dependencies.WindUI
    Window = dependencies.Window
    Config = dependencies.Config
    waitForSettingsReady = dependencies.waitForSettingsReady
    
    -- Get integration references
    autoBuyEnabled = dependencies.autoBuyEnabled
    autoPlaceEnabled = dependencies.autoPlaceEnabled
    autoHatchEnabled = dependencies.autoHatchEnabled
    setAutoBuyEnabled = dependencies.setAutoBuyEnabled
    setAutoPlaceEnabled = dependencies.setAutoPlaceEnabled
    setAutoHatchEnabled = dependencies.setAutoHatchEnabled
    autoBuyToggle = dependencies.autoBuyToggle
    autoPlaceToggle = dependencies.autoPlaceToggle
    autoHatchToggle = dependencies.autoHatchToggle
    
    -- Create Quest tab
    local QuestTab = Window:Tab({ Title = "📝 | Auto Quest" })
    
    -- Create UI elements
    autoQuestToggle = QuestTab:Toggle({
        Title = "📝 Auto Quest",
        Desc = "Automatically complete daily tasks and claim rewards",
        Value = false,
        Callback = function(state)
            autoQuestEnabled = state
            
            waitForSettingsReady(0.2)
            if state and not autoQuestThread then
                autoQuestThread = spawn(function()
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
        Desc = "Select player to send eggs to",
        Values = getPlayerList(),
        Value = {},
        Multi = false,
        AllowNone = false,
        Callback = function(selection)
            -- Selection handled in getTargetPlayer()
        end
    })
    
    -- Send Egg filters
    sendEggTFilterDropdown = QuestTab:Dropdown({
        Title = "🥚 Send Egg T-Filter",
        Desc = "Exclude these egg types from sending (leave empty to send all)",
        Values = {"BasicEgg", "RareEgg", "SuperRareEgg", "EpicEgg", "LegendEgg", "PrismaticEgg", "HyperEgg", "VoidEgg", "BowserEgg", "DemonEgg", "BoneDragonEgg", "UltraEgg", "DinoEgg", "FlyEgg", "UnicornEgg", "AncientEgg"},
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            -- Selection handled in executeSendEgg()
        end
    })
    
    sendEggMFilterDropdown = QuestTab:Dropdown({
        Title = "🧬 Send Egg M-Filter",
        Desc = "Exclude these mutations from sending (leave empty to send all)",
        Values = {"Golden", "Diamond", "Electric", "Fire", "Jurassic"},
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            -- Selection handled in executeSendEgg()
        end
    })
    
    -- Sell Pet filters
    sellPetTFilterDropdown = QuestTab:Dropdown({
        Title = "🐾 Sell Pet T-Filter",
        Desc = "Exclude these pet types from selling (leave empty to sell all)",
        Values = {"BasicEgg", "RareEgg", "SuperRareEgg", "EpicEgg", "LegendEgg", "PrismaticEgg", "HyperEgg", "VoidEgg", "BowserEgg", "DemonEgg", "BoneDragonEgg", "UltraEgg", "DinoEgg", "FlyEgg", "UnicornEgg", "AncientEgg"},
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            -- Selection handled in executeSellPet()
        end
    })
    
    sellPetMFilterDropdown = QuestTab:Dropdown({
        Title = "🧬 Sell Pet M-Filter",
        Desc = "Exclude these mutations from selling (leave empty to sell all)",
        Values = {"Golden", "Diamond", "Electric", "Fire", "Jurassic"},
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            -- Selection handled in executeSellPet()
        end
    })
    
    -- Status display
    questStatusParagraph = QuestTab:Paragraph({
        Title = "📊 Quest Status",
        Desc = "No active tasks found",
        Image = "activity",
        ImageSize = 22
    })
    
    -- Control toggles
    claimAllToggle = QuestTab:Toggle({
        Title = "🎉 Claim All Ready",
        Desc = "Automatically claim all completed tasks",
        Value = false,
        Callback = function(state)
            if state then
                local tasks = getTaskData()
                local claimed = 0
                for _, task in pairs(tasks) do
                    if task.progress >= task.completeValue and task.claimedCount < task.repeatCount then
                        if claimTaskReward(task.id) then
                            claimed = claimed + 1
                        end
                        wait(0.5)
                    end
                end
                WindUI:Notify({ Title = "🎉 Claim All", Content = "Claimed " .. claimed .. " tasks!", Duration = 3 })
                claimAllToggle:SetValue(false)
            end
        end
    })
    
    refreshTasksToggle = QuestTab:Toggle({
        Title = "🔄 Refresh Tasks",
        Desc = "Refresh task status and update display",
        Value = false,
        Callback = function(state)
            if state then
                updateQuestStatus()
                refreshTasksToggle:SetValue(false)
            end
        end
    })
    
    -- Manual buttons
    QuestTab:Button({
        Title = "🔄 Refresh Player List",
        Desc = "Update the target player dropdown with current players",
        Callback = function()
            if targetPlayerDropdown then
                targetPlayerDropdown:Refresh(getPlayerList())
            end
        end
    })
    
    QuestTab:Button({
        Title = "🛑 Emergency Stop",
        Desc = "Immediately stop all quest actions",
        Callback = function()
            autoQuestEnabled = false
            if autoQuestThread then
                autoQuestThread = nil
            end
            WindUI:Notify({ Title = "🛑 Emergency Stop", Content = "All quest actions stopped", Duration = 3 })
        end
    })
    
    -- Register with config
    if Config then
        Config:Register("autoQuestEnabled", autoQuestToggle)
        Config:Register("targetPlayerDropdown", targetPlayerDropdown)
        Config:Register("sendEggTFilterDropdown", sendEggTFilterDropdown)
        Config:Register("sendEggMFilterDropdown", sendEggMFilterDropdown)
        Config:Register("sellPetTFilterDropdown", sellPetTFilterDropdown)
        Config:Register("sellPetMFilterDropdown", sellPetMFilterDropdown)
        Config:Register("claimAllToggle", claimAllToggle)
        Config:Register("refreshTasksToggle", refreshTasksToggle)
    end
    
    -- Start status update loop
    spawn(function()
        while true do
            if autoQuestEnabled then
                updateQuestStatus()
            end
            wait(5)
        end
    end)
    
    return AutoQuestSystem
end

return AutoQuestSystem
