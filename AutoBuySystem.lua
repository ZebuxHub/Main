-- AutoBuySystem.lua - Enhanced Auto Buy Egg System for Build A Zoo
-- Author: Zebux
-- Version: 2.0

local AutoBuySystem = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Module variables
local WindUI = nil
local Tabs = nil

-- Auto buy state
local autoBuyEnabled = false
local autoBuyThread = nil
local buyingInProgress = false
local beltConnections = {}

-- Selection sets (passed from main script)
local selectedTypeSet = {}
local selectedMutationSet = {}

-- Auto buy statistics
local autoBuyStats = {
    totalAttempts = 0,
    successfulBuys = 0,
    mutationFinds = 0,
    lastMutationFound = nil,
    lastMutationTime = 0
}

-- Helper functions (will be passed from main script)
local getPlayerNetWorth = nil
local getAssignedIslandName = nil
local getIslandBelts = nil
local getActiveBelt = nil
local getEggMutationFromGUI = nil
local getEggMutation = nil
local EggData = nil

-- Enhanced function to determine if we should buy an egg
local function shouldBuyEggInstance(eggInstance, playerMoney)
    if not eggInstance or not eggInstance:IsA("Model") then 
        return false, nil, nil, "Invalid egg instance" 
    end
    
    -- Read Type first
    local eggType = eggInstance:GetAttribute("Type")
        or eggInstance:GetAttribute("EggType")
        or eggInstance:GetAttribute("Name")
    if not eggType then 
        return false, nil, nil, "No egg type found" 
    end
    eggType = tostring(eggType)
    
    -- Check if this is the type we want
    if selectedTypeSet and next(selectedTypeSet) then
        if not selectedTypeSet[eggType] then 
            return false, nil, nil, "Egg type not selected: " .. eggType 
        end
    end
    
    -- Enhanced mutation checking
    local eggMutation = nil
    if selectedMutationSet and next(selectedMutationSet) then
        -- Try multiple methods to get mutation
        eggMutation = getEggMutationFromGUI and getEggMutationFromGUI(eggInstance.Name)
        
        if not eggMutation and getEggMutation then
            eggMutation = getEggMutation(eggInstance.Name)
        end
        
        if not eggMutation then
            return false, nil, nil, "No mutation found but mutations required"
        end
        
        if not selectedMutationSet[eggMutation] then
            return false, nil, nil, "Mutation not selected: " .. eggMutation
        end
    end

    -- Enhanced price detection
    local price = nil
    
    -- Method 1: Try hardcoded data first
    if EggData and EggData[eggType] then
        local priceStr = EggData[eggType].Price:gsub(",", "")
        price = tonumber(priceStr)
    end
    
    -- Method 2: Try instance attributes
    if not price then
        price = eggInstance:GetAttribute("Price")
    end
    
    -- Method 3: Try reading from GUI
    if not price then
        local rootPart = eggInstance:FindFirstChild("RootPart")
        if rootPart then
            local guiPaths = {"GUI/EggGUI", "EggGUI", "GUI", "Gui"}
            for _, guiPath in ipairs(guiPaths) do
                local eggGUI = rootPart:FindFirstChild(guiPath)
                if eggGUI then
                    local priceLabels = {"Price", "PriceLabel", "Cost", "CostLabel"}
                    for _, labelName in ipairs(priceLabels) do
                        local priceLabel = eggGUI:FindFirstChild(labelName)
                        if priceLabel and priceLabel:IsA("TextLabel") then
                            local priceText = priceLabel.Text
                            -- Enhanced price parsing - handle K, M, B suffixes
                            local numStr = priceText:gsub("[^%d%.KMBkmb]", "")
                            if numStr ~= "" then
                                local num = tonumber(numStr:match("([%d%.]+)"))
                                if num then
                                    local suffix = numStr:match("[KMBkmb]")
                                    if suffix then
                                        if suffix:lower() == "k" then num = num * 1000
                                        elseif suffix:lower() == "m" then num = num * 1000000
                                        elseif suffix:lower() == "b" then num = num * 1000000000
                                        end
                                    end
                                    price = num
                                    if price then break end
                                end
                            end
                        end
                    end
                    if price then break end
                end
            end
        end
    end
    
    if type(price) ~= "number" or price <= 0 then 
        return false, nil, nil, "Invalid price: " .. tostring(price) 
    end
    if playerMoney < price then 
        return false, nil, nil, "Insufficient funds: need " .. price .. ", have " .. playerMoney 
    end
    
    -- Calculate priority score
    local priorityScore = 0
    
    if eggMutation then
        priorityScore = priorityScore + 1000
        if eggMutation == "Jurassic" then priorityScore = priorityScore + 500 end
        if eggMutation == "Diamond" then priorityScore = priorityScore + 400 end
        if eggMutation == "Golden" then priorityScore = priorityScore + 300 end
    end
    
    priorityScore = priorityScore + math.max(0, 1000000 - price) / 1000
    
    return true, eggInstance.Name, price, "Valid", priorityScore, eggMutation
end

local function buyEggByUID(eggUID)
    local args = {"BuyEgg", eggUID}
    ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
end

local function focusEggByUID(eggUID)
    local args = {"Focus", eggUID}
    ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
end

local function buyEggInstantly(eggInstance)
    if buyingInProgress then return end
    buyingInProgress = true
    
    local netWorth = getPlayerNetWorth()
    local ok, uid, price, reason, priorityScore, mutation = shouldBuyEggInstance(eggInstance, netWorth)
    
    autoBuyStats.totalAttempts = autoBuyStats.totalAttempts + 1
    
    if ok then
        -- Log important finds
        if mutation then
            autoBuyStats.mutationFinds = autoBuyStats.mutationFinds + 1
            autoBuyStats.lastMutationFound = mutation
            autoBuyStats.lastMutationTime = os.time()
        end
        
        -- Enhanced retry mechanism
        local maxRetries = 5
        local retryCount = 0
        local buySuccess = false
        
        while retryCount < maxRetries and not buySuccess do
            retryCount = retryCount + 1
            
            if not eggInstance or not eggInstance.Parent then
                break
            end
            
            local stillOk, stillUid, stillPrice, stillReason, stillPriority, stillMutation = shouldBuyEggInstance(eggInstance, getPlayerNetWorth())
            if not stillOk then
                break
            end
            
            local buyResult, buyError = pcall(function()
                buyEggByUID(uid)
                focusEggByUID(uid)
            end)
            
            if buyResult then
                autoBuyStats.successfulBuys = autoBuyStats.successfulBuys + 1
                buySuccess = true
                
                if stillMutation then
                    WindUI:Notify({ 
                        Title = "🦄 Mutation Found!", 
                        Content = "Bought " .. stillMutation .. " egg for " .. stillPrice .. "!", 
                        Duration = 4 
                    })
                end
            else
                local delayTime = stillMutation and 1.0 or 0.3
                task.wait(delayTime)
            end
        end
    end
    
    buyingInProgress = false
end

-- Enhanced belt monitoring with smart prioritization
local function setupBeltMonitoring(belt)
    if not belt then return end
    
    local function onChildAdded(child)
        if not autoBuyEnabled then return end
        if child:IsA("Model") then
            task.spawn(function()
                task.wait(0.1)
                buyEggInstantly(child)
            end)
        end
    end
    
    local function checkExistingEggs()
        if not autoBuyEnabled then return end
        local children = belt:GetChildren()
        local candidates = {}
        
        for _, child in ipairs(children) do
            if child:IsA("Model") then
                local netWorth = getPlayerNetWorth()
                local ok, uid, price, reason, priorityScore, mutation = shouldBuyEggInstance(child, netWorth)
                
                if ok then
                    table.insert(candidates, {
                        instance = child,
                        uid = uid,
                        price = price,
                        priority = priorityScore or 0,
                        mutation = mutation
                    })
                end
            end
        end
        
        table.sort(candidates, function(a, b)
            return a.priority > b.priority
        end)
        
        if #candidates > 0 then
            local topCandidate = candidates[1]
            buyEggInstantly(topCandidate.instance)
        end
    end
    
    table.insert(beltConnections, belt.ChildAdded:Connect(onChildAdded))
    
    local checkThread = task.spawn(function()
        while autoBuyEnabled do
            checkExistingEggs()
            
            local checkInterval = 0.5
            if selectedMutationSet and next(selectedMutationSet) then
                checkInterval = 0.3
            end
            
            task.wait(checkInterval)
        end
    end)
    
    beltConnections[#beltConnections + 1] = { disconnect = function() 
        if checkThread then
            task.cancel(checkThread)
            checkThread = nil 
        end
    end }
end

local function cleanupBeltConnections()
    for _, connection in ipairs(beltConnections) do
        if connection.disconnect then
            connection:disconnect()
        elseif connection.Disconnect then
            connection:Disconnect()
        end
    end
    beltConnections = {}
end

local function runAutoBuy()
    while autoBuyEnabled do
        local islandName = getAssignedIslandName()

        if not islandName or islandName == "" then
            task.wait(1)
            continue
        end

        local activeBelt = getActiveBelt(islandName)
        if not activeBelt then
            task.wait(1)
            continue
        end

        cleanupBeltConnections()
        setupBeltMonitoring(activeBelt)
        
        while autoBuyEnabled do
            local currentIsland = getAssignedIslandName()
            if currentIsland ~= islandName then
                break
            end
            task.wait(0.5)
        end
    end
    
    cleanupBeltConnections()
end

-- Update stats display
local function updateAutoBuyStats()
    if not AutoBuySystem.statsLabel then return end
    
    local successRate = autoBuyStats.totalAttempts > 0 and 
        math.floor((autoBuyStats.successfulBuys / autoBuyStats.totalAttempts) * 100) or 0
    
    local lastMutationText = ""
    if autoBuyStats.lastMutationFound then
        local timeSince = os.time() - autoBuyStats.lastMutationTime
        local timeText = timeSince < 60 and (timeSince .. "s ago") or (math.floor(timeSince/60) .. "m ago")
        lastMutationText = " | 🦄 Last: " .. autoBuyStats.lastMutationFound .. " (" .. timeText .. ")"
    end
    
    local statsText = string.format("✅ Bought: %d | 📈 Rate: %d%% | 🔥 Mutations: %d%s", 
        autoBuyStats.successfulBuys, 
        successRate, 
        autoBuyStats.mutationFinds,
        lastMutationText)
    
    if AutoBuySystem.statsLabel.SetDesc then
        AutoBuySystem.statsLabel:SetDesc(statsText)
    end
end

-- Create Auto Buy UI
function AutoBuySystem.createUI()
    -- Statistics display
    AutoBuySystem.statsLabel = Tabs.AutoTab:Paragraph({
        Title = "📊 Auto Buy Statistics",
        Desc = "Starting up...",
        Image = "activity",
        ImageSize = 16,
    })

    -- Auto Buy Toggle
    AutoBuySystem.toggle = Tabs.AutoTab:Toggle({
        Title = "🥚 Auto Buy Eggs",
        Desc = "Enhanced auto buy with smart mutation detection and prioritization!",
        Value = false,
        Callback = function(state)
            autoBuyEnabled = state
            
            if state and not autoBuyThread then
                autoBuyThread = task.spawn(function()
                    runAutoBuy()
                    autoBuyThread = nil
                end)
                
                -- Start stats update loop
                task.spawn(function()
                    while autoBuyEnabled do
                        updateAutoBuyStats()
                        task.wait(2)
                    end
                end)
                
                WindUI:Notify({ Title = "🥚 Auto Buy", Content = "Enhanced system started! 🎉", Duration = 3 })
            elseif (not state) and autoBuyThread then
                cleanupBeltConnections()
                WindUI:Notify({ Title = "🥚 Auto Buy", Content = "Stopped", Duration = 3 })
            end
        end
    })

    -- Reset stats button
    Tabs.AutoTab:Button({
        Title = "🔄 Reset Auto Buy Stats",
        Desc = "Reset auto buy statistics",
        Callback = function()
            autoBuyStats = {
                totalAttempts = 0,
                successfulBuys = 0,
                mutationFinds = 0,
                lastMutationFound = nil,
                lastMutationTime = 0
            }
            updateAutoBuyStats()
            WindUI:Notify({ Title = "📊 Stats Reset", Content = "Auto buy statistics reset!", Duration = 2 })
        end
    })
    
    return AutoBuySystem.toggle
end

-- Update selection sets
function AutoBuySystem.updateSelections(typeSet, mutationSet)
    selectedTypeSet = typeSet or {}
    selectedMutationSet = mutationSet or {}
end

-- Initialize function
function AutoBuySystem.Init(dependencies)
    WindUI = dependencies.WindUI
    Tabs = dependencies.Tabs
    
    -- Set helper functions
    getPlayerNetWorth = dependencies.getPlayerNetWorth
    getAssignedIslandName = dependencies.getAssignedIslandName
    getIslandBelts = dependencies.getIslandBelts
    getActiveBelt = dependencies.getActiveBelt
    getEggMutationFromGUI = dependencies.getEggMutationFromGUI
    getEggMutation = dependencies.getEggMutation
    EggData = dependencies.EggData
    
    return AutoBuySystem
end

-- Cleanup function
function AutoBuySystem.cleanup()
    autoBuyEnabled = false
    cleanupBeltConnections()
    if autoBuyThread then
        autoBuyThread = nil
    end
end

-- Export stats for external use
function AutoBuySystem.getStats()
    return autoBuyStats
end

return AutoBuySystem
