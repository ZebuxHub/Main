-- WebhookSystem.lua
-- Lightweight webhook sender and trade/cerberus notifier

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local M = {}

M.url = ""
M.tradeNotify = false
M._cerbOnce = false
M._cerbSent = false
M._cerbConn = nil
M._cerbConn2 = nil
M._session = nil

local function safeGetPetsFolder()
	local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	return data and data:FindFirstChild("Pets") or nil
end

local function buildEnvelope(event, payload)
	local env = {
		event = event,
		playerName = LocalPlayer and LocalPlayer.Name or "",
		userId = LocalPlayer and LocalPlayer.UserId or 0,
		timestamp = os.time(),
		payload = payload or {}
	}
	return env
end

local function post(url, body)
	if type(url) ~= "string" or url == "" then return false, "no_url" end
	local json = HttpService:JSONEncode(body)
	local ok, res = pcall(function()
		return HttpService:PostAsync(url, json, Enum.HttpContentType.ApplicationJson, false)
	end)
	return ok, res
end

function M.SetUrl(url)
	M.url = tostring(url or "")
end

function M.SetTradeNotify(flag)
	M.tradeNotify = flag and true or false
end

local function extractConfInfo(conf)
	if not conf or not conf.GetAttribute then return { id = tostring(conf and conf.Name or ""), type = "", mutate = "" } end
	local t = conf:GetAttribute("T") or ""
	local m = conf:GetAttribute("M") or ""
	if tostring(m) == "Dino" then m = "Jurassic" end
	return { id = tostring(conf.Name), type = tostring(t), mutate = tostring(m) }
end

function M.SendAllInventory()
	local pets = safeGetPetsFolder()
	if not pets then return false end
	local list = {}
	for _, conf in ipairs(pets:GetChildren()) do
		if conf:IsA("Configuration") then
			table.insert(list, extractConfInfo(conf))
		end
	end
	local env = buildEnvelope("send_all", { items = list })
	post(M.url, env)
	return true
end

local function cerbCheckOnce()
	if M._cerbSent then return end
	local pets = safeGetPetsFolder()
	if not pets then return end
	for _, conf in ipairs(pets:GetChildren()) do
		if conf:IsA("Configuration") then
			local t = conf:GetAttribute("T")
			if tostring(t) == "Cerberus" or tostring(conf.Name):find("Cerberus") then
				local env = buildEnvelope("cerberus", { item = extractConfInfo(conf) })
				post(M.url, env)
				M._cerbSent = true
				return
			end
		end
	end
end

local function disconnectCerb()
	if M._cerbConn then pcall(function() M._cerbConn:Disconnect() end) M._cerbConn = nil end
	if M._cerbConn2 then pcall(function() M._cerbConn2:Disconnect() end) M._cerbConn2 = nil end
end

function M.SetCerbOnce(flag)
	M._cerbOnce = flag and true or false
	if not M._cerbOnce then
		disconnectCerb()
		return
	end
	M._cerbSent = false
	cerbCheckOnce()
	local pets = safeGetPetsFolder()
	if not pets then return end
	M._cerbConn = pets.ChildAdded:Connect(function(ch)
		if M._cerbSent or not M._cerbOnce then return end
		if ch:IsA("Configuration") then
			local t = ch:GetAttribute("T")
			if tostring(t) == "Cerberus" or tostring(ch.Name):find("Cerberus") then
				local env = buildEnvelope("cerberus", { item = extractConfInfo(ch), source = "ChildAdded" })
				post(M.url, env)
				M._cerbSent = true
				disconnectCerb()
			end
		end
	end)
	M._cerbConn2 = pets.ChildRemoved:Connect(function()
		-- no-op; keep connection alive until sent
	end)
end

local function ensureSession()
	if not M._session then
		M._session = { id = tostring(HttpService:GenerateGUID(false)), items = {}, start = os.time(), limit = 0, target = "" }
	end
	return M._session
end

function M.OnTradeToggle(enabled, limit, target)
	if enabled then
		M._session = { id = tostring(HttpService:GenerateGUID(false)), items = {}, start = os.time(), limit = tonumber(limit) or 0, target = tostring(target or "") }
	else
		if M.tradeNotify and M._session then
			local payload = {
				sessionId = M._session.id,
				target = M._session.target,
				limit = M._session.limit,
				count = #M._session.items,
				items = M._session.items,
				ended = os.time(),
				status = "stopped"
			}
			post(M.url, buildEnvelope("trade_stop", payload))
		end
		M._session = nil
	end
end

function M.OnGift(targetPlayer, kind, conf)
	if not M.tradeNotify then return end
	local s = ensureSession()
	local rec = extractConfInfo(conf)
	rec.kind = tostring(kind)
	if typeof(targetPlayer) == "Instance" then
		rec.receiver = targetPlayer.Name
		rec.receiverUserId = targetPlayer.UserId
	else
		rec.receiver = tostring(targetPlayer)
		rec.receiverUserId = 0
	end
	table.insert(s.items, rec)
	-- optional live progress
	post(M.url, buildEnvelope("trade_progress", { sessionId = s.id, last = rec, count = #s.items, target = s.target }))
end

function M.OnTradeHitLimit(limit, count, target)
	if not M.tradeNotify then return end
	local s = ensureSession()
	local payload = {
		sessionId = s.id,
		target = tostring(target or s.target),
		limit = tonumber(limit) or s.limit,
		count = tonumber(count) or #s.items,
		items = s.items,
		ended = os.time(),
		status = "complete"
	}
	post(M.url, buildEnvelope("trade_complete", payload))
	M._session = nil
end

return M


