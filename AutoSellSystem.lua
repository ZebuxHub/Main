-- AutoSellSystem.lua - Auto Sell functionality for Build A Zoo
-- Scans PlayerGui.Data.Pets for unplaced pets (no "D" attribute) and sells them via PetRE

local AutoSellSystem = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Config modules for speed calculation
local ResPet, ResMutate, ResBigPet, ResBigFish
pcall(function()
	local Config = ReplicatedStorage:WaitForChild("Config", 5)
	if Config then
		ResPet = require(Config:WaitForChild("ResPet"))
		ResMutate = require(Config:WaitForChild("ResMutate"))
		ResBigPet = require(Config:WaitForChild("ResBigPetScale"))
		ResBigFish = require(Config:WaitForChild("ResBigFishScale"))
	end
end)

-- Dependencies (injected via Init)
local WindUI, Tabs, MainTab, Config

-- Remotes (cached)
local Remotes = ReplicatedStorage:WaitForChild("Remote", 5)
local PetRE = Remotes and Remotes:FindFirstChild("PetRE")

-- State
local autoSellEnabled = false
local autoSellThread = nil
local sellMutations = false -- false = keep mutated (do not sell), true = sell mutated
local sellMode = "Pets Only" -- "Pets Only", "Eggs Only", "Both Pets & Eggs"
local speedThreshold = 0 -- 0 = disabled, >0 = minimum speed required
local sessionLimit = 0 -- 0 = unlimited
local sessionSold = 0

-- UI refs
local statusParagraph
local mutationDropdown
local sellModeDropdown
local speedThresholdInput
local autoSellToggle
local sessionLimitInput

-- Helpers
local function getPetContainer()
	local localPlayer = Players.LocalPlayer
	local pg = localPlayer and localPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	return data and data:FindFirstChild("Pets") or nil
end

local function getEggContainer()
	local localPlayer = Players.LocalPlayer
	local pg = localPlayer and localPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	return data and data:FindFirstChild("Egg") or nil
end

local function isUnplacedPet(petNode)
	if not petNode then return false end
	local d = petNode:GetAttribute("D")
	return d == nil or tostring(d) == ""
end

local function isAvailableEgg(eggNode)
	if not eggNode then return false end
	-- Eggs are available if they have no children (not being hatched) AND no "D" attribute
	local d = eggNode:GetAttribute("D")
	local hasChildren = #eggNode:GetChildren() > 0
	return (d == nil or tostring(d) == "") and not hasChildren
end

local function isMutated(node)
	if not node then return false end
	local m = node:GetAttribute("M")
	return m ~= nil and tostring(m) ~= ""
end

local function sellPetByUid(petUid)
	if not PetRE then return false end
	local ok = pcall(function()
		PetRE:FireServer("Sell", petUid)
	end)
	return ok == true
end

local function sellEggByUid(eggUid)
	-- Use PetRE with correct parameters for egg selling
	if not PetRE then return false end
	local ok = pcall(function()
		local args = {
			"Sell",
			eggUid,
			true -- Third parameter indicates it's an egg
		}
		PetRE:FireServer(unpack(args))
	end)
	return ok == true
end

-- Speed calculation functions (based on user's formula)
local function getBigLevel(exp, typ)
	if not ResBigPet or not ResBigFish then return 0, nil end
	local tbl = (typ == "Fish") and ResBigFish or ResBigPet
	if not tbl or not tbl.__index then return 0, nil end
	
	local stage, def = 0, nil
	for _, idx in pairs(tbl.__index) do
		local row = tbl[idx]
		if row and row.EXP and row.EXP <= exp then
			stage, def = idx, row
		else
			break
		end
	end
	return stage, def
end

local function calculateNormalPetSpeed(def, attrs, benefitMax, externalMult)
	if not def or not attrs then return 0 end
	
	local base = tonumber(def.ProduceRate) or 0
	local v = tonumber(attrs.V) or 0 -- 0..10000
	local grow = ((benefitMax - 1) * ((v * 1e-4) ^ 2.24) + 1)
	
	local mut = 1
	local M = attrs.M
	if M and ResMutate and ResMutate[M] and ResMutate[M].ProduceRate then
		mut = ResMutate[M].ProduceRate
	end
	
	externalMult = externalMult or 1
	local final = math.floor(base * grow * mut * externalMult + 1e-9)
	return final
end

local function calculateBigPetSpeed(petNode, attrs)
	if not petNode or not attrs then return 0 end
	
	local _, def = getBigLevel(tonumber(attrs.BPV) or 0, attrs.BPT or "Normal")
	if not def then return 0 end
	
	local base = tonumber(def.Produce) or 0
	local bigRate = 1
	
	-- Find MT_* attributes and get highest BigRate
	for name, _ in pairs(petNode:GetAttributes()) do
		if string.sub(name, 1, 3) == "MT_" then
			local id = string.split(name, "_")[2]
			if ResMutate and ResMutate[id] and ResMutate[id].BigRate then
				bigRate = math.max(bigRate, ResMutate[id].BigRate)
			end
		end
	end
	
	-- Big pets don't floor and don't multiply by v71
	local final = base * bigRate
	return final
end

local function getPetSpeed(petNode)
	if not petNode then return 0 end
	-- Prefer real value from UI using the pet UID
	local uid = petNode.Name
	local lp = Players.LocalPlayer
	local pg = lp and lp:FindFirstChild("PlayerGui")
	local ss = pg and pg:FindFirstChild("ScreenStorage")
	local frame = ss and ss:FindFirstChild("Frame")
	local content = frame and frame:FindFirstChild("ContentPet")
	local scroll = content and content:FindFirstChild("ScrollingFrame")
	local item = scroll and scroll:FindFirstChild(uid)
	local btn = item and item:FindFirstChild("BTN")
	local stat = btn and btn:FindFirstChild("Stat")
	local price = stat and stat:FindFirstChild("Price")
	local valueLabel = price and price:FindFirstChild("Value")
	local txt = valueLabel and valueLabel:IsA("TextLabel") and valueLabel.Text or nil
	if not txt and price and price:IsA("TextLabel") then
		txt = price.Text
	end
	if txt then
		local n = tonumber((txt:gsub("[^%d]", ""))) or 0
		return n
	end
	return 0
end

-- Helper function to parse speed threshold with K/M/B/T suffixes
local function parseSpeedThreshold(text)
	if not text or type(text) ~= "string" then return 0 end
	
	local cleanText = text:gsub("[$€£¥₹/s,]", ""):gsub("^%s*(.-)%s*$", "%1")
	local number, suffix = cleanText:match("^([%d%.]+)([KkMmBbTt]?)$")
	
	if not number then
		number = cleanText:match("([%d%.]+)")
	end
	
	local numValue = tonumber(number)
	if not numValue then return 0 end
	
	if suffix then
		local lowerSuffix = string.lower(suffix)
		if lowerSuffix == "k" then
			numValue = numValue * 1000
		elseif lowerSuffix == "m" then
			numValue = numValue * 1000000
		elseif lowerSuffix == "b" then
			numValue = numValue * 1000000000
		elseif lowerSuffix == "t" then
			numValue = numValue * 1000000000000
		end
	end
	
	return numValue
end

-- Status
local sellStats = {
	totalSold = 0,
	petsSold = 0,
	eggsSold = 0,
	lastAction = "Idle",
	lastSold = nil,
	skippedMutations = 0,
	skippedSpeed = 0,
	scannedPets = 0,
	scannedEggs = 0,
}

local function updateStatus()
	if not statusParagraph then return end
	local totalScanned = sellStats.scannedPets + sellStats.scannedEggs
	local speedText = speedThreshold > 0 and ("Sell if speed≤" .. tostring(speedThreshold) .. " | ") or ""
	local desc = string.format(
		"Sold: %d (P:%d E:%d) | Scanned: %d\nSkipped M: %d S: %d | %sMode: %s\nSession: %d/%s%s",
		sellStats.totalSold,
		sellStats.petsSold,
		sellStats.eggsSold,
		totalScanned,
		sellStats.skippedMutations,
		sellStats.skippedSpeed,
		speedText,
		sellMode,
		sessionSold,
		tostring(sessionLimit == 0 and "∞" or sessionLimit),
		sellStats.lastAction and ("\n" .. sellStats.lastAction) or ""
	)
	if statusParagraph.SetDesc then
		statusParagraph:SetDesc(desc)
	end
end

local function scanAndSell()
	sellStats.scannedPets = 0
	sellStats.scannedEggs = 0
	sellStats.skippedMutations = 0
	sellStats.skippedSpeed = 0

	-- Scan pets if mode allows
	if sellMode == "Pets Only" or sellMode == "Both Pets & Eggs" then
		local pets = getPetContainer()
		if not pets then
			sellStats.lastAction = "Waiting for PlayerGui.Data.Pets"
			updateStatus()
			return
		end

		for _, node in ipairs(pets:GetChildren()) do
		if not autoSellEnabled then return end
		if sessionLimit > 0 and sessionSold >= sessionLimit then
			sellStats.lastAction = "Session limit reached"
			updateStatus()
			if autoSellToggle and autoSellToggle.SetValue then
				autoSellToggle:SetValue(false)
			else
				autoSellEnabled = false
			end
			return
		end
		sellStats.scannedPets += 1

				local uid = node.Name
				local unplaced = isUnplacedPet(node)
				if unplaced then
					local mutated = isMutated(node)
					if mutated and not sellMutations then
						sellStats.skippedMutations += 1
						sellStats.lastAction = "Skipped mutated pet " .. uid
						updateStatus()
						continue
					end

					-- Check speed threshold if enabled
					if speedThreshold > 0 then
						local petSpeed = getPetSpeed(node)
						if petSpeed < speedThreshold then
							sellStats.skippedSpeed += 1
							sellStats.lastAction = "Skipped slow pet " .. uid .. " (speed: " .. tostring(petSpeed) .. ")"
							updateStatus()
							continue
						end
					end

			local ok = sellPetByUid(uid)
			if ok then
				sellStats.totalSold += 1
				sellStats.petsSold += 1
				sessionSold += 1
				sellStats.lastSold = uid
				sellStats.lastAction = "✅ Sold pet " .. uid
				if WindUI then
					WindUI:Notify({ Title = "💸 Auto Sell", Content = "Sold pet " .. uid, Duration = 2 })
				end
			else
				sellStats.lastAction = "❌ Failed selling " .. uid
			end
			updateStatus()
			task.wait(0.15)

			-- Stop immediately if session limit reached after this sale
			if sessionLimit > 0 and sessionSold >= sessionLimit then
				if WindUI then
					WindUI:Notify({ Title = "💸 Auto Sell", Content = "Session limit reached (" .. tostring(sessionSold) .. "/" .. tostring(sessionLimit) .. ")", Duration = 3 })
				end
				if autoSellToggle and autoSellToggle.SetValue then
					autoSellToggle:SetValue(false)
				else
					autoSellEnabled = false
				end
				return
			end
		end
	end
	end

	-- Scan eggs if mode allows
	if sellMode == "Eggs Only" or sellMode == "Both Pets & Eggs" then
		local eggs = getEggContainer()
		if eggs then
			for _, node in ipairs(eggs:GetChildren()) do
				if not autoSellEnabled then return end
				if sessionLimit > 0 and sessionSold >= sessionLimit then
					sellStats.lastAction = "Session limit reached"
					updateStatus()
					if autoSellToggle and autoSellToggle.SetValue then
						autoSellToggle:SetValue(false)
					else
						autoSellEnabled = false
					end
					return
				end
				sellStats.scannedEggs += 1

				local uid = node.Name
				local available = isAvailableEgg(node)
				if available then
					local mutated = isMutated(node)
					if mutated and not sellMutations then
						sellStats.skippedMutations += 1
						sellStats.lastAction = "Skipped mutated egg " .. uid
						updateStatus()
						continue
					end

					local ok = sellEggByUid(uid)
					if ok then
						sellStats.totalSold += 1
						sellStats.eggsSold += 1
						sessionSold += 1
						sellStats.lastSold = uid
						sellStats.lastAction = "✅ Sold egg " .. uid
						if WindUI then
							WindUI:Notify({ Title = "💸 Auto Sell", Content = "Sold egg " .. uid, Duration = 2 })
						end
					else
						sellStats.lastAction = "❌ Failed selling egg " .. uid
					end
					updateStatus()
					-- slower for eggs
					task.wait(0.4)

					-- Check session limit
					if sessionLimit > 0 and sessionSold >= sessionLimit then
						if WindUI then
							WindUI:Notify({ Title = "💸 Auto Sell", Content = "Session limit reached (" .. tostring(sessionSold) .. "/" .. tostring(sessionLimit) .. ")", Duration = 3 })
						end
						if autoSellToggle and autoSellToggle.SetValue then
							autoSellToggle:SetValue(false)
						else
							autoSellEnabled = false
						end
						return
					end
				end
			end
		end
	end

	sellStats.lastAction = "Scan complete"
	updateStatus()
end

local function runAutoSell()
	while autoSellEnabled do
		local ok, err = pcall(function()
			scanAndSell()
		end)
		if not ok then
			sellStats.lastAction = "Error: " .. tostring(err)
			updateStatus()
			task.wait(1)
		else
			-- Short idle before next pass
			task.wait(1.0)
		end
	end
end

-- UI
function AutoSellSystem.CreateUI()
	-- Create Auto Sell section in MainTab
	MainTab:Section({ Title = "Auto Sell Pets", Icon = "dollar-sign" })

	sellModeDropdown = MainTab:Dropdown({
		Title = "🎯 Sell Mode",
		Desc = "What to sell",
		Values = { "Pets Only", "Eggs Only", "Both Pets & Eggs" },
		Value = "Pets Only",
		Multi = false,
		AllowNone = false,
		Callback = function(selection)
			if type(selection) == "table" then selection = selection[1] end
			sellMode = selection or "Pets Only"
			updateStatus()
		end
	})

	mutationDropdown = MainTab:Dropdown({
		Title = "🧬 Mutations",
		Desc = "Sell mutated or keep",
		Values = { "Sell mutated pets", "Keep mutated (don't sell)" },
		Value = "Keep mutated (don't sell)",
		Multi = false,
		AllowNone = false,
		Callback = function(selection)
			if type(selection) == "table" then selection = selection[1] end
			sellMutations = (selection == "Sell mutated pets")
		end
	})

	speedThresholdInput = MainTab:Input({
		Title = "⚡ Speed Threshold",
		Desc = "Sell if speed ≤ value",
		Value = "0",
		Callback = function(value)
			local parsedValue = parseSpeedThreshold(value)
			speedThreshold = parsedValue
			updateStatus()
		end
	})

	sessionLimitInput = MainTab:Input({
		Title = "Session Sell Limit",
		Desc = "Max sells this session",
		Value = "0",
		Callback = function(value)
			local n = tonumber(value)
			if not n then
				local cleaned = tostring(value):gsub("[^%d%.]", "")
				n = tonumber(cleaned) or 0
			end
			n = math.max(0, math.floor(n))
			sessionLimit = n
			updateStatus()
		end
	})

	statusParagraph = MainTab:Paragraph({
		Title = "Status",
		Desc = "Auto sell status",
		Image = "activity",
		ImageSize = 16,
	})

	autoSellToggle = MainTab:Toggle({
		Title = "💸 Auto Sell",
		Desc = "Sell pets not placed",
		Value = false,
		Callback = function(state)
			autoSellEnabled = state
			if state and not autoSellThread then
				sessionSold = 0
				autoSellThread = task.spawn(function()
					runAutoSell()
					autoSellThread = nil
				end)
				if WindUI then
					WindUI:Notify({ Title = "💸 Auto Sell", Content = "Started", Duration = 2 })
				end
			elseif not state and autoSellThread then
				if WindUI then
					WindUI:Notify({ Title = "💸 Auto Sell", Content = "Stopped", Duration = 2 })
				end
			end
		end
	})

	-- Register with shared config if available (for persistence)
	if Config then
		pcall(function()
			Config:Register("autoSellEnabled", autoSellToggle)
		end)
		pcall(function()
			Config:Register("autoSellMutationMode", mutationDropdown)
		end)
		pcall(function()
			Config:Register("autoSellSessionLimit", sessionLimitInput)
		end)
	end

	updateStatus()
end

-- Public API
function AutoSellSystem.Init(dependencies)
	WindUI = dependencies.WindUI
	Tabs = dependencies.Tabs
	MainTab = dependencies.MainTab
	Config = dependencies.Config

	AutoSellSystem.CreateUI()
	return AutoSellSystem
end

return AutoSellSystem


