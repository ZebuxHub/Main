-- AntiAFKSystem.lua - GitHub-loaded Anti-AFK System
-- Author: Zebux
-- Version: 1.0

local AntiAFKSystem = {}

-- Services
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

-- State variables
local isEnabled = false
local connection = nil
local LocalPlayer = Players.LocalPlayer

-- Initialize the Anti-AFK system
function AntiAFKSystem.Init(config)
    config = config or {}
    
    -- Delete the game's LocalAntiAFK script if it exists
    local success, err = pcall(function()
        local playerScripts = LocalPlayer:WaitForChild("PlayerScripts", 5)
        
        if playerScripts then
            -- Try common locations where LocalAntiAFK might be
            local possiblePaths = {
                playerScripts:FindFirstChild("Game"),
                playerScripts:FindFirstChild("LocalAntiAFK"),
                playerScripts
            }
            
            for _, parent in ipairs(possiblePaths) do
                if parent then
                    local localAntiAFK = parent:FindFirstChild("LocalAntiAFK")
                    if localAntiAFK then
                        localAntiAFK:Destroy()
                        print("[AntiAFK] Removed game's LocalAntiAFK script")
                        break
                    end
                end
            end
        end
    end)
    
    if not success then
        warn("Failed to delete LocalAntiAFK: " .. tostring(err))
    end
    
    -- Auto-start if requested
    if config.autoStart then
        AntiAFKSystem.Enable()
    end
    
    return true
end

-- Enable Anti-AFK
function AntiAFKSystem.Enable()
    if isEnabled then return end
    
    isEnabled = true
    connection = LocalPlayer.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
    
    print("[AntiAFK] System enabled")
end

-- Disable Anti-AFK
function AntiAFKSystem.Disable()
    if not isEnabled then return end
    
    isEnabled = false
    if connection then
        connection:Disconnect()
        connection = nil
    end
    
    print("[AntiAFK] System disabled")
end

-- Get current status
function AntiAFKSystem.GetStatus()
    return isEnabled
end

-- Cleanup function
function AntiAFKSystem.Cleanup()
    AntiAFKSystem.Disable()
end

return AntiAFKSystem
