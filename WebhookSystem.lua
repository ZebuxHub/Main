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

-- Prevent duplicate session summaries
local sessionSummarySent = false

-- Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- One-time announcements to prevent spam
local dinoWorldAnnounced = false
local cerberusAnnounced = false

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
    
    -- Build pet field (top 5 sorted, with top 5 mutations)
    local petValue = "```diff\n"
    local petArr = {}
    for petType, petData in pairs(pets) do
        table.insert(petArr, { name = petType, total = petData.total or 0, mutations = petData.mutations or {} })
    end
    table.sort(petArr, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return (a.name or "") < (b.name or "")
    end)
    local pLimit = math.min(5, #petArr)
    for i = 1, pLimit do
        local it = petArr[i]
        petValue = petValue .. "🐾 " .. it.name .. " × " .. tostring(it.total or 0) .. "\n"
        local mutsArr = {}
        for m, c in pairs(it.mutations or {}) do table.insert(mutsArr, { m = m, c = c }) end
        table.sort(mutsArr, function(a, b)
            if a.c ~= b.c then return a.c > b.c end
            return (a.m or "") < (b.m or "")
        end)
        local mLimit = math.min(5, #mutsArr)
        for j = 1, mLimit do
            local mutation = mutsArr[j].m
            local count = mutsArr[j].c
            local mutationIcon = "🧬"
            if mutation == "Fire" then mutationIcon = "🔥" elseif mutation == "Electric" then mutationIcon = "⚡" end
            petValue = petValue .. "L " .. mutationIcon .. " " .. mutation .. " × " .. count .. "\n"
        end
        if i < pLimit then petValue = petValue .. "\n" end
    end
    if pLimit == 0 then
        petValue = "```diff\nNo pets found```"
    else
        petValue = petValue .. "```"
    end
    
    -- Build egg field (top 5 like pets list)
    local eggValue = "```diff\n"
    local eggArr = {}
    for eggType, eggData in pairs(eggs) do
        table.insert(eggArr, { name = eggType, total = eggData.total or 0, mutations = eggData.mutations or {} })
    end
    table.sort(eggArr, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return (a.name or "") < (b.name or "")
    end)
    local limit = math.min(5, #eggArr)
    for i = 1, limit do
        local it = eggArr[i]
        eggValue = eggValue .. "🏆 " .. it.name .. " × " .. tostring(it.total or 0) .. "\n"
        -- sort mutations by count desc then name
        local mutsArr = {}
        for m, c in pairs(it.mutations or {}) do table.insert(mutsArr, { m = m, c = c }) end
        table.sort(mutsArr, function(a, b)
            if a.c ~= b.c then return a.c > b.c end
            return (a.m or "") < (b.m or "")
        end)
        local mLimit = math.min(5, #mutsArr)
        for j = 1, mLimit do
            local mutation = mutsArr[j].m
            local count = mutsArr[j].c
            local mutationIcon = "🧬"
            if mutation == "Fire" then mutationIcon = "🔥" elseif mutation == "Electric" then mutationIcon = "⚡" end
            eggValue = eggValue .. "L " .. mutationIcon .. " " .. mutation .. " × " .. count .. "\n"
        end
        if i < limit then eggValue = eggValue .. "\n" end
    end
    if limit == 0 then
        eggValue = "```diff\nNo eggs found```"
    else
        eggValue = eggValue .. "```"
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

-- Helper: notify locally and optionally send webhook alert
local function notifyAndAlert(title, content)
	-- Local notification
	if WindUI and WindUI.Notify then
		pcall(function()
			WindUI:Notify({ Title = title, Content = content, Duration = 4 })
		end)
	end
	-- Webhook alert (only if enabled and URL set)
	if autoAlertEnabled then
		sendAlert(title, content)
	end
end

-- Monitor GameFlag for Base_DinoWorld unlock (value == 1)
local function setupDinoWorldMonitor()
	local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	local gameFlag = data and data:FindFirstChild("GameFlag")

	local function checkDinoWorld()
		if dinoWorldAnnounced then return end
		local val = nil
		if gameFlag then
			-- Prefer attribute; fallback to child ValueBase
			val = gameFlag:GetAttribute("Base_DinoWorld")
			if val == nil then
				local child = gameFlag:FindFirstChild("Base_DinoWorld")
				if child and child.Value ~= nil then
					local v = child.Value
					if type(v) == "string" then v = tonumber(v) or 0 end
					val = v
				end
			end
		end
		if type(val) == "string" then val = tonumber(val) or 0 end
		if type(val) == "number" and val >= 1 then
			dinoWorldAnnounced = true
			notifyAndAlert("🦕 Dino World Unlocked", "You got Dino World!")
		end
	end

	-- Initial check
	pcall(checkDinoWorld)

	-- Attribute change listener
	if gameFlag then
		pcall(function()
			gameFlag:GetAttributeChangedSignal("Base_DinoWorld"):Connect(checkDinoWorld)
		end)
		-- ValueBase child fallback listeners
		pcall(function()
			gameFlag.ChildAdded:Connect(function(c)
				if c and c.Name == "Base_DinoWorld" then
					if c.GetPropertyChangedSignal then
						c:GetPropertyChangedSignal("Value"):Connect(checkDinoWorld)
					end
					checkDinoWorld()
				end
			end)
		end)
	end
end

-- Monitor Data.Pets for any Configuration with attribute T == "Cerberus"
local function setupCerberusMonitor()
	local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	local petsFolder = data and data:FindFirstChild("Pets")

	local function inspectConfig(conf)
		if cerberusAnnounced then return end
		if conf and conf:IsA("Configuration") then
			local t = conf:GetAttribute("T")
			if t == "Cerberus" then
				cerberusAnnounced = true
				notifyAndAlert("🐾 Cerberus Acquired", "You obtained pet: Cerberus")
			end
		end
	end

	-- Initial scan
	if petsFolder then
		for _, ch in ipairs(petsFolder:GetChildren()) do
			inspectConfig(ch)
		end
		-- Watch for new pets
		pcall(function()
			petsFolder.ChildAdded:Connect(function(ch)
				-- Defer to allow attributes to populate
				task.defer(function()
					inspectConfig(ch)
				end)
			end)
		end)
	end
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

-- Function to create trade session summary embed
local function createTradeSessionSummaryEmbed()
    local username = LocalPlayer and LocalPlayer.Name or "Unknown"
    local sessionTime = os.time() - sessionStats.sessionStart
    local sessionText = sessionTime < 60 and (sessionTime .. "s") or (math.floor(sessionTime/60) .. "m")
    
    local embed = {
        content = nil,
        embeds = {
            {
                title = "🎯 Trade Session Completed",
                color = 65280, -- Green color
                fields = {
                    {
                        name = "User: " .. username,
                        value = "✅ **Trade session finished successfully!**\n" ..
                               "📊 **" .. tradeTracking.sessionTradeCount .. "/" .. tradeTracking.maxSessionTrades .. "** trades completed"
                    },
                    {
                        name = "📈 Session Summary",
                        value = "🔄 Total Trades: `" .. tradeTracking.sessionTradeCount .. "`\n" ..
                               "⏱️ Session Duration: `" .. sessionText .. "`\n" ..
                               "🎯 Trade Limit: `" .. tradeTracking.maxSessionTrades .. "`\n" ..
                               "✨ Status: `Session Complete`"
                    }
                },
                footer = {
                    text = "Trade Session Summary • Build A Zoo"
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        },
        attachments = {}
    }
    
    -- If a session note was provided via WebhookSystem.__sessionNote, append into fields
    if WebhookSystem.__sessionNote and type(WebhookSystem.__sessionNote) == "table" and #WebhookSystem.__sessionNote > 0 then
        for _, f in ipairs(WebhookSystem.__sessionNote) do
            table.insert(embed.embeds[1].fields, f)
        end
        WebhookSystem.__sessionNote = nil
    end
    
    return embed
end

-- Function to send trade session summary
local function sendTradeSessionSummary()
    if not webhookUrl or webhookUrl == "" then
        return
    end
    
    local embedData = createTradeSessionSummaryEmbed()
    sendWebhook(embedData)
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
    local tradeCount = math.min(tradeTracking.sessionTradeCount, tradeTracking.maxSessionTrades)
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

-- Function to detect and parse trade completion (simplified - now integrated via SendTrashSystem)
local function detectTradeCompletion()
    -- Trade detection is now handled by SendTrashSystem integration
    -- This function is kept for backward compatibility but does nothing
    local function monitorInventoryChanges()
        -- No-op: Trade detection moved to SendTrashSystem
    end
    
    return monitorInventoryChanges
end

-- Function to start trade monitoring
local function startTradeMonitoring()
    if tradeTracking.isMonitoring then return end
    
    tradeTracking.isMonitoring = true
    
    -- Set up trade detection
    local monitorInventoryChanges = detectTradeCompletion()
    
    -- Start monitoring
    task.spawn(function()
        monitorInventoryChanges()
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
    
    -- Start monitors for Dino World and Cerberus
    task.spawn(function()
        -- small delay to give UI/Data time to exist
        task.wait(1)
        pcall(setupDinoWorldMonitor)
        pcall(setupCerberusMonitor)
    end)
    
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
    
    -- Guard: do not overshoot the session limit
    if tradeTracking.sessionTradeCount >= tradeTracking.maxSessionTrades then
        return
    end
    
    -- Increment trade count
    tradeTracking.sessionTradeCount = tradeTracking.sessionTradeCount + 1
    sessionStats.tradesCompleted = sessionStats.tradesCompleted + 1
    
    -- Send the individual trade webhook
    sendTradeWebhook(fromPlayer, toPlayer, fromItems, toItems)
end

-- Public method to manually send trade session summary
function WebhookSystem.SendTradeSessionSummary(summaryLogs)
    if not autoAlertEnabled then return end
    if sessionSummarySent then return end
    -- If summaryLogs are provided, build a nicer description
    if type(summaryLogs) == "table" and #summaryLogs > 0 then
        -- Build a compact map per receiver
        local byReceiver = {}
        for _, log in ipairs(summaryLogs) do
            local recv = log.receiver or "Unknown"
            byReceiver[recv] = byReceiver[recv] or { items = {}, order = {} }
            local key = (log.type or "Unknown")
            local isEgg = (tostring(log.kind or ""):lower() == "egg") or (key:find("Egg") ~= nil)
            local icon = isEgg and "🥚" or "🐾"
            local entry = byReceiver[recv].items[key]
            if not entry then
                entry = { name = key, count = 0, icon = icon }
                byReceiver[recv].items[key] = entry
                table.insert(byReceiver[recv].order, key)
            end
            entry.count = entry.count + 1
        end
        -- Compose a short note field into the summary embed by temporarily
        -- setting a global that createTradeSessionSummaryEmbed can read.
        WebhookSystem.__sessionNote = {}
        local receiverCount = 0
        for recv, bucket in pairs(byReceiver) do
            receiverCount = receiverCount + 1
            local lines = {"```diff"}
            for _, key in ipairs(bucket.order) do
                local e = bucket.items[key]
                table.insert(lines, string.format("%s %s × %d", e.icon, e.name, e.count))
            end
            table.insert(lines, "```")
            table.insert(WebhookSystem.__sessionNote, { name = "📥 To: " .. recv, value = table.concat(lines, "\n"), inline = false })
            if receiverCount >= 2 then break end -- limit to 2 receivers for brevity
        end
    end
    sendTradeSessionSummary()
    sessionSummarySent = true
end

-- Public method to reset trade session count
function WebhookSystem.ResetTradeCount()
    tradeTracking.sessionTradeCount = 0
    sessionSummarySent = false
end

-- Public method to set max trades per session
function WebhookSystem.SetMaxTrades(maxTrades)
    tradeTracking.maxSessionTrades = maxTrades or 10
end

-- Sync counters from external systems (e.g., SendTrashSystem)
function WebhookSystem.SyncTradeCounters(currentCount, maxCount)
    if type(currentCount) == "number" then
        tradeTracking.sessionTradeCount = math.max(0, math.floor(currentCount))
    end
    if type(maxCount) == "number" then
        tradeTracking.maxSessionTrades = math.max(1, math.floor(maxCount))
    end
    if tradeTracking.sessionTradeCount < tradeTracking.maxSessionTrades then
        sessionSummarySent = false
    end
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
