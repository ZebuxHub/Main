local MiscSystem = {}

-- External deps passed via Init
local WindUI, Tabs, UnifiedConfig, ConfigCategory
local MiscTab

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

-- State
local autoPotionEnabled = false
local autoPotionThread = nil
local autoLikeEnabled = false
local autoLikeThread = nil
local selectedPotions = {}
local likedUserIds = {} -- session memory to avoid repeating targets
local autoLotteryEnabled = false
local autoClaimSnowEnabled = false
local autoClaimSnowThread = nil
-- Forward refs for UI controls that we may need to flip programmatically
local potionToggleRef = nil

local lotteryAttrConn = nil
local lotteryPollThread = nil

-- UI element references (declared at module level)
local lotteryToggle = nil
local potionToggle = nil
local potionDropdown = nil
local likeToggle = nil
local snowToggle = nil

-- Helpers
local function getAssetFolder()
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	return data and data:FindFirstChild("Asset") or nil
end

local function getAssetCount(key)
	local asset = getAssetFolder()
	if not asset then return 0 end
	local ok, value = pcall(function()
		return asset:GetAttribute(key)
	end)
	if ok and type(value) == "number" then return value end
	return 0
end

local function fireLotteryUseAll()
	local count = getAssetCount("LotteryTicket")
	if count <= 0 then return false, "No tickets" end
	local args = { { event = "lottery", count = count } }
	local ok, err = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("LotteryRE"):FireServer(unpack(args))
	end)
	return ok, err
end

local function startAutoLottery(onStatus)
	local function consume()
		if not autoLotteryEnabled then return end
		local c = getAssetCount("LotteryTicket")
		if c > 0 then
			fireLotteryUseAll()
		end
		if onStatus then onStatus() end
	end

	-- Attribute listener (fires immediately when LotteryTicket changes)
	local asset = getAssetFolder()
	if asset then
		pcall(function()
			lotteryAttrConn = asset:GetAttributeChangedSignal("LotteryTicket"):Connect(function()
				consume()
			end)
		end)
	end

	-- Lightweight fallback poller (in case attribute signal misses)
	lotteryPollThread = task.spawn(function()
		while autoLotteryEnabled do
			consume()
			task.wait(3)
		end
	end)
end

local function stopAutoLottery()
	autoLotteryEnabled = false
	if lotteryAttrConn then pcall(function() lotteryAttrConn:Disconnect() end) end
	lotteryAttrConn = nil
	if lotteryPollThread then pcall(function() task.cancel(lotteryPollThread) end) end
	lotteryPollThread = nil
end

local function getAllPotionIds()
	local list = {}
	local cfg
	pcall(function()
		cfg = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ResPotion"))
	end)
	if type(cfg) == "table" then
		for id, def in pairs(cfg) do
			if type(id) == "string" and id:match("^Potion_") and type(def) == "table" then
				table.insert(list, id)
			end
		end
		table.sort(list)
	end
	return list
end

local function usePotion(potionId)
	if type(potionId) ~= "string" or potionId == "" then return false end
	local args = { "UsePotion", potionId }
	local ok, err = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("ShopRE"):FireServer(unpack(args))
	end)
	return ok, err
end

local function getLikeProgress()
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	local seasonPass = data and data:FindFirstChild("SeasonPass")
	local season1 = seasonPass and seasonPass:FindFirstChild("Season1")
	if not season1 then return 0, false, 0, false end
	local likes = tonumber(season1:GetAttribute("D_LikeZoo")) or 0
	local weeklyLikes = tonumber(season1:GetAttribute("W_LikeZoo")) or 0
	local ccDaily = tonumber(season1:GetAttribute("CC_DailyTask2")) or 0
	local dailyComplete = (likes >= 3) or (ccDaily == 1)
	local weeklyComplete = (weeklyLikes >= 20)
	return likes, dailyComplete, weeklyLikes, weeklyComplete
end

local function getPotionWeeklyUse()
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	local seasonPass = data and data:FindFirstChild("SeasonPass")
	local season1 = seasonPass and seasonPass:FindFirstChild("Season1")
	if not season1 then return 0 end
	return tonumber(season1:GetAttribute("W_UsePotion")) or 0
end

local function getRandomOtherUserId()
	local me = Players.LocalPlayer
	local candidates = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= me and not likedUserIds[plr.UserId] then
			table.insert(candidates, plr.UserId)
		end
	end
	if #candidates == 0 then return nil end
	return candidates[math.random(1, #candidates)]
end

local function sendLikeTo(userId)
	if not userId then return false end
	local args = { "GiveLike", userId }
	local ok, err = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
	end)
	return ok, err
end

-- Auto Claim Snow helpers
local function getDinoEventTaskData()
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	return data and data:FindFirstChild("DinoEventTaskData")
end

-- Task definitions for validation
local TaskDefinitions = {
	Task_1 = { CompleteValue = 5, CompleteType = "HatchIceEgg" },
	Task_3 = { CompleteValue = 5, CompleteType = "SellPet" },
	Task_4 = { CompleteValue = 3, CompleteType = "BuyEvolutionEgg" },
	Task_5 = { CompleteValue = 1, CompleteType = "BuyIceEgg" },
	Task_7 = { CompleteValue = 10, CompleteType = "HatchEvolutionEgg" },
	Task_8 = { CompleteValue = 1200, CompleteType = "OnlineTime" }
}

local function getClaimableTask()
	local taskData = getDinoEventTaskData()
	if not taskData then return nil, nil end
	
	local tasksFolder = taskData:FindFirstChild("Tasks")
	if not tasksFolder then return nil, nil end
	
	-- Check Tasks 1, 2, 3
	for i = 1, 3 do
		local taskConfig = tasksFolder:FindFirstChild(tostring(i))
		if taskConfig then
			local taskId = taskConfig:GetAttribute("Id")
			local progress = taskConfig:GetAttribute("Progress") or 0
			local claimedCount = taskConfig:GetAttribute("ClaimedCount") or 0
			
			-- Get task definition to check completion requirement
			local taskDef = TaskDefinitions[taskId]
			if taskDef then
				local requiredProgress = taskDef.CompleteValue
				
				-- Only claim if task is complete (progress >= required) and not already claimed
				if taskId and progress >= requiredProgress and claimedCount == 0 then
					return taskId, taskConfig
				end
			end
		end
	end
	
	return nil, nil
end

local function claimDinoReward(taskId)
	if not taskId then return false end
	local args = {
		{
			event = "claimreward",
			id = taskId
		}
	}
	local ok, err = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("DinoEventRE"):FireServer(unpack(args))
	end)
	return ok, err
end

-- Threads
local function runAutoPotion()
	while autoPotionEnabled do
		-- Stop condition based on weekly usage
		local weeklyUse = getPotionWeeklyUse()
		if weeklyUse >= 10 then
			autoPotionEnabled = false
			if potionToggleRef and potionToggleRef.SetValue then pcall(function() potionToggleRef:SetValue(false) end) end
			if WindUI then pcall(function() WindUI:Notify({ Title = "Auto Potion", Content = "Stopped (weekly use reached 10)", Duration = 3 }) end) end
			break
		end
		local ownedAny = false
		for potionId, enabled in pairs(selectedPotions) do
			if enabled then
				local count = getAssetCount(potionId)
				if count > 0 then
					ownedAny = true
					usePotion(potionId)
					task.wait(0.4)
				end
			end
		end
		-- If nothing owned, slow down a bit
		task.wait(ownedAny and 1.0 or 2.0)
	end
end

local function hopServer()
    local lp = Players.LocalPlayer
    pcall(function()
        if WindUI then WindUI:Notify({ Title = "Auto Like", Content = "Hopping to a new server...", Duration = 3 }) end
        TeleportService:Teleport(game.PlaceId, lp)
    end)
end

local function runAutoLike(statusParagraph)
    local noTargetStreak = 0
    while autoLikeEnabled do
        local likes, dailyComplete, weeklyLikes, weeklyComplete = getLikeProgress()
		if statusParagraph and statusParagraph.SetDesc then
			local msg = string.format("Daily Like: %d/3 | Weekly Like: %d/20", likes, weeklyLikes)
			if dailyComplete and weeklyComplete then msg = msg .. " (complete)" end
			statusParagraph:SetDesc(msg)
		end
		-- Stop only when BOTH daily and weekly are complete
		if dailyComplete and weeklyComplete then break end
        local targetId = getRandomOtherUserId()
        if not targetId then
            -- everyone liked already in this server
            noTargetStreak = noTargetStreak + 1
            if not weeklyComplete and noTargetStreak >= 3 then
                hopServer()
                task.wait(3.0)
            else
                task.wait(2.0)
            end
        else
            noTargetStreak = 0
            sendLikeTo(targetId)
            likedUserIds[targetId] = true
            task.wait(1.0)
        end
    end
end

local function runAutoClaimSnow(statusParagraph)
	local claimedTasks = {}
	local lastClaimTime = 0
	
	while autoClaimSnowEnabled do
		local currentTime = tick()
		local taskId, taskItem = getClaimableTask()
		
		if taskId and not claimedTasks[taskId] then
			-- Prevent spam claiming the same task
			if currentTime - lastClaimTime >= 2 then
				local success, err = claimDinoReward(taskId)
				if success then
					claimedTasks[taskId] = true
					lastClaimTime = currentTime
					if WindUI then
						WindUI:Notify({ 
							Title = "❄️ Auto Claim Snow", 
							Content = "Claimed reward: " .. taskId, 
							Duration = 3 
						})
					end
					if statusParagraph and statusParagraph.SetDesc then
						statusParagraph:SetDesc("Last claimed: " .. taskId .. " at " .. os.date("%H:%M:%S"))
					end
				else
					if statusParagraph and statusParagraph.SetDesc then
						statusParagraph:SetDesc("Failed to claim: " .. taskId)
					end
				end
			end
		else
			-- Update status when no tasks available - show current task progress
			if statusParagraph and statusParagraph.SetDesc then
				local taskData = getDinoEventTaskData()
				local msg = "Monitoring tasks..."
				
				if taskData then
					local tasksFolder = taskData:FindFirstChild("Tasks")
					if tasksFolder then
						local taskInfo = {}
						for i = 1, 3 do
							local taskConfig = tasksFolder:FindFirstChild(tostring(i))
							if taskConfig then
								local taskId = taskConfig:GetAttribute("Id") or "Unknown"
								local progress = taskConfig:GetAttribute("Progress") or 0
								local claimedCount = taskConfig:GetAttribute("ClaimedCount") or 0
								
								-- Get required progress from task definition
								local taskDef = TaskDefinitions[taskId]
								local required = taskDef and taskDef.CompleteValue or 0
								local completeType = taskDef and taskDef.CompleteType or "Unknown"
								
								-- Format complete type to be more readable
								local readableType = completeType
									:gsub("([A-Z])", " %1") -- Add space before capital letters
									:gsub("^%s+", "") -- Remove leading space
								
								local status
								if claimedCount > 0 then
									status = "✅ Claimed"
								elseif progress >= required and required > 0 then
									status = "🎁 Ready"
								elseif progress > 0 then
									status = string.format("🔄 %d/%d", progress, required)
								else
									status = "⏳ Waiting"
								end
								
								table.insert(taskInfo, string.format("%s (%s): %s", taskId, readableType, status))
							end
						end
						if #taskInfo > 0 then
							msg = "Tasks: " .. table.concat(taskInfo, " | ")
						end
					end
				end
				
				if next(claimedTasks) then
					local claimedCount = 0
					for _ in pairs(claimedTasks) do claimedCount = claimedCount + 1 end
					msg = msg .. " (Session claimed: " .. claimedCount .. ")"
				end
				
				statusParagraph:SetDesc(msg)
			end
		end
		
		-- Optimized polling - check every 1 second to avoid lag
		task.wait(1.0)
	end
end

-- Public Init
function MiscSystem.Init(deps)
	WindUI = deps.WindUI
	Tabs = deps.Tabs
	UnifiedConfig = deps.UnifiedConfig
	ConfigCategory = deps.ConfigCategory or "misc"
	MiscTab = deps.Tab or (Tabs and Tabs.MiscTab)
	if not MiscTab then return false end

	-- Lottery section
	MiscTab:Section({ Title = "Lottery", Icon = "gift" })
	local lotteryStatus = MiscTab:Paragraph({ Title = "Tickets", Desc = "Detecting..." })
	local function refreshLottery()
		local c = getAssetCount("LotteryTicket")
		if lotteryStatus and lotteryStatus.SetDesc then
			lotteryStatus:SetDesc("LotteryTicket: " .. tostring(c))
		end
	end
	local lotteryToggle = MiscTab:Toggle({
		Title = "Auto Use Tickets",
		Desc = "Use LotteryTicket automatically on change",
		Value = false,
		Callback = function(state)
			autoLotteryEnabled = state
			if state then
				startAutoLottery(refreshLottery)
			else
				stopAutoLottery()
			end
		end
	})
	refreshLottery()

	-- Auto Potion section
	MiscTab:Section({ Title = "Auto Potion", Icon = "flask-round" })
	local potionList = getAllPotionIds()
	local potionDropdown = MiscTab:Dropdown({
		Title = "Potions",
		Desc = "Select potions to auto-use",
		Values = potionList,
		Value = {},
		Multi = true,
		AllowNone = true,
		Callback = function(selection)
			selectedPotions = {}
			if type(selection) == "table" then
				for _, id in ipairs(selection) do selectedPotions[id] = true end
			end
		end
	})
	local potionToggle = MiscTab:Toggle({
		Title = "Auto Use Potions",
		Desc = "Use selected potions automatically",
		Value = false,
		Callback = function(state)
			autoPotionEnabled = state
			if state and not autoPotionThread then
				autoPotionThread = task.spawn(function()
					runAutoPotion()
					autoPotionThread = nil
				end)
			end
		end
	})
	potionToggleRef = potionToggle

	-- Auto Like section
	MiscTab:Section({ Title = "Auto Like", Icon = "thumbs-up" })
	local likeStatus = MiscTab:Paragraph({ Title = "Status", Desc = "Daily Like: 0/3 | Weekly Like: 0/20" })
	local likeToggle = MiscTab:Toggle({
		Title = "Auto Like Other Zoos",
		Desc = "Automatically like others until complete",
		Value = false,
		Callback = function(state)
			autoLikeEnabled = state
			if state and not autoLikeThread then
				likedUserIds = {}
				autoLikeThread = task.spawn(function()
					runAutoLike(likeStatus)
					autoLikeThread = nil
				end)
			end
		end
	})

	-- Auto Claim Snow section
	MiscTab:Section({ Title = "Auto Claim Snow", Icon = "snowflake" })
	local snowStatus = MiscTab:Paragraph({ Title = "Status", Desc = "Monitoring for claimable tasks..." })
	local snowToggle = MiscTab:Toggle({
		Title = "Auto Claim Dino Event",
		Desc = "Automatically claim snow event rewards",
		Value = false,
		Callback = function(state)
			autoClaimSnowEnabled = state
			if state and not autoClaimSnowThread then
				autoClaimSnowThread = task.spawn(function()
					runAutoClaimSnow(snowStatus)
					autoClaimSnowThread = nil
				end)
				if WindUI then
					WindUI:Notify({ 
						Title = "❄️ Auto Claim Snow", 
						Content = "Started monitoring dino event tasks", 
						Duration = 3 
					})
				end
			elseif not state then
				if WindUI then
					WindUI:Notify({ 
						Title = "❄️ Auto Claim Snow", 
						Content = "Stopped monitoring", 
						Duration = 2 
					})
				end
			end
		end
	})

	-- Config registration with unified config system
	if UnifiedConfig then
		pcall(function()
			UnifiedConfig:Register("misc_lottery_toggle", lotteryToggle, ConfigCategory or "misc")
			UnifiedConfig:Register("misc_potion_toggle", potionToggle, ConfigCategory or "misc")
			UnifiedConfig:Register("misc_potion_dropdown", potionDropdown, ConfigCategory or "misc")
			UnifiedConfig:Register("misc_like_toggle", likeToggle, ConfigCategory or "misc")
			UnifiedConfig:Register("misc_snow_toggle", snowToggle, ConfigCategory or "misc")
		end)
	end

	-- Initial refreshes
	refreshLottery()
	local likes = getLikeProgress()
	if likeStatus and likeStatus.SetDesc then likeStatus:SetDesc("Daily Like Progress: " .. tostring(likes or 0) .. "/3") end

	return true
end

function MiscSystem.GetConfigElements()
	return {
		lotteryToggle = lotteryToggle,
		potionToggle = potionToggle,
		potionDropdown = potionDropdown,
		likeToggle = likeToggle,
		snowToggle = snowToggle
	}
end

function MiscSystem.Cleanup()
	-- Stop all active systems
	autoLotteryEnabled = false
	autoPotionEnabled = false
	autoLikeEnabled = false
	autoClaimSnowEnabled = false
	
	-- Cleanup connections and threads
	stopAutoLottery()
	
	if autoLikeThread then
		pcall(function() task.cancel(autoLikeThread) end)
		autoLikeThread = nil
	end
	
	if autoClaimSnowThread then
		pcall(function() task.cancel(autoClaimSnowThread) end)
		autoClaimSnowThread = nil
	end
	
	if autoPotionThread then
		pcall(function() task.cancel(autoPotionThread) end)
		autoPotionThread = nil
	end
end

return MiscSystem


