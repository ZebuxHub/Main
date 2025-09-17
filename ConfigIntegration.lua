-- ConfigIntegration.lua - Integration helper for OptimizedConfigManager
-- Provides compatibility with existing WindUI ConfigManager API

local ConfigIntegration = {}

-- Dependencies
local OptimizedConfigManager = require(script.Parent.OptimizedConfigManager)

-- State
local state = {
    optimizedConfig = nil,
    windUI = nil,
    isInitialized = false
}

-- WindUI ConfigManager compatibility wrapper
local WindUIConfigWrapper = {}
WindUIConfigWrapper.__index = WindUIConfigWrapper

function WindUIConfigWrapper.new(configName)
    local self = setmetatable({}, WindUIConfigWrapper)
    self.configName = configName
    self.sectionMap = {
        ["BuildAZoo_Main"] = "main",
        ["BuildAZoo_AutoSystems"] = "autoSystems", 
        ["BuildAZoo_CustomUI"] = "customUI"
    }
    return self
end

function WindUIConfigWrapper:Save()
    if not state.optimizedConfig then return false end
    
    local section = self.sectionMap[self.configName] or "main"
    local success = true
    
    -- Save current section immediately
    state.optimizedConfig:SaveImmediate(function(saveSuccess, error)
        success = saveSuccess
        if not saveSuccess then
            warn("ConfigIntegration: Save failed for " .. self.configName .. " - " .. tostring(error))
        end
    end)
    
    return success
end

function WindUIConfigWrapper:Load()
    if not state.optimizedConfig then return false end
    
    local section = self.sectionMap[self.configName] or "main"
    local data = state.optimizedConfig:GetSection(section)
    
    -- Apply loaded data to WindUI elements (if needed)
    return data ~= nil
end

function WindUIConfigWrapper:LoadFromData(data)
    if not state.optimizedConfig then return false end
    
    local section = self.sectionMap[self.configName] or "main"
    state.optimizedConfig:SetSection(section, data, true)
    return true
end

function WindUIConfigWrapper:GetData()
    if not state.optimizedConfig then return {} end
    
    local section = self.sectionMap[self.configName] or "main"
    return state.optimizedConfig:GetSection(section) or {}
end

-- Enhanced ConfigManager that mimics WindUI's API
local EnhancedConfigManager = {}
EnhancedConfigManager.__index = EnhancedConfigManager

function EnhancedConfigManager.new()
    local self = setmetatable({}, EnhancedConfigManager)
    self.configs = {}
    return self
end

function EnhancedConfigManager:CreateConfig(configName)
    if not self.configs[configName] then
        self.configs[configName] = WindUIConfigWrapper.new(configName)
    end
    return self.configs[configName]
end

function EnhancedConfigManager:GetConfig(configName)
    return self.configs[configName]
end

function EnhancedConfigManager:AllConfigs()
    if not state.optimizedConfig then return {} end
    
    return {
        main = state.optimizedConfig:GetSection("main"),
        autoSystems = state.optimizedConfig:GetSection("autoSystems"),
        customUI = state.optimizedConfig:GetSection("customUI"),
        selections = state.optimizedConfig:GetSection("selections")
    }
end

-- Public API
function ConfigIntegration:Init(windUI, window)
    if state.isInitialized then return true end
    
    state.windUI = windUI
    state.optimizedConfig = OptimizedConfigManager
    
    -- Initialize optimized config
    local success = state.optimizedConfig:Init(windUI)
    
    if success then
        state.isInitialized = true
        
        -- Replace Window's ConfigManager with our enhanced version
        if window then
            window.ConfigManager = EnhancedConfigManager.new()
        end
        
        if windUI then
            windUI:Notify({
                Title = "⚡ Config Integration",
                Content = "Optimized config system active!",
                Duration = 3
            })
        end
    end
    
    return success
end

function ConfigIntegration:GetOptimizedConfig()
    return state.optimizedConfig
end

function ConfigIntegration:GetEnhancedConfigManager()
    return EnhancedConfigManager.new()
end

-- Migration helper
function ConfigIntegration:MigrateFromLegacySystem(legacyConfigManager, callback)
    if not state.optimizedConfig or not legacyConfigManager then
        if callback then callback(false, "Missing dependencies") end
        return
    end
    
    -- Extract legacy config data
    local legacyData = {
        windUIConfigs = {},
        customSelections = {}
    }
    
    -- Get all legacy configs
    if legacyConfigManager.AllConfigs then
        legacyData.windUIConfigs = legacyConfigManager:AllConfigs()
    end
    
    -- Load custom selections from legacy files
    local HttpService = game:GetService("HttpService")
    local legacyFiles = {
        "Zebux_EggSelections.json",
        "Zebux_FruitSelections.json", 
        "Zebux_FeedFruitSelections.json",
        "Zebux_CustomSelections.json"
    }
    
    for _, fileName in ipairs(legacyFiles) do
        local success, data = pcall(function()
            if isfile(fileName) then
                return HttpService:JSONDecode(readfile(fileName))
            end
        end)
        
        if success and data then
            if fileName:find("EggSelections") then
                legacyData.customSelections.eggSelections = data
            elseif fileName:find("FruitSelections") then
                legacyData.customSelections.fruitSelections = data
            elseif fileName:find("FeedFruitSelections") then
                legacyData.customSelections.feedFruitSelections = data
            elseif fileName:find("CustomSelections") then
                for key, value in pairs(data) do
                    legacyData.customSelections[key] = value
                end
            end
        end
    end
    
    -- Migrate to optimized system
    state.optimizedConfig:MigrateFromLegacy(legacyData, function(success, error)
        if success then
            -- Clean up legacy files
            for _, fileName in ipairs(legacyFiles) do
                pcall(function()
                    if isfile(fileName) then
                        delfile(fileName)
                    end
                end)
            end
            
            if state.windUI then
                state.windUI:Notify({
                    Title = "✅ Migration Complete",
                    Content = "Legacy configs migrated successfully!",
                    Duration = 4
                })
            end
        else
            warn("ConfigIntegration: Migration failed - " .. tostring(error))
        end
        
        if callback then callback(success, error) end
    end)
end

-- Performance monitoring
function ConfigIntegration:GetPerformanceStats()
    if not state.optimizedConfig then return {} end
    
    local stats = state.optimizedConfig:GetStats()
    stats.isInitialized = state.isInitialized
    stats.memoryUsage = collectgarbage("count")
    
    return stats
end

-- Utility functions for easy integration
function ConfigIntegration:CreateCompatibleConfigManager(window)
    local manager = EnhancedConfigManager.new()
    
    if window then
        window.ConfigManager = manager
    end
    
    return manager
end

function ConfigIntegration:SetupAutoSave(interval)
    interval = interval or 30 -- Default 30 seconds
    
    if state.autoSaveConnection then
        state.autoSaveConnection:Disconnect()
    end
    
    state.autoSaveConnection = task.spawn(function()
        while state.isInitialized do
            task.wait(interval)
            if state.optimizedConfig then
                state.optimizedConfig:SaveImmediate()
            end
        end
    end)
end

function ConfigIntegration:Cleanup()
    if state.autoSaveConnection then
        state.autoSaveConnection:Disconnect()
        state.autoSaveConnection = nil
    end
    
    if state.optimizedConfig then
        state.optimizedConfig:SaveImmediate()
        state.optimizedConfig:ClearCache()
    end
    
    state.isInitialized = false
end

return ConfigIntegration
