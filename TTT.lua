-- Best Auto.lua
-- Spin-off headless automation: buy → place → hatch → prune → unlock → thresholds → upgrades → auto-feed → anti-AFK

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

-- State
local runFlag = false
local mutationOnly = false -- becomes true when average speed >= 1000
local thresholdBPDone = false
local thresholdFishDone = false
local purchasedUpgrades = {}
local controllerLoopRunning = false
local placeLoopRunning = false
local hatchLoopRunning = false
local forceMutationOnly = false
local SelectedBuyFruit = nil
local SelectedFeedFruit = nil
local SelectedBuyFruits = nil -- multi array or nil
local SelectedFeedFruits = nil -- multi array or nil

-- Global UI elements (to avoid PARSER_LOCAL_LIMIT)
Trade = nil
targetDropdown = nil
tradeLimitInput = nil
tradeToggle = nil
AutoFishSystem = nil

-- Utils
local function parseNumberWithSuffix(text)
	if text == nil then return nil end
	if type(text) == "number" then return text end
	local s = tostring(text)
	s = s:gsub(",[ ]?", "")
	s = s:gsub("[$€£¥₹/s]", "")
	s = s:gsub("^%s*(.-)%s$", "%1")
	local num, suf = s:match("^([%d%.]+)([KkMmBbTt]?)$")
	if not num then
		local raw = s:match("([%d%.]+)")
		if not raw then return nil end
		num = raw
		suf = ""
	end
	local n = tonumber(num)
	if not n then return nil end
	if suf ~= nil and suf ~= "" then
		local c = suf:lower()
		if c == "k" then n = n * 1e3
		elseif c == "m" then n = n * 1e6
		elseif c == "b" then n = n * 1e9
		elseif c == "t" then n = n * 1e12 end
	end
	return n
end

local function getNetWorth()
	local lp = LocalPlayer
	if not lp then return 0 end
	local a = lp:GetAttribute("NetWorth")
	if type(a) == "number" then return a end
	local ls = lp:FindFirstChild("leaderstats")
	if ls then
		local nv = ls:FindFirstChild("NetWorth")
		if nv and type(nv.Value) == "number" then return nv.Value end
	end
	return 0
end

local function getAssignedIslandName()
	if not LocalPlayer then return nil end
	return LocalPlayer:GetAttribute("AssignedIslandName")
end

local function getIslandNumberFromName(islandName)
	if not islandName then return nil end
	local m = tostring(islandName):match("Island_(%d+)")
	if m then return tonumber(m) end
	m = tostring(islandName):match("(%d+)")
	return m and tonumber(m) or nil
end

-- ResConveyor (from user)
local ResConveyor = nil -- removed hard-coded; load from ReplicatedStorage.Config.ResConveyor

local function conveyorIndexFromId(idStr)
	local n = tostring(idStr):match("(%d+)")
	return n and tonumber(n) or nil
end

-- Ocean egg inference
local OCEAN_EGGS = {
	SeaweedEgg = true, ClownfishEgg = true, LionfishEgg = true, SharkEgg = true,
	AnglerfishEgg = true, OctopusEgg = true, SeaDragonEgg = true
}

-- Dynamic config caches (auto-refresh)
local resEggConfigCache = nil
local resPetConfigCache = nil
local resConveyorConfigCache = nil

local function safeRequire(moduleScript)
	local ok, result = pcall(function()
		return require(moduleScript)
	end)
	if ok and type(result) == "table" then return result end
	return nil
end

local function loadResEggConfig()
	local cfgFolder = ReplicatedStorage:FindFirstChild("Config")
	local mod = cfgFolder and cfgFolder:FindFirstChild("ResEgg")
	if mod then
		local tbl = safeRequire(mod)
		if tbl and type(tbl) == "table" then
			resEggConfigCache = tbl
		end
	end
end

local function loadResPetConfig()
	local cfgFolder = ReplicatedStorage:FindFirstChild("Config")
	local mod = cfgFolder and cfgFolder:FindFirstChild("ResPet")
	if mod then
		local tbl = safeRequire(mod)
		if tbl and type(tbl) == "table" then
			resPetConfigCache = tbl
		end
	end
end

local function loadResConveyorConfig()
	local cfgFolder = ReplicatedStorage:FindFirstChild("Config")
	local mod = cfgFolder and cfgFolder:FindFirstChild("ResConveyor")
	if mod then
		local tbl = safeRequire(mod)
		if tbl and type(tbl) == "table" then
			resConveyorConfigCache = tbl
		end
	end
end

-- Initial load + periodic refresh
pcall(loadResEggConfig)
pcall(loadResPetConfig)
pcall(loadResConveyorConfig)

-- One-time load only; no periodic refresh per user request

local function isOceanEgg(eggType)
	local t = eggType and tostring(eggType)
	if t and resEggConfigCache and type(resEggConfigCache) == "table" then
		local entry = resEggConfigCache[t]
		if not entry then
			-- try scan by ID field match
			for key, val in pairs(resEggConfigCache) do
				if type(val) == "table" then
					if tostring(val.ID) == t or tostring(val.Type) == t or tostring(key) == t then
						entry = val
						break
					end
				end
			end
		end
		if type(entry) == "table" and entry.Category then
			local c = string.lower(tostring(entry.Category))
			if c:find("ocean") or c:find("water") or c:find("sea") then
				return true
			else
				return false
			end
		end
	end
	-- Fallback to static list
	return t and OCEAN_EGGS[t] == true
end

-- World scanning
local function getIslandBelts(islandName)
	if type(islandName) ~= "string" or islandName == "" then return {} end
	local art = workspace:FindFirstChild("Art")
	if not art then return {} end
	local island = art:FindFirstChild(islandName)
	if not island then return {} end
	local env = island:FindFirstChild("ENV")
	if not env then return {} end
	local conveyorRoot = env:FindFirstChild("Conveyor")
	if not conveyorRoot then return {} end
	local belts = {}
	for i = 1, 9 do
		local c = conveyorRoot:FindFirstChild("Conveyor" .. i)
		if c then
			local b = c:FindFirstChild("Belt")
			if b then table.insert(belts, b) end
		end
	end
	return belts
end

local function getActiveBelt(islandName)
	local belts = getIslandBelts(islandName)
	if #belts == 0 then return nil end
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local hrpPos = hrp and hrp.Position or Vector3.new()
	local best, bestScore
	for _, belt in ipairs(belts) do
		local children = belt:GetChildren()
		local eggs = 0
		local samplePos
		for _, ch in ipairs(children) do
			if ch:IsA("Model") then
				eggs += 1
				if not samplePos then
					local ok, cf = pcall(function() return ch:GetPivot() end)
					if ok and cf then samplePos = cf.Position end
				end
			end
		end
		if not samplePos then
			local p = belt.Parent and belt.Parent:FindFirstChildWhichIsA("BasePart", true)
			samplePos = p and p.Position or hrpPos
		end
		local dist = (samplePos - hrpPos).Magnitude
		local score = eggs * 100000 - dist
		if not bestScore or score > bestScore then
			bestScore, best = score, belt
		end
	end
	return best
end

-- Egg details
local function getEggMutationFromGUI(eggUID)
	local islandName = getAssignedIslandName()
	if not islandName then return nil end
	local art = workspace:FindFirstChild("Art"); if not art then return nil end
	local island = art:FindFirstChild(islandName); if not island then return nil end
	local env = island:FindFirstChild("ENV"); if not env then return nil end
	local conveyor = env:FindFirstChild("Conveyor"); if not conveyor then return nil end
	for i = 1, 9 do
		local cb = conveyor:FindFirstChild("Conveyor" .. i)
		if cb then
			local belt = cb:FindFirstChild("Belt")
			if belt then
				local eggModel = belt:FindFirstChild(eggUID)
				if eggModel and eggModel:IsA("Model") then
					local rp = eggModel:FindFirstChild("RootPart")
					if rp then
						local candidates = {"GUI/EggGUI","EggGUI","GUI","BillboardGui"}
						for _, path in ipairs(candidates) do
							local egui = rp:FindFirstChild(path)
							if egui then
								for _, lbl in ipairs({"Mutate","Mutation","MutateText","MutationLabel"}) do
									local t = egui:FindFirstChild(lbl)
									if t and t:IsA("TextLabel") then
										local txt = tostring(t.Text or "")
										txt = txt:gsub("^%s*(.-)%s$", "%1")
										if txt ~= "" and txt ~= "None" then
											local low = string.lower(txt)
											if low == "dino" then return "Jurassic" end
											return txt
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	return nil
end

local function getEggPriceFromGUI(model)
	local rp = model:FindFirstChild("RootPart")
	if not rp then return nil end
	for _, gp in ipairs({"GUI/EggGUI","EggGUI","GUI","Gui"}) do
		local egui = rp:FindFirstChild(gp)
		if egui then
			for _, lbl in ipairs({"Price","PriceLabel","Cost","CostLabel"}) do
				local t = egui:FindFirstChild(lbl)
				if t and t:IsA("TextLabel") then
					local v = parseNumberWithSuffix(t.Text)
					if v and v > 0 then return v end
				end
			end
		end
	end
	return nil
end

-- Buy / Focus remotes
local function buyEggByUID(uid)
	local args = {"BuyEgg", uid}
	pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
	end)
end

local function focusEggByUID(uid)
	local args = {"Focus", uid}
	pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
	end)
end

-- Check egg suitability
local function shouldBuyEggInstance(eggInstance)
	if not eggInstance or not eggInstance:IsA("Model") then return false end
	local eggType = eggInstance:GetAttribute("Type") or eggInstance:GetAttribute("EggType") or eggInstance:GetAttribute("Name")
	if not eggType then return false end
	if mutationOnly or forceMutationOnly then
		local mut = getEggMutationFromGUI(eggInstance.Name)
		if not mut or mut == "None" then return false end
	end
	local price = eggInstance:GetAttribute("Price") or getEggPriceFromGUI(eggInstance)
	if type(price) ~= "number" then price = tonumber(price) end
	local net = getNetWorth()
	if price and price > 0 and net < price then return false end
	return true
end

-- Player GUI data helpers
local function getEggContainer()
	local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	return data and data:FindFirstChild("Egg") or nil
end

local function listAvailableEggUIDs()
	local eg = getEggContainer()
	local items = {}
	if not eg then return items end
	for _, child in ipairs(eg:GetChildren()) do
		if #child:GetChildren() == 0 then
			local eggType = child:GetAttribute("T") or child.Name
			table.insert(items, { uid = child.Name, type = eggType })
		end
	end
	return items
end

-- Farm tiles
local farmPartsCache = {}

local function cacheSet(islandNumber, key, parts)
	farmPartsCache[islandNumber] = farmPartsCache[islandNumber] or {}
	farmPartsCache[islandNumber][key] = { parts = parts, last = tick() }
end

local function cacheGet(islandNumber, key, ttl)
	ttl = ttl or 5
	local rec = farmPartsCache[islandNumber] and farmPartsCache[islandNumber][key]
	if rec and (tick() - (rec.last or 0) <= ttl) then
		return rec.parts
	end
	return nil
end

local function scanForPartsByNamePattern(root, predicate)
	local out = {}
	local function dfs(parent)
		for _, ch in ipairs(parent:GetChildren()) do
			if ch:IsA("BasePart") and predicate(ch) then
				table.insert(out, ch)
			end
			dfs(ch)
		end
	end
	pcall(function()
		dfs(root)
	end)
	return out
end

local function getFarmParts(islandNumber)
	if not islandNumber then return {} end
	local cached = cacheGet(islandNumber, "regular", 5)
	if cached then return cached end
	local art = workspace:FindFirstChild("Art"); if not art then return {} end
	local island = art:FindFirstChild("Island_" .. tostring(islandNumber))
	if not island then
		for _, child in ipairs(art:GetChildren()) do
			if child.Name:match("^Island[_-]?" .. tostring(islandNumber) .. "$") then island = child break end
		end
		if not island then return {} end
	end
	local parts = scanForPartsByNamePattern(island, function(p)
		return p.Name:match("^Farm_split_%d+_%d+_%d+$") and p.Size == Vector3.new(8,8,8) and p.CanCollide
	end)
	-- Filter locked by Locks
	local unlocked = {}
	local env = island:FindFirstChild("ENV")
	local locks = env and env:FindFirstChild("Locks")
	local lockAreas = {}
	if locks then
		for _, m in ipairs(locks:GetChildren()) do
			if m:IsA("Model") then
				local f = m:FindFirstChild("Farm")
				if f and f:IsA("BasePart") and f.Transparency == 0 then
					table.insert(lockAreas, {pos = f.Position, size = f.Size})
				end
			end
		end
	end
	for _, part in ipairs(parts) do
		local pos = part.Position
		local locked = false
		for _, a in ipairs(lockAreas) do
			local hs = a.size/2
			if pos.X >= a.pos.X-hs.X and pos.X <= a.pos.X+hs.X and pos.Z >= a.pos.Z-hs.Z and pos.Z <= a.pos.Z+hs.Z then
				locked = true; break
			end
		end
		if not locked then table.insert(unlocked, part) end
	end
	cacheSet(islandNumber, "regular", unlocked)
	return unlocked
end

local function getWaterFarmParts(islandNumber)
	if not islandNumber then return {} end
	local cached = cacheGet(islandNumber, "water", 5)
	if cached then return cached end
	local art = workspace:FindFirstChild("Art"); if not art then return {} end
	local island = art:FindFirstChild("Island_" .. tostring(islandNumber))
	if not island then
		for _, child in ipairs(art:GetChildren()) do
			if child.Name:match("^Island[_-]?" .. tostring(islandNumber) .. "$") then island = child break end
		end
		if not island then return {} end
	end
	local parts = scanForPartsByNamePattern(island, function(p)
		return p.Name == "WaterFarm_split_0_0_0" and p.Size == Vector3.new(8,8,8) and p.CanCollide
	end)
	-- Filter locked using Locks bounds
	local unlocked = {}
	local env = island:FindFirstChild("ENV")
	local locks = env and env:FindFirstChild("Locks")
	local lockAreas = {}
	if locks then
		for _, m in ipairs(locks:GetChildren()) do
			if m:IsA("Model") then
				local f = m:FindFirstChild("Farm")
				if f and f:IsA("BasePart") and f.Transparency == 0 then
					table.insert(lockAreas, {pos = f.Position, size = f.Size})
				end
			end
		end
	end
	for _, part in ipairs(parts) do
		local pos = part.Position
		local locked = false
		for _, a in ipairs(lockAreas) do
			local hs = a.size/2
			if pos.X >= a.pos.X-hs.X and pos.X <= a.pos.X+hs.X and pos.Z >= a.pos.Z-hs.Z and pos.Z <= a.pos.Z+hs.Z then
				locked = true; break
			end
		end
		if not locked then table.insert(unlocked, part) end
	end
	cacheSet(islandNumber, "water", unlocked)
	return unlocked
end

local function isFarmTileOccupied(tilePart, minDistance)
	minDistance = minDistance or 6
	if not tilePart or not tilePart:IsA("BasePart") then return true end
	local surfacePos = Vector3.new(tilePart.Position.X, tilePart.Position.Y + 12, tilePart.Position.Z)
	-- Check PlayerBuiltBlocks models
	local container = workspace:FindFirstChild("PlayerBuiltBlocks")
	if container then
		for _, m in ipairs(container:GetChildren()) do
			if m:IsA("Model") then
				local ok, cf = pcall(function() return m:GetPivot() end)
				local pos = ok and cf and cf.Position
				if pos then
					local xz = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(surfacePos.X, 0, surfacePos.Z)).Magnitude
					local yd = math.abs(pos.Y - surfacePos.Y)
					if xz < 4.0 and yd < 20.0 then return true end
				end
			end
		end
	end
	-- Check workspace.Pets
	local pets = workspace:FindFirstChild("Pets")
	if pets then
		for _, m in ipairs(pets:GetChildren()) do
			if m:IsA("Model") then
				local ok, cf = pcall(function() return m:GetPivot() end)
				local pos = ok and cf and cf.Position
				if pos then
					local xz = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(surfacePos.X, 0, surfacePos.Z)).Magnitude
					local yd = math.abs(pos.Y - surfacePos.Y)
					if xz < 4.0 and yd < 20.0 then return true end
				end
			end
		end
	end
	return false
end

local function findAvailableTileForEggType(eggType)
	local islandName = getAssignedIslandName()
	local islandNumber = getIslandNumberFromName(islandName)
	local parts = (eggType and isOceanEgg(eggType)) and getWaterFarmParts(islandNumber) or getFarmParts(islandNumber)
	for _, p in ipairs(parts) do
		if not isFarmTileOccupied(p, 6) then return p end
	end
	return nil
end

local function countAllAvailableTiles(eggType)
	local islandName = getAssignedIslandName()
	local islandNumber = getIslandNumberFromName(islandName)
	local parts = {}
	if eggType == nil then
		for _, p in ipairs(getFarmParts(islandNumber)) do table.insert(parts, p) end
		for _, p in ipairs(getWaterFarmParts(islandNumber)) do table.insert(parts, p) end
	else
		if isOceanEgg(eggType) then
			for _, p in ipairs(getWaterFarmParts(islandNumber)) do table.insert(parts, p) end
		else
			for _, p in ipairs(getFarmParts(islandNumber)) do table.insert(parts, p) end
		end
	end
	local c = 0
	for _, p in ipairs(parts) do
		if not isFarmTileOccupied(p, 6) then c += 1 end
	end
	return c
end

-- Placement
local function placeEggAtTile(tilePart, eggUID)
	if not tilePart or not eggUID then return false end
	local pos = Vector3.new(tilePart.Position.X, tilePart.Position.Y + (tilePart.Size.Y/2), tilePart.Position.Z)
	-- Focus the egg UID so it's considered held
	pcall(function()
		focusEggByUID(eggUID)
	end)
	task.wait(0.05)
	-- Place directly via remote
	local args = {"Place", { DST = Vector3.new(pos.X,pos.Y,pos.Z), ID = eggUID }}
	local ok = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
	end)
	if ok then lastActivityTime = tick() end
	return ok
end

-- Unlock tiles
local function parseLockCost(val)
	if type(val) == "number" then return val end
	if type(val) ~= "string" then return 0 end
	local s = val:gsub("[$€£¥₹,]", "")
	local n, suf = s:match("^([%d%.]+)([KkMmBbTt]?)$")
	local v = tonumber(n) or 0
	if suf and suf ~= "" then
		local c = suf:lower()
		if c == "k" then v = v * 1e3 elseif c == "m" then v = v * 1e6 elseif c == "b" then v = v * 1e9 elseif c == "t" then v = v * 1e12 end
	end
	return v
end

local function getLockedTilesForCurrentIsland()
	local locked = {}
	local islandName = getAssignedIslandName(); if not islandName then return locked end
	local art = workspace:FindFirstChild("Art"); if not art then return locked end
	local island = art:FindFirstChild(islandName); if not island then return locked end
	local env = island:FindFirstChild("ENV"); if not env then return locked end
	local locks = env:FindFirstChild("Locks"); if not locks then return locked end
	for _, model in ipairs(locks:GetChildren()) do
		if model:IsA("Model") then
			local farm = model:FindFirstChild("Farm")
			if farm and farm:IsA("BasePart") then
				local isLocked = (tonumber(farm.Transparency) or 0) <= 0.01 or farm.CanCollide
				if isLocked then
					local cost = farm:GetAttribute("LockCost") or model:GetAttribute("LockCost") or farm:GetAttribute("Cost") or 0
					table.insert(locked, { model = model, farmPart = farm, cost = cost })
				end
			end
		end
	end
	return locked
end

local function unlockTile(lockInfo)
	if not lockInfo or not lockInfo.farmPart then return false end
	local args = {"Unlock", lockInfo.farmPart}
	local ok = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
	end)
	if ok then lastActivityTime = tick() end
	return ok
end

local function tryAutoUnlockSomeTiles()
	local locked = getLockedTilesForCurrentIsland()
	if #locked == 0 then return false end
	table.sort(locked, function(a,b)
		return parseLockCost(a.cost) < parseLockCost(b.cost)
	end)
	local did = false
	for i = 1, math.min(2, #locked) do
		local cost = parseLockCost(locked[i].cost)
		if getNetWorth() >= cost then
			if unlockTile(locked[i]) then did = true task.wait(0.4) end
		end
	end
	return did
end

-- Hatching
local hatchInFlightByUid = {}
local function getOwnerUserIdDeep(inst)
	local cur = inst
	while cur and cur ~= workspace do
		if cur.GetAttribute then
			local v = cur:GetAttribute("UserId")
			if type(v) == "number" then return v end
			if type(v) == "string" then local n = tonumber(v) if n then return n end end
		end
		cur = cur.Parent
	end
	return nil
end

local function isOwnedEggModel(model)
	if not model or not model:IsA("Model") then return false end
	local owner = getOwnerUserIdDeep(model)
	local lp = LocalPlayer
	if owner == nil or not lp or lp.UserId ~= owner then return false end
	local rp = model:FindFirstChild("RootPart")
	return rp and rp:FindFirstChild("RF") ~= nil
end

local function hatchEggDirectly(eggUID)
	if hatchInFlightByUid[eggUID] then return false end
	hatchInFlightByUid[eggUID] = true
	task.spawn(function()
		pcall(function()
			local eggModel = workspace:FindFirstChild("PlayerBuiltBlocks")
			eggModel = eggModel and eggModel:FindFirstChild(eggUID)
			if eggModel and eggModel:FindFirstChild("RootPart") and eggModel.RootPart:FindFirstChild("RF") then
				lastActivityTime = tick()
				eggModel.RootPart.RF:InvokeServer("Hatch")
			end
		end)
		task.delay(2, function() hatchInFlightByUid[eggUID] = nil end)
	end)
	return true
end

-- Pet speeds and pruning
local function getMyPetsWithSpeed()
	local petsFolder = workspace:FindFirstChild("Pets")
	local out = {}
	if not petsFolder then return out end
	for _, m in ipairs(petsFolder:GetChildren()) do
		if m:IsA("Model") then
			local rp = m:FindFirstChild("RootPart")
			if rp then
				-- Skip Big Pets
				local bigPetGUI = rp:FindFirstChild("GUI/BigPetGUI")
				if bigPetGUI then
					-- do not include in speed averaging
				else
					local uid = rp:GetAttribute("UserId") or m:GetAttribute("UserId")
					if tostring(uid or "") == tostring(LocalPlayer and LocalPlayer.UserId or 0) then
						local gui = rp:FindFirstChild("GUI/IdleGUI", true)
						local sp = gui and gui:FindFirstChild("Speed")
						local val = sp and parseNumberWithSuffix(sp.Text)
						if val then
							table.insert(out, {name = m.Name, speed = val})
						end
					end
				end
			end
		end
	end
	return out
end

local function computeAverageSpeed()
	local list = getMyPetsWithSpeed()
	if #list == 0 then return 0 end
	local sum = 0
	for _, it in ipairs(list) do sum += it.speed end
	return sum / #list
end

local avgCache = { value = 0, last = 0 }
local function getAverageSpeedThrottled(interval)
	interval = interval or 5
	local now = tick()
	if now - (avgCache.last or 0) >= interval then
		avgCache.value = computeAverageSpeed()
		avgCache.last = now
	end
	return avgCache.value or 0
end

local function deletePetByName(petName)
	if not petName or petName == "" then return false end
	local args = {"Del", petName}
	local ok = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
	end)
	return ok
end

local function getPetNodeByName(petUid)
	local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	local pets = data and data:FindFirstChild("Pets")
	return pets and pets:FindFirstChild(petUid) or nil
end

local function isPetNodePlaced(node)
	if not node then return false end
	local d = node:GetAttribute("D")
	return d ~= nil and tostring(d) ~= ""
end

local function sellPetByUid(petUid)
	local ok = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("PetRE"):FireServer("Sell", petUid)
	end)
	return ok == true
end

local function unplacePetByUid(petUid)
	local ok = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer("Del", petUid)
	end)
	return ok == true
end

local function removeOrSellPet(petUid)
	local node = getPetNodeByName(petUid)
	if node then
		if isPetNodePlaced(node) then
			unplacePetByUid(petUid)
			task.wait(0.15)
			-- refresh node
			node = getPetNodeByName(petUid)
		end
		-- attempt sell
		if sellPetByUid(petUid) then return true end
	end
	-- fallback delete
	return unplacePetByUid(petUid)
end

local function pruneBelowAverageIfFull(eggType)
	if countAllAvailableTiles(eggType) > 0 then return end
	local avg = computeAverageSpeed()
	if avg <= 0 then return end
	local list = getMyPetsWithSpeed()
	-- Build candidate list: non-mutated first, then by lowest speed
	local candidates = {}
	for _, it in ipairs(list) do
		if it.speed < avg then
			local node = getPetNodeByName(it.name)
			local mutated = false
			if node then
				local mAttr = node:GetAttribute("M")
				mutated = (mAttr ~= nil and tostring(mAttr) ~= "")
			end
			table.insert(candidates, { name = it.name, speed = it.speed, mutated = mutated })
		end
	end
	if #candidates == 0 then return end
	table.sort(candidates, function(a,b)
		if a.mutated ~= b.mutated then return (not a.mutated) end
		return a.speed < b.speed
	end)
	for _, c in ipairs(candidates) do
		if countAllAvailableTiles(eggType) > 0 then break end
		removeOrSellPet(c.name)
		task.wait(0.1)
	end
end

-- Threshold actions
local function tryUnlockBigPetAt30k()
	if thresholdBPDone then return end
	if getNetWorth() < 30000 then return end
	local art = workspace:FindFirstChild("Art"); if not art then return end
	local island = art:FindFirstChild("Island_5"); if not island then return end
	local env = island:FindFirstChild("ENV"); if not env then return end
	local big = env:FindFirstChild("BigPet"); if not big then return end
	local one = big:FindFirstChild("1"); if not one then return end
	local active = one:GetAttribute("Active")
	if active == nil or active == false then
		pcall(function()
			ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer("UnlockBP", 1)
		end)
		lastActivityTime = tick()
		thresholdBPDone = true
	end
end

local function tryUnlockFishAt50k()
	if thresholdFishDone then return end
	if getNetWorth() < 50000 then return end
	pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FishingRE"):FireServer("UnlockFish")
	end)
	thresholdFishDone = true
end

local function tryUnlockBigPet3At50k()
	if getNetWorth() < 50000 then return end
	local art = workspace:FindFirstChild("Art"); if not art then return end
	local island = art:FindFirstChild("Island_5"); if not island then return end
	local env = island:FindFirstChild("ENV"); if not env then return end
	local big = env:FindFirstChild("BigPet"); if not big then return end
	local three = big:FindFirstChild("3"); if not three then return end
	local active = three:GetAttribute("Active")
	if tonumber(active) == 1 then
		pcall(function()
			ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer("UnlockBP", 3)
		end)
		lastActivityTime = tick()
	end
end

-- Upgrades
local function tryUpgradeConveyors()
	for idx = 2, 9 do
		if not purchasedUpgrades[idx] then
			local key = "Conveyor" .. idx
			local cfg = (resConveyorConfigCache and resConveyorConfigCache[key]) or ResConveyor[key]
			local cost = cfg and (cfg.Cost or cfg.Price) or 0
			if type(cost) == "string" then cost = parseNumberWithSuffix(cost) end
			if getNetWorth() >= (cost or 0) then
				local ok = pcall(function()
					ReplicatedStorage:WaitForChild("Remote"):WaitForChild("ConveyorRE"):FireServer("Upgrade", idx)
				end)
				if ok then purchasedUpgrades[idx] = true lastActivityTime = tick() task.wait(0.2) end
			end
		end
	end
end

local function getGameFlag()
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	return data and data:FindFirstChild("GameFlag") or nil
end

local function getCurrentConveyorLevel()
	local gf = getGameFlag()
	if not gf then return 1 end
	local val = gf:GetAttribute("Conveyor")
	if type(val) == "number" then return val end
	if type(val) == "string" then
		local n = tonumber((val:match("(%d+)") or ""))
		if n then return n end
	end
	return 1
end

local function tryUpgradeConveyorNext()
	local curr = tonumber(getCurrentConveyorLevel() or 1)
	if not curr or curr < 1 then curr = 1 end
	if curr >= 9 then return false end
	local nextIdx = curr + 1
	local key = "Conveyor" .. nextIdx
	local cfg = (resConveyorConfigCache and resConveyorConfigCache[key]) or (ResConveyor and ResConveyor[key])
	local cost = cfg and (cfg.Cost or cfg.Price) or 0
	if type(cost) == "string" then cost = parseNumberWithSuffix(cost) end
	if getNetWorth() < (cost or 0) then return false end
	local ok = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("ConveyorRE"):FireServer("Upgrade", nextIdx)
	end)
	if ok then lastActivityTime = tick() purchasedUpgrades[nextIdx] = true end
	return ok == true
end

-- Auto-Feed Big Pets: use external system (no UI) and feed with any fruit in inventory
local AutoFeedSystem = nil
pcall(function()
	AutoFeedSystem = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/AutoFeedSystem.lua"))()
end)

local function startAutoFeed()
	if not AutoFeedSystem or not AutoFeedSystem.runAutoFeed then return end
	local status = { lastAction = "", totalFeeds = 0, petsFound = 0, availablePets = 0 }
	local function getSelected()
		local inv = AutoFeedSystem.getPlayerFruitInventory and AutoFeedSystem.getPlayerFruitInventory() or {}
		local sel = {}
		for k, v in pairs(inv) do if v and v > 0 then sel[k] = true end end
		return sel
	end
	task.spawn(function()
		local ok = pcall(function()
			AutoFeedSystem.runAutoFeed(true, status, function() end, getSelected)
		end)
		if not ok then warn("AutoFeed loop error") end
	end)
end

-- Auto Claim Money
local autoClaimEnabled = true
local autoClaimDelay = 0.1
local autoClaimRunning = false

local function getOwnedPetNames()
	local names = {}
	local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	local data = playerGui and playerGui:FindFirstChild("Data")
	local petsContainer = data and data:FindFirstChild("Pets")
	if petsContainer then
		for _, child in ipairs(petsContainer:GetChildren()) do
			local n
			if child:IsA("ValueBase") then
				n = tostring(child.Value)
			else
				n = tostring(child.Name)
			end
			if n and n ~= "" then table.insert(names, n) end
		end
	end
	return names
end

local function claimMoneyForPet(petName)
	if not petName or petName == "" then return false end
	local petsFolder = workspace:FindFirstChild("Pets")
	if not petsFolder then return false end
	local petModel = petsFolder:FindFirstChild(petName)
	if not petModel then return false end
	local root = petModel:FindFirstChild("RootPart")
	if not root then return false end
	local re = root:FindFirstChild("RE")
	if not re or not re.FireServer then return false end
	local ok = pcall(function()
		re:FireServer("Claim")
	end)
	return ok
end

local function startAutoClaim()
	if autoClaimRunning then return end
	autoClaimRunning = true
	task.spawn(function()
		while autoClaimEnabled do
			local ok, err = pcall(function()
				local names = getOwnedPetNames()
				if #names == 0 then task.wait(0.8) return end
				for _, n in ipairs(names) do
					claimMoneyForPet(n)
					task.wait(autoClaimDelay)
				end
			end)
			if not ok then
				warn("Auto Claim error: " .. tostring(err))
				task.wait(1)
			end
		end
		autoClaimRunning = false
	end)
end

-- Auto Buy Fruit (simple)
local autoBuyFruitEnabled = false
local autoBuyFruitRunning = false

local FruitData = {
	Strawberry = { Price = "5,000" },
	Blueberry = { Price = "20,000" },
	Watermelon = { Price = "80,000" },
	Apple = { Price = "400,000" },
	Orange = { Price = "1,200,000" },
	Corn = { Price = "3,500,000" },
	Banana = { Price = "12,000,000" },
	Grape = { Price = "50,000,000" },
	Pear = { Price = "200,000,000" },
	Pineapple = { Price = "600,000,000" },
	GoldMango = { Price = "2,000,000,000" },
	BloodstoneCycad = { Price = "8,000,000,000" },
	ColossalPinecone = { Price = "40,000,000,000" },
	VoltGinkgo = { Price = "80,000,000,000" },
	DeepseaPearlFruit = { Price = "40,000,000,000" }
}

local defaultFruitOrder = {
	"Strawberry","Blueberry","Watermelon","Apple","Orange","Corn","Banana","Grape","Pear",
	"Pineapple","GoldMango","BloodstoneCycad","ColossalPinecone","VoltGinkgo","DeepseaPearlFruit"
}

local function getFoodStoreLST()
	local player = Players.LocalPlayer
	if not player then return nil end
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return nil end
	local data = playerGui:FindFirstChild("Data")
	if not data then return nil end
	local foodStore = data:FindFirstChild("FoodStore")
	if not foodStore then return nil end
	return foodStore:FindFirstChild("LST")
end

local function isFruitInStock(fruitId)
	local lst = getFoodStoreLST()
	if not lst then return true end -- assume yes if list missing
	local candidates = {fruitId, string.lower(fruitId), string.upper(fruitId), (fruitId:gsub(" ", "_")), string.lower(fruitId:gsub(" ", "_"))}
	for _, key in ipairs(candidates) do
		local a = lst:GetAttribute(key)
		if type(a) == "number" and a > 0 then return true end
		local label = lst:FindFirstChild(key)
		if label and label:IsA("TextLabel") then
			local num = tonumber((label.Text or ""):match("%d+"))
			if num and num > 0 then return true end
		end
	end
	return false
end

local function buyFruitOnce(fruitId)
	local ok = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("FoodStoreRE"):FireServer(fruitId)
	end)
	return ok
end

local function startAutoBuyFruit()
	if autoBuyFruitRunning then return end
	autoBuyFruitRunning = true
	task.spawn(function()
		while autoBuyFruitEnabled do
			local net = getNetWorth()
			local bought = false
			local order = {}
			if type(SelectedBuyFruits) == "table" and next(SelectedBuyFruits) ~= nil then
				local allowAny = false
				for _, v in ipairs(SelectedBuyFruits) do if tostring(v) == "Any" then allowAny = true break end end
				if allowAny then
					order = defaultFruitOrder
				else
					for _, f in ipairs(defaultFruitOrder) do
						for _, sel in ipairs(SelectedBuyFruits) do if tostring(sel) == tostring(f) then table.insert(order, f) break end end
					end
					if #order == 0 then order = defaultFruitOrder end
				end
			else
				order = defaultFruitOrder
			end
			for _, fruitId in ipairs(order) do
				local info = FruitData[fruitId]
				local price = info and info.Price and parseNumberWithSuffix((info.Price):gsub(",", "")) or nil
				if isFruitInStock(fruitId) and price and net >= price then
					if buyFruitOnce(fruitId) then
						bought = true
						net = getNetWorth()
					end
					task.wait(0.2)
				end
			end
			if not bought then task.wait(2) else task.wait(0.8) end
		end
		autoBuyFruitRunning = false
	end)
end

-- Anti-AFK
local function setupAntiAFK()
	pcall(function()
		Players.LocalPlayer.Idled:Connect(function()
			game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
			task.wait(1)
			game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
		end)
	end)
end

-- Auto Buy: monitor belts and buy immediately
local beltConnections = {}
local function cleanupBeltConnections()
	for _, c in ipairs(beltConnections) do pcall(function() c:Disconnect() end) end
	beltConnections = {}
end

local function buyEggInstantly(eggInstance)
	if not runFlag then return end
	if not shouldBuyEggInstance(eggInstance) then return end
	local uid = eggInstance.Name
	local beforeNet = getNetWorth()
	buyEggByUID(uid)
	lastActivityTime = tick()
	focusEggByUID(uid)
	-- simple confirmation wait
	local t0 = tick() + 2
	while tick() < t0 do
		local eg = getEggContainer()
		if eg and #eg:GetChildren() > 0 then break end
		local curr = getNetWorth()
		if curr < beforeNet then break end
		task.wait(0.1)
	end
end

local function setupBeltMonitoring(belt)
	if not belt then return end
	local function onChildAdded(ch)
		if not runFlag then return end
		if ch:IsA("Model") then
			task.spawn(function()
				-- allow attributes/GUI to initialize briefly
				task.wait(0.1)
				buyEggInstantly(ch)
			end)
		end
	end
	local conn = belt.ChildAdded:Connect(onChildAdded)
	table.insert(beltConnections, conn)
	-- coalesced periodic scan with mutation priority
	task.spawn(function()
		while runFlag do
			local children = belt:GetChildren()
			local candidates = {}
			for _, ch in ipairs(children) do
				if ch:IsA("Model") then
					local net = getNetWorth()
					local ok, uid, price, reason = pcall(function()
						return shouldBuyEggInstance(ch), ch.Name, getEggPriceFromGUI(ch), ""
					end)
					if ok and shouldBuyEggInstance(ch) then
						local mut = getEggMutationFromGUI(ch.Name)
						local pri = (mut and 1000 or 0)
						table.insert(candidates, { inst = ch, pr = pri })
					end
				end
			end
			if #candidates > 0 then
				table.sort(candidates, function(a,b) return a.pr > b.pr end)
				buyEggInstantly(candidates[1].inst)
			end
			task.wait(mutationOnly and 0.3 or 0.6)
		end
	end)
end

-- Orchestrated loops (start/stop controllable)
local function startControllerLoop()
	if controllerLoopRunning then return end
	controllerLoopRunning = true
	task.spawn(function()
		setupAntiAFK()
		startAutoFeed()
		while runFlag do
			local islandName = getAssignedIslandName()
			if islandName and islandName ~= "" then
				local activeBelt = getActiveBelt(islandName)
				cleanupBeltConnections()
				setupBeltMonitoring(activeBelt)
				while runFlag do
					local curr = getAssignedIslandName()
					if curr ~= islandName then break end
					tryUnlockBigPetAt30k()
					tryUnlockFishAt50k()
					tryUnlockBigPet3At50k()
					tryUpgradeConveyors()
				
					task.wait(0.8)
				end
			else
				task.wait(1)
			end
		end
		cleanupBeltConnections()
		controllerLoopRunning = false
	end)
end

-- Auto place eggs continuously (controllable)
local function startPlaceLoop()
	if placeLoopRunning then return end
	placeLoopRunning = true
	task.spawn(function()
		while runFlag do
			local eggs = listAvailableEggUIDs()
			if #eggs == 0 then task.wait(0.8) else
				for _, e in ipairs(eggs) do
					local tile = findAvailableTileForEggType(e.type)
					if not tile then
						if not tryAutoUnlockSomeTiles() then pruneBelowAverageIfFull(e.type) end
						tile = findAvailableTileForEggType(e.type)
					end
					if tile then placeEggAtTile(tile, e.uid) task.wait(0.2) end
				end
			end
		end
		placeLoopRunning = false
	end)
end

-- Auto hatch owned eggs (controllable)
local function startHatchLoop()
	if hatchLoopRunning then return end
	hatchLoopRunning = true
	task.spawn(function()
		while runFlag do
			local container = workspace:FindFirstChild("PlayerBuiltBlocks")
			if container then
				for _, m in ipairs(container:GetChildren()) do
					if isOwnedEggModel(m) then hatchEggDirectly(m.Name) task.wait(0.05) end
				end
			end
			task.wait(2)
		end
		hatchLoopRunning = false
	end)
end

local function startLoopsIfNeeded()
	if not runFlag then return end
	startControllerLoop()
	startPlaceLoop()
	startHatchLoop()
end

-- Start loops immediately on script load
-- startLoopsIfNeeded()
-- startAutoClaim()
-- do not auto-start fruit until Run is toggled (managed by Run toggle)
-- startAutoBuyFruit()

-- Revamp UI (separate functions only) - Early return mode
local REVAMP_MODE = true
if REVAMP_MODE then
	-- Services
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local LocalPlayer = Players.LocalPlayer
	local HttpService = game:GetService("HttpService")

	-- Load WindUI
	local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
	local Window = WindUI:CreateWindow({
		Title = "Build a Zoo",
		Icon = "gitlab",
		IconThemed = true,
		Author = "Zebux",
		Folder = "Zebux",
		Size = UDim2.fromOffset(520, 320),
		Transparent = true,
		Theme = "Dark",
	})
	Window:EditOpenButton({
		Title = "Best Auto",
		Icon = "monitor",
		CornerRadius = UDim.new(0,16),
		StrokeThickness = 2,
		Color = ColorSequence.new(Color3.fromHex("FF0F7B"), Color3.fromHex("F89B29")),
		OnlyMobile = false,
		Draggable = true,
	})

	-- Tabs
	local Section = Window:Section({ Title = "Controller", Opened = true })
	local BuyTab = Section:Tab({ Title = "Main", Icon = "airplay" })
	local PlaceTab = Section:Tab({ Title = "Place", Icon = "package" })
	local RecallTab = Section:Tab({ Title = "Recall", Icon = "undo-2" })
	local FishTab = Section:Tab({ Title = "Fish", Icon = "fish" })
	local ShopTab = Section:Tab({ Title = "Shop", Icon = "shopping-cart" })
    local TradeTab = Section:Tab({ Title = "Trade", Icon = "move-vertical" })
	local SaveTab = Section:Tab({ Title = "Save", Icon = "save" })


	-- Config Manager
	local Config = Window.ConfigManager:CreateConfig("BestAuto_Revamp")

	-- Load configs
	local ResEgg = nil
	local ResMutate = nil
	local ResPet = nil
	local ResConveyor = nil
	pcall(function()
		local cfg = ReplicatedStorage:WaitForChild("Config")
		ResEgg = require(cfg:WaitForChild("ResEgg"))
		ResMutate = require(cfg:WaitForChild("ResMutate"))
		ResPet = require(cfg:WaitForChild("ResPet"))
		ResConveyor = require(cfg:WaitForChild("ResConveyor"))
	end)

	-- Helpers
	local function normalizeMutation(m)
		if not m then return nil end
		local s = tostring(m)
		if s:lower() == "Dino" then return "Jurassic" end
		return s
	end
	local function tableHasAny(list)
		return type(list) == "table" and next(list) ~= nil
	end
	local function listHas(list, value)
		if not tableHasAny(list) then return false end
		local s = tostring(value)
		for _, v in ipairs(list) do if tostring(v) == s then return true end end
		return false
	end
	local function getAssignedIslandName()
		return LocalPlayer and LocalPlayer:GetAttribute("AssignedIslandName")
	end

	local function getIslandBelts(islandName)
		local art = workspace:FindFirstChild("Art") if not art then return {} end
		local island = art:FindFirstChild(islandName or "") if not island then return {} end
		local env = island:FindFirstChild("ENV") if not env then return {} end
		local conveyorRoot = env:FindFirstChild("Conveyor") if not conveyorRoot then return {} end
		local belts = {}
		for i = 1, 9 do
			local c = conveyorRoot:FindFirstChild("Conveyor" .. i)
			if c and c:FindFirstChild("Belt") then table.insert(belts, c.Belt) end
		end
		return belts
	end

	local function getActiveBelt()
		local island = getAssignedIslandName()
		if not island then return nil end
		local belts = getIslandBelts(island)
		if #belts == 0 then return nil end
		local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local pos = hrp and hrp.Position or Vector3.new()
		local best, bestScore
		for _, belt in ipairs(belts) do
			local eggs = 0
			local p = belt.Parent and belt.Parent:FindFirstChildWhichIsA("BasePart", true)
			local bpos = p and p.Position or pos
			for _, ch in ipairs(belt:GetChildren()) do if ch:IsA("Model") then eggs += 1 end end
			local score = eggs * 100000 - (bpos - pos).Magnitude
			if not bestScore or score > bestScore then best, bestScore = belt, score end
		end
		return best
	end

	local function buyEggByUID(uid)
		pcall(function()
			ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer("BuyEgg", uid)
		end)
	end

	local function focusEggByUID(uid)
		pcall(function()
			ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer("Focus", uid)
		end)
	end

	local function getEggMutationFromGUI(eggUID)
		local island = getAssignedIslandName() if not island then return nil end
		local art = workspace:FindFirstChild("Art") if not art then return nil end
		local is = art:FindFirstChild(island) if not is then return nil end
		local env = is:FindFirstChild("ENV") if not env then return nil end
		local conv = env:FindFirstChild("Conveyor") if not conv then return nil end
		for i=1,9 do
			local cb = conv:FindFirstChild("Conveyor"..i)
			local belt = cb and cb:FindFirstChild("Belt")
			local eggModel = belt and belt:FindFirstChild(eggUID)
			local rp = eggModel and eggModel:FindFirstChild("RootPart")
			local gui = rp and (rp:FindFirstChild("GUI/EggGUI") or rp:FindFirstChild("EggGUI") or rp:FindFirstChild("GUI"))
			if gui then
				local t = gui:FindFirstChild("Mutate") or gui:FindFirstChild("Mutation")
				if t and t:IsA("TextLabel") then
					local s = tostring(t.Text or ""):gsub("^%s*(.-)%s$","%1")
					if s ~= "" and s ~= "None" then return s end
				end
			end
		end
		return nil
	end

	-- Build dropdown values
	local eggValues = {}
	if ResEgg then
		for k, v in pairs(ResEgg) do
			local key = tostring(k)
			if not key:match("^_") and key ~= "_index" and key ~= "__index" then
				local name = (type(v) == "table" and (v.Type or v.Name)) or key
				table.insert(eggValues, tostring(name))
			end
		end
		table.sort(eggValues)
	end
	local petValues = {}
	if ResPet then
		for k, v in pairs(ResPet) do
			local key = tostring(k)
			if not key:match("^_") and key ~= "_index" and key ~= "__index" then
				local name = (type(v) == "table" and (v.ID or v.Type or v.Name)) or key
				table.insert(petValues, tostring(name))
			end
		end
		table.sort(petValues)
	end
	local mutateValues = {}
	if ResMutate then
		for k, v in pairs(ResMutate) do
			local key = tostring(k)
			if not key:match("^_") and key ~= "_index" and key ~= "__index" then
				table.insert(mutateValues, tostring(v.ID or key))
			end
		end
		table.sort(mutateValues)
	end

	-- Buy controls
	local selectedEggs = nil -- table or nil
	local selectedMutates = nil -- table or nil
	local buyEnabled = false
	local autoHatchEnabled = false

	BuyTab:Section({ Title = "Egg Multi Mutation", Icon = "egg" })
	local buyEggDropdown = BuyTab:Dropdown({
		Title = "Egg (Multi)",
		Values = eggValues,
		AllowNone = true,
		Multi = true,
		Callback = function(v)
			if type(v) == "table" then selectedEggs = v elseif v == nil then selectedEggs = nil else selectedEggs = { tostring(v) } end
		end
	})
	local buyMutateDropdown = BuyTab:Dropdown({
		Title = "Mutation (Multi)",
		Values = mutateValues,
		AllowNone = true,
		Multi = true,
		Callback = function(v)
			if type(v) == "table" then selectedMutates = v elseif v == nil then selectedMutates = nil else selectedMutates = { tostring(v) } end
		end
	})
	BuyTab:Section({ Title = "Buy Enabled", Icon = "shopping-bag" })
	local buyToggle = BuyTab:Toggle({
		Title = "Buy Enabled",
		Desc = "Buy eggs matching selections",
		Value = false,
		Callback = function(v) buyEnabled = v end
	})

	BuyTab:Section({ Title = "Auto Hatch", Icon = "egg" })
	BuyTab:Toggle({ Title = "Auto Hatch", Value = false, Callback = function(v) autoHatchEnabled = v end })

	BuyTab:Section({ Title = "Auto Claim Money", Icon = "coins" })
	local autoClaimToggle = BuyTab:Toggle({ Title = "Auto Claim Money", Value = false, Callback = function(v)
		autoClaimEnabled = v and true or false
		if v then startAutoClaim() end
	end })

	-- Buy loop
	task.spawn(function()
		while true do
			if buyEnabled then
				local belt = getActiveBelt()
				if belt then
					for _, ch in ipairs(belt:GetChildren()) do
						if ch:IsA("Model") then
							local uid = ch.Name
							local t = ch:GetAttribute("Type") or ch:GetAttribute("EggType") or ch:GetAttribute("Name")
							local m = normalizeMutation(getEggMutationFromGUI(uid))
							local eggsSelected = tableHasAny(selectedEggs)
							local mutsSelected = tableHasAny(selectedMutates)
							local okToBuy = false
							if eggsSelected then
								okToBuy = listHas(selectedEggs, t) and (not mutsSelected or listHas(selectedMutates, m))
							elseif mutsSelected then
								okToBuy = listHas(selectedMutates, m)
							else
								okToBuy = true -- nothing selected => buy anything
							end
							if okToBuy then
								buyEggByUID(uid)
								focusEggByUID(uid)
								break
							end
						end
					end
				end
			end
			task.wait(0.4)
		end
	end)

	-- Auto Hatch loop (Buy tab toggle)
	task.spawn(function()
		while true do
			if autoHatchEnabled then
				local container = workspace:FindFirstChild("PlayerBuiltBlocks")
				if container then
					for _, m in ipairs(container:GetChildren()) do
						if isOwnedEggModel(m) then hatchEggDirectly(m.Name) task.wait(0.05) end
					end
				end
			end
			task.wait(0.8)
		end
	end)

	-- Place controls
	local placeMode = "" -- Egg | Pet | Both
	local placeMutates = nil -- table or nil
	local placeEggs = nil -- table or nil
	local placeSpeedMin = 0
	local placeEnabled = false

	PlaceTab:Section({ Title = "Mode", Icon = "list" })
	PlaceTab:Dropdown({ Title = "Mode", Values = {"Egg","Pet","Both"}, Value = "Egg", Callback = function(v) placeMode = v end })
	PlaceTab:Section({ Title = "Filters", Icon = "sliders-horizontal" })
	local placeMutateDropdown = PlaceTab:Dropdown({ Title = "Mutation (Multi)", Values = mutateValues, AllowNone = true, Multi = true, Callback = function(v)
		if type(v) == "table" then placeMutates = v elseif v == nil then placeMutates = nil else placeMutates = { tostring(v) } end
	end })
	local placeEggDropdown = PlaceTab:Dropdown({ Title = "Egg (Multi)", Values = eggValues, AllowNone = true, Multi = true, Callback = function(v)
		if type(v) == "table" then placeEggs = v elseif v == nil then placeEggs = nil else placeEggs = { tostring(v) } end
	end })
	PlaceTab:Section({ Title = "Run Controls", Icon = "settings" })
	local placeMinProduceInput = PlaceTab:Input({ Title = "Min Produce", Value = "0", Placeholder = "e.g. 100", Callback = function(val) placeSpeedMin = tonumber(val) or 0 end })
	local placeToggle = PlaceTab:Toggle({ Title = "Place Enabled", Value = false, Callback = function(v) placeEnabled = v end })

	-- Minimal helpers for placing
	local function getEggContainer()
		local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
		local data = pg and pg:FindFirstChild("Data")
		return data and data:FindFirstChild("Egg") or nil
	end
	local function listAvailableEggUIDs()
		local eg = getEggContainer()
		local items = {}
		if not eg then return items end
		for _, child in ipairs(eg:GetChildren()) do
			if #child:GetChildren() == 0 then
				local eggType = child:GetAttribute("T") or child.Name
				table.insert(items, { uid = child.Name, type = eggType })
			end
		end
		return items
	end
	local function getEggMutationFromData(eggUID)
		local eg = getEggContainer()
		local node = eg and eg:FindFirstChild(eggUID)
		if not node then return nil end
		local m = node:GetAttribute("M")
		if tostring(m):lower() == "dino" then m = "Jurassic" end
		return m
	end

	-- Pet placement helpers (produce-based)
	local BENFIT_MAX = 10
	local EXTERNAL_MULT = 1

	local ResBigPet, ResBigFish
	pcall(function()
		local cfg = ReplicatedStorage:WaitForChild("Config")
		ResBigPet = require(cfg:WaitForChild("ResBigPetScale"))
		ResBigFish = require(cfg:WaitForChild("ResBigFishScale"))
	end)

	local function getPetsContainer()
		local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
		local data = pg and pg:FindFirstChild("Data")
		return data and data:FindFirstChild("Pets") or nil
	end

	local function isPetNodePlaced(node)
		if not node then return false end
		local d = node:GetAttribute("D")
		return d ~= nil and tostring(d) ~= ""
	end

	local function calcNormalProduce(def, attrs, bm, v71)
		local base = tonumber(def and def.ProduceRate) or 0
		local v = tonumber(attrs and attrs.V) or 0
		local grow = ((bm - 1) * ((v * 1e-4) ^ 2.24) + 1)
		local mut = 1
		local M = attrs and attrs.M
		if M == "Dino" then M = "Jurassic" end
		if M and ResMutate and ResMutate[M] and ResMutate[M].ProduceRate then
			mut = ResMutate[M].ProduceRate
		end
		v71 = v71 or 1
		local final = math.floor(base * grow * mut * v71 + 1e-9)
		return final
	end

	local function computePetProduceFromNode(node)
		if not node then return nil end
		local attrs = node:GetAttributes()
		local T = attrs.T
		if not T or not ResPet or not ResPet[T] then return nil end
		-- Big pets: skip or compute separately
		if attrs.BPV then
			-- Optional big calc; if unavailable, skip placement decision
			if not (ResBigPet or ResBigFish) then return nil end
			local tbl = (attrs.BPT == "Fish") and ResBigFish or ResBigPet
			local stageDef = nil
			for _, idx in pairs(tbl.__index or {}) do
				local row = tbl[idx]
				if row and (row.EXP or 0) <= (tonumber(attrs.BPV) or 0) then stageDef = row else break end
			end
			if not stageDef then return nil end
			local base = tonumber(stageDef.Produce) or 0
			return base -- simplified; game multiplies by highest BigRate mutation on model
		end
		return calcNormalProduce(ResPet[T], attrs, BENFIT_MAX, EXTERNAL_MULT)
	end

	local function listUnplacedPets()
		local pets = getPetsContainer()
		local out = {}
		if not pets then return out end
		for _, node in ipairs(pets:GetChildren()) do
			if not isPetNodePlaced(node) then
				local attrs = node:GetAttributes()
				local uid = node.Name
				local typ = attrs.T
				local mut = attrs.M
				if mut == "Dino" then mut = "Jurassic" end
				local prod = computePetProduceFromNode(node)
				table.insert(out, { uid = uid, type = typ, mutate = mut, produce = prod or 0 })
			end
		end
		return out
	end

	local function isOceanPetType(petType)
		if not petType or not ResPet then return false end
		local def = ResPet[petType]
		if not def then return false end
		if def.Category then
			local c = string.lower(tostring(def.Category))
			return c:find("ocean") or c:find("water") or c:find("sea") or false
		end
		return false
	end

	local function findAvailableTileForPetType(petType)
		local island = getAssignedIslandName()
		if not island then return nil end
		local idx = tonumber((island:match("(%d+)") or ""))
		if not idx then return nil end
		local parts = isOceanPetType(petType) and getWaterFarmParts(idx) or getFarmParts(idx)
		for _, p in ipairs(parts) do
			if not isFarmTileOccupied(p, 6) then return p end
		end
		return nil
	end

	local function placePetAtTile(tilePart, petUID)
		return placeEggAtTile(tilePart, petUID)
	end

	-- Place loop (supports Egg/Pet/Both)
	task.spawn(function()
		while true do
			if placeEnabled then
				local doEgg = (placeMode == "Egg" or placeMode == "Both")
				local doPet = (placeMode == "Pet" or placeMode == "Both")
				local anyPlaced = false
				
				if doEgg then
					local eggs = listAvailableEggUIDs()
					if #eggs > 0 then
						for _, e in ipairs(eggs) do
							local ok = true
							if tableHasAny(placeEggs) and (not listHas(placeEggs, e.type)) then ok = false end
							if ok and tableHasAny(placeMutates) then
								local m = getEggMutationFromData(e.uid)
								ok = listHas(placeMutates, m)
							end
							-- if neither filter selected, ok remains true (place anything)
							if ok then
								local tile = findAvailableTileForEggType(e.type)
								if not tile then
									-- Try unlock once, then check again
									local unlocked = pcall(tryAutoUnlockSomeTiles)
									if unlocked then
										task.wait(0.3) -- Give unlock time to process
										tile = findAvailableTileForEggType(e.type)
									end
								end
								if tile then
									placeEggAtTile(tile, e.uid)
									anyPlaced = true
									task.wait(0.2) -- Small delay after successful placement
									break
								else
									-- No tile available even after unlock attempt - skip this egg
									break
								end
							end
						end
					end
				end
				
				if doPet then
					-- Pet mode: place from inventory using produce threshold and optional mutation filter
					local candidates = listUnplacedPets()
					if #candidates > 0 then
						-- filter
						local filtered = {}
						for _, it in ipairs(candidates) do
							local ok = true
							if tableHasAny(placeMutates) and (not listHas(placeMutates, it.mutate or "")) then ok = false end
							if ok and placeSpeedMin > 0 and (tonumber(it.produce or 0) < placeSpeedMin) then ok = false end
							if ok then table.insert(filtered, it) end
						end
						if #filtered == 0 and (not tableHasAny(placeMutates)) and (placeSpeedMin <= 0) then
							filtered = candidates -- no filters selected -> place anything
						end
						-- sort best first by produce
						table.sort(filtered, function(a,b) return (a.produce or 0) > (b.produce or 0) end)
						
						for _, it in ipairs(filtered) do
							local tile = findAvailableTileForPetType(it.type)
							if not tile then
								-- Try unlock once, then check again
								local unlocked = pcall(tryAutoUnlockSomeTiles)
								if unlocked then
									task.wait(0.3) -- Give unlock time to process
									tile = findAvailableTileForPetType(it.type)
								end
							end
							if tile then
								placePetAtTile(tile, it.uid)
								anyPlaced = true
								task.wait(0.2) -- Small delay after successful placement
								break
							else
								-- No tile available even after unlock attempt - skip this pet
								break
							end
						end
					end
				end
				
				-- If nothing was placed and we have items, wait longer to avoid spam
				if not anyPlaced and ((doEgg and #listAvailableEggUIDs() > 0) or (doPet and #listUnplacedPets() > 0)) then
					task.wait(2.0) -- Longer wait when tiles are full
				else
					task.wait(0.6) -- Normal wait when no items or successful placement
				end
			else
				task.wait(1.0) -- Wait when disabled
			end
		end
	end)

	-- Recall controls
	local recallEnabled = false
	local recallMinProduce = 0
	local recallMode = "Both" -- Regular | Water | Both
	local recallNonMutatedOnly = false -- recall only non-mutated when true

	RecallTab:Section({ Title = "Mode", Icon = "target" })
	local recallModeDropdown = RecallTab:Dropdown({ Title = "Mode", Values = {"Regular","Water","Both"}, Value = "Both", Callback = function(v) recallMode = v end })
	RecallTab:Section({ Title = "Settings", Icon = "sliders-horizontal" })
	local recallMinProduceInput = RecallTab:Input({ Title = "Min Produce", Value = "0", Placeholder = "e.g. 200", Callback = function(v) recallMinProduce = tonumber(v) or 0 end })
	local recallNonMutatedToggle = RecallTab:Toggle({ Title = "Non-Mutated Only", Value = false, Callback = function(v) recallNonMutatedOnly = v end })
	RecallTab:Section({ Title = "Run Controls", Icon = "settings" })
	local recallToggle = RecallTab:Toggle({ Title = "Auto Recall", Value = false, Callback = function(v) recallEnabled = v end })

	-- Recall loop (scoped by Regular/Water/Both)
	task.spawn(function()
		while true do
			if recallEnabled and recallMinProduce > 0 then
				local petsFolder = workspace:FindFirstChild("Pets")
				if petsFolder then
					for _, m in ipairs(petsFolder:GetChildren()) do
						if m:IsA("Model") then
							local rp = m:FindFirstChild("RootPart")
							if rp and not rp:FindFirstChild("GUI/BigPetGUI") then
								local node = getPetsContainer() and getPetsContainer():FindFirstChild(m.Name)
								if node then
									local attrs = node:GetAttributes()
									local typ = attrs.T
									local mut = attrs.M
									if mut == "Dino" then mut = "Jurassic" end
									local isOcean = isOceanPetType(typ)
									-- Scope check: Regular excludes ocean; Water only ocean; Both any
									local scopeOk = (recallMode == "Both") or (recallMode == "Water" and isOcean) or (recallMode == "Regular" and not isOcean)
									local mutOk = (not recallNonMutatedOnly) or (mut == nil or tostring(mut) == "")
									if scopeOk and mutOk then
										local prod = computePetProduceFromNode(node)
										if prod and prod < recallMinProduce then
											pcall(function()
												ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer("Del", m.Name)
											end)
											break
										end
									end
								end
							end
						end
					end
				end
			end
			task.wait(0.8)
		end
	end)

	-- Shop controls (Upgrade, Fruit, Feed)
	local shopUpgrade = false
	local shopFruit = false
	local shopFeed = false

	local fruitList = {}
	for name, _ in pairs(FruitData) do table.insert(fruitList, name) end
	table.sort(fruitList)
	table.insert(fruitList, 1, "Any")

	ShopTab:Section({ Title = "Buy Fruit", Icon = "apple" })
	local buyFruitDropdown = ShopTab:Dropdown({ Title = "Fruit for Auto Buy (Multi)", Values = fruitList, AllowNone = true, Multi = true, Callback = function(v)
		if type(v) == "table" then SelectedBuyFruits = v elseif v == nil then SelectedBuyFruits = nil else SelectedBuyFruits = { tostring(v) } end
	end })
	local buyFruitToggle = ShopTab:Toggle({ Title = "Auto Buy Fruit", Value = false, Callback = function(v)
		autoBuyFruitEnabled = v
		shopFruit = v
		if v then startAutoBuyFruit() end
	end })

	ShopTab:Section({ Title = "Feed Big Pets", Icon = "bone" })
	local feedFruitDropdown = ShopTab:Dropdown({ Title = "Fruit for Auto Feed (Multi)", Values = fruitList, AllowNone = true, Multi = true, Callback = function(v)
		if type(v) == "table" then SelectedFeedFruits = v elseif v == nil then SelectedFeedFruits = nil else SelectedFeedFruits = { tostring(v) } end
	end })
	local feedToggle = ShopTab:Toggle({ Title = "Auto Feed Big Pets", Value = false, Callback = function(v)
		shopFeed = v
		if v then startAutoFeed() end
	end })

	ShopTab:Section({ Title = "Conveyors", Icon = "cog" })
	local upgradeToggle = ShopTab:Toggle({ Title = "Auto Upgrade Conveyors", Value = false, Callback = function(v)
		shopUpgrade = v
	end })

	-- Shop loop: upgrades and guided next level
	task.spawn(function()
		while true do
			if shopUpgrade then
				-- Prefer next-level based on GameFlag; fallback to sweep
				local ok = pcall(function() tryUpgradeConveyorNext() end)
				if not ok then pcall(tryUpgradeConveyors) end
			end
			task.wait(1.2)
		end
	end)


	-- Load ConfigManager for save system
	local ConfigManager = Window.ConfigManager
	
	-- Config name input variable
	local configFileName = ""
	
	-- Config Loading Queue System
	local configLoadQueue = {}
	local isLoadingConfig = false
	
	local function queueConfigLoad(configName, isAutoLoad)
		table.insert(configLoadQueue, {
			configName = configName,
			isAutoLoad = isAutoLoad or false,
			timestamp = tick()
		})
		
		-- Process queue if not already processing
		if not isLoadingConfig then
			task.spawn(processConfigQueue)
		end
	end
	
	local function processConfigQueue()
		if isLoadingConfig or #configLoadQueue == 0 then return end
		
		isLoadingConfig = true
		local configToLoad = table.remove(configLoadQueue, 1)
		
		-- Wait for UI to be fully ready
		task.wait(0.5)
		
		pcall(function()
			local loadConfig = ConfigManager:CreateConfig(configToLoad.configName)
			
			-- Register all elements
			loadConfig:Register("buyToggleElement", buyToggle)
			loadConfig:Register("autoClaimElement", autoClaimToggle)
			loadConfig:Register("placeToggleElement", placeToggle)
			loadConfig:Register("autoBuyFruitElement", buyFruitToggle)
			loadConfig:Register("autoFeedElement", feedToggle)
			loadConfig:Register("upgradeToggleElement", upgradeToggle)
			loadConfig:Register("buyEggDropdownElement", buyEggDropdown)
			loadConfig:Register("buyMutateDropdownElement", buyMutateDropdown)
			loadConfig:Register("placeEggDropdownElement", placeEggDropdown)
			loadConfig:Register("placeMutateDropdownElement", placeMutateDropdown)
			loadConfig:Register("buyFruitDropdownElement", buyFruitDropdown)
			loadConfig:Register("feedFruitDropdownElement", feedFruitDropdown)
			
			-- Load the config
			loadConfig:Load()
			
			-- Update auto-buy variables immediately
			if buyEggDropdown.Value and type(buyEggDropdown.Value) == "table" then
				selectedEggs = buyEggDropdown.Value
			else
				selectedEggs = nil
			end
			
			if buyMutateDropdown.Value and type(buyMutateDropdown.Value) == "table" then
				selectedMutates = buyMutateDropdown.Value
			else
				selectedMutates = nil
			end
			
			if buyFruitDropdown.Value and type(buyFruitDropdown.Value) == "table" then
				SelectedBuyFruits = buyFruitDropdown.Value
			else
				SelectedBuyFruits = nil
			end
			
			-- Force refresh dropdowns with ModuleScript data
			task.wait(0.1)
			pcall(function()
				-- Store the loaded values before refreshing
				local savedSelections = {
					buyEgg = buyEggDropdown.Value,
					buyMutate = buyMutateDropdown.Value,
					placeEgg = placeEggDropdown.Value,
					placeMutate = placeMutateDropdown.Value,
					buyFruit = buyFruitDropdown.Value,
					feedFruit = feedFruitDropdown.Value
				}
				
				-- Re-fetch ModuleScript data
				local ResEgg = require(game.ReplicatedStorage.Modules.ResEgg)
				local ResMutate = require(game.ReplicatedStorage.Modules.ResMutate)
				local ResPet = require(game.ReplicatedStorage.Modules.ResPet)
				local ResConveyor = require(game.ReplicatedStorage.Modules.ResConveyor)
				
				-- Rebuild values
				local eggValues = {}
				for eggName, eggData in pairs(ResEgg) do
					if eggData.Enabled then
						table.insert(eggValues, eggName)
					end
				end
				table.sort(eggValues)
				
				local mutateValues = {}
				for mutateName, mutateData in pairs(ResMutate) do
					if mutateData.Enabled then
						table.insert(mutateValues, mutateName)
					end
				end
				table.sort(mutateValues)
				
				local fruitList = {}
				for fruitName, fruitData in pairs(ResConveyor.Fruits) do
					table.insert(fruitList, fruitName)
				end
				table.sort(fruitList)
				
				-- Update dropdown values
				if buyEggDropdown.SetValues then buyEggDropdown:SetValues(eggValues) end
				if buyMutateDropdown.SetValues then buyMutateDropdown:SetValues(mutateValues) end
				if placeEggDropdown.SetValues then placeEggDropdown:SetValues(eggValues) end
				if placeMutateDropdown.SetValues then placeMutateDropdown:SetValues(mutateValues) end
				if buyFruitDropdown.SetValues then buyFruitDropdown:SetValues(fruitList) end
				if feedFruitDropdown.SetValues then feedFruitDropdown:SetValues(fruitList) end
				
				task.wait(0.2)
				
				-- Reapply selections
				if savedSelections.buyEgg and type(savedSelections.buyEgg) == "table" then
					for _, item in ipairs(savedSelections.buyEgg) do
						pcall(function() buyEggDropdown:Select(item) end)
					end
				end
				
				if savedSelections.buyMutate and type(savedSelections.buyMutate) == "table" then
					for _, item in ipairs(savedSelections.buyMutate) do
						pcall(function() buyMutateDropdown:Select(item) end)
					end
				end
				
				if savedSelections.placeEgg and type(savedSelections.placeEgg) == "table" then
					for _, item in ipairs(savedSelections.placeEgg) do
						pcall(function() placeEggDropdown:Select(item) end)
					end
				end
				
				if savedSelections.placeMutate and type(savedSelections.placeMutate) == "table" then
					for _, item in ipairs(savedSelections.placeMutate) do
						pcall(function() placeMutateDropdown:Select(item) end)
					end
				end
				
				if savedSelections.buyFruit and type(savedSelections.buyFruit) == "table" then
					for _, item in ipairs(savedSelections.buyFruit) do
						pcall(function() buyFruitDropdown:Select(item) end)
					end
				end
				
				if savedSelections.feedFruit and type(savedSelections.feedFruit) == "table" then
					for _, item in ipairs(savedSelections.feedFruit) do
						pcall(function() feedFruitDropdown:Select(item) end)
					end
				end
				
				-- Final update of auto-buy variables
				task.wait(0.1)
				if buyEggDropdown.Value and type(buyEggDropdown.Value) == "table" then
					selectedEggs = buyEggDropdown.Value
				else
					selectedEggs = nil
				end
				
				if buyMutateDropdown.Value and type(buyMutateDropdown.Value) == "table" then
					selectedMutates = buyMutateDropdown.Value
				else
					selectedMutates = nil
				end
				
				if buyFruitDropdown.Value and type(buyFruitDropdown.Value) == "table" then
					SelectedBuyFruits = buyFruitDropdown.Value
				else
					SelectedBuyFruits = nil
				end
			end)
			
			-- Show notification
				WindUI:Notify({
				Title = configToLoad.isAutoLoad and "Auto Load Complete" or "Config Loaded",
				Content = "Configuration '" .. configToLoad.configName .. "' loaded successfully via queue system!",
					Duration = 3,
				Icon = "check"
			})
		end)
		
		isLoadingConfig = false
		
		-- Process next in queue if any
		if #configLoadQueue > 0 then
			task.wait(0.1)
			task.spawn(processConfigQueue)
		end
	end

	-- Function to get all available configs (EXACT copy of Windui.lua ListFiles pattern)
	local function getAllConfigs()
		local configList = {}
		
		-- Try multiple possible paths where WindUI might save configs
		local possiblePaths = {
			"Zebux",  -- Direct folder
			"WindUI/Zebux", -- WindUI subfolder
			"WindUI/Zebux/config", -- Full WindUI path
			"WindUI/" .. (Window.Folder or "Zebux"), -- Use Window.Folder
			"WindUI/" .. (Window.Folder or "Zebux") .. "/config" -- Full path with Window.Folder
		}
		
		pcall(function()
			if listfiles then
				for _, configPath in ipairs(possiblePaths) do
					pcall(function()
						local files = listfiles(configPath)
						
						-- EXACT same loop as Windui.lua ListFiles()
						for _, file in ipairs(files) do
							local fileName = file:match("([^/]+)%.json$")  -- EXACT same regex as Windui.lua
							if fileName and fileName ~= "" then
								-- Ensure fileName is a string and not already added
								fileName = tostring(fileName)
								local exists = false
								for _, existing in ipairs(configList) do
									if existing == fileName then
										exists = true
										break
									end
								end
								if not exists then
									table.insert(configList, fileName)
								end
							end
			end
		end)
				end
			end
		end)
		
		-- Sort alphabetically
		table.sort(configList)
		return configList
	end
	
	-- Dropdown declaration for later use
	local configDropdown
	
	
	-- Save Tab Sections for better organization
	SaveTab:Section({
		Title = "Create New Config",
		Icon = "plus"
	})

	-- Config Name Input (move up to create section)
	configNameInput = SaveTab:Input({
			Title = "Config Name", 
		Placeholder = "Enter config name...",
		Callback = function(value)
			configFileName = value
			end 
		})

	-- Save button (move up to create section)
		SaveTab:Button({ 
			Title = "Save Config", 
			Icon = "save",
		Desc = "Saves elements to config",
			Callback = function()
		if configFileName and configFileName ~= "" then
			pcall(function()
				-- Create new config with custom name
				local currentConfig = ConfigManager:CreateConfig(configFileName)
				
				-- Register all elements to the new config
				currentConfig:Register("buyToggleElement", buyToggle)
				currentConfig:Register("autoClaimElement", autoClaimToggle)
				currentConfig:Register("placeToggleElement", placeToggle)
				currentConfig:Register("autoBuyFruitElement", buyFruitToggle)
				currentConfig:Register("autoFeedElement", feedToggle)
				currentConfig:Register("upgradeToggleElement", upgradeToggle)
				currentConfig:Register("buyEggDropdownElement", buyEggDropdown)
				currentConfig:Register("buyMutateDropdownElement", buyMutateDropdown)
				currentConfig:Register("placeEggDropdownElement", placeEggDropdown)
				currentConfig:Register("placeMutateDropdownElement", placeMutateDropdown)
				currentConfig:Register("buyFruitDropdownElement", buyFruitDropdown)
				currentConfig:Register("feedFruitDropdownElement", feedFruitDropdown)
				
				-- Register Place tab elements
				currentConfig:Register("placeToggleElement", placeToggle)
				currentConfig:Register("placeMinProduceElement", placeMinProduceInput)
				
				-- Register Recall tab elements
				currentConfig:Register("recallToggleElement", recallToggle)
				currentConfig:Register("recallModeDropdownElement", recallModeDropdown)
				currentConfig:Register("recallMinProduceElement", recallMinProduceInput)
				currentConfig:Register("recallNonMutatedToggleElement", recallNonMutatedToggle)
				
				-- Register AutoFishSystem elements (same way as other working elements)
				if AutoFishSystem and AutoFishSystem.GetUIElements then
					local fishUI = AutoFishSystem.GetUIElements()
					if fishUI.toggle and fishUI.dropdown then
						print("Registering AutoFish elements like other working elements")
						currentConfig:Register("autoFishToggleElement", fishUI.toggle)
						currentConfig:Register("autoFishBaitElement", fishUI.dropdown)
					else
						print("AutoFish UI elements not available")
					end
				else
					print("AutoFishSystem GetUIElements not available")
				end
				
				-- Register Trade elements with custom Get/Set functions
				currentConfig:Register("tradeToggleElement", {
					Get = function() return Trade and Trade.enabled or false end,
					Set = function(value) 
						if Trade then 
							Trade.enabled = value 
							if tradeToggle and tradeToggle.SetValue then 
								tradeToggle:SetValue(value) 
							end
						end 
					end
				})
				currentConfig:Register("tradeModeElement", {
					Get = function() return Trade and Trade.mode or "Both" end,
					Set = function(value) if Trade then Trade.mode = value or "Both" end end
				})
				currentConfig:Register("tradeLimitElement", {
					Get = function() return Trade and Trade.limit or 10 end,
					Set = function(value) 
						local n = tonumber(value)
						if Trade and n and n >= 1 then 
							Trade.limit = math.floor(n)
							if tradeLimitInput and tradeLimitInput.SetValue then
								tradeLimitInput:SetValue(tostring(Trade.limit))
							end
						end 
					end
				})
				
				-- AutoFishSystem registration moved to BEFORE save (see above)
				
				-- Save the config
				currentConfig:Save()
				
				-- Refresh dropdown list
				configDropdown:SetValues(ConfigManager:AllConfigs())
				
				-- Show success notification
				WindUI:Notify({
					Title = "Config Saved",
					Content = "Configuration '" .. configFileName .. "' saved successfully!",
					Duration = 3,
					Icon = "check"
				})
			end)
		else
			WindUI:Notify({
				Title = "Error",
				Content = "Please enter a config name first!",
				Duration = 3,
				Icon = "alert-triangle"
				})
			end 
			end 
		})

	SaveTab:Section({
		Title = "Load Existing Config",
		Icon = "folder-open"
	})

	-- Load Existing Config Dropdown (move to load section)
	local configFiles = getAllConfigs()
	configDropdown = SaveTab:Dropdown({
		Title = "Select Config",
		Multi = false,
		AllowNone = true,
		Values = configFiles,
		Callback = function(selectedConfig)
			-- Extract just the filename without path and extension for WindUI ConfigManager
			if selectedConfig then
				local justName = selectedConfig:match("([^/\\]+)%.json$") or selectedConfig:match("([^/\\]+)$") or selectedConfig
				configFileName = justName
			else
				configFileName = selectedConfig
			end
		end
	})

	-- Load button (simplified approach)
		SaveTab:Button({ 
			Title = "Load Config", 
		Icon = "folder-open",
		Desc = "Loads elements from config",
			Callback = function()
			local configToLoad = configFileName or ""
			
			if configToLoad and configToLoad ~= "" and configToLoad ~= "None" then
				print("Loading config: " .. configToLoad) -- Debug
				
				local success, error = pcall(function()
					-- Create a new config object
					local loadConfig = ConfigManager:CreateConfig(configToLoad)
					
					-- Register all elements
					loadConfig:Register("buyToggleElement", buyToggle)
					loadConfig:Register("autoClaimElement", autoClaimToggle)
					loadConfig:Register("placeToggleElement", placeToggle)
					loadConfig:Register("autoBuyFruitElement", buyFruitToggle)
					loadConfig:Register("autoFeedElement", feedToggle)
					loadConfig:Register("upgradeToggleElement", upgradeToggle)
					loadConfig:Register("buyEggDropdownElement", buyEggDropdown)
					loadConfig:Register("buyMutateDropdownElement", buyMutateDropdown)
					loadConfig:Register("placeEggDropdownElement", placeEggDropdown)
					loadConfig:Register("placeMutateDropdownElement", placeMutateDropdown)
					loadConfig:Register("buyFruitDropdownElement", buyFruitDropdown)
					loadConfig:Register("feedFruitDropdownElement", feedFruitDropdown)
					
					-- Register Place tab elements
					loadConfig:Register("placeToggleElement", placeToggle)
					loadConfig:Register("placeMinProduceElement", placeMinProduceInput)
					
					-- Register Recall tab elements
					loadConfig:Register("recallToggleElement", recallToggle)
					loadConfig:Register("recallModeDropdownElement", recallModeDropdown)
					loadConfig:Register("recallMinProduceElement", recallMinProduceInput)
					loadConfig:Register("recallNonMutatedToggleElement", recallNonMutatedToggle)
					
					-- Register Trade elements with custom Get/Set functions
					loadConfig:Register("tradeToggleElement", {
						Get = function() return Trade and Trade.enabled or false end,
						Set = function(value) 
							if Trade then 
								Trade.enabled = value 
								if tradeToggle and tradeToggle.SetValue then 
									tradeToggle:SetValue(value) 
								end
							end 
						end
					})
					loadConfig:Register("tradeModeElement", {
						Get = function() return Trade and Trade.mode or "Both" end,
						Set = function(value) if Trade then Trade.mode = value or "Both" end end
					})
					loadConfig:Register("tradeLimitElement", {
						Get = function() return Trade and Trade.limit or 10 end,
						Set = function(value) 
							local n = tonumber(value)
							if Trade and n and n >= 1 then 
								Trade.limit = math.floor(n)
								if tradeLimitInput and tradeLimitInput.SetValue then
									tradeLimitInput:SetValue(tostring(Trade.limit))
								end
							end 
						end
					})
					
					-- Register AutoFishSystem elements (same way as other working elements)
					if AutoFishSystem and AutoFishSystem.GetUIElements then
						local fishUI = AutoFishSystem.GetUIElements()
						if fishUI.toggle and fishUI.dropdown then
							loadConfig:Register("autoFishToggleElement", fishUI.toggle)
							loadConfig:Register("autoFishBaitElement", fishUI.dropdown)
						end
					end
					
					print("Registered elements, loading config...") -- Debug
					
					-- Load the config
					loadConfig:Load()
					
					print("Config loaded, updating variables...") -- Debug
					
					-- Manually sync AutoFishSystem state after config load
					if AutoFishSystem and AutoFishSystem.GetUIElements then
						local fishUI = AutoFishSystem.GetUIElements()
						if fishUI.toggle and fishUI.dropdown then
							local toggleValue = fishUI.toggle.Value
							local baitValue = fishUI.dropdown.Value
							print("Syncing AutoFish state - Toggle:", toggleValue, "Bait:", baitValue)
							if toggleValue ~= nil then AutoFishSystem.SetEnabled(toggleValue) end
							if baitValue then AutoFishSystem.SetBait(baitValue) end
						end
					end
					
					-- Wait a moment for the load to complete
					task.wait(0.2)
					
					-- Update auto-buy variables immediately to prevent random buying
					if buyEggDropdown.Value and type(buyEggDropdown.Value) == "table" then
						selectedEggs = buyEggDropdown.Value
						print("Updated selectedEggs: " .. table.concat(selectedEggs, ", "))
					else
						selectedEggs = nil
						print("selectedEggs set to nil")
					end
					
					if buyMutateDropdown.Value and type(buyMutateDropdown.Value) == "table" then
						selectedMutates = buyMutateDropdown.Value
						print("Updated selectedMutates: " .. table.concat(selectedMutates, ", "))
					else
						selectedMutates = nil
						print("selectedMutates set to nil")
					end
					
					if buyFruitDropdown.Value and type(buyFruitDropdown.Value) == "table" then
						SelectedBuyFruits = buyFruitDropdown.Value
						print("Updated SelectedBuyFruits: " .. table.concat(SelectedBuyFruits, ", "))
					else
						SelectedBuyFruits = nil
						print("SelectedBuyFruits set to nil")
					end
					
					print("Variables updated successfully")
				end)
				
				if success then
				WindUI:Notify({
						Title = "Config Loaded",
						Content = "Configuration '" .. configToLoad .. "' loaded successfully!",
					Duration = 3,
						Icon = "check"
					})
				else
					print("Error loading config: " .. tostring(error))
					WindUI:Notify({
						Title = "Load Error",
						Content = "Error loading config: " .. tostring(error),
						Duration = 5,
						Icon = "alert-triangle"
				})
			end 
			else
				WindUI:Notify({
					Title = "Error",
					Content = "Please select a config from the dropdown first!",
					Duration = 3,
					Icon = "alert-triangle"
		})
	end
		end 
	})

	-- Refresh configs button (move to load section)
	SaveTab:Button({ 
		Title = "Refresh Config List", 
		Icon = "refresh-cw",
		Desc = "Update the config dropdown list",
		Callback = function()
			pcall(function()
				local newConfigs = getAllConfigs()
				
				-- Use the correct WindUI refresh method (following Windui.lua example)
				configDropdown:Refresh(newConfigs)
				
				WindUI:Notify({
					Title = "List Refreshed",
					Content = "Found " .. #newConfigs .. " config(s). Config list updated!",
					Duration = 3,
					Icon = "refresh-cw"
				})
			end)
		end
	})

	SaveTab:Section({
		Title = "Auto Load Settings",
		Icon = "power"
	})

	-- Auto Load functionality
	local autoLoadConfigName = ""
	local autoLoadEnabled = false
	
	-- Load auto load settings on startup
		pcall(function()
		if isfile("BuildAZoo_AutoLoad.json") then
			local HttpService = game:GetService("HttpService")
			local autoLoadData = HttpService:JSONDecode(readfile("BuildAZoo_AutoLoad.json"))
			if autoLoadData then
				autoLoadConfigName = autoLoadData.configName or ""
				autoLoadEnabled = autoLoadData.enabled or false
			end
		end
	end)
	
	-- Auto Load button (with dynamic description)
	local autoLoadButton
	autoLoadButton = SaveTab:Button({
		Title = "Set Auto Load",
		Icon = "power",
		Desc = autoLoadConfigName ~= "" and ("Once script loads, this config will be loaded up: " .. autoLoadConfigName .. ".json") or "Once script loads, this config will be loaded up: None selected",
		Callback = function()
			if configFileName and configFileName ~= "" and configFileName ~= "None" then
				autoLoadConfigName = configFileName
				autoLoadEnabled = true
				
				-- Update button description dynamically
				if autoLoadButton and autoLoadButton.SetDesc then
					autoLoadButton:SetDesc("Once script loads, this config will be loaded up: " .. autoLoadConfigName .. ".json")
				end
				
				-- Save auto load preference
				pcall(function()
					local HttpService = game:GetService("HttpService")
					local autoLoadData = {
						enabled = true,
						configName = autoLoadConfigName
					}
					writefile("BuildAZoo_AutoLoad.json", HttpService:JSONEncode(autoLoadData))
				end)
				
				WindUI:Notify({
					Title = "Auto Load Set",
					Content = "Config '" .. autoLoadConfigName .. "' will auto-load on script startup!",
					Duration = 3,
					Icon = "check"
				})
			else
				WindUI:Notify({
					Title = "No Config Selected",
					Content = "Please select a config from the dropdown first!",
					Duration = 3,
					Icon = "alert-triangle"
				})
			end
		end
	})
	
	-- Disable Auto Load button
	SaveTab:Button({
		Title = "Disable Auto Load",
		Icon = "power-off",
		Desc = "Disable automatic config loading on startup",
		Callback = function()
			autoLoadConfigName = ""
			autoLoadEnabled = false
			
			-- Update auto load button description
			if autoLoadButton and autoLoadButton.SetDesc then
				autoLoadButton:SetDesc("Once script loads, this config will be loaded up: None selected")
			end
			
			-- Save disabled state
			pcall(function()
				local HttpService = game:GetService("HttpService")
				local autoLoadData = {
					enabled = false,
					configName = ""
				}
				writefile("BuildAZoo_AutoLoad.json", HttpService:JSONEncode(autoLoadData))
			end)
			
			WindUI:Notify({
				Title = "Auto Load Disabled",
				Content = "Auto load has been disabled.",
				Duration = 2,
				Icon = "info"
			})
		end
	})

	-- Initialize auto-loading for original config system
	pcall(function()
		Config:SetAutoLoad(true)
	end)

	-- Auto Load on Script Startup - Simplified
	task.spawn(function()
		task.wait(3) -- Wait for UI to fully load
		
			pcall(function()
			-- Check if auto load file exists and is enabled
			if isfile("BuildAZoo_AutoLoad.json") then
				local HttpService = game:GetService("HttpService")
				local autoLoadData = HttpService:JSONDecode(readfile("BuildAZoo_AutoLoad.json"))
				
				if autoLoadData and autoLoadData.enabled and autoLoadData.configName and autoLoadData.configName ~= "" then
					local configToAutoLoad = autoLoadData.configName
					print("Auto-loading config: " .. configToAutoLoad) -- Debug
					
					local success, error = pcall(function()
						-- Create a new config object
						local loadConfig = ConfigManager:CreateConfig(configToAutoLoad)
						
						-- Register all elements
						loadConfig:Register("buyToggleElement", buyToggle)
						loadConfig:Register("autoClaimElement", autoClaimToggle)
						loadConfig:Register("placeToggleElement", placeToggle)
						loadConfig:Register("autoBuyFruitElement", buyFruitToggle)
						loadConfig:Register("autoFeedElement", feedToggle)
						loadConfig:Register("upgradeToggleElement", upgradeToggle)
						loadConfig:Register("buyEggDropdownElement", buyEggDropdown)
						loadConfig:Register("buyMutateDropdownElement", buyMutateDropdown)
						loadConfig:Register("placeEggDropdownElement", placeEggDropdown)
						loadConfig:Register("placeMutateDropdownElement", placeMutateDropdown)
						loadConfig:Register("buyFruitDropdownElement", buyFruitDropdown)
						loadConfig:Register("feedFruitDropdownElement", feedFruitDropdown)
						
						-- Register Place tab elements
						loadConfig:Register("placeToggleElement", placeToggle)
						loadConfig:Register("placeMinProduceElement", placeMinProduceInput)
						
						-- Register Recall tab elements
						loadConfig:Register("recallToggleElement", recallToggle)
						loadConfig:Register("recallModeDropdownElement", recallModeDropdown)
						loadConfig:Register("recallMinProduceElement", recallMinProduceInput)
						loadConfig:Register("recallNonMutatedToggleElement", recallNonMutatedToggle)
						
						-- Register Trade elements with custom Get/Set functions
						loadConfig:Register("tradeToggleElement", {
							Get = function() return Trade and Trade.enabled or false end,
							Set = function(value) 
								if Trade then 
									Trade.enabled = value 
									if tradeToggle and tradeToggle.SetValue then 
										tradeToggle:SetValue(value) 
									end
								end 
							end
						})
						loadConfig:Register("tradeModeElement", {
							Get = function() return Trade and Trade.mode or "Both" end,
							Set = function(value) if Trade then Trade.mode = value or "Both" end end
						})
						loadConfig:Register("tradeLimitElement", {
							Get = function() return Trade and Trade.limit or 10 end,
							Set = function(value) 
								local n = tonumber(value)
								if Trade and n and n >= 1 then 
									Trade.limit = math.floor(n)
									if tradeLimitInput and tradeLimitInput.SetValue then
										tradeLimitInput:SetValue(tostring(Trade.limit))
									end
								end 
							end
						})
						
						-- Register AutoFishSystem elements (same way as other working elements)
						if AutoFishSystem and AutoFishSystem.GetUIElements then
							local fishUI = AutoFishSystem.GetUIElements()
							if fishUI.toggle and fishUI.dropdown then
								loadConfig:Register("autoFishToggleElement", fishUI.toggle)
								loadConfig:Register("autoFishBaitElement", fishUI.dropdown)
							end
						end
						
						print("Auto-load: Registered elements, loading config...") -- Debug
						
						-- Load the config
						loadConfig:Load()
						
						print("Auto-load: Config loaded, updating variables...") -- Debug
						
						-- Manually sync AutoFishSystem state after config load
						if AutoFishSystem and AutoFishSystem.GetUIElements then
							local fishUI = AutoFishSystem.GetUIElements()
							if fishUI.toggle and fishUI.dropdown then
								local toggleValue = fishUI.toggle.Value
								local baitValue = fishUI.dropdown.Value
								print("Auto-load: Syncing AutoFish state - Toggle:", toggleValue, "Bait:", baitValue)
								if toggleValue ~= nil then AutoFishSystem.SetEnabled(toggleValue) end
								if baitValue then AutoFishSystem.SetBait(baitValue) end
							end
						end
						
						-- Wait a moment for the load to complete
						task.wait(0.2)
						
						-- Update auto-buy variables immediately
						if buyEggDropdown.Value and type(buyEggDropdown.Value) == "table" then
							selectedEggs = buyEggDropdown.Value
							print("Auto-load: Updated selectedEggs: " .. table.concat(selectedEggs, ", "))
						else
							selectedEggs = nil
							print("Auto-load: selectedEggs set to nil")
						end
						
						if buyMutateDropdown.Value and type(buyMutateDropdown.Value) == "table" then
							selectedMutates = buyMutateDropdown.Value
							print("Auto-load: Updated selectedMutates: " .. table.concat(selectedMutates, ", "))
						else
							selectedMutates = nil
							print("Auto-load: selectedMutates set to nil")
						end
						
						if buyFruitDropdown.Value and type(buyFruitDropdown.Value) == "table" then
							SelectedBuyFruits = buyFruitDropdown.Value
							print("Auto-load: Updated SelectedBuyFruits: " .. table.concat(SelectedBuyFruits, ", "))
						else
							SelectedBuyFruits = nil
							print("Auto-load: SelectedBuyFruits set to nil")
						end
						
						print("Auto-load: Variables updated successfully")
					end)
					
					if success then
						WindUI:Notify({
							Title = "Auto Load Complete",
							Content = "Config '" .. configToAutoLoad .. "' loaded automatically on startup!",
							Duration = 4,
							Icon = "check"
						})
					else
						print("Auto-load error: " .. tostring(error))
						WindUI:Notify({
							Title = "Auto Load Failed",
							Content = "Failed to auto-load config: " .. tostring(error),
							Duration = 4,
							Icon = "alert-triangle"
						})
					end
				end
			end
		end)
	end)

	-- Load AutoFishSystem EARLY (before save/load UI) so it's available for config registration
	local function tryLoadAutoFish()
		local ok, mod = pcall(function()
			return loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/main/AutoFishSystem.lua"))()
		end)
		if ok and type(mod) == "table" then return mod end
		ok, mod = pcall(function()
			return loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/AutoFishSystem.lua"))()
		end)
		if ok and type(mod) == "table" then return mod end
		-- executor local fallback
		pcall(function()
			if readfile then
				local paths = {"Build a Zoo/AutoFishSystem.lua","AutoFishSystem.lua"}
				for _, p in ipairs(paths) do
					if isfile and isfile(p) then
						local src = readfile(p)
						local m = loadstring(src)()
						if type(m) == "table" then mod = m break end
					end
				end
			end
		end)
		if type(mod) == "table" then return mod end
		return nil
	end

	AutoFishSystem = tryLoadAutoFish()
	if AutoFishSystem and AutoFishSystem.Init then
		local initSuccess = pcall(function()
			local result = AutoFishSystem.Init({ WindUI = WindUI, FishTab = FishTab, ConfigManager = ConfigManager })
			print("AutoFishSystem.Init result:", result and "SUCCESS" or "FAILED")
		end)
		if not initSuccess then
			print("AutoFishSystem.Init threw error")
		pcall(function()
				WindUI:Notify({ Title = "Fish", Content = "Failed to initialize AutoFishSystem.", Duration = 2 })
		end)
		end
	else
		print("AutoFishSystem not loaded or missing Init function")
		pcall(function()
			WindUI:Notify({ Title = "Fish", Content = "Failed to load AutoFishSystem.", Duration = 2 })
		end)
	end

	-- Trade (Precise Auto Trade) - scoped to reduce locals
	do
		Trade = {
			enabled = false,
			mode = "Both",
			target = "Random Player",
			petTypes = {}, petMuts = {}, eggTypes = {}, eggMuts = {},
			cooldownUntil = {},
			limit = 10, count = 0, lastNoStockAt = 0
		}

		function Trade:getPlayersList()
			local list = {"Random Player"}
			for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(list, p.Name) end end
			return list
		end
		function Trade:toArray(sel)
			local out = {}
			if type(sel) == "table" then for _, v in ipairs(sel) do local s=tostring(v) if s~="" then table.insert(out,s) end end elseif type(sel)=="string" and sel~="" then table.insert(out, sel) end
			return out
		end
		function Trade:isLockedOrPlaced(conf)
			if not conf or not conf:IsA("Configuration") then return true end
			local lk = conf:GetAttribute("LK")
			local d = conf:GetAttribute("D")
			if tonumber(lk) == 1 then return true end
			return d ~= nil and tostring(d) ~= ""
		end
		function Trade:focusUID(uid)
			return pcall(function() ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer("Focus", uid) end)
		end
		function Trade:waitRemoval(folder, uid, timeout)
			timeout = timeout or 3.0
			local deadline = tick() + timeout
			while tick() < deadline do if not folder:FindFirstChild(uid) then return true end task.wait(0.05) end
			return false
		end
		function Trade:resolveTarget(name)
			if name == "Random Player" then local pool = {} for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(pool, p) end end if #pool==0 then return nil end return pool[math.random(1,#pool)] else for _, p in ipairs(Players:GetPlayers()) do if p.Name==name or p.DisplayName==name then return p end end end return nil
		end
		function Trade:shouldSend(kind, tVal, mVal)
			if not tVal or tVal=="" or tVal=="Unknown" then return false end
			if kind=="pet" then
				if #self.petTypes>0 then local ok=false for _,v in ipairs(self.petTypes) do if tostring(v)==tostring(tVal) then ok=true break end end if not ok then return false end end
				if #self.petMuts>0 then if not mVal or mVal=="" then return false end local ok=false for _,v in ipairs(self.petMuts) do if tostring(v)==tostring(mVal) then ok=true break end end if not ok then return false end end
				return true
			else
				if #self.eggTypes>0 then local ok=false for _,v in ipairs(self.eggTypes) do if tostring(v)==tostring(tVal) then ok=true break end end if not ok then return false end end
				if #self.eggMuts>0 then if not mVal or mVal=="" then return false end local ok=false for _,v in ipairs(self.eggMuts) do if tostring(v)==tostring(mVal) then ok=true break end end if not ok then return false end end
				return true
			end
		end
		function Trade:anyMatch(kind, folder)
			if not folder then return false end
			for _, conf in ipairs(folder:GetChildren()) do
				if conf:IsA("Configuration") and not self:isLockedOrPlaced(conf) then
					local tVal = conf:GetAttribute("T")
					local mVal = conf:GetAttribute("M")
					if self:shouldSend(kind, tVal, mVal) then return true end
				end
			end
			return false
		end
		function Trade:sendOne(kind, conf, targetPlayer)
			if not conf or not conf:IsA("Configuration") then return false end
			local uid = conf.Name
			if (self.cooldownUntil[uid] or 0) > tick() then return false end
			if self:isLockedOrPlaced(conf) then return false end
			local tVal = conf:GetAttribute("T")
			local mVal = conf:GetAttribute("M")
			if not self:shouldSend(kind, tVal, mVal) then return false end
			self:focusUID(uid); task.wait(0.05)
			tVal = conf:GetAttribute("T"); mVal = conf:GetAttribute("M")
			if not self:shouldSend(kind, tVal, mVal) then return false end
			local ok = pcall(function() ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(targetPlayer) end)
			if not ok then return false end
			local dataRoot = LocalPlayer and LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Data")
			local folder = dataRoot and dataRoot:FindFirstChild(kind=="pet" and "Pets" or "Egg")
			if not folder then return false end
			local removed = self:waitRemoval(folder, uid, 3.0)
			self.cooldownUntil[uid] = tick() + 1.0
			return removed
		end

		TradeTab:Section({ Title = "Mode & Target", Icon = "target" })
		TradeTab:Dropdown({ Title = "Mode", Values = {"Pets","Eggs","Both"}, Value = "Both", Callback = function(v) Trade.mode = v end })
		targetDropdown = TradeTab:Dropdown({ Title = "Target", Values = Trade:getPlayersList(), Value = "Random Player", Callback = function(v) Trade.target = v end })
		TradeTab:Button({ Title = "Refresh Player List", Callback = function()
			local newList = Trade:getPlayersList()
			if targetDropdown and targetDropdown.SetValues then
				targetDropdown:SetValues(newList)
			end
		end })
		TradeTab:Section({ Title = "Pet Filters", Icon = "paw-print" })
		TradeTab:Dropdown({ Title = "Pet Types (Multi)", Values = petValues, Value = {}, Multi = true, AllowNone = true, Callback = function(v) Trade.petTypes = Trade:toArray(v) end })
		TradeTab:Dropdown({ Title = "Pet Mutations (Multi)", Values = mutateValues, Value = {}, Multi = true, AllowNone = true, Callback = function(v) Trade.petMuts = Trade:toArray(v) end })
		TradeTab:Section({ Title = "Egg Filters", Icon = "egg" })
		TradeTab:Dropdown({ Title = "Egg Types (Multi)", Values = eggValues, Value = {}, Multi = true, AllowNone = true, Callback = function(v) Trade.eggTypes = Trade:toArray(v) end })
		TradeTab:Dropdown({ Title = "Egg Mutations (Multi)", Values = mutateValues, Value = {}, Multi = true, AllowNone = true, Callback = function(v) Trade.eggMuts = Trade:toArray(v) end })
		TradeTab:Section({ Title = "Run Controls", Icon = "settings" })
		tradeLimitInput = TradeTab:Input({ Title = "Max Items This Run", Value = tostring(Trade.limit), Placeholder = "e.g. 10", Callback = function(v) local n=tonumber(v) if n and n>=1 then Trade.limit = math.floor(n) end end })
		tradeToggle = TradeTab:Toggle({ Title = "Auto Trade", Value = false, Callback = function(v) Trade.enabled = v if v then Trade.count = 0 end end })

		task.spawn(function()
			while true do
				if Trade.enabled then
					local tgt = Trade:resolveTarget(Trade.target)
					if tgt then
						local dataRoot = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Data")
						local petsFolder = dataRoot and dataRoot:FindFirstChild("Pets")
						local eggsFolder = dataRoot and dataRoot:FindFirstChild("Egg")
						local hasPetFilter = (#Trade.petTypes>0) or (#Trade.petMuts>0)
						local hasEggFilter = (#Trade.eggTypes>0) or (#Trade.eggMuts>0)
						local needPets = (Trade.mode=="Pets") or (Trade.mode=="Both")
						local needEggs = (Trade.mode=="Eggs") or (Trade.mode=="Both")
						local noStock = false
						if hasPetFilter and needPets and not Trade:anyMatch("pet", petsFolder) then noStock = true end
						if hasEggFilter and needEggs and not Trade:anyMatch("egg", eggsFolder) then noStock = true end
						if noStock then
							if tick() - Trade.lastNoStockAt > 2 then Trade.lastNoStockAt = tick() WindUI:Notify({ Title = "No Stock", Content = "Selected pet/egg filters are out of stock.", Duration = 2 }) end
						else
							local sent = false
							if needPets and petsFolder then for _, conf in ipairs(petsFolder:GetChildren()) do if Trade:sendOne("pet", conf, tgt) then sent = true break end end end
							if (not sent) and needEggs and eggsFolder then for _, conf in ipairs(eggsFolder:GetChildren()) do if Trade:sendOne("egg", conf, tgt) then sent = true break end end end
							if sent then Trade.count += 1 if Trade.count >= Trade.limit then Trade.enabled = false pcall(function() tradeToggle:SetValue(false) end) end end
						end
					end
				end
				task.wait(0.25)
			end
		end)

		-- Trade and Fish elements are already registered in the WindUI ConfigManager above
	end

end

-- Safety stop on player leave
pcall(function()
	LocalPlayer.OnTeleport:Connect(function() runFlag = false end)
end)

-- Removed unused functions: setFishingState() and isIdle()


