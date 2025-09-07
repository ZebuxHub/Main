-- WebhookSystem.lua
-- Discord webhook integration for Build a Zoo automation

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local WebhookSystem = {}

-- Configuration
WebhookSystem.config = {
    url = "",
    enabled = true,
    cerberusAlert = false,
    tradeEach = false,
    tradeSummary = false,
    inventorySnapshot = false
}

-- Emoji mappings for fruits and items
WebhookSystem.emojis = {
    -- Fruits
    Strawberry = "<:Strawberry:1414278519382605874>",
    Blueberry = "<:Blueberry:1414278423119007744>",
    Watermelon = "<:Watermelon:1414278523903803402>",
    Apple = "<:Apple:1414278364042232040>",
    Orange = "<:Orange:1414278509769261219>",
    Corn = "<:Corn:1414278452315684954>",
    Banana = "<:Banana:1414278394849267823>",
    Grape = "<:Grape:1414278507005083849>",
    Pear = "<:Pear:1414278513632219256>",
    Pineapple = "<:Pineapple:1414278517302100008>",
    GoldMango = "<:GoldMango:1414278503440060516>",
    BloodstoneCycad = "<:BloodstoneCycad:1414278408988528725>",
    ColossalPinecone = "<:ColossalPinecone:1414278437052616865>",
    VoltGinkgo = "<:VoltGinkgo:1414278521681088543>",
    DeepseaPearlFruit = "<:DeepseaPearlFruit:1414278482913005598>",
    
    -- Other items
    Ticket = "<:Ticket:1414283452659798167>",
    
    -- Pet emojis
    Mouse = "🐾",
    Rabbit = "🐾",
    Toucan = "🐾",
    Fox = "🐾",
    Bighead = "🐾",
    
    -- Egg emojis
    RareEgg = "🥚",
    EpicEgg = "🥚",
    LionfishEgg = "🏆",
    SharkEgg = "🏆",
    
    -- Mutation emojis
    Golden = "🧬",
    Diamond = "🧬",
    Dino = "🧬",
    Electric = "⚡",
    Fire = "🔥"
}

-- Internal state
WebhookSystem.cerbNotifiedUID = {}
WebhookSystem.cerbConnection = nil
WebhookSystem.tradeLog = {}
WebhookSystem.sessionStartTime = 0

-- Utility functions
function WebhookSystem:getRequestFunction()
    local req = (http_request or request or (syn and syn.request) or (krnl and krnl.request) or (fluxus and fluxus.request) or (http and http.request))
    return req
end

function WebhookSystem:sendPayload(payload)
    if not self.config.url or self.config.url == "" then return false, "No URL" end
    local req = self:getRequestFunction()
    if not req then return false, "No request function" end
    
    local ok, res = pcall(function()
        return req({
            Url = self.config.url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    return ok == true, res
end

function WebhookSystem:sendText(text)
    local content = tostring(text or "")
    if #content > 1900 then content = content:sub(1, 1900) .. "..." end
    return self:sendPayload({ content = content })
end

function WebhookSystem:sendEmbed(embed)
    return self:sendPayload({ embeds = { embed } })
end

-- Get player data
function WebhookSystem:getPlayerData()
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = pg and pg:FindFirstChild("Data")
    return data
end

function WebhookSystem:getNetWorth()
    local lp = LocalPlayer
    if not lp then return 0 end
    local a = lp:GetAttribute("NetWorth")
    if type(a) == "number" then return a end
    local ls = lp:FindFirstChild("leaderstats")
    if ls then
        local nv = ls:FindFirstChild("NetWorth")
        if nv and type(nv.Value) == "number" then return nv.Value end
    end
    return 0
end

function WebhookSystem:formatNumber(num)
    if not num or num == 0 then return "0" end
    if num >= 1e12 then return string.format("%.2fT", num / 1e12)
    elseif num >= 1e9 then return string.format("%.2fB", num / 1e9)
    elseif num >= 1e6 then return string.format("%.2fM", num / 1e6)
    elseif num >= 1e3 then return string.format("%.2fK", num / 1e3)
    else return tostring(math.floor(num)) end
end

-- Inventory snapshot
function WebhookSystem:getFruitInventory()
    local data = self:getPlayerData()
    local asset = data and data:FindFirstChild("Asset")
    if not asset then 
        print("❌ Asset folder not found!")
        return {} 
    end
    
    local fruits = {}
    local fruitNames = {"Strawberry", "Blueberry", "Watermelon", "Apple", "Orange", "Corn", "Banana", "Grape", "Pear", "Pineapple", "GoldMango", "BloodstoneCycad", "ColossalPinecone", "VoltGinkgo", "DeepseaPearlFruit"}
    
    for _, fruitName in ipairs(fruitNames) do
        local count = asset:GetAttribute(fruitName) or 0
        if count > 0 then
            fruits[fruitName] = count
            print("🍎 Found " .. fruitName .. ": " .. count)
        end
    end
    
    print("📊 Total fruits found: " .. #fruits)
    return fruits
end

function WebhookSystem:getTicketCount()
    local data = self:getPlayerData()
    local asset = data and data:FindFirstChild("Asset")
    if not asset then return 0 end
    return asset:GetAttribute("LotteryTicket") or 0
end

function WebhookSystem:getPetInventory()
    local data = self:getPlayerData()
    local pets = data and data:FindFirstChild("Pets")
    if not pets then 
        print("❌ Pets folder not found!")
        return {} 
    end
    
    local petCounts = {}
    for _, petNode in ipairs(pets:GetChildren()) do
        if petNode:IsA("Configuration") then
            local attrs = petNode:GetAttributes()
            local petType = attrs.T or "Unknown"
            local mutation = attrs.M
            if mutation == "Dino" then mutation = "Jurassic" end
            
            local key = petType .. (mutation and (" [" .. mutation .. "]") or "")
            petCounts[key] = (petCounts[key] or 0) + 1
        end
    end
    
    print("🐾 Total pet types found: " .. #petCounts)
    return petCounts
end

function WebhookSystem:getEggInventory()
    local data = self:getPlayerData()
    local eggs = data and data:FindFirstChild("Egg")
    if not eggs then 
        print("❌ Egg folder not found!")
        return {} 
    end
    
    local eggCounts = {}
    for _, eggNode in ipairs(eggs:GetChildren()) do
        if eggNode:IsA("Configuration") then
            local attrs = eggNode:GetAttributes()
            local eggType = attrs.T or "Unknown"
            local mutation = attrs.M
            if mutation == "Dino" then mutation = "Jurassic" end
            
            local key = eggType .. (mutation and (" [" .. mutation .. "]") or "")
            eggCounts[key] = (eggCounts[key] or 0) + 1
        end
    end
    
    print("🥚 Total egg types found: " .. #eggCounts)
    return eggCounts
end

function WebhookSystem:formatFruitLine(fruits)
    local lines = {}
    local line1 = {}
    local line2 = {}
    local line3 = {}
    
    local fruitOrder = {"Strawberry", "Blueberry", "Watermelon", "Apple", "Orange", "Corn", "Banana", "Grape", "Pear", "Pineapple", "GoldMango", "BloodstoneCycad", "ColossalPinecone", "VoltGinkgo", "DeepseaPearlFruit"}
    
    for i, fruitName in ipairs(fruitOrder) do
        local count = fruits[fruitName] or 0
        if count > 0 then
            local emoji = self.emojis[fruitName] or "🍎"
            local item = emoji .. " `" .. tostring(count) .. "`"
            
            if i <= 5 then
                table.insert(line1, item)
            elseif i <= 10 then
                table.insert(line2, item)
            else
                table.insert(line3, item)
            end
        end
    end
    
    if #line1 > 0 then table.insert(lines, table.concat(line1, "  ")) end
    if #line2 > 0 then table.insert(lines, table.concat(line2, "  ")) end
    if #line3 > 0 then table.insert(lines, table.concat(line3, "  ")) end
    
    return table.concat(lines, "\n\n")
end

function WebhookSystem:formatPetLine(pets, limit)
    local lines = {}
    local sorted = {}
    
    for pet, count in pairs(pets) do
        table.insert(sorted, {pet = pet, count = count})
    end
    
    table.sort(sorted, function(a, b) return a.count > b.count end)
    
    local current = 1
    for _, item in ipairs(sorted) do
        if current > (limit or 20) then break end
        
        local petName = item.pet:match("^([^%[]+)")
        local mutation = item.pet:match("%[([^%]]+)%]")
        local emoji = self.emojis[petName] or "🐾"
        local mutEmoji = self.emojis[mutation] or "🧬"
        
        local line = emoji .. " " .. petName .. " × " .. item.count
        if mutation then
            line = line .. "\nL " .. mutEmoji .. " " .. mutation .. " × " .. item.count
        end
        
        table.insert(lines, line)
        current = current + 1
    end
    
    return table.concat(lines, "\n")
end

function WebhookSystem:sendInventorySnapshot()
    if not self.config.url or self.config.url == "" then
        print("❌ Webhook URL not set!")
        return false, "No webhook URL"
    end
    
    local netWorth = self:getNetWorth()
    local ticketCount = self:getTicketCount()
    local fruits = self:getFruitInventory()
    local pets = self:getPetInventory()
    local eggs = self:getEggInventory()
    
    local netWorthStr = self:formatNumber(netWorth)
    local ticketStr = self:formatNumber(ticketCount)
    
    local fruitText = self:formatFruitLine(fruits)
    local petText = self:formatPetLine(pets, 15)
    local eggText = self:formatPetLine(eggs, 10)
    
    local embed = {
        title = "📊 Inventory Snapshot",
        color = 16761095,
        fields = {
            {
                value = "💰 Net Worth: `" .. netWorthStr .. "`\n" .. self.emojis.Ticket .. " Ticket: `" .. ticketStr .. "`"
            },
            {
                name = "🪣 Fruits",
                value = fruitText
            },
            {
                name = "🐾 Pets",
                value = "```diff\n" .. petText .. "\n```",
                inline = true
            },
            {
                name = "🥚 Top Eggs",
                value = "```diff\n" .. eggText .. "\n```",
                inline = true
            }
        },
        footer = {
            text = "Generated • Build A Zoo"
        }
    }
    
    print("📊 Sending inventory snapshot...")
    local success, result = self:sendEmbed(embed)
    if success then
        print("✅ Inventory snapshot sent successfully!")
    else
        print("❌ Failed to send inventory snapshot:", result)
    end
    return success, result
end

-- Cerberus detection
function WebhookSystem:checkAndNotifyCerberus(node)
    if not node then return end
    if self.cerbNotifiedUID[node.Name] then return end
    
    local attrs = node:GetAttributes()
    local petType = tostring(attrs.T or "")
    local nameLower = string.lower(node.Name)
    
    if string.lower(petType) == "cerberus" or nameLower:find("cerberus") then
        self.cerbNotifiedUID[node.Name] = true
        
        local mutation = attrs.M
        if mutation == "Dino" then mutation = "Jurassic" end
        
        local desc = "🐾 " .. petType
        if mutation then
            desc = desc .. " [" .. mutation .. "]"
        end
        desc = desc .. " (UID: " .. node.Name .. ")"
        
        local embed = {
            title = "🎉 Cerberus Acquired!",
            description = desc,
            color = 16776960, -- Yellow
            timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
        }
        
        self:sendEmbed(embed)
    end
end

function WebhookSystem:startCerberusWatcher()
    self:stopCerberusWatcher()
    
    local data = self:getPlayerData()
    local pets = data and data:FindFirstChild("Pets")
    if not pets then return end
    
    -- Check existing pets
    for _, petNode in ipairs(pets:GetChildren()) do
        self:checkAndNotifyCerberus(petNode)
    end
    
    -- Watch for new pets
    self.cerbConnection = pets.ChildAdded:Connect(function(child)
        self:checkAndNotifyCerberus(child)
    end)
end

function WebhookSystem:stopCerberusWatcher()
    if self.cerbConnection then
        pcall(function() self.cerbConnection:Disconnect() end)
        self.cerbConnection = nil
    end
end

-- Trade notifications
function WebhookSystem:logTrade(kind, type, mutation, uid, receiver, receiverId)
    local entry = {
        kind = kind,
        type = type,
        mutation = mutation,
        uid = uid,
        receiver = receiver,
        receiverId = receiverId,
        timestamp = os.time()
    }
    table.insert(self.tradeLog, entry)
    
    if self.config.tradeEach then
        self:sendTradeNotification(entry)
    end
end

function WebhookSystem:sendTradeNotification(entry)
    local kindEmoji = entry.kind == "pet" and "🐾" or "🥚"
    local mutationText = entry.mutation and (" [" .. entry.mutation .. "]") or ""
    
    local embed = {
        title = "🤝 Trade Sent",
        description = kindEmoji .. " " .. entry.type .. mutationText .. " → " .. entry.receiver,
        color = 3447003, -- Blue
        fields = {
            {
                name = "📤 From",
                value = LocalPlayer and LocalPlayer.Name or "Unknown",
                inline = true
            },
            {
                name = "📥 To",
                value = entry.receiver,
                inline = true
            }
        },
        footer = {
            text = "Trade sent • " .. os.date("%B %d, %Y at %I:%M %p")
        }
    }
    
    self:sendEmbed(embed)
end

function WebhookSystem:sendTradeSummary()
    if #self.tradeLog == 0 then return end
    
    local receiverMap = {}
    local totalItems = 0
    
    for _, entry in ipairs(self.tradeLog) do
        local receiver = entry.receiver or "Unknown"
        if not receiverMap[receiver] then
            receiverMap[receiver] = {pets = {}, eggs = {}}
        end
        
        local item = entry.type .. (entry.mutation and (" [" .. entry.mutation .. "]") or "")
        if entry.kind == "pet" then
            receiverMap[receiver].pets[item] = (receiverMap[receiver].pets[item] or 0) + 1
        else
            receiverMap[receiver].eggs[item] = (receiverMap[receiver].eggs[item] or 0) + 1
        end
        totalItems = totalItems + 1
    end
    
    local fields = {}
    for receiver, data in pairs(receiverMap) do
        local items = {}
        
        for item, count in pairs(data.pets) do
            table.insert(items, "🐾 " .. item .. " × " .. count)
        end
        for item, count in pairs(data.eggs) do
            table.insert(items, "🥚 " .. item .. " × " .. count)
        end
        
        table.insert(fields, {
            name = "📥 To: " .. receiver,
            value = "```diff\n" .. table.concat(items, "\n") .. "\n```",
            inline = true
        })
    end
    
    local embed = {
        title = "🤝 Trade Session Summary",
        description = "📊 Total items sent: " .. totalItems .. "\n👥 Players helped: " .. #fields,
        color = 65280, -- Green
        fields = fields,
        footer = {
            text = "Session completed • " .. os.date("%B %d, %Y at %I:%M %p")
        }
    }
    
    self:sendEmbed(embed)
end

function WebhookSystem:clearTradeLog()
    self.tradeLog = {}
    self.sessionStartTime = 0
end

-- Initialize webhook system
function WebhookSystem:init()
    -- Auto-start cerberus watcher if enabled
    if self.config.cerberusAlert then
        self:startCerberusWatcher()
    end
end

return WebhookSystem
