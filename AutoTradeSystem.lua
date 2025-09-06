local AutoTradeSystem = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local WindUI, Window, Config

-- UI handles
local TradeTab
local tradeToggle
local targetDropdown
local typeDropdown
local mutateDropdown
local minProduceInput
local onlyUnplacedToggle

-- State
local tradeEnabled = false
local selectedTarget = "Random Player"
local includeTypes = {}
local includeMutations = {}
local minProduce = 0
local onlyUnplaced = true

-- Helpers
local function safeGetAttribute(obj, name, default)
	local ok, v = pcall(function() return obj:GetAttribute(name) end)
	if ok and v ~= nil then return v end
	return default
end

local function listToSet(list)
	if type(list) ~= "table" then return nil end
	local set = {}
	for _, v in ipairs(list) do set[tostring(v):lower()] = true end
	return set
end

local function getDataRoot()
	local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	return pg and pg:FindFirstChild("Data") or nil
end

local function getInventoryFolders()
	local root = getDataRoot()
	if not root then return nil, nil end
	return root:FindFirstChild("Pets"), root:FindFirstChild("Egg")
end

local function buildSnapshotFromConf(conf, isEgg)
	if not conf or not conf:IsA("Configuration") then return nil end
	local t = safeGetAttribute(conf, "T", nil)
	if not t or t == "" or t == "Unknown" then return nil end
	local m = safeGetAttribute(conf, "M", "")
	local d = safeGetAttribute(conf, "D", nil)
	local lk = safeGetAttribute(conf, "LK", 0)
	local sp = isEgg and 0 or (safeGetAttribute(conf, "Speed", 0) or 0)
	return { uid = conf.Name, type = t, mut = m, placed = (d ~= nil and tostring(d) ~= ""), locked = (lk == 1), produce = tonumber(sp) or 0 }
end

local function refreshLive(uid, isEgg)
	local pets, eggs = getInventoryFolders()
	local folder = isEgg and eggs or pets
	local conf = folder and folder:FindFirstChild(uid) or nil
	return buildSnapshotFromConf(conf, isEgg)
end

local function shouldTradeItem(snap, typeSet, mutSet, minP, requireUnplaced)
	if not snap or snap.locked then return false end
	if requireUnplaced and snap.placed then return false end
	if typeSet and next(typeSet) and (not typeSet[tostring(snap.type):lower()]) then return false end
	if mutSet and next(mutSet) then
		local m = tostring(snap.mut or ""):lower()
		if m == "dino" then m = "jurassic" end
		if m == "" then return false end
		if not mutSet[m] then return false end
	end
	if (minP or 0) > 0 and (tonumber(snap.produce or 0) < minP) then return false end
	return true
end

local function focusItem(uid)
	pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer("Focus", uid)
	end)
end

local function giftTo(targetPlayer)
	pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("GiftRE"):FireServer(targetPlayer)
	end)
end

local function pickTarget()
	if selectedTarget == "Random Player" then
		local arr = {}
		for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(arr, p) end end
		if #arr == 0 then return nil end
		return arr[math.random(1, #arr)]
	else
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Name == selectedTarget or p.DisplayName == selectedTarget then return p end
		end
	end
	return nil
end

local function iterateInventoryOnce(callback)
	local pets, eggs = getInventoryFolders()
	if pets then
		for _, conf in ipairs(pets:GetChildren()) do if conf:IsA("Configuration") then callback(conf, false) end end
	end
	if eggs then
		for _, conf in ipairs(eggs:GetChildren()) do if conf:IsA("Configuration") then callback(conf, true) end end
	end
end

local cooldownUntil = {}
local function setCooldown(uid, secs)
	cooldownUntil[uid] = os.clock() + (secs or 1.0)
end
local function isCooling(uid)
	local u = cooldownUntil[uid]
	return u and os.clock() < u
end

local function runTradeLoop()
	while tradeEnabled do
		local tset = listToSet(includeTypes)
		local mset = listToSet(includeMutations)
		local target = pickTarget()
		if not target then task.wait(0.6) goto continue end
		local sent = false
		iterateInventoryOnce(function(conf, isEgg)
			if sent then return end
			local uid = conf.Name
			if isCooling(uid) then return end
			local snap = buildSnapshotFromConf(conf, isEgg)
			if not shouldTradeItem(snap, tset, mset, minProduce, onlyUnplaced) then return end
			-- re-verify live just before sending
			snap = refreshLive(uid, isEgg) or snap
			if not shouldTradeItem(snap, tset, mset, minProduce, onlyUnplaced) then setCooldown(uid, 1.0) return end
			focusItem(uid)
			task.wait(0.05)
			giftTo(target)
			setCooldown(uid, 1.2)
			sent = true
		end)
		if not sent then task.wait(0.5) end
		::continue::
	end
end

function AutoTradeSystem.Init(deps)
	WindUI = deps.WindUI
	Window = deps.Window
	Config = deps.Config
	local tabIcon = deps.Icon or "swap-horizontal"
	TradeTab = Window:Tab({ Title = "Trade", Icon = tabIcon })
	
	-- UI
	tradeToggle = TradeTab:Toggle({ Title = "Auto Trade", Value = false, Callback = function(v)
		tradeEnabled = v
		if v then task.spawn(runTradeLoop) end
	end })
	
	targetDropdown = TradeTab:Dropdown({ Title = "Target", Values = (function()
		local list = {"Random Player"}
		for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(list, p.Name) end end
		return list
	end)(), Value = "Random Player", Callback = function(v) selectedTarget = v or "Random Player" end })
	
	typeDropdown = TradeTab:Dropdown({ Title = "Types (Multi)", Values = deps.Types or {}, Value = {}, Multi = true, AllowNone = true, Callback = function(v) includeTypes = v or {} end })
	mutateDropdown = TradeTab:Dropdown({ Title = "Mutations (Multi)", Values = deps.Mutations or {}, Value = {}, Multi = true, AllowNone = true, Callback = function(v) includeMutations = v or {} end })
	minProduceInput = TradeTab:Input({ Title = "Min Produce", Value = "0", Placeholder = "e.g. 100", Callback = function(v) minProduce = tonumber(v) or 0 end })
	onlyUnplacedToggle = TradeTab:Toggle({ Title = "Only Unplaced", Value = true, Callback = function(v) onlyUnplaced = v and true or false end })
	
	-- Persist
	if Config then
		Config:Register("tradeEnabled", tradeToggle)
		Config:Register("tradeTarget", targetDropdown)
		Config:Register("tradeTypes", { Get = function() return includeTypes end, Set = function(v) includeTypes = v or {} if typeDropdown and v then typeDropdown:Select(v) end end })
		Config:Register("tradeMutations", { Get = function() return includeMutations end, Set = function(v) includeMutations = v or {} if mutateDropdown and v then mutateDropdown:Select(v) end end })
		Config:Register("tradeMinProduce", { Get = function() return tostring(minProduce) end, Set = function(v) minProduce = tonumber(v) or 0 end })
		Config:Register("tradeOnlyUnplaced", onlyUnplacedToggle)
	end
end

return AutoTradeSystem
