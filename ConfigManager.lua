-- ConfigManager.lua - Configuration loading and saving for Build A Zoo
-- Author: Zebux

local ConfigManager = {}
local Core = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/Core.lua"))()

-- Configuration variables
local eggConfig = {}
local conveyorConfig = {}
local petFoodConfig = {}
local mutationConfig = {}

-- Map for egg ID to type conversion
local idToTypeMap = {}

-- Config loading functions
function ConfigManager.loadEggConfig()
    local ok, cfg = pcall(function()
        local cfgFolder = Core.ReplicatedStorage:WaitForChild("Config")
        local module = cfgFolder:WaitForChild("ResEgg")
        return require(module)
    end)
    if ok and type(cfg) == "table" then
        eggConfig = cfg
    else
        eggConfig = {}
    end
    return eggConfig
end

function ConfigManager.loadConveyorConfig()
    local ok, cfg = pcall(function()
        local cfgFolder = Core.ReplicatedStorage:WaitForChild("Config")
        local module = cfgFolder:WaitForChild("ResConveyor")
        return require(module)
    end)
    if ok and type(cfg) == "table" then
        conveyorConfig = cfg
    else
        conveyorConfig = {}
    end
    return conveyorConfig
end

function ConfigManager.loadPetFoodConfig()
    local ok, cfg = pcall(function()
        local cfgFolder = Core.ReplicatedStorage:WaitForChild("Config")
        local module = cfgFolder:WaitForChild("ResPetFood")
        return require(module)
    end)
    if ok and type(cfg) == "table" then
        petFoodConfig = cfg
    else
        petFoodConfig = {}
    end
    return petFoodConfig
end

function ConfigManager.loadMutationConfig()
    local ok, cfg = pcall(function()
        local cfgFolder = Core.ReplicatedStorage:WaitForChild("Config")
        local module = cfgFolder:WaitForChild("ResMutate")
        return require(module)
    end)
    if ok and type(cfg) == "table" then
        mutationConfig = cfg
    else
        mutationConfig = {}
    end
    return mutationConfig
end

-- Helper functions
local function getTypeFromConfig(key, val)
    if type(val) == "table" then
        local t = val.Type or val.Name or val.type or val.name
        if t ~= nil then return tostring(t) end
    end
    return tostring(key)
end

function ConfigManager.buildEggIdList()
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

function ConfigManager.buildMutationList()
    local mutations = {}
    for id, val in pairs(mutationConfig) do
        local idStr = tostring(id)
        -- Filter out meta keys like _index, __index, and any leading underscore entries
        if not string.match(idStr, "^_%_?index$") and not string.match(idStr, "^__index$") and not idStr:match("^_") then
            local mutationName = val.Name or val.ID or val.Id or idStr
            mutationName = tostring(mutationName)
            
            table.insert(mutations, mutationName)
        end
    end
    table.sort(mutations)
    return mutations
end

-- Price helpers
function ConfigManager.getEggPriceById(eggId)
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

function ConfigManager.getEggPriceByType(eggType)
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
                local price = ConfigManager.getEggPriceById(key)
                if type(price) == "number" then return price end
            end
        end
    end
    return nil
end

-- Getters for configs
function ConfigManager.getEggConfig()
    return eggConfig
end

function ConfigManager.getConveyorConfig()
    return conveyorConfig
end

function ConfigManager.getPetFoodConfig()
    return petFoodConfig
end

function ConfigManager.getMutationConfig()
    return mutationConfig
end

function ConfigManager.getIdToTypeMap()
    return idToTypeMap
end

-- Initialize all configs
function ConfigManager.initializeAll()
    ConfigManager.loadEggConfig()
    ConfigManager.loadConveyorConfig()
    ConfigManager.loadPetFoodConfig()
    ConfigManager.loadMutationConfig()
    ConfigManager.buildEggIdList()
    ConfigManager.buildMutationList()
end

return ConfigManager
