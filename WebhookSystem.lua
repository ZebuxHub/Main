-- WebhookSystem.lua
-- Provides Discord Webhook tab (URL input, actions, alerts) and embed helpers

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local function safeGet(fn)
	local ok, res = pcall(fn)
	if ok then return res end
	return nil
end

local function getLocalPlayer()
	return Players.LocalPlayer
end

local function getPlayerGui()
	local lp = getLocalPlayer()
	return lp and lp:FindFirstChild("PlayerGui") or nil
end

local function getDataFolder()
	local pg = getPlayerGui()
	return pg and pg:FindFirstChild("Data") or nil
end

local function getAssetFolder()
	local d = getDataFolder()
	return d and d:FindFirstChild("Asset") or nil
end

local function getPetsFolder()
	local d = getDataFolder()
	return d and d:FindFirstChild("Pets") or nil
end

local function getEggFolder()
	local d = getDataFolder()
	return d and d:FindFirstChild("Egg") or nil
end

local function getNetWorth()
	local lp = getLocalPlayer()
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

local function formatWithSuffix(n)
	local v = tonumber(n) or 0
	local abs = math.abs(v)
	local function fmt(x)
		if x >= 100 then return string.format("%d", x) end
		if x >= 10 then return string.format("%.1f", x) end
		return string.format("%.2f", x)
	end
	if abs >= 1e12 then return fmt(v/1e12).."T" end
	if abs >= 1e9 then return fmt(v/1e9).."B" end
	if abs >= 1e6 then return fmt(v/1e6).."M" end
	if abs >= 1e3 then return fmt(v/1e3).."K" end
	return tostring(math.floor(v))
end

local defaultFruitOrder = {
	"Strawberry","Blueberry","Watermelon","Apple","Orange","Corn","Banana","Grape","Pear",
	"Pineapple","GoldMango","BloodstoneCycad","ColossalPinecone","VoltGinkgo","DeepseaPearlFruit"
}

local FRUIT_EMOJI = {
	Apple = "<:Apple:1414278364042232040>",
	Banana = "<:Banana:1414278394849267823>",
	Blueberry = "<:Blueberry:1414278423119007744>",
	Watermelon = "<:Watermelon:1414278523903803402>",
	Strawberry = "<:Strawberry:1414278519382605874>",
	Orange = "<:Orange:1414278509769261219>",
	Corn = "<:Corn:1414278452315684954>",
	Grape = "<:Grape:1414278507005083849>",
	Pear = "<:Pear:1414278513632219256>",
	Pineapple = "<:Pineapple:1414278517302100008>",
	GoldMango = "<:GoldMango:1414278503440060516>",
	BloodstoneCycad = "<:BloodstoneCycad:1414278408988528725>",
	ColossalPinecone = "<:ColossalPinecone:1414278437052616865>",
	VoltGinkgo = "<:VoltGinkgo:1414278521681088543>",
	DeepseaPearlFruit = "<:DeepseaPearlFruit:1414278482913005598>",
	Ticket = "<:Ticket:1414283452659798167>"
}

local function getAssetCount(id)
	local asset = getAssetFolder()
	if not asset then return 0 end
	local v = asset:GetAttribute(id)
	if v == nil then v = asset:GetAttribute(string.lower(id)) or asset:GetAttribute(string.upper(id)) end
	return tonumber(v) or 0
end

local Webhook = { url = "", enabled = true, cerberus = false, tradeEach = false, tradeSummary = false, cerbConn = nil, cerbNotifiedUID = {} }

function Webhook:sendPayload(payload)
	if not self.url or self.url == "" then return false, "No URL" end
	local req = (http_request or request or (syn and syn.request) or (krnl and krnl.request) or (fluxus and fluxus.request) or (http and http.request))
	if not req then return false, "No request fn" end
	local ok, res = pcall(function()
		return req({ Url = self.url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(payload) })
	end)
	return ok == true, res
end

function Webhook:sendEmbed(opts)
	local embed = {
		title = tostring((opts and opts.title) or ""),
		description = tostring((opts and opts.description) or ""),
		color = tonumber((opts and opts.color) or 0x5865F2),
		timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
		fields = (opts and opts.fields) or nil,
		footer = (opts and opts.footer) or nil,
	}
	return self:sendPayload({ embeds = { embed } })
end

function Webhook:sendText(text)
	local content = tostring(text or "")
	if #content > 1900 then content = content:sub(1, 1900).."..." end
	return self:sendPayload({ content = content })
end

local function buildPetsSummaryBlock()
	local pets = getPetsFolder()
	if not pets then return "No pets." end
	local typeMap = {}
	for _, node in ipairs(pets:GetChildren()) do
		local a = node:GetAttributes()
		local typ = tostring(a.T or "Unknown")
		local mut = tostring(a.M or "")
		if mut == "Dino" then mut = "Jurassic" end
		local rec = typeMap[typ]
		if not rec then rec = { total = 0, muts = {} } typeMap[typ] = rec end
		rec.total += 1
		if mut ~= "" then rec.muts[mut] = (rec.muts[mut] or 0) + 1 end
	end
	local items = {}
	for k, v in pairs(typeMap) do table.insert(items, { name = k, total = v.total, muts = v.muts }) end
	table.sort(items, function(a,b) return a.total > b.total end)
	local top = {}
	local limit = math.min(4, #items)
	for i = 1, limit do
		local it = items[i]
		table.insert(top, string.format("🐾 %s × %d", it.name, it.total))
		local pairsArr = {}
		for m, c in pairs(it.muts) do table.insert(pairsArr, { m = m, c = c }) end
		table.sort(pairsArr, function(a,b) return a.c > b.c end)
		for _, row in ipairs(pairsArr) do
			table.insert(top, string.format("L 🧬 %s × %d", row.m, row.c))
		end
		if i < limit then table.insert(top, "") end
	end
	return "```diff\n" .. table.concat(top, "\n") .. "\n```"
end

local function buildEggsSummaryBlock()
	local eggs = getEggFolder()
	if not eggs then return "No eggs." end
	local typeMap = {}
	for _, node in ipairs(eggs:GetChildren()) do
		local a = node:GetAttributes()
		local typ = tostring(a.T or "Unknown")
		local mut = tostring(a.M or "")
		if mut == "Dino" then mut = "Jurassic" end
		local rec = typeMap[typ]
		if not rec then rec = { total = 0, muts = {} } typeMap[typ] = rec end
		rec.total += 1
		if mut ~= "" then rec.muts[mut] = (rec.muts[mut] or 0) + 1 end
	end
	local items = {}
	for k, v in pairs(typeMap) do table.insert(items, { name = k, total = v.total, muts = v.muts }) end
	table.sort(items, function(a,b) return a.total > b.total end)
	local top = {}
	local limit = math.min(2, #items)
	for i = 1, limit do
		local it = items[i]
		table.insert(top, string.format("🏆 %s × %d", it.name, it.total))
		local pairsArr = {}
		for m, c in pairs(it.muts) do table.insert(pairsArr, { m = m, c = c }) end
		table.sort(pairsArr, function(a,b) return a.c > b.c end)
		for _, row in ipairs(pairsArr) do
			table.insert(top, string.format("L 🧬 %s × %d", row.m, row.c))
		end
		if i < limit then table.insert(top, "") end
	end
	return "```diff\n" .. table.concat(top, "\n") .. "\n```"
end

local function buildFruitsLine()
	local parts = {}
	local col = 0
	for _, id in ipairs(defaultFruitOrder) do
		local cnt = getAssetCount(id)
		local em = FRUIT_EMOJI[id] or (":"..id..":")
		table.insert(parts, string.format("%s `%s`", em, tostring(cnt)))
		col += 1
		if col % 5 == 0 then table.insert(parts, "\n\n") end
	end
	local s = table.concat(parts, "  ")
	-- collapse trailing breaks
	s = s:gsub("(\n\n)+$", "")
	return s
end

function Webhook:sendInventorySnapshot()
	local fields = {}
	local net = formatWithSuffix(getNetWorth())
	local ticket = formatWithSuffix(getAssetCount("LotteryTicket"))
	table.insert(fields, { value = string.format("💰 Net Worth:  `%s`\n%s Ticket: `%s`", net, FRUIT_EMOJI.Ticket or "🎟️", ticket) })
	table.insert(fields, { name = "🪣 Fruits", value = buildFruitsLine() })
	table.insert(fields, { name = "🐾 Pets", value = buildPetsSummaryBlock(), inline = true })
	table.insert(fields, { name = "🥚 Top Eggs", value = buildEggsSummaryBlock(), inline = true })
	self:sendPayload({ embeds = { {
		title = "📊 Inventory Snapshot",
		color = 16761095,
		fields = fields,
		footer = { text = "Generated • Build A Zoo" },
		timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
	} } })
end

local function stringifyPetNode(node)
	if not node then return nil end
	local a = node:GetAttributes()
	local uid = tostring(node.Name)
	local typ = tostring(a.T or "?")
	local mut = a.M; if mut == "Dino" then mut = "Jurassic" end
	return uid .. " | " .. typ .. (mut and (" ["..tostring(mut).."]") or "")
end

local function sendAllOwnedPets(WebhookObj)
	local pets = getPetsFolder()
	if not pets then WebhookObj:sendEmbed({ title = "Owned Pets", description = "No pets found.", color = 0xED4245 }); return end
	local lines = {}
	for _, n in ipairs(pets:GetChildren()) do
		local s = stringifyPetNode(n)
		if s then table.insert(lines, s) end
	end
	table.sort(lines)
	if #lines == 0 then WebhookObj:sendEmbed({ title = "Owned Pets", description = "No pets found.", color = 0xED4245 }); return end
	for i, s in ipairs(lines) do lines[i] = "- " .. s end
	local chunk = {}
	local acc = 0
	for _, ln in ipairs(lines) do
		if acc + #ln + 1 > 1800 and #chunk > 0 then
			WebhookObj:sendEmbed({ title = "Owned Pets ("..tostring(#lines)..")", description = table.concat(chunk, "\n"), color = 0x57F287 })
			chunk = {}
			acc = 0
		end
		table.insert(chunk, ln)
		acc += #ln + 1
	end
	if #chunk > 0 then
		WebhookObj:sendEmbed({ title = "Owned Pets ("..tostring(#lines)..")", description = table.concat(chunk, "\n"), color = 0x57F287 })
	end
end

local function checkAndNotifyCerberus(WebhookObj, node)
	if not node then return end
	if WebhookObj.cerbNotifiedUID[node.Name] then return end
	local a = node:GetAttributes()
	local typ = tostring(a.T or "")
	local nameLower = string.lower(node.Name)
	if string.lower(typ) == "cerberus" or nameLower:find("cerberus") then
		WebhookObj.cerbNotifiedUID[node.Name] = true
		local desc = stringifyPetNode(node) or node.Name
		WebhookObj:sendEmbed({ title = "Cerberus acquired", description = desc, color = 0xFEE75C })
	end
end

function Webhook:startCerbWatcher()
	self:stopCerbWatcher()
	local pets = getPetsFolder()
	if not pets then return end
	for _, n in ipairs(pets:GetChildren()) do checkAndNotifyCerberus(self, n) end
	self.cerbConn = pets.ChildAdded:Connect(function(ch)
		checkAndNotifyCerberus(self, ch)
	end)
end

function Webhook:stopCerbWatcher()
	if self.cerbConn then safeGet(function() self.cerbConn:Disconnect() end) self.cerbConn = nil end
end

function Webhook:sendTradeSummaryEmbed(log, kindLabel)
	if type(log) ~= "table" or #log == 0 then return end
	local me = getLocalPlayer() and getLocalPlayer().Name or "Player"
	local overall = {}
	local byReceiver = {}
	for _, e in ipairs(log) do
		local label = ((e.kind == "egg") and "🥚" or "🐾") .. " " .. tostring(e.type or "?") .. ((e.mutate and e.mutate ~= "" and (" ["..tostring(e.mutate).."]")) or "")
		overall[label] = (overall[label] or 0) + 1
		local rec = tostring(e.receiver or "Unknown")
		if not byReceiver[rec] then byReceiver[rec] = {} end
		byReceiver[rec][label] = (byReceiver[rec][label] or 0) + 1
	end
	local function blockFromMap(map)
		local arr = {}
		for label, cnt in pairs(map) do table.insert(arr, { label = label, count = cnt }) end
		table.sort(arr, function(a,b) return a.count > b.count end)
		local lines = {}
		for _, it in ipairs(arr) do table.insert(lines, string.format("%s × %d", it.label, it.count)) end
		return (#lines > 0) and ("```diff\n" .. table.concat(lines, "\n") .. "\n```") or "-"
	end
	local fields = {}
	local title = (kindLabel == "complete") and "🤝 Trade Completed" or "📥 Trade Summary"
	-- From (overall)
	local fromName = string.format("📤 From: %s", me)
	local overallBlock = blockFromMap(overall)
	table.insert(fields, { name = fromName, value = overallBlock, inline = true })
	-- To (per receiver, capped to avoid too many fields)
	local receivers = {}
	for name, map in pairs(byReceiver) do table.insert(receivers, { name = name, map = map }) end
	table.sort(receivers, function(a,b)
		local ca, cb = 0, 0
		for _, c in pairs(a.map) do ca += c end
		for _, c in pairs(b.map) do cb += c end
		return ca > cb
	end)
	local maxFields = 5
	for i = 1, math.min(#receivers, maxFields) do
		local r = receivers[i]
		table.insert(fields, { name = string.format("📥 To: %s", r.name), value = blockFromMap(r.map), inline = true })
	end
	self:sendPayload({ embeds = { {
		title = title,
		color = 3447003,
		fields = fields,
		footer = { text = (kindLabel == "complete") and "Trade completed" or "Trade summary" },
		timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
	} } })
end

local M = {}

function M.Init(opts)
	local WindUI = opts and opts.WindUI
	local Tabs = opts and opts.Tabs
	local Config = opts and opts.Config
	local WebhookTab = Tabs and Tabs.WebhookTab
	local wb = Webhook
	if WebhookTab then
		WebhookTab:Section({ Title = "Discord Webhook", Icon = "link" })
		WebhookTab:Input({ Title = "Webhook URL", Value = "", Placeholder = "https://discord.com/api/webhooks/...", Callback = function(v)
			wb.url = tostring(v or "")
		end })
		WebhookTab:Section({ Title = "Actions", Icon = "send" })
		WebhookTab:Button({ Title = "Send Owned Pets Now", Callback = function()
			sendAllOwnedPets(wb)
		end })
		WebhookTab:Button({ Title = "Send Inventory Snapshot", Callback = function()
			wb:sendInventorySnapshot()
		end })
		WebhookTab:Section({ Title = "Alerts", Icon = "bell" })
		WebhookTab:Toggle({ Title = "Alert on Cerberus", Value = false, Callback = function(v)
			wb.cerberus = v and true or false
			if wb.cerberus then wb:startCerbWatcher() else wb:stopCerbWatcher() end
		end })
		WebhookTab:Section({ Title = "Trade Notifications", Icon = "share-2" })
		WebhookTab:Toggle({ Title = "Notify Each Trade Item", Value = false, Callback = function(v)
			wb.tradeEach = v and true or false
		end })
		WebhookTab:Toggle({ Title = "Send Summary On Stop", Value = false, Callback = function(v)
			wb.tradeSummary = v and true or false
		end })
		if Config then
			safeGet(function()
				Config:Register("webhookUrl", { Get = function() return wb.url end, Set = function(v) wb.url = tostring(v or "") end })
				Config:Register("webhookTradeEach", { Get = function() return wb.tradeEach end, Set = function(v) wb.tradeEach = v and true or false end })
				Config:Register("webhookTradeSummary", { Get = function() return wb.tradeSummary end, Set = function(v) wb.tradeSummary = v and true or false end })
			end)
		end
	end
	return wb
end

return M


