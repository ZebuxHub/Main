-- AutoSellSystem.lua - Auto Sell functionality for Build A Zoo
-- Scans PlayerGui.Data.Pets for unplaced pets (no "D" attribute) and sells them via PetRE

local AutoSellSystem = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

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
local sessionLimit = 0 -- 0 = unlimited
local sessionSold = 0

-- UI refs
local statusParagraph
local mutationDropdown
local sellModeDropdown
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
	-- Eggs are available if they have no children (not being hatched)
	return #eggNode:GetChildren() == 0
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
	-- Try CharacterRE for egg selling (common pattern in Build A Zoo)
	local CharacterRE = Remotes and Remotes:FindFirstChild("CharacterRE")
	if not CharacterRE then return false end
	local ok = pcall(function()
		CharacterRE:FireServer("SellEgg", eggUid)
	end)
	return ok == true
end

-- Status
local sellStats = {
	totalSold = 0,
	petsSold = 0,
	eggsSold = 0,
	lastAction = "Idle",
	lastSold = nil,
	skippedMutations = 0,
	scannedPets = 0,
	scannedEggs = 0,
}

local function updateStatus()
	if not statusParagraph then return end
	local totalScanned = sellStats.scannedPets + sellStats.scannedEggs
	local desc = string.format(
		"Sold: %d (P:%d E:%d) | Scanned: %d | Skipped M: %d\nMode: %s | Session: %d/%s%s",
		sellStats.totalSold,
		sellStats.petsSold,
		sellStats.eggsSold,
		totalScanned,
		sellStats.skippedMutations,
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
					task.wait(0.15)

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
		Desc = "Choose what to sell automatically",
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
		Desc = "Choose whether to sell mutated pets (M attribute).",
		Values = { "Sell mutated pets", "Keep mutated (don't sell)" },
		Value = "Keep mutated (don't sell)",
		Multi = false,
		AllowNone = false,
		Callback = function(selection)
			if type(selection) == "table" then selection = selection[1] end
			sellMutations = (selection == "Sell mutated pets")
		end
	})

	sessionLimitInput = MainTab:Input({
		Title = "Session Sell Limit",
		Desc = "Max sells this session (0 = unlimited)",
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
		Desc = "Idle",
		Image = "activity",
		ImageSize = 16,
	})

	autoSellToggle = MainTab:Toggle({
		Title = "💸 Auto Sell Unplaced Pets",
		Desc = "Automatically sell pets without 'D' attribute (not placed).",
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


