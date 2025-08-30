-- Build A Zoo: Main Script using WindUI (Modular Version)
-- Author: Zebux
-- Version: 2.0 - Modularized

-- Load WindUI library
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Load core modules
local Core = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/Core.lua"))()
local ConfigManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/ConfigManager.lua"))()
local AutoClaim = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/AutoClaim.lua"))()
local AutoHatch = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/AutoHatch.lua"))()
local AutoPlace = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/AutoPlace.lua"))()
local AutoShop = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/AutoShop.lua"))()
local AutoPacks = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/AutoPacks.lua"))()
local Settings = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/Settings.lua"))()

-- Load additional systems
local EggSelection = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/EggSelection.lua"))()
local FruitSelection = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/FruitSelection.lua"))()
local FeedFruitSelection = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/FeedFruitSelection.lua"))()
local AutoFeedSystem = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/AutoFeedSystem.lua"))()

-- Load Auto Fish System
local AutoFishSystem = nil
task.spawn(function()
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/AutoFishSystem.lua"))()
    end)
    if success and result then
        AutoFishSystem = result
    end
end)

-- Selection state variables
local selectedTypeSet = {}
local selectedMutationSet = {}
local selectedFruits = {}
local selectedFeedFruits = {}
local updateCustomUISelection
local settingsLoaded = false

-- Global settings ready flag
_G.ZebuxSettingsLoaded = false

-- Auto Feed variables
local autoFeedEnabled = false
local autoFeedThread = nil
local autoFeedToggle

-- Window
local Window = WindUI:CreateWindow({
    Title = "Build A Zoo",
    Icon = "app-window-mac",
    IconThemed = true,
    Author = "Zebux",
    Folder = "Zebux",
    Size = UDim2.fromOffset(520, 360),
    Transparent = true,
    Theme = "Dark",
})

-- Setup default open button (always visible)
Window:EditOpenButton({
    Title = "Build A Zoo",
    Icon = "monitor",
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 2,
    Color = ColorSequence.new( -- gradient
        Color3.fromHex("FF0F7B"), 
        Color3.fromHex("F89B29")
    ),
    OnlyMobile = false,
    Enabled = true,
    Draggable = true,
})

-- Create tabs
local Tabs = {}
Tabs.MainSection = Window:Section({ Title = "🤖 Auto Helpers", Opened = true })
Tabs.AutoTab = Tabs.MainSection:Tab({ Title = "🥚 | Buy Eggs"})
Tabs.PlaceTab = Tabs.MainSection:Tab({ Title = "🏠 | Place Pets"})
Tabs.HatchTab = Tabs.MainSection:Tab({ Title = "⚡ | Hatch Eggs"})
Tabs.ClaimTab = Tabs.MainSection:Tab({ Title = "💰 | Get Money"})
Tabs.ShopTab = Tabs.MainSection:Tab({ Title = "🛒 | Shop"})
Tabs.PackTab = Tabs.MainSection:Tab({ Title = "🎁 | Get Packs"})
Tabs.FruitTab = Tabs.MainSection:Tab({ Title = "🍎 | Fruit Store"})
Tabs.FeedTab = Tabs.MainSection:Tab({ Title = "🍽️ | Auto Feed"})
Tabs.FishTab = Tabs.MainSection:Tab({ Title = "🎣 | Auto Fish"})
Tabs.SaveTab = Tabs.MainSection:Tab({ Title = "💾 | Save Settings"})

-- Initialize all modules
ConfigManager.initializeAll()

-- Create UI for each module
-- Auto Claim/Money Tab
local autoClaimToggle = Tabs.ClaimTab:Toggle({
    Title = "💰 Auto Collect Money",
    Desc = "Automatically collect money from islands",
    Value = false,
    Callback = function(state)
        if state then
            AutoClaim.startAutoClaim()
        else
            AutoClaim.stopAutoClaim()
        end
        WindUI:Notify({ Title = "💰 Auto Claim", Content = state and "Started!" or "Stopped", Duration = 3 })
    end
})

local autoClaimDelaySlider = Tabs.ClaimTab:Slider({
    Title = "⏰ Claim Speed",
    Desc = "How fast to collect money (lower = faster)",
    Value = {
        Min = 0,
        Max = 1000,
        Default = 100,
    },
    Callback = function(value)
        AutoClaim.setClaimDelay(math.clamp((tonumber(value) or 100) / 1000, 0, 2))
    end
})

-- Auto Hatch Tab
local autoHatchToggle = Tabs.HatchTab:Toggle({
    Title = "⚡ Auto Hatch Eggs",
    Desc = "Automatically hatch eggs when they're ready",
    Value = false,
    Callback = function(state)
        if state then
            AutoHatch.startAutoHatch()
        else
            AutoHatch.stopAutoHatch()
        end
        WindUI:Notify({ Title = "⚡ Auto Hatch", Content = state and "Started!" or "Stopped", Duration = 3 })
    end
})

-- Auto Place Tab
local autoPlaceToggle = Tabs.PlaceTab:Toggle({
    Title = "🏠 Auto Place Pets",
    Desc = "Automatically place pets on available tiles",
    Value = false,
    Callback = function(state)
        if state then
            AutoPlace.startAutoPlace()
        else
            AutoPlace.stopAutoPlace()
        end
        WindUI:Notify({ Title = "🏠 Auto Place", Content = state and "Started!" or "Stopped", Duration = 3 })
    end
})

local autoDeleteToggle = Tabs.PlaceTab:Toggle({
    Title = "🗑️ Auto Delete Low Pets",
    Desc = "Automatically delete pets below speed threshold",
    Value = false,
    Callback = function(state)
        if state then
            AutoPlace.startAutoDelete()
        else
            AutoPlace.stopAutoDelete()
        end
        WindUI:Notify({ Title = "🗑️ Auto Delete", Content = state and "Started!" or "Stopped", Duration = 3 })
    end
})

local autoDeleteSpeedSlider = Tabs.PlaceTab:Input({
    Title = "Speed Threshold",
    Desc = "Delete pets with speed below this value (supports K, M, B, T suffixes)",
    Value = "100",
    Callback = function(value)
        AutoPlace.setDeleteThreshold(value)
    end
})

-- Auto Shop Tab
local autoUpgradeToggle = Tabs.ShopTab:Toggle({
    Title = "🛒 Auto Upgrade",
    Desc = "Automatically purchase upgrades in shop",
    Value = false,
    Callback = function(state)
        if state then
            AutoShop.startAutoUpgrade()
        else
            AutoShop.stopAutoUpgrade()
        end
        WindUI:Notify({ Title = "🛒 Auto Upgrade", Content = state and "Started!" or "Stopped", Duration = 3 })
    end
})

-- Auto Packs Tab
local autoPacksToggle = Tabs.PackTab:Toggle({
    Title = "🎁 Auto Claim Packs",
    Desc = "Automatically claim available packs",
    Value = false,
    Callback = function(state)
        if state then
            AutoPacks.startAutoPacks()
        else
            AutoPacks.stopAutoPacks()
        end
        WindUI:Notify({ Title = "🎁 Auto Packs", Content = state and "Started!" or "Stopped", Duration = 3 })
    end
})

-- Set UI elements in modules
AutoClaim.setToggle(autoClaimToggle)
AutoClaim.setSlider(autoClaimDelaySlider)
AutoHatch.setToggle(autoHatchToggle)
AutoPlace.setToggle(autoPlaceToggle)
AutoShop.setToggle(autoUpgradeToggle)
AutoPacks.setToggle(autoPacksToggle)

-- Create placeholder for other systems
Tabs.AutoTab:Button({
    Title = "🥚 Open Egg Selection UI",
    Desc = "Open the modern glass-style egg selection interface",
    Callback = function()
        WindUI:Notify({ Title = "🚧 Coming Soon", Content = "Egg selection UI will be added in next update!", Duration = 3 })
    end
})

-- Auto Feed Tab
autoFeedToggle = Tabs.FeedTab:Toggle({
    Title = "🍽️ Auto Feed Pets",
    Desc = "Automatically feed Big Pets with selected fruits when they're hungry",
    Value = false,
    Callback = function(state)
        autoFeedEnabled = state
        WindUI:Notify({ Title = "🍽️ Auto Feed", Content = state and "Started!" or "Stopped", Duration = 3 })
    end
})

-- Anti-AFK System
local antiAFKEnabled = false
local antiAFKConnection = nil

local function setupAntiAFK()
    if antiAFKEnabled then return end
    antiAFKEnabled = true
    antiAFKConnection = game:GetService("Players").LocalPlayer.Idled:Connect(function()
        game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
    WindUI:Notify({ Title = "🛡️ Anti-AFK", Content = "Anti-AFK activated!", Duration = 3 })
end

local function disableAntiAFK()
    if not antiAFKEnabled then return end
    antiAFKEnabled = false
    if antiAFKConnection then
        antiAFKConnection:Disconnect()
        antiAFKConnection = nil
    end
    WindUI:Notify({ Title = "🛡️ Anti-AFK", Content = "Anti-AFK deactivated.", Duration = 3 })
end

-- Save Settings Tab
Tabs.SaveTab:Section({ Title = "💾 Save & Load", Icon = "save" })

Tabs.SaveTab:Paragraph({
    Title = "💾 Settings Manager",
    Desc = "Save your current settings to remember them next time you use the script!",
    Image = "save",
    ImageSize = 18,
})

Tabs.SaveTab:Button({
    Title = "💾 Save All Settings",
    Desc = "Save all your current settings",
    Callback = function()
        Settings.saveAllSettings()
        WindUI:Notify({ Title = "💾 Settings", Content = "All settings saved!", Duration = 3 })
    end
})

Tabs.SaveTab:Button({
    Title = "📂 Load All Settings",
    Desc = "Load your saved settings",
    Callback = function()
        Settings.loadAllSettings()
        WindUI:Notify({ Title = "📂 Settings", Content = "Settings loaded!", Duration = 3 })
    end
})

Tabs.SaveTab:Button({
    Title = "🛡️ Toggle Anti-AFK",
    Desc = "Enable or disable the built-in anti-AFK system",
    Callback = function()
        if Settings.isAntiAFKEnabled() then
            Settings.disableAntiAFK()
        else
            Settings.setupAntiAFK()
        end
    end
})

-- Config Manager
local ConfigManagerUI = Window.ConfigManager
local zebuxConfig = ConfigManagerUI:CreateConfig("zebuxConfig")

-- Register UI elements
local function registerUIElements()
    local autoClaimElements = AutoClaim.GetUIElements()
    local autoHatchElements = AutoHatch.GetUIElements()
    
    if autoClaimElements.autoClaimToggle then
        zebuxConfig:Register("autoClaimToggle", autoClaimElements.autoClaimToggle)
    end
    if autoClaimElements.autoClaimDelaySlider then
        zebuxConfig:Register("autoClaimDelaySlider", autoClaimElements.autoClaimDelaySlider)
    end
    if autoHatchElements.autoHatchToggle then
        zebuxConfig:Register("autoHatchToggle", autoHatchElements.autoHatchToggle)
    end
    if autoFeedToggle then
        zebuxConfig:Register("autoFeedToggle", autoFeedToggle)
    end
end

Tabs.SaveTab:Button({
    Title = "💾 Manual Save",
    Desc = "Manually save all your current settings",
    Callback = function()
        zebuxConfig:Save()
        WindUI:Notify({ 
            Title = "💾 Settings Saved", 
            Content = "All your settings have been saved! 🎉", 
            Duration = 3 
        })
    end
})

Tabs.SaveTab:Button({
    Title = "📂 Manual Load",
    Desc = "Manually load your saved settings",
    Callback = function()
        zebuxConfig:Load()
        WindUI:Notify({ 
            Title = "📂 Settings Loaded", 
            Content = "Your settings have been loaded! 🎉", 
            Duration = 3 
        })
    end
})

-- Initialize everything
task.spawn(function()
    -- Register UI elements with config system
    zebuxConfig:Register("autoClaimToggle", autoClaimToggle)
    zebuxConfig:Register("autoClaimDelaySlider", autoClaimDelaySlider)
    zebuxConfig:Register("autoHatchToggle", autoHatchToggle)
    zebuxConfig:Register("autoPlaceToggle", autoPlaceToggle)
    zebuxConfig:Register("autoDeleteToggle", autoDeleteToggle)
    zebuxConfig:Register("autoUpgradeToggle", autoUpgradeToggle)
    zebuxConfig:Register("autoPacksToggle", autoPacksToggle)
    
    -- Load WindUI config settings
    zebuxConfig:Load()
    
    -- Load module-specific settings
    Settings.loadAllSettings()
    
    WindUI:Notify({ 
        Title = "📂 Auto-Load Complete", 
        Content = "Your saved settings have been loaded! 🎉", 
        Duration = 3 
    })
    
    Settings.setSettingsLoaded(true)
end)
task.spawn(function()
    task.wait(3) -- Wait for UI to fully load
    
    WindUI:Notify({ 
        Title = "📂 Loading Settings", 
        Content = "Loading your saved settings...", 
        Duration = 2 
    })
    
    -- Register all UI elements
    registerUIElements()
    
    -- Load settings
    zebuxConfig:Load()
    
    WindUI:Notify({ 
        Title = "📂 Auto-Load Complete", 
        Content = "Your saved settings have been loaded! 🎉", 
        Duration = 3 
    })
    
    -- Mark settings as loaded
    settingsLoaded = true
    _G.ZebuxSettingsLoaded = true
end)

-- Close callback
Window:OnClose(function()
    -- Cleanup all modules
    AutoClaim.Cleanup()
    AutoHatch.Cleanup()
    
    if AutoFishSystem and AutoFishSystem.Cleanup then
        AutoFishSystem.Cleanup()
    end
    
    disableAntiAFK()
end)

WindUI:Notify({ 
    Title = "🎉 Build A Zoo Loaded", 
    Content = "Welcome to Build A Zoo! All systems ready!", 
    Duration = 5 
})
