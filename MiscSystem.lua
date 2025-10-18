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
local autoLikeUnlimited = false
local selectedPotions = {}
local likedUserIds = {} -- session memory to avoid repeating targets
local autoLotteryEnabled = false
local autoClaimHalloweenEnabled = false
local autoClaimHalloweenThread = nil
local autoClaimDailyLoginEnabled = false
local autoClaimDailyLoginThread = nil
local autoBuyEventShopEnabled = false
local autoBuyEventShopThread = nil
local selectedEventShopItems = {}
local autoClaimEggEnabled = false
local autoClaimEggThread = nil
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
local function getEventShopUI()
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	local screenDino = pg and pg:FindFirstChild("ScreenDino")
	local root = screenDino and screenDino:FindFirstChild("Root")
	return root
end

local function getEventEggClaimCount()
	local root = getEventShopUI()
	if not root then return 0 end
	local eggFrame = root:FindFirstChild("EggFrame")
	local freeBtn = eggFrame and eggFrame:FindFirstChild("FreeBtn")
	local frame = freeBtn and freeBtn:FindFirstChild("Frame")
	local count = frame and frame:FindFirstChild("Count")
	if not count then return 0 end
	
	local text = count.Text
	-- Parse "Claim(x5)" or "Claim(x0)" to get number
	local num = text:match("Claim%(x(%d+)%)")
	return tonumber(num) or 0
end

local function claimEventEgg()
	local args = {
		{
			event = "onlinepack"
		}
	}
	
	local ok, err = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("DinoEventRE"):FireServer(unpack(args))
	end)
	
	return ok, err
end

local function getEventCandyAmount()
	local root = getEventShopUI()
	if not root then return 0 end
	local coin = root:FindFirstChild("Coin")
	local textLabel = coin and coin:FindFirstChild("TextLabel")
	if not textLabel then return 0 end
	local text = textLabel.Text
	-- Parse number from text (e.g., "1,234" or "1234")
	local numStr = text:gsub(",", "")
	return tonumber(numStr) or 0
end

local function getAllEventShopItems()
	local items = {}
	local rewardConfig
	
	-- Get reward data from ReplicatedStorage config
	pcall(function()
		rewardConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ResDinoEventReward"))
	end)
	
	if not rewardConfig or type(rewardConfig) ~= "table" then return {} end
	
	-- Get UI for availability checking
	local root = getEventShopUI()
	local scrollFrame = nil
	if root then
		local storeFrame = root:FindFirstChild("StoreFrame")
		local frame = storeFrame and storeFrame:FindFirstChild("Frame")
		scrollFrame = frame and frame:FindFirstChild("ScrollingFrame")
	end
	
	for rewardId, rewardData in pairs(rewardConfig) do
		if type(rewardId) == "string" and rewardId:match("^Reward_") and type(rewardData) == "table" then
			local itemName = rewardData.Thing1 or rewardId
			local cost = rewardData.TaskPoints or 0
			local claimNumber = rewardData.ClaimNumber or -1
			
			-- Check availability from UI if possible
			local available = -1 -- -1 means unlimited
			local hasLimit = false
			
			if scrollFrame then
				local itemFrame = scrollFrame:FindFirstChild(rewardId)
				if itemFrame then
					local limit = itemFrame:FindFirstChild("limit")
					if limit and limit.Visible then
						hasLimit = true
						local nameLabel = limit:FindFirstChild("NameLabel")
						if nameLabel then
							local text = nameLabel.Text
							-- Parse "Available X times" or just number
							local num = text:match("Available (%d+) times") or text:match("(%d+)")
							available = tonumber(num) or 0
						end
					end
				end
			end
			
			-- If no UI data, use ClaimNumber from config
			if not hasLimit and claimNumber ~= -1 then
				available = claimNumber
			end
			
			-- Build display name
			local displayName = itemName
			if available == -1 then
				displayName = string.format("%s (%d candy, Unlimited)", itemName, cost)
			else
				displayName = string.format("%s (%d candy, %d left)", itemName, cost, available)
			end
			
			table.insert(items, {
				id = rewardId,
				name = itemName,
				displayName = displayName,
				cost = cost,
				available = available,
				claimNumber = claimNumber
			})
		end
	end
	
	-- Sort by Sort field or ID
	table.sort(items, function(a, b)
		local sortA = rewardConfig[a.id] and rewardConfig[a.id].Sort or 999
		local sortB = rewardConfig[b.id] and rewardConfig[b.id].Sort or 999
		return sortA < sortB
	end)
	
	return items
end

local function getEventShopItemStatus(itemId)
	-- Get cost from config
	local cost = 0
	local configAvailable = -1
	
	pcall(function()
		local rewardConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ResDinoEventReward"))
		if rewardConfig and rewardConfig[itemId] then
			cost = rewardConfig[itemId].TaskPoints or 0
			configAvailable = rewardConfig[itemId].ClaimNumber or -1
		end
	end)
	
	-- Get availability from UI
	local root = getEventShopUI()
	if not root then 
		return {
			available = configAvailable,
			cost = cost,
			hasLimit = configAvailable ~= -1
		}
	end
	
	local storeFrame = root:FindFirstChild("StoreFrame")
	local frame = storeFrame and storeFrame:FindFirstChild("Frame")
	local scrollFrame = frame and frame:FindFirstChild("ScrollingFrame")
	if not scrollFrame then 
		return {
			available = configAvailable,
			cost = cost,
			hasLimit = configAvailable ~= -1
		}
	end
	
	local item = scrollFrame:FindFirstChild(itemId)
	if not item then 
		return {
			available = configAvailable,
			cost = cost,
			hasLimit = configAvailable ~= -1
		}
	end
	
	-- Check if limit element exists and is visible
	local limit = item:FindFirstChild("limit")
	if limit and limit.Visible then
		local nameLabel = limit:FindFirstChild("NameLabel")
		if nameLabel then
			local text = nameLabel.Text
			-- Parse "Available X times" or just number
			local num = text:match("Available (%d+) times") or text:match("(%d+)")
			local available = tonumber(num) or 0
			return {
				available = available,
				cost = cost,
				hasLimit = true
			}
		end
	end
	
	-- No limit visible, item is unlimited
	return {
		available = -1,
		cost = cost,
		hasLimit = false
	}
end

local function buyEventShopItem(itemId)
	if not itemId then return false end
	
	local args = {
		{
			event = "exchange",
			id = itemId
		}
	}
	
	local ok, err = pcall(function()
		ReplicatedStorage:WaitForChild("Remote"):WaitForChild("DinoEventRE"):FireServer(unpack(args))
	end)
	
	return ok, err
end

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
	
	-- Try Season2 first, fallback to Season1
	local season = seasonPass and (seasonPass:FindFirstChild("Season2") or seasonPass:FindFirstChild("Season1"))
	if not season then return 0, false, 0, false end
	
	local likes = tonumber(season:GetAttribute("D_LikeZoo")) or 0
	local weeklyLikes = tonumber(season:GetAttribute("W_LikeZoo")) or 0
	local ccDaily = tonumber(season:GetAttribute("CC_DailyTask2")) or 0
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
		
		-- Update status display
		if statusParagraph and statusParagraph.SetDesc then
			local msg = string.format("Daily Like: %d/3 | Weekly Like: %d/20", likes, weeklyLikes)
			if autoLikeUnlimited then
				msg = msg .. " (Unlimited Mode)"
			elseif dailyComplete and weeklyComplete then 
				msg = msg .. " (Complete)" 
			end
			statusParagraph:SetDesc(msg)
		end
		
		-- Check stop conditions based on mode
		if not autoLikeUnlimited then
			-- Check both daily and weekly completion
			if dailyComplete and weeklyComplete then break end
		end
		-- If unlimited mode, never stop
		
        local targetId = getRandomOtherUserId()
        if not targetId then
            -- everyone liked already in this server
            noTargetStreak = noTargetStreak + 1
            if autoLikeUnlimited or not weeklyComplete then
				if noTargetStreak >= 3 then
					hopServer()
					task.wait(3.0)
				else
					task.wait(2.0)
				end
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

local function runAutoClaimHalloween(statusParagraph)
	local lastStatus = {}
	
	while autoClaimHalloweenEnabled do
		local claimedAny = false
		local statusLines = {}
		
		-- Check all 3 task slots
		for slot = 1, 3 do
			local ok, result = checkAndClaimTask(slot)
			if ok then
				claimedAny = true
				if WindUI then
					WindUI:Notify({ Title = "🎃 Auto Claim Halloween", Content = result, Duration = 3 })
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

local function runAutoBuyEventShop(statusParagraph)
	while autoBuyEventShopEnabled do
		local candy = getEventCandyAmount()
		local statusLines = {}
		local boughtAny = false
		
		-- Get reward config for item names
		local rewardConfig
		pcall(function()
			rewardConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ResDinoEventReward"))
		end)
		
		-- Determine which items to buy
		local itemsToBuy = {}
		local hasSelection = false
		for _, _ in pairs(selectedEventShopItems) do
			hasSelection = true
			break
		end
		
		if hasSelection then
			-- Buy only selected items
			for itemId, enabled in pairs(selectedEventShopItems) do
				if enabled then
					table.insert(itemsToBuy, itemId)
				end
			end
		else
			-- Buy all items if none selected
			if rewardConfig then
				for rewardId, _ in pairs(rewardConfig) do
					if type(rewardId) == "string" and rewardId:match("^Reward_") then
						table.insert(itemsToBuy, rewardId)
					end
				end
			end
		end
		
		-- Try to buy items
		for _, itemId in ipairs(itemsToBuy) do
			local itemStatus = getEventShopItemStatus(itemId)
			if itemStatus then
				-- Get item name from config
				local itemName = itemId
				if rewardConfig and rewardConfig[itemId] then
					itemName = rewardConfig[itemId].Thing1 or itemId
				end
				
				-- Check if item is available (-1 means unlimited)
				local canBuy = false
				if itemStatus.available == -1 then
					-- Unlimited item
					canBuy = true
				elseif itemStatus.available > 0 then
					-- Limited item with stock remaining
					canBuy = true
				end
				
				if canBuy then
					-- Check if we have enough candy
					if candy >= itemStatus.cost then
						local ok, err = buyEventShopItem(itemId)
						if ok then
							boughtAny = true
							candy = candy - itemStatus.cost -- Update local candy count
							if WindUI then
								WindUI:Notify({ 
									Title = "🎃 Auto Buy Event Shop", 
									Content = string.format("Bought %s for %d candy!", itemName, itemStatus.cost), 
									Duration = 3 
								})
							end
							task.wait(1.0) -- Wait between purchases
							-- Update candy display immediately after purchase
							if statusParagraph and statusParagraph.SetDesc then
								statusParagraph:SetDesc(string.format("Candy: %d", candy))
							end
						end
					else
						table.insert(statusLines, string.format("%s: Not enough candy (%d/%d)", itemName, candy, itemStatus.cost))
					end
				else
					-- Item is sold out
					table.insert(statusLines, string.format("%s: Sold out (0 available)", itemName))
				end
			end
		end
		
		-- Update status display
		if statusParagraph and statusParagraph.SetDesc then
			local statusText = string.format("Candy: %d\n", candy)
			if #statusLines > 0 then
				statusText = statusText .. table.concat(statusLines, "\n")
			else
				statusText = statusText .. "Waiting for items to buy..."
			end
			statusParagraph:SetDesc(statusText)
		end
		
		-- Wait longer if nothing was bought
		task.wait(boughtAny and 2.0 or 5.0)
	end
end

local function runAutoClaimEgg(statusParagraph)
	while autoClaimEggEnabled do
		local claimCount = getEventEggClaimCount()
		
		-- Update status display
		if statusParagraph and statusParagraph.SetDesc then
			statusParagraph:SetDesc(string.format("Available Eggs: %d", claimCount))
		end
		
		-- Claim if eggs are available
		if claimCount > 0 then
			local ok, err = claimEventEgg()
			if ok then
				if WindUI then
					WindUI:Notify({ 
						Title = "🥚 Auto Claim Egg", 
						Content = string.format("Claimed %d egg(s)!", claimCount), 
						Duration = 3 
					})
				end
				task.wait(1.0) -- Wait after claiming
			else
				task.wait(2.0) -- Wait longer if claim failed
			end
		else
			task.wait(3.0) -- Wait longer when no eggs available
		end
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
	
	local unlimitedToggle = MiscTab:Toggle({
		Title = "Unlimited Mode",
		Desc = "Keep liking without any limit, never stop",
		Value = false,
		Callback = function(state)
			autoLikeUnlimited = state
		end
	})
	
	local likeToggle = MiscTab:Toggle({
		Title = "Auto Like Other Zoos",
		Desc = "Automatically like others",
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

	-- Auto Claim Halloween section
	MiscTab:Section({ Title = "Auto Claim Halloween", Icon = "ghost" })
	local halloweenStatus = MiscTab:Paragraph({ Title = "Task Status", Desc = "Halloween Tasks: Detecting..." })
	local halloweenToggle = MiscTab:Toggle({
		Title = "Auto Claim Halloween Rewards",
		Desc = "Automatically claim completed Halloween event tasks",
		Value = false,
		Callback = function(state)
			autoClaimHalloweenEnabled = state
			if state and not autoClaimHalloweenThread then
				autoClaimHalloweenThread = task.spawn(function()
					runAutoClaimHalloween(halloweenStatus)
					autoClaimHalloweenThread = nil
				end)
				if WindUI then
					WindUI:Notify({ Title = "🎃 Auto Claim Halloween", Content = "Started monitoring tasks", Duration = 2 })
				end
			elseif not state and autoClaimHalloweenThread then
				if WindUI then
					WindUI:Notify({ Title = "🎃 Auto Claim Halloween", Content = "Stopped", Duration = 2 })
				end
			end
		end
	})

	-- Auto Buy Event Shop section
	MiscTab:Section({ Title = "Auto Buy Event Shop", Icon = "shopping-cart" })
	local eventShopStatus = MiscTab:Paragraph({ Title = "Shop Status", Desc = "Event Shop: Detecting..." })
	
	-- Get available items for dropdown
	local eventShopItems = getAllEventShopItems()
	local itemNames = {}
	local itemIdToName = {}
	for _, item in ipairs(eventShopItems) do
		table.insert(itemNames, item.displayName)
		itemIdToName[item.displayName] = item.id
	end
	
	local eventShopDropdown = MiscTab:Dropdown({
		Title = "Items to Buy",
		Desc = "Select items to auto-buy (leave empty to buy all)",
		Values = itemNames,
		Value = {},
		Multi = true,
		AllowNone = true,
		Callback = function(selection)
			selectedEventShopItems = {}
			if type(selection) == "table" then
				for _, displayName in ipairs(selection) do
					local itemId = itemIdToName[displayName]
					if itemId then
						selectedEventShopItems[itemId] = true
					end
				end
			end
		end
	})
	
	local eventShopToggle = MiscTab:Toggle({
		Title = "Auto Buy Event Items",
		Desc = "Buy selected items or all if none selected",
		Value = false,
		Callback = function(state)
			autoBuyEventShopEnabled = state
			if state and not autoBuyEventShopThread then
				autoBuyEventShopThread = task.spawn(function()
					runAutoBuyEventShop(eventShopStatus)
					autoBuyEventShopThread = nil
				end)
				if WindUI then
					WindUI:Notify({ Title = "🎃 Auto Buy Event Shop", Content = "Started monitoring shop", Duration = 2 })
				end
			elseif not state and autoBuyEventShopThread then
				if WindUI then
					WindUI:Notify({ Title = "🎃 Auto Buy Event Shop", Content = "Stopped", Duration = 2 })
				end
			end
		end
	})

	-- Auto Claim Egg section
	MiscTab:Section({ Title = "Auto Claim Egg", Icon = "egg" })
	local eggStatus = MiscTab:Paragraph({ Title = "Egg Status", Desc = "Available Eggs: 0" })
	local eggToggle = MiscTab:Toggle({
		Title = "Auto Claim Event Eggs",
		Desc = "Automatically claim online pack eggs when available",
		Value = false,
		Callback = function(state)
			autoClaimEggEnabled = state
			if state and not autoClaimEggThread then
				autoClaimEggThread = task.spawn(function()
					runAutoClaimEgg(eggStatus)
					autoClaimEggThread = nil
				end)
				if WindUI then
					WindUI:Notify({ Title = "🥚 Auto Claim Egg", Content = "Started monitoring eggs", Duration = 2 })
				end
			elseif not state and autoClaimEggThread then
				if WindUI then
					WindUI:Notify({ Title = "🥚 Auto Claim Egg", Content = "Stopped", Duration = 2 })
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
			Config:Register("misc_like_unlimited", unlimitedToggle)
			Config:Register("misc_halloween_toggle", halloweenToggle)
			Config:Register("misc_event_shop_toggle", eventShopToggle)
			Config:Register("misc_event_shop_dropdown", eventShopDropdown)
			Config:Register("misc_egg_toggle", eggToggle)
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


