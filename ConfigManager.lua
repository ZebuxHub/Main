-- ============================================================================
-- UNIFIED CONFIG MANAGER FOR BUILD A ZOO
-- ============================================================================
-- Features:
-- • User-specific folders (per Windows PC user)
-- • Master config file + individual module configs
-- • Auto-save and auto-load
-- • Migration from old config format
-- • Works with all external modules
-- ============================================================================

local ConfigManager = {}
ConfigManager.__index = ConfigManager

-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- ============================================================================
-- CONFIGURATION PATHS
-- ============================================================================

-- Get Windows username for user-specific folders
local function getWindowsUsername()
    local success, username = pcall(function()
        -- Try to get from environment variable (if executor supports it)
        if syn and syn.get_thread_identity then
            -- Synapse support
            return os.getenv("USERNAME") or os.getenv("USER") or "DefaultUser"
        elseif identifyexecutor then
            -- Try to identify executor and get username
            local executor = identifyexecutor()
            return os.getenv("USERNAME") or os.getenv("USER") or executor or "DefaultUser"
        else
            -- Fallback to player name
            return Players.LocalPlayer.Name
        end
    end)
    
    if success and username and username ~= "" then
        -- Sanitize username (remove invalid characters for folder names)
        username = username:gsub("[^%w_%-]", "_")
        return username
    end
    
    -- Final fallback
    return Players.LocalPlayer.Name:gsub("[^%w_%-]", "_")
end

-- Create folder structure
local USERNAME = getWindowsUsername()
local BASE_FOLDER = "WindUI/Zebux"
local USER_FOLDER = BASE_FOLDER .. "/Users/" .. USERNAME
local CONFIG_FOLDER = USER_FOLDER .. "/Configs"
local BACKUP_FOLDER = USER_FOLDER .. "/Backups"
local MODULE_FOLDER = CONFIG_FOLDER .. "/Modules"

-- Master config file
local MASTER_CONFIG_FILE = CONFIG_FOLDER .. "/MasterConfig.json"

-- Create all necessary folders
local function createFolderStructure()
    pcall(function() if not isfolder(BASE_FOLDER) then makefolder(BASE_FOLDER) end end)
    pcall(function() if not isfolder(BASE_FOLDER .. "/Users") then makefolder(BASE_FOLDER .. "/Users") end end)
    pcall(function() if not isfolder(USER_FOLDER) then makefolder(USER_FOLDER) end end)
    pcall(function() if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end end)
    pcall(function() if not isfolder(BACKUP_FOLDER) then makefolder(BACKUP_FOLDER) end end)
    pcall(function() if not isfolder(MODULE_FOLDER) then makefolder(MODULE_FOLDER) end end)
end

createFolderStructure()

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function deepCopy(original)
    local copy
    if type(original) == 'table' then
        copy = {}
        for key, value in next, original, nil do
            copy[deepCopy(key)] = deepCopy(value)
        end
        setmetatable(copy, deepCopy(getmetatable(original)))
    else
        copy = original
    end
    return copy
end

local function mergeTables(target, source)
    for key, value in pairs(source) do
        if type(value) == 'table' and type(target[key]) == 'table' then
            mergeTables(target[key], value)
        else
            target[key] = value
        end
    end
    return target
end

-- ============================================================================
-- CONFIG MANAGER CORE
-- ============================================================================

function ConfigManager.new()
    local self = setmetatable({}, ConfigManager)
    
    self.modules = {}
    self.masterConfig = {
        version = "2.0",
        lastSaved = os.time(),
        username = USERNAME,
        modules = {}
    }
    
    self.autoSaveEnabled = true
    self.autoSaveInterval = 60 -- Auto-save every 60 seconds
    self.lastAutoSave = 0
    
    return self
end

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

function ConfigManager:RegisterModule(moduleName, moduleConfig)
    if not moduleName or type(moduleName) ~= "string" then
        warn("[ConfigManager] Invalid module name")
        return false
    end
    
    self.modules[moduleName] = {
        name = moduleName,
        config = moduleConfig or {},
        elements = {},
        callbacks = {}
    }
    
    print("[ConfigManager] Registered module: " .. moduleName)
    return true
end

function ConfigManager:RegisterElement(moduleName, elementKey, element, defaultValue)
    if not self.modules[moduleName] then
        warn("[ConfigManager] Module not registered: " .. moduleName)
        return false
    end
    
    self.modules[moduleName].elements[elementKey] = {
        element = element,
        defaultValue = defaultValue,
        currentValue = defaultValue
    }
    
    return true
end

function ConfigManager:RegisterCallback(moduleName, callbackName, callback)
    if not self.modules[moduleName] then
        warn("[ConfigManager] Module not registered: " .. moduleName)
        return false
    end
    
    self.modules[moduleName].callbacks[callbackName] = callback
    return true
end

-- ============================================================================
-- SAVE FUNCTIONS
-- ============================================================================

-- Save individual module config
function ConfigManager:SaveModule(moduleName)
    if not self.modules[moduleName] then
        warn("[ConfigManager] Module not found: " .. moduleName)
        return false
    end
    
    local moduleData = {
        version = "2.0",
        timestamp = os.time(),
        config = deepCopy(self.modules[moduleName].config),
        elements = {}
    }
    
    -- Save element values
    for key, elementData in pairs(self.modules[moduleName].elements) do
        if elementData.element and elementData.element.Value ~= nil then
            moduleData.elements[key] = elementData.element.Value
        else
            moduleData.elements[key] = elementData.currentValue
        end
    end
    
    local success, err = pcall(function()
        local filePath = MODULE_FOLDER .. "/" .. moduleName .. ".json"
        local jsonData = HttpService:JSONEncode(moduleData)
        writefile(filePath, jsonData)
    end)
    
    if success then
        print("[ConfigManager] Saved module: " .. moduleName)
        return true
    else
        warn("[ConfigManager] Failed to save module " .. moduleName .. ": " .. tostring(err))
        return false
    end
end

-- Save master config (all modules in one file)
function ConfigManager:SaveMaster()
    self.masterConfig.lastSaved = os.time()
    self.masterConfig.modules = {}
    
    -- Collect all module data
    for moduleName, moduleData in pairs(self.modules) do
        self.masterConfig.modules[moduleName] = {
            config = deepCopy(moduleData.config),
            elements = {}
        }
        
        -- Save element values
        for key, elementData in pairs(moduleData.elements) do
            if elementData.element and elementData.element.Value ~= nil then
                self.masterConfig.modules[moduleName].elements[key] = elementData.element.Value
            else
                self.masterConfig.modules[moduleName].elements[key] = elementData.currentValue
            end
        end
    end
    
    local success, err = pcall(function()
        local jsonData = HttpService:JSONEncode(self.masterConfig)
        writefile(MASTER_CONFIG_FILE, jsonData)
    end)
    
    if success then
        print("[ConfigManager] Saved master config")
        return true
    else
        warn("[ConfigManager] Failed to save master config: " .. tostring(err))
        return false
    end
end

-- Save all (master + individual modules)
function ConfigManager:SaveAll()
    local results = {
        master = self:SaveMaster()
    }
    
    for moduleName, _ in pairs(self.modules) do
        results[moduleName] = self:SaveModule(moduleName)
    end
    
    return results
end

-- ============================================================================
-- LOAD FUNCTIONS
-- ============================================================================

-- Load individual module config
function ConfigManager:LoadModule(moduleName)
    if not self.modules[moduleName] then
        warn("[ConfigManager] Module not registered: " .. moduleName)
        return false
    end
    
    local filePath = MODULE_FOLDER .. "/" .. moduleName .. ".json"
    
    local success, moduleData = pcall(function()
        if isfile(filePath) then
            return HttpService:JSONDecode(readfile(filePath))
        end
        return nil
    end)
    
    if success and moduleData then
        -- Load config data
        if moduleData.config then
            self.modules[moduleName].config = mergeTables(self.modules[moduleName].config, moduleData.config)
        end
        
        -- Load element values
        if moduleData.elements then
            for key, value in pairs(moduleData.elements) do
                if self.modules[moduleName].elements[key] then
                    local elementData = self.modules[moduleName].elements[key]
                    elementData.currentValue = value
                    
                    -- Apply to UI element if exists
                    if elementData.element and elementData.element.SetValue then
                        pcall(function()
                            elementData.element:SetValue(value)
                        end)
                    end
                end
            end
        end
        
        print("[ConfigManager] Loaded module: " .. moduleName)
        return true
    end
    
    return false
end

-- Load master config
function ConfigManager:LoadMaster()
    local success, masterData = pcall(function()
        if isfile(MASTER_CONFIG_FILE) then
            return HttpService:JSONDecode(readfile(MASTER_CONFIG_FILE))
        end
        return nil
    end)
    
    if success and masterData and masterData.modules then
        for moduleName, moduleData in pairs(masterData.modules) do
            if self.modules[moduleName] then
                -- Load config data
                if moduleData.config then
                    self.modules[moduleName].config = mergeTables(self.modules[moduleName].config, moduleData.config)
                end
                
                -- Load element values
                if moduleData.elements then
                    for key, value in pairs(moduleData.elements) do
                        if self.modules[moduleName].elements[key] then
                            local elementData = self.modules[moduleName].elements[key]
                            elementData.currentValue = value
                            
                            -- Apply to UI element if exists
                            if elementData.element and elementData.element.SetValue then
                                pcall(function()
                                    elementData.element:SetValue(value)
                                end)
                            end
                        end
                    end
                end
            end
        end
        
        print("[ConfigManager] Loaded master config")
        return true
    end
    
    return false
end

-- Load all (try master first, fallback to individual modules)
function ConfigManager:LoadAll()
    local results = {}
    
    -- Try loading master config first
    results.master = self:LoadMaster()
    
    -- Also try loading individual module configs (they override master)
    for moduleName, _ in pairs(self.modules) do
        results[moduleName] = self:LoadModule(moduleName)
    end
    
    return results
end

-- ============================================================================
-- MIGRATION FROM OLD CONFIG FORMAT
-- ============================================================================

function ConfigManager:MigrateOldConfigs()
    print("[ConfigManager] Checking for old configs to migrate...")
    
    local oldConfigs = {
        -- WindUI legacy configs
        {
            old = "WindUI/Zebux/custom/ClaimSettings.json",
            module = "Main",
            handler = function(data)
                if data.autoClaimDelay then
                    self:SetValue("Main", "autoClaimDelay", data.autoClaimDelay)
                end
            end
        },
        {
            old = "WindUI/Zebux/custom/EggSelections.json",
            module = "AutoPlace",
            handler = function(data)
                if data.eggs then
                    self:SetValue("AutoPlace", "selectedEggs", data.eggs)
                end
                if data.mutations then
                    self:SetValue("AutoPlace", "selectedMutations", data.mutations)
                end
            end
        },
        {
            old = "WindUI/Zebux/custom/FruitSelections.json",
            module = "Shop",
            handler = function(data)
                if data.fruits then
                    self:SetValue("Shop", "selectedFruits", data.fruits)
                end
            end
        },
        {
            old = "WindUI/Zebux/custom/FeedFruitSelections.json",
            module = "AutoFeed",
            handler = function(data)
                if data.fruits then
                    self:SetValue("AutoFeed", "selectedFeedFruits", data.fruits)
                end
            end
        }
    }
    
    local migrated = 0
    
    for _, configInfo in ipairs(oldConfigs) do
        local success, data = pcall(function()
            if isfile(configInfo.old) then
                return HttpService:JSONDecode(readfile(configInfo.old))
            end
            return nil
        end)
        
        if success and data then
            configInfo.handler(data)
            migrated = migrated + 1
            
            -- Backup and remove old file
            pcall(function()
                local backupPath = BACKUP_FOLDER .. "/" .. configInfo.old:match("([^/]+)$")
                writefile(backupPath, readfile(configInfo.old))
                delfile(configInfo.old)
            end)
        end
    end
    
    if migrated > 0 then
        print("[ConfigManager] Migrated " .. migrated .. " old config files")
        self:SaveAll()
    end
end

-- ============================================================================
-- GET/SET VALUES
-- ============================================================================

function ConfigManager:GetValue(moduleName, key, defaultValue)
    if not self.modules[moduleName] then
        return defaultValue
    end
    
    if self.modules[moduleName].elements[key] then
        return self.modules[moduleName].elements[key].currentValue or defaultValue
    end
    
    if self.modules[moduleName].config[key] ~= nil then
        return self.modules[moduleName].config[key]
    end
    
    return defaultValue
end

function ConfigManager:SetValue(moduleName, key, value)
    if not self.modules[moduleName] then
        return false
    end
    
    if self.modules[moduleName].elements[key] then
        self.modules[moduleName].elements[key].currentValue = value
        
        -- Update UI element if exists
        if self.modules[moduleName].elements[key].element and 
           self.modules[moduleName].elements[key].element.SetValue then
            pcall(function()
                self.modules[moduleName].elements[key].element:SetValue(value)
            end)
        end
    else
        self.modules[moduleName].config[key] = value
    end
    
    return true
end

-- ============================================================================
-- AUTO-SAVE SYSTEM
-- ============================================================================

function ConfigManager:StartAutoSave()
    self.autoSaveEnabled = true
    
    task.spawn(function()
        while self.autoSaveEnabled do
            task.wait(self.autoSaveInterval)
            
            if os.time() - self.lastAutoSave >= self.autoSaveInterval then
                self:SaveAll()
                self.lastAutoSave = os.time()
                print("[ConfigManager] Auto-saved all configs")
            end
        end
    end)
end

function ConfigManager:StopAutoSave()
    self.autoSaveEnabled = false
end

-- ============================================================================
-- EXPORT/IMPORT
-- ============================================================================

function ConfigManager:ExportToClipboard()
    local success, result = pcall(function()
        local exportData = {
            version = "2.0",
            exported = os.time(),
            username = USERNAME,
            modules = self.masterConfig.modules
        }
        
        return HttpService:JSONEncode(exportData)
    end)
    
    if success and result then
        setclipboard(result)
        print("[ConfigManager] Config exported to clipboard!")
        return true
    else
        warn("[ConfigManager] Failed to export config")
        return false
    end
end

function ConfigManager:ImportFromClipboard()
    local success, importData = pcall(function()
        local clipboardData = getclipboard and getclipboard() or ""
        if clipboardData == "" then
            error("Clipboard is empty")
        end
        return HttpService:JSONDecode(clipboardData)
    end)
    
    if success and importData and importData.modules then
        -- Backup current config before importing
        local backupPath = BACKUP_FOLDER .. "/pre_import_" .. os.time() .. ".json"
        pcall(function()
            writefile(backupPath, HttpService:JSONEncode(self.masterConfig))
        end)
        
        -- Import new config
        self.masterConfig = importData
        
        -- Apply to modules
        for moduleName, moduleData in pairs(importData.modules) do
            if self.modules[moduleName] then
                self.modules[moduleName].config = moduleData.config or {}
                
                for key, value in pairs(moduleData.elements or {}) do
                    self:SetValue(moduleName, key, value)
                end
            end
        end
        
        self:SaveAll()
        print("[ConfigManager] Config imported successfully!")
        return true
    else
        warn("[ConfigManager] Failed to import config from clipboard")
        return false
    end
end

-- ============================================================================
-- INFO & DEBUGGING
-- ============================================================================

function ConfigManager:GetInfo()
    return {
        username = USERNAME,
        userFolder = USER_FOLDER,
        configFolder = CONFIG_FOLDER,
        masterConfigFile = MASTER_CONFIG_FILE,
        moduleFolder = MODULE_FOLDER,
        registeredModules = #self.modules,
        lastSaved = self.masterConfig.lastSaved
    }
end

function ConfigManager:PrintInfo()
    local info = self:GetInfo()
    print("============ CONFIG MANAGER INFO ============")
    print("User: " .. info.username)
    print("User Folder: " .. info.userFolder)
    print("Config Folder: " .. info.configFolder)
    print("Modules Registered: " .. info.registeredModules)
    print("Last Saved: " .. os.date("%Y-%m-%d %H:%M:%S", info.lastSaved))
    print("=============================================")
end

-- ============================================================================
-- INITIALIZE
-- ============================================================================

function ConfigManager:Initialize()
    createFolderStructure()
    self:MigrateOldConfigs()
    self:LoadAll()
    self:StartAutoSave()
    
    print("[ConfigManager] Initialized successfully!")
    return true
end

-- ============================================================================
-- EXPORT MODULE
-- ============================================================================

return ConfigManager

