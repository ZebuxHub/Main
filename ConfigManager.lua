-- ConfigManager.lua - Centralized Configuration Management for Build A Zoo
-- Handles all file I/O operations and config management

local ConfigManager = {}

-- Services
local HttpService = game:GetService("HttpService")

-- File system functions
local isfolder = isfolder
local makefolder = makefolder
local writefile = writefile
local readfile = readfile
local isfile = isfile
local delfile = delfile
local listfiles = listfiles

-- Config paths
local BASE_CFG_FOLDER = "WindUI/Zebux"
local CUSTOM_CFG_FOLDER = BASE_CFG_FOLDER .. "/custom"

-- Initialize folders
pcall(function() if not isfolder(BASE_CFG_FOLDER) then makefolder(BASE_CFG_FOLDER) end end)
pcall(function() if not isfolder(CUSTOM_CFG_FOLDER) then makefolder(CUSTOM_CFG_FOLDER) end end)

-- Legacy file name mappings
local function legacyNameFor(fileName)
    if fileName == "ClaimSettings.json" then return "Zebux_ClaimSettings.json" end
    if fileName == "EggSelections.json" then return "Zebux_EggSelections.json" end
    if fileName == "FruitSelections.json" then return "Zebux_FruitSelections.json" end
    if fileName == "FeedFruitSelections.json" then return "Zebux_FeedFruitSelections.json" end
    if fileName == "CustomSelections.json" then return "Zebux_CustomSelections.json" end
    return nil
end

-- Get config file path
local function cfgPath(fileName)
    return string.format("%s/%s", CUSTOM_CFG_FOLDER, fileName)
end

-- Save JSON data to custom config folder
function ConfigManager.saveJSONCustom(fileName, data)
    pcall(function()
        local path = cfgPath(fileName)
        writefile(path, HttpService:JSONEncode(data))
    end)
end

-- Load JSON data from custom config folder (with legacy migration)
function ConfigManager.loadJSONCustom(fileName)
    local ok, result = pcall(function()
        local path = cfgPath(fileName)
        if isfile(path) then
            return HttpService:JSONDecode(readfile(path))
        end
        -- Migration from legacy flat files (root)
        local legacy = legacyNameFor(fileName)
        if legacy and isfile(legacy) then
            local jsonData = readfile(legacy)
            local decoded = HttpService:JSONDecode(jsonData)
            -- Write to new organized path and remove legacy
            writefile(path, jsonData)
            pcall(function() delfile(legacy) end)
            return decoded
        end
        return nil
    end)
    if ok then return result end
    return nil
end

-- Save all custom selections
function ConfigManager.saveCustomSelections(customSelections)
    local success, err = pcall(function()
        ConfigManager.saveJSONCustom("CustomSelections.json", customSelections)
    end)
    
    if not success then
        warn("Failed to save custom selections: " .. tostring(err))
    end
end

-- Load all custom selections
function ConfigManager.loadCustomSelections()
    local customSelections = {
        eggSelections = {},
        fruitSelections = {},
        feedFruitSelections = {}
    }
    
    local success, err = pcall(function()
        local loaded = ConfigManager.loadJSONCustom("CustomSelections.json")
        if loaded then
            customSelections = loaded
        end
    end)
    
    if not success then
        warn("Failed to load custom selections: " .. tostring(err))
    end
    
    return customSelections
end

-- Update specific custom UI selection
function ConfigManager.updateCustomUISelection(uiType, selections, customSelections)
    if uiType == "eggSelections" then
        customSelections.eggSelections = {
            eggs = {},
            mutations = {}
        }
        for eggId, _ in pairs(selections.eggs or {}) do
            table.insert(customSelections.eggSelections.eggs, eggId)
        end
        for mutationId, _ in pairs(selections.mutations or {}) do
            table.insert(customSelections.eggSelections.mutations, mutationId)
        end
    elseif uiType == "fruitSelections" then
        customSelections.fruitSelections = {}
        for fruitId, _ in pairs(selections) do
            table.insert(customSelections.fruitSelections, fruitId)
        end
    elseif uiType == "feedFruitSelections" then
        customSelections.feedFruitSelections = {}
        for fruitId, _ in pairs(selections) do
            table.insert(customSelections.feedFruitSelections, fruitId)
        end
    end
    
    ConfigManager.saveCustomSelections(customSelections)
end

-- Enhanced save function for all configs
function ConfigManager.saveAllConfigs(mainConfig, autoSystemsConfig, customUIConfig, customSelections)
    local results = {}
    
    -- Save main config
    local mainSuccess, mainErr = pcall(function()
        mainConfig:Save()
    end)
    results.mainConfig = mainSuccess and "✅ Success" or ("❌ " .. tostring(mainErr))
    
    -- Save auto systems config
    local autoSuccess, autoErr = pcall(function()
        autoSystemsConfig:Save()
    end)
    results.autoSystemsConfig = autoSuccess and "✅ Success" or ("❌ " .. tostring(autoErr))
    
    -- Save custom UI config
    local customUISuccess, customUIErr = pcall(function()
        customUIConfig:Save()
    end)
    results.customUIConfig = customUISuccess and "✅ Success" or ("❌ " .. tostring(customUIErr))
    
    -- Save custom selections
    local customSuccess, customErr = pcall(function()
        ConfigManager.saveCustomSelections(customSelections)
    end)
    results.customSelections = customSuccess and "✅ Success" or ("❌ " .. tostring(customErr))
    
    return results
end

-- Enhanced load function for all configs
function ConfigManager.loadAllConfigs(mainConfig, autoSystemsConfig, customUIConfig)
    local results = {}
    
    -- Load main config
    local mainSuccess, mainErr = pcall(function()
        mainConfig:Load()
    end)
    results.mainConfig = mainSuccess and "✅ Success" or ("❌ " .. tostring(mainErr))
    
    -- Load auto systems config
    local autoSuccess, autoErr = pcall(function()
        autoSystemsConfig:Load()
    end)
    results.autoSystemsConfig = autoSuccess and "✅ Success" or ("❌ " .. tostring(autoErr))
    
    -- Load custom UI config
    local customUISuccess, customUIErr = pcall(function()
        customUIConfig:Load()
    end)
    results.customUIConfig = customUISuccess and "✅ Success" or ("❌ " .. tostring(customUIErr))
    
    -- Load custom selections
    local customSelections = ConfigManager.loadCustomSelections()
    results.customSelections = "✅ Success"
    
    return results, customSelections
end

-- Clean up config files (for reset functionality)
function ConfigManager.resetAllConfigs()
    local success, err = pcall(function()
        -- Delete WindUI config files
        local configFiles = listfiles("WindUI/Zebux/config")
        for _, file in ipairs(configFiles) do
            if file:match("zebuxConfig%.json$") then
                delfile(file)
            end
        end
        
        -- Delete organized custom selections folder
        if isfolder(CUSTOM_CFG_FOLDER) then
            for _, f in ipairs(listfiles(CUSTOM_CFG_FOLDER)) do
                pcall(function() delfile(f) end)
            end
        end
    end)
    
    if not success then
        warn("Failed to reset configs: " .. tostring(err))
    end
    
    return success
end

return ConfigManager
