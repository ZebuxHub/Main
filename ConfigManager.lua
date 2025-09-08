-- ConfigManager.lua
-- Comprehensive configuration management system for Best Auto.lua
-- Supports saving/loading all user selections to JSON files with file management UI

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local ConfigManager = {}
ConfigManager.__index = ConfigManager

-- Configuration storage
local configs = {}
local currentConfigName = "DefaultConfig"
local folderPath = "BuildAZoo_Configs"
local autoLoadEnabled = true

-- Ensure config folder exists
pcall(function()
    makefolder(folderPath)
end)

-- File operations
local function SaveFile(fileName, data)
    local filePath = folderPath .. "/" .. fileName .. ".json"
    local success, result = pcall(function()
        local jsonData = HttpService:JSONEncode(data)
        writefile(filePath, jsonData)
        return true
    end)
    return success, result
end

local function LoadFile(fileName)
    local filePath = folderPath .. "/" .. fileName .. ".json"
    local success, result = pcall(function()
        if isfile(filePath) then
            local jsonData = readfile(filePath)
            return HttpService:JSONDecode(jsonData)
        end
        return nil
    end)
    if success then
        return result
    else
        warn("ConfigManager: Failed to load file " .. fileName .. " - " .. tostring(result))
        return nil
    end
end

local function DeleteFile(fileName)
    local filePath = folderPath .. "/" .. fileName .. ".json"
    local success, result = pcall(function()
        if isfile(filePath) then
            delfile(filePath)
            return true
        end
        return false
    end)
    return success, result
end

local function ListConfigFiles()
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
    if success then
        table.sort(result)
        return result
    else
        warn("ConfigManager: Failed to list files - " .. tostring(result))
        return {}
    end
end

-- Config value management
function ConfigManager.new(name)
    local self = setmetatable({}, ConfigManager)
    self.name = name or "DefaultConfig"
    self.registeredElements = {}
    self.configData = {}
    currentConfigName = self.name
    return self
end

function ConfigManager:SetName(name)
    if name and name ~= "" then
        self.name = tostring(name)
        currentConfigName = self.name
    end
end

function ConfigManager:SetAutoLoad(enabled)
    autoLoadEnabled = enabled == true
end

function ConfigManager:Register(key, element)
    if not key or key == "" then
        warn("ConfigManager: Invalid key provided for registration")
        return
    end
    
    self.registeredElements[key] = element
end

function ConfigManager:GetValue(key)
    local element = self.registeredElements[key]
    if not element then return nil end
    
    if type(element) == "table" then
        if element.Get and type(element.Get) == "function" then
            local success, result = pcall(element.Get)
            return success and result or nil
        elseif element.GetValue and type(element.GetValue) == "function" then
            local success, result = pcall(element.GetValue)
            return success and result or nil
        elseif element.Value ~= nil then
            return element.Value
        end
    end
    
    return nil
end

function ConfigManager:SetValue(key, value)
    local element = self.registeredElements[key]
    if not element then return false end
    
    if type(element) == "table" then
        if element.Set and type(element.Set) == "function" then
            local success = pcall(element.Set, value)
            return success
        elseif element.SetValue and type(element.SetValue) == "function" then
            local success = pcall(element.SetValue, value)
            return success
        elseif element.Select and type(element.Select) == "function" and type(value) == "table" then
            local success = pcall(element.Select, value)
            return success
        end
    end
    
    return false
end

function ConfigManager:Save(fileName)
    fileName = fileName or self.name
    if not fileName or fileName == "" then
        warn("ConfigManager: No filename provided for save")
        return false
    end
    
    local configData = {
        _metadata = {
            version = "1.0",
            timestamp = os.time(),
            player = LocalPlayer and LocalPlayer.Name or "Unknown"
        }
    }
    
    -- Collect all registered values
    for key, element in pairs(self.registeredElements) do
        local value = self:GetValue(key)
        if value ~= nil then
            configData[key] = value
        end
    end
    
    local success, result = SaveFile(fileName, configData)
    if success then
        print("ConfigManager: Saved configuration '" .. fileName .. "' successfully")
        return true
    else
        warn("ConfigManager: Failed to save configuration '" .. fileName .. "' - " .. tostring(result))
        return false
    end
end

function ConfigManager:Load(fileName)
    fileName = fileName or self.name
    if not fileName or fileName == "" then
        warn("ConfigManager: No filename provided for load")
        return false
    end
    
    local configData = LoadFile(fileName)
    if not configData then
        warn("ConfigManager: Failed to load configuration '" .. fileName .. "'")
        return false
    end
    
    local loadedCount = 0
    local failedCount = 0
    
    -- Apply loaded values
    for key, value in pairs(configData) do
        if key ~= "_metadata" and self.registeredElements[key] then
            local success = self:SetValue(key, value)
            if success then
                loadedCount = loadedCount + 1
            else
                failedCount = failedCount + 1
                warn("ConfigManager: Failed to set value for key '" .. key .. "'")
            end
        end
    end
    
    print("ConfigManager: Loaded configuration '" .. fileName .. "' - " .. loadedCount .. " values loaded, " .. failedCount .. " failed")
    return true
end

function ConfigManager:Delete(fileName)
    fileName = fileName or self.name
    if not fileName or fileName == "" then
        warn("ConfigManager: No filename provided for delete")
        return false
    end
    
    local success, result = DeleteFile(fileName)
    if success then
        print("ConfigManager: Deleted configuration '" .. fileName .. "' successfully")
        return true
    else
        warn("ConfigManager: Failed to delete configuration '" .. fileName .. "' - " .. tostring(result))
        return false
    end
end

function ConfigManager:ListConfigs()
    return ListConfigFiles()
end

function ConfigManager:GetConfigData(fileName)
    fileName = fileName or self.name
    local data = LoadFile(fileName)
    if data and data._metadata then
        return {
            name = fileName,
            timestamp = data._metadata.timestamp,
            player = data._metadata.player,
            version = data._metadata.version
        }
    end
    return nil
end

-- UI Integration functions
function ConfigManager:CreateUI(SaveTab, WindUI)
    if not SaveTab or not WindUI then
        warn("ConfigManager: Invalid UI components provided")
        return
    end
    
    local selectedConfigFile = ""
    local configDropdown = nil
    
    -- Helper function to refresh file list
    local function refreshFileList()
        local files = self:ListConfigs()
        if configDropdown and configDropdown.SetValues then
            pcall(function()
                configDropdown:SetValues(files)
            end)
        end
        return files
    end
    
    -- Config File Management Section
    SaveTab:Section({ Title = "Configuration Files", Icon = "folder" })
    
    -- File selection dropdown
    configDropdown = SaveTab:Dropdown({
        Title = "Select Config File",
        Values = refreshFileList(),
        AllowNone = true,
        Callback = function(selected)
            selectedConfigFile = selected or ""
        end
    })
    
    -- Config name input for new configs
    local configNameInput = ""
    SaveTab:Input({
        Title = "New Config Name",
        Value = self.name,
        Placeholder = "Enter config name",
        Callback = function(text)
            configNameInput = tostring(text or "")
            if configNameInput ~= "" then
                self:SetName(configNameInput)
            end
        end
    })
    
    -- Auto-load toggle
    SaveTab:Toggle({
        Title = "Auto Load on Startup",
        Value = autoLoadEnabled,
        Callback = function(v)
            self:SetAutoLoad(v)
        end
    })
    
    -- File Operations Section
    SaveTab:Section({ Title = "File Operations", Icon = "file-cog" })
    
    -- Save button
    SaveTab:Button({
        Title = "Save Configuration",
        Icon = "save",
        Callback = function()
            local fileName = configNameInput ~= "" and configNameInput or self.name
            if fileName and fileName ~= "" then
                local success = self:Save(fileName)
                if success then
                    WindUI:Notify({
                        Title = "Config Saved",
                        Content = "Configuration '" .. fileName .. "' saved successfully!",
                        Duration = 3,
                        Icon = "check-circle"
                    })
                    refreshFileList()
                else
                    WindUI:Notify({
                        Title = "Save Failed",
                        Content = "Failed to save configuration '" .. fileName .. "'",
                        Duration = 3,
                        Icon = "x-circle"
                    })
                end
            else
                WindUI:Notify({
                    Title = "Invalid Name",
                    Content = "Please enter a valid configuration name",
                    Duration = 3,
                    Icon = "alert-triangle"
                })
            end
        end
    })
    
    -- Load button
    SaveTab:Button({
        Title = "Load Selected Config",
        Icon = "download",
        Callback = function()
            if selectedConfigFile and selectedConfigFile ~= "" then
                local success = self:Load(selectedConfigFile)
                if success then
                    WindUI:Notify({
                        Title = "Config Loaded",
                        Content = "Configuration '" .. selectedConfigFile .. "' loaded successfully!",
                        Duration = 3,
                        Icon = "check-circle"
                    })
                else
                    WindUI:Notify({
                        Title = "Load Failed",
                        Content = "Failed to load configuration '" .. selectedConfigFile .. "'",
                        Duration = 3,
                        Icon = "x-circle"
                    })
                end
            else
                WindUI:Notify({
                    Title = "No Selection",
                    Content = "Please select a configuration file to load",
                    Duration = 3,
                    Icon = "alert-triangle"
                })
            end
        end
    })
    
    -- Delete button
    SaveTab:Button({
        Title = "Delete Selected Config",
        Icon = "trash-2",
        Callback = function()
            if selectedConfigFile and selectedConfigFile ~= "" then
                local success = self:Delete(selectedConfigFile)
                if success then
                    WindUI:Notify({
                        Title = "Config Deleted",
                        Content = "Configuration '" .. selectedConfigFile .. "' deleted successfully!",
                        Duration = 3,
                        Icon = "check-circle"
                    })
                    selectedConfigFile = ""
                    refreshFileList()
                else
                    WindUI:Notify({
                        Title = "Delete Failed",
                        Content = "Failed to delete configuration '" .. selectedConfigFile .. "'",
                        Duration = 3,
                        Icon = "x-circle"
                    })
                end
            else
                WindUI:Notify({
                    Title = "No Selection",
                    Content = "Please select a configuration file to delete",
                    Duration = 3,
                    Icon = "alert-triangle"
                })
            end
        end
    })
    
    -- Refresh button
    SaveTab:Button({
        Title = "Refresh File List",
        Icon = "refresh-cw",
        Callback = function()
            local files = refreshFileList()
            WindUI:Notify({
                Title = "Files Refreshed",
                Content = "Found " .. #files .. " configuration files",
                Duration = 2,
                Icon = "refresh-cw"
            })
        end
    })
    
    -- Config Info Section
    SaveTab:Section({ Title = "Config Information", Icon = "info" })
    
    SaveTab:Button({
        Title = "Show Config Details",
        Icon = "eye",
        Callback = function()
            if selectedConfigFile and selectedConfigFile ~= "" then
                local info = self:GetConfigData(selectedConfigFile)
                if info then
                    local content = "Name: " .. info.name .. 
                                  "\nPlayer: " .. (info.player or "Unknown") ..
                                  "\nVersion: " .. (info.version or "Unknown") ..
                                  "\nCreated: " .. (info.timestamp and os.date("%c", info.timestamp) or "Unknown")
                    
                    WindUI:Notify({
                        Title = "Config Details",
                        Content = content,
                        Duration = 5,
                        Icon = "info"
                    })
                else
                    WindUI:Notify({
                        Title = "No Details",
                        Content = "Could not load details for '" .. selectedConfigFile .. "'",
                        Duration = 3,
                        Icon = "alert-triangle"
                    })
                end
            else
                WindUI:Notify({
                    Title = "No Selection",
                    Content = "Please select a configuration file to view details",
                    Duration = 3,
                    Icon = "alert-triangle"
                })
            end
        end
    })
    
    -- Export/Import Section
    SaveTab:Section({ Title = "Advanced", Icon = "settings" })
    
    SaveTab:Button({
        Title = "Export All Configs",
        Icon = "package",
        Callback = function()
            local allConfigs = {}
            local files = self:ListConfigs()
            local exportCount = 0
            
            for _, fileName in ipairs(files) do
                local data = LoadFile(fileName)
                if data then
                    allConfigs[fileName] = data
                    exportCount = exportCount + 1
                end
            end
            
            if exportCount > 0 then
                local success = SaveFile("AllConfigs_Export_" .. os.time(), allConfigs)
                if success then
                    WindUI:Notify({
                        Title = "Export Complete",
                        Content = "Exported " .. exportCount .. " configurations",
                        Duration = 3,
                        Icon = "check-circle"
                    })
                end
            else
                WindUI:Notify({
                    Title = "Export Failed",
                    Content = "No configurations found to export",
                    Duration = 3,
                    Icon = "alert-triangle"
                })
            end
        end
    })
    
    return configDropdown
end

-- Auto-load functionality
function ConfigManager:AutoLoad()
    if not autoLoadEnabled then return end
    
    local files = self:ListConfigs()
    if #files > 0 then
        -- Try to load the most recent config or default
        local targetFile = self.name
        local found = false
        
        for _, fileName in ipairs(files) do
            if fileName == targetFile then
                found = true
                break
            end
        end
        
        if not found and #files > 0 then
            targetFile = files[1] -- Load first available config
        end
        
        if found or #files > 0 then
            task.delay(1, function() -- Small delay to ensure UI is ready
                self:Load(targetFile)
            end)
        end
    end
end

return ConfigManager
