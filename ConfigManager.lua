-- ConfigManager.lua
-- Advanced Configuration Management System for Build a Zoo
-- Supports saving/loading all user settings to JSON files with ModuleScript integration

local ConfigManager = {}
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Configuration storage
local folderPath = "BuildAZoo_Configs"
local defaultConfigName = "DefaultConfig"

-- Initialize folder
pcall(function()
    makefolder(folderPath)
end)

-- State management
ConfigManager.registeredElements = {}
ConfigManager.currentConfig = nil
ConfigManager.autoLoad = false
ConfigManager.configName = defaultConfigName

-- ModuleScript data cache
ConfigManager.moduleData = {
    ResEgg = nil,
    ResMutate = nil,
    ResPet = nil,
    ResConveyor = nil,
    ResBigPet = nil,
    ResBigFish = nil
}

-- Initialize ModuleScript data
function ConfigManager:LoadModuleData()
    pcall(function()
        local cfg = ReplicatedStorage:WaitForChild("Config")
        self.moduleData.ResEgg = require(cfg:WaitForChild("ResEgg"))
        self.moduleData.ResMutate = require(cfg:WaitForChild("ResMutate"))
        self.moduleData.ResPet = require(cfg:WaitForChild("ResPet"))
        self.moduleData.ResConveyor = require(cfg:WaitForChild("ResConveyor"))
        
        -- Optional modules
        pcall(function()
            self.moduleData.ResBigPet = require(cfg:WaitForChild("ResBigPetScale"))
        end)
        pcall(function()
            self.moduleData.ResBigFish = require(cfg:WaitForChild("ResBigFishScale"))
        end)
    end)
end

-- Extract values from ModuleScript data for dropdowns
function ConfigManager:ExtractModuleValues(moduleType)
    local values = {}
    local moduleData = self.moduleData[moduleType]
    
    if not moduleData then return values end
    
    for key, data in pairs(moduleData) do
        local keyStr = tostring(key)
        if not keyStr:match("^_") and keyStr ~= "_index" and keyStr ~= "__index" then
            local name = keyStr
            if type(data) == "table" then
                name = data.Type or data.Name or data.ID or keyStr
            end
            table.insert(values, tostring(name))
        end
    end
    
    table.sort(values)
    return values
end

-- Get all available dropdown values
function ConfigManager:GetDropdownValues()
    return {
        eggs = self:ExtractModuleValues("ResEgg"),
        pets = self:ExtractModuleValues("ResPet"),
        mutations = self:ExtractModuleValues("ResMutate"),
        conveyors = self:ExtractModuleValues("ResConveyor")
    }
end

-- File operations
function ConfigManager:SaveFile(fileName, data)
    local filePath = folderPath .. "/" .. fileName .. ".json"
    local success, result = pcall(function()
        local jsonData = HttpService:JSONEncode(data)
        writefile(filePath, jsonData)
        return true
    end)
    return success, result
end

function ConfigManager:LoadFile(fileName)
    local filePath = folderPath .. "/" .. fileName .. ".json"
    local success, result = pcall(function()
        if isfile(filePath) then
            local jsonData = readfile(filePath)
            return HttpService:JSONDecode(jsonData)
        end
        return nil
    end)
    return success, result
end

function ConfigManager:ListFiles()
    local files = {}
    local success, result = pcall(function()
        if isfolder(folderPath) then
            for _, file in ipairs(listfiles(folderPath)) do
                local fileName = file:match("([^/\\]+)%.json$")
                if fileName then
                    table.insert(files, fileName)
                end
            end
        end
        return files
    end)
    return success and result or {}
end

function ConfigManager:DeleteFile(fileName)
    local filePath = folderPath .. "/" .. fileName .. ".json"
    local success = pcall(function()
        if isfile(filePath) then
            delfile(filePath)
            return true
        end
        return false
    end)
    return success
end

-- Element registration system
function ConfigManager:Register(elementName, element)
    if not elementName or not element then return false end
    
    self.registeredElements[elementName] = {
        element = element,
        type = self:DetectElementType(element)
    }
    return true
end

function ConfigManager:DetectElementType(element)
    if type(element) == "table" then
        if element.Get and element.Set then
            return "custom"
        elseif element.GetValue and element.SetValue then
            return "windui_element"
        elseif element.Value ~= nil then
            return "value_object"
        end
    end
    return "unknown"
end

-- Value extraction and setting
function ConfigManager:GetElementValue(elementName)
    local registered = self.registeredElements[elementName]
    if not registered then return nil end
    
    local element = registered.element
    local elementType = registered.type
    
    local success, value = pcall(function()
        if elementType == "custom" then
            return element.Get()
        elseif elementType == "windui_element" then
            return element:GetValue()
        elseif elementType == "value_object" then
            return element.Value
        end
        return nil
    end)
    
    return success and value or nil
end

function ConfigManager:SetElementValue(elementName, value)
    local registered = self.registeredElements[elementName]
    if not registered then return false end
    
    local element = registered.element
    local elementType = registered.type
    
    local success = pcall(function()
        if elementType == "custom" then
            element.Set(value)
        elseif elementType == "windui_element" then
            element:SetValue(value)
        elseif elementType == "value_object" then
            element.Value = value
        end
        return true
    end)
    
    return success
end

-- Configuration operations
function ConfigManager:SaveConfig(configName)
    configName = configName or self.configName or defaultConfigName
    
    local configData = {
        metadata = {
            version = "1.0",
            created = os.date("%Y-%m-%d %H:%M:%S"),
            game = "Build a Zoo",
            player = Players.LocalPlayer and Players.LocalPlayer.Name or "Unknown"
        },
        settings = {},
        moduleData = {
            timestamp = tick(),
            values = self:GetDropdownValues()
        }
    }
    
    -- Save all registered elements
    for elementName, _ in pairs(self.registeredElements) do
        local value = self:GetElementValue(elementName)
        if value ~= nil then
            configData.settings[elementName] = value
        end
    end
    
    local success, error = self:SaveFile(configName, configData)
    return success, error, configData
end

function ConfigManager:LoadConfig(configName)
    configName = configName or self.configName or defaultConfigName
    
    local success, configData = self:LoadFile(configName)
    if not success or not configData then
        return false, "Failed to load config file"
    end
    
    -- Validate config structure
    if not configData.settings then
        return false, "Invalid config file structure"
    end
    
    -- Load settings
    local loadedCount = 0
    local failedCount = 0
    
    for elementName, value in pairs(configData.settings) do
        if self:SetElementValue(elementName, value) then
            loadedCount = loadedCount + 1
        else
            failedCount = failedCount + 1
        end
    end
    
    self.currentConfig = configName
    return true, string.format("Loaded %d settings (%d failed)", loadedCount, failedCount), configData
end

-- Auto-load functionality
function ConfigManager:SetAutoLoad(enabled)
    self.autoLoad = enabled
    if enabled and self.configName then
        task.spawn(function()
            task.wait(1) -- Small delay to ensure all elements are registered
            self:LoadConfig(self.configName)
        end)
    end
end

function ConfigManager:SetConfigName(name)
    self.configName = name or defaultConfigName
end

-- Configuration presets
function ConfigManager:CreatePreset(presetName, description, settings)
    local presetData = {
        metadata = {
            version = "1.0",
            created = os.date("%Y-%m-%d %H:%M:%S"),
            type = "preset",
            name = presetName,
            description = description or "",
            game = "Build a Zoo"
        },
        settings = settings or {},
        moduleData = {
            timestamp = tick(),
            values = self:GetDropdownValues()
        }
    }
    
    return self:SaveFile("preset_" .. presetName, presetData)
end

-- Built-in presets
function ConfigManager:GetBuiltInPresets()
    return {
        {
            name = "Beginner Setup",
            description = "Basic automation for new players",
            settings = {
                buyEnabled = true,
                autoHatchEnabled = true,
                autoClaimEnabled = true,
                placeEnabled = true,
                placeMode = "Egg",
                placeSpeedMin = 0,
                recallEnabled = false,
                shopUpgrade = true,
                shopFruit = false,
                shopFeed = false
            }
        },
        {
            name = "Advanced Farming",
            description = "High-end farming with mutations",
            settings = {
                buyEnabled = true,
                autoHatchEnabled = true,
                autoClaimEnabled = true,
                placeEnabled = true,
                placeMode = "Both",
                placeSpeedMin = 100,
                recallEnabled = true,
                recallMinProduce = 50,
                shopUpgrade = true,
                shopFruit = true,
                shopFeed = true
            }
        },
        {
            name = "Mutation Focus",
            description = "Focus on mutated pets only",
            settings = {
                buyEnabled = true,
                autoHatchEnabled = true,
                autoClaimEnabled = true,
                placeEnabled = true,
                placeMode = "Both",
                recallEnabled = true,
                recallNonMutatedOnly = true,
                shopUpgrade = true,
                shopFruit = true,
                shopFeed = true
            }
        }
    }
end

function ConfigManager:ApplyPreset(presetName)
    local presets = self:GetBuiltInPresets()
    for _, preset in ipairs(presets) do
        if preset.name == presetName then
            local loadedCount = 0
            for elementName, value in pairs(preset.settings) do
                if self:SetElementValue(elementName, value) then
                    loadedCount = loadedCount + 1
                end
            end
            return true, string.format("Applied preset: %s (%d settings)", presetName, loadedCount)
        end
    end
    return false, "Preset not found: " .. presetName
end

-- Backup and restore
function ConfigManager:CreateBackup()
    local backupName = "backup_" .. os.date("%Y%m%d_%H%M%S")
    return self:SaveConfig(backupName)
end

function ConfigManager:ListBackups()
    local files = self:ListFiles()
    local backups = {}
    for _, file in ipairs(files) do
        if file:match("^backup_") then
            table.insert(backups, file)
        end
    end
    return backups
end

-- Export/Import functionality
function ConfigManager:ExportConfig(configName, includeModuleData)
    configName = configName or self.configName
    local success, configData = self:LoadFile(configName)
    
    if success and configData then
        if not includeModuleData then
            configData.moduleData = nil
        end
        
        local exportData = HttpService:JSONEncode(configData)
        return true, exportData
    end
    
    return false, "Failed to export config"
end

function ConfigManager:ImportConfig(configName, importData)
    local success, configData = pcall(function()
        return HttpService:JSONDecode(importData)
    end)
    
    if success and configData then
        return self:SaveFile(configName, configData)
    end
    
    return false, "Invalid import data"
end

-- Configuration validation
function ConfigManager:ValidateConfig(configData)
    if type(configData) ~= "table" then
        return false, "Config data is not a table"
    end
    
    if not configData.settings then
        return false, "Missing settings section"
    end
    
    if not configData.metadata then
        return false, "Missing metadata section"
    end
    
    return true, "Configuration is valid"
end

-- Initialize the ConfigManager
function ConfigManager:Init()
    self:LoadModuleData()
    return self
end

-- Statistics and info
function ConfigManager:GetStats()
    local files = self:ListFiles()
    local configFiles = 0
    local presetFiles = 0
    local backupFiles = 0
    
    for _, file in ipairs(files) do
        if file:match("^preset_") then
            presetFiles = presetFiles + 1
        elseif file:match("^backup_") then
            backupFiles = backupFiles + 1
        else
            configFiles = configFiles + 1
        end
    end
    
    return {
        totalFiles = #files,
        configFiles = configFiles,
        presetFiles = presetFiles,
        backupFiles = backupFiles,
        registeredElements = table.getn and table.getn(self.registeredElements) or 0,
        currentConfig = self.currentConfig,
        autoLoad = self.autoLoad
    }
end

return ConfigManager:Init()
