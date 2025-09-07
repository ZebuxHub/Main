local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local M = {
	url = "",
	cerbOnce = false,
	tradeNotify = false,
	session = { entries = {}, limit = 0, target = "", startedAt = os.time() },
	_cerbConn = nil,
	_cerbSent = false,
}

function M:SetUrl(url)
	self.url = tostring(url or "")
end

function M:Post(payload)
	if not self.url or self.url == "" then return end
	pcall(function()
		HttpService:PostAsync(self.url, HttpService:JSONEncode(payload), Enum.HttpContentType.ApplicationJson)
	end)
end

function M:CollectPets()
	local out = {}
	local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	local pets = data and data:FindFirstChild("Pets")
	if pets then
		for _, node in ipairs(pets:GetChildren()) do
			if node:IsA("Configuration") then
				local attrs = node:GetAttributes()
				local d = attrs.D
				if d == nil or tostring(d) == "" then
					table.insert(out, { uid = node.Name, T = attrs.T, M = attrs.M })
				end
			end
		end
	end
	-- group count by T/M
	local map = {}
	for _, it in ipairs(out) do
		local key = string.format("%s|%s", tostring(it.T or "Unknown"), tostring(it.M or ""))
		local rec = map[key]
		if not rec then rec = { T = it.T, M = it.M, count = 0 }; map[key] = rec end
		rec.count += 1
	end
	local arr = {}
	for _, rec in pairs(map) do table.insert(arr, rec) end
	table.sort(arr, function(a,b)
		if tostring(a.T) == tostring(b.T) then return tostring(a.M or "") < tostring(b.M or "") end
		return tostring(a.T) < tostring(b.T)
	end)
	return arr
end

function M:CollectEggs()
	local out = {}
	local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	local eggs = data and data:FindFirstChild("Egg")
	if eggs then
		for _, node in ipairs(eggs:GetChildren()) do
			if node:IsA("Configuration") then
				local attrs = node:GetAttributes()
				local d = attrs.D
				if d == nil or tostring(d) == "" then
					table.insert(out, { uid = node.Name, T = (attrs.T or node.Name), M = attrs.M })
				end
			end
		end
	end
	local map = {}
	for _, it in ipairs(out) do
		local key = string.format("%s|%s", tostring(it.T or "Unknown"), tostring(it.M or ""))
		local rec = map[key]
		if not rec then rec = { T = it.T, M = it.M, count = 0 }; map[key] = rec end
		rec.count += 1
	end
	local arr = {}
	for _, rec in pairs(map) do table.insert(arr, rec) end
	table.sort(arr, function(a,b)
		if tostring(a.T) == tostring(b.T) then return tostring(a.M or "") < tostring(b.M or "") end
		return tostring(a.T) < tostring(b.T)
	end)
	return arr
end

local function makeEmbed(title, description, fields)
	return { title = title, description = description, color = 5814783, timestamp = DateTime.now():ToIsoDate(), fields = fields }
end

function M:SendAllInventory()
	local eggs = self:CollectEggs()
	local pets = self:CollectPets()
	local eggLines, petLines = {}, {}
	for _, e in ipairs(eggs) do table.insert(eggLines, string.format("%s%s x%d", tostring(e.T or "Unknown"), (e.M and (" ["..tostring(e.M).."]") or ""), tonumber(e.count) or 0)) end
	for _, p in ipairs(pets) do table.insert(petLines, string.format("%s%s x%d", tostring(p.T or "Unknown"), (p.M and (" ["..tostring(p.M).."]") or ""), tonumber(p.count) or 0)) end
	local fields = {
		{ name = "Eggs (unplaced)", value = (#eggLines>0 and table.concat(eggLines, "\n") or "None"), inline = false },
		{ name = "Pets (unplaced)", value = (#petLines>0 and table.concat(petLines, "\n") or "None"), inline = false },
	}
	self:Post({ username = "Best Auto", embeds = { makeEmbed("Inventory Snapshot", tostring(LocalPlayer and LocalPlayer.Name or ""), fields) } })
end

function M:SendSummary(reason)
	if not (self.tradeNotify and self.url ~= "") then return end
	local lines = {}
	for _, ent in ipairs(self.session.entries) do
		local s = string.format("%s → %s | %s%s | %s", tostring(LocalPlayer and LocalPlayer.Name or ""), tostring(ent.receiver or ""), tostring(ent.T or "Unknown"), (ent.M and (" ["..tostring(ent.M).."]") or ""), tostring(ent.uid or ""))
		table.insert(lines, s)
	end
	local fields = {
		{ name = "Target", value = tostring(self.session.target or ""), inline = true },
		{ name = "Limit", value = tostring(self.session.limit or 0), inline = true },
		{ name = "Count", value = tostring(#self.session.entries), inline = true },
		{ name = "Entries", value = (#lines>0 and table.concat(lines, "\n") or "None"), inline = false },
	}
	self:Post({ username = "Best Auto", embeds = { makeEmbed("Trade Session Summary ("..tostring(reason or "")..
		")", os.date("!%Y-%m-%dT%H:%M:%SZ", self.session.startedAt or os.time()), fields) } })
end

function M:OnGift(targetPlayer, kind, conf)
	if not conf then return end
	local tVal = conf:GetAttribute("T")
	local mVal = conf:GetAttribute("M")
	local uid = conf.Name or ""
	local receiver = targetPlayer and targetPlayer.Name or ""
	if self.tradeNotify and self.url ~= "" then
		local fields = {
			{ name = "Receiver", value = receiver or "", inline = true },
			{ name = "Kind", value = tostring(kind or ""), inline = true },
			{ name = "Item", value = string.format("%s%s", tostring(tVal or "Unknown"), (mVal and (" ["..tostring(mVal).."]") or "")), inline = false },
			{ name = "UID", value = uid or "", inline = false },
		}
		self:Post({ username = "Best Auto", embeds = { makeEmbed("Trade Complete", tostring(LocalPlayer and LocalPlayer.Name or ""), fields) } })
	end
	self:AddEntry(receiver, kind, uid, tVal, mVal)
end

function M:OnTradeToggle(enabled, limit, target)
	if enabled then
		self:Reset(limit, target)
	else
		if #self.session.entries > 0 then self:SendSummary("stopped") end
	end
end

function M:OnTradeHitLimit(limit, count, target)
	self.session.limit = tonumber(limit) or self.session.limit
	self.session.target = tostring(target or self.session.target)
	self:SendSummary("limit_reached")
end

function M:SetCerbOnce(enabled)
	self.cerbOnce = enabled and true or false
	if self._cerbConn then pcall(function() self._cerbConn:Disconnect() end) self._cerbConn = nil end
	self._cerbSent = false
	if not self.cerbOnce then return end
	-- Immediate scan
	if self:_scanForCerberus() and not self._cerbSent then
		self:Post({ event = "cerberus_detected", user = tostring(LocalPlayer and LocalPlayer.Name or "") })
		self._cerbSent = true
		return
	end
	-- Watch for new pets
	local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	local pets = data and data:FindFirstChild("Pets")
	if pets then
		self._cerbConn = pets.ChildAdded:Connect(function(child)
			if self._cerbSent or not self.cerbOnce then return end
			if child and child:IsA("Configuration") then
				local t = child:GetAttribute("T")
				if tostring(t) == "Cerberus" then
					self:Post({ event = "cerberus_detected", user = tostring(LocalPlayer and LocalPlayer.Name or "") })
					self._cerbSent = true
					if self._cerbConn then pcall(function() self._cerbConn:Disconnect() end) self._cerbConn = nil end
				end
			end
		end)
	end
end

function M:Reset(limit, target)
	self.session = { entries = {}, limit = tonumber(limit) or 0, target = tostring(target or ""), startedAt = os.time() }
end

function M:AddEntry(receiver, kind, uid, T, MVal)
	table.insert(self.session.entries, { receiver = tostring(receiver or ""), kind = tostring(kind or ""), uid = tostring(uid or ""), T = T, M = MVal, ts = os.time() })
end

return M


