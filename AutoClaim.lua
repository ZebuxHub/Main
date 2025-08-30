-- AutoClaim.lua - Auto Money Collection System for Build A Zoo
-- Author: Zebux

local AutoClaim = {}
local Core = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/Core.lua"))()

-- Auto state variables
local autoClaimEnabled = false
local autoClaimThread = nil
local autoClaimDelay = 0.1 -- seconds between claims

-- UI elements (to be set by main script)
local autoClaimToggle = nil
local autoClaimDelaySlider = nil

-- Load auto claim delay from file
local function loadAutoClaimDelay()
    local delaySuccess, delayData = pcall(function()
        if isfile("Zebux_ClaimSettings.json") then
            local jsonData = readfile("Zebux_ClaimSettings.json")
            return game:GetService("HttpService"):JSONDecode(jsonData)
        end
    end)
    
    if delaySuccess and delayData and delayData.autoClaimDelay then
        autoClaimDelay = delayData.autoClaimDelay
    end
end

-- Save auto claim delay to file
local function saveAutoClaimDelay()
    pcall(function()
        local delayData = {
            autoClaimDelay = autoClaimDelay
        }
        writefile("Zebux_ClaimSettings.json", game:GetService("HttpService"):JSONEncode(delayData))
    end)
end

-- Get owned pet names from PlayerGui
local function getOwnedPetNames()
    local names = {}
    local playerGui = Core.LocalPlayer and Core.LocalPlayer:FindFirstChild("PlayerGui")
    local data = playerGui and playerGui:FindFirstChild("Data")
    local petsContainer = data and data:FindFirstChild("Pets")
    if petsContainer then
        for _, child in ipairs(petsContainer:GetChildren()) do
            -- Assume children under Data.Pets are ValueBase instances or folders named as pet names
            local n
            if child:IsA("ValueBase") then
                n = tostring(child.Value)
            else
                n = tostring(child.Name)
            end
            if n and n ~= "" then
                table.insert(names, n)
            end
        end
    end
    return names
end

-- Claim money from a specific pet
local function claimMoneyForPet(petName)
    if not petName or petName == "" then return false end
    local petsFolder = workspace:FindFirstChild("Pets")
    if not petsFolder then return false end
    local petModel = petsFolder:FindFirstChild(petName)
    if not petModel then return false end
    local root = petModel:FindFirstChild("RootPart")
    if not root then return false end
    local re = root:FindFirstChild("RE")
    if not re or not re.FireServer then return false end
    local ok, err = pcall(function()
        re:FireServer("Claim")
    end)
    if not ok then warn("Claim failed for pet " .. tostring(petName) .. ": " .. tostring(err)) end
    return ok
end

-- Main auto claim function
local function runAutoClaim()
    while autoClaimEnabled do
        local ok, err = pcall(function()
            local names = getOwnedPetNames()
            if #names == 0 then task.wait(0.8) return end
            for _, n in ipairs(names) do
                claimMoneyForPet(n)
                task.wait(autoClaimDelay)
            end
        end)
        if not ok then
            warn("Auto Claim error: " .. tostring(err))
            task.wait(1)
        end
    end
end

-- Create UI elements
function AutoClaim.CreateUI(WindUI, Tabs)
    autoClaimToggle = Tabs.ClaimTab:Toggle({
        Title = "💰 Auto Get Money",
        Desc = "Automatically collects money from your pets",
        Value = false,
        Callback = function(state)
            autoClaimEnabled = state
            
            Core.waitForSettingsReady(0.2)
            if state and not autoClaimThread then
                autoClaimThread = task.spawn(function()
                    runAutoClaim()
                    autoClaimThread = nil
                end)
                WindUI:Notify({ Title = "💰 Auto Claim", Content = "Started collecting money! 🎉", Duration = 3 })
            elseif (not state) and autoClaimThread then
                WindUI:Notify({ Title = "💰 Auto Claim", Content = "Stopped", Duration = 3 })
            end
        end
    })

    autoClaimDelaySlider = Tabs.ClaimTab:Slider({
        Title = "⏰ Claim Speed",
        Desc = "How fast to collect money (lower = faster)",
        Value = {
            Min = 0,
            Max = 1000,
            Default = 100,
        },
        Callback = function(value)
            autoClaimDelay = math.clamp((tonumber(value) or 100) / 1000, 0, 2)
            -- Auto-save delay when changed
            saveAutoClaimDelay()
        end
    })

    Tabs.ClaimTab:Button({
        Title = "💰 Get All Money Now",
        Desc = "Collect money from all pets right now",
        Callback = function()
            local names = getOwnedPetNames()
            if #names == 0 then
                WindUI:Notify({ Title = "💰 Auto Claim", Content = "No pets found", Duration = 3 })
                return
            end
            local count = 0
            for _, n in ipairs(names) do
                if claimMoneyForPet(n) then count += 1 end
                task.wait(0.05)
            end
            WindUI:Notify({ Title = "💰 Auto Claim", Content = string.format("Got money from %d pets! 🎉", count), Duration = 3 })
        end
    })
end

-- Get UI elements for config registration
function AutoClaim.GetUIElements()
    return {
        autoClaimToggle = autoClaimToggle,
        autoClaimDelaySlider = autoClaimDelaySlider
    }
end

-- Initialize the module
function AutoClaim.Init()
    loadAutoClaimDelay()
end

-- Cleanup function
function AutoClaim.Cleanup()
    autoClaimEnabled = false
    if autoClaimThread then
        task.cancel(autoClaimThread)
        autoClaimThread = nil
    end
end

return AutoClaim
