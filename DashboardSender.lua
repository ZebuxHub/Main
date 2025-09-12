-- DashboardIntegration.lua
-- Example integration of DashboardSender with existing Build A Zoo systems
-- This shows how to connect the dashboard to your main script

local DashboardIntegration = {}

-- Example of how to integrate DashboardSender into your main Build A Zoo script
local function setupDashboardIntegration()
    
    -- Load the DashboardSender module
    local DashboardSender = require(script.Parent.DashboardSender)
    
    -- Initialize with your existing dependencies
    DashboardSender = DashboardSender.InitCore({
        WindUI = WindUI,
        Window = Window,
        Config = Config,
        WebhookSystem = WebhookSystem -- Pass WebhookSystem for inventory access
    })
    
    -- Configure your Supabase settings
    -- IMPORTANT: Replace these with your actual Supabase project values
    DashboardSender.SetSupabaseConfig(
        "https://your-https://gtenepqivurfmvbsoxeo.supabase.co-id.supabase.co",  -- Your Supabase URL
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd0ZW5lcHFpdnVyZm12YnNveGVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2NzYzMjEsImV4cCI6MjA3MzI1MjMyMX0.FyZdIIyhrUdC8HERluKvBJZ-8Cyr6PTNZ5fEMEhQi9w"                    -- Your Supabase anon key
    )
    
    -- Enable dashboard updates
    DashboardSender.SetEnabled(true)
    
    -- Set update frequency (30 seconds is recommended)
    DashboardSender.SetUpdateInterval(30)
    
    -- Show HWID to user for reference
    local hwid = DashboardSender.GetHWID()
    if WindUI and WindUI.Notify then
        WindUI:Notify({
            Title = "Dashboard Connected",
            Content = "Your HWID: " .. hwid:sub(1, 8) .. "... 📊",
            Duration = 5
        })
    end
    
    return DashboardSender
end

-- Example UI integration (if you want to add dashboard controls to your UI)
local function createDashboardUI(Tab, DashboardSender)
    if not Tab or not DashboardSender then return end
    
    -- Create Dashboard section in your existing tab
    local DashboardSection = Tab:CreateSection("Dashboard")
    
    -- Toggle for dashboard updates
    local DashboardToggle = DashboardSection:CreateToggle({
        Name = "Enable Dashboard",
        CurrentValue = false,
        Flag = "DashboardEnabled",
        Callback = function(Value)
            DashboardSender.SetEnabled(Value)
            if Value then
                WindUI:Notify({
                    Title = "Dashboard Enabled",
                    Content = "Data will be sent to dashboard every 30 seconds",
                    Duration = 3
                })
            else
                WindUI:Notify({
                    Title = "Dashboard Disabled", 
                    Content = "Dashboard updates stopped",
                    Duration = 3
                })
            end
        end
    })
    
    -- Slider for update frequency
    local UpdateSlider = DashboardSection:CreateSlider({
        Name = "Update Interval",
        Range = {10, 300},
        Increment = 10,
        CurrentValue = 30,
        Flag = "DashboardInterval",
        Callback = function(Value)
            DashboardSender.SetUpdateInterval(Value)
            WindUI:Notify({
                Title = "Update Interval Changed",
                Content = "Dashboard will update every " .. Value .. " seconds",
                Duration = 2
            })
        end
    })
    
    -- Button to send data immediately
    local SendNowButton = DashboardSection:CreateButton({
        Name = "Send Data Now",
        Callback = function()
            local success = DashboardSender.SendDataNow()
            if success then
                WindUI:Notify({
                    Title = "Data Sent",
                    Content = "Dashboard updated successfully! 📊",
                    Duration = 2
                })
            end
        end
    })
    
    -- Display HWID
    local HWIDLabel = DashboardSection:CreateLabel("HWID: " .. DashboardSender.GetHWID():sub(1, 16) .. "...")
    
    -- Input for Supabase URL
    local URLInput = DashboardSection:CreateInput({
        Name = "Supabase URL",
        PlaceholderText = "https://your-project.supabase.co",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            if Text and Text ~= "" then
                -- Extract key from current config or use placeholder
                local currentConfig = DashboardSender.GetConfigElements()
                DashboardSender.SetSupabaseConfig(Text, currentConfig.supabaseKey)
                WindUI:Notify({
                    Title = "Supabase URL Updated",
                    Content = "Dashboard will use new URL",
                    Duration = 2
                })
            end
        end
    })
    
    -- Input for Supabase API Key
    local KeyInput = DashboardSection:CreateInput({
        Name = "Supabase API Key", 
        PlaceholderText = "your-anon-key-here",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            if Text and Text ~= "" then
                -- Extract URL from current config or use placeholder
                local currentConfig = DashboardSender.GetConfigElements()
                DashboardSender.SetSupabaseConfig(currentConfig.supabaseUrl, Text)
                WindUI:Notify({
                    Title = "API Key Updated",
                    Content = "Dashboard authentication updated",
                    Duration = 2
                })
            end
        end
    })
    
    return {
        DashboardToggle = DashboardToggle,
        UpdateSlider = UpdateSlider,
        SendNowButton = SendNowButton,
        HWIDLabel = HWIDLabel,
        URLInput = URLInput,
        KeyInput = KeyInput
    }
end

-- Example config integration
local function setupDashboardConfig(Config, DashboardSender)
    if not Config or not DashboardSender then return end
    
    -- Add dashboard config to your existing config system
    Config.DashboardEnabled = false
    Config.DashboardInterval = 30
    Config.SupabaseURL = "https://your-project.supabase.co"
    Config.SupabaseKey = "your-anon-key-here"
    
    -- Load dashboard config
    local function loadDashboardConfig()
        local config = DashboardSender.GetConfigElements()
        Config.DashboardEnabled = config.dashboardEnabled
        Config.DashboardInterval = config.updateInterval
        Config.SupabaseURL = config.supabaseUrl
        Config.SupabaseKey = config.supabaseKey
    end
    
    -- Save dashboard config
    local function saveDashboardConfig()
        DashboardSender.LoadConfig({
            dashboardEnabled = Config.DashboardEnabled,
            updateInterval = Config.DashboardInterval,
            supabaseUrl = Config.SupabaseURL,
            supabaseKey = Config.SupabaseKey
        })
    end
    
    return {
        load = loadDashboardConfig,
        save = saveDashboardConfig
    }
end

-- Main integration function
function DashboardIntegration.Setup(dependencies)
    local WindUI = dependencies.WindUI
    local Window = dependencies.Window
    local Config = dependencies.Config
    local Tab = dependencies.Tab -- Optional: for UI integration
    local WebhookSystem = dependencies.WebhookSystem
    
    -- Set up dashboard sender
    local DashboardSender = setupDashboardIntegration()
    
    -- Set up UI if Tab is provided
    local dashboardUI = nil
    if Tab then
        dashboardUI = createDashboardUI(Tab, DashboardSender)
    end
    
    -- Set up config integration
    local dashboardConfig = setupDashboardConfig(Config, DashboardSender)
    
    -- Return the integrated system
    return {
        DashboardSender = DashboardSender,
        UI = dashboardUI,
        Config = dashboardConfig
    }
end

-- Example usage in your main script:
--[[

-- In your main Build A Zoo script, add this:

local DashboardIntegration = require(script.DashboardIntegration)

-- After your existing UI setup, add:
local Dashboard = DashboardIntegration.Setup({
    WindUI = WindUI,
    Window = Window, 
    Config = Config,
    Tab = YourExistingTab, -- Optional: adds dashboard UI controls
    WebhookSystem = WebhookSystem
})

-- The dashboard will now automatically:
-- 1. Send player data every 30 seconds
-- 2. Include pets, eggs, fruits, net worth, tickets
-- 3. Use HWID-based identification
-- 4. Work with your existing webhook system
-- 5. Provide UI controls (if Tab provided)

--]]

return DashboardIntegration
