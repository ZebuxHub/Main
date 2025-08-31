-- SimpleLauncher.lua - Simple launcher for Build A Zoo with basic premium check
print("🔄 Starting Zebux Build A Zoo...")

-- Basic premium key check
local premiumKey = "prefis8b03e264f1244d7da9db6149389aa1bf"
local userKey = "" -- User will need to change this

-- Check if user has premium
local isPremium = (userKey == premiumKey and userKey ~= "")

-- Set global premium status
getgenv().ZebuxPremium = isPremium
getgenv().ZebuxPremiumFeatures = isPremium and {
    unlimitedSends = true,
    prioritySupport = true,
    advancedWebhooks = true,
    customization = true,
    betaFeatures = true
} or {}

print("👤 User Status:", isPremium and "🌟 Premium" or "🆓 Free")

-- Load main script
local function loadMainScript()
    local buildAZooPath = "d:/Zebux/Build a Zoo/Build A Zoo.lua"
    
    if readfile and isfile and isfile(buildAZooPath) then
        print("📁 Loading Build A Zoo from local file...")
        local success, err = pcall(function()
            loadstring(readfile(buildAZooPath))()
        end)
        
        if success then
            print("✅ Build A Zoo loaded successfully!")
        else
            print("❌ Error loading Build A Zoo:", err)
        end
    else
        print("❌ Build A Zoo file not found at:", buildAZooPath)
        print("Please make sure the file exists and try again.")
    end
end

-- Load the main script
loadMainScript()

--[[
PREMIUM USER INSTRUCTIONS:
1. Change the userKey variable above to: "prefis8b03e264f1244d7da9db6149389aa1bf"
2. Save the file
3. Run this script

FREE USER INSTRUCTIONS:
1. Just run this script as-is
2. You'll get basic features
]]
