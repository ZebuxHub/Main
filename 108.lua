-- Build A Zoo: Auto Buy Egg using WindUI

-- Load WindUI library (same as in Windui.lua)
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local vector = { create = function(x, y, z) return Vector3.new(x, y, z) end }
local LocalPlayer = Players.LocalPlayer

-- Window
local Window = WindUI:CreateWindow({
    Title = "Build A Zoo",
    Icon = "app-window-mac",
    IconThemed = true,
    Author = "Zebux",
    Folder = "Zebux",
    Size = UDim2.fromOffset(520, 360),
    Transparent = true,
    Theme = "Dark",
    -- No keysystem
})

local Tabs = {}
Tabs.MainSection = Window:Section({ Title = "Automation", Opened = true })
Tabs.AutoTab = Tabs.MainSection:Tab({ Title = "Auto Eggs", Icon = "egg" })
Tabs.PlaceTab = Tabs.MainSection:Tab({ Title = "Auto Place", Icon = "map-pin" })
Tabs.HatchTab = Tabs.MainSection:Tab({ Title = "Auto Hatch", Icon = "zap" })
Tabs.ClaimTab = Tabs.MainSection:Tab({ Title = "Auto Claim", Icon = "dollar-sign" })
Tabs.ShopTab = Tabs.MainSection:Tab({ Title = "Shop", Icon = "shopping-cart" })
Tabs.PackTab = Tabs.MainSection:Tab({ Title = "Auto Pack", Icon = "gift" })
Tabs.FruitTab = Tabs.MainSection:Tab({ Title = "Fruit Market", Icon = "apple" })

-- Forward declarations for status used by UI callbacks defined below
local statusData
local function updateStatusParagraph() end
local function updatePlaceStatusParagraph() end
-- Auto state variables (declared early so close handler can reference)
local autoFruitEnabled = false
local autoFruitThread = nil
local autoFeedEnabled = false

-- Egg config loader
local eggConfig = {}
local conveyorConfig = {}
local petFoodConfig = {}

local function loadEggConfig()
    local ok, cfg = pcall(function()
        local cfgFolder = ReplicatedStorage:WaitForChild("Config")
        local module = cfgFolder:WaitForChild("ResEgg")
        return require(module)
    end)
    if ok and type(cfg) == "table" then
        eggConfig = cfg
    else
        eggConfig = {}
    end
end

local idToTypeMap = {}
local function loadConveyorConfig()
    local ok, cfg = pcall(function()
        local cfgFolder = ReplicatedStorage:WaitForChild("Config")
        local module = cfgFolder:WaitForChild("ResConveyor")
        return require(module)
    end)
    if ok and type(cfg) == "table" then
        conveyorConfig = cfg
    else
        conveyorConfig = {}
    end
end

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
local function getTypeFromConfig(key, val)
    if type(val) == "table" then
        local t = val.Type or val.Name or val.type or val.name
        if t ~= nil then return tostring(t) end
    end
    return tostring(key)
end

local function buildEggIdList()
    idToTypeMap = {}
    local ids = {}
    for id, val in pairs(eggConfig) do
        local idStr = tostring(id)
        -- Filter out meta keys like _index, __index, and any leading underscore entries
        if not string.match(idStr, "^_%_?index$") and not string.match(idStr, "^__index$") and not idStr:match("^_") then
            table.insert(ids, idStr)
            idToTypeMap[idStr] = getTypeFromConfig(id, val)
        end
    end
    table.sort(ids)
    return ids
end

-- UI helpers
local function tryCreateTextInput(parent, opts)
    -- Tries common method names to create a textbox-like input in WindUI
    local created
    for _, method in ipairs({"Textbox", "Input", "TextBox"}) do
        local ok, res = pcall(function()
            return parent[method](parent, opts)
        end)
        if ok and res then created = res break end
    end
    return created
end

local function caseInsensitiveContains(hay, needle)
    if type(hay) ~= "string" or type(needle) ~= "string" then return false end
    return string.find(string.lower(hay), string.lower(needle), 1, true) ~= nil
end

local function getEggPriceById(eggId)
    local entry = eggConfig[eggId] or eggConfig[tonumber(eggId)]
    if entry == nil then
        for key, value in pairs(eggConfig) do
            if tostring(key) == tostring(eggId) then
                entry = value
                break
            end
            if type(value) == "table" then
                if value.Id == eggId or tostring(value.Id) == tostring(eggId) or value.Name == eggId then
                    entry = value
                    break
                end
            end
        end
    end
    if type(entry) == "table" then
        local price = entry.Price or entry.price or entry.Cost or entry.cost
        if type(price) == "number" then return price end
        if type(entry.Base) == "table" and type(entry.Base.Price) == "number" then return entry.Base.Price end
    end
    return nil
end

local function getEggPriceByType(eggType)
    local target = tostring(eggType)
    for key, value in pairs(eggConfig) do
        if type(value) == "table" then
            local t = value.Type or value.Name or value.type or value.name or tostring(key)
            if tostring(t) == target then
                local price = value.Price or value.price or value.Cost or value.cost
                if type(price) == "number" then return price end
                if type(value.Base) == "table" and type(value.Base.Price) == "number" then return value.Base.Price end
            end
        else
            if tostring(key) == target then
                -- primitive mapping, try id-based
                local price = getEggPriceById(key)
                if type(price) == "number" then return price end
            end
        end
    end
    return nil
end

-- Player helpers
local function getAssignedIslandName()
    if not LocalPlayer then return nil end
    return LocalPlayer:GetAttribute("AssignedIslandName")
end

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

local function fireConveyorUpgrade(index)
    local args = { "Upgrade", tonumber(index) or index }
    local ok, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("ConveyorRE"):FireServer(table.unpack(args))
    end)
    if not ok then warn("Conveyor Upgrade fire failed: " .. tostring(err)) end
    return ok
end

-- World helpers
local function getIslandBelts(islandName)
    if type(islandName) ~= "string" or islandName == "" then return {} end
    local art = workspace:FindFirstChild("Art")
    if not art then return {} end
    local island = art:FindFirstChild(islandName)
    if not island then return {} end
    local env = island:FindFirstChild("ENV")
    if not env then return {} end
    local conveyorRoot = env:FindFirstChild("Conveyor")
    if not conveyorRoot then return {} end
    local belts = {}
    -- Strictly look for Conveyor1..Conveyor9 in order
    for i = 1, 9 do
        local c = conveyorRoot:FindFirstChild("Conveyor" .. i)
        if c then
            local b = c:FindFirstChild("Belt")
            if b then table.insert(belts, b) end
        end
    end
    return belts
end

-- Pick one "active" belt (with most eggs; tie -> nearest to player)
local function getActiveBelt(islandName)
    local belts = getIslandBelts(islandName)
    if #belts == 0 then return nil end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local hrpPos = hrp and hrp.Position or Vector3.new()
    local bestBelt, bestScore, bestDist
    for _, belt in ipairs(belts) do
        local children = belt:GetChildren()
        local eggs = 0
        local samplePos
        for _, ch in ipairs(children) do
            if ch:IsA("Model") then
                eggs += 1
                if not samplePos then
                    local ok, cf = pcall(function() return ch:GetPivot() end)
                    if ok and cf then samplePos = cf.Position end
                end
            end
        end
        if not samplePos then
            local p = belt.Parent and belt.Parent:FindFirstChildWhichIsA("BasePart", true)
            samplePos = p and p.Position or hrpPos
        end
        local dist = (samplePos - hrpPos).Magnitude
        -- Higher eggs preferred; for tie, closer belt preferred
        local score = eggs * 100000 - dist
        if not bestScore or score > bestScore then
            bestScore, bestDist, bestBelt = score, dist, belt
        end
    end
    return bestBelt
end

-- Auto Place helpers
local function getIslandNumberFromName(islandName)
    if not islandName then return nil end
    -- Extract number from island name (e.g., "Island_3" -> 3)
    local match = string.match(islandName, "Island_(%d+)")
    if match then
        return tonumber(match)
    end
    -- Try other patterns
    match = string.match(islandName, "(%d+)")
    if match then
        return tonumber(match)
    end
    return nil
end

local function getFarmParts(islandNumber)
    if not islandNumber then return {} end
    local art = workspace:FindFirstChild("Art")
    if not art then return {} end
    
    local islandName = "Island_" .. tostring(islandNumber)
    local island = art:FindFirstChild(islandName)
    if not island then 
        -- Try alternative naming patterns
        for _, child in ipairs(art:GetChildren()) do
            if child.Name:match("^Island[_-]?" .. tostring(islandNumber) .. "$") then
                island = child
                break
            end
        end
        if not island then return {} end
    end
    
    local farmParts = {}
    local function scanForFarmParts(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("BasePart") and child.Name:match("^Farm_split_%d+_%d+_%d+$") then
                -- Additional validation: check if part is valid for placement
                if child.Size == Vector3.new(8, 8, 8) and child.CanCollide then
                    table.insert(farmParts, child)
                end
            end
            scanForFarmParts(child)
        end
    end
    
    scanForFarmParts(island)
    return farmParts
end

-- Occupancy helpers (uses Model:GetPivot to detect nearby placed pets)
local function isPetLikeModel(model)
    if not model or not model:IsA("Model") then return false end
    -- Common signals that a model is a pet or a placed unit
    if model:FindFirstChildOfClass("Humanoid") then return true end
    if model:FindFirstChild("AnimationController") then return true end
    if model:GetAttribute("IsPet") or model:GetAttribute("PetType") or model:GetAttribute("T") then return true end
    local lowerName = string.lower(model.Name)
    if string.find(lowerName, "pet") or string.find(lowerName, "egg") then return true end
    if CollectionService and (CollectionService:HasTag(model, "Pet") or CollectionService:HasTag(model, "IdleBigPet")) then
        return true
    end
    return false
end

local function getTileCenterPosition(farmPart)
    if not farmPart or not farmPart.IsA or not farmPart:IsA("BasePart") then return nil end
    -- Middle of the farm tile (parts are 8x8x8)
    return farmPart.Position
end

local function getPetModelsOverlappingTile(farmPart)
    if not farmPart or not farmPart:IsA("BasePart") then return {} end
    local centerCF = farmPart.CFrame
    -- Slightly taller box to capture pets above the tile
    local regionSize = Vector3.new(8, 14, 8)
    local params = OverlapParams.new()
    params.RespectCanCollide = false
    -- Search within whole workspace, we will filter to models
    local parts = workspace:GetPartBoundsInBox(centerCF, regionSize, params)
    local modelMap = {}
    for _, part in ipairs(parts) do
        if part ~= farmPart then
            local model = part:FindFirstAncestorOfClass("Model")
            if model and not modelMap[model] and isPetLikeModel(model) then
                modelMap[model] = true
            end
        end
    end
    local models = {}
    for model in pairs(modelMap) do table.insert(models, model) end
    return models
end

local function isFarmTileOccupied(farmPart, minDistance)
    minDistance = minDistance or 6
    local center = getTileCenterPosition(farmPart)
    if not center then return true end
    local models = getPetModelsOverlappingTile(farmPart)
    if #models == 0 then return false end
    -- If any pet pivot lies within minDistance of center, treat as occupied
    for _, model in ipairs(models) do
        local pivotPos = model:GetPivot().Position
        if (pivotPos - center).Magnitude <= minDistance then
            return true
        end
    end
    return false
end

local function findAvailableFarmPart(farmParts, minDistance)
    if not farmParts or #farmParts == 0 then return nil end
    -- Shuffle to distribute placement
    local indices = {}
    for i = 1, #farmParts do indices[i] = i end
    for i = #indices, 2, -1 do
        local j = math.random(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    for _, idx in ipairs(indices) do
        local part = farmParts[idx]
        if not isFarmTileOccupied(part, minDistance) then
            return part
        end
    end
    return nil
end

-- Player helpers for proximity-based placement
local function getPlayerRootPosition()
    local character = LocalPlayer and LocalPlayer.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    return hrp.Position
end

local function findAvailableFarmPartNearPosition(farmParts, minDistance, targetPosition)
    if not targetPosition then return findAvailableFarmPart(farmParts, minDistance) end
    if not farmParts or #farmParts == 0 then return nil end
    -- Sort farm parts by distance to targetPosition and pick first unoccupied
    local sorted = table.clone(farmParts)
    table.sort(sorted, function(a, b)
        return (a.Position - targetPosition).Magnitude < (b.Position - targetPosition).Magnitude
    end)
    for _, part in ipairs(sorted) do
        if not isFarmTileOccupied(part, minDistance) then
            return part
        end
    end
    return nil
end

local function getPetUID()
    if not LocalPlayer then return nil end
    
    -- Wait for PlayerGui to exist
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        -- Try to wait for it briefly
        playerGui = LocalPlayer:WaitForChild("PlayerGui", 2)
        if not playerGui then return nil end
    end
    
    -- Wait for Data folder to exist
    local data = playerGui:FindFirstChild("Data")
    if not data then
        data = playerGui:WaitForChild("Data", 2)
        if not data then return nil end
    end
    
    -- Wait for Egg object to exist
    local egg = data:FindFirstChild("Egg")
    if not egg then
        egg = data:WaitForChild("Egg", 2)
        if not egg then return nil end
    end
    
    -- The PET UID is the NAME of the egg object, not its Value
    local eggName = egg.Name
    if not eggName or eggName == "" then
        return nil
    end
    
    return eggName
end

-- Available Egg helpers (Auto Place)
local function getEggContainer()
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = pg and pg:FindFirstChild("Data")
    return data and data:FindFirstChild("Egg") or nil
end

local function listAvailableEggUIDs()
    local eg = getEggContainer()
    local uids = {}
    if not eg then return uids end
    for _, child in ipairs(eg:GetChildren()) do
        if #child:GetChildren() == 0 then -- no subfolder => available
            -- Get the actual egg type from T attribute
            local eggType = child:GetAttribute("T")
            if eggType then
                table.insert(uids, { uid = child.Name, type = eggType })
            else
                table.insert(uids, { uid = child.Name, type = child.Name })
            end
        end
    end
    return uids
end

-- Enhanced pet validation based on the Pet module
local function validatePetUID(petUID)
    if not petUID or type(petUID) ~= "string" or petUID == "" then
        return false, "Invalid PET UID"
    end
    
    -- Check if pet exists in ReplicatedStorage.Pets (based on Pet module patterns)
    local petsFolder = ReplicatedStorage:FindFirstChild("Pets")
    if petsFolder then
        -- The Pet module shows pets are stored by their type (T attribute)
        -- We might need to validate the pet type exists
        return true, "Valid PET UID"
    end
    
    return true, "PET UID found (pets folder not accessible)"
end

-- Get pet information for better status display
local function getPetInfo(petUID)
    if not petUID then return nil end
    
    -- Try to get pet data from various sources
    local petData = {
        UID = petUID,
        Type = nil,
        Rarity = nil,
        Level = nil,
        Mutations = nil
    }
    
    -- Check if we can get pet type from the UID
    -- This might be stored in the player's data or we might need to parse it
    if type(petUID) == "string" then
        -- Some games store pet type in the UID itself
        petData.Type = petUID
    end
    
    return petData
end

-- ============ Auto Claim Money ============
local autoClaimEnabled = false
local autoClaimThread = nil
local autoClaimDelay = 0.1 -- seconds between claims

local function getOwnedPetNames()
    local names = {}
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    local data = playerGui and playerGui:FindFirstChild("Data")
    local petsContainer = data and data:FindFirstChild("Pets")
    if petsContainer then
        for _, child in ipairs(petsContainer:GetChildren()) do
            -- Assume children under Data.Pets are ValueBase instances or folders named as pet names
            local n
            if child:IsA("ValueBase") then
                n = tostring(child.Value)
            else
                n = tostring(child.Name)
            end
            if n and n ~= "" then
                table.insert(names, n)
            end
        end
    end
    return names
end

local function claimMoneyForPet(petName)
    if not petName or petName == "" then return false end
    local petsFolder = workspace:FindFirstChild("Pets")
    if not petsFolder then return false end
    local petModel = petsFolder:FindFirstChild(petName)
    if not petModel then return false end
    local root = petModel:FindFirstChild("RootPart")
    if not root then return false end
    local re = root:FindFirstChild("RE")
    if not re or not re.FireServer then return false end
    local ok, err = pcall(function()
        re:FireServer("Claim")
    end)
    if not ok then warn("Claim failed for pet " .. tostring(petName) .. ": " .. tostring(err)) end
    return ok
end

local function runAutoClaim()
    while autoClaimEnabled do
        local ok, err = pcall(function()
            local names = getOwnedPetNames()
            if #names == 0 then task.wait(0.8) return end
            for _, n in ipairs(names) do
                claimMoneyForPet(n)
                task.wait(autoClaimDelay)
            end
        end)
        if not ok then
            warn("Auto Claim error: " .. tostring(err))
            task.wait(1)
        end
    end
end

Tabs.ClaimTab:Toggle({
    Title = "Auto Claim Money",
    Desc = "Claims from each of your placed pets (workspace.Pets)",
    Value = false,
    Callback = function(state)
        autoClaimEnabled = state
        if state and not autoClaimThread then
            autoClaimThread = task.spawn(function()
                runAutoClaim()
                autoClaimThread = nil
            end)
            WindUI:Notify({ Title = "Auto Claim", Content = "Started", Duration = 3 })
        elseif (not state) and autoClaimThread then
            WindUI:Notify({ Title = "Auto Claim", Content = "Stopped", Duration = 3 })
        end
    end
})

Tabs.ClaimTab:Slider({
    Title = "Delay Between Claims",
    Desc = "Time between each pet claim (ms)",
    Default = 100,
    Min = 0,
    Max = 1000,
    Rounding = 0,
    Callback = function(value)
        autoClaimDelay = math.clamp((tonumber(value) or 100) / 1000, 0, 2)
    end
})

Tabs.ClaimTab:Button({
    Title = "Claim All Now",
    Desc = "Immediately claims from all your pets",
    Callback = function()
        local names = getOwnedPetNames()
        if #names == 0 then
            WindUI:Notify({ Title = "Auto Claim", Content = "No pets found in Data.Pets", Duration = 3 })
            return
        end
        local count = 0
        for _, n in ipairs(names) do
            if claimMoneyForPet(n) then count += 1 end
            task.wait(0.05)
        end
        WindUI:Notify({ Title = "Auto Claim", Content = string.format("Claimed from %d pets", count), Duration = 3 })
    end
})

-- ============ Auto Hatch ============
local autoHatchEnabled = false
local autoHatchThread = nil

-- Hatch debug UI
Tabs.HatchTab:Section({ Title = "Status", Icon = "info" })
local hatchStatus = { last = "Idle", owned = 0, ready = 0, lastModel = nil, lastEggType = nil }
local hatchParagraph = Tabs.HatchTab:Paragraph({
    Title = "Auto Hatch",
    Desc = "Scanner idle",
    Image = "zap",
    ImageSize = 18,
})
local function updateHatchStatus()
    if not hatchParagraph or not hatchParagraph.SetDesc then return end
    local lines = {}
    table.insert(lines, string.format("Owned: %d | Ready: %d", hatchStatus.owned or 0, hatchStatus.ready or 0))
    if hatchStatus.lastModel then
        local extra = hatchStatus.lastEggType and (" (" .. tostring(hatchStatus.lastEggType) .. ")") or ""
        table.insert(lines, "Target: " .. tostring(hatchStatus.lastModel) .. extra)
    end
    table.insert(lines, "Status: " .. tostring(hatchStatus.last or ""))
    hatchParagraph:SetDesc(table.concat(lines, "\n"))
end

local function getOwnerUserIdDeep(inst)
    local current = inst
    while current and current ~= workspace do
        if current.GetAttribute then
            local uidAttr = current:GetAttribute("UserId")
            if type(uidAttr) == "number" then return uidAttr end
            if type(uidAttr) == "string" then
                local n = tonumber(uidAttr)
                if n then return n end
            end
        end
        current = current.Parent
    end
    return nil
end

local function playerOwnsInstance(inst)
    if not inst then return false end
    local ownerId = getOwnerUserIdDeep(inst)
    local lp = Players.LocalPlayer
    return ownerId ~= nil and lp and lp.UserId == ownerId
end

local function getModelPosition(model)
    if not model or not model.GetPivot then return nil end
    local ok, cf = pcall(function() return model:GetPivot() end)
    if ok and cf then return cf.Position end
    local pp = model.PrimaryPart or model:FindFirstChild("RootPart")
    return pp and pp.Position or nil
end

local function getEggTypeFromModel(model)
    if not model then return nil end
    local root = model:FindFirstChild("RootPart")
    if root and root.GetAttribute then
        local et = root:GetAttribute("EggType")
        if et ~= nil then return tostring(et) end
    end
    return nil
end

local function isStringEmpty(s)
    return type(s) == "string" and (s == "" or s:match("^%s*$") ~= nil)
end

local function isReadyText(text)
    if type(text) ~= "string" then return false end
    -- Empty or whitespace means ready
    if isStringEmpty(text) then return true end
    -- Percent text like "100%", "100.0%", "100.00%" also counts as ready
    local num = text:match("^%s*(%d+%.?%d*)%s*%%%s*$")
    if num then
        local n = tonumber(num)
        if n and n >= 100 then return true end
    end
    -- Words that often mean ready
    local lower = string.lower(text)
    if string.find(lower, "hatch", 1, true) or string.find(lower, "ready", 1, true) then
        return true
    end
    return false
end

local function isHatchReady(model)
    -- Look for TimeBar/TXT text being empty anywhere under the model
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("TextLabel") and d.Name == "TXT" then
            local parent = d.Parent
            if parent and parent.Name == "TimeBar" then
                if isReadyText(d.Text) then
                    return true
                end
            end
        end
        if d:IsA("ProximityPrompt") and type(d.ActionText) == "string" then
            local at = string.lower(d.ActionText)
            if string.find(at, "hatch", 1, true) then
                return true
            end
        end
    end
    return false
end

local function collectOwnedEggs()
    local owned = {}
    local container = workspace:FindFirstChild("PlayerBuiltBlocks")
    if not container then
        hatchStatus.owned = 0
        hatchStatus.ready = 0
        hatchStatus.last = "No PlayerBuiltBlocks found"
        updateHatchStatus()
        return owned
    end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Model") and playerOwnsInstance(child) then
            table.insert(owned, child)
        end
    end
    -- also allow owned nested models (fallback)
    if #owned == 0 then
        for _, child in ipairs(container:GetDescendants()) do
            if child:IsA("Model") and playerOwnsInstance(child) then
                table.insert(owned, child)
            end
        end
    end
    return owned
end

local function filterReadyEggs(models)
    local ready = {}
    for _, m in ipairs(models or {}) do
        if isHatchReady(m) then table.insert(ready, m) end
    end
    return ready
end

local function pressPromptE(prompt)
    if typeof(prompt) ~= "Instance" or not prompt:IsA("ProximityPrompt") then return false end
    -- Try executor helper first
    if _G and typeof(_G.fireproximityprompt) == "function" then
        local s = pcall(function() _G.fireproximityprompt(prompt, prompt.HoldDuration or 0) end)
        if s then return true end
    end
    -- Pure client fallback: simulate the prompt key with VirtualInput
    local key = prompt.KeyboardKeyCode
    if key == Enum.KeyCode.Unknown or key == nil then key = Enum.KeyCode.E end
    -- LoS and distance flexibility
    pcall(function()
        prompt.RequiresLineOfSight = false
        prompt.Enabled = true
    end)
    local hold = prompt.HoldDuration or 0
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    if hold > 0 then task.wait(hold + 0.05) end
    VirtualInputManager:SendKeyEvent(false, key, false, game)
    return true
end

local function walkTo(position, timeout)
    local char = Players.LocalPlayer and Players.LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    hum:MoveTo(position)
    local reached = hum.MoveToFinished:Wait(timeout or 5)
    return reached
end

local function tryHatchModel(model)
    -- Double-check ownership before proceeding
    if not playerOwnsInstance(model) then
        return false, "Not owner"
    end
    -- Find a ProximityPrompt named "E" or any prompt on the model
    local prompt
    -- Prefer a prompt on a part named Prompt or with ActionText that implies hatch
    for _, inst in ipairs(model:GetDescendants()) do
        if inst:IsA("ProximityPrompt") then
            prompt = inst
            if inst.ActionText and string.len(inst.ActionText) > 0 then break end
        end
    end
    if not prompt then return false, "No prompt" end
    local pos = getModelPosition(model)
    if not pos then return false, "No position" end
    walkTo(pos, 6)
    -- Ensure we are within MaxActivationDistance by nudging forward if necessary
    local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp and (hrp.Position - pos).Magnitude > (prompt.MaxActivationDistance or 10) - 1 then
        local dir = (pos - hrp.Position).Unit
        hrp.CFrame = CFrame.new(pos - dir * 1.5, pos)
        task.wait(0.1)
    end
    local ok = pressPromptE(prompt)
    return ok
end

local function runAutoHatch()
    while autoHatchEnabled do
        local ok, err = pcall(function()
            hatchStatus.last = "Scanning"
            updateHatchStatus()
            local owned = collectOwnedEggs()
            hatchStatus.owned = #owned
            if #owned == 0 then
                hatchStatus.last = "No owned eggs"
                updateHatchStatus()
                task.wait(1.0)
                return
            end
            local eggs = filterReadyEggs(owned)
            hatchStatus.ready = #eggs
            if #eggs == 0 then
                hatchStatus.last = "Owned but not ready"
                updateHatchStatus()
                task.wait(0.8)
                return
            end
            -- Try nearest first
            local me = getPlayerRootPosition()
            table.sort(eggs, function(a, b)
                local pa = getModelPosition(a) or Vector3.new()
                local pb = getModelPosition(b) or Vector3.new()
                return (pa - me).Magnitude < (pb - me).Magnitude
            end)
            for _, m in ipairs(eggs) do
                hatchStatus.lastModel = m.Name
                hatchStatus.lastEggType = getEggTypeFromModel(m)
                hatchStatus.last = "Moving to hatch"
                updateHatchStatus()
                tryHatchModel(m)
                task.wait(0.2)
            end
            hatchStatus.last = "Done"
            updateHatchStatus()
        end)
        if not ok then
            warn("Auto Hatch error: " .. tostring(err))
            hatchStatus.last = "Error: " .. tostring(err)
            updateHatchStatus()
            task.wait(1)
        end
    end
end

Tabs.HatchTab:Toggle({
    Title = "Auto Hatch",
    Desc = "Walk to your eggs in workspace.PlayerBuiltBlocks and press E",
    Value = false,
    Callback = function(state)
        autoHatchEnabled = state
        if state and not autoHatchThread then
            autoHatchThread = task.spawn(function()
                runAutoHatch()
                autoHatchThread = nil
            end)
            WindUI:Notify({ Title = "Auto Hatch", Content = "Started", Duration = 3 })
        elseif (not state) and autoHatchThread then
            WindUI:Notify({ Title = "Auto Hatch", Content = "Stopped", Duration = 3 })
        end
    end
})

Tabs.HatchTab:Button({
    Title = "Hatch Nearest",
    Desc = "Hatch the nearest owned egg (E prompt)",
    Callback = function()
        local owned = collectOwnedEggs()
        hatchStatus.owned = #owned
        if #owned == 0 then
            hatchStatus.last = "No owned eggs"
            updateHatchStatus()
            WindUI:Notify({ Title = "Auto Hatch", Content = "No eggs owned", Duration = 3 })
            return
        end
        local eggs = filterReadyEggs(owned)
        hatchStatus.ready = #eggs
        if #eggs == 0 then
            hatchStatus.last = "Owned but not ready"
            updateHatchStatus()
            WindUI:Notify({ Title = "Auto Hatch", Content = "No eggs ready", Duration = 3 })
            return
        end
        local me = getPlayerRootPosition() or Vector3.new()
        table.sort(eggs, function(a, b)
            local pa = getModelPosition(a) or Vector3.new()
            local pb = getModelPosition(b) or Vector3.new()
            return (pa - me).Magnitude < (pb - me).Magnitude
        end)
        hatchStatus.lastModel = eggs[1].Name
        hatchStatus.lastEggType = getEggTypeFromModel(eggs[1])
        hatchStatus.last = "Moving to hatch"
        updateHatchStatus()
        local ok = tryHatchModel(eggs[1])
        WindUI:Notify({ Title = ok and "Hatched" or "Hatch Failed", Content = eggs[1].Name, Duration = 3 })
    end
})

local function placePetAtPart(farmPart, petUID)
    if not farmPart or not petUID then return false end
    
    -- Enhanced validation based on Pet module insights
    if not farmPart:IsA("BasePart") then return false end
    
    local isValid, validationMsg = validatePetUID(petUID)
    if not isValid then
        warn("Pet validation failed: " .. validationMsg)
        return false
    end
    
    local position = farmPart.Position
    local args = {
        "Place",
        {
            DST = vector.create(position.X, position.Y, position.Z),
            ID = petUID
        }
    }
    
    local ok, err = pcall(function()
        local remote = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE")
        if remote then
            remote:FireServer(unpack(args))
        else
            error("CharacterRE remote not found")
        end
    end)
    
    if not ok then
        warn("Failed to fire Place for PET UID " .. tostring(petUID) .. " at " .. tostring(position) .. ": " .. tostring(err))
        return false
    end
    
    return true
end

-- UI state
loadEggConfig()
loadConveyorConfig()
loadPetFoodConfig()
local eggIdList = buildEggIdList()
local selectedTypeSet = {}

local eggDropdown
eggDropdown = Tabs.AutoTab:Dropdown({
    Title = "Egg IDs",
    Desc = "Pick the eggs you want to buy.",
    Values = eggIdList,
    Value = {},
    Multi = true,
    AllowNone = true,
            Callback = function(selection)
            selectedTypeSet = {}
            local function addTypeFor(idStr)
                -- Always include the ID itself (many games set Type directly to the config ID, e.g., "BasicEgg")
                selectedTypeSet[idStr] = true
                -- Also include the mapped Type from config (if available and different)
                local mappedType = idToTypeMap[idStr]
                if mappedType and tostring(mappedType) ~= idStr then
                    selectedTypeSet[tostring(mappedType)] = true
                end
            end
            if type(selection) == "table" then
                for _, id in ipairs(selection) do
                    addTypeFor(tostring(id))
                end
            elseif type(selection) == "string" then
                addTypeFor(tostring(selection))
            end
            -- update selected types display
            local keys = {}
            for k in pairs(selectedTypeSet) do table.insert(keys, k) end
            table.sort(keys)
            statusData.selectedTypes = table.concat(keys, ", ")
            updateStatusParagraph()
        end
})

-- Removed search bar to reduce UI clutter and processing

Tabs.AutoTab:Button({
    Title = "Reload Eggs",
    Callback = function()
        loadEggConfig()
        eggIdList = buildEggIdList()
        if eggDropdown and eggDropdown.Refresh then
            eggDropdown:Refresh(eggIdList)
        end
    end
})

local autoBuyEnabled = false
local autoBuyThread = nil

-- Status tracking
statusData = {
    eggsFound = 0,
    matchingFound = 0,
    affordableFound = 0,
    lastAction = "Idle",
    lastUID = nil,
    totalBuys = 0,
    netWorth = 0,
    islandName = nil,
}

Tabs.AutoTab:Section({ Title = "Status", Icon = "info" })
local statusParagraph = Tabs.AutoTab:Paragraph({
    Title = "Auto Buy",
    Desc = "Turn on the switch and pick egg names.",
    Image = "shopping-bag",
    ImageSize = 18,
})

local function formatStatusDesc()
    local lines = {}
    table.insert(lines, string.format("Island: %s", tostring(statusData.islandName or "?")))
    table.insert(lines, string.format("NetWorth: %s", tostring(statusData.netWorth)))
    table.insert(lines, string.format("Belt: %d eggs | Match %d | Can buy %d", statusData.eggsFound or 0, statusData.matchingFound or 0, statusData.affordableFound or 0))
    if statusData.selectedTypes then table.insert(lines, "Selected: " .. statusData.selectedTypes) end
    if statusData.lastUID then table.insert(lines, "Last Buy: " .. tostring(statusData.lastUID)) end
    table.insert(lines, "Status: " .. tostring(statusData.lastAction))
    return table.concat(lines, "\n")
end

function updateStatusParagraph()
    if statusParagraph and statusParagraph.SetDesc then
        statusParagraph:SetDesc(formatStatusDesc())
    end
end

local function shouldBuyEggInstance(eggInstance, playerMoney)
    if not eggInstance or not eggInstance:IsA("Model") then return false, nil, nil end
    -- Read Type primarily; some games may store as EggType or Name
    local eggType = eggInstance:GetAttribute("Type")
        or eggInstance:GetAttribute("EggType")
        or eggInstance:GetAttribute("Name")
    if not eggType then return false, nil, nil end
    eggType = tostring(eggType)
    if not selectedTypeSet[eggType] then return false, nil, nil end

    local price = eggInstance:GetAttribute("Price") or getEggPriceByType(eggType)
    if type(price) ~= "number" then return false, nil, nil end
    if playerMoney < price then return false, nil, nil end
    return true, eggInstance.Name, price
end

local function buyEggByUID(eggUID)
    local args = {
        "BuyEgg",
        eggUID
    }
    local ok, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    if not ok then
        warn("Failed to fire BuyEgg for UID " .. tostring(eggUID) .. ": " .. tostring(err))
    end
end

local function focusEggByUID(eggUID)
    local args = {
        "Focus",
        eggUID
    }
    local ok, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    if not ok then
        warn("Failed to fire Focus for UID " .. tostring(eggUID) .. ": " .. tostring(err))
    end
end

-- Event-driven Auto Buy system
local beltConnections = {}
local lastBeltChildren = {}
local buyingInProgress = false

local function cleanupBeltConnections()
    for _, conn in ipairs(beltConnections) do
        pcall(function() conn:Disconnect() end)
    end
    beltConnections = {}
end

local function shouldBuyEggInstance(eggInstance, playerMoney)
    if not eggInstance or not eggInstance:IsA("Model") then return false, nil, nil end
    local eggType = eggInstance:GetAttribute("Type") or eggInstance:GetAttribute("EggType") or eggInstance:GetAttribute("Name")
    if not eggType then return false, nil, nil end
    eggType = tostring(eggType)
    if not selectedTypeSet[eggType] then return false, nil, nil end

    local price = eggInstance:GetAttribute("Price") or getEggPriceByType(eggType)
    if type(price) ~= "number" then return false, nil, nil end
    if playerMoney < price then return false, nil, nil end
    return true, eggInstance.Name, price
end

local function buyEggInstantly(eggInstance)
    if buyingInProgress then return end
    buyingInProgress = true
    
    local netWorth = getPlayerNetWorth()
    local ok, uid, price = shouldBuyEggInstance(eggInstance, netWorth)
    
    if ok then
        statusData.lastUID = uid
        statusData.lastAction = "Buying UID " .. tostring(uid) .. " for " .. tostring(price)
        statusData.netWorth = netWorth
        updateStatusParagraph()
        
        buyEggByUID(uid)
        focusEggByUID(uid)
        statusData.totalBuys = (statusData.totalBuys or 0) + 1
        statusData.lastAction = "Bought + Focused UID " .. tostring(uid)
        updateStatusParagraph()
    end
    
    buyingInProgress = false
end

local function setupBeltMonitoring(belt)
    if not belt then return end
    
    -- Monitor for new eggs appearing
    local function onChildAdded(child)
        if not autoBuyEnabled then return end
        if child:IsA("Model") then
            task.wait(0.1) -- Small delay to ensure attributes are set
            buyEggInstantly(child)
        end
    end
    
    -- Monitor existing eggs for price/money changes
    local function checkExistingEggs()
        if not autoBuyEnabled then return end
        local children = belt:GetChildren()
        for _, child in ipairs(children) do
            if child:IsA("Model") then
                buyEggInstantly(child)
            end
        end
    end
    
    -- Connect events
    table.insert(beltConnections, belt.ChildAdded:Connect(onChildAdded))
    
    -- Check existing eggs periodically
    local checkThread = task.spawn(function()
        while autoBuyEnabled do
            checkExistingEggs()
            task.wait(0.5) -- Check every 0.5 seconds
        end
    end)
    
    -- Store thread for cleanup
    beltConnections[#beltConnections + 1] = { disconnect = function() checkThread = nil end }
end

local function runAutoBuy()
    while autoBuyEnabled do
        local islandName = getAssignedIslandName()
        statusData.islandName = islandName

        if not islandName or islandName == "" then
            statusData.lastAction = "Waiting for island assignment"
            updateStatusParagraph()
            task.wait(1)
            continue
        end

        local activeBelt = getActiveBelt(islandName)
        if not activeBelt then
            statusData.eggsFound = 0
            statusData.matchingFound = 0
            statusData.affordableFound = 0
            statusData.lastAction = "Waiting for belt on island"
            updateStatusParagraph()
            task.wait(1)
            continue
        end

        -- Count current eggs
        local children = {}
        for _, inst in ipairs(activeBelt:GetChildren()) do
            if inst:IsA("Model") then table.insert(children, inst) end
        end
        statusData.eggsFound = #children
        statusData.netWorth = getPlayerNetWorth()

        -- Setup monitoring for this belt
        cleanupBeltConnections()
        setupBeltMonitoring(activeBelt)
        
        statusData.lastAction = "Monitoring belt for new eggs"
        updateStatusParagraph()
        
        -- Wait until disabled or island changes
        while autoBuyEnabled do
            local currentIsland = getAssignedIslandName()
            if currentIsland ~= islandName then
                break -- Island changed, restart monitoring
            end
            task.wait(0.5)
        end
    end
    
    cleanupBeltConnections()
end

Tabs.AutoTab:Toggle({
    Title = "🥚 Auto Buy Eggs",
    Desc = "Instantly buys eggs as soon as they appear on the conveyor belt!",
    Value = false,
    Callback = function(state)
        autoBuyEnabled = state
        if state and not autoBuyThread then
            autoBuyThread = task.spawn(function()
                runAutoBuy()
                autoBuyThread = nil
            end)
            WindUI:Notify({ Title = "🥚 Auto Buy", Content = "Started - Watching for eggs! 🎉", Duration = 3 })
            statusData.lastAction = "Started - Watching for eggs!"
            updateStatusParagraph()
        elseif (not state) and autoBuyThread then
            cleanupBeltConnections()
            WindUI:Notify({ Title = "🥚 Auto Buy", Content = "Stopped", Duration = 3 })
            statusData.lastAction = "Stopped"
            updateStatusParagraph()
        end
    end
})

-- Event-driven Auto Place functionality
local autoPlaceEnabled = false
local autoPlaceThread = nil
local placeConnections = {}
local placingInProgress = false
local availableEggs = {} -- Track available eggs to place
local availableTiles = {} -- Track available tiles
local selectedEggTypes = {} -- Selected egg types for placement
local tileMonitoringActive = false


-- Auto Place status tracking
local placeStatusData = {
    islandName = nil,
    availableEggs = 0,
    availableTiles = 0,
    totalPlaces = 0,
    lastAction = "Idle",
    selectedEggs = 0,
}

Tabs.PlaceTab:Section({ Title = "Status", Icon = "info" })
Tabs.PlaceTab:Paragraph({
    Title = "How to use",
    Desc = table.concat({
        "1) Turn on 'Auto Place'.",
        "2) The script walks to tiles and looks for BlockInd.",
        "3) When BlockInd appears, it holds 2 and places.",
    }, "\n"),
    Image = "info",
    ImageSize = 16,
})
local placeStatusParagraph = Tabs.PlaceTab:Paragraph({
    Title = "Auto Place",
    Desc = "Walk-to-tile + BlockInd placement",
    Image = "map-pin",
    ImageSize = 18,
})

-- Function to get egg options
local function getEggOptions()
    local eggOptions = {}
    
    -- Try to get from ResEgg config first
    local eggConfig = loadEggConfig()
    if eggConfig then
        for id, data in pairs(eggConfig) do
            if type(id) == "string" and not id:match("^_") and id ~= "_index" and id ~= "__index" then
                local eggName = data.Type or data.Name or id
                table.insert(eggOptions, eggName)
            end
        end
    end
    
    -- Fallback: get from PlayerBuiltBlocks
    if #eggOptions == 0 then
        local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
        if playerBuiltBlocks then
            for _, egg in ipairs(playerBuiltBlocks:GetChildren()) do
                if egg:IsA("Model") then
                    local eggType = egg:GetAttribute("Type") or egg:GetAttribute("EggType") or egg:GetAttribute("Name")
                    if eggType and not table.find(eggOptions, eggType) then
                        table.insert(eggOptions, eggType)
                    end
                end
            end
        end
    end
    
    table.sort(eggOptions)
    return eggOptions
end

-- Egg selection dropdown
local placeEggDropdown = Tabs.PlaceTab:Dropdown({
    Title = "Select Eggs to Place",
    Desc = "Choose which egg types to place automatically",
    Values = eggIdList,
    Value = {},
    Multi = true,
    AllowNone = true,
    Callback = function(selection)
        selectedEggTypes = selection
        placeStatusData.selectedEggs = #selection
        updatePlaceStatusParagraph()
    end
})

-- Manual refresh button
Tabs.PlaceTab:Button({
    Title = "Refresh Egg List",
    Desc = "Manually refresh the egg dropdown if it's empty",
    Callback = function()
        local newOptions = getEggOptions()
        WindUI:Notify({ Title = "Egg List", Content = "Found " .. #newOptions .. " egg types", Duration = 3 })
    end
})

Tabs.PlaceTab:Button({
    Title = "Force Refresh Tiles",
    Desc = "Manually recheck all farm tiles for availability",
    Callback = function()
        updateAvailableTiles()
        WindUI:Notify({ Title = "Tile Refresh", Content = "Rechecked all tiles", Duration = 3 })
    end
})

local function formatPlaceStatusDesc()
    local lines = {}
    table.insert(lines, string.format("🏝️ Island: %s", tostring(placeStatusData.islandName or "?")))
    table.insert(lines, string.format("🥚 Available Eggs: %d | 📦 Available Tiles: %d", 
        placeStatusData.availableEggs or 0, 
        placeStatusData.availableTiles or 0))
    
    if placeStatusData.totalTiles then
        table.insert(lines, string.format("📊 Total Tiles: %d | ❌ Occupied: %d", 
            placeStatusData.totalTiles or 0,
            placeStatusData.occupiedTiles or 0))
    end
    
    table.insert(lines, string.format("✅ Total Placed: %d", placeStatusData.totalPlaces or 0))
    
    if placeStatusData.selectedEggs then
        table.insert(lines, string.format("🎯 Selected Types: %d", placeStatusData.selectedEggs or 0))
    end
    
    table.insert(lines, string.format("🔄 Status: %s", tostring(placeStatusData.lastAction or "Ready")))
    return table.concat(lines, "\n")
end

local function updatePlaceStatusParagraph()
    if placeStatusParagraph and placeStatusParagraph.SetDesc then
        placeStatusParagraph:SetDesc(formatPlaceStatusDesc())
    end
end

-- Check and remember which tiles are taken
-- Count actual placed pets in PlayerBuiltBlocks
local function countPlacedPets()
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    local count = 0
    if playerBuiltBlocks then
        for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
            if model:IsA("Model") then
                local userId = model:GetAttribute("UserId")
                if userId and tonumber(userId) == Players.LocalPlayer.UserId then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- Event-driven placement system
local function cleanupPlaceConnections()
    for _, conn in ipairs(placeConnections) do
        pcall(function() conn:Disconnect() end)
    end
    placeConnections = {}
end

local function updateAvailableEggs()
    local eggs = listAvailableEggUIDs()
    availableEggs = {}
    
    if #selectedEggTypes == 0 then
        -- If no types selected, use all eggs
        availableEggs = eggs
    else
        -- Filter by selected types
        local selectedSet = {}
        for _, type in ipairs(selectedEggTypes) do
            selectedSet[type] = true
        end
        
        for _, eggInfo in ipairs(eggs) do
            if selectedSet[eggInfo.type] then
                table.insert(availableEggs, eggInfo)
            end
        end
    end
    
    placeStatusData.availableEggs = #availableEggs
    updatePlaceStatusParagraph()
end

local function updateAvailableTiles()
    local islandName = getAssignedIslandName()
    local islandNumber = getIslandNumberFromName(islandName)
    local farmParts = getFarmParts(islandNumber)
    
    availableTiles = {}
    local totalTiles = #farmParts
    local occupiedTiles = 0
    
    for i, part in ipairs(farmParts) do
        -- Check if tile is actually available (not occupied) with more lenient radius
        local isOccupied = false
        local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
        if playerBuiltBlocks then
                    for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
            if model:IsA("Model") then
                local modelPos = model:GetPivot().Position
                local tilePos = part.Position
                
                -- Separate X/Z and Y axis checks
                local xzDistance = math.sqrt((modelPos.X - tilePos.X)^2 + (modelPos.Z - tilePos.Z)^2)
                local yDistance = math.abs(modelPos.Y - tilePos.Y)
                
                -- X/Z: 4 studs radius (tile is 8x8, so 4 studs from center)
                -- Y: 8 studs radius (allow eggs placed above/below tile)
                if xzDistance < 4.0 and yDistance < 8.0 then
                    isOccupied = true
                    occupiedTiles = occupiedTiles + 1
                    break
                end
            end
        end
        end
        
        if not isOccupied then
            table.insert(availableTiles, { part = part, index = i })
        end
    end
    
    placeStatusData.availableTiles = #availableTiles
    placeStatusData.totalTiles = totalTiles
    placeStatusData.occupiedTiles = occupiedTiles
    
    -- Debug info
    placeStatusData.lastAction = string.format("Found %d available tiles out of %d total (occupied: %d)", 
        #availableTiles, totalTiles, occupiedTiles)
    
    updatePlaceStatusParagraph()
end

local function placeEggInstantly(eggInfo, tileInfo)
    if placingInProgress then return false end
    placingInProgress = true
    
    local petUID = eggInfo.uid
    local tilePart = tileInfo.part
    
    -- Final check: is tile still available?
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    if playerBuiltBlocks then
        for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
            if model:IsA("Model") then
                local modelPos = model:GetPivot().Position
                local tilePos = tilePart.Position
                
                -- Separate X/Z and Y axis checks
                local xzDistance = math.sqrt((modelPos.X - tilePos.X)^2 + (modelPos.Z - tilePos.Z)^2)
                local yDistance = math.abs(modelPos.Y - tilePos.Y)
                
                -- X/Z: 4 studs radius, Y: 8 studs radius
                if xzDistance < 4.0 and yDistance < 8.0 then
                    placeStatusData.lastAction = "❌ Tile " .. tostring(tileInfo.index) .. " occupied - skipping"
                    placingInProgress = false
                    return false
                end
            end
        end
    end
    
    -- Equip egg to Deploy S2
    local deploy = LocalPlayer.PlayerGui.Data:FindFirstChild("Deploy")
    if deploy then
        local eggUID = "Egg_" .. petUID
        deploy:SetAttribute("S2", eggUID)
    end
    
    -- Hold egg
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
    task.wait(0.1)
    
    -- Teleport to tile
    local char = Players.LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(tilePart.Position)
            task.wait(0.1)
        end
    end
    
    -- Place egg
    local args = {
        "Place",
        {
            DST = vector.create(tilePart.Position.X, tilePart.Position.Y, tilePart.Position.Z),
            ID = petUID
        }
    }
    
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    if success then
        -- Verify placement
        task.wait(0.3)
        local placementConfirmed = false
        
        if playerBuiltBlocks then
            for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
                if model:IsA("Model") and model.Name == petUID then
                    placementConfirmed = true
                    break
                end
            end
        end
        
        if placementConfirmed then
            placeStatusData.totalPlaces = (placeStatusData.totalPlaces or 0) + 1
            placeStatusData.lastAction = "✅ Placed " .. tostring(petUID) .. " on tile " .. tostring(tileInfo.index)
            
            -- Remove egg and tile from available lists
            for i, egg in ipairs(availableEggs) do
                if egg.uid == petUID then
                    table.remove(availableEggs, i)
                    break
                end
            end
            
            for i, tile in ipairs(availableTiles) do
                if tile.index == tileInfo.index then
                    table.remove(availableTiles, i)
                    break
                end
            end
            
            placeStatusData.availableEggs = #availableEggs
            placeStatusData.availableTiles = #availableTiles
            updatePlaceStatusParagraph()
            placingInProgress = false
            return true
        else
            placeStatusData.lastAction = "❌ Placement failed for " .. tostring(petUID) .. " - removing tile"
            -- Remove the failed tile from available tiles so we don't retry it
            for i, tile in ipairs(availableTiles) do
                if tile.index == tileInfo.index then
                    table.remove(availableTiles, i)
                    break
                end
            end
            placeStatusData.availableTiles = #availableTiles
            updatePlaceStatusParagraph()
            placingInProgress = false
            return false
        end
    else
        placeStatusData.lastAction = "❌ Failed to fire placement for " .. tostring(petUID) .. " - removing tile"
        -- Remove the failed tile from available tiles so we don't retry it
        for i, tile in ipairs(availableTiles) do
            if tile.index == tileInfo.index then
                table.remove(availableTiles, i)
                break
            end
        end
        placeStatusData.availableTiles = #availableTiles
        updatePlaceStatusParagraph()
        placingInProgress = false
        return false
    end
end

local function attemptPlacement()
    if #availableEggs == 0 or #availableTiles == 0 then return end
    
    -- Place eggs on available tiles (limit to prevent lag)
    local placed = 0
    local attempts = 0
    local maxAttempts = math.min(#availableEggs, #availableTiles, 5) -- Limit to 5 attempts max
    
    while #availableEggs > 0 and #availableTiles > 0 and attempts < maxAttempts do
        attempts = attempts + 1
        
        -- Double-check tile is still available before placing
        local tileInfo = availableTiles[1]
        local isStillAvailable = true
        
        if tileInfo then
            local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
            if playerBuiltBlocks then
                for _, model in ipairs(playerBuiltBlocks:GetChildren()) do
                    if model:IsA("Model") then
                        local modelPos = model:GetPivot().Position
                        local tilePos = tileInfo.part.Position
                        
                        -- Separate X/Z and Y axis checks
                        local xzDistance = math.sqrt((modelPos.X - tilePos.X)^2 + (modelPos.Z - tilePos.Z)^2)
                        local yDistance = math.abs(modelPos.Y - tilePos.Y)
                        
                        -- X/Z: 4 studs radius, Y: 8 studs radius
                        if xzDistance < 4.0 and yDistance < 8.0 then
                            isStillAvailable = false
                            break
                        end
                    end
                end
            end
        end
        
        if isStillAvailable then
            if placeEggInstantly(availableEggs[1], availableTiles[1]) then
                placed = placed + 1
                task.wait(0.2) -- Longer delay between successful placements
            else
                -- Placement failed, tile was removed from availableTiles
                task.wait(0.1) -- Quick retry
            end
        else
            -- Tile is no longer available, remove it
            table.remove(availableTiles, 1)
            placeStatusData.availableTiles = #availableTiles
            updatePlaceStatusParagraph()
        end
    end
    
    if placed > 0 then
        placeStatusData.lastAction = "Placed " .. tostring(placed) .. " eggs"
        updatePlaceStatusParagraph()
    elseif attempts > 0 then
        placeStatusData.lastAction = "Tried " .. tostring(attempts) .. " placements, no success"
        updatePlaceStatusParagraph()
    end
end

local function setupPlacementMonitoring()
    -- Monitor for new eggs in PlayerGui.Data.Egg
    local eggContainer = getEggContainer()
    if eggContainer then
        local function onEggAdded(child)
            if not autoPlaceEnabled then return end
            if #child:GetChildren() == 0 then -- No subfolder = available egg
                task.wait(0.2) -- Wait for attributes to be set
                updateAvailableEggs()
                attemptPlacement()
            end
        end
        
        local function onEggRemoved(child)
            if not autoPlaceEnabled then return end
            updateAvailableEggs()
        end
        
        table.insert(placeConnections, eggContainer.ChildAdded:Connect(onEggAdded))
        table.insert(placeConnections, eggContainer.ChildRemoved:Connect(onEggRemoved))
    end
    
    -- Monitor for new tiles becoming available (when pets are removed from PlayerBuiltBlocks)
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    if playerBuiltBlocks then
        local function onBlockChanged()
            if not autoPlaceEnabled then return end
            task.wait(0.2)
            updateAvailableTiles()
            attemptPlacement()
        end
        
        table.insert(placeConnections, playerBuiltBlocks.ChildAdded:Connect(onBlockChanged))
        table.insert(placeConnections, playerBuiltBlocks.ChildRemoved:Connect(onBlockChanged))
    end
    
    -- Less frequent periodic updates to reduce lag
    local updateThread = task.spawn(function()
        while autoPlaceEnabled do
            updateAvailableEggs()
            updateAvailableTiles()
            attemptPlacement()
            task.wait(3) -- Update every 3 seconds instead of 1
        end
    end)
    
    table.insert(placeConnections, { disconnect = function() updateThread = nil end })
end

local function runAutoPlace()
    while autoPlaceEnabled do
        local islandName = getAssignedIslandName()
        placeStatusData.islandName = islandName
        
        if not islandName or islandName == "" then
            placeStatusData.lastAction = "Waiting for island assignment"
            updatePlaceStatusParagraph()
            task.wait(1)
            continue
        end
        
        -- Setup monitoring
        cleanupPlaceConnections()
        setupPlacementMonitoring()
        
        placeStatusData.lastAction = "Monitoring for eggs and tiles"
        updatePlaceStatusParagraph()
        
        -- Wait until disabled or island changes
        while autoPlaceEnabled do
            local currentIsland = getAssignedIslandName()
            if currentIsland ~= islandName then
                break -- Island changed, restart monitoring
            end
            task.wait(0.5)
        end
    end
    
    cleanupPlaceConnections()
end

Tabs.PlaceTab:Toggle({
    Title = "🏠 Auto Place Pets",
    Desc = "Automatically places your pets on empty farm tiles!",
    Value = false,
    Callback = function(state)
        autoPlaceEnabled = state
        if state and not autoPlaceThread then
            -- Reset counters
            placeStatusData.totalPlaces = countPlacedPets()
            placeStatusData.availableEggs = 0
            placeStatusData.availableTiles = 0
            
            autoPlaceThread = task.spawn(function()
                runAutoPlace()
                autoPlaceThread = nil
            end)
            WindUI:Notify({ Title = "🏠 Auto Place", Content = "Started - Placing pets automatically! 🎉", Duration = 3 })
            placeStatusData.lastAction = "Started - Placing pets automatically!"
            updatePlaceStatusParagraph()
        elseif (not state) and autoPlaceThread then
            cleanupPlaceConnections()
            WindUI:Notify({ Title = "🏠 Auto Place", Content = "Stopped", Duration = 3 })
            placeStatusData.lastAction = "Stopped"
            updatePlaceStatusParagraph()
        end
    end
})

-- Auto Delete functionality
local autoDeleteEnabled = false
local autoDeleteThread = nil
local deleteSpeedThreshold = 100 -- Default speed threshold
local deleteStatusData = {
    totalDeleted = 0,
    lastAction = "Idle",
    currentPet = nil,
    speedThreshold = 100,
    scannedPets = 0,
    slowPetsFound = 0
}

Tabs.PlaceTab:Section({ Title = "Auto Delete", Icon = "trash" })

-- Create paragraph first
local deleteStatusParagraph = Tabs.PlaceTab:Paragraph({
    Title = "Auto Delete Status",
    Desc = "Ready to delete slow pets",
    Image = "trash",
    ImageSize = 18,
})

local function formatDeleteStatusDesc()
    local lines = {}
    table.insert(lines, string.format("⚡ Speed Threshold: %d", deleteStatusData.speedThreshold or 100))
    table.insert(lines, string.format("🔍 Scanned: %d | 🐌 Slow: %d | ❌ Deleted: %d", 
        deleteStatusData.scannedPets or 0,
        deleteStatusData.slowPetsFound or 0,
        deleteStatusData.totalDeleted or 0))
    
    if deleteStatusData.currentPet then
        table.insert(lines, string.format("🐾 Current: %s", tostring(deleteStatusData.currentPet)))
    end
    
    table.insert(lines, string.format("🔄 Status: %s", tostring(deleteStatusData.lastAction or "Ready")))
    return table.concat(lines, "\n")
end

local function updateDeleteStatusParagraph()
    if deleteStatusParagraph and deleteStatusParagraph.SetDesc then
        deleteStatusParagraph:SetDesc(formatDeleteStatusDesc())
    end
end

Tabs.PlaceTab:Input({
    Title = "Speed Threshold",
    Desc = "Delete pets with speed below this value",
    Value = "100",
    Callback = function(value)
        deleteSpeedThreshold = tonumber(value) or 100
        deleteStatusData.speedThreshold = deleteSpeedThreshold
        updateDeleteStatusParagraph()
    end
})

-- Auto Delete function
local function runAutoDelete()
    while autoDeleteEnabled do
        local ok, err = pcall(function()
            -- Get all pets in workspace.Pets
            local petsFolder = workspace:FindFirstChild("Pets")
            if not petsFolder then
                deleteStatusData.lastAction = "No pets folder found"
                updateDeleteStatusParagraph()
                task.wait(1)
                return
            end
            
            local playerUserId = Players.LocalPlayer.UserId
            local petsToDelete = {}
            local scannedCount = 0
            
            -- Scan all pets and check their speed
            for _, pet in ipairs(petsFolder:GetChildren()) do
                if not autoDeleteEnabled then break end
                
                if pet:IsA("Model") then
                    scannedCount = scannedCount + 1
                    
                    -- Check if pet belongs to player
                    local petUserId = pet:GetAttribute("UserId")
                    if petUserId and tonumber(petUserId) == playerUserId then
                        -- Check pet's speed
                        local rootPart = pet:FindFirstChild("RootPart")
                        if rootPart then
                            local idleGUI = rootPart:FindFirstChild("GUI/IdleGUI", true)
                            if idleGUI then
                                local speedText = idleGUI:FindFirstChild("Speed")
                                if speedText and speedText:IsA("TextLabel") then
                                    -- Parse speed from format like "$100/s"
                                    local speedTextValue = speedText.Text
                                    local speedValue = tonumber(string.match(speedTextValue, "%d+"))
                                    if speedValue and speedValue < deleteSpeedThreshold then
                                        table.insert(petsToDelete, {
                                            name = pet.Name,
                                            speed = speedValue
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            deleteStatusData.scannedPets = scannedCount
            deleteStatusData.slowPetsFound = #petsToDelete
            
            if #petsToDelete == 0 then
                deleteStatusData.lastAction = "No slow pets found to delete"
                updateDeleteStatusParagraph()
                task.wait(2)
                return
            end
            
            -- Delete pets one by one
            for i, petInfo in ipairs(petsToDelete) do
                if not autoDeleteEnabled then break end
                
                deleteStatusData.currentPet = petInfo.name
                deleteStatusData.lastAction = string.format("Deleting pet %s (Speed: %d)", petInfo.name, petInfo.speed)
                updateDeleteStatusParagraph()
                
                -- Fire delete remote
                local args = {
                    "Del",
                    petInfo.name
                }
                
                local success = pcall(function()
                    ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
                end)
                
                if success then
                    deleteStatusData.totalDeleted = deleteStatusData.totalDeleted + 1
                    deleteStatusData.lastAction = string.format("✅ Deleted %s (Speed: %d)", petInfo.name, petInfo.speed)
                    updateDeleteStatusParagraph()
                    task.wait(0.5) -- Wait between deletions
                else
                    deleteStatusData.lastAction = string.format("❌ Failed to delete %s", petInfo.name)
                    updateDeleteStatusParagraph()
                    task.wait(0.2)
                end
            end
            
            deleteStatusData.currentPet = nil
            deleteStatusData.lastAction = string.format("Completed - Deleted %d slow pets", #petsToDelete)
            updateDeleteStatusParagraph()
            task.wait(3) -- Wait before next scan
            
        end)
        
        if not ok then
            warn("Auto Delete error: " .. tostring(err))
            deleteStatusData.lastAction = "Error: " .. tostring(err)
            updateDeleteStatusParagraph()
            task.wait(1)
        end
    end
end

Tabs.PlaceTab:Toggle({
    Title = "Auto Delete",
    Desc = "Automatically delete slow pets (only your pets)",
    Value = false,
    Callback = function(state)
        autoDeleteEnabled = state
        if state and not autoDeleteThread then
            deleteStatusData.totalDeleted = 0
            deleteStatusData.scannedPets = 0
            deleteStatusData.slowPetsFound = 0
            autoDeleteThread = task.spawn(function()
                runAutoDelete()
                autoDeleteThread = nil
            end)
            WindUI:Notify({ Title = "Auto Delete", Content = "Started", Duration = 3 })
            deleteStatusData.lastAction = "Started"
            updateDeleteStatusParagraph()
        elseif (not state) and autoDeleteThread then
            WindUI:Notify({ Title = "Auto Delete", Content = "Stopped", Duration = 3 })
            deleteStatusData.lastAction = "Stopped"
            updateDeleteStatusParagraph()
        end
    end
})

-- Anchor workflow removed (no longer needed)
Window:EditOpenButton({ Title = "Build A Zoo", Icon = "monitor", Draggable = true })

-- Close callback
Window:OnClose(function()
    autoBuyEnabled = false
    autoPlaceEnabled = false
    autoFruitEnabled = false
    autoFeedEnabled = false
end)


-- ============ Auto Claim Pack (every 10 minutes) ============
local autoPackEnabled = false
local autoPackThread = nil
local lastPackAt = 0

local function fireOnlinePack()
    local ok, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("DinoEventRE"):FireServer({ event = "onlinepack" })
    end)
    if not ok then warn("OnlinePack fire failed: " .. tostring(err)) end
    return ok
end

local function getOnlinePackText()
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local gui = pg:FindFirstChild("ScreenDinoOnLinePack")
    if not gui then return nil end
    local root = gui:FindFirstChild("Root")
    if not root then return nil end
    local bar = root:FindFirstChild("ProgressBar")
    if not bar then return nil end
    local textHolder = bar:FindFirstChild("Text")
    if not textHolder then return nil end
    local label = textHolder:FindFirstChild("Text")
    if label and label:IsA("TextLabel") then
        return label.Text
    end
    return nil
end

local function parseMMSS(str)
    if type(str) ~= "string" then return nil end
    local m, s = str:match("^(%d+):(%d+)$")
    if not m then return nil end
    local mi = tonumber(m)
    local si = tonumber(s)
    if not mi or not si then return nil end
    return mi * 60 + si
end

local function isPackReady()
    local txt = getOnlinePackText()
    if not txt then return false end
    local secs = parseMMSS(txt)
    if not secs then return false end
    return secs >= 1800 -- 30:00
end

local function runAutoPack()
    while autoPackEnabled do
        -- Only claim when UI shows 30:00 (or above)
        if isPackReady() then
            if os.clock() - (lastPackAt or 0) > 2 then -- small debounce window
                if fireOnlinePack() then
                    lastPackAt = os.clock()
                    WindUI:Notify({ Title = "Auto Pack", Content = "Online pack claimed", Duration = 3 })
                end
            end
            task.wait(2)
        else
            task.wait(1)
        end
    end
end

Tabs.PackTab:Toggle({
    Title = "Auto Claim Pack",
    Desc = "Claims when the timer shows 30:00",
    Value = false,
    Callback = function(state)
        autoPackEnabled = state
        if state and not autoPackThread then
            autoPackThread = task.spawn(function()
                runAutoPack()
                autoPackThread = nil
            end)
            WindUI:Notify({ Title = "Auto Pack", Content = "Started", Duration = 3 })
        elseif (not state) and autoPackThread then
            WindUI:Notify({ Title = "Auto Pack", Content = "Stopped", Duration = 3 })
        end
    end
})

Tabs.PackTab:Button({
    Title = "Claim Now",
    Desc = "Fire online pack immediately then start cooldown",
    Callback = function()
        if fireOnlinePack() then
            lastPackAt = os.clock()
            WindUI:Notify({ Title = "Auto Pack", Content = "Claimed", Duration = 3 })
        end
    end
})

-- ============ Shop / Auto Upgrade ============
Tabs.ShopTab:Section({ Title = "Auto Upgrade Conveyor", Icon = "arrow-up" })
local shopStatus = { lastAction = "Idle", upgradesTried = 0, upgradesDone = 0 }
local shopParagraph = Tabs.ShopTab:Paragraph({ Title = "Shop Status", Desc = "Waiting...", Image = "activity", ImageSize = 22 })
local function setShopStatus(msg)
    shopStatus.lastAction = msg
    if shopParagraph and shopParagraph.SetDesc then
        shopParagraph:SetDesc(string.format("Upgrades: %d done\nLast: %s", shopStatus.upgradesDone, shopStatus.lastAction))
    end
end

local function parseConveyorIndexFromId(idStr)
    local n = tostring(idStr):match("(%d+)")
    return n and tonumber(n) or nil
end

-- Remember upgrades we have already bought in this session
local purchasedUpgrades = {}

local function chooseAffordableUpgrades(netWorth)
    local actions = {}
    for key, entry in pairs(conveyorConfig) do
        if type(entry) == "table" then
            local cost = entry.Cost or entry.Price or (entry.Base and entry.Base.Price)
            local idLike = entry.ID or entry.Id or entry.Name or key
            local idx = parseConveyorIndexFromId(idLike)
            if idx and type(cost) == "number" and netWorth >= cost and idx >= 1 and idx <= 9 and not purchasedUpgrades[idx] then
                table.insert(actions, { idx = idx, cost = cost })
            end
        end
    end
    table.sort(actions, function(a, b) return a.idx < b.idx end)
    return actions
end

local autoUpgradeEnabled = false
local autoUpgradeThread = nil
Tabs.ShopTab:Toggle({
    Title = "Auto Upgrade",
    Desc = "Auto-upgrades conveyor 1..9 when NetWorth >= Cost (ResConveyor)",
    Value = false,
    Callback = function(state)
        autoUpgradeEnabled = state
        if state and not autoUpgradeThread then
            autoUpgradeThread = task.spawn(function()
                while autoUpgradeEnabled do
                    local net = getPlayerNetWorth()
                    local actions = chooseAffordableUpgrades(net)
                    if #actions == 0 then
                        setShopStatus("Waiting (NetWorth " .. tostring(net) .. ")")
                        task.wait(0.8)
                    else
                        for _, a in ipairs(actions) do
                            setShopStatus(string.format("Upgrading %d (cost %s)", a.idx, tostring(a.cost)))
                            if fireConveyorUpgrade(a.idx) then
                                shopStatus.upgradesDone += 1
                                purchasedUpgrades[a.idx] = true
                            end
                            shopStatus.upgradesTried += 1
                            task.wait(0.2)
                        end
                    end
                end
            end)
            setShopStatus("Started")
            WindUI:Notify({ Title = "Shop", Content = "Auto Upgrade started", Duration = 3 })
        elseif (not state) and autoUpgradeThread then
            WindUI:Notify({ Title = "Shop", Content = "Auto Upgrade stopped", Duration = 3 })
            setShopStatus("Stopped")
        end
    end
})

Tabs.ShopTab:Button({
    Title = "Upgrade All Affordable Now",
    Desc = "Checks ResConveyor and fires upgrades 1..9 you can afford",
    Callback = function()
        local net = getPlayerNetWorth()
        local actions = chooseAffordableUpgrades(net)
        if #actions == 0 then
            setShopStatus("No affordable upgrades (NetWorth " .. tostring(net) .. ")")
            return
        end
        for _, a in ipairs(actions) do
            if fireConveyorUpgrade(a.idx) then
                shopStatus.upgradesDone += 1
                purchasedUpgrades[a.idx] = true
            end
            shopStatus.upgradesTried += 1
            task.wait(0.1)
        end
        setShopStatus("Manual upgrade fired for " .. tostring(#actions) .. " items")
    end
})

Tabs.ShopTab:Button({
    Title = "Reset Remembered Upgrades",
    Desc = "Clear the one-time memory if you want to attempt again",
    Callback = function()
        purchasedUpgrades = {}
        setShopStatus("Memory reset")
        WindUI:Notify({ Title = "Shop", Content = "Upgrade memory cleared", Duration = 3 })
    end
})



-- ============ Fruit Market (Auto Buy Fruit) ============
Tabs.FruitTab:Section({ Title = "🍎 Fruit Store Status", Icon = "info" })
local fruitStatus = { last = "Ready to buy fruits!", haveUI = false, haveData = false, selected = "", totalBought = 0 }
local fruitParagraph = Tabs.FruitTab:Paragraph({ Title = "🍎 Fruit Market", Desc = "Pick your favorite fruits to buy automatically!", Image = "apple", ImageSize = 18 })
local function updateFruitStatus()
    if fruitParagraph and fruitParagraph.SetDesc then
        local lines = {}
        table.insert(lines, "🍎 Selected Fruits: " .. (fruitStatus.selected or "None picked yet"))
        table.insert(lines, "🛒 Store Open: " .. (fruitStatus.haveUI and "✅ Yes" or "❌ No - Open the store first"))
        table.insert(lines, "📊 Total Bought: " .. tostring(fruitStatus.totalBought or 0))
        table.insert(lines, "🔄 Status: " .. tostring(fruitStatus.last or "Ready!"))
        fruitParagraph:SetDesc(table.concat(lines, "\n"))
    end
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

local selectedFruitSet = {}
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

function getAllFruitNames()
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

function hasAnyFruitOwned()
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

local function fireBuyFruit(fruitName)
    local args = { fruitName }
    local ok, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FoodStoreRE"):FireServer(unpack(args))
    end)
    if not ok then warn("Food buy failed for " .. tostring(fruitName) .. ": " .. tostring(err)) end
    return ok
end

-- local autoFruitEnabled and autoFruitThread are declared near the top
local fruitOnlyIfZero = false

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
        if not skip and isFruitInStock(name) then
            fruitStatus.last = "🛒 Buying " .. name .. "..."
            updateFruitStatus()
            fireBuyFruit(name)
            bought += 1
            fruitStatus.totalBought = (fruitStatus.totalBought or 0) + 1
            task.wait(0.1)
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
    local function cleanup()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
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
    cleanup()
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

Tabs.FruitTab:Toggle({
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
        for _, n in ipairs(names) do
            if isFruitInStock(n) then
                fireBuyFruit(n)
                bought += 1
                fruitStatus.totalBought = (fruitStatus.totalBought or 0) + 1
                task.wait(0.1)
            end
        end
        WindUI:Notify({ Title = "🍎 Fruit Market", Content = string.format("Bought %d fruits! 🎉", bought), Duration = 3 })
        fruitStatus.last = string.format("🎉 Bought %d fruits!", bought)
        updateFruitStatus()
    end
})

Tabs.FruitTab:Toggle({
    Title = "🍎 Only Buy If You Don't Have Any",
    Desc = "Only buy fruits if you don't have any of that type already",
    Value = false,
    Callback = function(state)
        fruitOnlyIfZero = state
    end
})
