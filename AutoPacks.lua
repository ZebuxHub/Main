-- AutoPacks.lua - Auto Pack Claiming System for Build A Zoo
-- Author: Zebux

local AutoPacks = {}
local Core = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/Core.lua"))()

-- Auto state variables
local autoPacksEnabled = false
local autoPacksThread = nil

-- UI elements (to be set by main script)
local autoPacksToggle = nil

-- Function to claim available packs
local function claimPacks()
    if not autoPacksEnabled then return end
    
    local success, err = pcall(function()
        local playerGUI = Core.LocalPlayer:WaitForChild("PlayerGui")
        
        -- Look for pack claim buttons
        local packGUIs = {
            playerGUI:FindFirstChild("PackGUI"),
            playerGUI:FindFirstChild("RewardGUI"),
            playerGUI:FindFirstChild("ClaimGUI")
        }
        
        for _, gui in ipairs(packGUIs) do
            if gui then
                local claimButtons = gui:GetDescendants()
                for _, button in ipairs(claimButtons) do
                    if button:IsA("TextButton") and 
                       (string.find(string.lower(button.Text), "claim") or
                        string.find(string.lower(button.Text), "collect") or
                        string.find(string.lower(button.Text), "get")) then
                        
                        -- Check if button is enabled/visible
                        if button.Visible and button.Active then
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
                            
                            task.wait(0.5) -- Wait between claims
                        end
                    end
                end
            end
        end
    end)
    
    if not success then
        warn("Auto Packs error: " .. tostring(err))
    end
end

function AutoPacks.startAutoPacks()
    if autoPacksThread then return end
    
    autoPacksEnabled = true
    autoPacksThread = task.spawn(function()
        while autoPacksEnabled do
            claimPacks()
            task.wait(5) -- Check every 5 seconds
        end
    end)
end

function AutoPacks.stopAutoPacks()
    autoPacksEnabled = false
    if autoPacksThread then
        task.cancel(autoPacksThread)
        autoPacksThread = nil
    end
end

-- Setters for UI elements
function AutoPacks.setToggle(toggle)
    autoPacksToggle = toggle
end

-- Getters
function AutoPacks.isEnabled()
    return autoPacksEnabled
end

return AutoPacks
