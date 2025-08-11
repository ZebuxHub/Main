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

-- Remote caches
local RS_Remote = ReplicatedStorage:WaitForChild("Remote")
local REMOTE_CharacterRE = RS_Remote:WaitForChild("CharacterRE")
local REMOTE_ConveyorRE = RS_Remote:WaitForChild("ConveyorRE")
local REMOTE_DinoEventRE = RS_Remote:WaitForChild("DinoEventRE")

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
-- Forward declarations for status used by UI callbacks defined below
local statusData
local function updateStatusParagraph() end

-- Egg config loader
local eggConfig = {}
local conveyorConfig = {}

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

-- UI helpers (kept minimal to reduce overhead)

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
        REMOTE_ConveyorRE:FireServer(table.unpack(args))
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
    local kids = parent:GetChildren()
    for i = 1, #kids do
        local child = kids[i]
        if child:IsA("BasePart") and child.Name:match("^Farm_split_%d+_%d+_%d+$") then
            if child.Size == Vector3.new(8, 8, 8) and child.CanCollide then
                farmParts[#farmParts+1] = child
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
    for i = 1, #parts do
        local part = parts[i]
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
                task.wait(0.1)
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
local hatchStatus = { last = "Idle", owned = 0, ready = 0, lastModel = nil, lastTarget = nil }
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
    if hatchStatus.lastTarget or hatchStatus.lastModel then
        local label = hatchStatus.lastTarget or hatchStatus.lastModel
        table.insert(lines, "Target: " .. tostring(label))
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
    local desc = model:GetDescendants()
    for i = 1, #desc do
        local d = desc[i]
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

local function getEggTypeForModel(model)
    if not model then return nil end
    local rp = model:FindFirstChild("RootPart")
    if rp and rp.GetAttribute then
        local t = rp:GetAttribute("EggType")
        if t ~= nil then return tostring(t) end
    end
    if model.GetAttribute then
        local t2 = model:GetAttribute("EggType")
        if t2 ~= nil then return tostring(t2) end
    end
    return nil
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
                hatchStatus.lastTarget = getEggTypeForModel(m) or m.Name
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
        hatchStatus.lastTarget = getEggTypeForModel(eggs[1]) or eggs[1].Name
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
        REMOTE_CharacterRE:FireServer(unpack(args))
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

local function runAutoBuy()
    while autoBuyEnabled do
        local islandName = getAssignedIslandName()
        statusData.islandName = islandName

        if not islandName or islandName == "" then
            statusData.lastAction = "Waiting for island assignment (AssignedIslandName)"
            updateStatusParagraph()
            task.wait(0.6)
            continue
        end

        local beltFolders = getIslandBelts(islandName)
        if #beltFolders == 0 then
            statusData.eggsFound = 0
            statusData.matchingFound = 0
            statusData.affordableFound = 0
            statusData.lastAction = "Waiting for belt on island"
            updateStatusParagraph()
            task.wait(0.6)
            continue
        end

        -- Combine eggs from all belts (Conveyor1..n)
        local children = {}
        -- Collect models with minimal allocations
        for b = 1, #beltFolders do
            local kids = beltFolders[b]:GetChildren()
            for i = 1, #kids do
                local inst = kids[i]
                if inst:IsA("Model") then children[#children+1] = inst end
            end
        end
        statusData.eggsFound = #children
        statusData.netWorth = getPlayerNetWorth()

        if statusData.eggsFound == 0 then
            statusData.matchingFound = 0
            statusData.affordableFound = 0
            statusData.lastAction = "Waiting for eggs to spawn"
            updateStatusParagraph()
            task.wait(0.5)
            continue
        end

        local matching = {}
        local seen = {}
        for i = 1, #children do
            local child = children[i]
            local ok, uid, price = shouldBuyEggInstance(child, statusData.netWorth)
            if ok then matching[#matching+1] = { uid = uid, price = price } end
            local t = child:GetAttribute("Type") or child:GetAttribute("EggType") or child:GetAttribute("Name")
            if t ~= nil then seen[tostring(t)] = true end
        end
        do
            local list = {}
            for k in pairs(seen) do table.insert(list, k) end
            table.sort(list)
            statusData.seenTypes = (#list > 0) and table.concat(list, ", ") or nil
        end
        statusData.matchingFound = #matching

        if statusData.matchingFound == 0 then
            statusData.affordableFound = 0
            statusData.lastAction = "No matching eggs on belt (adjust dropdown)"
            updateStatusParagraph()
            task.wait(0.5)
            continue
        end

        table.sort(matching, function(a, b)
            return (a.price or math.huge) < (b.price or math.huge)
        end)

        local affordable = {}
        for i = 1, #matching do
            local item = matching[i]
            if statusData.netWorth >= (item.price or math.huge) then
                affordable[#affordable+1] = item
            end
        end
        statusData.affordableFound = #affordable

        if statusData.affordableFound == 0 then
            local cheapest = matching[1]
            statusData.lastAction = "Waiting for money (cheapest " .. tostring(cheapest and cheapest.price or "?") .. ", NetWorth " .. tostring(statusData.netWorth) .. ")"
            updateStatusParagraph()
            task.wait(0.4)
            continue
        end

        local chosen = affordable[1]
        statusData.lastUID = chosen.uid
        statusData.lastAction = "Buying UID " .. tostring(chosen.uid) .. " for " .. tostring(chosen.price)
        updateStatusParagraph()
        buyEggByUID(chosen.uid)
        focusEggByUID(chosen.uid)
        statusData.totalBuys = (statusData.totalBuys or 0) + 1
        statusData.lastAction = "Bought + Focused UID " .. tostring(chosen.uid)
        updateStatusParagraph()
        task.wait(0.25)
    end
end

Tabs.AutoTab:Toggle({
    Title = "Auto Buy Egg",
    Desc = "Buys eggs from your island conveyor that match the selected egg IDs",
    Value = false,
    Callback = function(state)
        autoBuyEnabled = state
        if state and not autoBuyThread then
            autoBuyThread = task.spawn(function()
                runAutoBuy()
                autoBuyThread = nil
            end)
            WindUI:Notify({ Title = "Auto Buy", Content = "Started", Duration = 3 })
            statusData.lastAction = "Started"
            updateStatusParagraph()
        elseif (not state) and autoBuyThread then
            WindUI:Notify({ Title = "Auto Buy", Content = "Stopped", Duration = 3 })
            statusData.lastAction = "Stopped"
            updateStatusParagraph()
        end
    end
})

-- Auto Place functionality
local autoPlaceEnabled = false
local autoPlaceThread = nil
local placeAnchorPosition = nil
local anchorRadiusStuds = 300


-- Auto Place status tracking
local placeStatusData = {
    islandName = nil,
    islandNumber = nil,
    farmPartsFound = 0,
    petUID = nil,
    petInfo = nil,
    totalPlaces = 0,
    lastAction = "Idle",
    lastPosition = nil,
    validationStatus = nil,
}

Tabs.PlaceTab:Section({ Title = "Status", Icon = "info" })
Tabs.PlaceTab:Paragraph({
    Title = "How to use",
    Desc = table.concat({
        "1) Stand where you want pets to appear.",
        "2) Press 'Save Current Location'.",
        "3) Turn on 'Auto Place'.",
        "Tip: It will try free tiles within 300 studs of your saved spot.",
    }, "\n"),
    Image = "info",
    ImageSize = 16,
})
local placeStatusParagraph = Tabs.PlaceTab:Paragraph({
    Title = "Auto Place",
    Desc = "Save your spot, then turn on.",
    Image = "map-pin",
    ImageSize = 18,
})

local function formatPlaceStatusDesc()
    local lines = {}
    table.insert(lines, string.format("Island: %s", tostring(placeStatusData.islandName or "?")))
    table.insert(lines, string.format("Tiles: %d | Placed: %d", placeStatusData.farmPartsFound or 0, placeStatusData.totalPlaces or 0))
    if placeAnchorPosition then
        table.insert(lines, string.format("Anchor: r=%d (%.0f, %.0f, %.0f)", anchorRadiusStuds, placeAnchorPosition.X, placeAnchorPosition.Y, placeAnchorPosition.Z))
    end
    if placeStatusData.lastPosition then
        table.insert(lines, "Last: " .. tostring(placeStatusData.lastPosition))
    end
    table.insert(lines, "Status: " .. tostring(placeStatusData.lastAction))
    return table.concat(lines, "\n")
end

local function updatePlaceStatusParagraph()
    if placeStatusParagraph and placeStatusParagraph.SetDesc then
        placeStatusParagraph:SetDesc(formatPlaceStatusDesc())
    end
end

local function runAutoPlace()
    while autoPlaceEnabled do
        local ok, err = pcall(function()
            local islandName = getAssignedIslandName()
            placeStatusData.islandName = islandName
            
            if not islandName or islandName == "" then
                placeStatusData.lastAction = "Waiting for island assignment"
                updatePlaceStatusParagraph()
                task.wait(0.6)
                return
            end
            
            local islandNumber = getIslandNumberFromName(islandName)
            placeStatusData.islandNumber = islandNumber
            
            if not islandNumber then
                placeStatusData.lastAction = "Could not determine island number from: " .. tostring(islandName)
                updatePlaceStatusParagraph()
                task.wait(0.6)
                return
            end
            
            local farmParts = getFarmParts(islandNumber)
            placeStatusData.farmPartsFound = #farmParts
            
            if placeStatusData.farmPartsFound == 0 then
                placeStatusData.lastAction = "No farm parts found on Island_" .. tostring(islandNumber)
                updatePlaceStatusParagraph()
                task.wait(0.6)
                return
            end
            
            local petUID = getPetUID()
            placeStatusData.petUID = petUID
            
                    if not petUID then
            placeStatusData.lastAction = "No PET UID found in PlayerGui.Data.Egg.Name"
            placeStatusData.validationStatus = "No PET UID"
            updatePlaceStatusParagraph()
            task.wait(0.6)
            return
        end
            
            -- Enhanced pet validation and info gathering
            local isValid, validationMsg = validatePetUID(petUID)
            placeStatusData.validationStatus = validationMsg
            
            if not isValid then
                placeStatusData.lastAction = "PET UID validation failed: " .. validationMsg
                updatePlaceStatusParagraph()
                task.wait(0.6)
                return
            end
            
            -- Get pet information for better status display
            placeStatusData.petInfo = getPetInfo(petUID)
            
            -- Only place around the saved anchor spot
            if not placeAnchorPosition then
                placeStatusData.lastAction = "Save a spot first (Press 'Save Current Location')"
                updatePlaceStatusParagraph()
                task.wait(0.8)
                return
            end
            local minSpacing = 8 -- studs between pets
            local chosenPart
            local targetPos = placeAnchorPosition
            -- Restrict to tiles within anchorRadiusStuds to keep placement localized
            local nearby = {}
            for _, part in ipairs(farmParts) do
                if (part.Position - targetPos).Magnitude <= anchorRadiusStuds then
                    table.insert(nearby, part)
                end
            end
            chosenPart = findAvailableFarmPartNearPosition(#nearby > 0 and nearby or farmParts, minSpacing, targetPos)
            if not chosenPart then
                placeStatusData.lastAction = "All farm tiles occupied (min spacing " .. tostring(minSpacing) .. ")"
                updatePlaceStatusParagraph()
                task.wait(0.6)
                return
            end
            local position = chosenPart.Position
            placeStatusData.lastPosition = string.format("(%.1f, %.1f, %.1f)", position.X, position.Y, position.Z)
            placeStatusData.lastAction = "Placing PET " .. tostring(petUID) .. " at center " .. placeStatusData.lastPosition
            updatePlaceStatusParagraph()
            
            local success = placePetAtPart(chosenPart, petUID)
            if success then
                placeStatusData.totalPlaces = (placeStatusData.totalPlaces or 0) + 1
                placeStatusData.lastAction = "Successfully placed PET " .. tostring(petUID)
            else
                placeStatusData.lastAction = "Failed to place PET " .. tostring(petUID)
            end
            updatePlaceStatusParagraph()
            
            task.wait(0.5)
        end)
        
        if not ok then
            warn("Auto Place error: " .. tostring(err))
            placeStatusData.lastAction = "Error: " .. tostring(err)
            updatePlaceStatusParagraph()
            task.wait(1) -- Wait longer on error
        end
    end
end

Tabs.PlaceTab:Toggle({
    Title = "Auto Place",
    Desc = "Automatically places pets from your inventory at farm locations",
    Value = false,
    Callback = function(state)
        autoPlaceEnabled = state
        if state and not autoPlaceThread then
            -- Capture anchor when turning on if not set
            if not placeAnchorPosition then
                placeAnchorPosition = getPlayerRootPosition()
            end
            autoPlaceThread = task.spawn(function()
                runAutoPlace()
                autoPlaceThread = nil
            end)
            WindUI:Notify({ Title = "Auto Place", Content = "Started", Duration = 3 })
            placeStatusData.lastAction = "Started"
            updatePlaceStatusParagraph()
        elseif (not state) and autoPlaceThread then
            WindUI:Notify({ Title = "Auto Place", Content = "Stopped", Duration = 3 })
            placeStatusData.lastAction = "Stopped"
            updatePlaceStatusParagraph()
        end
    end
})

-- Anchoring tools
Tabs.PlaceTab:Button({
    Title = "Save Current Location",
    Desc = "Use your current position as an anchor (100 studs radius)",
    Callback = function()
        local pos = getPlayerRootPosition()
        if not pos then
            WindUI:Notify({ Title = "Auto Place", Content = "Could not read player position", Duration = 3 })
            return
        end
        placeAnchorPosition = pos
        WindUI:Notify({ Title = "Auto Place", Content = string.format("Anchor saved r=%d", anchorRadiusStuds), Duration = 3 })
        placeStatusData.lastAction = "Anchor saved"
        updatePlaceStatusParagraph()
    end
})
Tabs.PlaceTab:Button({
    Title = "Clear Anchor",
    Desc = "Forget saved anchor; place anywhere",
    Callback = function()
        placeAnchorPosition = nil
        WindUI:Notify({ Title = "Auto Place", Content = "Anchor cleared", Duration = 3 })
        placeStatusData.lastAction = "Anchor cleared"
        updatePlaceStatusParagraph()
    end
})

-- Manual place button for testing
Tabs.PlaceTab:Button({
    Title = "Place Pet Now",
    Desc = "Manually place a pet at the nearest free farm location",
    Callback = function()
        local islandName = getAssignedIslandName()
        if not islandName then
            WindUI:Notify({ Title = "Error", Content = "No island assigned", Duration = 3 })
            return
        end
        
        local islandNumber = getIslandNumberFromName(islandName)
        if not islandNumber then
            WindUI:Notify({ Title = "Error", Content = "Could not determine island number", Duration = 3 })
            return
        end
        
        local farmParts = getFarmParts(islandNumber)
        if #farmParts == 0 then
            WindUI:Notify({ Title = "Error", Content = "No farm parts found", Duration = 3 })
            return
        end
        
        local petUID = getPetUID()
        if not petUID then
            WindUI:Notify({ Title = "Error", Content = "No PET UID found in PlayerGui.Data.Egg.Name", Duration = 3 })
            return
        end
        
        -- Enhanced validation
        local isValid, validationMsg = validatePetUID(petUID)
        if not isValid then
            WindUI:Notify({ Title = "Error", Content = "PET UID validation failed: " .. validationMsg, Duration = 3 })
            return
        end
        
        -- Prefer an available tile using pivot occupancy checks
        local targetPos = placeAnchorPosition or getPlayerRootPosition()
        local nearby = {}
        for _, part in ipairs(farmParts) do
            if not targetPos or (part.Position - targetPos).Magnitude <= anchorRadiusStuds then
                table.insert(nearby, part)
            end
        end
        local chosenPart = findAvailableFarmPartNearPosition(#nearby > 0 and nearby or farmParts, 8, targetPos)
        if not chosenPart then
            WindUI:Notify({ Title = "Error", Content = "All farm tiles are occupied nearby", Duration = 3 })
            placeStatusData.lastAction = "Manual place failed (occupied)"
            updatePlaceStatusParagraph()
            return
        end
        local success = placePetAtPart(chosenPart, petUID)
        
        if success then
            WindUI:Notify({ Title = "Success", Content = "Pet placed at farm location", Duration = 3 })
            placeStatusData.totalPlaces = (placeStatusData.totalPlaces or 0) + 1
            placeStatusData.lastAction = "Manual place successful"
            updatePlaceStatusParagraph()
        else
            WindUI:Notify({ Title = "Error", Content = "Failed to place pet", Duration = 3 })
            placeStatusData.lastAction = "Manual place failed"
            updatePlaceStatusParagraph()
        end
    end
})

-- Pet validation test button
Tabs.PlaceTab:Button({
    Title = "Test Pet Validation",
    Desc = "Check if current PET UID is valid",
    Callback = function()
        local petUID = getPetUID()
        if not petUID then
            WindUI:Notify({ Title = "Error", Content = "No PET UID found in PlayerGui.Data.Egg.Name", Duration = 3 })
            return
        end
        
        local isValid, validationMsg = validatePetUID(petUID)
        local petInfo = getPetInfo(petUID)
        
        local message = "PET UID: " .. tostring(petUID) .. "\n"
        message = message .. "Validation: " .. validationMsg .. "\n"
        if petInfo and petInfo.Type then
            message = message .. "Pet Type: " .. tostring(petInfo.Type)
        end
        
        WindUI:Notify({ 
            Title = isValid and "Valid PET" or "Invalid PET", 
            Content = message, 
            Duration = 5 
        })
        
        -- Update status display
        placeStatusData.petUID = petUID
        placeStatusData.petInfo = petInfo
        placeStatusData.validationStatus = validationMsg
        updatePlaceStatusParagraph()
    end
})

-- Optional helper to open the window
Window:EditOpenButton({ Title = "Build A Zoo", Icon = "monitor", Draggable = true })

-- Close callback
Window:OnClose(function()
    autoBuyEnabled = false
    autoPlaceEnabled = false
end)


-- ============ Auto Claim Pack (every 10 minutes) ============
local autoPackEnabled = false
local autoPackThread = nil
local lastPackAt = 0

local function fireOnlinePack()
    local ok, err = pcall(function()
        REMOTE_DinoEventRE:FireServer({ event = "onlinepack" })
    end)
    if not ok then warn("OnlinePack fire failed: " .. tostring(err)) end
    return ok
end

local function runAutoPack()
    while autoPackEnabled do
        local now = os.clock()
        local since = now - (lastPackAt or 0)
        if since >= 600 then -- 10 minutes
            if fireOnlinePack() then
                lastPackAt = os.clock()
                WindUI:Notify({ Title = "Auto Pack", Content = "Online pack claimed", Duration = 3 })
            end
        end
        task.wait(5)
    end
end

Tabs.PackTab:Toggle({
    Title = "Auto Claim Pack",
    Desc = "Claims online pack every 10 minutes",
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



