-- AutoPlace.lua - Auto Pet Placement System for Build A Zoo
-- Author: Zebux

local AutoPlace = {}
local Core = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/Core.lua"))()
local ConfigManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/ConfigManager.lua"))()

-- Auto state variables
local autoPlaceEnabled = false
local autoPlaceThread = nil
local placeConnections = {}
local placingInProgress = false
local availableEggs = {} -- Track available eggs to place
local availableTiles = {} -- Track available tiles
local selectedEggTypes = {} -- Selected egg types for placement
local selectedMutations = {} -- Selected mutations for placement
local tileMonitoringActive = false

-- UI elements (to be set by main script)
local autoPlaceToggle = nil
local placeEggDropdown = nil
local placeMutationDropdown = nil

-- Auto Delete functionality
local autoDeleteEnabled = false
local autoDeleteThread = nil
local deleteSpeedThreshold = 100 -- Default speed threshold

-- Enhanced number parsing function to handle K, M, B, T suffixes and commas
local function parseNumberWithSuffix(text)
    if not text or type(text) ~= "string" then return nil end
    
    -- Remove common prefixes and suffixes
    local cleanText = text:gsub("[$€£¥₹/s]", ""):gsub("^%s*(.-)%s*$", "%1") -- Remove currency symbols and /s
    
    -- Handle comma-separated numbers (e.g., "1,234,567")
    cleanText = cleanText:gsub(",", "")
    
    -- Try to match number with suffix (e.g., "1.5K", "2.3M", "1.2B")
    local number, suffix = cleanText:match("^([%d%.]+)([KkMmBbTt]?)$")
    
    if not number then
        -- Try to match just number without suffix
        number = cleanText:match("^([%d%.]+)$")
        suffix = ""
    end
    
    local numValue = tonumber(number)
    if not numValue then return nil end
    
    -- Apply suffix multipliers
    if suffix and suffix ~= "" then
        local lowerSuffix = suffix:lower()
        if lowerSuffix == "k" then
            numValue = numValue * 1000
        elseif lowerSuffix == "m" then
            numValue = numValue * 1000000
        elseif lowerSuffix == "b" then
            numValue = numValue * 1000000000
        elseif lowerSuffix == "t" then
            numValue = numValue * 1000000000000
        end
    end
    
    return numValue
end

-- Function to get egg options
local function getEggOptions()
    local eggOptions = {}
    
    -- Try to get from ResEgg config first
    local eggConfig = ConfigManager.loadEggConfig()
    if eggConfig then
        for id, data in pairs(eggConfig) do
            if type(id) == "string" and not id:match("^_") and id ~= "_index" and id ~= "__index" then
                local eggName = data.Type or data.Name or id
                table.insert(eggOptions, eggName)
            end
        end
    end
    
    -- Fallback: get from PlayerBuiltBlocks
    if #eggOptions == 0 then
        local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
        if playerBuiltBlocks then
            for _, egg in ipairs(playerBuiltBlocks:GetChildren()) do
                if egg:IsA("Model") then
                    local eggType = egg:GetAttribute("Type") or egg:GetAttribute("EggType") or egg:GetAttribute("Name")
                    if eggType and not table.find(eggOptions, eggType) then
                        table.insert(eggOptions, eggType)
                    end
                end
            end
        end
    end
    
    table.sort(eggOptions)
    return eggOptions
end

-- Egg mutation checking
local function isSelectedMutation(mutationText)
    if not mutationText or mutationText == "" then
        return #selectedMutations == 0 -- If no mutations selected, accept all
    end
    
    -- If specific mutations are selected, check if this mutation is in the list
    if #selectedMutations > 0 then
        for _, mutation in ipairs(selectedMutations) do
            if string.find(string.lower(mutationText), string.lower(mutation)) then
                return true
            end
        end
        return false
    end
    
    return true -- If no mutations specified, accept all
end

-- Function to get pet speed/value from UI
local function getPetSpeedValue(pet)
    if not pet or not pet:IsA("Model") then return 0 end
    
    local billboardGui = pet:FindFirstChild("BillboardGui")
    if not billboardGui then return 0 end
    
    local main = billboardGui:FindFirstChild("Main")
    if not main then return 0 end
    
    local idleGUI = main:FindFirstChild("IdleGUI")
    if not idleGUI then return 0 end
    
    local speedText = idleGUI:FindFirstChild("Speed")
    if speedText and speedText:IsA("TextLabel") then
        -- Parse speed from format like "$100/s", "1.5K/s", "2.3M/s"
        local speedValue = parseNumberWithSuffix(speedText.Text)
        return speedValue or 0
    end
    
    return 0
end

-- Auto Delete pets below threshold
local function autoDeletePets()
    if not autoDeleteEnabled then return end
    
    local petsToDelete = {}
    local playerBuiltBlocks = workspace:FindFirstChild("PlayerBuiltBlocks")
    
    if playerBuiltBlocks then
        for _, pet in ipairs(playerBuiltBlocks:GetChildren()) do
            if pet:IsA("Model") and pet:GetAttribute("Type") then
                local speedValue = getPetSpeedValue(pet)
                if speedValue > 0 and speedValue < deleteSpeedThreshold then
                    table.insert(petsToDelete, {
                        name = pet.Name,
                        speed = speedValue,
                        pet = pet
                    })
                end
            end
        end
    end
    
    -- Delete collected pets
    for _, petData in ipairs(petsToDelete) do
        local success, err = pcall(function()
            local args = {
                "DELETE",
                {
                    Model = petData.pet
                }
            }
            Core.ReplicatedStorage:WaitForChild("Remote"):WaitForChild("BuildingRE"):FireServer(unpack(args))
            print(string.format("🗑️ Deleted pet %s (Speed: %.0f)", petData.name, petData.speed))
        end)
        
        if not success then
            warn("Failed to delete pet: " .. tostring(err))
        end
        
        task.wait(0.1) -- Small delay between deletions
    end
end

-- Auto Place Functions
function AutoPlace.startAutoPlace()
    if autoPlaceThread then return end
    
    autoPlaceEnabled = true
    autoPlaceThread = task.spawn(function()
        while autoPlaceEnabled do
            task.wait(1)
            
            if placingInProgress then
                task.wait(0.5)
                continue
            end
            
            -- Implementation would continue here with tile scanning and placement logic
            -- This is a simplified version for the modular structure
        end
    end)
end

function AutoPlace.stopAutoPlace()
    autoPlaceEnabled = false
    if autoPlaceThread then
        task.cancel(autoPlaceThread)
        autoPlaceThread = nil
    end
end

function AutoPlace.startAutoDelete()
    if autoDeleteThread then return end
    
    autoDeleteEnabled = true
    autoDeleteThread = task.spawn(function()
        while autoDeleteEnabled do
            autoDeletePets()
            task.wait(2) -- Check every 2 seconds
        end
    end)
end

function AutoPlace.stopAutoDelete()
    autoDeleteEnabled = false
    if autoDeleteThread then
        task.cancel(autoDeleteThread)
        autoDeleteThread = nil
    end
end

-- Setters for UI elements
function AutoPlace.setToggle(toggle)
    autoPlaceToggle = toggle
end

function AutoPlace.setEggDropdown(dropdown)
    placeEggDropdown = dropdown
end

function AutoPlace.setMutationDropdown(dropdown)
    placeMutationDropdown = dropdown
end

function AutoPlace.setDeleteThreshold(threshold)
    deleteSpeedThreshold = threshold
end

function AutoPlace.setSelectedEggTypes(types)
    selectedEggTypes = types
end

function AutoPlace.setSelectedMutations(mutations)
    selectedMutations = mutations
end

-- Getters
function AutoPlace.isEnabled()
    return autoPlaceEnabled
end

function AutoPlace.isDeleteEnabled()
    return autoDeleteEnabled
end

function AutoPlace.getDeleteThreshold()
    return deleteSpeedThreshold
end

function AutoPlace.getEggOptions()
    return getEggOptions()
end

return AutoPlace
