-- UnifiedConfigManager.lua - Centralized Config System for Build A Zoo
-- Optimized for low-end devices with lazy loading and memory management
-- Supports both WindUI and Custom UI systems

local UnifiedConfigManager = {}

-- Services
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Configuration
local CONFIG = {
    BASE_FOLDER = "WindUI/Zebux/BuildAZoo",
    UNIFIED_FILE = "UnifiedConfig.json",
    BACKUP_FOLDER = "backup",
    MAX_BACKUPS = 3,
    SAVE_DEBOUNCE = 2, -- seconds
    MEMORY_CLEANUP_INTERVAL = 30, -- seconds
    COMPRESSION_ENABLED = true
}

-- State Management
local configData = {}
local registeredElements = {}
local saveDebounceTimer = nil
local lastSaveTime = 0
local memoryCleanupConnection = nil
local isInitialized = false

-- Performance tracking
local performanceStats = {
    saveCount = 0,
    loadCount = 0,
    totalSaveTime = 0,
    totalLoadTime = 0,
    memoryUsage = 0
}

-- Utility Functions
local function createFolders()
    local folders = {
        CONFIG.BASE_FOLDER,
        CONFIG.BASE_FOLDER .. "/" .. CONFIG.BACKUP_FOLDER
    }
    
    for _, folder in ipairs(folders) do
        pcall(function()
            if not isfolder(folder) then
                makefolder(folder)
            end
        end)
    end
end

local function getConfigPath()
    return CONFIG.BASE_FOLDER .. "/" .. CONFIG.UNIFIED_FILE
end

local function getBackupPath(index)
    return CONFIG.BASE_FOLDER .. "/" .. CONFIG.BACKUP_FOLDER .. "/backup_" .. tostring(index) .. ".json"
end

-- Compression utilities for large configs
local function compressData(data)
    if not CONFIG.COMPRESSION_ENABLED then return data end
    
    -- Simple compression: remove unnecessary whitespace and optimize structure
    local compressed = {}
    for key, value in pairs(data) do
        if type(value) == "table" and next(value) then
            compressed[key] = value
        elseif type(value) ~= "table" and value ~= nil and value ~= "" then
            compressed[key] = value
        end
    end
    return compressed
end

-- Memory management
local function updateMemoryUsage()
    performanceStats.memoryUsage = collectgarbage("count")
end

local function cleanupMemory()
    -- Clean up unused references
    for elementId, element in pairs(registeredElements) do
        if element.cleanup and type(element.cleanup) == "function" then
            pcall(element.cleanup)
        end
    end
    
    -- Force garbage collection on low-end devices
    if performanceStats.memoryUsage > 50000 then -- 50MB threshold
        collectgarbage("collect")
    end
    
    updateMemoryUsage()
end

-- Backup management
local function createBackup()
    local configPath = getConfigPath()
    if not isfile(configPath) then return end
    
    pcall(function()
        local currentData = readfile(configPath)
        
        -- Shift existing backups
        for i = CONFIG.MAX_BACKUPS - 1, 1, -1 do
            local currentBackup = getBackupPath(i)
            local nextBackup = getBackupPath(i + 1)
            
            if isfile(currentBackup) then
                if i == CONFIG.MAX_BACKUPS - 1 then
                    -- Delete oldest backup
                    delfile(nextBackup)
                end
                -- Move backup up one slot
                writefile(nextBackup, readfile(currentBackup))
                delfile(currentBackup)
            end
        end
        
        -- Create new backup
        writefile(getBackupPath(1), currentData)
    end)
end

-- Core Config Functions
local function loadConfigData()
    local startTime = tick()
    
    local configPath = getConfigPath()
    if not isfile(configPath) then
        configData = {}
        return true
    end
    
    local success, result = pcall(function()
        local rawData = readfile(configPath)
        return HttpService:JSONDecode(rawData)
    end)
    
    if success and type(result) == "table" then
        configData = result
        performanceStats.loadCount = performanceStats.loadCount + 1
        performanceStats.totalLoadTime = performanceStats.totalLoadTime + (tick() - startTime)
        return true
    else
        -- Try to load from backup
        for i = 1, CONFIG.MAX_BACKUPS do
            local backupPath = getBackupPath(i)
            if isfile(backupPath) then
                local backupSuccess, backupResult = pcall(function()
                    local rawData = readfile(backupPath)
                    return HttpService:JSONDecode(rawData)
                end)
                
                if backupSuccess and type(backupResult) == "table" then
                    configData = backupResult
                    warn("UnifiedConfigManager: Loaded from backup " .. i)
                    return true
                end
            end
        end
        
        -- All failed, start fresh
        configData = {}
        warn("UnifiedConfigManager: Failed to load config, starting fresh")
        return false
    end
end

local function saveConfigData()
    local startTime = tick()
    
    -- Debounce saves to prevent spam
    local currentTime = tick()
    if currentTime - lastSaveTime < CONFIG.SAVE_DEBOUNCE then
        return false
    end
    
    createBackup()
    
    local success = pcall(function()
        local compressedData = compressData(configData)
        local jsonData = HttpService:JSONEncode(compressedData)
        writefile(getConfigPath(), jsonData)
    end)
    
    if success then
        lastSaveTime = currentTime
        performanceStats.saveCount = performanceStats.saveCount + 1
        performanceStats.totalSaveTime = performanceStats.totalSaveTime + (tick() - startTime)
    end
    
    return success
end

-- Element Registration System
function UnifiedConfigManager:Register(elementId, element, category)
    if not elementId or not element then
        warn("UnifiedConfigManager: Invalid registration parameters")
        return false
    end
    
    category = category or "default"
    
    -- Create category structure
    if not configData[category] then
        configData[category] = {}
    end
    
    -- Store element reference
    registeredElements[elementId] = {
        element = element,
        category = category,
        lastValue = nil
    }
    
    -- Load existing value if available
    if configData[category][elementId] ~= nil then
        self:LoadElement(elementId)
    end
    
    return true
end

function UnifiedConfigManager:Unregister(elementId)
    if registeredElements[elementId] then
        registeredElements[elementId] = nil
        return true
    end
    return false
end

-- Element Value Management
function UnifiedConfigManager:SaveElement(elementId)
    local registration = registeredElements[elementId]
    if not registration then return false end
    
    local element = registration.element
    local category = registration.category
    
    local value = nil
    
    -- Handle different element types
    if type(element) == "table" then
        if element.Get and type(element.Get) == "function" then
            -- Custom getter
            local success, result = pcall(element.Get)
            if success then value = result end
        elseif element.Value ~= nil then
            -- Direct value access
            value = element.Value
        end
    elseif type(element) == "function" then
        -- Function-based element
        local success, result = pcall(element)
        if success then value = result end
    end
    
    if value ~= nil then
        configData[category][elementId] = value
        registration.lastValue = value
        return true
    end
    
    return false
end

function UnifiedConfigManager:LoadElement(elementId)
    local registration = registeredElements[elementId]
    if not registration then return false end
    
    local element = registration.element
    local category = registration.category
    local value = configData[category][elementId]
    
    if value == nil then return false end
    
    -- Handle different element types
    if type(element) == "table" then
        if element.Set and type(element.Set) == "function" then
            -- Custom setter
            local success = pcall(element.Set, value)
            if success then registration.lastValue = value end
            return success
        elseif element.SetValue and type(element.SetValue) == "function" then
            -- WindUI-style setter
            local success = pcall(element.SetValue, value)
            if success then registration.lastValue = value end
            return success
        end
    elseif type(element) == "function" then
        -- Function-based element
        local success = pcall(element, value)
        if success then registration.lastValue = value end
        return success
    end
    
    return false
end

-- Batch Operations
function UnifiedConfigManager:SaveAll(category)
    local savedCount = 0
    local totalCount = 0
    
    for elementId, registration in pairs(registeredElements) do
        if not category or registration.category == category then
            totalCount = totalCount + 1
            if self:SaveElement(elementId) then
                savedCount = savedCount + 1
            end
        end
    end
    
    local success = saveConfigData()
    return success, savedCount, totalCount
end

function UnifiedConfigManager:LoadAll(category)
    local loadedCount = 0
    local totalCount = 0
    
    for elementId, registration in pairs(registeredElements) do
        if not category or registration.category == category then
            totalCount = totalCount + 1
            if self:LoadElement(elementId) then
                loadedCount = loadedCount + 1
            end
        end
    end
    
    return true, loadedCount, totalCount
end

-- Auto-save functionality
function UnifiedConfigManager:EnableAutoSave(interval)
    interval = interval or 30 -- Default 30 seconds
    
    if saveDebounceTimer then
        saveDebounceTimer:Disconnect()
    end
    
    saveDebounceTimer = task.spawn(function()
        while true do
            task.wait(interval)
            if next(registeredElements) then
                self:SaveAll()
            end
        end
    end)
end

function UnifiedConfigManager:DisableAutoSave()
    if saveDebounceTimer then
        pcall(function() task.cancel(saveDebounceTimer) end)
        saveDebounceTimer = nil
    end
end

-- Performance and Debugging
function UnifiedConfigManager:GetStats()
    updateMemoryUsage()
    return {
        registeredElements = #registeredElements,
        categories = #configData,
        saves = performanceStats.saveCount,
        loads = performanceStats.loadCount,
        avgSaveTime = performanceStats.saveCount > 0 and (performanceStats.totalSaveTime / performanceStats.saveCount) or 0,
        avgLoadTime = performanceStats.loadCount > 0 and (performanceStats.totalLoadTime / performanceStats.loadCount) or 0,
        memoryUsage = performanceStats.memoryUsage,
        configSize = #HttpService:JSONEncode(configData)
    }
end

function UnifiedConfigManager:GetCategories()
    local categories = {}
    for category, _ in pairs(configData) do
        table.insert(categories, category)
    end
    return categories
end

function UnifiedConfigManager:ExportCategory(category)
    if configData[category] then
        return HttpService:JSONEncode(configData[category])
    end
    return nil
end

function UnifiedConfigManager:ImportCategory(category, jsonData)
    local success, data = pcall(function()
        return HttpService:JSONDecode(jsonData)
    end)
    
    if success and type(data) == "table" then
        configData[category] = data
        return saveConfigData()
    end
    
    return false
end

-- Initialization
function UnifiedConfigManager:Init()
    if isInitialized then return true end
    
    createFolders()
    loadConfigData()
    
    -- Setup memory cleanup
    memoryCleanupConnection = task.spawn(function()
        while true do
            task.wait(CONFIG.MEMORY_CLEANUP_INTERVAL)
            cleanupMemory()
        end
    end)
    
    -- Enable auto-save by default
    self:EnableAutoSave()
    
    isInitialized = true
    return true
end

-- Cleanup
function UnifiedConfigManager:Cleanup()
    self:DisableAutoSave()
    
    if memoryCleanupConnection then
        pcall(function() task.cancel(memoryCleanupConnection) end)
        memoryCleanupConnection = nil
    end
    
    -- Final save
    self:SaveAll()
    
    -- Clear memory
    configData = {}
    registeredElements = {}
    
    isInitialized = false
end

-- Legacy compatibility functions
function UnifiedConfigManager:CreateConfig(name)
    -- Return a wrapper that uses categories
    return {
        Register = function(_, elementId, element)
            return UnifiedConfigManager:Register(elementId, element, name)
        end,
        Load = function(_)
            return UnifiedConfigManager:LoadAll(name)
        end,
        Save = function(_)
            return UnifiedConfigManager:SaveAll(name)
        end
    }
end

return UnifiedConfigManager
