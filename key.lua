-- KeySystem.lua - AuthGuard Key System for Build A Zoo
-- Lua 5.1 Compatible

local KeySystem = {}

-- Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- AuthGuard Configuration
local AUTHGUARD_CONFIG = {
    PRIVATE_KEY = "PRIVATE_KEY", -- Replace with your actual private key
    SERVICE_ID = "SERVICE_ID",   -- Replace with your actual service ID
    SCRIPT_NAME = "Build A Zoo"
}

-- Key validation state
local keyValidated = false
local currentKey = ""
local keyValidationAttempts = 0
local maxValidationAttempts = 3

-- Load AuthGuard
local AuthGuard = nil
local function loadAuthGuard()
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/AuthGuard0/library/refs/heads/main/v1.lua"))(
            AUTHGUARD_CONFIG.PRIVATE_KEY,
            {
                serviceId = AUTHGUARD_CONFIG.SERVICE_ID,
            }
        )
    end)
    
    if success and result then
        AuthGuard = result
        return true
    else
        warn("Failed to load AuthGuard: " .. tostring(result))
        return false
    end
end

-- Key storage functions
local function saveKey(key)
    if not writefile then return false end
    
    local success, err = pcall(function()
        local keyData = {
            key = key,
            timestamp = os.time(),
            scriptName = AUTHGUARD_CONFIG.SCRIPT_NAME
        }
        local jsonData = HttpService:JSONEncode(keyData)
        writefile("Zebux_KeyData.json", jsonData)
    end)
    
    return success
end

local function loadSavedKey()
    if not readfile or not isfile then return nil end
    
    local success, result = pcall(function()
        if isfile("Zebux_KeyData.json") then
            local jsonData = readfile("Zebux_KeyData.json")
            local keyData = HttpService:JSONDecode(jsonData)
            
            -- Check if this is for the same script
            if keyData and keyData.scriptName == AUTHGUARD_CONFIG.SCRIPT_NAME then
                return keyData.key
            end
        end
    end)
    
    return success and result or nil
end

local function clearSavedKey()
    if not delfile or not isfile then return false end
    
    local success, err = pcall(function()
        if isfile("Zebux_KeyData.json") then
            delfile("Zebux_KeyData.json")
        end
    end)
    
    return success
end

-- Key validation function
local function validateKey(key)
    if not AuthGuard then
        warn("AuthGuard not loaded")
        return false
    end
    
    if not key or key == "" then
        return false
    end
    
    keyValidationAttempts = keyValidationAttempts + 1
    
    local success, result = pcall(function()
        return AuthGuard:validateKey(key)
    end)
    
    if success and result then
        keyValidated = true
        currentKey = key
        saveKey(key)
        return true
    else
        warn("Key validation failed: " .. tostring(result))
        return false
    end
end

-- Auto-validation on script start
local function autoValidateKey()
    local savedKey = loadSavedKey()
    if savedKey then
        if validateKey(savedKey) then
            print("✅ Auto-validated saved key successfully!")
            return true
        else
            print("❌ Saved key is invalid, clearing...")
            clearSavedKey()
        end
    end
    return false
end

-- GUI Creation
function KeySystem.CreateGUI()
    -- Load AuthGuard first
    if not loadAuthGuard() then
        warn("Failed to load AuthGuard, key system disabled")
        return false
    end
    
    -- Try auto-validation
    if autoValidateKey() then
        return true -- Key already valid, no need for GUI
    end
    
    -- Create WindUI Window for key system
    local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
    
    local KeyWindow = WindUI:CreateWindow({
        Title = "🔐 " .. AUTHGUARD_CONFIG.SCRIPT_NAME .. " - Key System",
        Icon = "shield",
        IconThemed = true,
        Author = "Zebux",
        Folder = "Zebux",
        Size = UDim2.fromOffset(400, 300),
        Transparent = true,
        Theme = "Dark",
    })
    
    -- Status display
    local statusParagraph = KeyWindow:Paragraph({
        Title = "🔐 Key Status",
        Desc = "Please enter your key to continue",
        Image = "shield",
        ImageSize = 22
    })
    
    -- Key input
    local keyInput = KeyWindow:Input({
        Title = "🔑 Enter Key",
        Desc = "Enter your AuthGuard key here",
        Default = "",
        Callback = function(value)
            currentKey = value
        end
    })
    
    -- Get key link button
    KeyWindow:Button({
        Title = "🔗 Get Key",
        Desc = "Click to open the key website",
        Callback = function()
            if AuthGuard then
                local link = AuthGuard:getLink()
                if link then
                    -- Try to open the link
                    local success, err = pcall(function()
                        setclipboard(link)
                    end)
                    
                    if success then
                        WindUI:Notify({
                            Title = "🔗 Key Link",
                            Content = "Key link copied to clipboard! Open it in your browser.",
                            Duration = 5
                        })
                    else
                        WindUI:Notify({
                            Title = "🔗 Key Link",
                            Content = "Key link: " .. link,
                            Duration = 8
                        })
                    end
                else
                    WindUI:Notify({
                        Title = "❌ Error",
                        Content = "Failed to get key link",
                        Duration = 3
                    })
                end
            end
        end
    })
    
    -- Validate key button
    KeyWindow:Button({
        Title = "✅ Validate Key",
        Desc = "Check if your key is valid",
        Callback = function()
            if keyValidationAttempts >= maxValidationAttempts then
                WindUI:Notify({
                    Title = "⚠️ Too Many Attempts",
                    Content = "Please wait before trying again",
                    Duration = 3
                })
                return
            end
            
            if not currentKey or currentKey == "" then
                WindUI:Notify({
                    Title = "⚠️ No Key Entered",
                    Content = "Please enter a key first",
                    Duration = 3
                })
                return
            end
            
            -- Update status
            statusParagraph:SetDesc("Validating key...")
            
            -- Validate key
            if validateKey(currentKey) then
                statusParagraph:SetDesc("✅ Key validated successfully!")
                WindUI:Notify({
                    Title = "✅ Success",
                    Content = "Key is valid! Starting script...",
                    Duration = 3
                })
                
                -- Close key window and return success
                task.wait(2)
                KeyWindow:Close()
                return true
            else
                local attemptsLeft = maxValidationAttempts - keyValidationAttempts
                statusParagraph:SetDesc("❌ Invalid key. Attempts left: " .. attemptsLeft)
                WindUI:Notify({
                    Title = "❌ Invalid Key",
                    Content = "Please check your key and try again. Attempts left: " .. attemptsLeft,
                    Duration = 3
                })
            end
        end
    })
    
    -- Clear saved key button
    KeyWindow:Button({
        Title = "🗑️ Clear Saved Key",
        Desc = "Remove saved key from this device",
        Callback = function()
            if clearSavedKey() then
                WindUI:Notify({
                    Title = "🗑️ Key Cleared",
                    Content = "Saved key has been removed",
                    Duration = 3
                })
                statusParagraph:SetDesc("Saved key cleared")
            else
                WindUI:Notify({
                    Title = "❌ Error",
                    Content = "Failed to clear saved key",
                    Duration = 3
                })
            end
        end
    })
    
    -- Help section
    KeyWindow:Section({ Title = "❓ Help", Icon = "help-circle" })
    
    KeyWindow:Paragraph({
        Title = "How to get a key:",
        Desc = "1. Click 'Get Key' to copy the link\n2. Open the link in your browser\n3. Follow the instructions to get your key\n4. Copy the key and paste it here\n5. Click 'Validate Key' to continue",
        Image = "info",
        ImageSize = 18
    })
    
    -- Make window draggable
    KeyWindow:EditOpenButton({ 
        Title = "🔐 Key System", 
        Icon = "shield", 
        Draggable = true 
    })
    
    -- Return the window for external control
    return KeyWindow
end

-- Public functions
function KeySystem.IsKeyValid()
    return keyValidated
end

function KeySystem.GetCurrentKey()
    return currentKey
end

function KeySystem.ValidateKey(key)
    return validateKey(key)
end

function KeySystem.ClearKey()
    keyValidated = false
    currentKey = ""
    keyValidationAttempts = 0
    return clearSavedKey()
end

-- Auto-validation on require
if autoValidateKey() then
    print("✅ Key system ready - key already validated!")
else
    print("🔐 Key system ready - GUI will be shown when needed")
end

return KeySystem
