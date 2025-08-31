local KeyGuardLibrary = loadstring(game:HttpGet("https://cdn.keyguardian.org/library/v1.0.0.lua"))()

-- Normal user data
local normalTrueData = "5deff8e5966a4de0b2d08c93c926208e"
local normalFalseData = "a5525b56c8d34282818a4fdcc09462e8"

-- Premium user data  
local premiumTrueData = "1b330b041411408fafa547fd07c7d2e1"
local premiumFalseData = "8b630b18a9c7448fb00c180ad1d61002"

KeyGuardLibrary.Set({
	publicToken = "8336ddf50c0746359b04047ff8e226f7",
	privateToken = "5e4a1fecc29844db815b7e1740ed2279",
	trueData = normalTrueData, -- Default to normal
	falseData = normalFalseData,
})

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local normalKey = ""
local premiumKey = ""

-- Track current user type
local userType = "normal" -- "normal" or "premium"

-- Rejoin game function for free users
local function rejoinGame()
    game:GetService("TeleportService"):Teleport(game.PlaceId, game.Players.LocalPlayer)
end

-- Load saved key from file
local function loadSavedKey()
    local success, result = pcall(function()
        return readfile("BuildAZoo_Key.txt")
    end)
    if success and result and result ~= "" then
        -- Parse saved data (key|timestamp|usertype)
        local parts = result:split("|")
        if #parts == 3 then
            local savedKey = parts[1]
            local savedTimestamp = tonumber(parts[2])
            local savedUserType = parts[3]
            
            -- Different behavior based on user type
            local currentTime = os.time()
            local timeDiff = currentTime - savedTimestamp
            
            if savedUserType == "premium" then
                -- Premium users never expire
                print("Premium user detected - unlimited access")
                userType = savedUserType
                return savedKey, savedUserType
            else
                -- Normal users rejoin every 8 hours
                local rejoinTime = 8 * 60 * 60 -- 8 hours for normal users
                
                if timeDiff < rejoinTime then
                    local remainingTime = rejoinTime - timeDiff
                    local remainingHours = math.floor(remainingTime / 3600)
                    print("Normal user - rejoining in " .. remainingHours .. " hours")
                    userType = savedUserType
                    return savedKey, savedUserType
                else
                    print("Normal user 8-hour period expired - rejoining game...")
                    -- Clear key and rejoin
                    pcall(function()
                        delfile("BuildAZoo_Key.txt")
                    end)
                    
                    spawn(function()
                        wait(2) -- Give time for message to show
                        rejoinGame()
                    end)
                    
                    return "", "normal"
                end
            end
        end
    end
    return "", "normal"
end

-- Save key to file with timestamp and user type
local function saveKey(keyToSave, keyUserType)
    local currentTime = os.time()
    local dataToSave = keyToSave .. "|" .. tostring(currentTime) .. "|" .. keyUserType
    
    local success = pcall(function()
        writefile("BuildAZoo_Key.txt", dataToSave)
    end)
    return success
end

-- Function to handle key validation and auto-execution
local function validateAndExecuteKey(keyToValidate, keyType, windowToDestroy)
    local response
    local validData
    
    if keyType == "premium" then
        -- Set premium data temporarily
        KeyGuardLibrary.Set({
            publicToken = "8336ddf50c0746359b04047ff8e226f7",
            privateToken = "5e4a1fecc29844db815b7e1740ed2279",
            trueData = premiumTrueData,
            falseData = premiumFalseData,
        })
        response = KeyGuardLibrary.validatePremiumKey(keyToValidate)
        validData = premiumTrueData
    else
        -- Set normal data temporarily
        KeyGuardLibrary.Set({
            publicToken = "8336ddf50c0746359b04047ff8e226f7",
            privateToken = "5e4a1fecc29844db815b7e1740ed2279",
            trueData = normalTrueData,
            falseData = normalFalseData,
        })
        response = KeyGuardLibrary.validateDefaultKey(keyToValidate)
        validData = normalTrueData
    end
    
    if response == validData then
        print("✅ " .. keyType:upper() .. " key is valid - executing script...")
        
        userType = keyType
        
        -- Destroy the UI if window is provided
        if windowToDestroy then
            windowToDestroy:Destroy()
            print("🗑️ UI destroyed")
        end
        
        -- Build A Zoo: Auto Buy Egg using WindUI
        loadstring(game:HttpGet("https://cdn.authguard.org/virtual-file/2da65111c4804eb79ca995b361b5c396"))()
        
        return true
    else
        print("❌ " .. keyType:upper() .. " key is invalid")
        return false
    end
end

-- Auto-load and validate saved key
local savedKey, savedUserType = loadSavedKey()
if savedKey ~= "" then
    -- Auto-validate the saved key
    if validateAndExecuteKey(savedKey, savedUserType) then
        if savedUserType == "premium" then
            premiumKey = savedKey
        else
            normalKey = savedKey
        end
        -- Start Place Here

        -- End Place Here
        return -- Exit early since script is loaded
    else
        print("❌ Saved key is no longer valid")
        -- Clear invalid key
        pcall(function()
            delfile("BuildAZoo_Key.txt")
        end)
        normalKey = ""
        premiumKey = ""
    end
else
    normalKey = ""
    premiumKey = ""
end

local Window = Fluent:CreateWindow({
		Title = "Key System - Zebux",
		SubTitle = "Normal & Premium Access",
		TabWidth = 160,
		Size = UDim2.fromOffset(580, 400),
		Acrylic = false,
		Theme = "Dark",
		MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
		Normal = Window:AddTab({ Title = "Normal User", Icon = "key" }),
		Premium = Window:AddTab({ Title = "Premium User", Icon = "crown" }),
}

-- Normal User Tab
local NormalEntkey = Tabs.Normal:AddInput("NormalInput", {
		Title = "Enter Normal Key",
		Description = "8 hour sessions - Free (auto-rejoin)",
		Default = normalKey,
		Placeholder = "Enter normal key…",
		Numeric = false,
		Finished = false,
		Callback = function(Value)
				normalKey = Value
		end
})

local NormalCheckkey = Tabs.Normal:AddButton({
		Title = "✅ Check Normal Key",
		Description = "Validate your normal key (8 hour sessions)",
		Callback = function()
				if validateAndExecuteKey(normalKey, "normal", Window) then
					-- Save the valid key with timestamp
					if saveKey(normalKey, "normal") then
						print("Normal key saved successfully! (8 hour sessions)")
					else
						print("Failed to save key")
					end
				end
		end
})

local NormalGetkey = Tabs.Normal:AddButton({
		Title = "🔗 Get Normal Key",
		Description = "Get free normal key (8 hour sessions)",
		Callback = function()
				-- Set to normal data for link generation
				KeyGuardLibrary.Set({
					publicToken = "8336ddf50c0746359b04047ff8e226f7",
					privateToken = "5e4a1fecc29844db815b7e1740ed2279",
					trueData = normalTrueData,
					falseData = normalFalseData,
				})
				setclipboard(KeyGuardLibrary.getLink())
				print("Normal key link copied to clipboard!")
		end
})

-- Premium User Tab
local PremiumEntkey = Tabs.Premium:AddInput("PremiumInput", {
		Title = "Enter Premium Key",
		Description = "Unlimited access - Premium features",
		Default = premiumKey,
		Placeholder = "Enter premium key…",
		Numeric = false,
		Finished = false,
		Callback = function(Value)
				premiumKey = Value
		end
})

local PremiumCheckkey = Tabs.Premium:AddButton({
		Title = "👑 Check Premium Key",
		Description = "Validate your premium key (unlimited)",
		Callback = function()
				if validateAndExecuteKey(premiumKey, "premium", Window) then
					-- Save the valid key with timestamp
					if saveKey(premiumKey, "premium") then
						print("Premium key saved successfully! (Unlimited access)")
					else
						print("Failed to save key")
					end
				end
		end
})

local PremiumGetkey = Tabs.Premium:AddButton({
		Title = "💎 Get Premium Key",
		Description = "Purchase premium key (unlimited access)",
		Callback = function()
				-- Set to premium data for link generation
				KeyGuardLibrary.Set({
					publicToken = "8336ddf50c0746359b04047ff8e226f7",
					privateToken = "5e4a1fecc29844db815b7e1740ed2279",
					trueData = premiumTrueData,
					falseData = premiumFalseData,
				})
				setclipboard(KeyGuardLibrary.getLink())
				print("Premium key link copied to clipboard!")
		end
})

-- Info sections
Tabs.Normal:AddParagraph({
    Title = "ℹ️ Normal Access",
    Content = "• 8 hour sessions\n• Free to use\n• Auto-rejoin every 8 hours"
})

Tabs.Premium:AddParagraph({
    Title = "👑 Premium Access", 
    Content = "• Priority support\n• No time restrictions\n• Never expires"
})

Window:SelectTab(1)
