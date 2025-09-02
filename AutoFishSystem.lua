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
local ContextActionService = game:GetService("ContextActionService")

-- Module variables
local WindUI = nil
local Tabs = nil
local Config = nil
local currentPosLabel = nil

-- Forward declarations for functions referenced earlier
local updateCurrentPositionDisplay
local stopFlagPlacement
local removeFishingFlag

-- Configuration
local FishingConfig = {
    SelectedBait = "FishingBait1",
    FishingPosition = Vector3.new(0, 0, 0),
    AutoFishEnabled = false,
    DelayBetweenCasts = 0.5,
    FishingRange = 5, -- Fish within 5 studs of player
    VerticalOffset = 10, -- Cast position Y offset above player
    PlayerAnchored = false, -- Track if player is anchored
    SafePosition = nil, -- Store safe position to prevent falling
    Original = {
        WalkSpeed = nil,
        JumpPower = nil,
        AutoRotate = nil
    },
    _Controls = nil, -- cached controls module
    _CASBound = false, -- movement sink bound flag
    FreezeConn = nil,
    -- Position placement history
    PlacedPositions = {},
    CurrentPositionIndex = 1,
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
        -- Loaded " .. #AvailableBaits .. " fishing baits
    else
        -- Fallback baits
        AvailableBaits = {"FishingBait1", "FishingBait2", "FishingBait3"}
        -- Failed to load fishing bait config, using fallback baits
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

-- Player NetWorth helper (money)
local function getPlayerNetWorth()
	local player = LocalPlayer
	if not player then return 0 end
	local attr = player:GetAttribute("NetWorth")
	if type(attr) == "number" then return attr end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local nw = leaderstats:FindFirstChild("NetWorth")
		if nw and type(nw.Value) == "number" then return nw.Value end
	end
	return 0
end

local function toNumberLoose(v)
	if type(v) == "number" then return v end
	if type(v) == "string" then
		local cleaned = v:gsub("[^%d%.]", "")
		local n = tonumber(cleaned)
		if n then return n end
	end
	return nil
end

local function getBaitPrice(baitId)
	if not FishingBaitConfig or not baitId then return 0 end
	local cfg = FishingBaitConfig[baitId]
	if type(cfg) ~= "table" then return 0 end
	-- Try multiple common fields
	return toNumberLoose(cfg.Price) or toNumberLoose(cfg.BuyRate) or toNumberLoose(cfg.Cost) or 0
end

local function chooseAffordableBait(selectedId)
	-- Build a price-sorted list
	local items = {}
	for _, id in ipairs(AvailableBaits) do
		local price = getBaitPrice(id) or 0
		table.insert(items, { id = id, price = price })
	end
	table.sort(items, function(a, b)
		return (a.price or 0) < (b.price or 0)
	end)
	-- Find selected index in this sorted list
	local selIndex = 1
	for i, it in ipairs(items) do
		if it.id == selectedId then selIndex = i break end
	end
	local net = getPlayerNetWorth()
	local sel = items[selIndex]
	if not sel then return selectedId, false end
	if net >= (sel.price or 0) then
		return selectedId, false
	end
	-- Step down to the nearest cheaper affordable option (one step at a time)
	local fallbackIndex = math.max(selIndex - 1, 1)
	-- If one step down still too expensive, keep stepping until affordable or reach cheapest
	for i = fallbackIndex, 1, -1 do
		if net >= (items[i].price or 0) then
			return items[i].id, true
		end
	end
	-- If nothing is affordable, return the cheapest anyway
	return items[1].id, true
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
    PinHologram = nil,
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

-- Enhanced Player Anchoring System with Fall Prevention
local function anchorPlayer()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local rootPart = LocalPlayer.Character.HumanoidRootPart
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        
        -- Store original position for safety
        FishingConfig.SafePosition = rootPart.CFrame
        
        -- Save movement state and freeze movement without ragdolling
        if humanoid then
            if FishingConfig.Original.WalkSpeed == nil then
                FishingConfig.Original.WalkSpeed = humanoid.WalkSpeed
            end
            if FishingConfig.Original.JumpPower == nil then
                FishingConfig.Original.JumpPower = humanoid.JumpPower
            end
            if FishingConfig.Original.AutoRotate == nil then
                FishingConfig.Original.AutoRotate = humanoid.AutoRotate
            end
            humanoid.AutoRotate = false
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
            humanoid.Sit = false
            humanoid.PlatformStand = false
        end

        -- Anchor the root so external forces/animations can’t drag us
        rootPart.Anchored = true
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero

        -- Hard freeze: keep restoring position if any server animation tries to move us
        if FishingConfig.FreezeConn then
            FishingConfig.FreezeConn:Disconnect()
            FishingConfig.FreezeConn = nil
        end
        FishingConfig.FreezeConn = RunService.Heartbeat:Connect(function()
            if not FishingConfig.PlayerAnchored then return end
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local target = FishingConfig.SafePosition
            if not target then return end
            local posDelta = (hrp.Position - target.Position).Magnitude
            if posDelta > 0.15 then
                hrp.CFrame = target
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end)
        
        FishingConfig.PlayerAnchored = true
        -- Hard-disable controls via CAS sink and PlayerModule if available
        if not FishingConfig._CASBound then
            local function sink(actionName, inputState, inputObj)
                return Enum.ContextActionResult.Sink
            end
            ContextActionService:BindAction("AFS_BlockMovement", sink, false,
                Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
                Enum.KeyCode.Space, Enum.KeyCode.LeftShift)
            FishingConfig._CASBound = true
        end
        -- Try to disable PlayerModule controls for gamepads/mobile as well
        pcall(function()
            local playerScripts = LocalPlayer:WaitForChild("PlayerScripts", 2)
            if playerScripts then
                local pm = playerScripts:FindFirstChild("PlayerModule")
                if pm and pm:FindFirstChild("ControlModule") then
                    local controls = require(pm:FindFirstChild("ControlModule"))
                    FishingConfig._Controls = controls
                    if controls and controls.Disable then controls:Disable() end
                end
            end
        end)
        -- Player anchored for fishing with fall protection
    end
end

local function unanchorPlayer()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local rootPart = LocalPlayer.Character.HumanoidRootPart
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        
        -- Check if player fell or is in bad position
        if FishingConfig.SafePosition then
            local currentY = rootPart.Position.Y
            local safeY = FishingConfig.SafePosition.Position.Y
            
            -- If player fell significantly, restore to safe position
            if currentY < safeY - 20 then
                -- Player fell! Restoring to safe position...
                rootPart.CFrame = FishingConfig.SafePosition
                task.wait(0.1)
            end
        end
        
        -- Restore normal movement
        if humanoid then
            humanoid.AutoRotate = FishingConfig.Original.AutoRotate ~= nil and FishingConfig.Original.AutoRotate or true
            humanoid.WalkSpeed = FishingConfig.Original.WalkSpeed ~= nil and FishingConfig.Original.WalkSpeed or 16
            humanoid.JumpPower = FishingConfig.Original.JumpPower ~= nil and FishingConfig.Original.JumpPower or 50
            humanoid.PlatformStand = false
        end

        -- Stop freeze loop
        if FishingConfig.FreezeConn then
            FishingConfig.FreezeConn:Disconnect()
            FishingConfig.FreezeConn = nil
        end

        rootPart.Anchored = false
        FishingConfig.PlayerAnchored = false
        -- Re-enable controls
        if FishingConfig._CASBound then
            pcall(function()
                ContextActionService:UnbindAction("AFS_BlockMovement")
            end)
            FishingConfig._CASBound = false
        end
        if FishingConfig._Controls and FishingConfig._Controls.Enable then
            pcall(function() FishingConfig._Controls:Enable() end)
        end
        -- Player unanchored with fall protection
    end
end

-- Auto Position System
local function getRandomFishingPosition()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return Vector3.new(0, 0, 0)
    end
    
    local playerPosition = LocalPlayer.Character.HumanoidRootPart.Position
    
    -- Generate random position within 5 studs of player
    local randomX = playerPosition.X + (math.random(-50, 50) / 10) -- -5 to 5 studs
    local randomZ = playerPosition.Z + (math.random(-50, 50) / 10) -- -5 to 5 studs
    local randomY = playerPosition.Y + (FishingConfig.VerticalOffset or 10) -- Raise above player
    
    return Vector3.new(randomX, randomY, randomZ)
end

local function updateFishingPosition()
    FishingConfig.FishingPosition = getRandomFishingPosition()
    -- Fishing position updated
end
local function savePositionToHistory(position, method)
    local timestamp = os.time()
    local positionData = {
        Position = position,
        Timestamp = timestamp,
        Method = method or "Pin Placement",
        Index = #FishingConfig.PlacedPositions + 1
    }
    
    table.insert(FishingConfig.PlacedPositions, positionData)
    
    -- Keep only last 20 positions to prevent memory overflow
    if #FishingConfig.PlacedPositions > 20 then
        table.remove(FishingConfig.PlacedPositions, 1)
        -- Update indices
        for i, pos in ipairs(FishingConfig.PlacedPositions) do
            pos.Index = i
        end
    end
    
    FishingConfig.CurrentPositionIndex = #FishingConfig.PlacedPositions
    -- Position saved to history
end

local function getPositionHistoryText()
    if #FishingConfig.PlacedPositions == 0 then
        return "No positions placed yet. Use 'Place Hologram Pin' to mark fishing spots!"
    end
    
    local current = FishingConfig.PlacedPositions[FishingConfig.CurrentPositionIndex]
    if not current then
        FishingConfig.CurrentPositionIndex = #FishingConfig.PlacedPositions
        current = FishingConfig.PlacedPositions[FishingConfig.CurrentPositionIndex]
    end
    
    if current then
        local timeAgo = os.time() - current.Timestamp
        local timeText = timeAgo < 60 and string.format("%ds ago", timeAgo) or 
                        timeAgo < 3600 and string.format("%dm ago", math.floor(timeAgo/60)) or 
                        string.format("%dh ago", math.floor(timeAgo/3600))
        
        return string.format("📍 Position %d/%d: %.1f, %.1f, %.1f\n🕒 Placed %s via %s", 
            FishingConfig.CurrentPositionIndex, #FishingConfig.PlacedPositions,
            current.Position.X, current.Position.Y, current.Position.Z,
            timeText, current.Method)
    end
    
    return "Position history error"
end

local function usePositionFromHistory(index)
    if index and FishingConfig.PlacedPositions[index] then
        local position = FishingConfig.PlacedPositions[index].Position
        FishingConfig.FishingPosition = position
        FishingConfig.CurrentPositionIndex = index
        updateCurrentPositionDisplay()
        return true
    end
    return false
end

local function clearPositionHistory()
    FishingConfig.PlacedPositions = {}
    FishingConfig.CurrentPositionIndex = 1
end

local function startMouseTracking()
    -- Function kept for compatibility but flag system is preferred
    WindUI:Notify({ 
        Title = "🚩 Use Pin System", 
        Content = "Use 'Place Hologram Pin' for better visual positioning!", 
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
    
    -- Create main pin container
    local pinContainer = Instance.new("Model")
    pinContainer.Name = "HologramPinModel"
    pinContainer.Parent = workspace
    
    -- Create hologram pin
    local pin = Instance.new("Part")
    pin.Name = "HologramPin"
    pin.Size = Vector3.new(1, 3, 1)
    pin.Material = Enum.Material.ForceField
    pin.Color = Color3.new(0, 1, 1)
    pin.Transparency = 0.3
    pin.CanCollide = false
    pin.Anchored = true
    pin.Shape = Enum.PartType.Cylinder
    pin.Position = FishingConfig.FishingPosition + Vector3.new(0, 1.5, 0)
    pin.Rotation = Vector3.new(0, 0, 90) -- Rotate to make it stand upright
    pin.Parent = pinContainer
    
    -- Add subtle glow
    local pinLight = Instance.new("PointLight")
    pinLight.Color = Color3.new(0, 1, 1)
    pinLight.Brightness = 2
    pinLight.Range = 15
    pinLight.Parent = pin
    
    -- Create floating text label
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Size = UDim2.new(0, 150, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 2.5, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = pinContainer
    
    -- Simple text background
    local textBackground = Instance.new("Frame")
    textBackground.Size = UDim2.new(1, 0, 1, 0)
    textBackground.BackgroundColor3 = Color3.new(0, 0, 0)
    textBackground.BackgroundTransparency = 0.6
    textBackground.BorderSizePixel = 0
    textBackground.Parent = billboardGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = textBackground
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = "🎣 Fishing Spot"
    textLabel.TextColor3 = Color3.new(0, 1, 1)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.Parent = textBackground
    
    -- Add simple selection box
    local selectionBox = Instance.new("SelectionBox")
    selectionBox.Color3 = Color3.new(0, 1, 1)
    selectionBox.LineThickness = 0.2
    selectionBox.Transparency = 0.4
    selectionBox.Adornee = pinContainer
    selectionBox.Parent = pinContainer
    
    -- Store references
    FlagSystem.FlagPart = pinContainer
    FlagSystem.PinHologram = pin
    
    return pinContainer
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
                -- Update pin position in real-time as mouse moves
                local newPosition = raycastResult.Position
                
                -- Update pin hologram position
                if FlagSystem.PinHologram then
                    FlagSystem.PinHologram.Position = newPosition + Vector3.new(0, 1.5, 0)
                end
                
                -- Update display but don't save position yet
                if MouseTracker.PositionLabel then
                    MouseTracker.PositionLabel:SetDesc("Pin Position: %.1f, %.1f, %.1f\nLeft-click anywhere to place pin here!", 
                        raycastResult.Position.X, raycastResult.Position.Y, raycastResult.Position.Z)
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
                -- Final pin position
                local finalPosition = raycastResult.Position
                
                -- Update pin hologram to final position and stop following mouse
                if FlagSystem.PinHologram then
                    FlagSystem.PinHologram.Position = finalPosition + Vector3.new(0, 1.5, 0)
                end
                
                -- Save fishing position
                FishingConfig.FishingPosition = finalPosition
                
                -- Save to position history
                savePositionToHistory(finalPosition, "Pin Placement")
                
                -- Update displays immediately with error handling
                pcall(function()
                    if currentPosLabel then
                        currentPosLabel:SetDesc(string.format("X: %.1f, Y: %.1f, Z: %.1f", 
                            finalPosition.X, finalPosition.Y, finalPosition.Z))
                    end
                end)
                
                -- Stop flag placement mode completely - ready for next placement
                stopFlagPlacement()
                
                -- Confirmation notification
                WindUI:Notify({ 
                    Title = "📍 Pin Placed Successfully", 
                    Content = string.format("Pin locked at: %.1f, %.1f, %.1f\nClick 'Place Hologram Pin' again to place another pin", 
                        finalPosition.X, finalPosition.Y, finalPosition.Z), 
                    Duration = 4 
                })
            end
        end
    end)
    
    -- Store click connection for cleanup
    FlagSystem.ClickConnection = clickConnection
    
    -- User input for canceling (ESC key)
    FlagSystem.UserInputConnection = UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Escape and FlagSystem.Active then
            -- Cancel flag placement and remove the pin
            removeFishingFlag()
            stopFlagPlacement()
            WindUI:Notify({ 
                Title = "❌ Pin Placement Cancelled", 
                Content = "Pin placement was cancelled", 
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
    
    -- Note: Notification is now handled in the button callback for better clarity
end

function stopFlagPlacement()
    -- Immediately set active to false to stop all tracking
    FlagSystem.Active = false
    
    -- Disconnect all mouse tracking connections with error handling
    pcall(function()
        if FlagSystem.DragConnection then
            FlagSystem.DragConnection:Disconnect()
            FlagSystem.DragConnection = nil
        end
    end)
    
    pcall(function()
        if FlagSystem.ClickConnection then
            FlagSystem.ClickConnection:Disconnect()
            FlagSystem.ClickConnection = nil
        end
    end)
    
    pcall(function()
        if FlagSystem.UserInputConnection then
            FlagSystem.UserInputConnection:Disconnect()
            FlagSystem.UserInputConnection = nil
        end
    end)
    
    -- Update displays with error handling
    pcall(function()
        if currentPosLabel then
            currentPosLabel:SetDesc(string.format("X: %.1f, Y: %.1f, Z: %.1f", 
                FishingConfig.FishingPosition.X, 
                FishingConfig.FishingPosition.Y, 
                FishingConfig.FishingPosition.Z))
        end
    end)
    
    -- Update UI guidance text
    pcall(function()
        if MouseTracker.PositionLabel then
            MouseTracker.PositionLabel:SetDesc("Click 'Place Hologram Pin' then left-click anywhere in the world to place pin")
        end
    end)
    
    -- Pin placement stopped
end

function removeFishingFlag()
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
    -- Update fishing position to random spot around player
    updateFishingPosition()
    
    -- First fire Focus + FishRob (don't move player)
    local args = {
        "Focus",
        "FishRob"
    }
    
    local success, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
    end)
    
    if not success then
        WindUI:Notify({ 
            Title = "🎣 Auto Fish Debug", 
            Content = "❌ Failed to focus fishing: " .. tostring(err), 
            Duration = 3 
        })
        unanchorPlayer() -- Unanchor if failed
        return false
    end
    
    -- Start fishing state (if server expects a handshake)
    pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer("Start")
    end)

    -- Shorter wait before throw for faster cycles
    task.wait(0.1)
    
    -- Select affordable bait
    local selectedBait = (function()
        local chosen = chooseAffordableBait(FishingConfig.SelectedBait)
        if type(chosen) == "table" then chosen = chosen[1] end
        return chosen or FishingConfig.SelectedBait
    end)()
    
    WindUI:Notify({ 
        Title = "🎣 Auto Fish Debug", 
        Content = "🎯 Using bait: " .. tostring(selectedBait) .. " at position: " .. tostring(FishingConfig.FishingPosition), 
        Duration = 2 
    })
    
    local throwArgs = {
        "Throw",
        {
            Bait = selectedBait,
            Pos = FishingConfig.FishingPosition,
            NoMove = true -- hint for server, if supported
        }
    }
    
    local throwSuccess, throwErr = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer(unpack(throwArgs))
    end)
    
    if not throwSuccess then
        WindUI:Notify({ 
            Title = "🎣 Auto Fish Debug", 
            Content = "❌ Failed to throw fishing line: " .. tostring(throwErr), 
            Duration = 3 
        })
        return false
    end
    
    WindUI:Notify({ 
        Title = "🎣 Auto Fish Debug", 
        Content = "✅ Cast successful! Waiting for fish...", 
        Duration = 2 
    })
    
    FishingConfig.Stats.TotalCasts = FishingConfig.Stats.TotalCasts + 1
    return true
end

-- Enhanced fish collection system
local function collectNearbyFish()
    local playerRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not playerRootPart then return false end
    
    local playerPosition = playerRootPart.Position
    local collected = 0
    
    -- Look for fish models in workspace
    local function searchForFish(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("Model") and child.Name:lower():find("fish") then
                -- Check if fish belongs to player
                local userId = child:GetAttribute("UserId")
                if userId and tonumber(userId) == LocalPlayer.UserId then
                    -- Check distance
                    local fishPosition = child:GetPivot().Position
                    local distance = (fishPosition - playerPosition).Magnitude
                    
                    if distance <= FishingConfig.FishingRange * 2 then -- Larger collection range
                        -- Try to collect fish
                        local collectArgs = {"Collect", child.Name}
                        local success = pcall(function()
                            ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer(unpack(collectArgs))
                        end)
                        
                        if success then
                            collected = collected + 1
                            -- Collected fish
                        end
                    end
                end
            end
            -- Recursively search children
            if child:IsA("Folder") or child:IsA("Model") then
                searchForFish(child)
            end
        end
    end
    
    -- Search in multiple locations where fish might spawn
    searchForFish(workspace)
    local art = workspace:FindFirstChild("Art")
    if art then searchForFish(art) end
    
    if collected > 0 then
        -- Auto-collected fish
    end
    
    return collected > 0
end

local function pullFish()
    local args = {
        "POUT",
        {
            SUC = 1,
            NoMove = true
        }
    }
    
    local success, err = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer(unpack(args))
    end)
    
    if not success then
        -- Failed to pull fish
        unanchorPlayer() -- Unanchor if failed
        return false
    end
    
    -- Wait a moment for fish to be caught before collecting
    task.wait(0.5)
    
    -- Auto-collect fish
    local collectSuccess = collectNearbyFish()
    
    -- Unanchor player after fishing attempt
    if unanchorPlayer then
        pcall(unanchorPlayer)
    -- else unanchorPlayer is nil
    end
    
    FishingConfig.Stats.FishCaught = FishingConfig.Stats.FishCaught + 1
    FishingConfig.Stats.SuccessfulCasts = FishingConfig.Stats.SuccessfulCasts + 1
    FishingConfig.Stats.LastCatchTime = os.time()
    
    return true
end



-- Enhanced function to find the player's fishing object dynamically
local function findPlayerFishingObject()
    if not LocalPlayer then return nil end
    
    -- Method 1: Look for object with player's name
    local playerName = LocalPlayer.Name
    local playerObj = workspace:FindFirstChild(playerName)
    if playerObj then
        return playerObj
    end
    
    -- Method 2: Look for object with player's DisplayName
    if LocalPlayer.DisplayName and LocalPlayer.DisplayName ~= playerName then
        local displayObj = workspace:FindFirstChild(LocalPlayer.DisplayName)
        if displayObj then
            return displayObj
        end
    end
    
    -- Method 3: Look for object with player's UserId pattern
    local userId = LocalPlayer.UserId
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj:GetAttribute("UserId") == userId then
            return obj
        end
    end
    
    -- Method 4: Search for objects that might be fishing-related and belong to player
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") then
            local name = obj.Name:lower()
            -- Check if it contains fishing-related keywords and player identifier
            if (name:find("fish") or name:find("rod") or name:find("bait")) and 
               (name:find(playerName:lower()) or name:find(tostring(userId))) then
                return obj
            end
        end
    end
    
    -- Method 5: Look for any object that has AnimFish attribute (fishing objects)
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj:GetAttribute("AnimFish") then
            -- Additional check: see if it's related to the current player
            local objUserId = obj:GetAttribute("UserId")
            if objUserId == userId then
                return obj
            end
        end
    end
    
    return nil
end

local function waitForFishPull()
    -- We no longer rely on fishingObj/AnimFish; only Player attribute FishState
    
    local timeout = 20 -- Lower timeout to recycle faster if missed
    local startTime = tick()
    local lastState = nil
    
    -- Wait for FishState to be "Pull"
    while FishingConfig.AutoFishEnabled and (tick() - startTime) < timeout do
        local playerState = LocalPlayer:GetAttribute("FishState")
        
        -- Debug: show state changes
        if playerState ~= lastState then
            WindUI:Notify({ 
                Title = "🎣 FishState", 
                Content = "State changed: " .. tostring(lastState) .. " → " .. tostring(playerState), 
                Duration = 2 
            })
            lastState = playerState
        end
        
        if tostring(playerState) == "Pull" then
            WindUI:Notify({ 
                Title = "🎣 Auto Fish Debug", 
                Content = "✅ Fish ready to pull! State = " .. tostring(playerState), 
                Duration = 2 
            })
            return true
        end
        task.wait(0.05)
    end
    
    WindUI:Notify({ 
        Title = "🎣 Auto Fish Debug", 
        Content = "⏰ Fishing timeout reached. Last FishState: " .. tostring(lastState), 
        Duration = 3 
    })
    return false
end

local function runAutoFish()
    -- Starting auto fish loop
    while FishingConfig.AutoFishEnabled do
        local startOk = startFishing()
        if startOk then
            local pullOk = waitForFishPull()
            if pullOk then
                pullFish()
            end
        end
        -- Faster looping between casts
        task.wait(FishingConfig.DelayBetweenCasts or 0.5)
    end
end

function FishingSystem.Start()
    if FishingSystem.Active then return end
    
    FishingSystem.Active = true
    FishingConfig.AutoFishEnabled = true
    FishingConfig.Stats.SessionStartTime = os.time()
    -- Freeze player for the whole auto-fishing session
    pcall(anchorPlayer)
    
    FishingSystem.Thread = task.spawn(runAutoFish)
    
    WindUI:Notify({ 
        Title = "🎣 Auto Fish", 
        Content = "Started fishing around player! Player will be anchored during fishing. 🎉", 
        Duration = 3 
    })
end

function FishingSystem.Stop()
    if not FishingSystem.Active then return end
    
    FishingSystem.Active = false
    FishingConfig.AutoFishEnabled = false
    
    -- Make sure to unanchor player when stopping
    pcall(unanchorPlayer)
    
    if FishingSystem.Thread then
        task.cancel(FishingSystem.Thread)
        FishingSystem.Thread = nil
    end
    
    local sessionTime = os.time() - FishingConfig.Stats.SessionStartTime
    local sessionMinutes = math.floor(sessionTime / 60)
    WindUI:Notify({ 
        Title = "🎣 Auto Fish", 
        Content = string.format("🛑 Stopped! Session: %dm | Fish: %d | Player unanchored", sessionMinutes, FishingConfig.Stats.FishCaught), 
        Duration = 3 
    })
end

-- UI Elements
local baitDropdown = nil
local autoFishToggle = nil
local statsLabel = nil
local currentPosLabel = nil

-- Function to update the current position display
function updateCurrentPositionDisplay()
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
        -- No dependencies provided
        return
    end
    
    WindUI = dependencies.WindUI
    Tabs = dependencies.Tabs
    Config = dependencies.Config -- Can be nil
    
    -- Validate critical dependencies
    if not WindUI then
        -- WindUI is required but not provided
        return
    end
    
    if not Tabs or not Tabs.FishTab then
        -- Tabs.FishTab is required but not provided
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
        Desc = "Choose fishing bait. If too expensive, we’ll fallback one step cheaper.",
        Values = #AvailableBaits > 0 and AvailableBaits or {"FishingBait1", "FishingBait2", "FishingBait3"},
        Default = FishingConfig.SelectedBait,
        Callback = function(selected)
            local chosen, downgraded = chooseAffordableBait(selected)
            FishingConfig.SelectedBait = chosen
            if downgraded and chosen ~= selected then
                WindUI:Notify({
                    Title = "🎣 Bait Adjusted",
                    Content = "Not enough money. Using cheaper bait: " .. tostring(chosen),
                    Duration = 3
                })
                pcall(function() baitDropdown:Select(chosen) end)
            else
                WindUI:Notify({ 
                    Title = "🎣 Bait Selected", 
                    Content = "Selected: " .. tostring(chosen), 
                    Duration = 2 
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
        Value = {
            Min = 1,
            Max = 10,
            Default = FishingConfig.DelayBetweenCasts,
        },
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
            -- Try to register with autoSystemsConfig if available, fallback to main config
            if dependencies.autoSystemsConfig then
                dependencies.autoSystemsConfig:Register("autoFishEnabled", autoFishToggle)
                -- Registered with AutoSystems config
            else
                Config:Register("autoFishEnabled", autoFishToggle)
                -- Registered with main config
            end
        end)
    elseif not Config then
        -- Config system not available, settings won't be saved
    end
    
    -- Start stats update loop
    task.spawn(function()
        while true do
            updateStats()
            task.wait(2)
        end
    end)
    
    -- Auto Fish System initialized successfully
end

-- Cleanup function
function AutoFishSystem.Cleanup()
    FishingSystem.Stop()
    
    -- Make sure player is unanchored
    unanchorPlayer()
    
    -- Auto Fish System cleaned up successfully
end

return AutoFishSystem
