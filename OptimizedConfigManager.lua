-- OptimizedConfigManager.lua - High-performance config system for low-end devices
-- Optimized for minimal freezing, reduced memory usage, and fast I/O operations

local OptimizedConfigManager = {}

-- Services
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Configuration
local CONFIG_FOLDER = "WindUI/Zebux/Optimized"
local UNIFIED_CONFIG_FILE = "BuildAZoo_Unified.json"
local BACKUP_CONFIG_FILE = "BuildAZoo_Backup.json"
local SAVE_DEBOUNCE_TIME = 0.5 -- Seconds to wait before saving
local MAX_CACHE_SIZE = 50 -- Maximum cached config sections

-- Ensure folders exist
pcall(function() 
    if not isfolder("WindUI") then makefolder("WindUI") end
    if not isfolder("WindUI/Zebux") then makefolder("WindUI/Zebux") end
    if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
end)

-- State management
local state = {
    configCache = {}, -- Lazy-loaded config sections
    saveQueue = {}, -- Pending saves (debounced)
    saveTimer = nil, -- Debounce timer
    lastSavedState = {}, -- For incremental updates
    isLoading = false, -- Prevent concurrent loads
    isSaving = false, -- Prevent concurrent saves
    cacheSize = 0 -- Track cache memory usage
}

-- Default configuration structure
local defaultConfig = {
    main = {
        autoBuy = false,
        autoHatch = false,
        autoPlace = false,
        autoUnlock = false,
        autoClaim = false
    },
    autoSystems = {
        autoDelete = false,
        autoDino = false,
        autoUpgrade = false,
        autoFeed = false,
        autoFish = false
    },
    customUI = {
        theme = "DarkPurple",
        notifications = true,
        compactMode = false
    },
    selections = {
        eggSelections = {},
        fruitSelections = {},
        feedFruitSelections = {},
        mutationOrder = {}
    },
    performance = {
        enableCache = true,
        asyncSave = true,
        compressData = true
    }
}

-- Utility Functions
local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = deepCopy(v)
    end
    return copy
end

local function getConfigPath()
    return string.format("%s/%s", CONFIG_FOLDER, UNIFIED_CONFIG_FILE)
end

local function getBackupPath()
    return string.format("%s/%s", CONFIG_FOLDER, BACKUP_CONFIG_FILE)
end

-- Data Compression (removes default values to reduce file size)
local function compressConfig(data)
    local compressed = {}
    
    local function compressSection(section, defaults, result)
        for key, value in pairs(section) do
            if type(value) == "table" and type(defaults[key]) == "table" then
                local compressedSub = {}
                compressSection(value, defaults[key], compressedSub)
                if next(compressedSub) then
                    result[key] = compressedSub
                end
            elseif value ~= defaults[key] then
                result[key] = value
            end
        end
    end
    
    compressSection(data, defaultConfig, compressed)
    return compressed
end

-- Data Decompression (restores default values)
local function decompressConfig(compressed)
    local function mergeDefaults(target, defaults)
        local result = deepCopy(defaults)
        if type(target) ~= "table" then return result end
        
        for key, value in pairs(target) do
            if type(value) == "table" and type(result[key]) == "table" then
                result[key] = mergeDefaults(value, result[key])
            else
                result[key] = value
            end
        end
        return result
    end
    
    return mergeDefaults(compressed, defaultConfig)
end

-- Cache Management
local function addToCache(section, data)
    if state.cacheSize >= MAX_CACHE_SIZE then
        -- Remove oldest cache entry
        local oldestKey = next(state.configCache)
        state.configCache[oldestKey] = nil
        state.cacheSize = state.cacheSize - 1
    end
    
    state.configCache[section] = data
    state.cacheSize = state.cacheSize + 1
end

local function clearCache()
    state.configCache = {}
    state.cacheSize = 0
end

-- Async File Operations (prevents freezing)
local function asyncReadFile(path, callback)
    coroutine.wrap(function()
        local success, result = pcall(function()
            if isfile(path) then
                return readfile(path)
            end
            return nil
        end)
        
        if callback then
            callback(success, result)
        end
    end)()
end

local function asyncWriteFile(path, data, callback)
    coroutine.wrap(function()
        local success, error = pcall(function()
            writefile(path, data)
        end)
        
        if callback then
            callback(success, error)
        end
    end)()
end

-- Debounced Save System
local function debouncedSave()
    -- Clear existing timer
    if state.saveTimer then
        state.saveTimer:Disconnect()
        state.saveTimer = nil
    end
    
    -- Set new timer
    state.saveTimer = task.delay(SAVE_DEBOUNCE_TIME, function()
        if next(state.saveQueue) and not state.isSaving then
            state.isSaving = true
            
            -- Merge all queued changes
            local finalConfig = deepCopy(state.lastSavedState)
            for section, changes in pairs(state.saveQueue) do
                if finalConfig[section] then
                    for key, value in pairs(changes) do
                        finalConfig[section][key] = value
                    end
                else
                    finalConfig[section] = changes
                end
            end
            
            -- Compress and save asynchronously
            local compressedData = state.performance and state.performance.compressData and compressConfig(finalConfig) or finalConfig
            local jsonData = HttpService:JSONEncode(compressedData)
            
            asyncWriteFile(getConfigPath(), jsonData, function(success, error)
                if success then
                    -- Create backup
                    asyncWriteFile(getBackupPath(), jsonData, function() end)
                    state.lastSavedState = finalConfig
                    state.saveQueue = {}
                else
                    warn("OptimizedConfig: Save failed - " .. tostring(error))
                end
                state.isSaving = false
            end)
        end
        state.saveTimer = nil
    end)
end

-- Public API
function OptimizedConfigManager:Init(windUI)
    self.WindUI = windUI
    
    -- Load initial config
    self:LoadConfig(function(success)
        if success and windUI then
            windUI:Notify({
                Title = "⚡ Optimized Config",
                Content = "System initialized successfully!",
                Duration = 2
            })
        end
    end)
    
    return true
end

function OptimizedConfigManager:LoadConfig(callback)
    if state.isLoading then
        if callback then callback(false, "Already loading") end
        return
    end
    
    state.isLoading = true
    
    asyncReadFile(getConfigPath(), function(success, data)
        if success and data then
            local parseSuccess, config = pcall(function()
                local parsed = HttpService:JSONDecode(data)
                return decompressConfig(parsed)
            end)
            
            if parseSuccess then
                state.lastSavedState = config
                clearCache() -- Clear cache when loading new config
                
                if callback then callback(true, config) end
            else
                -- Try backup file
                asyncReadFile(getBackupPath(), function(backupSuccess, backupData)
                    if backupSuccess and backupData then
                        local backupParseSuccess, backupConfig = pcall(function()
                            local parsed = HttpService:JSONDecode(backupData)
                            return decompressConfig(parsed)
                        end)
                        
                        if backupParseSuccess then
                            state.lastSavedState = backupConfig
                            if callback then callback(true, backupConfig) end
                        else
                            -- Use default config
                            state.lastSavedState = deepCopy(defaultConfig)
                            if callback then callback(true, state.lastSavedState) end
                        end
                    else
                        -- Use default config
                        state.lastSavedState = deepCopy(defaultConfig)
                        if callback then callback(true, state.lastSavedState) end
                    end
                    state.isLoading = false
                end)
                return
            end
        else
            -- Use default config
            state.lastSavedState = deepCopy(defaultConfig)
            if callback then callback(true, state.lastSavedState) end
        end
        
        state.isLoading = false
    end)
end

function OptimizedConfigManager:GetSection(sectionName, useCache)
    useCache = useCache ~= false -- Default to true
    
    -- Check cache first
    if useCache and state.configCache[sectionName] then
        return state.configCache[sectionName]
    end
    
    -- Get from main config
    local section = state.lastSavedState[sectionName] or defaultConfig[sectionName]
    
    -- Add to cache
    if useCache and section then
        addToCache(sectionName, deepCopy(section))
    end
    
    return section
end

function OptimizedConfigManager:SetSection(sectionName, data, immediate)
    immediate = immediate or false
    
    -- Update cache
    if state.configCache[sectionName] then
        state.configCache[sectionName] = deepCopy(data)
    end
    
    -- Queue for saving
    state.saveQueue[sectionName] = deepCopy(data)
    
    if immediate then
        -- Force immediate save
        if state.saveTimer then
            state.saveTimer:Disconnect()
            state.saveTimer = nil
        end
        debouncedSave()
    else
        -- Use debounced save
        debouncedSave()
    end
end

function OptimizedConfigManager:GetValue(sectionName, key, defaultValue)
    local section = self:GetSection(sectionName)
    return section and section[key] or defaultValue
end

function OptimizedConfigManager:SetValue(sectionName, key, value, immediate)
    local section = self:GetSection(sectionName) or {}
    section[key] = value
    self:SetSection(sectionName, section, immediate)
end

function OptimizedConfigManager:SaveImmediate(callback)
    if state.saveTimer then
        state.saveTimer:Disconnect()
        state.saveTimer = nil
    end
    
    -- Force immediate save
    if next(state.saveQueue) and not state.isSaving then
        state.isSaving = true
        
        local finalConfig = deepCopy(state.lastSavedState)
        for section, changes in pairs(state.saveQueue) do
            if finalConfig[section] then
                for key, value in pairs(changes) do
                    finalConfig[section][key] = value
                end
            else
                finalConfig[section] = changes
            end
        end
        
        local compressedData = compressConfig(finalConfig)
        local jsonData = HttpService:JSONEncode(compressedData)
        
        asyncWriteFile(getConfigPath(), jsonData, function(success, error)
            if success then
                asyncWriteFile(getBackupPath(), jsonData, function() end)
                state.lastSavedState = finalConfig
                state.saveQueue = {}
            else
                warn("OptimizedConfig: Immediate save failed - " .. tostring(error))
            end
            state.isSaving = false
            if callback then callback(success, error) end
        end)
    else
        if callback then callback(true) end
    end
end

function OptimizedConfigManager:GetStats()
    return {
        cacheSize = state.cacheSize,
        maxCacheSize = MAX_CACHE_SIZE,
        queuedSaves = #state.saveQueue,
        isLoading = state.isLoading,
        isSaving = state.isSaving,
        configPath = getConfigPath(),
        backupPath = getBackupPath()
    }
end

function OptimizedConfigManager:ClearCache()
    clearCache()
end

-- Migration function for existing configs
function OptimizedConfigManager:MigrateFromLegacy(legacyConfigs, callback)
    local migratedConfig = deepCopy(defaultConfig)
    
    -- Migrate WindUI configs
    if legacyConfigs.windUIConfigs then
        for configName, configData in pairs(legacyConfigs.windUIConfigs) do
            if configName:find("BuildAZoo_Main") then
                for key, value in pairs(configData) do
                    migratedConfig.main[key] = value
                end
            elseif configName:find("BuildAZoo_AutoSystems") then
                for key, value in pairs(configData) do
                    migratedConfig.autoSystems[key] = value
                end
            elseif configName:find("BuildAZoo_CustomUI") then
                for key, value in pairs(configData) do
                    migratedConfig.customUI[key] = value
                end
            end
        end
    end
    
    -- Migrate custom selections
    if legacyConfigs.customSelections then
        migratedConfig.selections = legacyConfigs.customSelections
    end
    
    -- Save migrated config
    state.lastSavedState = migratedConfig
    self:SaveImmediate(callback)
end

return OptimizedConfigManager
