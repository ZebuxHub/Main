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
local holdConn = nil
local isCasting = false

-- Forward declarations for functions referenced earlier
local updateCurrentPositionDisplay

-- Configuration
local FishingConfig = {
    SelectedBait = "FishingBait1",
    FishingPosition = Vector3.new(0, 0, 0),
    AutoFishEnabled = false,
	DelayBetweenCasts = 0,
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
    PartCollideState = {}
}

-- Fishing Bait Configuration
local FishingBaitConfig = {}
local AvailableBaits = {}

-- Ensure Focus helpers (hold FishRob)
local function readHoldUID()
	local lp = LocalPlayer
	if not lp then return nil end
	local attrVal = nil
	pcall(function()
		attrVal = lp:GetAttribute("HoldUID")
	end)
	if attrVal and tostring(attrVal) ~= "" then
		return tostring(attrVal)
	end
	local vobj = lp:FindFirstChild("HoldUID")
	if vobj and vobj:IsA("ValueBase") then
		local vv = vobj.Value
		if vv and tostring(vv) ~= "" then
			return tostring(vv)
		end
	end
	return nil
end

local function ensureFishRobFocus()
	local held = readHoldUID()
	if held == "FishRob" then return true end
	local ok = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer("Focus", "FishRob")
	end)
	return ok == true
end

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
-- Water detection system removed for minimal, instant-cast flow

 

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

-- findNearestWater removed

-- moveToWater removed

-- autoDetectAndMoveToWater removed

-- Mouse Position Tracking System
-- MouseTracker removed (no pin UI in minimal flow)

-- Flag System for Position Setting
-- FlagSystem removed (no pin/hologram UI)

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

        -- Reduce collisions on character to avoid physics push from flying eggs/parts
        pcall(function()
            FishingConfig.PartCollideState = {}
            for _, desc in ipairs(LocalPlayer.Character:GetDescendants()) do
                if desc:IsA("BasePart") then
                    FishingConfig.PartCollideState[desc] = desc.CanCollide
                    desc.CanCollide = false
                    desc.Massless = true
                    desc.CustomPhysicalProperties = PhysicalProperties.new(1, 1, 1)
                end
            end
            -- Keep HRP CanCollide false as well
            FishingConfig.PartCollideState[rootPart] = rootPart.CanCollide
            rootPart.CanCollide = false
        end)

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
            local hum = char:FindFirstChildOfClass("Humanoid")
            -- Hard lock: snap every frame and zero velocities, also cancel movement commands
            hrp.CFrame = target
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if hum and hum.Move then
                hum:Move(Vector3.new(0, 0, 0), true)
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
        -- Restore collisions to original state
        pcall(function()
            for part, prev in pairs(FishingConfig.PartCollideState or {}) do
                if part and part.Parent then
                    part.CanCollide = prev
                    part.Massless = false
                    part.CustomPhysicalProperties = PhysicalProperties.new(1, 0.3, 0.5)
                end
            end
            FishingConfig.PartCollideState = {}
        end)
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

-- startMouseTracking removed

-- stopMouseTracking removed

-- createFishingFlag removed

-- enableFlagDragging removed

-- startFlagPlacement removed

-- stopFlagPlacement removed

-- removeFishingFlag removed

-- Fishing System
local FishingSystem = {
    Active = false,
    Thread = nil
}

local function startFishing()
	-- Determine cast position: workspace.Sea CFrame if available, else above head
	local function getSeaCastPosition()
		local sea = workspace:FindFirstChild("Sea")
		if not sea then return nil end
		local cf = nil
		local ok, pivot = pcall(function() return sea:GetPivot() end)
		if ok and pivot then cf = pivot
		elseif sea:IsA("BasePart") then cf = sea.CFrame
		elseif sea.PrimaryPart then cf = sea.PrimaryPart.CFrame end
		return cf and cf.Position or nil
	end
	local seaPos = getSeaCastPosition()
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local defaultPos = hrp and (hrp.Position + Vector3.new(0, FishingConfig.VerticalOffset or 10, 0)) or Vector3.new()
	local castPos = seaPos or defaultPos
	FishingConfig.FishingPosition = castPos

	-- Ensure hold and throw immediately
	local held = readHoldUID()
	if held ~= "FishRob" then
		if not ensureFishRobFocus() then return false end
	end
    
    -- Select affordable bait
	local selectedBait = FishingConfig.SelectedBait or "FishingBait1"
	-- Throw ASAP
	isCasting = true
    local throwArgs = {
        "Throw",
        {
            Bait = selectedBait,
			Pos = castPos,
            NoMove = true -- hint for server, if supported
        }
    }
    
    local throwSuccess, throwErr = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer(unpack(throwArgs))
    end)
    
    if not throwSuccess then
		isCasting = false
        return false
    end
	-- removed statistics counter
    return true
end

-- Enhanced fish collection system
-- collectNearbyFish removed for instant recast flow

local function pullFish()
    local args = {
        "POUT",
        {
            SUC = 1,
            NoMove = true
        }
    }
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer(unpack(args))
    end)
    if not success then
        unanchorPlayer()
        return false
    end
    return true
end



-- Enhanced function to find the player's fishing object dynamically
-- Removed: findPlayerFishingObject (no longer used; we rely solely on FishState)

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
        
        if tostring(playerState) == "PULL" then
            return true
        end
        task.wait(0.05)
    end
    
    isCasting = false
    return false
end

local function runAutoFish()
    -- Starting auto fish loop
    while FishingConfig.AutoFishEnabled do
        if not isCasting then
            startFishing()
        end
            local pullOk = waitForFishPull()
            if pullOk then
                pullFish()
            isCasting = false
            -- Immediate recast in next loop iteration (no waits)
            end
    end
end

function FishingSystem.Start()
    if FishingSystem.Active then return end
    
    FishingSystem.Active = true
    FishingConfig.AutoFishEnabled = true
    -- removed statistics session start
    -- Freeze player for the whole auto-fishing session
    pcall(anchorPlayer)
    
    FishingSystem.Thread = task.spawn(runAutoFish)
    -- Listen for HoldUID changes to throw ASAP when holding FishRob
    pcall(function()
        if holdConn then holdConn:Disconnect() end
        holdConn = Players.LocalPlayer:GetAttributeChangedSignal("HoldUID"):Connect(function()
            if not FishingConfig.AutoFishEnabled then return end
            if isCasting then return end
            if readHoldUID()=="FishRob" then startFishing() end
        end)
    end)
    
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
    pcall(function() if holdConn then holdConn:Disconnect() holdConn=nil end end)
    
    WindUI:Notify({ Title = "🎣 Auto Fish", Content = "🛑 Stopped! Player unanchored", Duration = 2 })
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
    -- removed statistics
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
    
    -- Silence all notifications from this module
    pcall(function()
        if WindUI and type(WindUI) == "table" then
            WindUI.Notify = function() end
        end
    end)

    -- Load fishing bait configuration
    loadFishingBaitConfig()
    
    -- Create Auto Fish Tab UI
    -- Minimal Fish UI: only Select Bait (keeps desc) and Auto Fish toggle
    task.wait(1)
    baitDropdown = Tabs.FishTab:Dropdown({
        Title = "Select Bait",
        Desc = "Choose fishing bait; will fallback to cheaper if unaffordable.",
        Values = #AvailableBaits > 0 and AvailableBaits or {"FishingBait1", "FishingBait2", "FishingBait3"},
        Default = FishingConfig.SelectedBait,
        Callback = function(selected)
            if selected and tostring(selected) ~= "" then
                FishingConfig.SelectedBait = tostring(selected)
            end
        end
    })
    
    autoFishToggle = Tabs.FishTab:Toggle({
        Title = "Auto Fish",
        Value = false,
        Callback = function(state)
            if state then
                FishingSystem.Start()
                pcall(function() ensureFishRobFocus() end)
                startFishing()
            else
                FishingSystem.Stop()
            end
        end
    })
    -- reset statistics button removed
    
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
    
    -- stats update loop removed
    
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
