-- AutoFishSystem.lua - Auto Fishing System for Build A Zoo
-- Author: Zebux
-- Version: 1.0

local AutoFishSystem = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

-- Module variables
local WindUI = nil
local Tabs = nil
local Config = nil

-- Configuration
local FishingConfig = {
    SelectedBait = "FishingBait1",
    FishingPosition = Vector3.new(0, 0, 0),
    AutoFishEnabled = false,
    DelayBetweenCasts = 2,
    AutoWaterDetection = false,
    SearchRadius = 100,
    PositionSetting = false,
    MouseTracking = false,
    Stats = {
        FishCaught = 0,
        SessionStartTime = os.time(),
        LastCatchTime = 0,
        TotalCasts = 0,
        SuccessfulCasts = 0
    }
}

-- Fishing Bait Configuration
local FishingBaitConfig = {}
local AvailableBaits = {}

local function loadFishingBaitConfig()
    local success, result = pcall(function()
        local configFolder = ReplicatedStorage:WaitForChild("Config", 5)
        if configFolder then
            local baitModule = configFolder:FindFirstChild("ResFishingBait")
            if baitModule then
                return require(baitModule)
            end
        end
        return nil
    end)
    
    if success and result then
        FishingBaitConfig = result
        -- Build available baits list
        AvailableBaits = {}
        for id, data in pairs(FishingBaitConfig) do
            if type(id) == "string" and not id:match("^_") and id ~= "__index" then
                table.insert(AvailableBaits, id)
            end
        end
        table.sort(AvailableBaits)
        print("🎣 Loaded " .. #AvailableBaits .. " fishing baits")
    else
        -- Fallback baits
        AvailableBaits = {"FishingBait1", "FishingBait2", "FishingBait3"}
        print("⚠️ Failed to load fishing bait config, using fallback baits")
    end
end

-- Water Detection System
local WaterDetection = {
    WaterNames = {"Water", "Lake", "Pond", "River", "Stream", "Ocean", "Sea"},
    CurrentTarget = nil,
    MovingToWater = false
}

local function isWaterPart(part)
    if not part then return false end
    
    local name = part.Name:lower()
    for _, waterName in ipairs(WaterDetection.WaterNames) do
        if name:find(waterName:lower()) then
            return true
        end
    end
    
    -- Check material for water-like materials
    if part.Material == Enum.Material.Water then
        return true
    end
    
    -- Check transparency and color for water-like appearance
    if part.Transparency > 0.3 and part.BrickColor.Name == "Bright blue" then
        return true
    end
    
    return false
end

local function findNearestWater()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    
    local playerPosition = LocalPlayer.Character.HumanoidRootPart.Position
    local nearestWater = nil
    local shortestDistance = FishingConfig.SearchRadius
    
    -- Search for water parts in workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and isWaterPart(obj) then
            local distance = (obj.Position - playerPosition).Magnitude
            if distance < shortestDistance then
                nearestWater = obj
                shortestDistance = distance
            end
        end
    end
    
    return nearestWater, shortestDistance
end

local function moveToWater(waterPart)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Humanoid") then
        return false
    end
    
    local humanoid = LocalPlayer.Character.Humanoid
    local humanoidRootPart = LocalPlayer.Character.HumanoidRootPart
    
    if not waterPart then
        return false
    end
    
    WaterDetection.MovingToWater = true
    WaterDetection.CurrentTarget = waterPart
    
    -- Calculate position near the water (slightly offset to avoid going into water)
    local targetPosition = waterPart.Position + Vector3.new(0, waterPart.Size.Y/2 + 3, 0)
    
    -- Use pathfinding for smart movement
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentMaxSlope = 45
    })
    
    local success, errorMessage = pcall(function()
        path:ComputeAsync(humanoidRootPart.Position, targetPosition)
    end)
    
    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        
        for i, waypoint in ipairs(waypoints) do
            if not WaterDetection.MovingToWater then break end
            
            humanoid:MoveTo(waypoint.Position)
            
            -- Wait for the character to reach the waypoint
            local connection
            local reached = false
            
            connection = humanoid.MoveToFinished:Connect(function(reachedWaypoint)
                reached = true
                connection:Disconnect()
            end)
            
            -- Timeout after 10 seconds per waypoint
            local timeout = 0
            while not reached and WaterDetection.MovingToWater and timeout < 100 do
                task.wait(0.1)
                timeout = timeout + 1
            end
            
            if connection then
                connection:Disconnect()
            end
        end
        
        -- Update fishing position to current location
        if WaterDetection.MovingToWater then
            FishingConfig.FishingPosition = humanoidRootPart.Position
            WindUI:Notify({ 
                Title = "🌊 Water Found", 
                Content = string.format("Moved to water! Distance: %.1fm", (targetPosition - humanoidRootPart.Position).Magnitude), 
                Duration = 3 
            })
        end
    else
        -- Fallback: direct movement
        humanoid:MoveTo(targetPosition)
        
        local connection
        local reached = false
        
        connection = humanoid.MoveToFinished:Connect(function(reachedTarget)
            reached = true
            FishingConfig.FishingPosition = humanoidRootPart.Position
            connection:Disconnect()
            WindUI:Notify({ 
                Title = "🌊 Water Found", 
                Content = "Moved to water location!", 
                Duration = 3 
            })
        end)
        
        -- Timeout after 15 seconds
        task.delay(15, function()
            if connection then
                connection:Disconnect()
            end
        end)
    end
    
    WaterDetection.MovingToWater = false
    return true
end

local function autoDetectAndMoveToWater()
    if not FishingConfig.AutoWaterDetection then
        return true -- Skip if auto detection is disabled
    end
    
    WindUI:Notify({ 
        Title = "🔍 Water Detection", 
        Content = "Searching for nearby water...", 
        Duration = 2 
    })
    
    local waterPart, distance = findNearestWater()
    
    if waterPart then
        WindUI:Notify({ 
            Title = "🌊 Water Found", 
            Content = string.format("Found water %.1fm away. Moving...", distance), 
            Duration = 3 
        })
        return moveToWater(waterPart)
    else
        WindUI:Notify({ 
            Title = "❌ No Water Found", 
            Content = string.format("No water found within %dm. Using current position.", FishingConfig.SearchRadius), 
            Duration = 4 
        })
        return false
    end
end

-- Mouse Position Tracking System
local MouseTracker = {
    Connection = nil,
    GuiConnection = nil,
    ClickConnection = nil,
    PositionLabel = nil
}

local function getMouseWorldPosition()
    local mouse = LocalPlayer:GetMouse()
    local unitRay = Camera:ScreenPointToRay(mouse.X, mouse.Y)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
    
    if raycastResult then
        return raycastResult.Position
    else
        -- Fallback to a position in front of the camera
        return unitRay.Origin + unitRay.Direction * 100
    end
end

local function startMouseTracking()
    if MouseTracker.Connection then
        MouseTracker.Connection:Disconnect()
    end
    
    FishingConfig.MouseTracking = true
    FishingConfig.PositionSetting = true
    
    -- Create position display
    local mouse = LocalPlayer:GetMouse()
    
    MouseTracker.Connection = mouse.Move:Connect(function()
        if FishingConfig.PositionSetting and FishingConfig.MouseTracking then
            local worldPos = getMouseWorldPosition()
            if MouseTracker.PositionLabel then
                MouseTracker.PositionLabel:SetDesc(string.format("Mouse Position: %.1f, %.1f, %.1f\nClick to set fishing position!", 
                    worldPos.X, worldPos.Y, worldPos.Z))
            end
        end
    end)
    
    MouseTracker.ClickConnection = mouse.Button1Down:Connect(function()
        if FishingConfig.PositionSetting and FishingConfig.MouseTracking then
            local worldPos = getMouseWorldPosition()
            
            -- Save the position to FishingConfig
            FishingConfig.FishingPosition = Vector3.new(worldPos.X, worldPos.Y, worldPos.Z)
            
            -- Update current position display
            updateCurrentPositionDisplay()
            
            -- Debug print to confirm position is saved
            print("🎣 Position saved:", FishingConfig.FishingPosition)
            
            WindUI:Notify({ 
                Title = "📍 Position Set", 
                Content = string.format("Fishing position set to: %.1f, %.1f, %.1f", 
                    FishingConfig.FishingPosition.X, FishingConfig.FishingPosition.Y, FishingConfig.FishingPosition.Z), 
                Duration = 3 
            })
            
            -- Stop tracking
            stopMouseTracking()
        end
    end)
    
    WindUI:Notify({ 
        Title = "🖱️ Mouse Tracking", 
        Content = "Move mouse and click to set fishing position!", 
        Duration = 3 
    })
end

local function stopMouseTracking()
    FishingConfig.MouseTracking = false
    FishingConfig.PositionSetting = false
    
    if MouseTracker.Connection then
        MouseTracker.Connection:Disconnect()
        MouseTracker.Connection = nil
    end
    
    if MouseTracker.ClickConnection then
        MouseTracker.ClickConnection:Disconnect()
        MouseTracker.ClickConnection = nil
    end
    
    if MouseTracker.PositionLabel then
        MouseTracker.PositionLabel:SetDesc("Click 'Set Position by Click' to start tracking")
    end
end

-- Fishing System
local FishingSystem = {
    Active = false,
    Thread = nil
}

local function startFishing()
    -- First fire Focus + FishRob
    local args = {
        "Focus",
        "FishRob"
    }
    
    local success, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    if not success then
        warn("Failed to focus fishing: " .. tostring(err))
        return false
    end
    
    -- Increased wait time for better accuracy
    task.wait(1)
    
    -- Debug print to verify position is being used
    print("🎣 Using fishing position:", FishingConfig.FishingPosition)
    
    local throwArgs = {
        "Throw",
        {
            Bait = FishingConfig.SelectedBait,
            Pos = FishingConfig.FishingPosition
        }
    }
    
    local throwSuccess, throwErr = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer(unpack(throwArgs))
    end)
    
    if not throwSuccess then
        warn("Failed to throw fishing line: " .. tostring(throwErr))
        return false
    end
    
    FishingConfig.Stats.TotalCasts = FishingConfig.Stats.TotalCasts + 1
    return true
end

local function pullFish()
    local args = {
        "POUT",
        {
            SUC = 1
        }
    }
    
    local success, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer(unpack(args))
    end)
    
    if not success then
        warn("Failed to pull fish: " .. tostring(err))
        return false
    end
    
    FishingConfig.Stats.FishCaught = FishingConfig.Stats.FishCaught + 1
    FishingConfig.Stats.SuccessfulCasts = FishingConfig.Stats.SuccessfulCasts + 1
    FishingConfig.Stats.LastCatchTime = os.time()
    
    return true
end

local function waitForFishPull()
    local zif = workspace:FindFirstChild("zif_025")
    if not zif then
        warn("zif_025 not found in workspace")
        return false
    end
    
    local timeout = 30 -- Increased timeout for better accuracy
    local startTime = tick()
    
    -- Wait for AnimFish attribute to be "Pull" with slower checking for accuracy
    while FishingConfig.AutoFishEnabled and (tick() - startTime) < timeout do
        local animFish = zif:GetAttribute("AnimFish")
        if animFish == "Pull" then
            return true
        end
        task.wait(0.2) -- Slower checking interval for better accuracy
    end
    
    return false
end

local function runAutoFish()
    while FishingConfig.AutoFishEnabled do
        local castStartTime = tick()
        local success = startFishing()
        
        if success then
            -- Wait for the fish to be ready to pull
            if waitForFishPull() then
                if pullFish() then
                    local castTime = tick() - castStartTime
                    WindUI:Notify({ 
                        Title = "🎣 Auto Fish", 
                        Content = string.format("🐟 Caught a fish! (%.1fs)", castTime), 
                        Duration = 2 
                    })
                else
                    WindUI:Notify({ 
                        Title = "🎣 Auto Fish", 
                        Content = "❌ Failed to pull fish", 
                        Duration = 2 
                    })
                end
            else
                WindUI:Notify({ 
                    Title = "🎣 Auto Fish", 
                    Content = "⏰ Fish pull timeout", 
                    Duration = 2 
                })
            end
        else
            WindUI:Notify({ 
                Title = "🎣 Auto Fish", 
                Content = "❌ Failed to start fishing", 
                Duration = 2 
            })
        end
        
        -- Wait before next fishing attempt
        if FishingConfig.AutoFishEnabled then
            task.wait(FishingConfig.DelayBetweenCasts)
        end
    end
end

function FishingSystem.Start()
    if FishingSystem.Active then return end
    
    FishingSystem.Active = true
    FishingConfig.AutoFishEnabled = true
    FishingConfig.Stats.SessionStartTime = os.time()
    
    FishingSystem.Thread = task.spawn(runAutoFish)
    
    WindUI:Notify({ 
        Title = "🎣 Auto Fish", 
        Content = "Started fishing! 🎉", 
        Duration = 3 
    })
end

function FishingSystem.Stop()
    if not FishingSystem.Active then return end
    
    FishingSystem.Active = false
    FishingConfig.AutoFishEnabled = false
    
    -- Stop water detection movement
    WaterDetection.MovingToWater = false
    
    if FishingSystem.Thread then
        task.cancel(FishingSystem.Thread)
        FishingSystem.Thread = nil
    end
    
    local sessionTime = os.time() - FishingConfig.Stats.SessionStartTime
    local sessionMinutes = math.floor(sessionTime / 60)
    WindUI:Notify({ 
        Title = "🎣 Auto Fish", 
        Content = string.format("🛑 Stopped! Session: %dm | Fish: %d", sessionMinutes, FishingConfig.Stats.FishCaught), 
        Duration = 3 
    })
end

-- UI Elements
local baitDropdown = nil
local autoFishToggle = nil
local statsLabel = nil
local currentPosLabel = nil

-- Function to update the current position display
local function updateCurrentPositionDisplay()
    if currentPosLabel then
        currentPosLabel:SetDesc(string.format("X: %.1f, Y: %.1f, Z: %.1f", 
            FishingConfig.FishingPosition.X, 
            FishingConfig.FishingPosition.Y, 
            FishingConfig.FishingPosition.Z))
    end
end

local function updateStats()
    if not statsLabel then return end
    
    local successRate = FishingConfig.Stats.TotalCasts > 0 and 
        math.floor((FishingConfig.Stats.SuccessfulCasts / FishingConfig.Stats.TotalCasts) * 100) or 0
    
    local sessionTime = os.time() - FishingConfig.Stats.SessionStartTime
    local sessionMinutes = math.floor(sessionTime / 60)
    
    local statsText = string.format("🐟 Fish: %d | 🎯 Rate: %d%% | ⏱️ Session: %dm", 
        FishingConfig.Stats.FishCaught, successRate, sessionMinutes)
    
    if statsLabel.SetDesc then
        statsLabel:SetDesc(statsText)
    end
end

-- Initialize function called by main script
function AutoFishSystem.Init(dependencies)
    -- Validate required dependencies
    if not dependencies then
        warn("AutoFishSystem.Init: No dependencies provided")
        return
    end
    
    WindUI = dependencies.WindUI
    Tabs = dependencies.Tabs
    Config = dependencies.Config -- Can be nil
    
    -- Validate critical dependencies
    if not WindUI then
        warn("AutoFishSystem.Init: WindUI is required but not provided")
        return
    end
    
    if not Tabs or not Tabs.FishTab then
        warn("AutoFishSystem.Init: Tabs.FishTab is required but not provided")
        return
    end
    
    -- Load fishing bait configuration
    loadFishingBaitConfig()
    
    -- Create Auto Fish Tab UI
    Tabs.FishTab:Section({ Title = "🎣 Fishing Settings", Icon = "settings" })
    
    -- Bait selection dropdown
    task.wait(1) -- Wait for config to load
    baitDropdown = Tabs.FishTab:Dropdown({
        Title = "🎣 Select Bait",
        Desc = "Choose fishing bait from available options",
        Values = #AvailableBaits > 0 and AvailableBaits or {"FishingBait1", "FishingBait2", "FishingBait3"},
        Default = FishingConfig.SelectedBait,
        Callback = function(selected)
            FishingConfig.SelectedBait = selected
            WindUI:Notify({ 
                Title = "🎣 Bait Selected", 
                Content = "Selected: " .. tostring(selected), 
                Duration = 2 
            })
        end
    })
    
    -- Mouse position tracking system replaces manual position inputs
    MouseTracker.PositionLabel = Tabs.FishTab:Paragraph({
        Title = "📍 Position Tracking",
        Desc = "Click 'Set Position by Click' to start tracking",
        Image = "crosshair",
        ImageSize = 18,
    })
    
    -- Current position display
    currentPosLabel = Tabs.FishTab:Paragraph({
        Title = "📍 Current Fishing Position",
        Desc = string.format("X: %.1f, Y: %.1f, Z: %.1f", 
            FishingConfig.FishingPosition.X, 
            FishingConfig.FishingPosition.Y, 
            FishingConfig.FishingPosition.Z),
        Image = "map-pin",
        ImageSize = 18,
    })
    
    -- Update the display immediately after creation
    updateCurrentPositionDisplay()
    
    -- Set position by click button
    Tabs.FishTab:Button({
        Title = "📍 Set Position by Click",
        Desc = "Click to enable mouse tracking, then click anywhere in the world to set fishing position",
        Callback = function()
            if not FishingConfig.PositionSetting then
                FishingConfig.PositionSetting = true
                startMouseTracking()
            else
                stopMouseTracking()
            end
        end
    })
    
    -- Set current position button (kept for convenience)
    Tabs.FishTab:Button({
        Title = "📍 Set Current Position",
        Desc = "Set fishing position to your current character location (same as clicking where you stand)",
        Callback = function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                FishingConfig.FishingPosition = LocalPlayer.Character.HumanoidRootPart.Position
                
                -- Update current position display
                updateCurrentPositionDisplay()
                
                -- Debug print to confirm position is saved
                print("🎣 Position saved:", FishingConfig.FishingPosition)
                
                WindUI:Notify({ 
                    Title = "📍 Position Set", 
                    Content = string.format("Position: %.2f, %.2f, %.2f", 
                        FishingConfig.FishingPosition.X, 
                        FishingConfig.FishingPosition.Y, 
                        FishingConfig.FishingPosition.Z), 
                    Duration = 3 
                })
            else
                WindUI:Notify({ 
                    Title = "❌ Error", 
                    Content = "Character not found", 
                    Duration = 3 
                })
            end
        end
    })
    
    Tabs.FishTab:Section({ Title = "🤖 Auto Fishing", Icon = "play" })
    
    -- Auto Fish toggle
    autoFishToggle = Tabs.FishTab:Toggle({
        Title = "🎣 Auto Fish",
        Desc = "Automatically fish with selected bait at specified position",
        Value = false,
        Callback = function(state)
            if state then
                FishingSystem.Start()
            else
                FishingSystem.Stop()
            end
        end
    })
    
    -- Cast delay slider
    Tabs.FishTab:Slider({
        Title = "⏰ Cast Delay",
        Desc = "Delay between fishing casts (seconds) - Higher = More Accurate",
        Default = FishingConfig.DelayBetweenCasts,
        Min = 1,
        Max = 10,
        Rounding = 1,
        Callback = function(value)
            FishingConfig.DelayBetweenCasts = value
        end
    })
    
    Tabs.FishTab:Section({ Title = "📊 Statistics", Icon = "info" })
    
    -- Statistics display
    statsLabel = Tabs.FishTab:Paragraph({
        Title = "🎣 Fishing Statistics",
        Desc = "🐟 Fish: 0 | 🎯 Rate: 0% | ⏱️ Session: 0m",
        Image = "activity",
        ImageSize = 18,
    })
    
    Tabs.FishTab:Section({ Title = "🎮 Manual Controls", Icon = "settings" })
    
    -- Manual controls
    Tabs.FishTab:Button({
        Title = "🎣 Cast Line",
        Desc = "Manually cast fishing line",
        Callback = function()
            task.spawn(function()
                if startFishing() then
                    WindUI:Notify({ 
                        Title = "🎣 Manual Cast", 
                        Content = "Line cast successfully!", 
                        Duration = 2 
                    })
                end
            end)
        end
    })
    
    Tabs.FishTab:Button({
        Title = "🐟 Pull Fish",
        Desc = "Manually pull fish from line",
        Callback = function()
            if pullFish() then
                WindUI:Notify({ 
                    Title = "🐟 Manual Pull", 
                    Content = "Fish pulled successfully!", 
                    Duration = 2 
                })
            end
        end
    })
    
    Tabs.FishTab:Button({
        Title = "🔄 Reset Statistics",
        Desc = "Reset fishing statistics",
        Callback = function()
            FishingConfig.Stats = {
                FishCaught = 0,
                SessionStartTime = os.time(),
                LastCatchTime = 0,
                TotalCasts = 0,
                SuccessfulCasts = 0
            }
            updateStats()
            WindUI:Notify({ 
                Title = "🔄 Statistics Reset", 
                Content = "Statistics have been reset!", 
                Duration = 2 
            })
        end
    })
    
    -- Register with config system if available
    if Config and autoFishToggle then
        pcall(function()
            Config:Register("autoFishEnabled", autoFishToggle)
        end)
    elseif not Config then
        print("⚠️ Auto Fish: Config system not available, settings won't be saved")
    end
    
    -- Start stats update loop
    task.spawn(function()
        while true do
            updateStats()
            task.wait(2)
        end
    end)
    
    print("🎣 Auto Fish System initialized successfully!")
end

-- Cleanup function
function AutoFishSystem.Cleanup()
    FishingSystem.Stop()
    stopMouseTracking()
end

return AutoFishSystem
