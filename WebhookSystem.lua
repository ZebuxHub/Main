-- WebhookSystem.lua
-- Discord Webhook Integration for Build A Zoo

local WebhookSystem = {}

-- Dependencies (injected from main script)
local WindUI
local Window
local Config
local Tab

-- State variables
local webhookUrl = ""
local autoAlertEnabled = false
local autoAlertThread = nil

-- Session tracking
local sessionStats = {
    tradesCompleted = 0,
    desiredEggsFound = 0,
    desiredPetsFound = 0,
    desiredFruitsFound = 0,
    sessionStart = os.time()
}

-- Trade tracking
local tradeTracking = {
    isMonitoring = false,
    currentTrade = nil,
    tradeConnection = nil,
    sessionTradeCount = 0,
    maxSessionTrades = 10
}

-- Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- Helper function to format numbers
local function formatNumber(num)
    if type(num) == "string" then
        num = tonumber(num) or 0
    end
    
    if num >= 1e12 then
        return string.format("%.2fT", num / 1e12)
    elseif num >= 1e9 then
        return string.format("%.2fB", num / 1e9)
    elseif num >= 1e6 then
        return string.format("%.2fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.2fK", num / 1e3)
    else
        return tostring(math.floor(num))
    end
end

-- Helper function to get player net worth
local function getPlayerNetWorth()
    if not LocalPlayer then return 0 end
    local attrValue = LocalPlayer:GetAttribute("NetWorth")
    if type(attrValue) == "number" then return attrValue end
    if type(attrValue) == "string" then return tonumber(attrValue) or 0 end
    return 0
end

-- Helper function to get player tickets
local function getPlayerTickets()
    if not LocalPlayer then return 0 end
    local attrValue = LocalPlayer:GetAttribute("Ticket")
    if type(attrValue) == "number" then return attrValue end
    if type(attrValue) == "string" then return tonumber(attrValue) or 0 end
    return 0
end

-- Function to get fruit inventory (based on FeedFruitSelection.lua)
local function getFruitInventory()
    local fruits = {}
    
    if not LocalPlayer then return fruits end
    
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return fruits end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return fruits end
    
    local asset = data:FindFirstChild("Asset")
    if not asset then return fruits end
    
    -- Hardcoded fruit data for mapping (from FeedFruitSelection.lua)
    local FruitData = {
        Strawberry = { Name = "Strawberry" },
        Blueberry = { Name = "Blueberry" },
        Watermelon = { Name = "Watermelon" },
        Apple = { Name = "Apple" },
        Orange = { Name = "Orange" },
        Corn = { Name = "Corn" },
        Banana = { Name = "Banana" },
        Grape = { Name = "Grape" },
        Pear = { Name = "Pear" },
        Pineapple = { Name = "Pineapple" },
        GoldMango = { Name = "Gold Mango" },
        BloodstoneCycad = { Name = "Bloodstone Cycad" },
        ColossalPinecone = { Name = "Colossal Pinecone" },
        VoltGinkgo = { Name = "Volt Ginkgo" },
        DeepseaPearlFruit = { Name = "DeepseaPearlFruit" }
    }
    
    -- Name normalization helper
    local function normalizeFruitName(name)
        if type(name) ~= "string" then return "" end
        local lowered = string.lower(name)
        lowered = lowered:gsub("[%s_%-%./]", "")
        return lowered
    end
    
    -- Build canonical name map
    local FRUIT_CANONICAL = {}
    for id, item in pairs(FruitData) do
        local display = item.Name or id
        FRUIT_CANONICAL[normalizeFruitName(id)] = display
        FRUIT_CANONICAL[normalizeFruitName(display)] = display
    end
    
    -- Read from Attributes on Asset (primary source)
    local attrMap = {}
    local ok, attrs = pcall(function()
        return asset:GetAttributes()
    end)
    if ok and type(attrs) == "table" then
        attrMap = attrs
    end
    
    for id, item in pairs(FruitData) do
        local display = item.Name or id
        local amount = attrMap[display] or attrMap[id]
        if amount == nil then
            -- Fallback by normalized key search
            local wantA, wantB = normalizeFruitName(display), normalizeFruitName(id)
            for k, v in pairs(attrMap) do
                local nk = normalizeFruitName(k)
                if nk == wantA or nk == wantB then
                    amount = v
                    break
                end
            end
        end
        if type(amount) == "string" then amount = tonumber(amount) or 0 end
        if type(amount) == "number" and amount > 0 then
            fruits[display] = amount
        end
    end
    
    -- Also support legacy children-based values as fallback/merge
    for _, child in pairs(asset:GetChildren()) do
        if child:IsA("StringValue") or child:IsA("IntValue") or child:IsA("NumberValue") then
            local normalized = normalizeFruitName(child.Name)
            local canonical = FRUIT_CANONICAL and FRUIT_CANONICAL[normalized]
            if canonical then
                local amount = child.Value
                if type(amount) == "string" then amount = tonumber(amount) or 0 end
                if type(amount) == "number" and amount > 0 then
                    fruits[canonical] = amount
                end
            end
        end
    end
    
    return fruits
end

-- Function to get pet inventory (only pets without D attribute - unplaced pets)
local function getPetInventory()
    local pets = {}
    
    if not LocalPlayer then return pets end
    
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return pets end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return pets end
    
    local petContainer = data:FindFirstChild("Pets")
    if not petContainer then return pets end
    
    for _, child in ipairs(petContainer:GetChildren()) do
        -- Scan ALL Configuration objects
        if child:IsA("Configuration") then
            local dAttr = child:GetAttribute("D")
            local petType = child:GetAttribute("T")
            local mutation = child:GetAttribute("M")
            
            -- Only count pets WITHOUT D attribute (unplaced pets)
            if not dAttr and petType then
                -- Handle Dino -> Jurassic conversion
                if mutation == "Dino" then
                    mutation = "Jurassic"
                end
                
                if not pets[petType] then
                    pets[petType] = {
                        total = 0,
                        mutations = {}
                    }
                end
                
                pets[petType].total = pets[petType].total + 1
                
                if mutation then
                    if not pets[petType].mutations[mutation] then
                        pets[petType].mutations[mutation] = 0
                    end
                    pets[petType].mutations[mutation] = pets[petType].mutations[mutation] + 1
                end
            end
        end
    end
    
    return pets
end

-- Function to get egg inventory (only eggs without D attribute - unhatched eggs)
local function getEggInventory()
    local eggs = {}
    
    if not LocalPlayer then return eggs end
    
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return eggs end
    
    local data = playerGui:FindFirstChild("Data")
    if not data then return eggs end
    
    local eggContainer = data:FindFirstChild("Egg")
    if not eggContainer then return eggs end
    
    for _, child in ipairs(eggContainer:GetChildren()) do
        -- Scan ALL Configuration objects
        if child:IsA("Configuration") then
            local dAttr = child:GetAttribute("D")
            local eggType = child:GetAttribute("T")
            local mutation = child:GetAttribute("M")
            
            -- Only count eggs WITHOUT D attribute (unhatched eggs)
            if not dAttr and eggType then
                -- Handle Dino -> Jurassic conversion
                if mutation == "Dino" then
                    mutation = "Jurassic"
                end
                
                if not eggs[eggType] then
                    eggs[eggType] = {
                        total = 0,
                        mutations = {}
                    }
                end
                
                eggs[eggType].total = eggs[eggType].total + 1
                
                if mutation then
                    if not eggs[eggType].mutations[mutation] then
                        eggs[eggType].mutations[mutation] = 0
                    end
                    eggs[eggType].mutations[mutation] = eggs[eggType].mutations[mutation] + 1
                end
            end
        end
    end
    
    return eggs
end

-- Function to create inventory embed
local function createInventoryEmbed()
    local netWorth = getPlayerNetWorth()
    local tickets = getPlayerTickets()
    local username = LocalPlayer and LocalPlayer.Name or "Unknown"
    
    -- Get inventories
    local fruits = getFruitInventory()
    local pets = getPetInventory()
    local eggs = getEggInventory()
    
    -- Build fruit field
    local fruitValue = ""
    local fruitCount = 0
    local fruitLines = {}
    local currentLine = ""
    
    -- Fruit emojis mapping (using provided format)
    local fruitEmojis = {
        Apple = "<:Apple:1414278364042232040>",
        Banana = "<:Banana:1414278394849267823>",
        Blueberry = "<:Blueberry:1414278423119007744>",
        Watermelon = "<:Watermelon:1414278523903803402>",
        Strawberry = "<:Strawberry:1414278519382605874>",
        Orange = "<:Orange:1414278509769261219>",
        Corn = "<:Corn:1414278452315684954>",
        Pear = "<:Pear:1414278513632219256>",
        Pineapple = "<:Pineapple:1414278517302100008>",
        Grape = "<:Grape:1414278507005083849>",
        ["Gold Mango"] = "<:GoldMango:1414278503440060516>",
        GoldMango = "<:GoldMango:1414278503440060516>",
        ["Bloodstone Cycad"] = "<:BloodstoneCycad:1414278408988528725>",
        BloodstoneCycad = "<:BloodstoneCycad:1414278408988528725>",
        ["Colossal Pinecone"] = "<:ColossalPinecone:1414278437052616865>",
        ColossalPinecone = "<:ColossalPinecone:1414278437052616865>",
        ["Volt Ginkgo"] = "<:VoltGinkgo:1414278521681088543>",
        VoltGinkgo = "<:VoltGinkgo:1414278521681088543>",
        DeepseaPearlFruit = "<:DeepseaPearlFruit:1414278482913005598>"
    }
    
    -- Sort fruits for consistent display
    local sortedFruits = {}
    for fruitName, count in pairs(fruits) do
        table.insert(sortedFruits, {name = fruitName, count = count})
    end
    table.sort(sortedFruits, function(a, b) return a.count > b.count end)
    
    local itemsInCurrentLine = 0
    
    for _, fruitData in ipairs(sortedFruits) do
        local fruitName = fruitData.name
        local count = fruitData.count
        local emoji = fruitEmojis[fruitName] or "🍎"
        local fruitText = emoji .. " `" .. count .. "`"
        
        -- Add to current line
        if currentLine ~= "" then
            currentLine = currentLine .. "  "
        end
        currentLine = currentLine .. fruitText
        itemsInCurrentLine = itemsInCurrentLine + 1
        
        -- Break line every 5 fruits
        if itemsInCurrentLine == 5 then
            table.insert(fruitLines, currentLine)
            currentLine = ""
            itemsInCurrentLine = 0
            
            -- Add empty line after every 2 rows (10 fruits total)
            if #fruitLines % 2 == 0 and fruitCount + 1 < #sortedFruits then
                table.insert(fruitLines, "")
            end
        end
        
        fruitCount = fruitCount + 1
    end
    
    if currentLine ~= "" then
        table.insert(fruitLines, currentLine)
    end
    
    fruitValue = table.concat(fruitLines, "\n")
    if fruitValue == "" then fruitValue = "No fruits found" end
    
    -- Build pet field
    local petValue = "```diff\n"
    local petCount = 0
    for petType, petData in pairs(pets) do
        if petCount >= 5 then break end -- Limit to top 5 pets
        
        petValue = petValue .. "🐾 " .. petType .. " × " .. petData.total .. "\n"
        
        -- Add mutations
        for mutation, count in pairs(petData.mutations) do
            local mutationIcon = "🧬"
            if mutation == "Fire" then mutationIcon = "🔥"
            elseif mutation == "Electric" then mutationIcon = "⚡"
            end
            petValue = petValue .. "L " .. mutationIcon .. " " .. mutation .. " × " .. count .. "\n"
        end
        
        petValue = petValue .. "\n"
        petCount = petCount + 1
    end
    petValue = petValue .. "```"
    
    if petCount == 0 then
        petValue = "```diff\nNo pets found```"
    end
    
    -- Build egg field
    local eggValue = "```diff\n"
    local eggCount = 0
    for eggType, eggData in pairs(eggs) do
        if eggCount >= 2 then break end -- Limit to top 2 eggs
        
        eggValue = eggValue .. "🏆 " .. eggType .. " × " .. eggData.total .. "\n"
        
        -- Add mutations
        for mutation, count in pairs(eggData.mutations) do
            local mutationIcon = "🧬"
            if mutation == "Fire" then mutationIcon = "🔥"
            elseif mutation == "Electric" then mutationIcon = "⚡"
            end
            eggValue = eggValue .. "L " .. mutationIcon .. " " .. mutation .. " × " .. count .. "\n"
        end
        
        eggValue = eggValue .. "\n"
        eggCount = eggCount + 1
    end
    eggValue = eggValue .. "```"
    
    if eggCount == 0 then
        eggValue = "```diff\nNo eggs found```"
    end
    
    -- Create embed
    local embed = {
        content = nil,
        embeds = {
            {
                title = "📊 Inventory Snapshot",
                color = 16761095,
                fields = {
                    {
                        name = "User: " .. username,
                        value = "💰 Net Worth:  `" .. formatNumber(netWorth) .. "`\n<:Ticket:1414283452659798167> Ticket: `" .. formatNumber(tickets) .. "`"
                    },
                    {
                        name = "🪣 Fruits",
                        value = fruitValue,
                    },
                    {
                        name = "🐾 Pets",
                        value = petValue,
                        inline = true
                    },
                    {
                        name = "🥚 Top Eggs",
                        value = eggValue,
                        inline = true
                    }
                },
                footer = {
                    text = "Generated • Build A Zoo"
                }
            }
        },
        attachments = {}
    }
    
    return embed
end

-- Function to send webhook
local function sendWebhook(embedData)
    
    if not webhookUrl or webhookUrl == "" then
        WindUI:Notify({
            Title = "Webhook Error",
            Content = "No webhook URL configured - Please enter your Discord webhook URL first",
            Duration = 5
        })
        return false
    end
    
    
    -- Try different methods to send HTTP request
    local success, result = false, "No method available"
    
    -- Method 1: Try HttpService (works in Studio/some executors)
    if not success then
        success, result = pcall(function()
            return game:GetService("HttpService"):PostAsync(webhookUrl, game:GetService("HttpService"):JSONEncode(embedData), Enum.HttpContentType.ApplicationJson)
        end)
    end
    
    -- Method 2: Try request function (common in executors)
    if not success and _G.request then
        success, result = pcall(function()
            return _G.request({
                Url = webhookUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = game:GetService("HttpService"):JSONEncode(embedData)
            })
        end)
    end
    
    -- Method 3: Try syn.request (Synapse X)
    if not success and syn and syn.request then
        success, result = pcall(function()
            return syn.request({
                Url = webhookUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = game:GetService("HttpService"):JSONEncode(embedData)
            })
        end)
    end
    
    -- Method 4: Try http_request (common executor function)
    if not success and http_request then
        success, result = pcall(function()
            local response = http_request({
                Url = webhookUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = game:GetService("HttpService"):JSONEncode(embedData)
            })
            return response
        end)
        if success and result then
            -- Consider 200-299 status codes as success
            if result.StatusCode and result.StatusCode >= 200 and result.StatusCode < 300 then
                success = true
            else
                success = false
                result = "HTTP Error: " .. (result.StatusCode or "unknown status")
            end
        else
        end
    end
    
    
    if success then
        WindUI:Notify({
            Title = "Webhook Sent",
            Content = "Message sent to Discord successfully! 🎉",
            Duration = 3
        })
        return true
    else
        WindUI:Notify({
            Title = "Webhook Failed",
            Content = "Failed to send: " .. tostring(result),
            Duration = 5
        })
        return false
    end
end

-- Function to send inventory
local function sendInventory()
    local embedData = createInventoryEmbed()
    sendWebhook(embedData)
end

-- Function to create alert embed
local function createAlertEmbed(alertType, details)
    local username = LocalPlayer and LocalPlayer.Name or "Unknown"
    local sessionTime = os.time() - sessionStats.sessionStart
    local sessionText = sessionTime < 60 and (sessionTime .. "s") or (math.floor(sessionTime/60) .. "m")
    
    local embed = {
        content = nil,
        embeds = {
            {
                title = "🚨 Alert: " .. alertType,
                color = 3447003, -- Blue color
                fields = {
                    {
                        name = "User: " .. username,
                        value = details
                    },
                    {
                        name = "📊 Session Stats",
                        value = "🔄 Trades: `" .. sessionStats.tradesCompleted .. "`\n" ..
                               "🥚 Desired Eggs: `" .. sessionStats.desiredEggsFound .. "`\n" ..
                               "🐾 Desired Pets: `" .. sessionStats.desiredPetsFound .. "`\n" ..
                               "🍎 Desired Fruits: `" .. sessionStats.desiredFruitsFound .. "`\n" ..
                               "⏱️ Session: `" .. sessionText .. "`"
                    }
                },
                footer = {
                    text = "Auto Alert • Build A Zoo"
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        },
        attachments = {}
    }
    
    return embed
end

-- Function to send alert
local function sendAlert(alertType, details)
    if not autoAlertEnabled or not webhookUrl or webhookUrl == "" then
        return
    end
    
    local embedData = createAlertEmbed(alertType, details)
    
    local success, result = pcall(function()
        return game:GetService("HttpService"):PostAsync(webhookUrl, HttpService:JSONEncode(embedData), Enum.HttpContentType.ApplicationJson)
    end)
    
    if not success then
        print("Alert webhook failed:", result)
    end
end

-- Function to create trade completion embed
local function createTradeEmbed(fromPlayer, toPlayer, fromItems, toItems)
    local tradeCount = tradeTracking.sessionTradeCount
    local maxTrades = tradeTracking.maxSessionTrades
    
    -- Build items text for "From" player
    local fromValue = "```diff\n"
    for _, item in ipairs(fromItems) do
        local icon = "🐾"
        if string.find(item.type or "", "Egg") then
            icon = "🥚"
        end
        fromValue = fromValue .. icon .. " " .. (item.type or "Unknown") .. " × " .. (item.count or 1) .. "\n"
    end
    fromValue = fromValue .. "```"
    
    -- Build items text for "To" player
    local toValue = "```diff\n"
    for _, item in ipairs(toItems) do
        local icon = "🐾"
        if string.find(item.type or "", "Egg") then
            icon = "🥚"
        end
        toValue = toValue .. icon .. " " .. (item.type or "Unknown") .. " × " .. (item.count or 1) .. "\n"
    end
    toValue = toValue .. "```"
    
    -- Create embed with exact format
    local embed = {
        content = nil,
        embeds = {
            {
                title = "🤝 Trade Completed (" .. tradeCount .. "/" .. maxTrades .. ")",
                color = 3447003,
                fields = {
                    {
                        name = "📤 From: " .. (fromPlayer or "Unknown"),
                        value = fromValue,
                        inline = true
                    },
                    {
                        name = "📥 To: " .. (toPlayer or "Unknown"),
                        value = toValue,
                        inline = true
                    }
                },
                footer = {
                    text = "Trade completed • " .. os.date("%B %d, %Y at %I:%M %p")
                }
            }
        },
        attachments = {}
    }
    
    return embed
end

-- Function to send trade completion webhook
local function sendTradeWebhook(fromPlayer, toPlayer, fromItems, toItems)
    if not webhookUrl or webhookUrl == "" then
        return
    end
    
    local embedData = createTradeEmbed(fromPlayer, toPlayer, fromItems, toItems)
    sendWebhook(embedData)
end

-- Function to detect and parse trade completion
local function detectTradeCompletion()
    -- Monitor for trade completion events
    -- This will need to be adapted based on the specific game's trade system
    
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    
    -- Look for trade-related RemoteEvents or signals
    local function onTradeCompleted(tradeData)
        if not tradeData then return end
        
        -- Increment session trade count
        tradeTracking.sessionTradeCount = tradeTracking.sessionTradeCount + 1
        sessionStats.tradesCompleted = sessionStats.tradesCompleted + 1
        
        -- Parse trade data (this will need to be adapted to the game's format)
        local fromPlayer = tradeData.fromPlayer or LocalPlayer.Name
        local toPlayer = tradeData.toPlayer or "Unknown"
        local fromItems = tradeData.fromItems or {}
        local toItems = tradeData.toItems or {}
        
        -- Send webhook notification
        sendTradeWebhook(fromPlayer, toPlayer, fromItems, toItems)
    end
    
    -- Monitor for trade events (this will need to be customized for the specific game)
    -- Example: Look for specific RemoteEvents or GUI changes that indicate trade completion
    
    return onTradeCompleted
end

-- Function to start trade monitoring
local function startTradeMonitoring()
    if tradeTracking.isMonitoring then return end
    
    tradeTracking.isMonitoring = true
    
    -- Set up trade detection
    local onTradeCompleted = detectTradeCompletion()
    
    -- Monitor for trade completion signals
    -- This is a placeholder - will need to be adapted to the specific game's trade system
    task.spawn(function()
        while tradeTracking.isMonitoring and autoAlertEnabled do
            -- Check for trade completion indicators
            -- This could monitor GUI changes, RemoteEvent calls, or inventory changes
            
            -- Example placeholder logic:
            -- if someTradeCompletionCondition then
            --     onTradeCompleted(tradeData)
            -- end
            
            task.wait(1) -- Check every second
        end
    end)
end

-- Function to stop trade monitoring
local function stopTradeMonitoring()
    tradeTracking.isMonitoring = false
    if tradeTracking.tradeConnection then
        tradeTracking.tradeConnection:Disconnect()
        tradeTracking.tradeConnection = nil
    end
end

-- Auto alert monitoring function
local function runAutoAlert()
    -- This would monitor for trades, desired items, etc.
    -- Implementation would depend on the game's specific events and data structure
    while autoAlertEnabled do
        -- Monitor for trade completions
        -- Monitor for desired eggs/pets/fruits
        -- Send alerts when conditions are met
        
        task.wait(5) -- Check every 5 seconds
    end
end

-- Core initialization without UI (called from main file)
function WebhookSystem.InitCore(dependencies)
    WindUI = dependencies.WindUI
    Window = dependencies.Window
    Config = dependencies.Config
    
    return WebhookSystem
end

-- Public methods for UI integration
function WebhookSystem.SetWebhookUrl(url)
    webhookUrl = url or ""
end

function WebhookSystem.SetAutoAlert(enabled)
    autoAlertEnabled = enabled
    
    if enabled then
        if not autoAlertThread then
            autoAlertThread = task.spawn(function()
                runAutoAlert()
                autoAlertThread = nil
            end)
        end
        -- Start trade monitoring when auto alert is enabled
        startTradeMonitoring()
    else
        -- Stop trade monitoring when auto alert is disabled
        stopTradeMonitoring()
    end
end

function WebhookSystem.SendInventory()
    sendInventory()
end

-- Public API functions
function WebhookSystem.SendAlert(alertType, details)
    sendAlert(alertType, details)
end

function WebhookSystem.UpdateSessionStats(statType, increment)
    increment = increment or 1
    if statType == "trades" then
        sessionStats.tradesCompleted = sessionStats.tradesCompleted + increment
    elseif statType == "eggs" then
        sessionStats.desiredEggsFound = sessionStats.desiredEggsFound + increment
    elseif statType == "pets" then
        sessionStats.desiredPetsFound = sessionStats.desiredPetsFound + increment
    elseif statType == "fruits" then
        sessionStats.desiredFruitsFound = sessionStats.desiredFruitsFound + increment
    end
end

-- Public method to manually trigger trade webhook (for external integration)
function WebhookSystem.SendTradeWebhook(fromPlayer, toPlayer, fromItems, toItems)
    if not autoAlertEnabled then return end
    
    -- Increment trade count
    tradeTracking.sessionTradeCount = tradeTracking.sessionTradeCount + 1
    sessionStats.tradesCompleted = sessionStats.tradesCompleted + 1
    
    -- Send the webhook
    sendTradeWebhook(fromPlayer, toPlayer, fromItems, toItems)
end

-- Public method to reset trade session count
function WebhookSystem.ResetTradeCount()
    tradeTracking.sessionTradeCount = 0
end

-- Public method to set max trades per session
function WebhookSystem.SetMaxTrades(maxTrades)
    tradeTracking.maxSessionTrades = maxTrades or 10
end

function WebhookSystem.GetConfigElements()
    return {
        webhookUrl = webhookUrl,
        autoAlertEnabled = autoAlertEnabled
    }
end

function WebhookSystem.LoadConfig(config)
    if config.webhookUrl then
        webhookUrl = config.webhookUrl
    end
    if config.autoAlertEnabled ~= nil then
        autoAlertEnabled = config.autoAlertEnabled
    end
end

-- Function to create UI (kept for legacy compatibility)
local function CreateUI()
    if not Tab then return end
    
    -- Legacy UI creation code removed - UI is now in main file
    -- This function is kept for backward compatibility but does nothing
end

-- Legacy initialization function (for backward compatibility)
function WebhookSystem.Init(dependencies)
    WindUI = dependencies.WindUI
    Window = dependencies.Window
    Config = dependencies.Config
    Tab = dependencies.Tab
    
    -- Only create UI if Tab is provided (legacy mode)
    if Tab then
        CreateUI()
    end
    
    return WebhookSystem
end

return WebhookSystem
