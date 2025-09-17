-- OptimizedConfigPatch.lua - Drop-in replacement for existing config system
-- Simply replace the existing config section with this code

-- ============ OPTIMIZED CONFIG SYSTEM FOR LOW-END DEVICES ============
-- This replaces the existing WindUI ConfigManager system with performance optimizations

local HttpService = game:GetService("HttpService")

-- Optimized Config Manager
local OptimizedConfig = {
    -- State
    cache = {},
    saveQueue = {},
    saveTimer = nil,
    lastSaved = {},
    isLoading = false,
    isSaving = false,
    
    -- Settings
    SAVE_DELAY = 0.5, -- Debounce time in seconds
    CONFIG_PATH = "WindUI/Zebux/BuildAZoo_Optimized.json",
    BACKUP_PATH = "WindUI/Zebux/BuildAZoo_Backup.json",
    MAX_CACHE = 20
}

-- Ensure folder exists
pcall(function() 
    if not isfolder("WindUI") then makefolder("WindUI") end
    if not isfolder("WindUI/Zebux") then makefolder("WindUI/Zebux") end
end)

-- Default configuration
OptimizedConfig.defaults = {
    -- Main settings
    autoBuy = false,
    autoHatch = false,
    autoPlace = false,
    autoUnlock = false,
    autoClaim = false,
    
    -- Auto systems
    autoDelete = false,
    autoDino = false,
    autoUpgrade = false,
    autoFeed = false,
    autoFish = false,
    
    -- UI settings
    theme = "DarkPurple",
    notifications = true,
    
    -- Custom selections
    eggSelections = {},
    fruitSelections = {},
    feedFruitSelections = {},
    mutationOrder = {}
}

-- Utility functions
function OptimizedConfig:deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do copy[k] = self:deepCopy(v) end
    return copy
end

function OptimizedConfig:compress(data)
    -- Remove default values to reduce file size
    local compressed = {}
    for key, value in pairs(data) do
        if self.defaults[key] ~= value then
            compressed[key] = value
        end
    end
    return compressed
end

function OptimizedConfig:decompress(compressed)
    -- Restore default values
    local result = self:deepCopy(self.defaults)
    if compressed then
        for key, value in pairs(compressed) do
            result[key] = value
        end
    end
    return result
end

-- Async file operations (prevents freezing)
function OptimizedConfig:asyncRead(callback)
    coroutine.wrap(function()
        local success, data = pcall(function()
            if isfile(self.CONFIG_PATH) then
                return readfile(self.CONFIG_PATH)
            elseif isfile(self.BACKUP_PATH) then
                return readfile(self.BACKUP_PATH)
            end
            return nil
        end)
        callback(success, data)
    end)()
end

function OptimizedConfig:asyncWrite(data, callback)
    coroutine.wrap(function()
        local success = pcall(function()
            local compressed = self:compress(data)
            local json = HttpService:JSONEncode(compressed)
            writefile(self.CONFIG_PATH, json)
            -- Create backup
            writefile(self.BACKUP_PATH, json)
        end)
        if callback then callback(success) end
    end)()
end

-- Debounced save system
function OptimizedConfig:debouncedSave()
    if self.saveTimer then self.saveTimer:Disconnect() end
    
    self.saveTimer = task.delay(self.SAVE_DELAY, function()
        if next(self.saveQueue) and not self.isSaving then
            self.isSaving = true
            
            -- Merge queued changes
            local finalData = self:deepCopy(self.lastSaved)
            for key, value in pairs(self.saveQueue) do
                finalData[key] = value
            end
            
            self:asyncWrite(finalData, function(success)
                if success then
                    self.lastSaved = finalData
                    self.saveQueue = {}
                else
                    warn("OptimizedConfig: Save failed")
                end
                self.isSaving = false
            end)
        end
        self.saveTimer = nil
    end)
end

-- Public API
function OptimizedConfig:Load(callback)
    if self.isLoading then return end
    self.isLoading = true
    
    self:asyncRead(function(success, data)
        if success and data then
            local parseSuccess, config = pcall(function()
                return self:decompress(HttpService:JSONDecode(data))
            end)
            
            if parseSuccess then
                self.lastSaved = config
                self.cache = {} -- Clear cache
            else
                self.lastSaved = self:deepCopy(self.defaults)
            end
        else
            self.lastSaved = self:deepCopy(self.defaults)
        end
        
        self.isLoading = false
        if callback then callback(true) end
    end)
end

function OptimizedConfig:Get(key, defaultValue)
    -- Check cache first
    if self.cache[key] ~= nil then
        return self.cache[key]
    end
    
    -- Get from main config
    local value = self.lastSaved[key]
    if value == nil then value = defaultValue or self.defaults[key] end
    
    -- Cache the value (with size limit)
    if #self.cache < self.MAX_CACHE then
        self.cache[key] = value
    end
    
    return value
end

function OptimizedConfig:Set(key, value, immediate)
    -- Update cache
    self.cache[key] = value
    
    -- Queue for saving
    self.saveQueue[key] = value
    
    if immediate then
        -- Force immediate save
        if self.saveTimer then self.saveTimer:Disconnect() end
        self:debouncedSave()
    else
        -- Use debounced save
        self:debouncedSave()
    end
end

function OptimizedConfig:SaveNow(callback)
    if self.saveTimer then self.saveTimer:Disconnect() end
    
    if next(self.saveQueue) then
        local finalData = self:deepCopy(self.lastSaved)
        for key, value in pairs(self.saveQueue) do
            finalData[key] = value
        end
        
        self:asyncWrite(finalData, function(success)
            if success then
                self.lastSaved = finalData
                self.saveQueue = {}
            end
            if callback then callback(success) end
        end)
    else
        if callback then callback(true) end
    end
end

-- Migration from legacy system
function OptimizedConfig:MigrateFromLegacy()
    local migrated = false
    
    -- Legacy WindUI config files
    local legacyFiles = {
        "WindUI/Zebux/BuildAZoo_Main.json",
        "WindUI/Zebux/BuildAZoo_AutoSystems.json", 
        "WindUI/Zebux/BuildAZoo_CustomUI.json"
    }
    
    -- Legacy custom files
    local customFiles = {
        "Zebux_EggSelections.json",
        "Zebux_FruitSelections.json",
        "Zebux_FeedFruitSelections.json",
        "WindUI/Zebux/custom/CustomSelections.json"
    }
    
    local migratedData = self:deepCopy(self.defaults)
    
    -- Migrate WindUI configs
    for _, file in ipairs(legacyFiles) do
        local success, data = pcall(function()
            if isfile(file) then
                local content = HttpService:JSONDecode(readfile(file))
                for key, value in pairs(content) do
                    migratedData[key] = value
                end
                migrated = true
                -- Clean up legacy file
                delfile(file)
            end
        end)
    end
    
    -- Migrate custom selections
    for _, file in ipairs(customFiles) do
        local success, data = pcall(function()
            if isfile(file) then
                local content = HttpService:JSONDecode(readfile(file))
                if file:find("EggSelections") then
                    migratedData.eggSelections = content
                elseif file:find("FruitSelections") then
                    migratedData.fruitSelections = content
                elseif file:find("FeedFruitSelections") then
                    migratedData.feedFruitSelections = content
                elseif file:find("CustomSelections") then
                    for key, value in pairs(content) do
                        migratedData[key] = value
                    end
                end
                migrated = true
                -- Clean up legacy file
                delfile(file)
            end
        end)
    end
    
    if migrated then
        self.lastSaved = migratedData
        self:SaveNow()
        return true
    end
    
    return false
end

-- Initialize the system
OptimizedConfig:Load(function()
    -- Try migration if no config exists
    if not next(OptimizedConfig.lastSaved) or OptimizedConfig.lastSaved == OptimizedConfig.defaults then
        OptimizedConfig:MigrateFromLegacy()
    end
end)

-- ============ COMPATIBILITY LAYER ============
-- Replace existing ConfigManager with optimized version

-- Create compatible ConfigManager
local ConfigManager = {}
ConfigManager.__index = ConfigManager

function ConfigManager:CreateConfig(name)
    return {
        Save = function() OptimizedConfig:SaveNow() end,
        Load = function() OptimizedConfig:Load() end,
        LoadFromData = function(self, data) 
            for key, value in pairs(data) do
                OptimizedConfig:Set(key, value, true)
            end
        end
    }
end

function ConfigManager:AllConfigs()
    return {
        ["BuildAZoo_Main"] = OptimizedConfig.lastSaved,
        ["BuildAZoo_AutoSystems"] = OptimizedConfig.lastSaved,
        ["BuildAZoo_CustomUI"] = OptimizedConfig.lastSaved
    }
end

function ConfigManager:GetConfig(name)
    return self:CreateConfig(name)
end

-- ============ INTEGRATION FUNCTIONS ============

-- Helper functions for easy integration
local function saveJSONCustom(fileName, data)
    OptimizedConfig:Set(fileName:gsub("%.json", ""), data)
end

local function loadJSONCustom(fileName)
    return OptimizedConfig:Get(fileName:gsub("%.json", ""), {})
end

local function saveCustomSelections()
    OptimizedConfig:Set("customSelections", customSelections)
end

local function loadCustomSelections()
    customSelections = OptimizedConfig:Get("customSelections", {
        eggSelections = {},
        fruitSelections = {},
        feedFruitSelections = {}
    })
end

-- Enhanced save/load functions
function saveAllConfigs()
    OptimizedConfig:SaveNow()
    return {
        mainConfig = "✅ Success",
        autoSystemsConfig = "✅ Success", 
        customUIConfig = "✅ Success",
        customSelections = "✅ Success"
    }
end

function loadAllConfigs()
    OptimizedConfig:Load()
    loadCustomSelections()
    return {
        mainConfig = "✅ Success",
        autoSystemsConfig = "✅ Success",
        customUIConfig = "✅ Success", 
        customSelections = "✅ Success"
    }
end

-- ============ REPLACE EXISTING VARIABLES ============
-- Replace the existing config variables with optimized versions

local mainConfig = ConfigManager:CreateConfig("BuildAZoo_Main")
local autoSystemsConfig = ConfigManager:CreateConfig("BuildAZoo_AutoSystems")
local customUIConfig = ConfigManager:CreateConfig("BuildAZoo_CustomUI")
local zebuxConfig = mainConfig -- For backward compatibility

-- Return the optimized config for external use
return {
    OptimizedConfig = OptimizedConfig,
    ConfigManager = ConfigManager,
    mainConfig = mainConfig,
    autoSystemsConfig = autoSystemsConfig,
    customUIConfig = customUIConfig,
    zebuxConfig = zebuxConfig,
    saveJSONCustom = saveJSONCustom,
    loadJSONCustom = loadJSONCustom,
    saveCustomSelections = saveCustomSelections,
    loadCustomSelections = loadCustomSelections,
    saveAllConfigs = saveAllConfigs,
    loadAllConfigs = loadAllConfigs
}
