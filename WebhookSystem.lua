-- Build A Zoo Webhook System
-- Handles Discord webhook notifications for inventory and alerts

local WebhookSystem = {}

-- Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Variables
local LocalPlayer = Players.LocalPlayer
local webhookUrl = ""
local autoAlertEnabled = false
local sessionAlerts = {
    trades = 0,
    desiredEggs = 0,
    desiredPets = 0,
    desiredFruits = 0
}

-- UI References
local WindUI, Window, Config
local webhookUrlInput, sendInventoryButton, autoAlertToggle

-- Emoji mappings for Discord
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
    GoldMango = "<:GoldMango:1414278503440060516>",
    BloodstoneCycad = "<:BloodstoneCycad:1414278408988528725>",
    ColossalPinecone = "<:ColossalPinecone:1414278437052616865>",
    VoltGinkgo = "<:VoltGinkgo:1414278521681088543>",
    DeepseaPearlFruit = "<:DeepseaPearlFruit:1414278482913005598>"
}

local mutationEmojis = {
    Golden = "🧬",
    Diamond = "🧬", 
    Electric = "⚡",
    Fire = "🔥",
    Dino = "🧬"
}

-- Helper Functions
local function formatNumber(num)
    if type(num) == "string" then
        num = tonumber(num) or 0
    end
    if num >= 1000000000000 then
        return string.format("%.2fT", num / 1000000000000)
    elseif num >= 1000000000 then
        return string.format("%.2fB", num / 1000000000)
    elseif num >= 1000000 then
        return string.format("%.2fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.2fK", num / 1000)
    else
        return tostring(math.floor(num))
    end
end

local function getPlayerNetWorth()
    if not LocalPlayer then return 0 end
    local attrValue = LocalPlayer:GetAttribute("NetWorth")
    return tonumber(attrValue) or 0
end

local function getPlayerTickets()
    if not LocalPlayer then return 0 end
    local attrValue = LocalPlayer:GetAttribute("Ticket")
    return tonumber(attrValue) or 0
end

-- Get player's fruit inventory
local function getFruitInventory()
    local fruits = {}
    local fruitContainer = LocalPlayer.PlayerGui:FindFirstChild("Data")
    if fruitContainer then
        fruitContainer = fruitContainer:FindFirstChild("Fruit")
        if fruitContainer then
            for _, fruitNode in ipairs(fruitContainer:GetChildren()) do
                if fruitNode:IsA("IntValue") then
                    local fruitName = fruitNode.Name
                    local count = fruitNode.Value
                    if count > 0 then
                        fruits[fruitName] = count
                    end
                end
            end
        end
    end
    return fruits
end

-- Get player's pet inventory with mutations
local function getPetInventory()
    local pets = {}
    local petContainer = LocalPlayer.PlayerGui:FindFirstChild("Data")
    if petContainer then
        petContainer = petContainer:FindFirstChild("Pets")
        if petContainer then
            for _, petNode in ipairs(petContainer:GetChildren()) do
                if petNode:IsA("Folder") then
                    local petType = petNode:GetAttribute("T") or petNode.Name
                    local mutation = petNode:GetAttribute("M")
                    
                    if not pets[petType] then
                        pets[petType] = { total = 0, mutations = {} }
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
    end
    return pets
end

-- Get player's egg inventory with mutations
local function getEggInventory()
    local eggs = {}
    local eggContainer = LocalPlayer.PlayerGui:FindFirstChild("Data")
    if eggContainer then
        eggContainer = eggContainer:FindFirstChild("Egg")
        if eggContainer then
            for _, eggNode in ipairs(eggContainer:GetChildren()) do
                if eggNode:IsA("Folder") and #eggNode:GetChildren() == 0 then
                    local eggType = eggNode:GetAttribute("Type") or eggNode.Name
                    local mutation = eggNode:GetAttribute("M")
                    
                    if not eggs[eggType] then
                        eggs[eggType] = { total = 0, mutations = {} }
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
    end
    return eggs
end

-- Format fruits for Discord embed
local function formatFruits(fruits)
    if not fruits or not next(fruits) then
        return "No fruits available"
    end
    
    local fruitLines = {}
    local currentLine = ""
    local itemsInLine = 0
    
    for fruitName, count in pairs(fruits) do
        local emoji = fruitEmojis[fruitName] or "🍎"
        local fruitText = string.format("%s `%s`", emoji, formatNumber(count))
        
        if itemsInLine >= 5 then
            table.insert(fruitLines, currentLine)
            currentLine = fruitText
            itemsInLine = 1
        else
            if currentLine ~= "" then
                currentLine = currentLine .. "  " .. fruitText
            else
                currentLine = fruitText
            end
            itemsInLine = itemsInLine + 1
        end
    end
    
    if currentLine ~= "" then
        table.insert(fruitLines, currentLine)
    end
    
    return table.concat(fruitLines, "\n\n")
end

-- Format pets for Discord embed
local function formatPets(pets, maxPets)
    if not pets or not next(pets) then
        return "No pets available"
    end
    
    local petLines = {}
    local count = 0
    
    -- Sort pets by total count (descending)
    local sortedPets = {}
    for petType, data in pairs(pets) do
        table.insert(sortedPets, {name = petType, data = data})
    end
    table.sort(sortedPets, function(a, b) return a.data.total > b.data.total end)
    
    for _, petInfo in ipairs(sortedPets) do
        if count >= (maxPets or 10) then break end
        
        local petType = petInfo.name
        local data = petInfo.data
        
        local line = string.format("🐾 %s × %d", petType, data.total)
        
        -- Add mutations
        if data.mutations and next(data.mutations) then
            for mutation, mutCount in pairs(data.mutations) do
                local emoji = mutationEmojis[mutation] or "🔸"
                line = line .. string.format("\nL %s %s × %d", emoji, mutation, mutCount)
            end
        end
        
        table.insert(petLines, line)
        count = count + 1
        
        if count < (maxPets or 10) and count < #sortedPets then
            table.insert(petLines, "")
        end
    end
    
    return "```diff\n" .. table.concat(petLines, "\n") .. "\n```"
end

-- Format eggs for Discord embed
local function formatEggs(eggs, maxEggs)
    if not eggs or not next(eggs) then
        return "No eggs available"
    end
    
    local eggLines = {}
    local count = 0
    
    -- Sort eggs by total count (descending)
    local sortedEggs = {}
    for eggType, data in pairs(eggs) do
        table.insert(sortedEggs, {name = eggType, data = data})
    end
    table.sort(sortedEggs, function(a, b) return a.data.total > b.data.total end)
    
    for _, eggInfo in ipairs(sortedEggs) do
        if count >= (maxEggs or 5) then break end
        
        local eggType = eggInfo.name
        local data = eggInfo.data
        
        local line = string.format("🏆 %s × %d", eggType, data.total)
        
        -- Add mutations
        if data.mutations and next(data.mutations) then
            for mutation, mutCount in pairs(data.mutations) do
                local emoji = mutationEmojis[mutation] or "🔸"
                line = line .. string.format("\nL %s %s × %d", emoji, mutation, mutCount)
            end
        end
        
        table.insert(eggLines, line)
        count = count + 1
        
        if count < (maxEggs or 5) and count < #sortedEggs then
            table.insert(eggLines, "")
        end
    end
    
    return "```diff\n" .. table.concat(eggLines, "\n") .. "\n```"
end

-- Send webhook message
local function sendWebhook(embed)
    print("🔄 Webhook: sendWebhook called")
    print("🔄 Webhook: URL exists:", webhookUrl and "YES" or "NO")
    
    if not webhookUrl or webhookUrl == "" then
        print("❌ Webhook: No URL set")
        WindUI:Notify({ Title = "Webhook Error", Content = "Please set a Discord webhook URL first", Duration = 3 })
        return false
    end
    
    local payload = {
        content = nil,
        embeds = { embed },
        attachments = {}
    }
    
    print("🔄 Webhook: Payload created, sending HTTP request...")
    local success, response = pcall(function()
        return HttpService:PostAsync(webhookUrl, HttpService:JSONEncode(payload), Enum.HttpContentType.ApplicationJson)
    end)
    
    print("🔄 Webhook: HTTP request result - Success:", success)
    if success then
        print("✅ Webhook: Message sent successfully")
        WindUI:Notify({ Title = "Webhook Success", Content = "Message sent to Discord!", Duration = 3 })
        return true
    else
        print("❌ Webhook: Error:", tostring(response))
        WindUI:Notify({ Title = "Webhook Error", Content = "Failed to send message: " .. tostring(response), Duration = 5 })
        return false
    end
end

-- Create inventory embed
local function createInventoryEmbed()
    print("🔄 Webhook: Getting player data...")
    local playerName = LocalPlayer.Name
    local netWorth = getPlayerNetWorth()
    local tickets = getPlayerTickets()
    
    print("🔄 Webhook: Player:", playerName, "NetWorth:", netWorth, "Tickets:", tickets)
    
    print("🔄 Webhook: Getting inventory data...")
    local fruits = getFruitInventory()
    local pets = getPetInventory()
    local eggs = getEggInventory()
    
    print("🔄 Webhook: Fruits count:", fruits and #fruits or "nil")
    print("🔄 Webhook: Pets count:", pets and #pets or "nil")
    print("🔄 Webhook: Eggs count:", eggs and #eggs or "nil")
    
    local embed = {
        title = "📊 Inventory Snapshot",
        color = 16761095, -- Orange color
        fields = {
            {
                name = "User: " .. playerName,
                value = string.format("💰 Net Worth:  `%s`\n<:Ticket:1414283452659798167> Ticket: `%s`", 
                    formatNumber(netWorth), formatNumber(tickets))
            },
            {
                name = "🪣 Fruits",
                value = formatFruits(fruits)
            },
            {
                name = "🐾 Pets",
                value = formatPets(pets, 8),
                inline = true
            },
            {
                name = "🥚 Top Eggs",
                value = formatEggs(eggs, 3),
                inline = true
            }
        },
        footer = {
            text = "Generated • Build A Zoo"
        }
    }
    
    return embed
end

-- Send inventory report
local function sendInventoryReport()
    print("🔄 Webhook: Starting inventory report...")
    
    if not webhookUrl or webhookUrl == "" then
        WindUI:Notify({ Title = "Webhook Error", Content = "Please set a Discord webhook URL first", Duration = 3 })
        return
    end
    
    print("🔄 Webhook: Creating embed...")
    local embed = createInventoryEmbed()
    print("🔄 Webhook: Embed created, sending...")
    sendWebhook(embed)
end

-- Auto alert functions
local function checkForDesiredItems()
    -- This would be expanded based on user's desired items
    -- For now, it's a placeholder for the alert system
    if autoAlertEnabled then
        -- Check for trades, desired eggs, pets, fruits
        -- Increment sessionAlerts counters as needed
        -- Send alerts when items are found
    end
end

-- Create UI
local function CreateUI(tab)
    -- Webhook URL Input
    webhookUrlInput = tab:Input({
        Title = "Discord Webhook URL",
        Desc = "Enter your Discord channel webhook URL",
        Placeholder = "https://discord.com/api/webhooks/...",
        Callback = function(value)
            print("🔄 Webhook: URL input changed to:", value)
            webhookUrl = value
            if Config then
                Config:Set("webhookUrl", value)
                print("🔄 Webhook: URL saved to config")
            end
        end
    })
    
    -- Send Inventory Button
    sendInventoryButton = tab:Button({
        Title = "📊 Send Inventory",
        Desc = "Send current inventory snapshot to Discord",
        Callback = function()
            print("🔄 Webhook: Send Inventory button clicked!")
            sendInventoryReport()
        end
    })
    
    -- Auto Alert Toggle
    autoAlertToggle = tab:Toggle({
        Title = "🔔 Auto Alert",
        Desc = "Automatically send alerts for trades and desired items",
        Value = false,
        Callback = function(state)
            autoAlertEnabled = state
            if Config then
                Config:Set("autoAlertEnabled", state)
            end
            
            if state then
                WindUI:Notify({ Title = "Auto Alert", Content = "Auto alerts enabled!", Duration = 3 })
            else
                WindUI:Notify({ Title = "Auto Alert", Content = "Auto alerts disabled", Duration = 3 })
            end
        end
    })
    
    -- Session Stats (Read-only display)
    tab:Paragraph({
        Title = "📈 Session Statistics",
        Desc = string.format("Trades: %d | Desired Eggs: %d | Desired Pets: %d | Desired Fruits: %d", 
            sessionAlerts.trades, sessionAlerts.desiredEggs, sessionAlerts.desiredPets, sessionAlerts.desiredFruits),
        Image = "bar-chart-3"
    })
end

-- Load configuration
local function loadConfig()
    if Config then
        local savedWebhookUrl = Config:Get("webhookUrl", "")
        local savedAutoAlert = Config:Get("autoAlertEnabled", false)
        
        if savedWebhookUrl and savedWebhookUrl ~= "" then
            webhookUrl = savedWebhookUrl
            if webhookUrlInput then
                webhookUrlInput:SetValue(savedWebhookUrl)
            end
        end
        
        if savedAutoAlert then
            autoAlertEnabled = savedAutoAlert
            if autoAlertToggle then
                autoAlertToggle:SetValue(savedAutoAlert)
            end
        end
    end
end

-- Initialize the system
function WebhookSystem.Init(dependencies)
    WindUI = dependencies.WindUI
    Window = dependencies.Window
    Config = dependencies.Config
    local Tab = dependencies.Tab
    
    if Tab then
        CreateUI(Tab)
        
        -- Load saved configuration
        task.wait(0.5) -- Wait for UI to be ready
        loadConfig()
        
        -- Start auto alert monitoring if enabled
        if autoAlertEnabled then
            task.spawn(function()
                while autoAlertEnabled do
                    checkForDesiredItems()
                    task.wait(5) -- Check every 5 seconds
                end
            end)
        end
    end
end

-- Get config elements for registration
function WebhookSystem.GetConfigElements()
    return {
        webhookUrl = webhookUrlInput,
        autoAlertEnabled = autoAlertToggle
    }
end

return WebhookSystem
