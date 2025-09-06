-- AutoFishSystem.lua - Minimal continuous Focus -> Throw -> POUT loop
-- Author: Zebux
-- Version: 2.0 (minimal casting)

local AutoFishSystem = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

-- Module variables
local WindUI = nil
local Tabs = nil
local Config = nil

-- State
local holdConn = nil
local castThread = nil
local active = false
local baitDropdown = nil
local autoFishToggle = nil
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
	if not safeCF then safeCF = hrp.CFrame end
	hum.AutoRotate = false
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum:Move(Vector3.new(0,0,0), true)
	hrp.Anchored = true
	if freezeConn then freezeConn:Disconnect() freezeConn = nil end
	freezeConn = RunService.Heartbeat:Connect(function()
		if not active then return end
		local c = LocalPlayer.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if not root then return end
        pcall(function()
			root.Anchored = true
			if safeCF then root.CFrame = safeCF end
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			if h and h.Move then h:Move(Vector3.new(0,0,0), true) end
		end)
	end)
	-- Sink movement
        pcall(function()
		ContextActionService:BindAction("AFS_BlockMovement", function() return Enum.ContextActionResult.Sink end, false,
			Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space, Enum.KeyCode.LeftShift)
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
	safeCF = nil
end

-- Minimal cast loop: Focus -> Throw -> POUT -> repeat (no waits)
local function castOnce()
	if not ensureFishRobFocus() then return end
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local pos = hrp and (hrp.Position + Vector3.new(0, FishingConfig.VerticalOffset, 0)) or Vector3.new()
	local bait = FishingConfig.SelectedBait or "FishingBait1"
                pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer("Throw", { Bait = bait, Pos = pos, NoMove = true })
	end)
    pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer("POUT", { SUC = 1, NoMove = true })
	end)
	-- Wait 2 seconds after POUT, then re-focus FishRob before next cycle
	task.wait(2)
	pcall(ensureFishRobFocus)
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
    end
end

function AutoFishSystem.SetBait(baitId)
	if baitId and tostring(baitId) ~= "" then
		FishingConfig.SelectedBait = tostring(baitId)
		pcall(function() if baitDropdown then baitDropdown:Select(FishingConfig.SelectedBait) end end)
    end
end

-- UI integration
function AutoFishSystem.Init(dependencies)
	if not dependencies then return end
    WindUI = dependencies.WindUI
    Tabs = dependencies.Tabs
	Config = dependencies.Config
	if not (WindUI and Tabs and Tabs.FishTab) then return end
	-- Silence notifications for smooth flow
	pcall(function() if WindUI and type(WindUI) == "table" then WindUI.Notify = function() end end end)
    baitDropdown = Tabs.FishTab:Dropdown({
		Title = "Select Bait",
		Desc = "Choose bait; loop is continuous.",
		Values = {"FishingBait1","FishingBait2","FishingBait3"},
        Default = FishingConfig.SelectedBait,
		Callback = function(sel)
			AutoFishSystem.SetBait(sel)
        end
    })
    autoFishToggle = Tabs.FishTab:Toggle({
		Title = "Auto Fish",
        Value = false,
        Callback = function(state)
			AutoFishSystem.SetEnabled(state)
        end
    })
    if Config and autoFishToggle then
		pcall(function() Config:Register("autoFishEnabled", autoFishToggle) end)
	end
end

function AutoFishSystem.Cleanup()
	AutoFishSystem.SetEnabled(false)
end

return AutoFishSystem
