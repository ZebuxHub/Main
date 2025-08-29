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
    FishingPosition = Vector3.new(-470.3221740722656, 11, 351.36126708984375),
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

-- Flag System for Position Setting
local FlagSystem = {
    FlagPart = nil,
    FlagMainPart = nil,
    FlagPole = nil,
    DragConnection = nil,
    ClickConnection = nil,
    Active = false,
    UserInputConnection = nil
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
    -- Function kept for compatibility but flag system is preferred
    WindUI:Notify({ 
        Title = "🚩 Use Flag System", 
        Content = "Use 'Place Fishing Flag' for better visual positioning!", 
        Duration = 3 
    })
end

local function stopMouseTracking()
    -- Function kept for compatibility
end

local function createFishingFlag()
    -- Remove existing flag if any
    if FlagSystem.FlagPart then
        FlagSystem.FlagPart:Destroy()
        FlagSystem.FlagPart = nil
    end
    
    -- Create main flag container
    local flagContainer = Instance.new("Model")
    flagContainer.Name = "FishingFlagModel"
    flagContainer.Parent = workspace
    
    -- Create flag pole (bottom part)
    local pole = Instance.new("Part")
    pole.Name = "FlagPole"
    pole.Size = Vector3.new(0.3, 5, 0.3)
    pole.Material = Enum.Material.WoodPlanks
    pole.Color = Color3.new(0.4, 0.2, 0.1)
    pole.CanCollide = false
    pole.Anchored = true
    pole.Shape = Enum.PartType.Cylinder
    pole.Position = FishingConfig.FishingPosition
    pole.Parent = flagContainer
    
    -- Add metal cap to pole
    local poleCap = Instance.new("Part")
    poleCap.Name = "PoleCap"
    poleCap.Size = Vector3.new(0.4, 0.2, 0.4)
    poleCap.Material = Enum.Material.Metal
    poleCap.Color = Color3.new(0.7, 0.7, 0.7)
    poleCap.CanCollide = false
    poleCap.Anchored = true
    poleCap.Shape = Enum.PartType.Ball
    poleCap.Position = pole.Position + Vector3.new(0, 2.6, 0)
    poleCap.Parent = flagContainer
    
    -- Create flag part with gradient effect
    local flag = Instance.new("Part")
    flag.Name = "FishingFlag"
    flag.Size = Vector3.new(2, 1.5, 0.1)
    flag.Material = Enum.Material.Neon
    flag.Color = Color3.new(0, 0.8, 1)
    flag.CanCollide = false
    flag.Anchored = true
    flag.TopSurface = Enum.SurfaceType.Smooth
    flag.BottomSurface = Enum.SurfaceType.Smooth
    flag.Position = pole.Position + Vector3.new(1, 1.5, 0)
    flag.Parent = flagContainer
    
    -- Add flag design with SurfaceGui
    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Face = Enum.NormalId.Front
    surfaceGui.Parent = flag
    
    -- Background gradient frame
    local gradientFrame = Instance.new("Frame")
    gradientFrame.Size = UDim2.new(1, 0, 1, 0)
    gradientFrame.BackgroundTransparency = 0.3
    gradientFrame.BorderSizePixel = 0
    gradientFrame.Parent = surfaceGui
    
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(0, 0.5, 1)),
        ColorSequenceKeypoint.new(1, Color3.new(0, 1, 1))
    })
    gradient.Rotation = 45
    gradient.Parent = gradientFrame
    
    -- Flag icon
    local flagIcon = Instance.new("TextLabel")
    flagIcon.Size = UDim2.new(0.4, 0, 0.6, 0)
    flagIcon.Position = UDim2.new(0.1, 0, 0.2, 0)
    flagIcon.BackgroundTransparency = 1
    flagIcon.Text = "🎣"
    flagIcon.TextColor3 = Color3.new(1, 1, 1)
    flagIcon.TextScaled = true
    flagIcon.Font = Enum.Font.SourceSansBold
    flagIcon.Parent = gradientFrame
    
    -- Flag text
    local flagText = Instance.new("TextLabel")
    flagText.Size = UDim2.new(0.5, 0, 0.3, 0)
    flagText.Position = UDim2.new(0.45, 0, 0.35, 0)
    flagText.BackgroundTransparency = 1
    flagText.Text = "FISH HERE"
    flagText.TextColor3 = Color3.new(1, 1, 1)
    flagText.TextScaled = true
    flagText.Font = Enum.Font.SourceSansBold
    flagText.Parent = gradientFrame
    
    -- Add glowing effect
    local pointLight = Instance.new("PointLight")
    pointLight.Color = Color3.new(0, 0.8, 1)
    pointLight.Brightness = 2
    pointLight.Range = 10
    pointLight.Parent = flag
    
    -- Create floating text label above flag
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Size = UDim2.new(0, 200, 0, 60)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = flagContainer
    
    -- Background for text
    local textBackground = Instance.new("Frame")
    textBackground.Size = UDim2.new(1, 0, 1, 0)
    textBackground.BackgroundColor3 = Color3.new(0, 0, 0)
    textBackground.BackgroundTransparency = 0.5
    textBackground.BorderSizePixel = 0
    textBackground.Parent = billboardGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = textBackground
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = "🎣 Fishing Position 🎣"
    textLabel.TextColor3 = Color3.new(0, 1, 1)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.Parent = textBackground
    
    -- Add selection box for visual feedback
    local selectionBox = Instance.new("SelectionBox")
    selectionBox.Color3 = Color3.new(0, 1, 1)
    selectionBox.LineThickness = 0.3
    selectionBox.Transparency = 0.3
    selectionBox.Adornee = flagContainer
    selectionBox.Parent = flagContainer
    
    -- Add waving animation
    task.spawn(function()
        local time = 0
        while flagContainer.Parent do
            time = time + 0.1
            if flag.Parent then
                flag.Rotation = Vector3.new(0, 0, math.sin(time) * 5)
            end
            task.wait(0.1)
        end
    end)
    
    FlagSystem.FlagPart = flagContainer
    FlagSystem.FlagMainPart = flag
    FlagSystem.FlagPole = pole
    return flagContainer
end

local function enableFlagDragging()
    if not FlagSystem.FlagPart then return end
    
    local mouse = LocalPlayer:GetMouse()
    local flag = FlagSystem.FlagPart
    
    -- Mouse move connection for real-time preview
    FlagSystem.DragConnection = mouse.Move:Connect(function()
        if FlagSystem.Active then
            local unitRay = Camera:ScreenPointToRay(mouse.X, mouse.Y)
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, flag}
            
            local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
            
            if raycastResult then
                -- Update flag position in real-time as mouse moves
                local newPosition = raycastResult.Position
                
                -- Update pole position (main anchor)
                if FlagSystem.FlagPole then
                    FlagSystem.FlagPole.Position = newPosition
                end
                
                -- Update flag position relative to pole
                if FlagSystem.FlagMainPart then
                    FlagSystem.FlagMainPart.Position = newPosition + Vector3.new(1, 1.5, 0)
                end
                
                -- Update entire flag container position
                if flag and flag:IsA("Model") then
                    flag:SetPrimaryPartCFrame(CFrame.new(newPosition))
                end
                
                -- Update display but don't save position yet
                if MouseTracker.PositionLabel then
                    MouseTracker.PositionLabel:SetDesc(string.format("Flag Position: %.1f, %.1f, %.1f\nClick anywhere to place flag!", 
                        raycastResult.Position.X, raycastResult.Position.Y, raycastResult.Position.Z))
                end
            end
        end
    end)
    
    -- Mouse click connection to confirm position
    local clickConnection
    clickConnection = mouse.Button1Down:Connect(function()
        if FlagSystem.Active then
            local unitRay = Camera:ScreenPointToRay(mouse.X, mouse.Y)
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, flag}
            
            local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
            
            if raycastResult then
                -- Final flag position
                local finalPosition = raycastResult.Position
                
                -- Update pole position (main anchor)
                if FlagSystem.FlagPole then
                    FlagSystem.FlagPole.Position = finalPosition
                end
                
                -- Update flag position relative to pole
                if FlagSystem.FlagMainPart then
                    FlagSystem.FlagMainPart.Position = finalPosition + Vector3.new(1, 1.5, 0)
                end
                
                -- Update entire flag container position
                if flag and flag:IsA("Model") then
                    flag:SetPrimaryPartCFrame(CFrame.new(finalPosition))
                end
                
                -- Save fishing position
                FishingConfig.FishingPosition = raycastResult.Position
                updateCurrentPositionDisplay()
                
                -- Stop flag placement
                stopFlagPlacement()
            end
        end
    end)
    
    -- Store click connection for cleanup
    FlagSystem.ClickConnection = clickConnection
    
    -- User input for canceling (ESC key)
    FlagSystem.UserInputConnection = UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Escape then
            -- Cancel flag placement
            removeFishingFlag()
            WindUI:Notify({ 
                Title = "❌ Beautiful Flag Placement Cancelled", 
                Content = "Beautiful flag placement was cancelled", 
                Duration = 2 
            })
        end
    end)
end

local function startFlagPlacement()
    FlagSystem.Active = true
    
    -- Create flag at current fishing position
    local flag = createFishingFlag()
    
    -- Enable dragging
    enableFlagDragging()
    
    WindUI:Notify({ 
        Title = "🚩 Beautiful Flag Placement Active", 
        Content = "Move mouse to preview the glowing flag position, then CLICK to place! Press ESC to cancel.", 
        Duration = 5 
    })
end

local function stopFlagPlacement()
    FlagSystem.Active = false
    
    -- Disconnect all connections
    if FlagSystem.DragConnection then
        FlagSystem.DragConnection:Disconnect()
        FlagSystem.DragConnection = nil
    end
    
    if FlagSystem.ClickConnection then
        FlagSystem.ClickConnection:Disconnect()
        FlagSystem.ClickConnection = nil
    end
    
    if FlagSystem.UserInputConnection then
        FlagSystem.UserInputConnection:Disconnect()
        FlagSystem.UserInputConnection = nil
    end
    
    -- Update displays
    updateCurrentPositionDisplay()
    
    if MouseTracker.PositionLabel then
        MouseTracker.PositionLabel:SetDesc("Click 'Place Beautiful Fishing Flag' to set position with glowing animated flag")
    end
    
    -- Debug print
    print("🎣 Flag position confirmed:", FishingConfig.FishingPosition)
    
    WindUI:Notify({ 
        Title = "🚩 Beautiful Position Confirmed", 
        Content = string.format("Beautiful fishing flag placed at: %.1f, %.1f, %.1f", 
            FishingConfig.FishingPosition.X, FishingConfig.FishingPosition.Y, FishingConfig.FishingPosition.Z), 
        Duration = 3 
    })
end

local function removeFishingFlag()
    if FlagSystem.FlagPart then
        FlagSystem.FlagPart:Destroy()
        FlagSystem.FlagPart = nil
    end
    
    -- Stop any active dragging
    if FlagSystem.Active then
        stopFlagPlacement()
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
    
    -- Mouse position tracking system - now shows beautiful flag system info
    MouseTracker.PositionLabel = Tabs.FishTab:Paragraph({
        Title = "🚩 Beautiful Flag Position System",
        Desc = "Click 'Place Beautiful Fishing Flag' to set position with glowing animated flag",
        Image = "flag",
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
    
    -- Place beautiful fishing flag button
    Tabs.FishTab:Button({
        Title = "🚩 Place Beautiful Fishing Flag",
        Desc = "Click to activate beautiful flag placement with glowing effects, then move mouse and click anywhere to set fishing position",
        Callback = function()
            if not FlagSystem.Active then
                startFlagPlacement()
            else
                stopFlagPlacement()
            end
        end
    })
    
    -- Remove beautiful flag button
    Tabs.FishTab:Button({
        Title = "🗑️ Remove Beautiful Flag",
        Desc = "Remove the beautiful glowing fishing flag from the world",
        Callback = function()
            removeFishingFlag()
            WindUI:Notify({ 
                Title = "🗑️ Beautiful Flag Removed", 
                Content = "Beautiful fishing flag has been removed from the world", 
                Duration = 2 
            })
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
    removeFishingFlag()
end

return AutoFishSystem
