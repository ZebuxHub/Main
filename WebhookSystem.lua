-- WebhookSystem.lua
-- Advanced Discord webhook system for Build a Zoo automation

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

-- Fruit emojis mapping
WebhookSystem.fruitEmojis = {
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
    DeepseaPearlFruit = "<:DeepseaPearlFruit:1414278482913005598>"
}

-- Mutation emojis
WebhookSystem.mutationEmojis = {
    Golden = "🧬",
    Diamond = "💎",
    Fire = "🔥",
    Electric = "⚡",
    Dino = "🦕",
    Jurassic = "🦕"
}

-- Pet emojis
WebhookSystem.petEmojis = {
    Mouse = "🐾",
    Rabbit = "🐰",
    Toucan = "🦜",
    Fox = "🦊",
    Bighead = "🐸",
    Cerberus = "🐕"
}

-- Egg emojis
WebhookSystem.eggEmojis = {
    RareEgg = "🥚",
    EpicEgg = "🥚",
    LionfishEgg = "🏆",
    SharkEgg = "🏆"
}

-- Trade tracking
WebhookSystem.tradeLog = {}
WebhookSystem.cerberusNotified = {}
WebhookSystem.cerberusConnection = nil

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
    local data = self:getPlayerData()
    if not data then return 0 end
    
    local netWorth = data:GetAttribute("NetWorth")
    if type(netWorth) == "number" then return netWorth end
    
    local leaderstats = data:FindFirstChild("leaderstats")
    if leaderstats then
        local nv = leaderstats:FindFirstChild("NetWorth")
        if nv and type(nv.Value) == "number" then return nv.Value end
    end
    return 0
end

function WebhookSystem:formatNumber(num)
    if not num or num < 0 then return "0" end
    if num < 1000 then return tostring(math.floor(num)) end
    if num < 1000000 then return string.format("%.2fK", num / 1000) end
    if num < 1000000000 then return string.format("%.2fM", num / 1000000) end
    if num < 1000000000000 then return string.format("%.2fB", num / 1000000000) end
    return string.format("%.2fT", num / 1000000000000)
end

-- Get fruit inventory
function WebhookSystem:getFruitInventory()
    local data = self:getPlayerData()
    local asset = data and data:FindFirstChild("Asset")
    if not asset then return {} end
    
    local fruits = {}
    for fruitName, emoji in pairs(self.fruitEmojis) do
        local count = asset:GetAttribute(fruitName) or 0
        if count > 0 then
            fruits[fruitName] = {
                count = count,
                emoji = emoji
            }
        end
    end
    
    -- Get lottery tickets
    local tickets = asset:GetAttribute("LotteryTicket") or 0
    if tickets > 0 then
        fruits["Ticket"] = {
            count = tickets,
            emoji = "<:Ticket:1414283452659798167>"
        }
    end
    
    return fruits
end

-- Get pets inventory
function WebhookSystem:getPetsInventory()
    local data = self:getPlayerData()
    local pets = data and data:FindFirstChild("Pets")
    if not pets then return {} end
    
    local petCounts = {}
    for _, petNode in ipairs(pets:GetChildren()) do
        if petNode:IsA("Configuration") then
            local attrs = petNode:GetAttributes()
            local petType = attrs.T or "Unknown"
            local mutation = attrs.M or ""
            local key = petType .. (mutation ~= "" and ("_" .. mutation) or "")
            
            if not petCounts[key] then
                petCounts[key] = {
                    type = petType,
                    mutation = mutation,
                    count = 0
                }
            end
            petCounts[key].count = petCounts[key].count + 1
        end
    end
    
    return petCounts
end

-- Get eggs inventory
function WebhookSystem:getEggsInventory()
    local data = self:getPlayerData()
    local eggs = data and data:FindFirstChild("Egg")
    if not eggs then return {} end
    
    local eggCounts = {}
    for _, eggNode in ipairs(eggs:GetChildren()) do
        if eggNode:IsA("Configuration") then
            local attrs = eggNode:GetAttributes()
            local eggType = attrs.T or "Unknown"
            local mutation = attrs.M or ""
            local key = eggType .. (mutation ~= "" and ("_" .. mutation) or "")
            
            if not eggCounts[key] then
                eggCounts[key] = {
                    type = eggType,
                    mutation = mutation,
                    count = 0
                }
            end
            eggCounts[key].count = eggCounts[key].count + 1
        end
    end
    
    return eggCounts
end

-- Send inventory snapshot
function WebhookSystem:sendInventorySnapshot()
    local netWorth = self:getNetWorth()
    local fruits = self:getFruitInventory()
    local pets = self:getPetsInventory()
    local eggs = self:getEggsInventory()
    
    -- Format fruits
    local fruitLines = {}
    local fruitCount = 0
    for fruitName, data in pairs(fruits) do
        if fruitName ~= "Ticket" then
            table.insert(fruitLines, data.emoji .. " `" .. tostring(data.count) .. "`")
            fruitCount = fruitCount + 1
            if fruitCount % 5 == 0 then
                table.insert(fruitLines, "\n")
            end
        end
    end
    
    -- Add lottery tickets
    if fruits["Ticket"] then
        table.insert(fruitLines, 1, fruits["Ticket"].emoji .. " Ticket: `" .. self:formatNumber(fruits["Ticket"].count) .. "`")
    end
    
    local fruitValue = table.concat(fruitLines, "  ")
    
    -- Format pets (top 10)
    local petEntries = {}
    for _, data in pairs(pets) do
        table.insert(petEntries, data)
    end
    table.sort(petEntries, function(a, b) return a.count > b.count end)
    
    local petLines = {}
    for i = 1, math.min(10, #petEntries) do
        local pet = petEntries[i]
        local emoji = self.petEmojis[pet.type] or "🐾"
        local mutEmoji = self.mutationEmojis[pet.mutation] or ""
        local line = emoji .. " " .. pet.type .. " × " .. pet.count
        if pet.mutation ~= "" then
            line = line .. "\nL " .. mutEmoji .. " " .. pet.mutation .. " × " .. pet.count
        end
        table.insert(petLines, line)
    end
    
    local petValue = "```diff\n" .. table.concat(petLines, "\n\n") .. "\n```"
    
    -- Format eggs (top 5)
    local eggEntries = {}
    for _, data in pairs(eggs) do
        table.insert(eggEntries, data)
    end
    table.sort(eggEntries, function(a, b) return a.count > b.count end)
    
    local eggLines = {}
    for i = 1, math.min(5, #eggEntries) do
        local egg = eggEntries[i]
        local emoji = self.eggEmojis[egg.type] or "🥚"
        local mutEmoji = self.mutationEmojis[egg.mutation] or ""
        local line = emoji .. " " .. egg.type .. " × " .. egg.count
        if egg.mutation ~= "" then
            line = line .. "\nL " .. mutEmoji .. " " .. egg.mutation .. " × " .. egg.count
        end
        table.insert(eggLines, line)
    end
    
    local eggValue = "```diff\n" .. table.concat(eggLines, "\n\n") .. "\n```"
    
    -- Create embed
    local embed = {
        title = "📊 Inventory Snapshot",
        color = 16761095,
        fields = {
            {
                value = "💰 Net Worth: `" .. self:formatNumber(netWorth) .. "`\n" .. (fruits["Ticket"] and (fruits["Ticket"].emoji .. " Ticket: `" .. self:formatNumber(fruits["Ticket"].count) .. "`") or "")
            },
            {
                name = "🪣 Fruits",
                value = fruitValue
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
    
    return self:sendEmbed(embed)
end

-- Cerberus detection
function WebhookSystem:checkForCerberus()
    if not self.config.cerberusAlert then return end
    
    local data = self:getPlayerData()
    local pets = data and data:FindFirstChild("Pets")
    if not pets then return end
    
    for _, petNode in ipairs(pets:GetChildren()) do
        if petNode:IsA("Configuration") then
            local attrs = petNode:GetAttributes()
            local petType = attrs.T or ""
            local petName = petNode.Name
            
            if (string.lower(petType) == "cerberus" or string.lower(petName):find("cerberus")) and not self.cerberusNotified[petName] then
                self.cerberusNotified[petName] = true
                
                local embed = {
                    title = "🐕 Cerberus Acquired!",
                    description = "**Pet:** " .. petType .. "\n**UID:** " .. petName,
                    color = 16776960,
                    footer = {
                        text = "Build A Zoo • Cerberus Alert"
                    }
                }
                
                self:sendEmbed(embed)
                break
            end
        end
    end
end

-- Start cerberus monitoring
function WebhookSystem:startCerberusMonitoring()
    self:stopCerberusMonitoring()
    
    if not self.config.cerberusAlert then return end
    
    local data = self:getPlayerData()
    local pets = data and data:FindFirstChild("Pets")
    if not pets then return end
    
    -- Check existing pets
    self:checkForCerberus()
    
    -- Monitor new pets
    self.cerberusConnection = pets.ChildAdded:Connect(function(petNode)
        task.wait(0.1) -- Wait for attributes to load
        self:checkForCerberus()
    end)
end

-- Stop cerberus monitoring
function WebhookSystem:stopCerberusMonitoring()
    if self.cerberusConnection then
        pcall(function() self.cerberusConnection:Disconnect() end)
        self.cerberusConnection = nil
    end
end

-- Trade logging
function WebhookSystem:logTrade(tradeData)
    if not tradeData then return end
    
    table.insert(self.tradeLog, {
        timestamp = os.time(),
        data = tradeData
    })
    
    if self.config.tradeEach then
        self:sendTradeNotification(tradeData)
    end
end

-- Send individual trade notification
function WebhookSystem:sendTradeNotification(tradeData)
    local embed = {
        title = "🤝 Trade Completed",
        color = 3447003,
        fields = {
            {
                name = "📤 From: " .. (LocalPlayer and LocalPlayer.Name or "Unknown"),
                value = "```diff\n" .. tradeData.sent or "No items sent" .. "\n```",
                inline = true
            },
            {
                name = "📥 To: " .. (tradeData.receiver or "Unknown"),
                value = "```diff\n" .. tradeData.received or "No items received" .. "\n```",
                inline = true
            }
        },
        footer = {
            text = "Trade completed • " .. os.date("%B %d, %Y %I:%M %p")
        }
    }
    
    return self:sendEmbed(embed)
end

-- Send trade summary
function WebhookSystem:sendTradeSummary()
    if #self.tradeLog == 0 then return end
    
    local totalTrades = #self.tradeLog
    local receivers = {}
    
    for _, trade in ipairs(self.tradeLog) do
        local receiver = trade.data.receiver or "Unknown"
        if not receivers[receiver] then
            receivers[receiver] = { count = 0, items = {} }
        end
        receivers[receiver].count = receivers[receiver].count + 1
    end
    
    local receiverCount = 0
    for _ in pairs(receivers) do receiverCount = receiverCount + 1 end
    
    local embed = {
        title = "📊 Trade Session Summary",
        description = "**Total Trades:** " .. totalTrades .. "\n**Players Helped:** " .. receiverCount,
        color = 5763719,
        fields = {},
        footer = {
            text = "Session completed • " .. os.date("%B %d, %Y %I:%M %p")
        }
    }
    
    local fieldCount = 0
    for receiver, data in pairs(receivers) do
        if fieldCount < 25 then
            table.insert(embed.fields, {
                name = "👤 " .. receiver,
                value = "Trades: " .. data.count,
                inline = true
            })
            fieldCount = fieldCount + 1
        end
    end
    
    return self:sendEmbed(embed)
end

-- Clear trade log
function WebhookSystem:clearTradeLog()
    self.tradeLog = {}
end

-- Initialize webhook system
function WebhookSystem:init()
    -- Auto-start cerberus monitoring if enabled
    if self.config.cerberusAlert then
        self:startCerberusMonitoring()
    end
end

return WebhookSystem
