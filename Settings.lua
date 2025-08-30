-- Settings.lua - Settings Management System for Build A Zoo
-- Author: Zebux

local Settings = {}
local Core = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/Core.lua"))()

-- Settings storage
local allSettings = {}
local settingsLoaded = false

-- Anti-AFK system
local antiAFKEnabled = false
local antiAFKConnection = nil

-- Function to save all settings (WindUI config + custom selections)
function Settings.saveAllSettings()
    -- Save WindUI config for simple UI elements
    if zebuxConfig then
        local saveSuccess, saveErr = pcall(function()
            zebuxConfig:Save()
        end)
        
        if not saveSuccess then
            warn("Failed to save WindUI config: " .. tostring(saveErr))
        end
    end
    
    -- Save auto claim delay specifically
    pcall(function()
        local delayData = {
            autoClaimDelay = autoClaimDelay
        }
        writefile("Zebux_ClaimSettings.json", game:GetService("HttpService"):JSONEncode(delayData))
    end)
    
    -- Save custom UI selections
    Settings.saveCustomSelections()
end

-- Function to load all saved settings before any function starts
function Settings.loadAllSettings()
    -- Load WindUI config for simple UI elements
    if zebuxConfig then
        local loadSuccess, loadErr = pcall(function()
            zebuxConfig:Load()
        end)
        
        if not loadSuccess then
            warn("Failed to load WindUI config: " .. tostring(loadErr))
        end
    end
    
    -- Load auto claim delay specifically
    local delaySuccess, delayData = pcall(function()
        if isfile("Zebux_ClaimSettings.json") then
            local jsonData = readfile("Zebux_ClaimSettings.json")
            return game:GetService("HttpService"):JSONDecode(jsonData)
        end
    end)
    
    if delaySuccess and delayData and delayData.autoClaimDelay then
        autoClaimDelay = delayData.autoClaimDelay
        if autoClaimDelaySlider then
            autoClaimDelaySlider:SetValue(autoClaimDelay * 1000) -- Convert back to slider scale
        end
    end
    
    -- Load custom UI selections
    Settings.loadCustomSelections()
end

-- Custom selection saving/loading functions
function Settings.saveCustomSelections()
    local selectionsToSave = {}
    
    -- Collect all selection data
    if eggDropdown then
        selectionsToSave.eggs = Settings.getDropdownValue(eggDropdown)
    end
    if mutationDropdown then
        selectionsToSave.mutations = Settings.getDropdownValue(mutationDropdown)
    end
    if placeEggDropdown then
        selectionsToSave.placeEggs = Settings.getDropdownValue(placeEggDropdown)
    end
    if placeMutationDropdown then
        selectionsToSave.placeMutations = Settings.getDropdownValue(placeMutationDropdown)
    end
    
    -- Save to file
    local success, err = pcall(function()
        local jsonData = game:GetService("HttpService"):JSONEncode(selectionsToSave)
        writefile("Zebux_Selections.json", jsonData)
    end)
    
    if not success then
        warn("Failed to save custom selections: " .. tostring(err))
    end
end

function Settings.loadCustomSelections()
    local success, selections = pcall(function()
        if isfile("Zebux_Selections.json") then
            local jsonData = readfile("Zebux_Selections.json")
            return game:GetService("HttpService"):JSONDecode(jsonData)
        end
    end)
    
    if success and selections then
        -- Restore dropdown selections
        if selections.eggs and eggDropdown then
            Settings.setDropdownValue(eggDropdown, selections.eggs)
        end
        if selections.mutations and mutationDropdown then
            Settings.setDropdownValue(mutationDropdown, selections.mutations)
        end
        if selections.placeEggs and placeEggDropdown then
            Settings.setDropdownValue(placeEggDropdown, selections.placeEggs)
        end
        if selections.placeMutations and placeMutationDropdown then
            Settings.setDropdownValue(placeMutationDropdown, selections.placeMutations)
        end
    end
end

-- Helper functions for dropdown management
function Settings.getDropdownValue(dropdown)
    if not dropdown then return {} end
    -- Try common getter patterns
    local candidates = {
        dropdown.Value,
        dropdown.Selected,
        dropdown.Current,
        dropdown.Selection
    }
    
    for _, candidate in ipairs(candidates) do
        if candidate and type(candidate) == "table" then
            return candidate
        end
    end
    return {}
end

function Settings.setDropdownValue(dropdown, value)
    if not dropdown or not value then return end
    
    -- Try common setter patterns
    local setters = {
        function() dropdown:SetValue(value) end,
        function() dropdown:Set(value) end,
        function() dropdown.Value = value end,
        function() dropdown.Selected = value end
    }
    
    for _, setter in ipairs(setters) do
        local success = pcall(setter)
        if success then break end
    end
end

-- Anti-AFK system
function Settings.setupAntiAFK()
    if antiAFKConnection then return end
    
    antiAFKEnabled = true
    antiAFKConnection = game:GetService("UserInputService").InputBegan:Connect(function() end)
    
    -- Simple movement anti-AFK
    task.spawn(function()
        while antiAFKEnabled do
            if Core.LocalPlayer.Character and Core.LocalPlayer.Character:FindFirstChild("Humanoid") then
                local humanoid = Core.LocalPlayer.Character.Humanoid
                humanoid:Move(Vector3.new(0, 0, 0), true)
            end
            task.wait(60) -- Every minute
        end
    end)
    
    print("🛡️ Anti-AFK system enabled")
end

function Settings.disableAntiAFK()
    antiAFKEnabled = false
    if antiAFKConnection then
        antiAFKConnection:Disconnect()
        antiAFKConnection = nil
    end
    print("🛡️ Anti-AFK system disabled")
end

function Settings.isAntiAFKEnabled()
    return antiAFKEnabled
end

function Settings.isSettingsLoaded()
    return settingsLoaded
end

function Settings.setSettingsLoaded(loaded)
    settingsLoaded = loaded
end

return Settings
