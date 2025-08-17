local KeyGuardLibrary = loadstring(game:HttpGet("https://cdn.keyguardian.org/library/v1.0.0.lua"))()
local trueData = "5deff8e5966a4de0b2d08c93c926208e"
local falseData = "a5525b56c8d34282818a4fdcc09462e8"

KeyGuardLibrary.Set({
	publicToken = "8336ddf50c0746359b04047ff8e226f7",
	privateToken = "5e4a1fecc29844db815b7e1740ed2279",
	trueData = trueData,
	falseData = falseData,
})

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local key = ""

-- Load saved key from file
local function loadSavedKey()
    local success, result = pcall(function()
        return readfile("BuildAZoo_Key.txt")
    end)
    if success and result and result ~= "" then
        -- Parse saved data (key|timestamp)
        local parts = result:split("|")
        if #parts == 2 then
            local savedKey = parts[1]
            local savedTimestamp = tonumber(parts[2])
            
            -- Check if key has expired (12 hours = 43200 seconds)
            local currentTime = os.time()
            local timeDiff = currentTime - savedTimestamp
            local expirationTime = 12 * 60 * 60 -- 12 hours in seconds
            
            if timeDiff < expirationTime then
                print("Saved key is still valid (expires in " .. math.floor((expirationTime - timeDiff) / 3600) .. " hours)")
                return savedKey
            else
                print("Saved key has expired")
                -- Clear expired key
                pcall(function()
                    delfile("BuildAZoo_Key.txt")
                end)
                return ""
            end
        end
    end
    return ""
end

-- Save key to file with timestamp
local function saveKey(keyToSave)
    local currentTime = os.time()
    local dataToSave = keyToSave .. "|" .. tostring(currentTime)
    
    local success = pcall(function()
        writefile("BuildAZoo_Key.txt", dataToSave)
    end)
    return success
end

-- Function to handle key validation and auto-execution
local function validateAndExecuteKey(keyToValidate)
    local response = KeyGuardLibrary.validateDefaultKey(keyToValidate)
    if response == trueData then
        print("✅ Key is valid - executing script...")
        loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/Test.lua"))()
        return true
    else
        print("❌ Key is invalid")
        return false
    end
end

-- Auto-load and validate saved key
local savedKey = loadSavedKey()
if savedKey ~= "" then
    -- Auto-validate the saved key
    if validateAndExecuteKey(savedKey) then
        key = savedKey
        -- Start Place Here

        -- End Place Here
        return -- Exit early since script is loaded
    else
        print("❌ Saved key is no longer valid")
        -- Clear invalid key
        pcall(function()
            delfile("BuildAZoo_Key.txt")
        end)
        key = ""
    end
else
    key = ""
end

local Window = Fluent:CreateWindow({
		Title = "Key System",
		SubTitle = "Zebux",
		TabWidth = 160,
		Size = UDim2.fromOffset(580, 340),
		Acrylic = false,
		Theme = "Dark",
		MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
		KeySys = Window:AddTab({ Title = "Key System", Icon = "key" }),
}

local Entkey = Tabs.KeySys:AddInput("Input", {
		Title = "Enter Key",
		Description = "Enter Key Here",
		Default = key, -- Auto-load saved key
		Placeholder = "Enter key…",
		Numeric = false,
		Finished = false,
		Callback = function(Value)
				key = Value
		end
})

local Checkkey = Tabs.KeySys:AddButton({
		Title = "Check Key",
		Description = "Enter Key before pressing this button",
		Callback = function()
				if validateAndExecuteKey(key) then
					-- Save the valid key with timestamp
					if saveKey(key) then
						print("Key saved successfully! (Expires in 12 hours)")
					else
						print("Failed to save key")
					end
				end
		end
})

local Getkey = Tabs.KeySys:AddButton({
		Title = "Get Key",
		Description = "Get Key here",
		Callback = function()
				setclipboard(KeyGuardLibrary.getLink())
		end
})

Window:SelectTab(1)
