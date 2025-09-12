-- data_collector.lua

local DataCollector = {}
task.wait(5)

-- Load WindUI for the interface
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/src.lua"))()
-- Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- Configuration (replace with your actual dashboard API endpoint)
local DASHBOARD_API_URL = "https://j6h5i7cg86gw.manus.space/api/dashboard/data"

-- Helper function to format numbers (from provided example)
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

-- Helper function to get player net worth (from provided example)
local function getPlayerNetWorth()
    if not LocalPlayer then return 0 end
    local attrValue = LocalPlayer:GetAttribute("NetWorth")
    if type(attrValue) == "number" then return attrValue end
    if type(attrValue) == "string" then return tonumber(attrValue) or 0 end
    return 0
end

-- Helper function to get player tickets (from provided example)
local function getPlayerTickets()
    if not LocalPlayer then return 0 end
    local attrValue = LocalPlayer:GetAttribute("Ticket")
    if type(attrValue) == "number" then return attrValue end
    if type(attrValue) == "string" then return tonumber(attrValue) or 0 end
    return 0
end

-- Function to get fruit inventory (from provided example)
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

-- Function to get pet inventory (from provided example)
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

-- Function to get egg inventory (from provided example)
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

-- Egg data from pasted_content_2.txt for calculating net worth
local EggData = {
    BasicEgg = { Price = 100, Sell = 100 },
    RareEgg = { Price = 500, Sell = 200 },
    SuperRareEgg = { Price = 2500, Sell = 200 },
    SeaweedEgg = { Price = 200, Sell = 200 },
    EpicEgg = { Price = 15000, Sell = 200 },
    LegendEgg = { Price = 100000, Sell = 4000 },
    ClownfishEgg = { Price = 200, Sell = 4000 },
    PrismaticEgg = { Price = 1000000, Sell = 10000 },
    LionfishEgg = { Price = 200, Sell = 10000 },
    HyperEgg = { Price = 2500000, Sell = 10000 },
    VoidEgg = { Price = 24000000, Sell = 40000 },
    BowserEgg = { Price = 130000000, Sell = 40000 },
    SharkEgg = { Price = 150000000, Sell = 40000 },
    DemonEgg = { Price = 400000000, Sell = 40000 },
    CornEgg = { Price = 1000000000, Sell = 40000 },
    AnglerfishEgg = { Price = 150000000, Sell = 40000 },
    BoneDragonEgg = { Price = 2000000000, Sell = 40000 },
    UltraEgg = { Price = 10000000000, Sell = 100000 },
    DinoEgg = { Price = 10000000000, Sell = 100000 },
    FlyEgg = { Price = 999999999999, Sell = 100000 },
    UnicornEgg = { Price = 40000000000, Sell = 100000 },
    OctopusEgg = { Price = 10000000000, Sell = 100000 },
    AncientEgg = { Price = 999999999999, Sell = 100000 },
    SeaDragonEgg = { Price = 999999999999, Sell = 100000 },
    UnicornProEgg = { Price = 50000000000, Sell = 100000 },
}

-- Function to calculate egg net worth
local function getEggNetWorth()
    local totalNetWorth = 0
    local eggs = getEggInventory()
    for eggType, eggData in pairs(eggs) do
        local eggInfo = EggData[eggType]
        if eggInfo and eggInfo.Sell then
            totalNetWorth = totalNetWorth + (eggData.total * eggInfo.Sell)
        end
    end
    return totalNetWorth
end

-- Function to get HWID (example, actual implementation depends on the executor/environment)
local function getHWID()
    -- This is a placeholder. In a real scenario, this would involve calling a specific
    -- function provided by the Lua executor to get a unique hardware ID.
    -- For demonstration, we'll use a simple placeholder.
    -- Example: return game:GetService("RbxAnalyticsService"):GetClientId()
    -- Or: return game:GetService("RbxAnalyticsService"):GetDeviceIdentifier()
    -- Or a custom function provided by the exploit/executor.
    return "PLACEHOLDER_HWID_" .. (LocalPlayer and LocalPlayer.UserId or "UNKNOWN")
end

-- Function to collect all relevant data
function DataCollector.collectData()
    local data = {
            hwid = getHWID(),
            username = LocalPlayer and LocalPlayer.Name or "Unknown",
            userId = LocalPlayer and LocalPlayer.UserId or "Unknown",
            netWorth = getPlayerNetWorth(),
            tickets = getPlayerTickets(),
            fruits = getFruitInventory(),
            pets = getPetInventory(),
            eggs = getEggInventory(),
            eggNetWorth = getEggNetWorth(),
            timestamp = os.time()
        }
        return data
end

-- Function to send data to the dashboard API
function DataCollector.sendData()
    local dataToSend = DataCollector.collectData()
    local jsonData = HttpService:JSONEncode(dataToSend)

    local success, result = pcall(function()
        return HttpService:PostAsync(DASHBOARD_API_URL, jsonData, Enum.HttpContentType.ApplicationJson)
    end)

    if success then
        print("Data sent to dashboard successfully!")
        -- You might want to add a local notification here if WindUI is available
        if WindUI and WindUI.Notify then
            WindUI:Notify({ Title = "Data Sent", Content = "Inventory data sent to dashboard!", Duration = 3 })
        end
    else
        warn("Failed to send data to dashboard: ", result)
        if WindUI and WindUI.Notify then
            WindUI:Notify({ Title = "Data Send Failed", Content = "Failed to send data: " .. tostring(result), Duration = 5 })
        end
    end
end

-- UI Variables
local Window
local UI_Elements = {}

-- Function to create the UI
local function createUI()
    Window = WindUI:CreateWindow({
        Title = "Data Collector Dashboard",
        Icon = "database",
        Author = "Build a Zoo",
        Folder = "DataCollector",
        Size = UDim2.fromOffset(600, 500),
        Transparent = true,
        Theme = "Dark",
        SideBarWidth = 180,
        ScrollBarEnabled = true,
    })

    -- Main section
    local MainSection = Window:Section({
        Title = "Dashboard",
        Opened = true,
    })

    -- Main tab
    local MainTab = MainSection:Tab({
        Title = "Inventory",
        Icon = "bar-chart-3"
    })

    -- Player Info Elements
    UI_Elements.Username = MainTab:Paragraph({
        Title = "Username",
        Desc = LocalPlayer and LocalPlayer.Name or "Unknown"
    })

    UI_Elements.NetWorth = MainTab:Paragraph({
        Title = "Net Worth",
        Desc = "Loading..."
    })

    UI_Elements.Tickets = MainTab:Paragraph({
        Title = "Tickets",
        Desc = "Loading..."
    })

    MainTab:Divider()

    -- Fruit Inventory
    UI_Elements.TotalFruits = MainTab:Paragraph({
        Title = "Total Fruits",
        Desc = "Loading..."
    })

    -- Pet Inventory
    UI_Elements.TotalPets = MainTab:Paragraph({
        Title = "Total Pets",
        Desc = "Loading..."
    })

    -- Egg Inventory
    UI_Elements.TotalEggs = MainTab:Paragraph({
        Title = "Total Eggs",
        Desc = "Loading..."
    })

    UI_Elements.EggNetWorth = MainTab:Paragraph({
        Title = "Egg Net Worth",
        Desc = "Loading..."
    })

    MainTab:Divider()

    -- Action Buttons
    MainTab:Button({
        Title = "Refresh Data",
        Icon = "refresh-ccw",
        Callback = function()
            updateUI()
            WindUI:Notify({
                Title = "Data Refreshed",
                Content = "Dashboard data has been updated!",
                Duration = 2
            })
        end
    })

    MainTab:Button({
        Title = "Send to Dashboard",
        Icon = "send",
        Callback = function()
            DataCollector.sendData()
        end
    })

    -- Auto-refresh every 30 seconds
    task.spawn(function()
        while true do
            task.wait(30)
            if Window and Window.Enabled then
                updateUI()
            end
        end
    end)
end

-- Function to update UI with current data
function updateUI()
    if not Window or not UI_Elements then return end

    local data = DataCollector.collectData()

    -- Update player info
    if UI_Elements.NetWorth then
        UI_Elements.NetWorth:SetDesc(formatNumber(data.netWorth))
    end

    if UI_Elements.Tickets then
        UI_Elements.Tickets:SetDesc(formatNumber(data.tickets))
    end

    -- Update fruit inventory
    local totalFruits = 0
    for fruit, amount in pairs(data.fruits) do
        totalFruits = totalFruits + amount
    end

    if UI_Elements.TotalFruits then
        UI_Elements.TotalFruits:SetDesc(formatNumber(totalFruits))
    end

    -- Update pet inventory
    local totalPets = 0
    for petType, petData in pairs(data.pets) do
        totalPets = totalPets + petData.total
    end

    if UI_Elements.TotalPets then
        UI_Elements.TotalPets:SetDesc(formatNumber(totalPets))
    end

    -- Update egg inventory
    local totalEggs = 0
    for eggType, eggData in pairs(data.eggs) do
        totalEggs = totalEggs + eggData.total
    end

    if UI_Elements.TotalEggs then
        UI_Elements.TotalEggs:SetDesc(formatNumber(totalEggs))
    end

    if UI_Elements.EggNetWorth then
        UI_Elements.EggNetWorth:SetDesc(formatNumber(data.eggNetWorth))
    end
end

-- Initialize UI when script loads
    task.spawn(function()
    task.wait(2) -- Wait a bit more for game to load
    createUI()
    updateUI()
    WindUI:Notify({
        Title = "Data Collector Ready",
        Content = "Dashboard UI has been loaded successfully!",
        Duration = 3
    })
end)

return DataCollector
