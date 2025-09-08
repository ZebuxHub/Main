-- ConfigManager.lua
-- Advanced configuration management for Best Auto script
-- Saves/loads all user selections to JSON files

local ConfigManager = {}

-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Config storage
local folderPath = "BestAuto_Configs"
local registeredElements = {}
local currentConfigName = "Default"

-- Ensure folder exists
pcall(function()
    if not isfolder(folderPath) then
        makefolder(folderPath)
    end
end)

-- Utility functions
local function SaveFile(fileName, data)
    local success, error = pcall(function()
        print("💾 SaveFile: Attempting to save " .. fileName .. ".json")
        print("📁 Folder path: " .. folderPath)
        
        -- Ensure folder exists
        if not isfolder(folderPath) then
            print("📁 Creating folder: " .. folderPath)
            makefolder(folderPath)
        end
        
        local filePath = folderPath .. "/" .. fileName .. ".json"
        print("📄 Full file path: " .. filePath)
        
        local jsonData = HttpService:JSONEncode(data)
        print("📝 JSON data length: " .. #jsonData .. " characters")
        print("📝 JSON preview: " .. jsonData:sub(1, 100) .. "...")
        
        writefile(filePath, jsonData)
        print("✅ File written successfully")
        
        -- Verify file was created
        if isfile(filePath) then
            local fileContent = readfile(filePath)
            print("✅ File verified, size: " .. #fileContent .. " characters")
        else
            error("File was not created")
        end
    end)
    
    if not success then
        warn("❌ SaveFile error: " .. tostring(error))
    end
    
    return success
end

local function LoadFile(fileName)
    local success, data = pcall(function()
        local filePath = folderPath .. "/" .. fileName .. ".json"
        if isfile(filePath) then
            local jsonData = readfile(filePath)
            return HttpService:JSONDecode(jsonData)
        end
        return nil
    end)
    return success and data or nil
end

local function ListFiles()
    local files = {}
    pcall(function()
        if isfolder(folderPath) then
            for _, file in ipairs(listfiles(folderPath)) do
                local fileName = file:match("([^/\\]+)%.json$")
                if fileName then
                    table.insert(files, fileName)
                end
            end
        end
    end)
    return files
end

local function DeleteFile(fileName)
    local success = pcall(function()
        local filePath = folderPath .. "/" .. fileName .. ".json"
        if isfile(filePath) then
            delfile(filePath)
            return true
        end
        return false
    end)
    return success
end

-- Element registration and management
function ConfigManager:Register(elementName, element, customGetter, customSetter)
    if not elementName then
        warn("ConfigManager: Invalid element registration - no elementName")
        return
    end
    
    -- Allow registration with custom getters/setters even if element is nil
    if not element and not customGetter then
        warn("ConfigManager: Invalid element registration - no element or customGetter for: " .. elementName)
        return
    end
    
    registeredElements[elementName] = {
        element = element,
        customGet = customGetter,
        customSet = customSetter
    }
    
    print("📝 ConfigManager: Registered '" .. elementName .. "'")
end

function ConfigManager:GetElementValue(elementName)
    local registered = registeredElements[elementName]
    if not registered then return nil end
    
    -- Use custom getter if provided
    if registered.customGet then
        local value = registered.customGet()
        -- Handle table values properly
        if type(value) == "table" then
            -- Convert table to clean array format for JSON serialization
            local result = {}
            for k, v in pairs(value) do
                -- Convert all values to strings to avoid module script references
                local cleanValue = tostring(v)
                if type(k) == "number" then
                    result[k] = cleanValue
                else
                    table.insert(result, cleanValue)
                end
            end
            -- Return nil if empty table instead of empty array
            return next(result) and result or nil
        end
        return value
    end
    
    -- Try standard WindUI methods
    local element = registered.element
    if element and element.GetValue then
        local value = element:GetValue()
        if type(value) == "table" then
            local result = {}
            for k, v in pairs(value) do
                -- Convert all values to strings to avoid module script references
                local cleanValue = tostring(v)
                if type(k) == "number" then
                    result[k] = cleanValue
                else
                    table.insert(result, cleanValue)
                end
            end
            -- Return nil if empty table instead of empty array
            return next(result) and result or nil
        end
        return value
    elseif element and element.Value then
        local value = element.Value
        if type(value) == "table" then
            local result = {}
            for k, v in pairs(value) do
                -- Convert all values to strings to avoid module script references
                local cleanValue = tostring(v)
                if type(k) == "number" then
                    result[k] = cleanValue
                else
                    table.insert(result, cleanValue)
                end
            end
            -- Return nil if empty table instead of empty array
            return next(result) and result or nil
        end
        return value
    end
    
    return nil
end

function ConfigManager:SetElementValue(elementName, value)
    local registered = registeredElements[elementName]
    if not registered then return false end
    
    -- Use custom setter if provided
    if registered.customSet then
        return registered.customSet(value)
    end
    
    -- Try standard WindUI methods
    local element = registered.element
    if element and element.SetValue then
        element:SetValue(value)
        return true
    elseif element and element.Select then
        element:Select(value)
        return true
    end
    
    return false
end

-- Config file operations
function ConfigManager:Save(configName)
    configName = configName or currentConfigName
    
    local configData = {
        metadata = {
            created = os.date("%Y-%m-%d %H:%M:%S"),
            player = LocalPlayer and LocalPlayer.Name or "Unknown",
            version = "1.0"
        },
        settings = {}
    }
    
    -- Collect all registered element values with debug output
    print("🔍 ConfigManager:Save - Collecting values for " .. #self:GetRegisteredElements() .. " elements:")
    local collectedCount = 0
    
    for elementName, _ in pairs(registeredElements) do
        print("🔍 Processing element: " .. elementName)
        local registered = registeredElements[elementName]
        
        -- Debug the registration details
        if registered.customGet then
            print("  - Has custom getter")
            local rawValue = registered.customGet()
            print("  - Raw value type: " .. type(rawValue))
            if type(rawValue) == "table" then
                print("  - Raw table length: " .. #rawValue)
                for i = 1, math.min(3, #rawValue) do
                    print("    [" .. i .. "] = " .. tostring(rawValue[i]))
                end
            end
        else
            print("  - No custom getter, checking element")
        end
        
        local value = self:GetElementValue(elementName)
        print("  - Final processed value type: " .. type(value or "nil"))
        
        if value ~= nil then
            configData.settings[elementName] = value
            collectedCount = collectedCount + 1
            
            -- Better debug output for tables
            if type(value) == "table" then
                local tableStr = "{"
                local count = 0
                for k, v in pairs(value) do
                    if count > 0 then tableStr = tableStr .. ", " end
                    tableStr = tableStr .. tostring(k) .. "=" .. tostring(v)
                    count = count + 1
                    if count >= 3 then tableStr = tableStr .. "..." break end
                end
                tableStr = tableStr .. "}"
                print("  ✓ " .. elementName .. " = " .. tableStr .. " (" .. count .. " items)")
            else
                print("  ✓ " .. elementName .. " = " .. tostring(value))
            end
        else
            print("  ✗ " .. elementName .. " = nil (skipped)")
        end
    end
    
    print("📦 Final config data: " .. collectedCount .. " settings collected")
    
    local success = SaveFile(configName, configData)
    
    if success then
        print("✅ Config saved: " .. configName .. " (" .. collectedCount .. " settings)")
        return true
    else
        warn("❌ Failed to save config: " .. configName)
        return false
    end
end

function ConfigManager:Load(configName)
    configName = configName or currentConfigName
    
    local configData = LoadFile(configName)
    if not configData then
        warn("❌ Config not found: " .. configName)
        return false
    end
    
    -- Apply loaded settings to elements
    local loadedCount = 0
    if configData.settings then
        for elementName, value in pairs(configData.settings) do
            if self:SetElementValue(elementName, value) then
                loadedCount = loadedCount + 1
            end
        end
    end
    
    print("✅ Config loaded: " .. configName .. " (" .. loadedCount .. " settings)")
    return true
end

function ConfigManager:Delete(configName)
    if not configName or configName == "" then
        warn("❌ Invalid config name for deletion")
        return false
    end
    
    local success = DeleteFile(configName)
    if success then
        print("✅ Config deleted: " .. configName)
    else
        warn("❌ Failed to delete config: " .. configName)
    end
    return success
end

function ConfigManager:List()
    return ListFiles()
end

function ConfigManager:Exists(configName)
    local files = self:List()
    for _, fileName in ipairs(files) do
        if fileName == configName then
            return true
        end
    end
    return false
end

function ConfigManager:SetCurrentConfig(configName)
    currentConfigName = configName or "Default"
end

function ConfigManager:GetCurrentConfig()
    return currentConfigName
end

-- Auto-save functionality
local autoSaveEnabled = false
local autoSaveInterval = 30 -- seconds

function ConfigManager:EnableAutoSave(interval)
    autoSaveEnabled = true
    autoSaveInterval = interval or 30
    
    task.spawn(function()
        while autoSaveEnabled do
            task.wait(autoSaveInterval)
            if autoSaveEnabled then
                self:Save(currentConfigName)
            end
        end
    end)
    
    print("✅ Auto-save enabled (every " .. autoSaveInterval .. "s)")
end

function ConfigManager:DisableAutoSave()
    autoSaveEnabled = false
    print("⏹️ Auto-save disabled")
end

-- Backup functionality
function ConfigManager:CreateBackup(configName)
    configName = configName or currentConfigName
    local backupName = configName .. "_backup_" .. os.date("%Y%m%d_%H%M%S")
    
    local originalData = LoadFile(configName)
    if originalData then
        local success = SaveFile(backupName, originalData)
        if success then
            print("✅ Backup created: " .. backupName)
            return backupName
        end
    end
    
    warn("❌ Failed to create backup for: " .. configName)
    return nil
end

-- Export/Import functionality
function ConfigManager:Export(configName)
    configName = configName or currentConfigName
    local configData = LoadFile(configName)
    
    if configData then
        local exportString = HttpService:JSONEncode(configData)
        pcall(function()
            setclipboard(exportString)
        end)
        print("✅ Config exported to clipboard: " .. configName)
        return exportString
    end
    
    warn("❌ Failed to export config: " .. configName)
    return nil
end

function ConfigManager:Import(configName, importString)
    if not configName or not importString then
        warn("❌ Invalid import parameters")
        return false
    end
    
    local success, configData = pcall(function()
        return HttpService:JSONDecode(importString)
    end)
    
    if success and configData then
        local saveSuccess = SaveFile(configName, configData)
        if saveSuccess then
            print("✅ Config imported: " .. configName)
            return true
        end
    end
    
    warn("❌ Failed to import config: " .. configName)
    return false
end

-- Reset functionality
function ConfigManager:Reset()
    registeredElements = {}
    print("🔄 ConfigManager reset - all registrations cleared")
end

function ConfigManager:GetRegisteredElements()
    local elementNames = {}
    for name, _ in pairs(registeredElements) do
        table.insert(elementNames, name)
    end
    return elementNames
end

-- Debug functionality
function ConfigManager:Debug()
    print("🔍 ConfigManager Debug Info:")
    print("  Current Config: " .. currentConfigName)
    print("  Registered Elements: " .. #self:GetRegisteredElements())
    print("  Available Configs: " .. #self:List())
    
    for i, name in ipairs(self:GetRegisteredElements()) do
        local value = self:GetElementValue(name)
        print("    " .. i .. ". " .. name .. " = " .. tostring(value))
    end
end

return ConfigManager
