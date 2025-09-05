-- AutoSellSystem.lua - Auto Sell functionality for Build A Zoo
-- Scans PlayerGui.Data.Pets for unplaced pets (no "D" attribute) and sells them via PetRE

local AutoSellSystem = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Dependencies (injected via Init)
local WindUI, Tabs, Config

-- Remotes (cached)
local Remotes = ReplicatedStorage:WaitForChild("Remote", 5)
local PetRE = Remotes and Remotes:FindFirstChild("PetRE")

-- State
local autoSellEnabled = false
local autoSellThread = nil
local sellMutations = false -- false = keep mutated (do not sell), true = sell mutated
local sessionLimit = 0 -- 0 = unlimited
local sessionSold = 0

-- UI refs
local statusParagraph
local mutationDropdown
local autoSellToggle
local sessionLimitInput

-- Helpers
local function getPetContainer()
	local localPlayer = Players.LocalPlayer
	local pg = localPlayer and localPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	return data and data:FindFirstChild("Pets") or nil
end

local function isUnplacedPet(petNode)
	if not petNode then return false end
	local d = petNode:GetAttribute("D")
	return d == nil or tostring(d) == ""
end

local function isMutated(petNode)
	if not petNode then return false end
	local m = petNode:GetAttribute("M")
	return m ~= nil and tostring(m) ~= ""
end

local function sellPetByUid(petUid)
	if not PetRE then return false end
	local ok = pcall(function()
		PetRE:FireServer("Sell", petUid)
	end)
	return ok == true
end

-- Status
local sellStats = {
	totalSold = 0,
	lastAction = "Idle",
	lastSold = nil,
	skippedMutations = 0,
	scanned = 0,
}

local function updateStatus()
	if not statusParagraph then return end
	local desc = string.format(
		"Sold: %d | Scanned: %d | Skipped M: %d\nSession: %d/%s%s",
		sellStats.totalSold,
		sellStats.scanned,
		sellStats.skippedMutations,
		sessionSold,
		tostring(sessionLimit == 0 and "∞" or sessionLimit),
		sellStats.lastAction and ("\n" .. sellStats.lastAction) or ""
	)
	if statusParagraph.SetDesc then
		statusParagraph:SetDesc(desc)
	end
end

local function scanAndSell()
	sellStats.scanned = 0
	sellStats.skippedMutations = 0

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
		sellStats.scanned += 1

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
				sessionSold += 1
				sellStats.lastSold = uid
				sellStats.lastAction = "✅ Sold " .. uid
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
	-- Create new tab
	Tabs.SellTab = Tabs.MainSection:Tab({ Title = "💸 | Auto Sell" })

	Tabs.SellTab:Paragraph({
		Title = "How it works",
		Desc = "Sells unplaced pets (no D attribute) directly from PlayerGui.Data.Pets.",
		Image = "info",
		ImageSize = 14,
	})

	mutationDropdown = Tabs.SellTab:Dropdown({
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

	sessionLimitInput = Tabs.SellTab:Input({
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

	statusParagraph = Tabs.SellTab:Paragraph({
		Title = "Status",
		Desc = "Idle",
		Image = "activity",
		ImageSize = 16,
	})

	autoSellToggle = Tabs.SellTab:Toggle({
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
	Config = dependencies.Config

	AutoSellSystem.CreateUI()
	return AutoSellSystem
end

return AutoSellSystem


