-- AutoShop.lua - Auto Shop and Upgrading System for Build A Zoo
-- Author: Zebux

local AutoShop = {}
local Core = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/Core.lua"))()

-- Auto state variables
local autoUpgradeEnabled = false
local autoUpgradeThread = nil

-- UI elements (to be set by main script)
local autoUpgradeToggle = nil

-- Auto Upgrade Functions
local function performAutoUpgrade()
    if not autoUpgradeEnabled then return end
    
    local success, err = pcall(function()
        -- Find upgrade buttons in the shop
        local playerGUI = Core.LocalPlayer:WaitForChild("PlayerGui")
        local shopGUI = playerGUI:FindFirstChild("ShopGUI")
        
        if shopGUI then
            -- Look for upgrade buttons and click them
            local upgradeButtons = shopGUI:GetDescendants()
            for _, button in ipairs(upgradeButtons) do
                if button:IsA("TextButton") and 
                   (string.find(string.lower(button.Text), "upgrade") or 
                    string.find(string.lower(button.Text), "buy")) then
                    
                    -- Simulate button click
                    Core.VirtualInputManager:SendMouseButtonEvent(
                        button.AbsolutePosition.X + button.AbsoluteSize.X/2,
                        button.AbsolutePosition.Y + button.AbsoluteSize.Y/2,
                        0, true, game, 0
                    )
                    task.wait(0.1)
                    Core.VirtualInputManager:SendMouseButtonEvent(
                        button.AbsolutePosition.X + button.AbsoluteSize.X/2,
                        button.AbsolutePosition.Y + button.AbsoluteSize.Y/2,
                        0, false, game, 0
                    )
                    
                    task.wait(0.5) -- Wait between upgrades
                end
            end
        end
    end)
    
    if not success then
        warn("Auto Upgrade error: " .. tostring(err))
    end
end

function AutoShop.startAutoUpgrade()
    if autoUpgradeThread then return end
    
    autoUpgradeEnabled = true
    autoUpgradeThread = task.spawn(function()
        while autoUpgradeEnabled do
            performAutoUpgrade()
            task.wait(2) -- Check every 2 seconds
        end
    end)
end

function AutoShop.stopAutoUpgrade()
    autoUpgradeEnabled = false
    if autoUpgradeThread then
        task.cancel(autoUpgradeThread)
        autoUpgradeThread = nil
    end
end

-- Setters for UI elements
function AutoShop.setToggle(toggle)
    autoUpgradeToggle = toggle
end

-- Getters
function AutoShop.isEnabled()
    return autoUpgradeEnabled
end

return AutoShop
