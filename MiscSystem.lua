local MiscSystem = {}

-- External deps passed via Init
local WindUI, Tabs, Config
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
local autoClaimDailyLoginEnabled = false
local autoClaimDailyLoginThread = nil
-- Forward refs for UI controls that we may need to flip programmatically
local potionToggleRef = nil

local lotteryAttrConn = nil
local lotteryPollThread = nil

-- Hardcoded Dino Event Task Data (Halloween Event)
local DinoEventTasks = {
    Task_1 = {
        Id = "Task_1", 
        TaskPoints = 12, 
        RepeatCount = 1, 
        CompleteType = "HatchHalloweenEgg", 
        CompleteValue = 5, 
        Desc = "K_DINO_DESC_Task_3", 
        Icon = "rbxassetid://127118347569247"
    }, 
    Task_2 = {
        Id = "Task_2", 
        TaskPoints = 12, 
        RepeatCount = 1, 
        CompleteType = "BuyHalloweenEgg", 
        CompleteValue = 1, 
        Desc = "K_DINO_DESC_Task_4", 
        Icon = "rbxassetid://127118347569247"
    }, 
    Task_5 = {
        Id = "Task_5", 
        TaskPoints = 12, 
        RepeatCount = 1, 
        CompleteType = "SellPet", 
        CompleteValue = 5, 
        Desc = "K_DINO_DESC_Task_5", 
        Icon = "rbxassetid://127118347569247"
    }, 
    Task_7 = {
        Id = "Task_7", 
        TaskPoints = 12, 
        RepeatCount = 1, 
        CompleteType = "SendEgg", 
        CompleteValue = 3, 
        Desc = "K_DINO_DESC_Task_7", 
        Icon = "rbxassetid://127118347569247"
    }, 
    Task_8 = {
        Id = "Task_8", 
        TaskPoints = 10, 
        RepeatCount = 4, 
        CompleteType = "OnlineTime", 
        CompleteValue = 1200, 
        Desc = "K_DINO_DESC_Task_8", 
        Icon = "rbxassetid://127118347569247"
    }
}

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

-- Snow Claim Helper Functions
local function getDinoEventTaskData()
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	return data and data:FindFirstChild("DinoEventTaskData")
end

local function getTaskProgress(taskSlot)
	local taskData = getDinoEventTaskData()
	if not taskData then return nil end
	
	local tasks = taskData:FindFirstChild("Tasks")
	if not tasks then return nil end
	
	local task = tasks:FindFirstChild(tostring(taskSlot))
	if not task then return nil end
	
	local taskId = task:GetAttribute("Id")
	local progress = task:GetAttribute("Progress") or 0
	local claimedCount = task:GetAttribute("ClaimedCount") or 0
	
	return {
		id = taskId,
		progress = progress,
		claimedCount = claimedCount,
		slot = taskSlot
	}
end

local function getTaskUIElement(taskSlot)
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	local screenDino = pg and pg:FindFirstChild("ScreenDinoEvent")
	local root = screenDino and screenDino:FindFirstChild("Root")
	local frame = root and root:FindFirstChild("Frame")
	local scroll = frame and frame:FindFirstChild("ScrollingFrame")
	return scroll and scroll:FindFirstChild("TaskItem_" .. tostring(taskSlot))
end

local function claimSnowReward(taskId)
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

local function checkAndClaimTask(taskSlot)
	local taskInfo = getTaskProgress(taskSlot)
	if not taskInfo or not taskInfo.id then return false, "No task data" end
	
	-- Get task definition
	local taskDef = DinoEventTasks[taskInfo.id]
	if not taskDef then return false, "Unknown task: " .. taskInfo.id end
	
	-- Check if task is fully completed (claimed count >= repeat count)
	if taskInfo.claimedCount >= taskDef.RepeatCount then
		return false, "Fully completed"
	end
	
	-- Check if task progress is ready for next claim
	if taskInfo.progress >= taskDef.CompleteValue then
		local ok, err = claimSnowReward(taskInfo.id)
		if ok then
			return true, "Claimed " .. taskInfo.id .. " (" .. (taskInfo.claimedCount + 1) .. "/" .. taskDef.RepeatCount .. ")"
		else
			return false, "Failed to claim: " .. tostring(err)
		end
	end
	
	return false, string.format("Not complete (%d/%d)", taskInfo.progress, taskDef.CompleteValue)
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
	local lastStatus = {}
	
	while autoClaimSnowEnabled do
		local claimedAny = false
		local statusLines = {}
		
		-- Check all 3 task slots
		for slot = 1, 3 do
			local ok, result = checkAndClaimTask(slot)
			if ok then
				claimedAny = true
				if WindUI then
					WindUI:Notify({ Title = "❄️ Auto Claim Snow", Content = result, Duration = 3 })
				end
			end
			
			-- Update status for this slot
			local taskInfo = getTaskProgress(slot)
			if taskInfo and taskInfo.id then
				local taskDef = DinoEventTasks[taskInfo.id]
				if taskDef then
					-- Create readable task type name
					local taskTypeName = taskDef.CompleteType
					if taskTypeName == "HatchHalloweenEgg" then
						taskTypeName = "Hatch Halloween Eggs"
					elseif taskTypeName == "BuyHalloweenEgg" then
						taskTypeName = "Buy Halloween Eggs"
					elseif taskTypeName == "SellPet" then
						taskTypeName = "Sell Pets"
					elseif taskTypeName == "SendEgg" then
						taskTypeName = "Send Eggs"
					elseif taskTypeName == "OnlineTime" then
						taskTypeName = "Online Time"
					end
					
					local status = string.format("Slot %d - %s: %d/%d (Claimed: %d/%d)", 
						slot,
						taskTypeName,
						taskInfo.progress, 
						taskDef.CompleteValue,
						taskInfo.claimedCount,
						taskDef.RepeatCount
					)
					
					if taskInfo.claimedCount >= taskDef.RepeatCount then
						status = status .. " ✅ Complete"
					elseif taskInfo.progress >= taskDef.CompleteValue then
						status = status .. " 🎁 Ready"
					else
						status = status .. " ⏳ In Progress"
					end
					
					table.insert(statusLines, status)
				end
			else
				table.insert(statusLines, string.format("Slot %d - No Task", slot))
			end
		end
		
		-- Update status display with line breaks
		if statusParagraph and statusParagraph.SetDesc then
			local statusText = table.concat(statusLines, "\n")
			statusParagraph:SetDesc(statusText)
		end
		
		-- Wait longer if nothing was claimed to reduce load
		task.wait(claimedAny and 1.0 or 3.0)
	end
end

-- Daily Login Helper Functions
local function getGameFlagFolder()
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	local data = pg and pg:FindFirstChild("Data")
	return data and data:FindFirstChild("GameFlag")
end

local function getDailyLoginStatus()
	local gameFlag = getGameFlagFolder()
	if not gameFlag then return nil end
	
	local dayCount = gameFlag:GetAttribute("SevenDaysLoginDayCount") or 0
	local statusList = {}
	
	for day = 1, 7 do
		local claimed = gameFlag:GetAttribute("SevenDaysLoginRewardClaimed_" .. tostring(day))
		local canClaim = (day <= dayCount) and not claimed
		
		table.insert(statusList, {
			day = day,
			claimed = claimed or false,
			canClaim = canClaim,
			available = day <= dayCount
		})
	end
	
	return {
		dayCount = dayCount,
		days = statusList
	}
end

local function claimDailyLoginReward(day)
	if not day then return false end
	
	local args = {
		{
			event = "claimreward",
			day = day
		}
	}
	
	local ok, err = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("SevenDaysLoginRE"):FireServer(unpack(args))
	end)
	
	return ok, err
end

local function runAutoClaimDailyLogin(statusParagraph)
	while autoClaimDailyLoginEnabled do
		local status = getDailyLoginStatus()
		local statusLines = {}
		local claimedAny = false
		
		if status then
			-- Try to claim all available rewards
			for _, dayInfo in ipairs(status.days) do
				if dayInfo.canClaim then
					local ok, err = claimDailyLoginReward(dayInfo.day)
					if ok then
						claimedAny = true
						if WindUI then
							WindUI:Notify({ 
								Title = "🎁 Daily Login", 
								Content = string.format("Claimed Day %d reward!", dayInfo.day), 
								Duration = 3 
							})
						end
						task.wait(1.0) -- Wait between claims
					end
				end
				
				-- Build status text
				local dayStatus = string.format("Day %d: ", dayInfo.day)
				if dayInfo.claimed then
					dayStatus = dayStatus .. "✅ Claimed"
				elseif dayInfo.canClaim then
					dayStatus = dayStatus .. "🎁 Ready to claim"
				elseif dayInfo.available then
					dayStatus = dayStatus .. "⏳ Already claimed"
				else
					dayStatus = dayStatus .. "🔒 Locked"
				end
				
				table.insert(statusLines, dayStatus)
			end
			
			-- Update status display
			if statusParagraph and statusParagraph.SetDesc then
				local statusText = string.format("Current Day: %d/7\n", status.dayCount)
				statusText = statusText .. table.concat(statusLines, "\n")
				statusParagraph:SetDesc(statusText)
			end
		else
			if statusParagraph and statusParagraph.SetDesc then
				statusParagraph:SetDesc("Waiting for data...")
			end
		end
		
		-- Wait longer if nothing was claimed
		task.wait(claimedAny and 2.0 or 5.0)
	end
end

-- Public Init
function MiscSystem.Init(deps)
	WindUI = deps.WindUI
	Tabs = deps.Tabs
	Config = deps.Config
	MiscTab = deps.Tab or (Tabs and Tabs.MiscTab)
	if not MiscTab then return end

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
	local snowStatus = MiscTab:Paragraph({ Title = "Task Status", Desc = "Snow Tasks: Detecting..." })
	local snowToggle = MiscTab:Toggle({
		Title = "Auto Claim Snow Rewards",
		Desc = "Automatically claim completed dino event tasks",
		Value = false,
		Callback = function(state)
			autoClaimSnowEnabled = state
			if state and not autoClaimSnowThread then
				autoClaimSnowThread = task.spawn(function()
					runAutoClaimSnow(snowStatus)
					autoClaimSnowThread = nil
				end)
				if WindUI then
					WindUI:Notify({ Title = "❄️ Auto Claim Snow", Content = "Started monitoring tasks", Duration = 2 })
				end
			elseif not state and autoClaimSnowThread then
				if WindUI then
					WindUI:Notify({ Title = "❄️ Auto Claim Snow", Content = "Stopped", Duration = 2 })
				end
			end
		end
	})

	-- Auto Claim Daily Login section
	MiscTab:Section({ Title = "Auto Claim Daily Login", Icon = "calendar-check" })
	local dailyLoginStatus = MiscTab:Paragraph({ Title = "Login Status", Desc = "Daily Login: Detecting..." })
	local dailyLoginToggle = MiscTab:Toggle({
		Title = "Auto Claim Daily Login",
		Desc = "Automatically claim daily login rewards (7 days)",
		Value = false,
		Callback = function(state)
			autoClaimDailyLoginEnabled = state
			if state and not autoClaimDailyLoginThread then
				autoClaimDailyLoginThread = task.spawn(function()
					runAutoClaimDailyLogin(dailyLoginStatus)
					autoClaimDailyLoginThread = nil
				end)
				if WindUI then
					WindUI:Notify({ Title = "🎁 Daily Login", Content = "Started monitoring login rewards", Duration = 2 })
				end
			elseif not state and autoClaimDailyLoginThread then
				if WindUI then
					WindUI:Notify({ Title = "🎁 Daily Login", Content = "Stopped", Duration = 2 })
				end
			end
		end
	})

	-- Config registration (optional)
	if Config then
		pcall(function()
			Config:Register("misc_lottery_toggle", lotteryToggle)
			Config:Register("misc_potion_toggle", potionToggle)
			Config:Register("misc_potion_dropdown", potionDropdown)
			Config:Register("misc_like_toggle", likeToggle)
			Config:Register("misc_snow_toggle", snowToggle)
			Config:Register("misc_daily_login_toggle", dailyLoginToggle)
		end)
	end

	-- Initial refreshes
	refreshLottery()
	local likes = getLikeProgress()
	if likeStatus and likeStatus.SetDesc then likeStatus:SetDesc("Daily Like Progress: " .. tostring(likes or 0) .. "/3") end

	return true
end

return MiscSystem


