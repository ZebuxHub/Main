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

-- Module variables
local WindUI = nil
local Tabs = nil
local Config = nil

-- Configuration
local FishingConfig = {
    SelectedBait = "FishingBait1",
    FishingPosition = Vector3.new(-470.3221740722656, 11, 351.36126708984375),
    AutoFishEnabled = false,
    DelayBetweenCasts = 2,
    AutoWaterDetection = true,
    SearchRadius = 100,
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
    
    -- Wait a moment then throw the line with selected bait
    task.wait(0.5)
    
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
    
    local timeout = 30 -- 30 second timeout
    local startTime = tick()
    
    -- Wait for AnimFish attribute to be "Pull"
    while FishingConfig.AutoFishEnabled and (tick() - startTime) < timeout do
        local animFish = zif:GetAttribute("AnimFish")
        if animFish == "Pull" then
            return true
        end
        task.wait(0.1)
    end
    
    return false
end

local function runAutoFish()
    -- Auto detect and move to water at the start if enabled
    if FishingConfig.AutoWaterDetection then
        autoDetectAndMoveToWater()
        task.wait(2) -- Wait for movement to complete
    end
    
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
    WindUI = dependencies.WindUI
    Tabs = dependencies.Tabs
    Config = dependencies.Config
    
    -- Load fishing bait configuration
    loadFishingBaitConfig()
    
    -- Create Auto Fish Tab UI
    Tabs.FishTab:Section({ Title = "🎣 Fishing Settings", Icon = "settings" })
    
    -- Auto Water Detection Toggle
    Tabs.FishTab:Toggle({
        Title = "🌊 Auto Water Detection",
        Desc = "Automatically find and move to nearby water before fishing",
        Value = FishingConfig.AutoWaterDetection,
        Callback = function(state)
            FishingConfig.AutoWaterDetection = state
            WindUI:Notify({ 
                Title = "🌊 Water Detection", 
                Content = state and "Auto water detection enabled!" or "Auto water detection disabled!", 
                Duration = 2 
            })
        end
    })
    
    -- Water Search Radius Slider
    Tabs.FishTab:Slider({
        Title = "🔍 Search Radius",
        Desc = "Maximum distance to search for water (meters)",
        Default = FishingConfig.SearchRadius,
        Min = 50,
        Max = 500,
        Rounding = 0,
        Callback = function(value)
            FishingConfig.SearchRadius = value
        end
    })
    
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
    
    -- Position inputs
    Tabs.FishTab:Input({
        Title = "🌍 Fishing Position X",
        Desc = "X coordinate for fishing position",
        Default = tostring(math.floor(FishingConfig.FishingPosition.X * 100) / 100),
        Numeric = true,
        Finished = true,
        Callback = function(value)
            local x = tonumber(value) or FishingConfig.FishingPosition.X
            FishingConfig.FishingPosition = Vector3.new(x, FishingConfig.FishingPosition.Y, FishingConfig.FishingPosition.Z)
        end
    })
    
    Tabs.FishTab:Input({
        Title = "🌍 Fishing Position Y",
        Desc = "Y coordinate for fishing position",
        Default = tostring(math.floor(FishingConfig.FishingPosition.Y * 100) / 100),
        Numeric = true,
        Finished = true,
        Callback = function(value)
            local y = tonumber(value) or FishingConfig.FishingPosition.Y
            FishingConfig.FishingPosition = Vector3.new(FishingConfig.FishingPosition.X, y, FishingConfig.FishingPosition.Z)
        end
    })
    
    Tabs.FishTab:Input({
        Title = "🌍 Fishing Position Z",
        Desc = "Z coordinate for fishing position",
        Default = tostring(math.floor(FishingConfig.FishingPosition.Z * 100) / 100),
        Numeric = true,
        Finished = true,
        Callback = function(value)
            local z = tonumber(value) or FishingConfig.FishingPosition.Z
            FishingConfig.FishingPosition = Vector3.new(FishingConfig.FishingPosition.X, FishingConfig.FishingPosition.Y, z)
        end
    })
    
    -- Set current position button
    Tabs.FishTab:Button({
        Title = "📍 Set Current Position",
        Desc = "Set fishing position to your current character position",
        Callback = function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                FishingConfig.FishingPosition = LocalPlayer.Character.HumanoidRootPart.Position
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
        Desc = "Delay between fishing casts (seconds)",
        Default = FishingConfig.DelayBetweenCasts,
        Min = 1,
        Max = 10,
        Rounding = 0,
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
    
    -- Manual water detection button
    Tabs.FishTab:Button({
        Title = "🌊 Find Water",
        Desc = "Manually search for and move to nearby water",
        Callback = function()
            task.spawn(function()
                if autoDetectAndMoveToWater() then
                    WindUI:Notify({ 
                        Title = "🌊 Manual Water Detection", 
                        Content = "Successfully found and moved to water!", 
                        Duration = 3 
                    })
                end
            end)
        end
    })
    
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
    if Config then
        pcall(function()
            Config:Register("autoFishEnabled", autoFishToggle)
        end)
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
end

return AutoFishSystem
