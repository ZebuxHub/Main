-- ConfigSystem.lua - Enhanced Configuration Management for Build A Zoo
-- Author: Zebux
-- Version: 2.0

local ConfigSystem = {}

-- Services
local HttpService = game:GetService("HttpService")

-- Module variables
local WindUI = nil
local Window = nil
local ConfigManager = nil

-- Config instances
local mainConfig = nil
local autoSystemsConfig = nil
local customUIConfig = nil

-- Custom UI selections storage (separate from WindUI config)
local customSelections = {
    eggSelections = {},
    fruitSelections = {},
    feedFruitSelections = {}
}

-- Enhanced save function
local function saveAllConfigs()
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
        ConfigSystem.saveCustomSelections()
    end)
    results.customSelections = customSuccess and "✅ Success" or ("❌ " .. tostring(customErr))
    
    return results
end

-- Enhanced load function
local function loadAllConfigs()
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
    local customSuccess, customErr = pcall(function()
        ConfigSystem.loadCustomSelections()
    end)
    results.customSelections = customSuccess and "✅ Success" or ("❌ " .. tostring(customErr))
    
    return results
end

-- Function to save custom UI selections
function ConfigSystem.saveCustomSelections()
    local success, err = pcall(function()
        local jsonData = HttpService:JSONEncode(customSelections)
        writefile("Zebux_CustomSelections.json", jsonData)
    end)
    
    if not success then
        warn("Failed to save custom selections: " .. tostring(err))
    end
end

-- Function to load custom UI selections
function ConfigSystem.loadCustomSelections()
    local success, err = pcall(function()
        if isfile("Zebux_CustomSelections.json") then
            local jsonData = readfile("Zebux_CustomSelections.json")
            local loaded = HttpService:JSONDecode(jsonData)
            if loaded then
                customSelections = loaded
                return true
            end
        end
    end)
    
    if not success then
        warn("Failed to load custom selections: " .. tostring(err))
    end
    return success
end

-- Function to update custom UI selections
function ConfigSystem.updateCustomSelection(uiType, selections)
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
    
    ConfigSystem.saveCustomSelections()
end

-- Get custom selections
function ConfigSystem.getCustomSelections()
    return customSelections
end

-- Register all UI elements with WindUI ConfigManager
function ConfigSystem.registerUIElements(elements)
    local function registerIfExists(config, key, element, description)
        if element then
            local success, err = pcall(function()
                config:Register(key, element)
            end)
            if not success then
                warn("❌ Failed to register " .. (description or key) .. ":", err)
            end
        end
    end
    
    -- Register Main Config elements
    registerIfExists(mainConfig, "autoBuyEnabled", elements.autoBuyToggle, "Auto Buy Toggle")
    registerIfExists(mainConfig, "autoHatchEnabled", elements.autoHatchToggle, "Auto Hatch Toggle")
    registerIfExists(mainConfig, "autoClaimEnabled", elements.autoClaimToggle, "Auto Claim Toggle")
    registerIfExists(mainConfig, "autoPlaceEnabled", elements.autoPlaceToggle, "Auto Place Toggle")
    registerIfExists(mainConfig, "autoUnlockEnabled", elements.autoUnlockToggle, "Auto Unlock Toggle")
    registerIfExists(mainConfig, "autoClaimDelaySlider", elements.autoClaimDelaySlider, "Auto Claim Delay Slider")
    
    -- Register Auto Systems Config elements
    registerIfExists(autoSystemsConfig, "autoDeleteEnabled", elements.autoDeleteToggle, "Auto Delete Toggle")
    registerIfExists(autoSystemsConfig, "autoDinoEnabled", elements.autoDinoToggle, "Auto Dino Toggle")
    registerIfExists(autoSystemsConfig, "autoUpgradeEnabled", elements.autoUpgradeToggle, "Auto Upgrade Toggle")
    registerIfExists(autoSystemsConfig, "autoBuyFruitEnabled", elements.autoBuyFruitToggle, "Auto Buy Fruit Toggle")
    registerIfExists(autoSystemsConfig, "autoFeedEnabled", elements.autoFeedToggle, "Auto Feed Toggle")
    registerIfExists(autoSystemsConfig, "autoDeleteSpeedSlider", elements.autoDeleteSpeedSlider, "Auto Delete Speed Slider")
    
    -- Register Custom UI Config elements
    registerIfExists(customUIConfig, "placeEggDropdown", elements.placeEggDropdown, "Place Egg Dropdown")
    registerIfExists(customUIConfig, "placeMutationDropdown", elements.placeMutationDropdown, "Place Mutation Dropdown")
end

-- Create UI for Save Tab
function ConfigSystem.createSaveTabUI(Tabs)
    -- Enhanced save/load section
    Tabs.SaveTab:Section({ Title = "💾 Save & Load", Icon = "save" })

    Tabs.SaveTab:Paragraph({
        Title = "💾 Enhanced Settings Manager",
        Desc = "Advanced WindUI ConfigManager system with organized categories:\n" ..
               "🔵 Main Config - Core automation (Buy, Hatch, Claim, Place, Unlock)\n" ..
               "🤖 Auto Systems - Advanced features (Delete, Dino, Upgrade, Feed)\n" ..
               "🎨 Custom UI - Dropdowns and selections\n" ..
               "📁 Custom Selections - Egg/Fruit choices saved separately",
        Image = "save",
        ImageSize = 18,
    })

    Tabs.SaveTab:Button({
        Title = "💾 Save All Settings",
        Desc = "Save all settings across all config categories",
        Callback = function()
            local results = saveAllConfigs()
            local totalSuccess = 0
            local totalCount = 0
            
            for category, result in pairs(results) do
                totalCount = totalCount + 1
                if result:find("✅") then
                    totalSuccess = totalSuccess + 1
                end
            end
            
            local message = string.format("Saved %d/%d categories successfully!", totalSuccess, totalCount)
            WindUI:Notify({ 
                Title = "💾 Save Complete", 
                Content = message, 
                Duration = 3 
            })
        end
    })

    Tabs.SaveTab:Button({
        Title = "📂 Load All Settings",
        Desc = "Load all saved settings from all config categories",
        Callback = function()
            local results = loadAllConfigs()
            local totalSuccess = 0
            local totalCount = 0
            
            for category, result in pairs(results) do
                totalCount = totalCount + 1
                if result:find("✅") then
                    totalSuccess = totalSuccess + 1
                end
            end
            
            local message = string.format("Loaded %d/%d categories successfully!", totalSuccess, totalCount)
            WindUI:Notify({ 
                Title = "📂 Load Complete", 
                Content = message, 
                Duration = 3 
            })
        end
    })

    -- Individual config management
    Tabs.SaveTab:Section({ Title = "🗂️ Individual Configs", Icon = "folder" })

    Tabs.SaveTab:Button({
        Title = "💾 Save Main Config Only",
        Desc = "Save core settings (Auto Buy, Hatch, Claim, Place, Unlock)",
        Callback = function()
            local success, err = pcall(function()
                mainConfig:Save()
            end)
            local message = success and "Main config saved!" or ("Failed: " .. tostring(err))
            WindUI:Notify({ Title = "💾 Main Config", Content = message, Duration = 2 })
        end
    })

    Tabs.SaveTab:Button({
        Title = "🤖 Save Auto Systems Config",
        Desc = "Save advanced automation (Delete, Dino, Upgrade, Fruit, Feed)",
        Callback = function()
            local success, err = pcall(function()
                autoSystemsConfig:Save()
            end)
            local message = success and "Auto systems saved!" or ("Failed: " .. tostring(err))
            WindUI:Notify({ Title = "🤖 Auto Systems", Content = message, Duration = 2 })
        end
    })

    Tabs.SaveTab:Button({
        Title = "🎨 Save Custom UI Config",
        Desc = "Save dropdowns and UI element states",
        Callback = function()
            local success, err = pcall(function()
                customUIConfig:Save()
            end)
            local message = success and "Custom UI saved!" or ("Failed: " .. tostring(err))
            WindUI:Notify({ Title = "🎨 Custom UI", Content = message, Duration = 2 })
        end
    })

    -- Config browser
    Tabs.SaveTab:Section({ Title = "📋 Config Browser", Icon = "list" })

    Tabs.SaveTab:Button({
        Title = "📋 View All Configs",
        Desc = "Show all available config files and their contents",
        Callback = function()
            local allConfigs = ConfigManager:AllConfigs()
            
            for configName, configData in pairs(allConfigs) do
                local count = 0
                for _ in pairs(configData) do
                    count = count + 1
                end
            end
            
            WindUI:Notify({ 
                Title = "📋 Config Browser", 
                Content = "Config details printed to console!", 
                Duration = 3 
            })
        end
    })

    -- Import/Export
    Tabs.SaveTab:Button({
        Title = "📤 Export Settings",
        Desc = "Export your settings to clipboard",
        Callback = function()
            local success, err = pcall(function()
                local configData = ConfigManager:AllConfigs()
                local exportData = {
                    windUIConfig = configData,
                    customSelections = customSelections
                }
                local jsonData = HttpService:JSONEncode(exportData)
                setclipboard(jsonData)
            end)
            
            if success then
                WindUI:Notify({ 
                    Title = "📤 Settings Exported", 
                    Content = "Settings copied to clipboard! 🎉", 
                    Duration = 3 
                })
            else
                WindUI:Notify({ 
                    Title = "❌ Export Failed", 
                    Content = "Failed to export settings: " .. tostring(err), 
                    Duration = 5 
                })
            end
        end
    })

    Tabs.SaveTab:Button({
        Title = "📥 Import Settings",
        Desc = "Import settings from clipboard",
        Callback = function()
            local success, err = pcall(function()
                local clipboardData = getclipboard()
                local importedData = HttpService:JSONDecode(clipboardData)
                
                if importedData and importedData.windUIConfig then
                    for configName, configData in pairs(importedData.windUIConfig) do
                        local config = ConfigManager:GetConfig(configName)
                        if config then
                            config:LoadFromData(configData)
                        end
                    end
                    
                    if importedData.customSelections then
                        customSelections = importedData.customSelections
                        ConfigSystem.saveCustomSelections()
                    end
                    
                    WindUI:Notify({ 
                        Title = "📥 Settings Imported", 
                        Content = "Settings imported successfully! 🎉", 
                        Duration = 3 
                    })
                else
                    error("Invalid settings format")
                end
            end)
            
            if not success then
                WindUI:Notify({ 
                    Title = "❌ Import Failed", 
                    Content = "Failed to import settings: " .. tostring(err), 
                    Duration = 5 
                })
            end
        end
    })
end

-- Auto-load function
function ConfigSystem.autoLoad(syncCallback)
    local loadResults = loadAllConfigs()
    
    -- Count successful loads
    local successCount = 0
    local totalCount = 0
    for category, result in pairs(loadResults) do
        totalCount = totalCount + 1
        if result:find("✅") then
            successCount = successCount + 1
        end
    end
    
    -- Sync UI after loading
    if syncCallback then
        task.spawn(function()
            task.wait(0.1)
            syncCallback()
        end)
        
        task.delay(0.5, function()
            syncCallback()
        end)
    end
    
    -- Show appropriate notification based on results
    local notificationTitle = "📂 Auto-Load Complete"
    local notificationContent
    
    if successCount == totalCount then
        notificationContent = string.format("All %d config categories loaded successfully! 🎉", totalCount)
    elseif successCount > 0 then
        notificationContent = string.format("Loaded %d/%d config categories (partial success)", successCount, totalCount)
    else
        notificationContent = "No configs found - using default settings"
        notificationTitle = "📂 Auto-Load (Defaults)"
    end
    
    WindUI:Notify({ 
        Title = notificationTitle, 
        Content = notificationContent, 
        Duration = 3 
    })
    
    return true
end

-- Initialize function
function ConfigSystem.Init(dependencies)
    WindUI = dependencies.WindUI
    Window = dependencies.Window
    ConfigManager = Window.ConfigManager
    
    -- Create config files for different categories
    mainConfig = ConfigManager:CreateConfig("BuildAZoo_Main")
    autoSystemsConfig = ConfigManager:CreateConfig("BuildAZoo_AutoSystems") 
    customUIConfig = ConfigManager:CreateConfig("BuildAZoo_CustomUI")
    
    -- Load existing custom selections
    ConfigSystem.loadCustomSelections()
    
    return {
        mainConfig = mainConfig,
        autoSystemsConfig = autoSystemsConfig,
        customUIConfig = customUIConfig,
        saveAllConfigs = saveAllConfigs,
        loadAllConfigs = loadAllConfigs
    }
end

return ConfigSystem
