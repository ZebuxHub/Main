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
				table.insert(out, { uid = node.Name, T = attrs.T, M = attrs.M, D = attrs.D })
			end
		end
	end
	return out
end

function M:_scanForCerberus()
	local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	local pets = data and data:FindFirstChild("Pets")
	if not pets then return false end
	for _, node in ipairs(pets:GetChildren()) do
		if node:IsA("Configuration") then
			local t = node:GetAttribute("T")
			if tostring(t) == "Cerberus" then return true end
		end
	end
	return false
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

function M:SendSummary(reason)
	if not (self.tradeNotify and self.url ~= "") then return end
	self:Post({
		event = "trade_session_summary",
		user = tostring(LocalPlayer and LocalPlayer.Name or ""),
		target = self.session.target,
		limit = self.session.limit,
		count = #self.session.entries,
		reason = tostring(reason or ""),
		entries = self.session.entries,
		startedAt = self.session.startedAt,
		endedAt = os.time(),
	})
end

function M:OnGift(targetPlayer, kind, conf)
	if not conf then return end
	local tVal = conf:GetAttribute("T")
	local mVal = conf:GetAttribute("M")
	local uid = conf.Name or ""
	local receiver = targetPlayer and targetPlayer.Name or ""
	if self.tradeNotify and self.url ~= "" then
		self:Post({ event = "trade_complete", user = tostring(LocalPlayer and LocalPlayer.Name or ""), receiver = receiver, kind = kind, uid = uid, T = tVal, M = mVal })
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

return M


