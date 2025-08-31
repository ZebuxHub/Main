-- PremiumKeySystem.lua - Premium Key Validation for Build A Zoo
-- Uses KeyGuardian for premium user validation

local PremiumKeySystem = {}

-- KeyGuardian Configuration
local KeyGuardian = loadstring(game:HttpGet('https://cdn.keyguardian.org/library/v2.lua'))()

KeyGuardian:Set({
    ServiceToken = "8336ddf50c0746359b04047ff8e226f7";
    APIToken = "5e4a1fecc29844db815b7e1740ed2279"
})

-- Premium Key
local PremiumKey = "prefis8b03e264f1244d7da9db6149389aa1bf"

-- UI Variables
local WindUI
local Window

-- State
local isPremiumUser = false
local keyValidationComplete = false

-- Premium Features Configuration
local PremiumFeatures = {
    unlimitedSends = true,
    prioritySupport = true,
    advancedWebhooks = true,
    customization = true,
    betaFeatures = true
}

-- Validation function
local function validatePremiumKey(inputKey)
    if not inputKey or inputKey == "" then
        return false, "Please enter a key"
    end
    
    -- Check if input matches premium key
    if inputKey ~= PremiumKey then
        return false, "Invalid premium key"
    end
    
    -- KeyGuardian validation process
    local success, result = pcall(function()
        if not KeyGuardian:ValidateKey(inputKey) then
            return false, "Key validation failed"
        end
        
        -- Complex validation checks (simplified for readability)
        local MT = getmetatable(KeyGuardian.Checks)
        local A, B, C = KeyGuardian.Checks.EQ(inputKey)
        
        -- Sanity checks
        local sanityEnv = getfenv(KeyGuardian.Sanity)
        if not sanityEnv or not sanityEnv["KeyGuardian"] then
            return false, "Sanity check failed"
        end
        
        -- Premium validation
        local Mode = KeyGuardian["Result"] and KeyGuardian["Result"]["Mode"]
        if Mode == "Premium" and KeyGuardian["Result"]["Key"] == inputKey then
            return true, "Premium access granted"
        elseif Mode == "Default" then
            return true, "Standard access granted"
        end
        
        return false, "Access denied"
    end)
    
    if success and result then
        return true, "Premium validation successful"
    else
        return false, result or "Validation error occurred"
    end
end

-- Create Premium Key UI
local function createPremiumKeyUI()
    -- Create Premium Key Window
    Window = WindUI:Window({
        Title = "🔑 Premium Key System",
        Icon = "rbxassetid://10734950020",
        Author = "Zebux",
        Folder = "ZebuxPremium",
        Size = UDim2.fromOffset(480, 360),
        KeySystem = false, -- We handle key system manually
        BackgroundTransparency = 0.1,
        Theme = "Dark",
        SideBarWidth = 170,
    })
    
    local MainTab = Window:Tab({ Title = "🔑 Premium Access", Icon = "key" })
    
    -- Status display
    local statusParagraph = MainTab:Paragraph({
        Title = "Premium Status:",
        Desc = "Enter your premium key to unlock advanced features"
    })
    
    -- Premium features list
    MainTab:Section({ Title = "🌟 Premium Features" })
    
    MainTab:Paragraph({
        Title = "Premium Benefits:",
        Desc = "• Unlimited send operations\n• Priority customer support\n• Advanced webhook customization\n• Beta feature access\n• Custom UI themes\n• Enhanced automation tools"
    })
    
    -- Key input section
    MainTab:Section({ Title = "🔐 Key Validation" })
    
    local keyInput = MainTab:Input({
        Title = "Premium Key",
        Desc = "Enter your premium access key",
        Default = "",
        Numeric = false,
        Finished = true,
        Callback = function(value)
            -- Auto-validate when key is entered
            if value and value ~= "" then
                validateAndProceed(value)
            end
        end
    })
    
    -- Manual validation button
    MainTab:Button({
        Title = "🔓 Validate Key",
        Desc = "Click to validate your premium key",
        Callback = function()
            local currentKey = keyInput:GetValue()
            validateAndProceed(currentKey)
        end
    })
    
    -- Get key link button
    MainTab:Button({
        Title = "🌐 Get Premium Key",
        Desc = "Open key link in browser",
        Callback = function()
            local keyLink = KeyGuardian:GetKeylink()
            if keyLink then
                WindUI:Notify({
                    Title = "🌐 Key Link",
                    Content = "Key link copied to clipboard!\n" .. keyLink,
                    Duration = 5
                })
                -- Copy to clipboard if possible
                if setclipboard then
                    setclipboard(keyLink)
                end
            end
        end
    })
    
    -- Validation and proceed function
    function validateAndProceed(inputKey)
        statusParagraph:SetDesc("🔄 Validating premium key...")
        
        -- Add slight delay for UX
        task.wait(0.5)
        
        local isValid, message = validatePremiumKey(inputKey)
        
        if isValid then
            isPremiumUser = true
            keyValidationComplete = true
            
            statusParagraph:SetDesc("✅ Premium access granted!\n" .. message)
            
            WindUI:Notify({
                Title = "🎉 Premium Access",
                Content = "Welcome to Zebux Premium!",
                Duration = 3
            })
            
            -- Wait a moment then proceed to main script
            task.wait(1)
            Window:Destroy()
            
            -- Load main script with premium features
            loadMainScript(true)
            
        else
            statusParagraph:SetDesc("❌ Key validation failed\n" .. message)
            
            WindUI:Notify({
                Title = "❌ Validation Failed",
                Content = message,
                Duration = 4
            })
        end
    end
    
    -- Free tier button (fallback)
    MainTab:Section({ Title = "🆓 Free Access" })
    
    MainTab:Button({
        Title = "Continue with Free Version",
        Desc = "Use basic features without premium key",
        Callback = function()
            isPremiumUser = false
            keyValidationComplete = true
            
            WindUI:Notify({
                Title = "🆓 Free Access",
                Content = "Continuing with basic features",
                Duration = 3
            })
            
            task.wait(1)
            Window:Destroy()
            
            -- Load main script without premium features
            loadMainScript(false)
        end
    })
end

-- Load main script function
function loadMainScript(isPremium)
    -- Load the main Build A Zoo script
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/YourRepo/BuildAZoo/main/Build%20A%20Zoo.lua"))()
    end)
    
    if not success then
        -- Fallback to local file
        local buildAZooPath = "d:/Zebux/Build a Zoo/Build A Zoo.lua"
        if isfile and isfile(buildAZooPath) then
            loadstring(readfile(buildAZooPath))()
        else
            WindUI:Notify({
                Title = "❌ Error",
                Content = "Failed to load main script: " .. tostring(err),
                Duration = 5
            })
        end
    end
    
    -- Set premium status in global scope for main script to use
    getgenv().ZebuxPremium = isPremium
    getgenv().ZebuxPremiumFeatures = isPremium and PremiumFeatures or {}
end

-- Initialize function
function PremiumKeySystem.Init()
    -- Load WindUI
    if not getgenv().WindUI then
        getgenv().WindUI = loadstring(game:HttpGet("https://github.com/AlexR32/Wind/raw/main/dist.lua"))()
    end
    WindUI = getgenv().WindUI
    
    -- Create the premium key UI
    createPremiumKeyUI()
end

-- Export functions for main script integration
PremiumKeySystem.IsPremium = function()
    return isPremiumUser
end

PremiumKeySystem.GetFeatures = function()
    return isPremiumUser and PremiumFeatures or {}
end

PremiumKeySystem.HasFeature = function(featureName)
    return isPremiumUser and PremiumFeatures[featureName] == true
end

return PremiumKeySystem
