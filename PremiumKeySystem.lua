-- PremiumKeySystem.lua - Premium Key Authentication for Build A Zoo
-- Advanced Key System with KeyGuardian Integration

local PremiumKeySystem = {}

-- KeyGuardian Configuration
local KeyGuardian = loadstring(game:HttpGet('https://cdn.keyguardian.org/library/v2.lua'))()

KeyGuardian:Set({
    ServiceToken = "8336ddf50c0746359b04047ff8e226f7",  -- Public Token
    APIToken = "5e4a1fecc29844db815b7e1740ed2279"       -- Private Token
})

-- Premium Key Configuration
local PREMIUM_KEY = "prefis8b03e264f1244d7da9db6149389aa1bf"

-- UI Library
local WindUI = loadstring(game:HttpGet("https://github.com/shlexware/Windowing/releases/latest/download/source.lua"))()

-- State Management
local validationState = {
    isValidated = false,
    isPremium = false,
    userKey = "",
    attempts = 0,
    maxAttempts = 3
}

-- Create Premium Key UI
local function createPremiumKeyUI()
    local Window = WindUI:CreateWindow({
        Title = "🌟 Build A Zoo - Premium Access",
        Icon = "rbxassetid://10734950309",
        Author = "Zebux Premium",
        Folder = "ZebuxPremium",
        Size = UDim2.fromOffset(400, 300),
        KeySystem = false,
        Transparent = true,
        Theme = "Dark",
        SideBarWidth = 170
    })
    
    -- Main Tab
    local MainTab = Window:Tab({
        Title = "🔑 Premium Authentication",
        Icon = "key"
    })
    
    -- Header Section
    MainTab:Section({
        Title = "🌟 Premium Access Required",
        Icon = "star"
    })
    
    MainTab:Paragraph({
        Title = "Premium Features:",
        Desc = "• Advanced automation systems\n• Priority support\n• Exclusive features\n• No limitations\n• Discord webhook integration"
    })
    
    -- Key Input Section
    MainTab:Section({
        Title = "🔐 Enter Premium Key",
        Icon = "lock"
    })
    
    local keyInput = MainTab:Input({
        Title = "Premium Key",
        Desc = "Enter your premium access key",
        Default = "",
        Numeric = false,
        Finished = true,
        Callback = function(value)
            validationState.userKey = tostring(value or "")
        end
    })
    
    -- Status Display
    local statusParagraph = MainTab:Paragraph({
        Title = "Status:",
        Desc = "Waiting for key input..."
    })
    
    -- Validate Button
    MainTab:Button({
        Title = "🚀 Validate Premium Key",
        Desc = "Authenticate your premium access",
        Callback = function()
            validatePremiumKey(statusParagraph, Window)
        end
    })
    
    -- Get Key Link Button
    MainTab:Button({
        Title = "🔗 Get Premium Key",
        Desc = "Open key generation link",
        Callback = function()
            local keyLink = KeyGuardian:GetKeylink()
            if keyLink then
                setclipboard(keyLink)
                WindUI:Notify({
                    Title = "🔗 Key Link",
                    Content = "Key generation link copied to clipboard!",
                    Duration = 5
                })
            else
                WindUI:Notify({
                    Title = "❌ Error",
                    Content = "Failed to get key link",
                    Duration = 3
                })
            end
        end
    })
    
    -- Info Section
    MainTab:Section({
        Title = "ℹ️ Information",
        Icon = "info"
    })
    
    MainTab:Paragraph({
        Title = "Need Help?",
        Desc = "• Join our Discord for support\n• Premium keys are valid for 24 hours\n• Contact support for key issues"
    })
    
    return Window
end

-- Advanced Validation Function
local function performAdvancedValidation(key)
    local MT = getmetatable(KeyGuardian.Checks)
    local A, B, C = KeyGuardian.Checks.EQ(key)
    
    -- Primary KeyGuardian validation
    if not KeyGuardian:ValidateKey(key) then
        return false, "Invalid key or HWID mismatch"
    end
    
    -- Sanity checks
    local sanityEnv = getfenv(KeyGuardian.Sanity)
    if not sanityEnv or not sanityEnv["KeyGuardian"] then
        return false, "Sanity check failed"
    end
    
    local kg = sanityEnv["KeyGuardian"]
    
    -- Advanced sanity validation
    local sanityChecks = {
        kg["math.random"]["RNG1"]["NUM"] == kg["math.random"]["RNG1"]["NUM"],
        kg["math.random"]["RNG2"]["NUM"] == kg["math.random"]["RNG2"]["NUM"],
        kg["Premium"]["NotPremium"] == true,
        kg["SHA256"]["Decoded"] == kg["SHA256"]["Decoded"]
    }
    
    for _, check in ipairs(sanityChecks) do
        if not check then
            return false, "Advanced sanity check failed"
        end
    end
    
    -- Complex validation matrix
    if A and B and C and MT == getmetatable(KeyGuardian.Checks) then
        local complexChecks = {
            type(A) == "table",
            type(B) == "table", 
            type(C) == "table",
            MT.__index == KeyGuardian.Method,
            MT.__call ~= nil
        }
        
        for _, check in ipairs(complexChecks) do
            if not check then
                return false, "Complex validation failed"
            end
        end
    else
        return false, "Validation matrix failed"
    end
    
    -- Final result validation
    local result = KeyGuardian["Result"]
    if not result then
        return false, "No validation result"
    end
    
    local mode = result["Mode"]
    if not mode or (mode ~= "Premium" and mode ~= "Default") then
        return false, "Invalid access mode"
    end
    
    if result["Key"] ~= key then
        return false, "Key mismatch in result"
    end
    
    return true, mode
end

-- Validate Premium Key
function validatePremiumKey(statusDisplay, window)
    validationState.attempts = validationState.attempts + 1
    
    -- Update status
    statusDisplay:SetDesc("🔄 Validating premium key... (Attempt " .. validationState.attempts .. "/" .. validationState.maxAttempts .. ")")
    
    if validationState.userKey == "" then
        statusDisplay:SetDesc("❌ Please enter a premium key first")
        WindUI:Notify({
            Title = "⚠️ No Key",
            Content = "Please enter your premium key",
            Duration = 3
        })
        return
    end
    
    -- Check attempt limit
    if validationState.attempts > validationState.maxAttempts then
        statusDisplay:SetDesc("🚫 Maximum attempts exceeded. Please restart the script.")
        WindUI:Notify({
            Title = "🚫 Too Many Attempts",
            Content = "Maximum validation attempts exceeded",
            Duration = 5
        })
        return
    end
    
    -- Perform validation
    local success, result = pcall(function()
        return performAdvancedValidation(validationState.userKey)
    end)
    
    if not success then
        statusDisplay:SetDesc("❌ Validation error: " .. tostring(result))
        WindUI:Notify({
            Title = "❌ Validation Error",
            Content = "An error occurred during validation",
            Duration = 3
        })
        return
    end
    
    local isValid, mode = result, nil
    if type(result) == "table" then
        isValid, mode = result[1], result[2]
    end
    
    if isValid then
        validationState.isValidated = true
        validationState.isPremium = (mode == "Premium")
        
        statusDisplay:SetDesc("✅ Premium access validated! Mode: " .. (mode or "Premium"))
        
        WindUI:Notify({
            Title = "🌟 Premium Validated!",
            Content = "Premium access granted. Loading Build A Zoo...",
            Duration = 3
        })
        
        -- Close key window
        task.wait(1)
        window:Destroy()
        
        -- Load main script
        loadMainScript()
    else
        statusDisplay:SetDesc("❌ Validation failed: " .. (mode or "Invalid key"))
        WindUI:Notify({
            Title = "❌ Validation Failed",
            Content = mode or "Invalid premium key",
            Duration = 3
        })
    end
end

-- Load Main Script Function
function loadMainScript()
    WindUI:Notify({
        Title = "🚀 Loading...",
        Content = "Loading Build A Zoo with premium features...",
        Duration = 2
    })
    
    task.wait(0.5)
    
    -- Load the main Build A Zoo script
    local success, err = pcall(function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/YourRepo/BuildAZoo/main/Build%20A%20Zoo.lua'))()
    end)
    
    if not success then
        -- Fallback to local file if available
        local localScript = game:GetService("ReplicatedStorage"):FindFirstChild("Build A Zoo")
        if localScript then
            loadstring(localScript.Source)()
        else
            WindUI:Notify({
                Title = "❌ Load Error",
                Content = "Failed to load main script: " .. tostring(err),
                Duration = 5
            })
        end
    end
end

-- Anti-Tamper Protection
local function setupAntiTamper()
    local mt = {
        __index = function(t, k)
            return rawget(t, k)
        end,
        __newindex = function(t, k, v)
            if k == "isValidated" or k == "isPremium" then
                error("Access denied: Tampering detected", 2)
            end
            rawset(t, k, v)
        end
    }
    setmetatable(validationState, mt)
end

-- Initialize Premium Key System
function PremiumKeySystem.Init()
    setupAntiTamper()
    
    -- Check if already validated
    if validationState.isValidated then
        loadMainScript()
        return
    end
    
    -- Create and show key UI
    local keyWindow = createPremiumKeyUI()
    
    WindUI:Notify({
        Title = "🌟 Premium Access",
        Content = "Enter your premium key to continue",
        Duration = 3
    })
end

-- Public API
function PremiumKeySystem.IsValidated()
    return validationState.isValidated
end

function PremiumKeySystem.IsPremium()
    return validationState.isPremium
end

function PremiumKeySystem.GetKeyLink()
    return KeyGuardian:GetKeylink()
end

return PremiumKeySystem
