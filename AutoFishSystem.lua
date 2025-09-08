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
local lastCastPos = nil
local lastCastPosAt = 0
local controlsRef = nil
local safeCF = nil

-- Config
local FishingConfig = {
    SelectedBait = "FishingBait1",
    AutoFishEnabled = false,
	VerticalOffset = 10,
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
		hum.WalkSpeed = 16
		hum.JumpPower = 50
	end
	if hrp then hrp.Anchored = false end
        pcall(function()
		if controlsRef and controlsRef.Enable then controlsRef:Enable() end
		controlsRef = nil
    end)
	safeCF = nil
end

-- Minimal cast loop: Focus -> Throw -> POUT -> repeat (no waits)
local function getCachedCastPos()
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
	if not ensureFishRobFocus() then return end
	-- Start fishing state after focus
    pcall(function()
        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer("Start")
    end)
	local pos = getCachedCastPos()
	local bait = FishingConfig.SelectedBait or "FishingBait1"
	pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer("Throw", { Bait = bait, Pos = pos, NoMove = true })
	end)
	pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer("POUT", { SUC = 1, NoMove = true })
	end)
end

local function loopCast()
	while active do
		castOnce()
		-- no delays for maximum throughput
		RunService.Heartbeat:Wait()
    end
end

-- Public API
function AutoFishSystem.SetEnabled(state)
	if state then
		if active then return end
		active = true
    FishingConfig.AutoFishEnabled = true
		lastCastPos = nil
		lastCastPosAt = 0
		anchorPlayer()
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
		unanchorPlayer()
		lastCastPos = nil
		lastCastPosAt = 0
		pcall(function() shared.LastFishPosList = nil end)
    end
end

function AutoFishSystem.SetBait(baitId)
	if baitId and tostring(baitId) ~= "" then
		FishingConfig.SelectedBait = tostring(baitId)
		pcall(function() if baitDropdown then baitDropdown:Select(FishingConfig.SelectedBait) end end)
    end
end

-- Get current state (for config saving)
function AutoFishSystem.GetEnabled()
	return FishingConfig.AutoFishEnabled or false
end

function AutoFishSystem.GetBait()
	return FishingConfig.SelectedBait or "FishingBait1"
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
		Desc = "Choose bait; loop is continuous.",
		Values = {"FishingBait1","FishingBait2","FishingBait3"},
        Default = FishingConfig.SelectedBait,
		Callback = function(sel)
			AutoFishSystem.SetBait(sel)
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

-- Get config elements for WindUI ConfigManager registration
function AutoFishSystem.GetConfigElements()
	if not (autoFishToggle and baitDropdown) then return {} end
	
	return {
		-- Auto Fish Toggle with custom Get/Set
		autoFishToggleElement = {
			Get = function() 
				return AutoFishSystem.GetEnabled()
			end,
			Set = function(value) 
				AutoFishSystem.SetEnabled(value)
				-- Update UI toggle to match
				if autoFishToggle and autoFishToggle.SetValue then
					pcall(function()
						autoFishToggle:SetValue(value)
					end)
				end
			end
		},
		
		-- Bait Selection with custom Get/Set  
		autoFishBaitElement = {
			Get = function() 
				return AutoFishSystem.GetBait()
			end,
			Set = function(value) 
				AutoFishSystem.SetBait(value or "FishingBait1")
				-- Update UI dropdown to match
				if baitDropdown and baitDropdown.SetValue then
					pcall(function()
						baitDropdown:SetValue(value or "FishingBait1")
					end)
				end
			end
		}
	}
end

function AutoFishSystem.Cleanup()
	AutoFishSystem.SetEnabled(false)
end

return AutoFishSystem
