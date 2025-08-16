-- Fruit Store System for Build A Zoo
-- This file is loaded by the main script using loadstring

local function createFruitStoreSystem(Tabs, WindUI, LocalPlayer, ReplicatedStorage, Players)
    -- Auto Fruit state variables
    local autoFruitEnabled = false
    local autoFruitThread = nil
    local fruitOnlyIfZero = false
    
    -- Fruit status tracking
    local fruitStatus = { 
        last = "Ready to buy fruits!", 
        haveUI = false, 
        haveData = false, 
        selected = "", 
        totalBought = 0 
    }
    
    -- Selected fruit set
    local selectedFruitSet = {}
    
    -- Load pet food config
    local petFoodConfig = {}
    local function loadPetFoodConfig()
        local ok, cfg = pcall(function()
            local cfgFolder = ReplicatedStorage:WaitForChild("Config")
            local module = cfgFolder:WaitForChild("ResPetFood")
            return require(module)
        end)
        if ok and type(cfg) == "table" then
            petFoodConfig = cfg
        else
            petFoodConfig = {}
        end
    end
    loadPetFoodConfig()
    
    -- Helper functions
    local function getPlayerNetWorth()
        if not LocalPlayer then return 0 end
        local attrValue = LocalPlayer:GetAttribute("NetWorth")
        if type(attrValue) == "number" then return attrValue end
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if leaderstats then
            local netWorthValue = leaderstats:FindFirstChild("NetWorth")
            if netWorthValue and type(netWorthValue.Value) == "number" then
                return netWorthValue.Value
            end
        end
        return 0
    end
    
    local function getFoodStoreUI()
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return nil end
        local gui = pg:FindFirstChild("ScreenFoodStore")
        if not gui then return nil end
        return gui
    end

    local function getFoodStoreLST()
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return nil end
        local data = pg:FindFirstChild("Data")
        if not data then return nil end
        local store = data:FindFirstChild("FoodStore")
        if not store then return nil end
        local lst = store:FindFirstChild("LST")
        return lst
    end

    local function getAssetContainer()
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        local data = pg and pg:FindFirstChild("Data")
        return data and data:FindFirstChild("Asset") or nil
    end

    local function getAssetCount(itemName)
        local asset = getAssetContainer()
        if not asset or not itemName then return nil end
        local val = asset:GetAttribute(itemName)
        if val == nil then
            local child = asset:FindFirstChild(itemName)
            if child and child:IsA("ValueBase") then val = child.Value end
        end
        local num = tonumber(val)
        return num
    end

    local function getAllFruitNames()
        local list = {}
        local seen = {}
        for key, val in pairs(petFoodConfig) do
            local keyStr = tostring(key)
            local lower = string.lower(keyStr)
            if lower ~= "_index" and lower ~= "__index" and not keyStr:match("^_") then
                local function addName(candidate)
                    local n = candidate and tostring(candidate) or ""
                    if n == "" then return end
                    if n:match("^_") then return end
                    -- Support PetFood_ prefix and plain names
                    local stripped = n:gsub("^PetFood_", "")
                    for _, choice in ipairs({ n, stripped }) do
                        if choice ~= "" and not seen[choice] then
                            table.insert(list, choice)
                            seen[choice] = true
                        end
                    end
                end
                if type(val) == "table" then
                    addName(val.Name)
                    addName(val.ID)
                    addName(val.Id)
                end
                addName(keyStr)
            end
        end
        return list
    end

    local function hasAnyFruitOwned()
        local asset = getAssetContainer()
        if not asset then return false end
        -- Build a set of fruit names from config for quick checks
        local fruits = {}
        for _, n in ipairs(getAllFruitNames()) do fruits[n] = true end
        -- Check attributes first
        local attrs = asset:GetAttributes()
        for k, v in pairs(attrs) do
            local key = tostring(k)
            local stripped = key:gsub("^PetFood_", "")
            if fruits[key] or fruits[stripped] then
                local num = tonumber(v)
                if num and num > 0 then return true end
            end
        end
        -- Fallback: check child ValueBase objects
        for _, child in ipairs(asset:GetChildren()) do
            if child:IsA("ValueBase") then
                local key = tostring(child.Name)
                local stripped = key:gsub("^PetFood_", "")
                if fruits[key] or fruits[stripped] then
                    local num = tonumber(child.Value)
                    if num and num > 0 then return true end
                end
            end
        end
        return false
    end

    local function getDeployContainer()
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        local data = pg and pg:FindFirstChild("Data")
        return data and data:FindFirstChild("Deploy") or nil
    end

    local function readDeploySlots()
        local deploy = getDeployContainer()
        local map = {}
        if not deploy then return map end
        for i = 2, 8 do
            local key = "S" .. tostring(i)
            local value = deploy:GetAttribute(key)
            if value == nil then
                local child = deploy:FindFirstChild(key)
                if child and child:IsA("ValueBase") then value = child.Value end
            end
            if value ~= nil then map[key] = tostring(value) end
        end
        return map
    end

    local function setDeploySlotS3(itemName)
        local deploy = getDeployContainer()
        if not deploy then return false end
        local ok = pcall(function()
            deploy:SetAttribute("S3", itemName)
            local child = deploy:FindFirstChild("S3")
            if child and child:IsA("ValueBase") then child.Value = itemName end
        end)
        return ok
    end

    local function candidateKeysForFruit(fruitName)
        local keys = {}
        local base = tostring(fruitName)
        table.insert(keys, base)
        table.insert(keys, string.upper(base))
        table.insert(keys, string.lower(base))
        do
            local cleaned = base:gsub("%s+", "")
            table.insert(keys, cleaned)
        end
        -- try to find matching entry in petFoodConfig to harvest alternate identifiers
        for k, v in pairs(petFoodConfig) do
            local name = (type(v) == "table" and (v.Name or v.ID or v.Id)) or k
            if tostring(name) == base then
                if type(v) == "table" then
                    for _, alt in ipairs({ v.Name, v.ID, v.Id }) do
                        if alt and not table.find(keys, tostring(alt)) then table.insert(keys, tostring(alt)) end
                    end
                end
                if not table.find(keys, tostring(k)) then table.insert(keys, tostring(k)) end
                break
            end
        end
        return keys
    end

    local function readStockFromLST(lst, fruitName)
        if not lst then return nil end
        local keys = candidateKeysForFruit(fruitName)
        -- Prefer attributes
        if lst.GetAttribute then
            for _, key in ipairs(keys) do
                local val = lst:GetAttribute(key)
                if val ~= nil then
                    local num = tonumber(val)
                    if num ~= nil then return num end
                    -- sometimes boolean-like; treat true as 1
                    if type(val) == "boolean" then return val and 1 or 0 end
                end
            end
        end
        -- Fallback: child Value objects
        for _, key in ipairs(keys) do
            local child = lst:FindFirstChild(key)
            if child and child:IsA("ValueBase") then
                local num = tonumber(child.Value)
                if num ~= nil then return num end
            end
        end
        return nil
    end

    local function getFruitPrice(fruitName)
        -- Try to get fruit price from petFoodConfig
        for key, val in pairs(petFoodConfig) do
            local keyStr = tostring(key)
            local lower = string.lower(keyStr)
            if lower ~= "_index" and lower ~= "__index" and not keyStr:match("^_") then
                local name
                if type(val) == "table" then
                    name = val.Name or val.ID or val.Id or keyStr
                else
                    name = keyStr
                end
                name = tostring(name)
                
                if name == fruitName then
                    -- Return price from config
                    if type(val) == "table" then
                        return val.Price or val.Cost or val.price or val.cost
                    end
                    return nil
                end
            end
        end
        return nil
    end

    local function isFruitInStock(fruitName)
        -- First, try attribute-based stock via Data.FoodStore.LST
        local lst = getFoodStoreLST()
        fruitStatus.haveData = lst ~= nil
        if lst then
            local qty = readStockFromLST(lst, fruitName)
            if qty ~= nil then return qty > 0 end
        end
        -- Fallback to UI if present
        local gui = getFoodStoreUI()
        fruitStatus.haveUI = gui ~= nil
        if not gui then return false end
        local root = gui:FindFirstChild("Root")
        if not root then return false end
        local frame = root:FindFirstChild("Frame")
        if not frame then return false end
        local scroller = frame:FindFirstChild("ScrollingFrame")
        if not scroller then return false end
        local item = scroller:FindFirstChild(fruitName)
        if not item then return false end
        local btn = item:FindFirstChild("ItemButton")
        if not btn then return false end
        local stock = btn:FindFirstChild("StockLabel")
        if not stock or not stock:IsA("TextLabel") then return false end
        local txt = tostring(stock.Text or "")
        if txt == "" then return false end
        -- Consider out-of-stock texts like "0" or words; treat any non-empty as available unless it matches 0
        local num = tonumber(txt)
        if num ~= nil then return num > 0 end
        return true
    end

    local function canAffordFruit(fruitName)
        local fruitPrice = getFruitPrice(fruitName)
        if not fruitPrice then return true end -- If no price found, assume affordable
        
        local netWorth = getPlayerNetWorth()
        return netWorth >= fruitPrice
    end

    local function fireBuyFruit(fruitName)
        local args = { fruitName }
        local ok, err = pcall(function()
            ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FoodStoreRE"):FireServer(unpack(args))
        end)
        if not ok then warn("Food buy failed for " .. tostring(fruitName) .. ": " .. tostring(err)) end
        return ok
    end

    -- UI Status functions
    local fruitParagraph
    local function updateFruitStatus()
        if not (fruitParagraph and fruitParagraph.SetDesc) then return end
        local now = os.clock()
        fruitParagraph._last = fruitParagraph._last or 0
        if now - fruitParagraph._last < 0.25 then return end
        fruitParagraph._last = now
        local lines = {}
        table.insert(lines, "🍎 Selected Fruits: " .. (fruitStatus.selected or "None picked yet"))
        table.insert(lines, "🛒 Store Open: " .. (fruitStatus.haveUI and "✅ Yes" or "❌ No - Open the store first"))
        table.insert(lines, "📊 Total Bought: " .. tostring(fruitStatus.totalBought or 0))
        table.insert(lines, "🔄 Status: " .. tostring(fruitStatus.last or "Ready!"))
        fruitParagraph:SetDesc(table.concat(lines, "\n"))
    end

    local function buildFruitList()
        local names = {}
        local added = {}
        for key, val in pairs(petFoodConfig) do
            local keyStr = tostring(key)
            local lower = string.lower(keyStr)
            -- Skip meta keys like _index/__index or any leading underscore keys
            if lower ~= "_index" and lower ~= "__index" and not keyStr:match("^_") then
                local name
                if type(val) == "table" then
                    name = val.Name or val.ID or val.Id or keyStr
                else
                    name = keyStr
                end
                name = tostring(name)
                if name and name ~= "" and not name:match("^_") and not added[name] then
                    table.insert(names, name)
                    added[name] = true
                end
            end
        end
        table.sort(names)
        return names
    end

    -- Try to buy selected fruits once; returns number bought
    local function attemptBuySelected(names)
        local bought = 0
        for _, name in ipairs(names) do
            local skip = false
            if fruitOnlyIfZero then
                local have = getAssetCount(name)
                if have ~= nil and have > 0 then
                    fruitStatus.last = "🍎 " .. name .. " already owned (" .. tostring(have) .. ")"
                    updateFruitStatus()
                    task.wait(0.05)
                    skip = true
                end
            end
            
            -- Check if fruit is in stock and affordable
            if not skip and isFruitInStock(name) and canAffordFruit(name) then
                fruitStatus.last = "🛒 Buying " .. name .. "..."
                updateFruitStatus()
                fireBuyFruit(name)
                bought += 1
                fruitStatus.totalBought = (fruitStatus.totalBought or 0) + 1
                task.wait(0.1)
            elseif not skip and isFruitInStock(name) and not canAffordFruit(name) then
                local price = getFruitPrice(name) or "Unknown"
                local netWorth = getPlayerNetWorth()
                fruitStatus.last = "💰 Cannot afford " .. name .. " (Price: " .. tostring(price) .. ", NetWorth: " .. tostring(netWorth) .. ")"
                updateFruitStatus()
                task.wait(0.05)
            end
        end
        return bought
    end

    -- Event-based waiting: listen for LST attribute or UI stock text changes for selected fruits
    local function waitForFruitAvailability(names, timeout)
        local evt = Instance.new("BindableEvent")
        local conns = {}
        local function add(conn)
            if conn then table.insert(conns, conn) end
        end
        local lst = getFoodStoreLST()
        if lst then
            for _, n in ipairs(names) do
                local keys = candidateKeysForFruit(n)
                for _, k in ipairs(keys) do
                    local sig = lst:GetAttributeChangedSignal(k)
                    add(sig:Connect(function() evt:Fire() end))
                end
            end
        end
        -- UI fallback: hook StockLabel text changes if UI open
        local gui = getFoodStoreUI()
        if gui then
            local root = gui:FindFirstChild("Root")
            local frame = root and root:FindFirstChild("Frame")
            local scroller = frame and frame:FindFirstChild("ScrollingFrame")
            if scroller then
                for _, n in ipairs(names) do
                    local item = scroller:FindFirstChild(n)
                    local stock = item and item:FindFirstChild("ItemButton") and item.ItemButton:FindFirstChild("StockLabel")
                    if stock then add(stock:GetPropertyChangedSignal("Text"):Connect(function() evt:Fire() end)) end
                end
            end
            -- If the store opens later, listen for it
        else
            local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
            if pg then add(pg.ChildAdded:Connect(function(child)
                if child.Name == "ScreenFoodStore" then evt:Fire() end
            end)) end
        end
        -- Wait for first trigger or timeout
        local waited = false
        task.spawn(function()
            task.wait(timeout or 30)
            if not waited then evt:Fire() end
        end)
        evt.Event:Wait()
        waited = true
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    end

    local function runAutoFruit()
        while autoFruitEnabled do
            local ok, err = pcall(function()
                -- build order list once per tick
                local names = {}
                for k in pairs(selectedFruitSet) do table.insert(names, k) end
                table.sort(names)
                if #names == 0 then
                    fruitStatus.last = "🍎 Pick some fruits first!"
                    updateFruitStatus()
                    task.wait(0.8)
                    return
                end
                -- Try once now
                local bought = attemptBuySelected(names)
                if bought == 0 then
                    fruitStatus.last = "⏰ Waiting for fruits to be in stock..."
                    updateFruitStatus()
                    waitForFruitAvailability(names, 30)
                else
                    fruitStatus.last = "🎉 Bought " .. tostring(bought) .. " fruits!"
                end
                updateFruitStatus()
            end)
            if not ok then
                fruitStatus.last = "❌ Error: " .. tostring(err)
                updateFruitStatus()
                task.wait(1)
            end
        end
    end

    -- Create UI
    Tabs.FruitTab:Section({ Title = "🍎 Fruit Store Status", Icon = "info" })
    
    fruitParagraph = Tabs.FruitTab:Paragraph({ 
        Title = "🍎 Fruit Market", 
        Desc = "Pick your favorite fruits to buy automatically!", 
        Image = "apple", 
        ImageSize = 18 
    })

    local fruitDropdown
    fruitDropdown = Tabs.FruitTab:Dropdown({
        Title = "🍎 Pick Your Fruits",
        Desc = "Choose which yummy fruits you want to buy automatically!",
        Values = buildFruitList(),
        Value = {},
        Multi = true,
        AllowNone = true,
        Callback = function(selection)
            selectedFruitSet = {}
            local function add(name)
                selectedFruitSet[tostring(name)] = true
            end
            if type(selection) == "table" then
                for _, n in ipairs(selection) do add(n) end
            elseif type(selection) == "string" then
                add(selection)
            end
            local keys = {}
            for k in pairs(selectedFruitSet) do table.insert(keys, k) end
            table.sort(keys)
            fruitStatus.selected = table.concat(keys, ", ")
            updateFruitStatus()
        end
    })

    Tabs.FruitTab:Button({
        Title = "🔄 Refresh Fruit List",
        Desc = "Update the fruit list if it's not showing all fruits",
        Callback = function()
            loadPetFoodConfig()
            if fruitDropdown and fruitDropdown.Refresh then
                fruitDropdown:Refresh(buildFruitList())
            end
            updateFruitStatus()
            WindUI:Notify({ Title = "🍎 Fruit Market", Content = "Fruit list refreshed!", Duration = 3 })
        end
    })

    Tabs.FruitTab:Button({
        Title = "🍎 Select All Fruits",
        Desc = "Quickly pick every fruit in the store!",
        Callback = function()
            local all = buildFruitList()
            selectedFruitSet = {}
            for _, n in ipairs(all) do selectedFruitSet[n] = true end
            fruitStatus.selected = table.concat(all, ", ")
            updateFruitStatus()
            WindUI:Notify({ Title = "🍎 Fruit Market", Content = "All fruits selected! 🎉", Duration = 3 })
        end
    })

    local autoFruitToggle = Tabs.FruitTab:Toggle({
        Title = "🛒 Auto Buy Fruits",
        Desc = "Automatically buys your selected fruits when they're available in the store!",
        Value = false,
        Callback = function(state)
            autoFruitEnabled = state
            if state and not autoFruitThread then
                autoFruitThread = task.spawn(function()
                    runAutoFruit()
                    autoFruitThread = nil
                end)
                fruitStatus.last = "🚀 Started buying fruits automatically!"
                updateFruitStatus()
                WindUI:Notify({ Title = "🍎 Fruit Market", Content = "Auto buy started! 🎉", Duration = 3 })
            elseif (not state) and autoFruitThread then
                fruitStatus.last = "⏸️ Stopped buying fruits"
                updateFruitStatus()
                WindUI:Notify({ Title = "🍎 Fruit Market", Content = "Auto buy stopped", Duration = 3 })
            end
        end
    })

    Tabs.FruitTab:Button({
        Title = "🛒 Buy Fruits Now",
        Desc = "Try to buy all your selected fruits right now!",
        Callback = function()
            local names = {}
            for k in pairs(selectedFruitSet) do table.insert(names, k) end
            table.sort(names)
            if #names == 0 then
                WindUI:Notify({ Title = "🍎 Fruit Market", Content = "Pick some fruits first!", Duration = 3 })
                return
            end
            local gui = getFoodStoreUI()
            fruitStatus.haveUI = gui ~= nil
            if not gui then
                WindUI:Notify({ Title = "🍎 Fruit Market", Content = "Open the fruit store first!", Duration = 3 })
                fruitStatus.last = "❌ Store not open - open the store first!"
                updateFruitStatus()
                return
            end
            local bought = 0
            local cannotAfford = 0
            for _, n in ipairs(names) do
                if isFruitInStock(n) and canAffordFruit(n) then
                    fireBuyFruit(n)
                    bought += 1
                    fruitStatus.totalBought = (fruitStatus.totalBought or 0) + 1
                    task.wait(0.1)
                elseif isFruitInStock(n) and not canAffordFruit(n) then
                    cannotAfford += 1
                end
            end
            local message = string.format("Bought %d fruits! 🎉", bought)
            if cannotAfford > 0 then
                message = message .. string.format("\nCannot afford %d fruits", cannotAfford)
            end
            WindUI:Notify({ Title = "🍎 Fruit Market", Content = message, Duration = 3 })
            fruitStatus.last = string.format("🎉 Bought %d fruits! (Cannot afford: %d)", bought, cannotAfford)
            updateFruitStatus()
        end
    })

    local onlyIfNoneOwnedToggle = Tabs.FruitTab:Toggle({
        Title = "🍎 Only Buy If You Don't Have Any",
        Desc = "Only buy fruits if you don't have any of that type already",
        Value = false,
        Callback = function(state)
            fruitOnlyIfZero = state
        end
    })

    -- Return UI elements for config registration
    return {
        autoFruitToggle = autoFruitToggle,
        onlyIfNoneOwnedToggle = onlyIfNoneOwnedToggle,
        fruitDropdown = fruitDropdown
    }
end

return createFruitStoreSystem
