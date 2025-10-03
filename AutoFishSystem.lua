-- AutoFishSystem.lua - Minimal continuous Focus -> Throw -> POUT loop
-- Author: Zebux
-- Version: 3.0 (WindUI Config Compatible)

local AutoFishSystem = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

-- Module variables
local WindUI = nil
local FishTab = nil
local ConfigManager = nil

-- State
local holdConn = nil
local castThread = nil
local active = false
local baitDropdown = nil
local autoFishToggle = nil
local speedSlider = nil
local frostSpotToggle = nil
local frostSpotOnlyToggle = nil
local lastCastPos = nil
local lastCastPosAt = 0
local controlsRef = nil
local safeCF = nil
local frostSpotConnection = nil
local currentFrostSpotPos = nil

-- Config
local FishingConfig = {
    SelectedBait = nil,  -- No default bait - must be selected by user
    AutoFishEnabled = false,
	VerticalOffset = 10,
	CastDelay = 0.1,  -- Delay between casts in seconds (adjustable via slider)
	FrostSpotEnabled = false,  -- Cast at Frost Spot when available
	FrostSpotOnlyMode = false,  -- Stop fishing if no Frost Spot available
}

-- Focus helper
local function readHoldUID()
	local lp = LocalPlayer
	if not lp then return nil end
	local attrVal = nil
	pcall(function()
		attrVal = lp:GetAttribute("HoldUID")
	end)
	if attrVal and tostring(attrVal) ~= "" then return tostring(attrVal) end
	local vobj = lp:FindFirstChild("HoldUID")
	if vobj and vobj:IsA("ValueBase") and vobj.Value and tostring(vobj.Value) ~= "" then
		return tostring(vobj.Value)
	end
	return nil
end

local function ensureFishRobFocus()
	if readHoldUID() == "FishRob" then return true end
	local ok = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer("Focus", "FishRob")
	end)
	return ok == true
end

-- Anchor helpers (stable while fishing)
local freezeConn = nil
local function anchorPlayer()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then return end
	safeCF = hrp.CFrame
	hum.AutoRotate = false
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hrp.Anchored = true
	if freezeConn then freezeConn:Disconnect() freezeConn = nil end
	freezeConn = RunService.Heartbeat:Connect(function()
		if not active then return end
        pcall(function()
			local c = LocalPlayer.Character
			local root = c and c:FindFirstChild("HumanoidRootPart") or hrp
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if root then
				root.Anchored = true
				if safeCF then root.CFrame = safeCF end
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
			if h and h.Move then h:Move(Vector3.new(0,0,0), true) end
		end)
	end)
	-- Sink movement
        pcall(function()
		ContextActionService:BindAction("AFS_BlockMovement", function() return Enum.ContextActionResult.Sink end, false,
			Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space, Enum.KeyCode.LeftShift)
	end)
	-- Disable PlayerModule controls (mobile/gamepad/pc)
	pcall(function()
		local ps = LocalPlayer:FindFirstChild("PlayerScripts")
		local pm = ps and ps:FindFirstChild("PlayerModule")
		local cm = pm and pm:FindFirstChild("ControlModule")
		if cm then
			local controls = require(cm)
			controlsRef = controls
                    if controls and controls.Disable then controls:Disable() end
            end
        end)
end

local function unanchorPlayer()
            pcall(function()
                ContextActionService:UnbindAction("AFS_BlockMovement")
            end)
	if freezeConn then freezeConn:Disconnect() freezeConn = nil end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = true
		hum.WalkSpeed = 35
		hum.JumpPower = 50
	end
	if hrp then hrp.Anchored = false end
        pcall(function()
		if controlsRef and controlsRef.Enable then controlsRef:Enable() end
		controlsRef = nil
    end)
	safeCF = nil
end

-- Frost Spot Detection (optimized with event-based monitoring)
local frostSpotWatchers = {} -- Store connections for cleanup

local function getFrostSpotPosition(fxSpecial)
	if not fxSpecial then return nil end
	
	-- Try to get position from Scope first
	local scope = fxSpecial:FindFirstChild("Scope")
	if scope and scope:IsA("BasePart") then
		return scope.CFrame.Position
	elseif fxSpecial:IsA("BasePart") then
		return fxSpecial.Position
	end
	
	return nil
end

local isAnchored = false

local function onFrostSpotAdded(fxSpecial, fishPoint)
	if not active or not FishingConfig.FrostSpotEnabled then return end
	
	-- Get and cache the Frost Spot position
	local pos = getFrostSpotPosition(fxSpecial)
	if pos then
		currentFrostSpotPos = pos
		print("[AutoFish] 🧊 Frost Spot detected at:", fishPoint.Name)
		
		-- If in ONLY Mode and not anchored yet, anchor now
		if FishingConfig.FrostSpotOnlyMode and not isAnchored then
			anchorPlayer()
			isAnchored = true
		end
		
		-- Monitor for when it's removed
		local removeConn
		removeConn = fxSpecial.AncestryChanged:Connect(function(_, parent)
			if not parent then
				-- Frost Spot removed
				currentFrostSpotPos = nil
				print("[AutoFish] ❄️ Frost Spot disappeared")
				
				-- If in ONLY Mode, unanchor until next Frost Spot
				if FishingConfig.FrostSpotOnlyMode and isAnchored then
					unanchorPlayer()
					isAnchored = false
				end
				
				if removeConn then
					removeConn:Disconnect()
					removeConn = nil
				end
			end
		end)
		
		-- Store connection for cleanup
		table.insert(frostSpotWatchers, removeConn)
	end
end

local function setupFrostSpotMonitoring()
	-- Clean up existing watchers
	for _, conn in ipairs(frostSpotWatchers) do
		if conn then conn:Disconnect() end
	end
	frostSpotWatchers = {}
	
	if frostSpotConnection then
		frostSpotConnection:Disconnect()
		frostSpotConnection = nil
	end
	
	if not FishingConfig.FrostSpotEnabled then
		currentFrostSpotPos = nil
		return
	end
	
	-- Find FishPoints container
	local fishPoints = workspace:FindFirstChild("FishPoints")
	if not fishPoints then return end
	
	-- Check existing Frost Spots (in case one is already active)
	for _, fishPoint in ipairs(fishPoints:GetChildren()) do
		if fishPoint.Name:match("^FishPoint%d+$") then
			local existingFX = fishPoint:FindFirstChild("FX_Fish_Special")
			if existingFX then
				onFrostSpotAdded(existingFX, fishPoint)
			end
		end
	end
	
	-- Set up event-based monitoring for NEW Frost Spots
	-- This only fires when FX_Fish_Special is ADDED, not every frame!
	frostSpotConnection = fishPoints.DescendantAdded:Connect(function(descendant)
		if not active or not FishingConfig.FrostSpotEnabled then return end
		
		-- Check if this is a FX_Fish_Special being added
		if descendant.Name == "FX_Fish_Special" then
			local fishPoint = descendant.Parent
			if fishPoint and fishPoint.Name:match("^FishPoint%d+$") then
				-- Small delay to let the Scope load
				task.wait(0.1)
				onFrostSpotAdded(descendant, fishPoint)
			end
		end
	end)
end

-- Minimal cast loop: Focus -> Throw -> POUT -> repeat (no waits)
local function getCachedCastPos()
	-- Priority 1: Use Frost Spot if enabled and available
	if FishingConfig.FrostSpotEnabled and currentFrostSpotPos then
		pcall(function()
			shared.LastFishPosList = { { position = currentFrostSpotPos } }
		end)
		return currentFrostSpotPos
	end
	
	-- Priority 2: If Frost Spot Only Mode is enabled and no Frost Spot available, return nil (don't cast)
	if FishingConfig.FrostSpotOnlyMode and FishingConfig.FrostSpotEnabled and not currentFrostSpotPos then
		return nil -- Don't cast when waiting for Frost Spot in Only Mode
	end
	
	-- Priority 3: Use cached position above player (normal mode)
	local now = tick()
	if (not lastCastPos) or (now - (lastCastPosAt or 0) >= 5) then
		local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		lastCastPos = hrp and (hrp.Position + Vector3.new(0, FishingConfig.VerticalOffset, 0)) or Vector3.new()
		lastCastPosAt = now
    pcall(function()
			shared.LastFishPosList = { { position = lastCastPos } }
		end)
	end
	return lastCastPos
end

local function castOnce()
	-- Check if bait is selected
	if not FishingConfig.SelectedBait or FishingConfig.SelectedBait == "" then
		warn("[AutoFish] No bait selected! Please select a bait first.")
		return false
	end
	
	-- Get casting position
	local pos = getCachedCastPos()
	
	-- If Frost Spot Only Mode is active and no position available, skip casting
	if not pos then
		-- In Frost Spot Only Mode, waiting for Frost Spot to appear
		return false
	end
	
	if not ensureFishRobFocus() then return false end
	
	-- Start fishing state after focus
    pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer("Start")
    end)
	
	local bait = FishingConfig.SelectedBait
	pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer("Throw", { Bait = bait, Pos = pos, NoMove = true })
	end)
	pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer("POUT", { SUC = 1, NoMove = true })
	end)
	return true
end

local function loopCast()
	while active do
		local success = castOnce()
		if not success then
			-- If cast failed (waiting for Frost Spot or no bait)
			-- Wait a bit longer to avoid spam
			task.wait(2)
		else
			-- Wait based on configured speed
			local delay = FishingConfig.CastDelay
			-- Ensure delay is a number
			if type(delay) == "table" and delay.Default then
				delay = delay.Default
			elseif type(delay) ~= "number" then
				delay = 0.1
			end
			
			if delay > 0 then
				task.wait(delay)
			else
				RunService.Heartbeat:Wait()
			end
		end
    end
end

-- Public API
function AutoFishSystem.SetEnabled(state)
	if state then
		if active then return end
		
		-- Debug: Show current bait state
		print("[AutoFish] 🔍 Attempting to start with bait:", FishingConfig.SelectedBait, "| Type:", type(FishingConfig.SelectedBait))
		
		-- ⚠️ Check if bait is selected - REQUIRED!
		if not FishingConfig.SelectedBait or FishingConfig.SelectedBait == "" then
			warn("[AutoFish] ❌ Cannot start - Please select a bait first! (FishingBait1, FishingBait2, or FishingBait3)")
			warn("[AutoFish] 🔍 Debug - Bait value:", FishingConfig.SelectedBait, "| Dropdown value:", baitDropdown and baitDropdown.Value or "nil")
			-- Turn off the toggle
			pcall(function() 
				if autoFishToggle then 
					autoFishToggle:SetValue(false)
				end
			end)
			return
		end
		
		print("[AutoFish] ✅ Starting with bait:", FishingConfig.SelectedBait)
		active = true
    FishingConfig.AutoFishEnabled = true
		lastCastPos = nil
		lastCastPosAt = 0
		currentFrostSpotPos = nil
		isAnchored = false
		
		-- Only anchor if Frost Spot ONLY Mode is NOT enabled
		if not FishingConfig.FrostSpotOnlyMode then
			anchorPlayer()
			isAnchored = true
		end
		
		setupFrostSpotMonitoring()
		if holdConn then holdConn:Disconnect() holdConn = nil end
		holdConn = Players.LocalPlayer:GetAttributeChangedSignal("HoldUID"):Connect(function()
			if active and readHoldUID() == "FishRob" then castOnce() end
		end)
		castThread = task.spawn(loopCast)
	else
    FishingConfig.AutoFishEnabled = false
		active = false
		if castThread then task.cancel(castThread) castThread = nil end
		if holdConn then holdConn:Disconnect() holdConn = nil end
		if frostSpotConnection then frostSpotConnection:Disconnect() frostSpotConnection = nil end
		-- Clean up frost spot watchers
		for _, conn in ipairs(frostSpotWatchers) do
			if conn then conn:Disconnect() end
		end
		frostSpotWatchers = {}
		if isAnchored then
			unanchorPlayer()
			isAnchored = false
		end
		lastCastPos = nil
		lastCastPosAt = 0
		currentFrostSpotPos = nil
		pcall(function() shared.LastFishPosList = nil end)
    end
end

function AutoFishSystem.SetBait(baitId)
	if baitId and tostring(baitId) ~= "" then
		FishingConfig.SelectedBait = tostring(baitId)
		pcall(function() if baitDropdown then baitDropdown:Select(FishingConfig.SelectedBait) end end)
    end
end

function AutoFishSystem.SetSpeed(delaySeconds)
	if delaySeconds and type(delaySeconds) == "number" and delaySeconds >= 0 then
		FishingConfig.CastDelay = delaySeconds
    end
end

function AutoFishSystem.SetFrostSpot(enabled)
	FishingConfig.FrostSpotEnabled = enabled
	pcall(function() if frostSpotToggle then frostSpotToggle:SetValue(enabled) end end)
	
	if active then
		setupFrostSpotMonitoring()
	end
end

function AutoFishSystem.SetFrostSpotOnlyMode(enabled)
	FishingConfig.FrostSpotOnlyMode = enabled
	pcall(function() if frostSpotOnlyToggle then frostSpotOnlyToggle:SetValue(enabled) end end)
	
	-- Handle anchoring state when toggling ONLY mode while fishing
	if active then
		if enabled then
			-- Entering ONLY mode - unanchor until Frost Spot appears
			if isAnchored and not currentFrostSpotPos then
				unanchorPlayer()
				isAnchored = false
				print("[AutoFish] ❄️ ONLY Mode enabled - unanchoring until Frost Spot appears")
			end
		else
			-- Exiting ONLY mode - anchor normally
			if not isAnchored then
				anchorPlayer()
				isAnchored = true
				print("[AutoFish] ❄️ ONLY Mode disabled - anchoring for normal fishing")
			end
		end
	end
end

-- Get current state (for config saving)
function AutoFishSystem.GetEnabled()
	return FishingConfig.AutoFishEnabled or false
end

function AutoFishSystem.GetBait()
	return FishingConfig.SelectedBait  -- No fallback - returns nil if not set
end

function AutoFishSystem.GetSpeed()
	return FishingConfig.CastDelay or 0.1
end

function AutoFishSystem.GetFrostSpot()
	return FishingConfig.FrostSpotEnabled or false
end

function AutoFishSystem.GetFrostSpotOnlyMode()
	return FishingConfig.FrostSpotOnlyMode or false
end

-- UI integration
function AutoFishSystem.Init(dependencies)
	if not dependencies then return false end
    WindUI = dependencies.WindUI
    FishTab = dependencies.FishTab
	ConfigManager = dependencies.ConfigManager
	
	if not (WindUI and FishTab) then return false end
	
	-- Silence notifications for smooth flow
	pcall(function() if WindUI and type(WindUI) == "table" then WindUI.Notify = function() end end end)
	
    baitDropdown = FishTab:Dropdown({
		Title = "Select Bait",
		Desc = "⚠️ Required! Choose bait before starting.",
		Values = {"FishingBait1", "FishingBait2", "FishingBait3"},
        Value = FishingConfig.SelectedBait,
		Callback = function(sel)
			AutoFishSystem.SetBait(sel)
        end
    })
	
	speedSlider = FishTab:Slider({
		Title = "Cast Speed",
		Desc = "Delay between casts (0 = Maximum speed, 10 = Slowest)",
		Value = {
			Min = 0,
			Max = 10,
			Default = FishingConfig.CastDelay,
		},
		Callback = function(val)
			AutoFishSystem.SetSpeed(val)
		end
	})
	
	frostSpotToggle = FishTab:Toggle({
		Title = "🧊 Cast at Frost Spot",
		Desc = "Automatically cast at Frost Spot when it appears",
		Value = FishingConfig.FrostSpotEnabled,
		Callback = function(state)
			AutoFishSystem.SetFrostSpot(state)
		end
	})
	
	frostSpotOnlyToggle = FishTab:Toggle({
		Title = "❄️ Frost Spot ONLY Mode",
		Desc = "⚠️ STOPS fishing when no Frost Spot | (Enable '🧊 Cast at Frost Spot' first)",
		Value = FishingConfig.FrostSpotOnlyMode,
		Callback = function(state)
			AutoFishSystem.SetFrostSpotOnlyMode(state)
		end
	})
	
    autoFishToggle = FishTab:Toggle({
		Title = "Auto Fish",
        Value = FishingConfig.AutoFishEnabled,
        Callback = function(state)
			AutoFishSystem.SetEnabled(state)
        end
    })
	
	return true
end

-- Get UI elements for external registration (like other working elements)
function AutoFishSystem.GetUIElements()
	return {
		toggle = autoFishToggle,
		dropdown = baitDropdown,
		slider = speedSlider,
		frostSpotToggle = frostSpotToggle,
		frostSpotOnlyToggle = frostSpotOnlyToggle
	}
end

-- Get config elements for WindUI ConfigManager registration
function AutoFishSystem.GetConfigElements()
	if not (autoFishToggle and baitDropdown and speedSlider and frostSpotToggle and frostSpotOnlyToggle) then 
		print("AutoFish UI elements not ready for config")
		return {} 
	end
	
	print("AutoFish returning UI elements directly")
	return {
		-- Register the actual UI elements directly
		autoFishToggleElement = autoFishToggle,
		autoFishBaitElement = baitDropdown,
		autoFishSpeedElement = speedSlider,
		frostSpotToggle = frostSpotToggle,
		frostSpotOnlyToggle = frostSpotOnlyToggle
	}
end

function AutoFishSystem.Cleanup()
	AutoFishSystem.SetEnabled(false)
end

-- Sync loaded values from UI elements after config load
function AutoFishSystem.SyncLoadedValues()
	print("[AutoFish] 🔄 Starting SyncLoadedValues...")
	
	-- Sync bait selection
	if baitDropdown and baitDropdown.Value then
		local baitValue = baitDropdown.Value
		print("[AutoFish] 🔍 Dropdown.Value type:", type(baitValue), "| Value:", baitValue)
		
		-- Handle both table and string values
		if type(baitValue) == "table" then
			FishingConfig.SelectedBait = baitValue[1]
			print("[AutoFish] 📦 Extracted from table:", FishingConfig.SelectedBait)
		elseif type(baitValue) == "string" then
			FishingConfig.SelectedBait = baitValue
			print("[AutoFish] 📝 Set from string:", FishingConfig.SelectedBait)
		else
			warn("[AutoFish] ⚠️ Unexpected bait value type:", type(baitValue))
		end
		print("[AutoFish] ✅ Synced Bait Selection:", FishingConfig.SelectedBait)
	else
		warn("[AutoFish] ⚠️ No dropdown or dropdown.Value is nil!")
		print("[AutoFish] 🔍 Dropdown exists:", baitDropdown ~= nil, "| Value:", baitDropdown and baitDropdown.Value or "nil")
	end
	
	-- Sync speed slider
	if speedSlider and speedSlider.Value then
		local speedValue = speedSlider.Value
		-- Handle if Value is a table (config object) or a number
		if type(speedValue) == "number" then
			FishingConfig.CastDelay = speedValue
		elseif type(speedValue) == "table" and speedValue.Default then
			FishingConfig.CastDelay = speedValue.Default
		end
		print("[AutoFish] Synced Cast Speed:", FishingConfig.CastDelay, "| Type:", type(speedSlider.Value))
	end
	
	-- Sync frost spot toggle
	if frostSpotToggle and frostSpotToggle.Value ~= nil then
		FishingConfig.FrostSpotEnabled = frostSpotToggle.Value
		print("[AutoFish] Synced Frost Spot Enabled:", FishingConfig.FrostSpotEnabled)
	end
	
	-- Sync frost spot only mode toggle
	if frostSpotOnlyToggle and frostSpotOnlyToggle.Value ~= nil then
		FishingConfig.FrostSpotOnlyMode = frostSpotOnlyToggle.Value
		print("[AutoFish] Synced Frost Spot ONLY Mode:", FishingConfig.FrostSpotOnlyMode)
	end
end

return AutoFishSystem
