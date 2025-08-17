-- AutoQuestSystem.lua
-- Adds Auto Quest automation with safe orchestration and WindUI integration

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local function safe(x, ...)
	local ok, res = pcall(x, ...)
	if ok then return res end
	return nil
end

local function getPlayerGui()
	return LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
end

local function getDataFolder()
	local pg = getPlayerGui()
	return pg and pg:FindFirstChild("Data")
end

local function getTasksRoot()
	local data = getDataFolder()
	local taskRoot = data and data:FindFirstChild("DinoEventTaskData")
	return taskRoot and taskRoot:FindFirstChild("Tasks")
end

local TaskDefs = {
	Task_1 = { CompleteType = "HatchEgg", CompleteValue = 5 },
	Task_3 = { CompleteType = "SellPet", CompleteValue = 5 },
	Task_4 = { CompleteType = "SendEgg", CompleteValue = 5 },
	Task_5 = { CompleteType = "BuyMutateEgg", CompleteValue = 1 },
	Task_7 = { CompleteType = "HatchEgg", CompleteValue = 10 },
	Task_8 = { CompleteType = "OnlineTime", CompleteValue = 900, RepeatCount = 6 },
}

local function readThreeTasks()
	local tasks = {}
	local root = getTasksRoot()
	if not root then return tasks end
	for i = 1, 3 do
		local slot = root:FindFirstChild(tostring(i))
		if slot then
			local id = slot:GetAttribute("Id")
			local progress = tonumber(slot:GetAttribute("Progress")) or 0
			local claimed = tonumber(slot:GetAttribute("ClaimedCount")) or 0
			table.insert(tasks, { slot = i, id = id, progress = progress, claimed = claimed })
		end
	end
	return tasks
end

local function claimTask(taskId)
	local args = { { event = "claimreward", id = taskId } }
	return pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("DinoEventRE"):FireServer(table.unpack(args))
	end)
end

-- Inventory helpers
local function getEggsInventory()
	local eggs = {}
	local data = getDataFolder()
	local eggFolder = data and data:FindChild("Egg") or data and data:FindFirstChild("Egg")
	if not eggFolder then return eggs end
	for _, inst in ipairs(eggFolder:GetChildren()) do
		if inst:IsA("Configuration") or inst:IsA("Folder") or inst.ClassName == "Configuration" then
			local uid = inst.Name
			local t = inst:GetAttribute("T")
			local m = inst:GetAttribute("M")
			if m == "Dino" then m = "Jurassic" end
			table.insert(eggs, { uid = uid, T = t, M = m })
		end
	end
	return eggs
end

local function getPetsInventory()
	local pets = {}
	local data = getDataFolder()
	local petsFolder = data and data:FindFirstChild("Pets")
	if not petsFolder then return pets end
	for _, inst in ipairs(petsFolder:GetChildren()) do
		if inst:IsA("Configuration") or inst.ClassName == "Configuration" then
			local uid = inst.Name
			local t = inst:GetAttribute("T")
			local m = inst:GetAttribute("M")
			if m == "Dino" then m = "Jurassic" end
			local lk = tonumber(inst:GetAttribute("LK")) or 0
			table.insert(pets, { uid = uid, T = t, M = m, LK = lk })
		end
	end
	return pets
end

-- Action helpers
local function focusUID(uid)
	local args = { "Focus", uid }
	return pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(table.unpack(args))
	end)
end

local function buyEgg(uid)
	local args = { "BuyEgg", uid }
	return pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(table.unpack(args))
	end)
end

local function giftToPlayer(player)
	return pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(player)
	end)
end

local function sellPet(uid)
	local args = { "Sell", uid }
	return pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("PetRE"):FireServer(table.unpack(args))
	end)
end

-- Belt scanning for mutated eggs (reads GUI/EggGUI/Mutate on belt models)
local function getAllBelts()
	local belts = {}
	local art = workspace:FindFirstChild("Art")
	if not art then return belts end
	for _, island in ipairs(art:GetChildren()) do
		local env = island:FindFirstChild("ENV")
		local conv = env and env:FindFirstChild("Conveyor")
		if conv then
			for i = 1, 9 do
				local c = conv:FindFirstChild("Conveyor" .. i)
				local b = c and c:FindFirstChild("Belt")
				if b then table.insert(belts, b) end
			end
		end
	end
	return belts
end

local function isModelMutated(model)
	local root = model and model:FindFirstChild("RootPart")
	local lbl = root and root:FindFirstChild("GUI/EggGUI/Mutate")
	if lbl and lbl:IsA("TextLabel") then
		local txt = lbl.Text or ""
		return txt ~= "" and txt ~= "?" and txt ~= "???"
	end
	return false
end

local function buyMutatedEggsOnce(maxBuys)
	local bought = 0
	for _, belt in ipairs(getAllBelts()) do
		for _, ch in ipairs(belt:GetChildren()) do
			if ch:IsA("Model") and isModelMutated(ch) then
				local uid = ch.Name
				buyEgg(uid)
				focusUID(uid)
				bought += 1
				if bought >= maxBuys then return bought end
				task.wait(0.25)
			end
		end
	end
	return bought
end

local function getPlayersList()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then table.insert(list, p.Name) end
	end
	table.sort(list)
	return list
end

local function pickTargetPlayer(mode, manualName)
	if mode == "Random" then
		local others = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then table.insert(others, p) end
		end
		if #others == 0 then return nil end
		return others[math.random(1, #others)]
	elseif mode == "Manual" then
		if not manualName or manualName == "" then return nil end
		return Players:FindFirstChild(manualName)
	else
		return Players:FindFirstChild(mode)
	end
end

local function toSet(list)
	local s = {}
	for _, v in ipairs(list or {}) do s[v] = true end
	return s
end

local function shouldSkipEgg(egg, exclTSet, exclMSet)
	if egg.T and exclTSet[egg.T] then return true end
	if egg.M and exclMSet[egg.M] then return true end
	return false
end

local function shouldSkipPet(pet, exclTSet, exclMSet)
	if tonumber(pet.LK) == 1 then return true end
	if pet.T and exclTSet[pet.T] then return true end
	if pet.M and exclMSet[pet.M] then return true end
	return false
end

local AutoQuest = {}

function AutoQuest.Init(ctx)
	local WindUI = ctx.WindUI
	local Window = ctx.Window
	local zebuxConfig = ctx.Config
	local waitForSettingsReady = ctx.waitForSettingsReady or function() end

	-- UI
	local Section = Window:Section({ Title = "📝 Auto Quest", Opened = true })
	local QuestTab = Section:Tab({ Title = "📝 | Auto Quest" })

	QuestTab:Paragraph({
		Title = "How it works",
		Desc = "Runs daily tasks automatically. Priority: BuyMutateEgg → HatchEgg → SendEgg → SellPet → OnlineTime. Uses exclusions for Send/Sell. Focus is called before gifting.",
		Image = "info",
		ImageSize = 18,
	})

	local autoQuestEnabled = false
	local autoQuestThread = nil

	local autoClaimToggle = QuestTab:Toggle({
		Title = "Auto-Claim Ready",
		Desc = "Claim tasks as soon as they are complete",
		Value = true,
		Callback = function(_) end
	})

	local autoRefreshToggle = QuestTab:Toggle({
		Title = "Auto-Refresh Task List",
		Desc = "Continuously refresh and watch tasks",
		Value = true,
		Callback = function(_) end
	})

	-- Target player controls
	local playerOptions = { "Random", "Manual" }
	for _, n in ipairs(getPlayersList()) do table.insert(playerOptions, n) end

	local targetPlayerMode = "Random"
	local targetPlayerDropdown = QuestTab:Dropdown({
		Title = "Target Player",
		Desc = "Pick who to gift to (Random excludes you)",
		Values = playerOptions,
		Value = "Random",
		Multi = false,
		AllowNone = false,
		Callback = function(val)
			targetPlayerMode = val
		end
	})

	local manualTargetInput = QuestTab:Input({
		Title = "Manual Username",
		Desc = "Only used if Target Player is Manual",
		Value = "",
		Callback = function(_) end
	})

	-- Exclusion dropdowns
	local function collectKnownEggT()
		local set = {}
		for _, e in ipairs(getEggsInventory()) do if e.T then set[e.T] = true end end
		local cfgFolder = safe(function() return ReplicatedStorage:WaitForChild("Config") end) or nil
		local resEgg = cfgFolder and cfgFolder:FindFirstChild("ResEgg")
		local tbl = resEgg and safe(function() return require(resEgg) end) or nil
		if type(tbl) == "table" then
			for k, v in pairs(tbl) do
				if type(k) ~= "string" or k:match("^_") then else
					local name = (type(v) == "table" and (v.Type or v.Name)) or tostring(k)
					set[tostring(name)] = true
				end
			end
		end
		local list = {}
		for n in pairs(set) do table.insert(list, n) end
		table.sort(list)
		return list
	end

	local function collectKnownMutations()
		local set = {}
		for _, e in ipairs(getEggsInventory()) do if e.M then set[e.M] = true end end
		for _, p in ipairs(getPetsInventory()) do if p.M then set[p.M] = true end end
		local cfgFolder = safe(function() return ReplicatedStorage:WaitForChild("Config") end) or nil
		local resMut = cfgFolder and cfgFolder:FindFirstChild("ResMutate")
		local tbl = resMut and safe(function() return require(resMut) end) or nil
		if type(tbl) == "table" then
			for k, v in pairs(tbl) do
				if type(k) ~= "string" or k:match("^_") then else
					local name = (type(v) == "table" and (v.Name or v.ID or v.Id)) or tostring(k)
					set[tostring(name)] = true
				end
			end
		end
		local list = {}
		for n in pairs(set) do table.insert(list, n) end
		table.sort(list)
		return list
	end

	local eggExclT = {}
	local eggExclM = {}
	local petExclT = {}
	local petExclM = {}

	local eggExcludeTDropdown = QuestTab:Dropdown({
		Title = "Exclude Egg T",
		Desc = "Don’t send eggs with these T names (empty = send all)",
		Values = collectKnownEggT(),
		Value = {},
		Multi = true,
		AllowNone = true,
		Callback = function(sel) eggExclT = sel end
	})

	local eggExcludeMDropdown = QuestTab:Dropdown({
		Title = "Exclude Egg Mutation M",
		Desc = "Don’t send eggs with these mutations (empty = allow all)",
		Values = collectKnownMutations(),
		Value = {},
		Multi = true,
		AllowNone = true,
		Callback = function(sel) eggExclM = sel end
	})

	local petExcludeTDropdown = QuestTab:Dropdown({
		Title = "Exclude Pet T",
		Desc = "Don’t sell pets with these T names (empty = sell all)",
		Values = collectKnownEggT(),
		Value = {},
		Multi = true,
		AllowNone = true,
		Callback = function(sel) petExclT = sel end
	})

	local petExcludeMDropdown = QuestTab:Dropdown({
		Title = "Exclude Pet Mutation M",
		Desc = "Don’t sell pets with these mutations (empty = allow all)",
		Values = collectKnownMutations(),
		Value = {},
		Multi = true,
		AllowNone = true,
		Callback = function(sel) petExclM = sel end
	})

	local respectLockToggle = QuestTab:Toggle({
		Title = "Respect LK (locked)",
		Desc = "Skip pets with LK == 1",
		Value = true,
		Callback = function(_) end
	})

	local function confirmDialog(title, content)
		local ok = true
		if Window and Window.Dialog then
			Window:Dialog({
				Title = title,
				Content = content,
				Icon = "help-circle",
				Buttons = {
					{ Title = "Cancel", Variant = "Secondary", Callback = function() ok = false end },
					{ Title = "OK", Variant = "Primary", Callback = function() ok = true end },
				}
			})
			-- give time for user to click
			task.wait(0.6)
		end
		return ok
	end

	local function runSendEgg(required)
		local exclTSet = toSet(eggExclT)
		local exclMSet = toSet(eggExclM)
		local target = pickTargetPlayer(targetPlayerMode, manualTargetInput and manualTargetInput.Value)
		if not target then return 0 end
		local sent = 0
		local inv = getEggsInventory()
		local candidates = {}
		for _, e in ipairs(inv) do
			if not shouldSkipEgg(e, exclTSet, exclMSet) then table.insert(candidates, e) end
		end
		if #candidates == 0 then
			if confirmDialog("No matching eggs", "Your filters matched 0 eggs. Continue anyway?") then
				candidates = inv
			else
				return 0
			end
		end
		for _, e in ipairs(candidates) do
			if sent >= required then break end
			focusUID(e.uid)
			giftToPlayer(target)
			sent += 1
			task.wait(0.25)
		end
		return sent
	end

	local function runSellPet(required)
		local exclTSet = toSet(petExclT)
		local exclMSet = toSet(petExclM)
		local sold = 0
		local inv = getPetsInventory()
		local candidates = {}
		for _, p in ipairs(inv) do
			if not (respectLockToggle and respectLockToggle.Value) or tonumber(p.LK) ~= 1 then
				if not shouldSkipPet(p, exclTSet, exclMSet) then table.insert(candidates, p) end
			end
		end
		if #candidates == 0 then
			if confirmDialog("No matching pets", "Your filters matched 0 pets. Continue anyway?") then
				candidates = inv
			else
				return 0
			end
		end
		for _, p in ipairs(candidates) do
			if sold >= required then break end
			sellPet(p.uid)
			sold += 1
			task.wait(0.25)
		end
		return sold
	end

	local function runHatchEgg(required)
		-- simple hatch assist: find ready prompts across owned models
		local function isReady(model)
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("TextLabel") and d.Name == "TXT" then
					local parent = d.Parent
					if parent and parent.Name == "TimeBar" then
						local txt = d.Text or ""
						if txt == "" or txt:find("100") or txt:lower():find("hatch") then return true end
					end
				end
				if d:IsA("ProximityPrompt") then
					local at = (d.ActionText or ""):lower()
					if at:find("hatch") then return true end
				end
			end
			return false
		end
		local function tryHatch(model)
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("ProximityPrompt") then
					local key = d.KeyboardKeyCode == Enum.KeyCode.Unknown and Enum.KeyCode.E or d.KeyboardKeyCode
					pcall(function()
						d.RequiresLineOfSight = false
						d.Enabled = true
					end)
					local hold = d.HoldDuration or 0
					game:GetService("VirtualInputManager"):SendKeyEvent(true, key, false, game)
					if hold > 0 then task.wait(hold + 0.05) end
					game:GetService("VirtualInputManager"):SendKeyEvent(false, key, false, game)
					return true
				end
			end
			return false
		end
		local placed = workspace:FindFirstChild("PlayerBuiltBlocks")
		if not placed then return 0 end
		local count = 0
		for _, m in ipairs(placed:GetChildren()) do
			if count >= required then break end
			if m:IsA("Model") and isReady(m) then
				tryHatch(m)
				count += 1
				task.wait(0.25)
			end
		end
		return count
	end

	local function remainingForTask(t)
		local def = TaskDefs[t.id]
		if not def then return 0 end
		local goal = tonumber(def.CompleteValue) or 0
		local done = tonumber(t.progress) or 0
		local remain = goal - done
		if remain < 0 then remain = 0 end
		return remain
	end

	local function tryClaimIfReady(t)
		local def = TaskDefs[t.id]
		if not def then return end
		if def.CompleteType == "OnlineTime" then
			if t.progress >= (def.CompleteValue or 900) then claimTask(t.id) end
		else
			if remainingForTask(t) <= 0 then claimTask(t.id) end
		end
	end

	local function orchestrate()
		waitForSettingsReady(0.2)
		while autoQuestEnabled do
			local tasks = readThreeTasks()
			-- Priority order
			local order = { "BuyMutateEgg", "HatchEgg", "SendEgg", "SellPet", "OnlineTime" }
			-- Build map type->task entries
			local typeToTask = {}
			for _, t in ipairs(tasks) do
				local def = TaskDefs[t.id]
				if def and (def.RepeatCount == nil or t.claimed < def.RepeatCount) then
					typeToTask[def.CompleteType] = t
				end
			end
			for _, typ in ipairs(order) do
				if not autoQuestEnabled then break end
				local t = typeToTask[typ]
				if t then
					local rem = remainingForTask(t)
					if typ == "BuyMutateEgg" and rem > 0 then
						buyMutatedEggsOnce(math.max(1, rem))
					elseif typ == "HatchEgg" and rem > 0 then
						runHatchEgg(rem)
					elseif typ == "SendEgg" and rem > 0 then
						runSendEgg(rem)
					elseif typ == "SellPet" and rem > 0 then
						runSellPet(rem)
					elseif typ == "OnlineTime" then
						-- passive; just claim-ready
					end
					-- auto-claim if toggled
					if autoClaimToggle and autoClaimToggle.Value then
						local latest = readThreeTasks()
						for _, tt in ipairs(latest) do if tt.id == t.id then tryClaimIfReady(tt) end end
					end
				end
			end
			-- If auto refresh, short wait; else longer
			task.wait((autoRefreshToggle and autoRefreshToggle.Value) and 1.0 or 3.0)
		end
	end

	local autoQuestToggle = QuestTab:Toggle({
		Title = "Enable Auto Quest",
		Desc = "Automatically do and claim daily tasks",
		Value = false,
		Callback = function(state)
			autoQuestEnabled = state
			if state and not autoQuestThread then
				autoQuestThread = task.spawn(function()
					orchestrate()
					autoQuestThread = nil
				end)
			else
				-- stop: thread loop will exit on next tick
			end
		end
	})

	-- Register with config manager for persistence
	if zebuxConfig then
		local function reg(key, el)
			if el then zebuxConfig:Register(key, el) end
		end
		reg("autoQuestEnabled", autoQuestToggle)
		reg("autoQuestAutoClaim", autoClaimToggle)
		reg("autoQuestAutoRefresh", autoRefreshToggle)
		reg("autoQuestTarget", targetPlayerDropdown)
		reg("autoQuestManualTarget", manualTargetInput)
		reg("autoQuestEggExclT", eggExcludeTDropdown)
		reg("autoQuestEggExclM", eggExcludeMDropdown)
		reg("autoQuestPetExclT", petExcludeTDropdown)
		reg("autoQuestPetExclM", petExcludeMDropdown)
		reg("autoQuestRespectLK", respectLockToggle)
	end

	-- Public
	return {
		Toggle = autoQuestToggle
	}
end

return AutoQuest


