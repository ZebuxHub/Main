-- SystemIntegration.lua - Integration layer for all Build A Zoo systems
-- Provides unified initialization and config management

local SystemIntegration = {}

-- Import the unified config manager
local UnifiedConfigManager = require(script.Parent.UnifiedConfigManager)

-- System modules (lazy loaded)
local systems = {
    AutoSellSystem = nil,
    MiscSystem = nil,
    AutoFeedSystem = nil,
    AutoFishSystem = nil,
    WebhookSystem = nil,
    -- Add other systems as needed
}

-- UI Management
local uiManagers = {
    WindUI = nil,
    CustomUI = nil
}

-- Configuration categories
local CONFIG_CATEGORIES = {
    MAIN = "main",
    AUTO_SYSTEMS = "auto_systems", 
    CUSTOM_UI = "custom_ui",
    MISC = "misc",
    WEBHOOKS = "webhooks",
    PERFORMANCE = "performance"
}

-- Performance settings for low-end devices
local PERFORMANCE_SETTINGS = {
    LOW_END_MODE = false,
    REDUCE_ANIMATIONS = false,
    BATCH_OPERATIONS = true,
    MEMORY_CLEANUP_INTERVAL = 30,
    AUTO_SAVE_INTERVAL = 60,
    MAX_CONCURRENT_OPERATIONS = 3
}

-- System state
local isInitialized = false
local activeUISystems = {}
local systemDependencies = {}

-- Utility Functions
local function detectLowEndDevice()
    -- Simple heuristic based on memory and performance
    local memoryUsage = collectgarbage("count")
    local startTime = tick()
    
    -- Perform a small computation test
    for i = 1, 1000 do
        math.sin(i)
    end
    
    local computeTime = tick() - startTime
    
    -- Consider low-end if high memory usage or slow computation
    return memoryUsage > 100000 or computeTime > 0.1
end

local function applyPerformanceSettings()
    if PERFORMANCE_SETTINGS.LOW_END_MODE then
        -- Reduce visual effects
        if PERFORMANCE_SETTINGS.REDUCE_ANIMATIONS then
            -- Disable or reduce animations in UI systems
            pcall(function()
                if uiManagers.WindUI and uiManagers.WindUI.SetAnimationSpeed then
                    uiManagers.WindUI:SetAnimationSpeed(0.5)
                end
            end)
        end
        
        -- Adjust memory cleanup
        UnifiedConfigManager:Init()
        
        -- Force more frequent garbage collection
        task.spawn(function()
            while true do
                task.wait(PERFORMANCE_SETTINGS.MEMORY_CLEANUP_INTERVAL)
                collectgarbage("collect")
            end
        end)
    end
end

-- System Loading Functions
local function loadSystem(systemName, dependencies)
    if systems[systemName] then
        return systems[systemName] -- Already loaded
    end
    
    local success, system = pcall(function()
        return require(script.Parent[systemName])
    end)
    
    if success and system then
        systems[systemName] = system
        systemDependencies[systemName] = dependencies or {}
        
        -- Initialize system if it has an Init function
        if system.Init and type(system.Init) == "function" then
            local initSuccess = pcall(function()
                return system.Init(dependencies or {})
            end)
            
            if not initSuccess then
                warn("SystemIntegration: Failed to initialize " .. systemName)
                systems[systemName] = nil
                return nil
            end
        end
        
        return system
    else
        warn("SystemIntegration: Failed to load " .. systemName .. ": " .. tostring(system))
        return nil
    end
end

-- UI System Management
function SystemIntegration:InitializeWindUI(windUIInstance)
    if not windUIInstance then
        warn("SystemIntegration: WindUI instance is required")
        return false
    end
    
    uiManagers.WindUI = windUIInstance
    activeUISystems.WindUI = true
    
    -- Create section and tabs for different system categories
    local mainSection = windUIInstance:Section({ Title = "Auto Helpers", Icon = "zap", Opened = true })
    local tabs = {
        MainSection = mainSection,
        MainTab = mainSection:Tab({ Title = "Main", Icon = "tv"}),
        PlaceTab = mainSection:Tab({ Title = "Place Pets", Icon = "map-pin"}),
        ShopTab = mainSection:Tab({ Title = "Shop", Icon = "shopping-cart"}),
        FishTab = mainSection:Tab({ Title = "Auto Fish", Icon = "anchor"}),
        MiscTab = mainSection:Tab({ Title = "Quest", Icon = "settings"}),
        PerfTab = mainSection:Tab({ Title = "Performance [Premium]", Icon = "activity", Locked = true}),
        TrashTab = mainSection:Tab({ Title = "Auto Trade [Premium]", Icon = "trash-2", Locked = true}),
        WebhookTab = mainSection:Tab({ Title = "Webhook [Premium]", Icon = "webhook", Locked = true}),
        ConfigTab = mainSection:Tab({ Title = "Config", Icon = "save"})
    }
    
    -- Store tabs for system access
    uiManagers.WindUITabs = tabs
    
    return true
end

function SystemIntegration:InitializeCustomUI(customUIInstance)
    uiManagers.CustomUI = customUIInstance
    activeUISystems.CustomUI = true
    return true
end

-- System Registration and Initialization
function SystemIntegration:RegisterSystem(systemName, configCategory, dependencies)
    configCategory = configCategory or CONFIG_CATEGORIES.MAIN
    
    -- Prepare dependencies
    local systemDeps = dependencies or {}
    systemDeps.UnifiedConfig = UnifiedConfigManager
    systemDeps.ConfigCategory = configCategory
    
    -- Add UI managers if available
    if uiManagers.WindUI then
        systemDeps.WindUI = uiManagers.WindUI
        systemDeps.Tabs = uiManagers.WindUITabs
    end
    
    if uiManagers.CustomUI then
        systemDeps.CustomUI = uiManagers.CustomUI
    end
    
    -- Load and initialize system
    local system = loadSystem(systemName, systemDeps)
    
    if system then
        -- Register system config elements
        if system.GetConfigElements and type(system.GetConfigElements) == "function" then
            local elements = system.GetConfigElements()
            if type(elements) == "table" then
                for elementId, element in pairs(elements) do
                    UnifiedConfigManager:Register(
                        systemName .. "_" .. elementId, 
                        element, 
                        configCategory
                    )
                end
            end
        end
        
        return system
    end
    
    return nil
end

-- Batch System Loading
function SystemIntegration:LoadAllSystems()
    local systemConfigs = {
        {
            name = "AutoSellSystem",
            category = CONFIG_CATEGORIES.AUTO_SYSTEMS,
            dependencies = { MainTab = uiManagers.WindUITabs and uiManagers.WindUITabs.AutoTab }
        },
        {
            name = "MiscSystem", 
            category = CONFIG_CATEGORIES.MISC,
            dependencies = { Tab = uiManagers.WindUITabs and uiManagers.WindUITabs.MiscTab }
        },
        {
            name = "AutoFeedSystem",
            category = CONFIG_CATEGORIES.AUTO_SYSTEMS,
            dependencies = { MainTab = uiManagers.WindUITabs and uiManagers.WindUITabs.AutoTab }
        },
        {
            name = "AutoFishSystem",
            category = CONFIG_CATEGORIES.AUTO_SYSTEMS,
            dependencies = { MainTab = uiManagers.WindUITabs and uiManagers.WindUITabs.AutoTab }
        },
        {
            name = "WebhookSystem",
            category = CONFIG_CATEGORIES.WEBHOOKS,
            dependencies = { MainTab = uiManagers.WindUITabs and uiManagers.WindUITabs.MiscTab }
        }
    }
    
    local loadedSystems = {}
    local failedSystems = {}
    
    for _, config in ipairs(systemConfigs) do
        local system = self:RegisterSystem(config.name, config.category, config.dependencies)
        if system then
            table.insert(loadedSystems, config.name)
        else
            table.insert(failedSystems, config.name)
        end
        
        -- Yield occasionally to prevent freezing on low-end devices
        if PERFORMANCE_SETTINGS.LOW_END_MODE then
            task.wait(0.1)
        end
    end
    
    return loadedSystems, failedSystems
end

-- Config Management UI
function SystemIntegration:CreateConfigUI()
    if not uiManagers.WindUITabs or not uiManagers.WindUITabs.ConfigTab then
        return false
    end
    
    local ConfigTab = uiManagers.WindUITabs.ConfigTab
    
    -- Performance Settings Section
    ConfigTab:Section({ Title = "Performance", Icon = "zap" })
    
    ConfigTab:Toggle({
        Title = "Low-End Device Mode",
        Desc = "Optimize for low-end devices",
        Value = PERFORMANCE_SETTINGS.LOW_END_MODE,
        Callback = function(value)
            PERFORMANCE_SETTINGS.LOW_END_MODE = value
            applyPerformanceSettings()
            UnifiedConfigManager:Register("performance_low_end_mode", {
                Get = function() return PERFORMANCE_SETTINGS.LOW_END_MODE end,
                Set = function(v) PERFORMANCE_SETTINGS.LOW_END_MODE = v end
            }, CONFIG_CATEGORIES.PERFORMANCE)
        end
    })
    
    ConfigTab:Toggle({
        Title = "Reduce Animations",
        Desc = "Reduce UI animations for better performance",
        Value = PERFORMANCE_SETTINGS.REDUCE_ANIMATIONS,
        Callback = function(value)
            PERFORMANCE_SETTINGS.REDUCE_ANIMATIONS = value
            applyPerformanceSettings()
        end
    })
    
    -- Config Management Section
    ConfigTab:Section({ Title = "Config Management", Icon = "save" })
    
    local statusParagraph = ConfigTab:Paragraph({
        Title = "Status",
        Desc = "Ready to save/load configurations"
    })
    
    -- Save All Button
    ConfigTab:Button({
        Title = "💾 Save All Settings",
        Desc = "Save all system configurations",
        Callback = function()
            local success, savedCount, totalCount = UnifiedConfigManager:SaveAll()
            local message = success and 
                string.format("Saved %d/%d settings successfully!", savedCount, totalCount) or
                "Failed to save settings"
            
            statusParagraph:SetDesc(message)
            
            if uiManagers.WindUI then
                uiManagers.WindUI:Notify({
                    Title = "💾 Save Complete",
                    Content = message,
                    Duration = 3
                })
            end
        end
    })
    
    -- Load All Button  
    ConfigTab:Button({
        Title = "📂 Load All Settings",
        Desc = "Load all system configurations",
        Callback = function()
            local success, loadedCount, totalCount = UnifiedConfigManager:LoadAll()
            local message = success and
                string.format("Loaded %d/%d settings successfully!", loadedCount, totalCount) or
                "Failed to load settings"
            
            statusParagraph:SetDesc(message)
            
            if uiManagers.WindUI then
                uiManagers.WindUI:Notify({
                    Title = "📂 Load Complete", 
                    Content = message,
                    Duration = 3
                })
            end
        end
    })
    
    -- Category Management
    local categories = UnifiedConfigManager:GetCategories()
    if #categories > 0 then
        ConfigTab:Dropdown({
            Title = "Export Category",
            Desc = "Export specific category",
            Values = categories,
            Value = categories[1],
            Multi = false,
            Callback = function(category)
                if category then
                    local data = UnifiedConfigManager:ExportCategory(category)
                    if data then
                        -- Could implement clipboard copy or file export here
                        statusParagraph:SetDesc("Exported " .. category .. " category")
                    end
                end
            end
        })
    end
    
    -- Performance Stats
    ConfigTab:Button({
        Title = "📊 Show Performance Stats",
        Desc = "Display performance statistics",
        Callback = function()
            local stats = UnifiedConfigManager:GetStats()
            local message = string.format(
                "Elements: %d | Categories: %d | Memory: %.1fMB | Avg Save: %.3fs",
                stats.registeredElements,
                stats.categories, 
                stats.memoryUsage / 1024,
                stats.avgSaveTime
            )
            statusParagraph:SetDesc(message)
        end
    })
    
    return true
end

-- Main Initialization
function SystemIntegration:Init(windUIInstance)
    if isInitialized then
        return true
    end
    
    -- Initialize unified config manager
    UnifiedConfigManager:Init()
    
    -- Detect device performance
    PERFORMANCE_SETTINGS.LOW_END_MODE = detectLowEndDevice()
    
    -- Apply performance settings
    applyPerformanceSettings()
    
    -- Initialize UI system
    if windUIInstance then
        self:InitializeWindUI(windUIInstance)
    end
    
    -- Load all systems
    local loaded, failed = self:LoadAllSystems()
    
    -- Create config UI
    self:CreateConfigUI()
    
    -- Auto-load configs
    task.spawn(function()
        task.wait(2) -- Wait for UI to fully initialize
        UnifiedConfigManager:LoadAll()
    end)
    
    isInitialized = true
    
    -- Return initialization results
    return {
        success = true,
        loadedSystems = loaded,
        failedSystems = failed,
        lowEndMode = PERFORMANCE_SETTINGS.LOW_END_MODE,
        configManager = UnifiedConfigManager
    }
end

-- Cleanup
function SystemIntegration:Cleanup()
    -- Save all configs before cleanup
    UnifiedConfigManager:SaveAll()
    
    -- Cleanup systems
    for systemName, system in pairs(systems) do
        if system and system.Cleanup and type(system.Cleanup) == "function" then
            pcall(system.Cleanup)
        end
    end
    
    -- Cleanup config manager
    UnifiedConfigManager:Cleanup()
    
    -- Clear references
    systems = {}
    uiManagers = {}
    activeUISystems = {}
    systemDependencies = {}
    
    isInitialized = false
end

-- Public API
SystemIntegration.UnifiedConfig = UnifiedConfigManager
SystemIntegration.ConfigCategories = CONFIG_CATEGORIES
SystemIntegration.PerformanceSettings = PERFORMANCE_SETTINGS

return SystemIntegration
